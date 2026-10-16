class_name SpiderController
extends CharacterBody2D

var boost_remaining := 0.0
var boost_start_count := 0
var speed_ratio := Balance.SPIDER_SPEED_RATIO
var catchup_active := false
var catchup_blend := 0.0
var target_x := 0.0
var horizontal_motion_speed := 0.0
var _follow_start_x := 0.0
var _follow_elapsed := 0.0
var _follow_delay_remaining := 0.0
var _danger_tracking := false
var _gap_transition_elapsed := 0.0
var _gap_transition_seconds := 0.0
var _gap_transition_from := 0.0
var _gap_transition_to := 0.0
@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager
@onready var game: GameManager = get_parent() as GameManager
var nightmare_modifiers := StageDatabase.nightmare_modifiers()

func _physics_process(delta: float) -> void:
	advance_active_clocks(delta)
	if player != null and (_danger_tracking or _gap_transition_seconds > 0.0):
		_update_danger_gap(delta)
		return
	var gap := distance_to_player()
	var catchup := catchup_state(gap, catchup_active, catchup_blend, delta)
	catchup_active = bool(catchup.active)
	catchup_blend = float(catchup.blend)
	var stage_number := stages.stage_for_y(player.global_position.y) if stages != null and player != null else 1
	var speed := speed_for_state(gap, stage_number, catchup_blend, boost_remaining > 0.0, player != null and player.time_wings_active)
	if game != null and game.is_nightmare_mode():
		var profile := pressure_profile(stage_number)
		var pressure_c := clampf((gap - float(profile.g_lo)) / Balance.SPIDER_RAMP_SPAN, 0.0, 1.0)
		var time_scale := Balance.TIME_WINGS_SLOW_SCALE if player != null and player.time_wings_active else 1.0
		speed += float(profile.pressure) * pressure_c * (float(nightmare_modifiers.get("spider_pressure_scale", 1.0)) - 1.0) * time_scale
	speed_ratio = speed / Balance.PLAYER_VERTICAL_SPEED
	_update_horizontal_follow(delta, stage_number)
	velocity = Vector2(0.0, -speed)
	move_and_slide()

func reset_run(at_position: Vector2) -> void:
	_danger_tracking = false
	_gap_transition_seconds = 0.0
	var reset_x := player.global_position.x if player != null else at_position.x
	global_position = Vector2(reset_x, at_position.y)
	velocity = Vector2.ZERO
	boost_remaining = 0.0
	boost_start_count = 0
	speed_ratio = Balance.SPIDER_SPEED_RATIO
	catchup_active = false
	catchup_blend = 0.0
	target_x = reset_x
	horizontal_motion_speed = 0.0
	_follow_start_x = reset_x
	_follow_elapsed = 0.0
	_follow_delay_remaining = 0.0

func begin_danger(immediate := false) -> void:
	_danger_tracking = true
	_start_gap_transition(Balance.DANGER_GAP, Balance.DANGER_APPROACH_SECONDS)
	if immediate and player != null:
		global_position.y = player.global_position.y + Balance.DANGER_GAP
		_gap_transition_seconds = 0.0

func retreat_from_danger(normal_gap: float) -> void:
	_danger_tracking = false
	_start_gap_transition(normal_gap, Balance.DANGER_RETREAT_SECONDS)

func _start_gap_transition(target_gap: float, seconds: float) -> void:
	_gap_transition_from = maxf(distance_to_player(), Balance.DANGER_GAP)
	_gap_transition_to = target_gap
	_gap_transition_elapsed = 0.0
	_gap_transition_seconds = seconds

func _update_danger_gap(delta: float) -> void:
	var gap := Balance.DANGER_GAP
	if _gap_transition_seconds > 0.0:
		_gap_transition_elapsed = minf(_gap_transition_elapsed + delta, _gap_transition_seconds)
		var progress := _gap_transition_elapsed / _gap_transition_seconds
		gap = lerpf(_gap_transition_from, _gap_transition_to, smoothstep(0.0, 1.0, progress))
		if _gap_transition_elapsed >= _gap_transition_seconds:
			_gap_transition_seconds = 0.0
	var previous_y := global_position.y
	global_position.y = player.global_position.y + maxf(gap, Balance.DANGER_GAP)
	velocity = Vector2(0.0, (global_position.y - previous_y) / maxf(delta, 0.000001))
	speed_ratio = -velocity.y / Balance.PLAYER_VERTICAL_SPEED
	catchup_active = false
	catchup_blend = 0.0
	var stage_number := stages.stage_for_y(player.global_position.y) if stages != null else 1
	_update_horizontal_follow(delta, stage_number)

