extends Node2D

const BODY_COLOR := Color("31a7a0")
const SKIN_COLOR := Color("f0b58d")
const HAIR_COLOR := Color("9f3348")
const BOOT_COLOR := Color("243747")
const OUTLINE := Color("152238")
const WING_COLOR := Color("a979dc")

var flash_remaining := 0.0
var last_penalty := 0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	if player.bean_penalty_count != last_penalty:
		last_penalty = player.bean_penalty_count
		flash_remaining = 0.16
	flash_remaining = maxf(flash_remaining - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var tint := Color.WHITE if flash_remaining <= 0.0 else Color("fff0b5")
	var climb_phase := sin(Time.get_ticks_msec() * 0.012) * 4.0
	if player.support_state == PlayerController.SupportState.TRANSFERRING:
		climb_phase = 6.0 * sin(player.transition_progress * PI)
	if player.time_wings_active:
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -30), Vector2(-22, -12), Vector2(-18, 12), Vector2(-5, 4)]), WING_COLOR)
		draw_colored_polygon(PackedVector2Array([Vector2(8, -30), Vector2(22, -12), Vector2(18, 12), Vector2(5, 4)]), WING_COLOR)
	# Gate 1 production greybox bounds are exactly 44 x 108 world units.
	draw_rect(Rect2(-22, -54, 44, 108), OUTLINE)
	draw_circle(Vector2(0, -38), 13.0, SKIN_COLOR * tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-13, -43), Vector2(0, -54), Vector2(13, -43), Vector2(10, -32), Vector2(-10, -32)]), HAIR_COLOR * tint)
	draw_rect(Rect2(-14, -25, 28, 49), BODY_COLOR * tint)
	draw_line(Vector2(-12, -18), Vector2(-22, -4 + climb_phase), SKIN_COLOR * tint, 7.0)
	draw_line(Vector2(12, -18), Vector2(22, -4 - climb_phase), SKIN_COLOR * tint, 7.0)
	draw_line(Vector2(-7, 22), Vector2(-12, 48 - climb_phase), BOOT_COLOR * tint, 8.0)
	draw_line(Vector2(7, 22), Vector2(12, 48 + climb_phase), BOOT_COLOR * tint, 8.0)
	draw_rect(Rect2(-20.5, -52.5, 41, 105), OUTLINE, false, ScaleLock.OUTLINE_WIDTH)
