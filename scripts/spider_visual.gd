extends Node2D

const FRAMES := [
	preload("res://assets/art/gpt/spider/climb_1.png"),
	preload("res://assets/art/gpt/spider/climb_2.png"),
	preload("res://assets/art/gpt/spider/climb_3.png"),
	preload("res://assets/art/gpt/spider/climb_4.png"),
	preload("res://assets/art/gpt/spider/attack.png"),
	preload("res://assets/art/gpt/spider/angry.png"),
	preload("res://assets/art/gpt/spider/stunned.png"),
	preload("res://assets/art/gpt/spider/idle.png"),
]

var sprite := Sprite2D.new()

func _ready() -> void:
	sprite.scale = Vector2(0.64, 0.64)
	sprite.position = Vector2(0, -8)
	add_child(sprite)

func _process(_delta: float) -> void:
	var spider := get_parent() as SpiderController
	if spider == null:
		return
	var frame := 7
	if spider.boost_remaining > 0.0:
		frame = 5
	elif spider.player != null and spider.player.time_wings_active:
		frame = 6
	elif spider.distance_to_player() <= Balance.GAUGE_MAX_DISTANCE * 0.20:
		frame = 4
	elif absf(spider.velocity.y) > 1.0:
		frame = int(Time.get_ticks_msec() / 140) % 4
	sprite.texture = FRAMES[frame]
