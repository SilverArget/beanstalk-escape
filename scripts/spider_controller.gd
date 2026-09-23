class_name SpiderController
extends CharacterBody2D

func _physics_process(_delta: float) -> void:
	velocity = Vector2(0.0, -Balance.PLAYER_VERTICAL_SPEED * Balance.SPIDER_SPEED_RATIO)
	move_and_slide()

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO

