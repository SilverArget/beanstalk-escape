class_name PlayerController
extends CharacterBody2D

enum MovementMode { TRUNK, ATTACHED, TRANSITION }
enum SupportState { SUPPORTED, TRANSFERRING, FALLING_RECOVERY }

var spawn_position := Vector2.ZERO
var knockback_remaining := 0.0
var stun_remaining := 0.0
var bean_penalty_count := 0
var vertical_blocked := false
var time_wings_active := false
var fire_wings_active := false
var rock_penalty_count := 0
var knockback_speed := Balance.BEAN_KNOCKBACK_SPEED
var active_branch := 1
var transition_from := 1
var transition_to := 1
var transition_progress := 0.0
var movement_mode := MovementMode.TRUNK
var branch_transition_count := 0
var on_support := true
var support_state := SupportState.SUPPORTED
var support_offset := 0.0
var support_offset_velocity := 0.0
var transfer_wind_offset := 0.0
var transfer_wind_velocity := 0.0
var recovery_remaining := 0.0
var recovery_velocity_y := 0.0
var transition_base_y := 0.0
var branch_graph := BranchGraph.new()
var _last_stage := 1
var _pending_branch_direction := 0
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager
@onready var body: Node2D = get_node_or_null("Body") as Node2D
@onready var storm: StormMechanics = get_parent().get_node_or_null("StormMechanics") as StormMechanics

func _ready() -> void:
	spawn_position = global_position
	_sync_stage_mode()

func _physics_process(delta: float) -> void:
	knockback_remaining = maxf(knockback_remaining - delta, 0.0)
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	_sync_stage_mode()
	if support_state == SupportState.FALLING_RECOVERY:
		_update_falling_recovery(delta)
		return
	if movement_mode == MovementMode.TRUNK:
		_update_trunk_movement(delta)
	else:
		_update_branch_movement(delta)
	if movement_mode == MovementMode.TRANSITION:
		vertical_blocked = false
		velocity = Vector2(0.0, -climb_speed())
		return
	vertical_blocked = not on_support
	if knockback_remaining > 0.0:
		velocity.y = knockback_speed
	elif stun_remaining > 0.0 or not on_support:
		velocity.y = 0.0
	else:
		velocity.y = -climb_speed()
	move_and_slide()
	if movement_mode == MovementMode.TRUNK:
		global_position.x = clampf(global_position.x, -Balance.TRUNK_HALF_WIDTH, Balance.TRUNK_HALF_WIDTH)
	elif support_state == SupportState.SUPPORTED:
		global_position.x = stages.branch_x_at(active_branch, global_position.y) + support_offset

func _sync_stage_mode() -> void:
	if stages == null:
		return
	var stage := stages.stage_for_y(global_position.y)
	if stage <= 2:
		if movement_mode != MovementMode.TRUNK:
			_reset_visual_pose()
		movement_mode = MovementMode.TRUNK
		support_state = SupportState.SUPPORTED
		on_support = true
		active_branch = stages.route_for_x(global_position.x)
	elif _last_stage <= 2 or movement_mode == MovementMode.TRUNK:
		# The trunk itself continues as the middle vine. Entering Stage 3 always
		# lands on that same support, regardless of the player's trunk-side X.
		active_branch = 1
		transition_from = active_branch
		transition_to = active_branch
		transition_progress = 0.0
		movement_mode = MovementMode.ATTACHED
		support_state = SupportState.SUPPORTED
		on_support = true
		global_position.x = stages.branch_x_at(active_branch, global_position.y)
		_reset_visual_pose()
	_last_stage = stage