func _update_horizontal_follow(delta: float, stage_number: int) -> void:
	if player == null:
		horizontal_motion_speed = 0.0
		return
	var previous_x := global_position.x
	if stage_number <= 2:
		target_x = player.global_position.x
		global_position.x = move_toward(global_position.x, target_x, Balance.SPIDER_TRUNK_FOLLOW_SPEED * delta)
	else:
		var target_branch := player.transition_to if player.movement_mode == PlayerController.MovementMode.TRANSITION else player.active_branch
		var desired_x := float(Balance.ROUTE_X[clampi(target_branch, 0, Balance.ROUTE_X.size() - 1)])
		if not is_equal_approx(desired_x, target_x):
			target_x = desired_x
			_follow_start_x = global_position.x
			_follow_elapsed = 0.0
			_follow_delay_remaining = Balance.SPIDER_FOLLOW_DELAY_SECONDS
		if _follow_delay_remaining > 0.0:
			_follow_delay_remaining = maxf(_follow_delay_remaining - delta, 0.0)
		else:
			_follow_elapsed = minf(_follow_elapsed + delta, Balance.SPIDER_FOLLOW_SECONDS)
			var progress := _follow_elapsed / Balance.SPIDER_FOLLOW_SECONDS
			var eased := progress * progress * (3.0 - 2.0 * progress)
			global_position.x = lerpf(_follow_start_x, target_x, eased)
	horizontal_motion_speed = (global_position.x - previous_x) / maxf(delta, 0.000001)

func is_following_horizontal() -> bool:
	return absf(horizontal_motion_speed) > 0.5

func apply_bean_boost() -> void:
	boost_remaining = Balance.SPIDER_BOOST_SECONDS
	boost_start_count += 1

func advance_active_clocks(delta: float) -> void:
	boost_remaining = maxf(boost_remaining - delta, 0.0)

func distance_to_player() -> float:
	if player == null:
		return Balance.START_DISTANCE
	return maxf(global_position.y - player.global_position.y, 0.0)

static func speed_ratio_for_distance(distance_px: float) -> float:
	var c := clampf((distance_px - 180.0) / Balance.SPIDER_RAMP_SPAN, 0.0, 1.0)
	return Balance.SPIDER_SPEED_RATIO + 0.12 * c

static func pressure_profile(stage_number: int) -> Dictionary:
	for band: Dictionary in Balance.SPIDER_PRESSURE_BANDS:
		if stage_number >= int(band.from) and stage_number <= int(band.to):
			return {"g_lo": float(band.g_lo), "pressure": float(band.pressure)}
	return {"g_lo": 156.0, "pressure": 12.0}

static func retry_gap_for_stage(stage_number: int) -> float:
	return stage_start_gap(stage_number)

static func stage_start_gap(stage_number: int) -> float:
	if stage_number <= 1:
		return Balance.START_DISTANCE
	var profile := pressure_profile(stage_number)
	var equilibrium_c := clampf(
		(1.0 - Balance.SPIDER_SPEED_RATIO) * Balance.PLAYER_VERTICAL_SPEED
		/ (Balance.PLAYER_VERTICAL_SPEED * 0.12 + float(profile.pressure)),
		0.0,
		1.0
	)
	return float(profile.g_lo) + Balance.SPIDER_RAMP_SPAN * equilibrium_c

static func pressure_equilibrium_table() -> Array:
	var result: Array = []
	for band: Dictionary in Balance.SPIDER_PRESSURE_BANDS:
		var pressure := float(band.pressure)
		result.append(float(band.g_lo) + 108.0 * 12.0 / (12.0 + pressure))
	return result

