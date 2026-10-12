class_name GoldCollectible
extends Node2D

signal collected(placement_id: String)

const COIN_TEXTURE := preload("res://assets/art/items/gold_coin.png")

var placement_id := ""
var player: PlayerController
var taken := false
var sparkle_remaining := 0.0
var sprite := Sprite2D.new()

func setup(id: String, target: PlayerController) -> void:
	placement_id = id
	player = target

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.texture = COIN_TEXTURE
	sprite.scale = Vector2.ONE * 0.82
	add_child(sprite)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not taken and player != null and global_position.distance_to(player.global_position) <= 38.0:
		taken = true
		sprite.visible = false
		sparkle_remaining = 0.28
		collected.emit(placement_id)
	if sparkle_remaining > 0.0:
		sparkle_remaining = maxf(sparkle_remaining - delta, 0.0)
		queue_redraw()
		if sparkle_remaining <= 0.0:
			queue_free()

func _process(_delta: float) -> void:
	if not taken:
		sprite.rotation = sin(Time.get_ticks_msec() * 0.004) * 0.08
		sprite.modulate.a = 0.92 + sin(Time.get_ticks_msec() * 0.008) * 0.08

func _draw() -> void:
	if sparkle_remaining <= 0.0:
		return
	var ratio := sparkle_remaining / 0.28
	var radius := lerpf(34.0, 14.0, ratio)
	var color := Color(1.0, 0.91, 0.38, ratio)
	for direction in 8:
		var angle := TAU * float(direction) / 8.0
		var inner := Vector2.from_angle(angle) * radius * 0.35
		var outer := Vector2.from_angle(angle) * radius
		draw_line(inner, outer, color, 2.0)
