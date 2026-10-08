class_name SpiderController
extends CharacterBody2D

var boost_remaining := 0.0
var boost_start_count := 0
var speed_ratio := Balance.SPIDER_SPEED_RATIO
@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController

func _physics_process(delta: float) -> void:
	boost_remaining = maxf(boost_remaining - delta, 0.0)
	speed_ratio = Balance.SPIDER_BOOST_RATIO if boost_remaining > 0.0 else speed_ratio_for_distance(distance_to_player())
	velocity = Vector2(0.0, -Balance.PLAYER_VERTICAL_SPEED * speed_ratio)
	move_and_slide()

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO
	boost_remaining = 0.0
	boost_start_count = 0
	speed_ratio = Balance.SPIDER_SPEED_RATIO

func apply_bean_boost() -> void:
	boost_remaining = Balance.SPIDER_BOOST_SECONDS
	boost_start_count += 1

func distance_to_player() -> float:
	if player == null:
		return Balance.START_DISTANCE
	return maxf(global_position.y - player.global_position.y, 0.0)

static func speed_ratio_for_distance(distance_px: float) -> float:
	if distance_px <= Balance.START_DISTANCE:
		return Balance.SPIDER_SPEED_RATIO
	var span := maxf(Balance.SPIDER_RAMP_FULL_DISTANCE - Balance.START_DISTANCE, 0.001)
	var t := clampf((distance_px - Balance.START_DISTANCE) / span, 0.0, 1.0)
	return lerpf(Balance.SPIDER_SPEED_RATIO, 1.0, t)
