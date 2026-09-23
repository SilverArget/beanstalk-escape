extends Node2D

func _draw() -> void:
	draw_rect(Rect2(-480, -5000, 960, 10000), Color("91cae8"), true)
	draw_line(Vector2(0, 800), Vector2(0, -900), Color("397447"), 72.0, true)
	for x: float in Balance.ROUTE_X:
		draw_line(Vector2(0, -420), Vector2(x, -1100), Color("4e9556"), 34.0, true)
		draw_line(Vector2(x, -1100), Vector2(x, -5000), Color("4e9556"), 34.0, true)

