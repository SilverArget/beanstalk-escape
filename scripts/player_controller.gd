class_name PlayerController
extends CharacterBody2D

var spawn_position := Vector2.ZERO

func _ready() -> void:
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, axis * Balance.PLAYER_HORIZONTAL_SPEED, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	velocity.y = -Balance.PLAYER_VERTICAL_SPEED
	move_and_slide()
	global_position.x = clampf(global_position.x, Balance.ROUTE_X[0], Balance.ROUTE_X[2])

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO

