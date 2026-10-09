extends Node2D

const POSES := {
	"climb1": preload("res://assets/art/player/female_climb1.png"),
	"climb2": preload("res://assets/art/player/female_climb2.png"),
	"hurt": preload("res://assets/art/player/female_hurt.png"),
	"fall": preload("res://assets/art/player/female_fall.png"),
	"cheer1": preload("res://assets/art/player/female_cheer1.png"),
	"cheer2": preload("res://assets/art/player/female_cheer2.png"),
	"idle": preload("res://assets/art/player/female_idle.png"),
	"jump": preload("res://assets/art/player/female_jump.png"),
	"hang": preload("res://assets/art/player/female_hang.png"),
}
const WING_LEFT := preload("res://assets/art/wings/wing_left.png")
const WING_RIGHT := preload("res://assets/art/wings/wing_right.png")

var sprite := Sprite2D.new()
var left_wing := Sprite2D.new()
var right_wing := Sprite2D.new()
var flash_remaining := 0.0
var last_penalty := 0

func _ready() -> void:
	left_wing.texture = WING_LEFT
	right_wing.texture = WING_RIGHT
	left_wing.position = Vector2(-18, 0)
	right_wing.position = Vector2(18, 0)
	left_wing.modulate = Palette.SKILL_TIME
	right_wing.modulate = Palette.SKILL_TIME
	left_wing.scale = Vector2(0.28, 0.28)
	right_wing.scale = Vector2(0.28, 0.28)
	add_child(left_wing)
	add_child(right_wing)
	# 87-88 px opaque source height -> 63 px at the 960x540 reference viewport.
	sprite.scale = Vector2(0.72, 0.72)
	sprite.position = Vector2(0, -3)
	add_child(sprite)
	_update_pose()

func _process(delta: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	if player.bean_penalty_count != last_penalty:
		last_penalty = player.bean_penalty_count
		flash_remaining = 0.16
	flash_remaining = maxf(flash_remaining - delta, 0.0)
	sprite.modulate = Palette.WHITE_FLASH if flash_remaining > 0.0 else Palette.WHITE_FLASH
	var wings_on := player.time_wings_active
	left_wing.visible = wings_on
	right_wing.visible = wings_on
	if wings_on:
		var flap := 0.85 + sin(Time.get_ticks_msec() * 0.018) * 0.15
		left_wing.rotation = -0.35 * flap
		right_wing.rotation = 0.35 * flap
	_update_pose()

func _update_pose() -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var game := player.get_parent() as GameManager
	var pose := "climb1"
	if game != null and game.app_state == GameManager.AppState.PLAYER_DEAD:
		pose = "fall"
	elif game != null and game.app_state == GameManager.AppState.GAME_COMPLETE:
		pose = "cheer1" if int(Time.get_ticks_msec() / 260) % 2 == 0 else "cheer2"
	elif player.knockback_remaining > 0.0:
		pose = "hurt"
	elif player.movement_mode == PlayerController.MovementMode.TRANSITION:
		pose = "jump" if player.transition_progress < 0.62 else "hang"
	elif absf(player.velocity.y) < 1.0:
		pose = "hang"
	else:
		pose = "climb1" if int(Time.get_ticks_msec() / 190) % 2 == 0 else "climb2"
	sprite.texture = POSES[pose]
