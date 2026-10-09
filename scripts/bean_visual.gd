extends Node2D

const BEAN_FRAMES := [
	preload("res://assets/art/gpt/items/bean_0.png"),
	preload("res://assets/art/gpt/items/bean_45.png"),
	preload("res://assets/art/gpt/items/bean_90.png"),
	preload("res://assets/art/gpt/items/bean_burst.png"),
]
const WARNING_BADGE := preload("res://assets/art/gpt/items/warning_badge.png")
const LANDING_SHADOW := preload("res://assets/art/gpt/items/landing_shadow.png")
const WARNING_ARROW := preload("res://assets/art/gpt/items/warning_arrow.png")

@export var warning := false
var burst := false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if warning:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.14
		_draw_centered(LANDING_SHADOW, Vector2(0, 8), Vector2(0.20, 0.20) * pulse)
		_draw_centered(WARNING_BADGE, Vector2(0, -35), Vector2(0.19, 0.19) * pulse)
		_draw_centered(WARNING_ARROW, Vector2(0, -70), Vector2(0.16, 0.16) * pulse)
	else:
		var frame := 3 if burst else int(Time.get_ticks_msec() / 90) % 3
		var scale_value := 0.26 if burst else 0.22
		_draw_centered(BEAN_FRAMES[frame], Vector2.ZERO, Vector2(scale_value, scale_value))

func show_burst() -> void:
	burst = true
	visible = true
	queue_redraw()

func _draw_centered(texture: Texture2D, position: Vector2, scale_value: Vector2) -> void:
	draw_set_transform(position, 0.0, scale_value)
	draw_texture(texture, -texture.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
