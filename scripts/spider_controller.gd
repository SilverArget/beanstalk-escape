class_name SpiderController
extends CharacterBody2D

var boost_remaining := 0.0
var boost_start_count := 0
var speed_ratio := Balance.SPIDER_SPEED_RATIO

func _physics_process(delta: float) -> void:
	boost_remaining = maxf(boost_remaining - delta, 0.0)
	speed_ratio = Balance.SPIDER_BOOST_RATIO if boost_remaining > 0.0 else Balance.SPIDER_SPEED_RATIO
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
