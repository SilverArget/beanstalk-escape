extends Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var phase := Time.get_ticks_msec() * 0.006
	for side in [-1.0, 1.0]:
		for index in 4:
			var root := Vector2(side * (12.0 + index * 2.2), -8.0 + index * 5.0)
			var step := sin(phase + index * 1.3 + (0.7 if side > 0.0 else 0.0))
			var knee := Vector2(side * (31.0 + index * 5.0), root.y - 16.0 + index * 8.0)
			var foot := Vector2(side * (48.0 + index * 8.0), 18.0 + index * 5.0 + step * 7.0)
			draw_polyline(PackedVector2Array([root, knee, foot]), Palette.SPIDER_BODY, 7.0, true)
			draw_circle(foot, 4.0, Palette.DANGER_GLOW)
	draw_circle(Vector2(0, 6), 25.0, Palette.SPIDER_BODY)
	draw_circle(Vector2(0, -18), 18.0, Palette.SPIDER_BODY)
	draw_arc(Vector2(0, 6), 13.0, -2.4, -0.7, 12, Palette.DANGER_GLOW, 5.0, true)
	for eye_x in [-7.0, 7.0]:
		draw_circle(Vector2(eye_x, -21), 5.5, Palette.DANGER_SPIDER)
		draw_circle(Vector2(eye_x, -22), 2.2, Palette.WHITE_FLASH)
