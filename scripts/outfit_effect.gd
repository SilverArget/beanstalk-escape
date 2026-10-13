class_name OutfitEffect
extends Node2D

var effect_name := ""
var elapsed := 0.0

func _init() -> void:
	var light_material := CanvasItemMaterial.new()
	light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light_material

func configure(item: Dictionary) -> void:
	effect_name = str(item.get("effect_name", ""))
	visible = not effect_name.is_empty()
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	match effect_name:
		"FALLING LEAVES":
			for index in 5:
				var phase := fmod(elapsed * 0.22 + index * 0.21, 1.0)
				var point := Vector2(sin(phase * TAU + index) * 28.0, -48.0 + phase * 96.0)
				_draw_leaf(point, 3.2, Color(0.50, 0.92, 0.22, 0.72))
		"PETAL DRIFT":
			for index in 6:
				var phase := fmod(elapsed * 0.18 + index * 0.17, 1.0)
				var point := Vector2(-30.0 + phase * 60.0, 42.0 - phase * 88.0 + sin(phase * TAU * 2.0) * 5.0)
				_draw_leaf(point, 2.8, Color(1.0, 0.42, 0.68, 0.76))
		"CLOUD PUFFS":
			for index in 5:
				var phase := fmod(elapsed * 0.16 + index * 0.23, 1.0)
				var point := Vector2(-31.0 + phase * 62.0, 20.0 - index * 10.0)
				draw_circle(point, 6.0 + phase * 3.0, Color(0.55, 0.84, 1.0, 0.08 * (1.0 - phase)))
				draw_circle(point, 3.5 + phase * 2.0, Color(0.92, 0.98, 1.0, 0.38 * (1.0 - phase)))
		"BUBBLE STREAM":
			for index in 7:
				var phase := fmod(elapsed * 0.26 + index * 0.15, 1.0)
				var point := Vector2(sin(index * 2.1 + elapsed) * 25.0, 45.0 - phase * 94.0)
				var radius := 2.2 + float(index % 3)
				draw_circle(point, radius + 2.0, Color(0.12, 0.75, 1.0, 0.08))
				draw_arc(point, radius, 0.0, TAU, 12, Color(0.58, 0.94, 1.0, 0.62 * (1.0 - phase)), 1.2, true)
		"SPARK ARCS":
			for index in 5:
				var side := -1.0 if index % 2 == 0 else 1.0
				var y := -31.0 + index * 15.0
				var start := Vector2(side * 20.0, y)
				var middle := start + Vector2(side * 8.0, 4.0)
				var finish := middle + Vector2(-side * 4.0, 7.0)
				var alpha := 0.25 + 0.65 * absf(sin(elapsed * 7.0 + index * 1.9))
				draw_line(start, middle, Color(1.0, 0.75, 0.06, alpha * 0.25), 4.0, true)
				draw_line(middle, finish, Color(1.0, 0.95, 0.42, alpha), 1.8, true)
		"EMBER SPARKS":
			for index in 8:
				var phase := fmod(elapsed * (0.22 + index * 0.008) + index * 0.13, 1.0)
				var point := Vector2(sin(index * 2.4 + phase * 3.0) * 28.0, 44.0 - phase * 92.0)
				draw_circle(point, 4.0, Color(1.0, 0.18, 0.02, 0.10 * (1.0 - phase)))
				draw_circle(point, 1.6, Color(1.0, 0.66, 0.12, 0.82 * (1.0 - phase)))
		"SNOW GLITTER":
			for index in 8:
				var phase := fmod(elapsed * 0.14 + index * 0.14, 1.0)
				var point := Vector2(sin(index * 2.0 + phase * TAU) * 31.0, -45.0 + phase * 90.0)
				var alpha := 0.75 * sin(phase * PI)
				draw_circle(point, 3.6, Color(0.42, 0.84, 1.0, alpha * 0.12))
				draw_line(point - Vector2(3.0, 0.0), point + Vector2(3.0, 0.0), Color(0.9, 0.98, 1.0, alpha), 1.2, true)
				draw_line(point - Vector2(0.0, 3.0), point + Vector2(0.0, 3.0), Color(0.9, 0.98, 1.0, alpha), 1.2, true)
		"SUN RAYS":
			var pulse := 0.9 + sin(elapsed * 2.4) * 0.08
			for layer in 3:
				draw_circle(Vector2.ZERO, (43.0 - layer * 6.0) * pulse, Color(1.0, 0.62, 0.08, 0.025 + layer * 0.012))
			for index in 8:
				var angle := elapsed * 0.32 + TAU * index / 8.0
				draw_line(Vector2.from_angle(angle) * 39.0, Vector2.from_angle(angle) * 55.0, Color(1.0, 0.76, 0.18, 0.30), 3.0, true)
		"STAR DUST":
			draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 24, Color(0.18, 0.72, 1.0, 0.16), 2.0, true)
			for index in 8:
				var angle := elapsed * (0.55 + float(index % 2) * 0.18) + TAU * index / 8.0
				var point := Vector2(cos(angle) * 35.0, sin(angle) * 43.0)
				var glint := 2.0 + 1.8 * absf(sin(elapsed * 3.5 + index))
				_draw_diamond(point, glint, Color(0.48, 0.92, 1.0, 0.82))

func _draw_leaf(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0.0, -radius), point + Vector2(radius * 0.75, 0.0),
		point + Vector2(0.0, radius), point + Vector2(-radius * 0.75, 0.0),
	]), color)

func _draw_diamond(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0.0, -radius), point + Vector2(radius, 0.0),
		point + Vector2(0.0, radius), point + Vector2(-radius, 0.0),
	]), color)
