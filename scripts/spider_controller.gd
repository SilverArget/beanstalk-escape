class_name SpiderController
extends CharacterBody2D

var boost_remaining := 0.0
var boost_start_count := 0
var speed_ratio := Balance.SPIDER_SPEED_RATIO
var catchup_active := false
var catchup_blend := 0.0
@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

func _physics_process(delta: float) -> void:
	advance_active_clocks(delta)
	var gap := distance_to_player()
	var catchup := catchup_state(gap, catchup_active, catchup_blend, delta)
	catchup_active = bool(catchup.active)
	catchup_blend = float(catchup.blend)
	var stage_number := stages.stage_for_y(player.global_position.y) if stages != null and player != null else 1
	var speed := speed_for_state(gap, stage_number, catchup_blend, boost_remaining > 0.0, player != null and player.time_wings_active)
	speed_ratio = speed / Balance.PLAYER_VERTICAL_SPEED
	velocity = Vector2(0.0, -speed)
	move_and_slide()

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO
	boost_remaining = 0.0
	boost_start_count = 0
	speed_ratio = Balance.SPIDER_SPEED_RATIO
	catchup_active = false
	catchup_blend = 0.0

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
	return 240.0 if stage_number <= 24 else 180.0

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