func _update_trunk_movement(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	if stun_remaining <= 0.0:
		velocity.x = move_toward(velocity.x, axis * Balance.PLAYER_HORIZONTAL_SPEED, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	active_branch = stages.route_for_x(global_position.x)
	on_support = true
	support_state = SupportState.SUPPORTED
	_reset_visual_pose()

func _update_branch_movement(delta: float) -> void:
	velocity.x = 0.0
	if movement_mode == MovementMode.TRANSITION:
		if storm != null:
			var wind_step := storm.step_transfer_wind(transfer_wind_offset, transfer_wind_velocity, transition_base_y, delta, time_wings_active)
			transfer_wind_offset = wind_step.x
			transfer_wind_velocity = wind_step.y
		transition_progress = minf(transition_progress + delta / Balance.BRANCH_TRANSITION_SECONDS, 1.0)
		if transition_progress >= 1.0 - 0.00001:
			transition_progress = 1.0
		transition_base_y -= climb_speed() * delta
		if transition_progress >= 0.75:
			transfer_wind_offset = lerpf(transfer_wind_offset, support_offset, (transition_progress - 0.75) / 0.25)
		global_position = branch_graph.transfer_point(stages, transition_from, transition_to, transition_base_y, transition_progress, transfer_wind_offset)
		on_support = false
		support_state = SupportState.TRANSFERRING
		_update_transition_visual(transition_progress)
		if transition_progress >= 1.0:
			if branch_graph.has_support(stages, transition_to, transition_base_y):
				active_branch = transition_to
				global_position = branch_graph.support_point(stages, active_branch, transition_base_y, support_offset)
				movement_mode = MovementMode.ATTACHED
				support_state = SupportState.SUPPORTED
				on_support = true
				_reset_visual_pose()
			else:
				_begin_falling_recovery()
		return
	if storm != null:
		var wind_step := storm.step_support_wind(support_offset, support_offset_velocity, global_position.y, delta, time_wings_active)
		support_offset = wind_step.x
		support_offset_velocity = wind_step.y
	global_position.x = stages.branch_x_at(active_branch, global_position.y) + support_offset
	on_support = branch_graph.has_support(stages, active_branch, global_position.y)
	if not on_support:
		_begin_falling_recovery()
		return
	support_state = SupportState.SUPPORTED
	if stun_remaining > 0.0:
		return
	var left_edge := Input.is_action_just_pressed("move_left")
	var right_edge := Input.is_action_just_pressed("move_right")
	var requested_direction := _pending_branch_direction
	_pending_branch_direction = 0
	if requested_direction == 0 and left_edge != right_edge:
		requested_direction = -1 if left_edge else 1
	if requested_direction == 0:
		return
	_begin_branch_transition(requested_direction)

func request_branch_direction(direction: int) -> bool:
	if (direction == -1 or direction == 1) and _pending_branch_direction == 0 and stages != null and stages.stage_for_y(global_position.y) >= 3 and movement_mode == MovementMode.ATTACHED:
		_pending_branch_direction = direction
		return true
	return false

func _begin_branch_transition(direction: int) -> bool:
	var target := active_branch + direction
	if target < 0 or target >= Balance.ROUTE_X.size():
		return false
	var stage := stages.stage_for_y(global_position.y)
	var progress := stages.progress_in_stage(global_position.y)
	if not branch_graph.can_transfer(stages, active_branch, target, global_position.y):
		return false
	transition_from = active_branch
	transition_to = target
	transition_progress = 0.0
	transition_base_y = global_position.y
	transfer_wind_offset = 0.0
	transfer_wind_velocity = 0.0
	movement_mode = MovementMode.TRANSITION
	support_state = SupportState.TRANSFERRING
	branch_transition_count += 1
	on_support = false
	return true

func _update_transition_visual(progress: float) -> void:
	if body == null:
		return
	var direction := signf(Balance.ROUTE_X[transition_to] - Balance.ROUTE_X[transition_from])
	if progress < 0.15:
		var anticipation := progress / 0.15
		body.position.y = 7.0 * sin(anticipation * PI)
		body.scale = Vector2(1.0 + 0.08 * anticipation, 1.0 - 0.10 * anticipation)
	elif progress < 0.85:
		# BranchGraph owns the airborne Y arc. Keep the body centered on that
		# path so the visual pose does not double the configured jump height.
		body.position.y = 0.0
		body.scale = Vector2.ONE
	else:
		var settle := (progress - 0.85) / 0.15
		body.position.y = 5.0 * sin(settle * PI)
		body.scale = Vector2(1.0 - 0.06 * (1.0 - settle), 1.0 + 0.08 * (1.0 - settle))
	body.rotation = direction * 0.18 * sin(progress * PI)

func _reset_visual_pose() -> void:
	if body != null:
		body.position = Vector2.ZERO
		body.rotation = 0.0
		body.scale = Vector2.ONE

func transition_state_name() -> String:
	if movement_mode == MovementMode.TRUNK:
		return "TRUNK"
	return "TRANSITION" if support_state == SupportState.TRANSFERRING else "ATTACHED"

func support_state_name() -> String:
	return SupportState.keys()[support_state]

func _begin_falling_recovery() -> void:
	movement_mode = MovementMode.ATTACHED
	support_state = SupportState.FALLING_RECOVERY
	on_support = false
	recovery_remaining = 0.35
	recovery_velocity_y = 120.0
	velocity = Vector2(0.0, recovery_velocity_y)

func _update_falling_recovery(delta: float) -> void:
	recovery_remaining = maxf(recovery_remaining - delta, 0.0)
	recovery_velocity_y += 600.0 * delta
	velocity = Vector2(0.0, recovery_velocity_y)
	global_position.y += recovery_velocity_y * delta
	var target := branch_graph.recovery_target(stages, active_branch, global_position)
	if not target.is_empty():
		active_branch = int(target.branch_id)
		global_position = target.point
		movement_mode = MovementMode.ATTACHED
		support_state = SupportState.SUPPORTED
		on_support = true
		velocity = Vector2.ZERO
		_reset_visual_pose()
		return
	if recovery_remaining <= 0.0:
		var game := get_parent()
		if game != null and game.has_method("_die"):
			game.call("_die", GameManager.DeathCause.FALL)

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO
	knockback_remaining = 0.0
	stun_remaining = 0.0
	bean_penalty_count = 0
	vertical_blocked = false
	time_wings_active = false
	fire_wings_active = false
	rock_penalty_count = 0
	knockback_speed = Balance.BEAN_KNOCKBACK_SPEED
	active_branch = stages.route_for_x(at_position.x) if stages != null else 1
	transition_from = active_branch
	transition_to = active_branch
	transition_progress = 0.0
	movement_mode = MovementMode.TRUNK if stages == null or stages.stage_for_y(at_position.y) <= 2 else MovementMode.ATTACHED
	branch_transition_count = 0
	_pending_branch_direction = 0
	on_support = true
	support_state = SupportState.SUPPORTED
	support_offset = 0.0
	support_offset_velocity = 0.0
	transfer_wind_offset = 0.0
	transfer_wind_velocity = 0.0
	recovery_remaining = 0.0
	recovery_velocity_y = 0.0
	transition_base_y = at_position.y
	_last_stage = stages.stage_for_y(at_position.y) if stages != null else 1
	_reset_visual_pose()

func apply_bean_hit() -> void:
	bean_penalty_count += 1
	if movement_mode == MovementMode.TRANSITION:
		_begin_falling_recovery()
	knockback_remaining = Balance.BEAN_KNOCKBACK_SECONDS
	stun_remaining = Balance.BEAN_STUN_SECONDS
	knockback_speed = Balance.BEAN_KNOCKBACK_SPEED

func apply_rock_hit(_hit_id: String) -> void:
	rock_penalty_count += 1
	if movement_mode == MovementMode.TRANSITION:
		_begin_falling_recovery()
	knockback_remaining = Balance.ROCK_KNOCKBACK_SECONDS
	stun_remaining = Balance.ROCK_STUN_SECONDS
	knockback_speed = Balance.ROCK_KNOCKBACK_SPEED

func climb_speed() -> float:
	return Balance.PLAYER_VERTICAL_SPEED * (Balance.FIRE_WINGS_SPEED_SCALE if fire_wings_active else 1.0)
