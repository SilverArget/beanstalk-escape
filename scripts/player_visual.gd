extends Node2D

const POSES := {
	"climb_right": preload("res://assets/art/gpt/player/climb_right.png"),
	"climb_alt": preload("res://assets/art/gpt/player/climb_alt.png"),
	"jump": preload("res://assets/art/gpt/player/jump.png"),
	"climb_left": preload("res://assets/art/gpt/player/climb_left.png"),
	"hurt": preload("res://assets/art/gpt/player/hurt.png"),
	"fall": preload("res://assets/art/gpt/player/fall.png"),
	"cheer": preload("res://assets/art/gpt/player/cheer.png"),
	"idle": preload("res://assets/art/gpt/player/idle.png"),
}
const CLIMB_SEQUENCE := ["climb_right", "climb_alt", "climb_left", "climb_alt"]
const WING_OPEN := preload("res://assets/art/gpt/items/wing_open.png")

var sprite := Sprite2D.new()
var wings := Sprite2D.new()
var flash_remaining := 0.0
var last_penalty := 0

func _ready() -> void:
	wings.texture = WING_OPEN
	wings.position = Vector2(0, -3)
	wings.scale = Vector2(0.18, 0.18)
	wings.z_index = -1
	add_child(wings)
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
	wings.visible = player.time_wings_active
	if wings.visible:
		var breathe := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.035
		wings.scale = Vector2(0.18, 0.18) * breathe
	_update_pose()

func _update_pose() -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var game := player.get_parent() as GameManager
	var pose := "climb_right"
	if game != null and game.app_state == GameManager.AppState.PLAYER_DEAD:
		pose = "fall"
	elif game != null and game.app_state == GameManager.AppState.GAME_COMPLETE:
		pose = "cheer"
	elif game != null and game.app_state != GameManager.AppState.PLAYING:
		pose = "idle"
	elif player.knockback_remaining > 0.0:
		pose = "hurt"
	elif player.movement_mode == PlayerController.MovementMode.TRANSITION:
		pose = "jump"
	elif absf(player.velocity.y) < 1.0:
		pose = "idle"
	else:
		pose = CLIMB_SEQUENCE[int(Time.get_ticks_msec() / 150) % CLIMB_SEQUENCE.size()]
	sprite.texture = POSES[pose]
