class_name ScaleGreybox
extends Node2D

enum View { STAGE_1, STAGE_3 }

var view := View.STAGE_1

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("8fcce5"), true)
	if view == View.STAGE_1:
		_draw_stage_1()
	else:
		_draw_stage_3()
	_draw_header()

func _draw_stage_1() -> void:
	var trunk := Rect2(480.0 - ScaleLock.TRUNK_WIDTH * 0.5, 0, ScaleLock.TRUNK_WIDTH, 540)
	_box(trunk, Color("4c9a4d"))
	for y in range(24, 540, 54):
		draw_line(Vector2(trunk.position.x + 8, y), Vector2(trunk.end.x - 8, y), Color("276346"), ScaleLock.OUTLINE_WIDTH)
	_draw_character(Vector2(480, ScaleLock.CHARACTER_REFERENCE_Y))
	_label(Vector2(24, 76), "STAGE 1 GREYBOX")
	_label(Vector2(24, 104), "trunk 180 | char 44 x 108 | zoom 1.0")
	_label(Vector2(24, 132), "edge inset 68 | seam count 0")

func _draw_stage_3() -> void:
	for center_x in [330.0, 480.0, 630.0]:
		_box(Rect2(center_x - ScaleLock.BRANCH_WIDTH * 0.5, 0, ScaleLock.BRANCH_WIDTH, 540), Color("4c9a4d"))
	_draw_character(Vector2(480, ScaleLock.CHARACTER_REFERENCE_Y))
	_box(Rect2(316, 118, 28, 28), Color("9ddc57"))
	_box(Rect2(606, 138, 48, 48), Color("665e50"))
	_box(Rect2(256, 214, 120, 72), Color("72b84d"))
	_box(Rect2(474, 382, 12, 12), Color("d8f0aa"))
	_label(Vector2(24, 76), "STAGE 3 GREYBOX")
	_label(Vector2(24, 104), "branches 44 | centers 150 | leaf 120")
	_label(Vector2(24, 132), "bean 28 | rock 48 | grip 12 | outline 3")
	_label(Vector2(390, 188), "CHANGE BRANCH", 20)

func _draw_character(anchor: Vector2) -> void:
	var rect := Rect2(anchor.x - ScaleLock.CHARACTER_WIDTH * 0.5, anchor.y - 88, ScaleLock.CHARACTER_WIDTH, ScaleLock.CHARACTER_HEIGHT)
	_box(rect, Color("2f817d"))
	var collider := Rect2(anchor.x - ScaleLock.COLLIDER_WIDTH * 0.5, rect.position.y + 11, ScaleLock.COLLIDER_WIDTH, ScaleLock.COLLIDER_HEIGHT)
	draw_rect(collider, Color(1, 1, 1, 0.18), true)
	draw_rect(collider, Color("fff2dc"), false, 1.0)
	draw_line(Vector2(anchor.x - 26, anchor.y), Vector2(anchor.x + 26, anchor.y), Color("ffbb4a"), 2.0)

func _draw_header() -> void:
	draw_rect(Rect2(0, 0, 960, 48), Color("172b24"), true)
	_label(Vector2(20, 31), "BEANSTALK ESCAPE  §5.1 SCALE LOCK  960 x 540", 22)

func _box(rect: Rect2, fill: Color) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, Color("173d2f"), false, ScaleLock.OUTLINE_WIDTH)

func _label(position: Vector2, text: String, size := 18) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("fff2dc"))
