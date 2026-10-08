class_name PlayerController
extends CharacterBody2D

var spawn_position := Vector2.ZERO
var knockback_remaining := 0.0
var stun_remaining := 0.0
var bean_penalty_count := 0
var vertical_blocked := false
var time_wings_active := false
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

func _ready() -> void:
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	knockback_remaining = maxf(knockback_remaining - delta, 0.0)
	stun_remaining = maxf(stun_remaining - delta, 0.0)
	if stun_remaining <= 0.0:
		velocity.x = move_toward(velocity.x, axis * Balance.PLAYER_HORIZONTAL_SPEED, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, Balance.PLAYER_HORIZONTAL_ACCELERATION * delta)
	vertical_blocked = stages != null and not stages.current_route_open(global_position.y, global_position.x)
	if knockback_remaining > 0.0:
		velocity.y = Balance.BEAN_KNOCKBACK_SPEED
	elif stun_remaining > 0.0 or vertical_blocked:
		velocity.y = 0.0
	else:
		velocity.y = -Balance.PLAYER_VERTICAL_SPEED
	move_and_slide()
	global_position.x = clampf(global_position.x, Balance.ROUTE_X[0], Balance.ROUTE_X[2])

func reset_run(at_position: Vector2) -> void:
	global_position = at_position
	velocity = Vector2.ZERO
	knockback_remaining = 0.0
	stun_remaining = 0.0
	bean_penalty_count = 0
	vertical_blocked = false
	time_wings_active = false

func apply_bean_hit() -> void:
	bean_penalty_count += 1
	knockback_remaining = Balance.BEAN_KNOCKBACK_SECONDS
	stun_remaining = Balance.BEAN_STUN_SECONDS
