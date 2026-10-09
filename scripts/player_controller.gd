class_name PlayerController
extends CharacterBody2D

enum MovementMode { TRUNK, ATTACHED, TRANSITION }

var spawn_position := Vector2.ZERO
var knockback_remaining := 0.0
var stun_remaining := 0.0
var bean_penalty_count := 0
var vertical_blocked := false
var time_wings_active := false
var active_branch := 1
var transition_from := 1
var transition_to := 1
var transition_progress := 0.0
var movement_mode := MovementMode.TRUNK
var branch_transition_count := 0
var on_support := true
var _last_stage := 1
var _pending_branch_direction := 0
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager
@onready var body: Node2D = get_node_or_null("Body") as Node2D

func _ready() -> void:
	spawn_position = global_position
	_sync_stage_mode()

func _physics_process(delta: float) -> void:
	knockback_remaining = maxf(knockback_remaining - delta, 0.0)
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	_sync_stage_mode()
	if movement_mode == MovementMode.TRUNK:
		_update_trunk_movement(delta)
	else:
		_update_branch_movement(delta)
	vertical_blocked = not on_support
	if knockback_remaining > 0.0:
		velocity.y = Balance.BEAN_KNOCKBACK_SPEED
	elif stun_remaining > 0.0 or not on_support:
		velocity.y = 0.0
	else:
		velocity.y = -Balance.PLAYER_VERTICAL_SPEED
	move_and_slide()
	if movement_mode == MovementMode.TRUNK:
		global_position.x = clampf(global_position.x, -Balance.TRUNK_HALF_WIDTH, Balance.TRUNK_HALF_WIDTH)

func _sync_stage_mode() -> void:
	if stages == null:
		return
	var stage := stages.stage_for_y(global_position.y)
	if stage <= 2:
		if movement_mode != MovementMode.TRUNK:
			_reset_visual_pose()
		movement_mode = MovementMode.TRUNK
		active_branch = stages.route_for_x(global_position.x)
	elif _last_stage <= 2 or movement_mode == MovementMode.TRUNK:
		active_branch = stages.route_for_x(global_position.x)
		transition_from = active_branch
		transition_to = active_branch
		transition_progress = 0.0
		movement_mode = MovementMode.ATTACHED
		global_position.x = Balance.ROUTE_X[active_branch]
		_reset_visual_pose()
	_last_stage = stage

func _update_trunk_movement(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	if stun_remaining <= 0.0:
		velocity.x = move_toward(velocity.x, axis * Balance.PLAYER_HORIZONTAL_SPEED, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	active_branch = stages.route_for_x(global_position.x)
	on_support = stages.current_route_open(global_position.y, global_position.x)
	_reset_visual_pose()

func _update_branch_movement(delta: float) -> void:
	velocity.x = 0.0
	if movement_mode == MovementMode.TRANSITION:
		transition_progress = minf(transition_progress + delta / Balance.BRANCH_TRANSITION_SECONDS, 1.0)
		var eased := transition_progress * transition_progress * (3.0 - 2.0 * transition_progress)
		global_position.x = lerpf(Balance.ROUTE_X[transition_from], Balance.ROUTE_X[transition_to], eased)
		on_support = false
		_update_transition_visual(transition_progress)
		if transition_progress >= 1.0:
			active_branch = transition_to
			global_position.x = Balance.ROUTE_X[active_branch]
			movement_mode = MovementMode.ATTACHED
			on_support = stages.is_route_open_at(stages.stage_for_y(global_position.y), active_branch, stages.progress_in_stage(global_position.y))
			_reset_visual_pose()
		return
	global_position.x = Balance.ROUTE_X[active_branch]
	on_support = stages.is_route_open_at(stages.stage_for_y(global_position.y), active_branch, stages.progress_in_stage(global_position.y))
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

func request_branch_direction(direction: int) -> void:
	if (direction == -1 or direction == 1) and stages != null and stages.stage_for_y(global_position.y) >= 3 and movement_mode == MovementMode.ATTACHED:
		_pending_branch_direction = direction

func _begin_branch_transition(direction: int) -> bool:
	var target := active_branch + direction
	if target < 0 or target >= Balance.ROUTE_X.size():
		return false
	var stage := stages.stage_for_y(global_position.y)
	var progress := stages.progress_in_stage(global_position.y)
	if not stages.is_route_open_at(stage, target, progress):
		return false
	transition_from = active_branch
	transition_to = target
	transition_progress = 0.0
	movement_mode = MovementMode.TRANSITION
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
		var arc_t := (progress - 0.15) / 0.70
		body.position.y = -Balance.BRANCH_ARC_HEIGHT * sin(arc_t * PI)
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
	return MovementMode.keys()[movement_mode]

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO
	knockback_remaining = 0.0
	stun_remaining = 0.0
	bean_penalty_count = 0
	vertical_blocked = false
	time_wings_active = false
	active_branch = stages.route_for_x(at_position.x) if stages != null else 1
	transition_from = active_branch
	transition_to = active_branch
	transition_progress = 0.0
	movement_mode = MovementMode.TRUNK if stages == null or stages.stage_for_y(at_position.y) <= 2 else MovementMode.ATTACHED
	branch_transition_count = 0
	_pending_branch_direction = 0
	on_support = true
	_last_stage = stages.stage_for_y(at_position.y) if stages != null else 1
	_reset_visual_pose()

func apply_bean_hit() -> void:
	bean_penalty_count += 1
	knockback_remaining = Balance.BEAN_KNOCKBACK_SECONDS
	stun_remaining = Balance.BEAN_STUN_SECONDS
