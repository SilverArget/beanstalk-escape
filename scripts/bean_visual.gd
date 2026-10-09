extends Node2D

@export var warning := false

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if warning:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.14
		_draw_warning_ellipse(Vector2.ZERO, Vector2(34, 10) * pulse, Palette.UI_SHADOW)
		draw_circle(Vector2(0, -28), 15.0, Palette.ACCENT_PROGRESS)
		draw_string(ThemeDB.fallback_font, Vector2(-4, -22), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.SPIDER_BODY)
	else:
		draw_set_transform(Vector2.ZERO, -0.35, Vector2.ONE)
		draw_circle(Vector2(-5, 0), 18.0, Palette.HAZARD_BEAN)
		draw_circle(Vector2(8, 5), 15.0, Palette.HAZARD_BEAN)
		draw_arc(Vector2(1, 1), 12.0, -2.1, 0.9, 16, Palette.HAZARD_BEAN_LIGHT, 4.0, true)

func _draw_warning_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
