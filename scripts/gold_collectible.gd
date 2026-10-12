class_name GoldCollectible
extends Node2D

signal collected(placement_id: String)

const COIN_TEXTURE := preload("res://assets/art/items/gold_coin.png")
const FEEDBACK_FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const FEEDBACK_DURATION := 0.55
const FEEDBACK_COLOR := Color("fff0a2")
const FEEDBACK_TEXT_COLOR := Color("ffe36b")
const FEEDBACK_OUTLINE_COLOR := Color("142b39")

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
		sparkle_remaining = FEEDBACK_DURATION
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
	var progress := 1.0 - sparkle_remaining / FEEDBACK_DURATION
	var alpha := minf(1.0, sparkle_remaining / 0.16)
	var color := Color(FEEDBACK_COLOR, alpha)
	var radius := 10.0 + progress * 18.0
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, 3.0, true)
	for direction in 8:
		var angle := TAU * float(direction) / 8.0 + progress * 0.45
		var inner := Vector2.from_angle(angle) * (15.0 + progress * 5.0)
		var outer := Vector2.from_angle(angle) * (24.0 + progress * 12.0)
		draw_line(inner, outer, color, 3.0, true)
	var text := "+1"
	var font_size := 20
	var text_width := FEEDBACK_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var text_y := -18.0 - progress * 28.0
	var baseline_y := text_y + (FEEDBACK_FONT.get_ascent(font_size) - FEEDBACK_FONT.get_descent(font_size)) * 0.5
	var text_position := Vector2(-text_width * 0.5, baseline_y)
	draw_string_outline(FEEDBACK_FONT, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 4, Color(FEEDBACK_OUTLINE_COLOR, alpha))
	draw_string(FEEDBACK_FONT, text_position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(FEEDBACK_TEXT_COLOR, alpha))

func feedback_snapshot() -> Dictionary:
	return {"t": sparkle_remaining, "duration": FEEDBACK_DURATION}
