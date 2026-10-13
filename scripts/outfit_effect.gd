class_name OutfitEffect
extends Node2D

var effect_name := ""
var elapsed := 0.0
var background_layer := false
var body_size := Vector2(80.0, 120.0)

func _init() -> void:
	var light_material := CanvasItemMaterial.new()
	light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light_material

func configure(item: Dictionary, draw_behind := false) -> void:
	effect_name = str(item.get("effect_name", ""))
	background_layer = draw_behind
	visible = not effect_name.is_empty() and (not background_layer or effect_name == "SUN RAYS")
	queue_redraw()

func set_body_box(size: Vector2) -> void:
	body_size = Vector2(maxf(size.x, 24.0), maxf(size.y, 48.0))
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	var half_width := body_size.x * 0.65
	var half_height := body_size.y * 0.5
	if background_layer:
		if effect_name == "SUN RAYS":
			var pulse := 0.96 + sin(elapsed * 2.4) * 0.05
			var aura_radius := maxf(body_size.x * 0.72, body_size.y * 0.34)
			for layer in 3:
				draw_circle(Vector2.ZERO, (aura_radius - layer * 7.0) * pulse, Color(1.0, 0.62, 0.08, 0.03 + layer * 0.014))
			for index in 8:
				var angle := elapsed * 0.32 + TAU * index / 8.0
				var direction := Vector2.from_angle(angle)
				draw_line(direction * aura_radius * 0.78, direction * aura_radius * 1.28, Color(1.0, 0.76, 0.18, 0.38), 3.5, true)
		return
	match effect_name:
		"FALLING LEAVES":
			for index in 5:
				var phase := fmod(elapsed * 0.22 + index * 0.21, 1.0)
				var point := Vector2(sin(phase * TAU + index) * half_width, -half_height + phase * body_size.y)
				_draw_leaf(point, 4.2, Color(0.50, 0.92, 0.22, 0.82))
		"PETAL DRIFT":
			for index in 6:
				var phase := fmod(elapsed * 0.18 + index * 0.17, 1.0)
				var point := Vector2(-half_width + phase * half_width * 2.0, half_height - phase * body_size.y + sin(phase * TAU * 2.0) * 6.0)
				_draw_leaf(point, 4.0, Color(1.0, 0.42, 0.68, 0.84))
		"CLOUD PUFFS":
			for index in 5:
				var phase := fmod(elapsed * 0.16 + index * 0.23, 1.0)
				var point := Vector2(-half_width + phase * half_width * 2.0, half_height * 0.55 - index * body_size.y * 0.14)
				draw_circle(point, 7.0 + phase * 3.0, Color(0.55, 0.84, 1.0, 0.12 * (1.0 - phase)))
				draw_circle(point, 4.5 + phase * 2.0, Color(0.92, 0.98, 1.0, 0.52 * (1.0 - phase)))
		"BUBBLE STREAM":
			for index in 7:
				var phase := fmod(elapsed * 0.26 + index * 0.15, 1.0)
				var point := Vector2(sin(index * 2.1 + elapsed) * half_width, half_height - phase * body_size.y)
				var radius := 3.2 + float(index % 3)
				draw_circle(point, radius + 2.0, Color(0.12, 0.75, 1.0, 0.08))
				draw_arc(point, radius, 0.0, TAU, 12, Color(0.58, 0.94, 1.0, 0.62 * (1.0 - phase)), 1.2, true)
		"SPARK ARCS":
			for index in 5:
				var side := -1.0 if index % 2 == 0 else 1.0
				var y := -half_height * 0.65 + index * body_size.y * 0.16
				var start := Vector2(side * body_size.x * 0.48, y)
				var middle := start + Vector2(side * 8.0, 4.0)
				var finish := middle + Vector2(-side * 4.0, 7.0)
				var alpha := 0.25 + 0.65 * absf(sin(elapsed * 7.0 + index * 1.9))
				draw_line(start, middle, Color(1.0, 0.75, 0.06, alpha * 0.25), 4.0, true)
				draw_line(middle, finish, Color(1.0, 0.95, 0.42, alpha), 1.8, true)
		"EMBER SPARKS":
			for index in 8:
				var phase := fmod(elapsed * (0.22 + index * 0.008) + index * 0.13, 1.0)
				var point := Vector2(sin(index * 2.4 + phase * 3.0) * half_width, half_height - phase * body_size.y)
				draw_circle(point, 4.0, Color(1.0, 0.18, 0.02, 0.10 * (1.0 - phase)))
				draw_circle(point, 1.6, Color(1.0, 0.66, 0.12, 0.82 * (1.0 - phase)))
		"SNOW GLITTER":
			for index in 8:
				var phase := fmod(elapsed * 0.14 + index * 0.14, 1.0)
				var point := Vector2(sin(index * 2.0 + phase * TAU) * half_width, -half_height + phase * body_size.y)
				var alpha := 0.75 * sin(phase * PI)
				draw_circle(point, 3.6, Color(0.42, 0.84, 1.0, alpha * 0.12))
				draw_line(point - Vector2(3.0, 0.0), point + Vector2(3.0, 0.0), Color(0.9, 0.98, 1.0, alpha), 1.2, true)
				draw_line(point - Vector2(0.0, 3.0), point + Vector2(0.0, 3.0), Color(0.9, 0.98, 1.0, alpha), 1.2, true)
		"SUN RAYS":
			pass
		"STAR DUST":
			draw_arc(Vector2.ZERO, half_width, 0.0, TAU, 24, Color(0.18, 0.72, 1.0, 0.24), 2.0, true)
			for index in 8:
				var angle := elapsed * (0.55 + float(index % 2) * 0.18) + TAU * index / 8.0
				var point := Vector2(cos(angle) * half_width, sin(angle) * half_height)
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