static func simulate_bean_penalty_safety(stage_number: int) -> Dictionary:
	var profile := pressure_profile(stage_number)
	var gap := float(profile.g_lo) + 108.0 * 12.0 / (12.0 + float(profile.pressure))
	var minimum_gap := gap
	var boost_remaining := Balance.SPIDER_BOOST_SECONDS
	var penalty_ticks := int(round(Balance.BEAN_KNOCKBACK_SECONDS * 120.0))
	var total_ticks := penalty_ticks + 5 * 120
	var post_penalty_gap := gap
	for tick in total_ticks:
		var player_speed := -Balance.BEAN_KNOCKBACK_SPEED if tick < penalty_ticks else Balance.PLAYER_VERTICAL_SPEED
		var spider_speed := speed_for_state(gap, stage_number, 0.0, boost_remaining > 0.0, false)
		gap += (player_speed - spider_speed) / 120.0
		minimum_gap = minf(minimum_gap, gap)
		boost_remaining = maxf(boost_remaining - 1.0 / 120.0, 0.0)
		if tick == penalty_ticks - 1:
			post_penalty_gap = gap
	return {"minimum_gap": minimum_gap, "post_penalty_gap": post_penalty_gap, "final_gap": gap}

static func simulate_rock_penalty_safety(stage_number: int, profile_override := {}) -> Dictionary:
	var profile := profile_override if not profile_override.is_empty() else pressure_profile(stage_number)
	var pressure := float(profile.pressure)
	# Solve the actual runtime speed equation for the undamaged equilibrium.
	var equilibrium_c := clampf(
		(1.0 - Balance.SPIDER_SPEED_RATIO) * Balance.PLAYER_VERTICAL_SPEED
		/ (Balance.PLAYER_VERTICAL_SPEED * 0.12 + pressure),
		0.0,
		1.0
	)
	var gap := float(profile.g_lo) + Balance.SPIDER_RAMP_SPAN * equilibrium_c
	var start_gap := gap
	var minimum_gap := gap
	var penalty_ticks := int(round(Balance.ROCK_KNOCKBACK_SECONDS * 120.0))
	var total_ticks := penalty_ticks + 5 * 120
	var post_penalty_gap := gap
	for tick in total_ticks:
		var player_speed := -Balance.ROCK_KNOCKBACK_SPEED if tick < penalty_ticks else Balance.PLAYER_VERTICAL_SPEED
		var spider_speed := speed_for_state(gap, stage_number, 0.0, false, false)
		# Positive player_speed climbs; rock knockback is negative climb speed.
		gap += (player_speed - spider_speed) / 120.0
		minimum_gap = minf(minimum_gap, gap)
		if tick == penalty_ticks - 1:
			post_penalty_gap = gap
	return {"start_gap": start_gap, "minimum_gap": minimum_gap, "post_penalty_gap": post_penalty_gap, "final_gap": gap}

static func catchup_state(gap: float, active: bool, blend: float, delta: float) -> Dictionary:
	if not active and gap >= Balance.SPIDER_CATCHUP_ON_GAP:
		active = true
	elif active and gap <= Balance.SPIDER_CATCHUP_OFF_GAP:
		return {"active": false, "blend": 0.0}
	if active:
		blend = minf(blend + delta / Balance.SPIDER_CATCHUP_BLEND_SECONDS, 1.0)
	return {"active": active, "blend": blend if active else 0.0}

static func speed_for_state(gap: float, stage_number: int, blend: float, bean_boost: bool, time_active: bool) -> float:
	var profile := pressure_profile(stage_number)
	var c := clampf((gap - float(profile.g_lo)) / Balance.SPIDER_RAMP_SPAN, 0.0, 1.0)
	var normal_ratio := Balance.SPIDER_SPEED_RATIO + 0.12 * c
	var excess_ratio := clampf(blend, 0.0, 1.0) * clampf((gap - Balance.SPIDER_CATCHUP_ORIGIN) / Balance.SPIDER_CATCHUP_SPAN, 0.0, 3.0)
	var bean_factor := Balance.SPIDER_BOOST_RATIO if bean_boost else 1.0
	var time_factor := Balance.TIME_WINGS_SLOW_SCALE if time_active else 1.0
	return Balance.PLAYER_VERTICAL_SPEED * (normal_ratio + excess_ratio) * bean_factor * time_factor + float(profile.pressure) * c * time_factor
