class_name OutfitEffect
extends Node2D

const PARTICLE_COUNT := 10
const GAME_PARTICLE_COUNT := 7
const BASE_BODY_SIZE := Vector2(80.0, 120.0)
const OUTLINE_COLOR := Color(0.035, 0.075, 0.055, 0.68)
const CORE_COLOR := Color(1.0, 1.0, 0.92, 0.98)

var effect_name := ""
var elapsed := 0.0
var background_layer := false
var body_size := BASE_BODY_SIZE
var _preview_mode := false


func _init() -> void:
	# Default MIX blending; no per-instance material so the canvas batches stay merged.
	material = null


func configure(item: Dictionary, draw_behind := false) -> void:
	effect_name = str(item.get("effect_name", ""))
	background_layer = draw_behind
	visible = not effect_name.is_empty() and (not background_layer or effect_name == "SUN RAYS")
	queue_redraw()


func set_body_box(size: Vector2) -> void:
	body_size = Vector2(maxf(size.x, 24.0), maxf(size.y, 48.0))
	queue_redraw()


func set_preview_mode(enabled: bool) -> void:
	if _preview_mode == enabled:
		return
	_preview_mode = enabled
	queue_redraw()


func render_profile() -> Dictionary:
	return {
		"particle_count": _particle_count(),
		"layers_per_particle": 4 if _preview_mode else 2,
		"max_draw_calls": PARTICLE_COUNT * 4 if _preview_mode else GAME_PARTICLE_COUNT * 2,
		"preview": _preview_mode,
	}


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	var scale_factor := _effect_scale()
	var side_x := body_size.x * 0.56 + 4.0 * scale_factor
	var edge_y := body_size.y * 0.52 + 4.0 * scale_factor
	if background_layer:
		_draw_sun_rays_back(scale_factor, side_x, edge_y)
		return

	match effect_name:
		"FALLING LEAVES":
			for index in _particle_count():
				var phase := fmod(elapsed * 0.22 + float(index) / _particle_count(), 1.0)
				var side := -1.0 if index % 2 == 0 else 1.0
				var point := Vector2(side * (side_x + sin(phase * TAU + index) * 5.0 * scale_factor), lerpf(-edge_y, edge_y, phase))
				_draw_leaf(point, 5.1 * scale_factor, phase * TAU + index, Color(0.62, 0.96, 0.25, 0.96))
		"PETAL DRIFT":
			for index in _particle_count():
				var phase := fmod(elapsed * 0.17 + float(index) / _particle_count(), 1.0)
				var side := -1.0 if index % 2 == 0 else 1.0
				var point := Vector2(side * (side_x + cos(phase * TAU * 2.0 + index) * 4.0 * scale_factor), lerpf(edge_y, -edge_y, phase))
				_draw_petal(point, 5.2 * scale_factor, -phase * TAU + index * 0.7, Color(1.0, 0.48, 0.76, 0.96))
		"CLOUD PUFFS":
			for index in _particle_count():
				var phase := fmod(elapsed * 0.13 + float(index) / _particle_count(), 1.0)
				var side := -1.0 if index % 2 == 0 else 1.0
				var point := Vector2(side * (side_x + sin(elapsed * 0.9 + index) * 4.0 * scale_factor), lerpf(edge_y, -edge_y, phase))
				_draw_cloud(point, 5.5 * scale_factor, sin(elapsed + index) * 0.08, Color(0.70, 0.91, 1.0, 0.96))
		"BUBBLE STREAM":
			for index in _particle_count():
				var phase := fmod(elapsed * 0.21 + float(index) / _particle_count(), 1.0)
				var side := -1.0 if index % 2 == 0 else 1.0
				var point := Vector2(side * (side_x + sin(phase * TAU * 2.0 + index) * 5.0 * scale_factor), lerpf(edge_y, -edge_y, phase))
				_draw_bubble(point, (4.4 + float(index % 3) * 0.7) * scale_factor, Color(0.36, 0.88, 1.0, 0.98))
		"SPARK ARCS":
			for index in _particle_count():
				var angle := elapsed * 0.72 + TAU * float(index) / _particle_count()
				var point := Vector2(cos(angle) * side_x, sin(angle) * edge_y)
				_draw_lightning(point, 5.4 * scale_factor, angle + PI * 0.5, Color(1.0, 0.84, 0.18, 0.98))
		"EMBER SPARKS":
			for index in _particle_count():
				var phase := fmod(elapsed * (0.19 + float(index % 3) * 0.012) + float(index) / _particle_count(), 1.0)
				var side := -1.0 if index % 2 == 0 else 1.0
				var point := Vector2(side * (side_x + sin(phase * TAU + index) * 5.0 * scale_factor), lerpf(edge_y, -edge_y, phase))
				_draw_ember(point, 5.0 * scale_factor, sin(elapsed * 2.0 + index) * 0.32, Color(1.0, 0.38, 0.06, 0.98))
		"SNOW GLITTER":
			for index in _particle_count():
				var phase := fmod(elapsed * 0.13 + float(index) / _particle_count(), 1.0)
				var side := -1.0 if index % 2 == 0 else 1.0
				var point := Vector2(side * (side_x + sin(phase * TAU + index * 1.7) * 5.0 * scale_factor), lerpf(-edge_y, edge_y, phase))
				_draw_snowflake(point, 5.2 * scale_factor, elapsed * 0.8 + index, Color(0.77, 0.95, 1.0, 0.98))
		"SUN RAYS":
			for index in _particle_count():
				var angle := -elapsed * 0.62 + TAU * float(index) / _particle_count()
				var point := Vector2(cos(angle) * side_x, sin(angle) * edge_y)
				_draw_sun_glint(point, 5.2 * scale_factor, angle)
		"STAR DUST":
			for index in _particle_count():
				var direction := -1.0 if index % 2 == 0 else 1.0
				var angle := elapsed * (0.42 + float(index % 3) * 0.05) * direction + TAU * float(index) / _particle_count()
				var point := Vector2(cos(angle) * side_x, sin(angle) * edge_y)
				_draw_star(point, 5.1 * scale_factor, -angle + elapsed, Color(0.48, 0.90, 1.0, 0.98))


func _effect_scale() -> float:
	return clampf(minf(body_size.x / BASE_BODY_SIZE.x, body_size.y / BASE_BODY_SIZE.y), 0.78, 2.4)


func _particle_count() -> int:
	return PARTICLE_COUNT if _preview_mode else GAME_PARTICLE_COUNT


func _draw_sun_rays_back(scale_factor: float, side_x: float, edge_y: float) -> void:
	if effect_name != "SUN RAYS":
		return
	var pulse := 1.0 + sin(elapsed * 2.2) * 0.035
	draw_circle(Vector2.ZERO, maxf(side_x, edge_y * 0.68) * pulse, Color(1.0, 0.58, 0.06, 0.16))
	for index in 8:
		var angle := elapsed * 0.34 + TAU * float(index) / 8.0
		var direction := Vector2.from_angle(angle)
		var inner := Vector2(direction.x * side_x * 0.72, direction.y * edge_y * 0.72)
		var outer := Vector2(direction.x * side_x * 1.34, direction.y * edge_y * 1.20)
		draw_line(inner, outer, Color(1.0, 0.70, 0.10, 0.74), 7.0 * scale_factor, _preview_mode)


func _draw_leaf(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var shape := PackedVector2Array([
		Vector2(0.0, -1.15), Vector2(0.72, -0.18), Vector2(0.42, 0.72),
		Vector2(0.0, 1.05), Vector2(-0.42, 0.72), Vector2(-0.72, -0.18),
	])
	_draw_layered_shape(point, radius, angle, shape, color)


func _draw_petal(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var shape := PackedVector2Array([
		Vector2(0.0, -1.18), Vector2(0.76, -0.34), Vector2(0.58, 0.52),
		Vector2(0.0, 1.0), Vector2(-0.58, 0.52), Vector2(-0.76, -0.34),
	])
	_draw_layered_shape(point, radius, angle, shape, color)


func _draw_cloud(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var shape := PackedVector2Array([
		Vector2(-1.05, 0.42), Vector2(-1.02, -0.10), Vector2(-0.70, -0.48),
		Vector2(-0.28, -0.44), Vector2(0.02, -0.90), Vector2(0.48, -0.82),
		Vector2(0.64, -0.42), Vector2(1.02, -0.25), Vector2(1.08, 0.36),
		Vector2(0.62, 0.62), Vector2(-0.55, 0.62),
	])
	_draw_layered_shape(point, radius, angle, shape, color)


func _draw_bubble(point: Vector2, radius: float, color: Color) -> void:
	if not _preview_mode:
		draw_circle(point, radius, color)
		draw_arc(point, radius + 1.2 * _effect_scale(), 0.0, TAU, 12, OUTLINE_COLOR, 2.4 * _effect_scale(), false)
		return
	draw_circle(point, radius * 1.55, Color(color.r, color.g, color.b, 0.15))
	draw_arc(point, radius + 1.2 * _effect_scale(), 0.0, TAU, 18, OUTLINE_COLOR, 2.8 * _effect_scale(), true)
	draw_arc(point, radius, 0.0, TAU, 18, color, 1.8 * _effect_scale(), true)
	draw_circle(point + Vector2(-radius * 0.34, -radius * 0.34), maxf(radius * 0.22, 1.1), CORE_COLOR)


func _draw_lightning(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var points := _transform_points(point, radius, angle, PackedVector2Array([
		Vector2(-0.42, -1.05), Vector2(0.18, -0.28), Vector2(-0.12, -0.12),
		Vector2(0.48, 1.02),
	]))
	if _preview_mode:
		draw_polyline(points, Color(color.r, color.g, color.b, 0.16), 8.0 * _effect_scale(), true)
		draw_polyline(points, OUTLINE_COLOR, 5.4 * _effect_scale(), true)
		draw_polyline(points, color, 3.1 * _effect_scale(), true)
		draw_polyline(points, CORE_COLOR, 1.0 * _effect_scale(), true)
		return
	draw_polyline(points, OUTLINE_COLOR, 5.4 * _effect_scale(), false)
	draw_polyline(points, color, 3.1 * _effect_scale(), false)


func _draw_ember(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var shape := PackedVector2Array([
		Vector2(0.0, -1.25), Vector2(0.72, -0.22), Vector2(0.58, 0.62),
		Vector2(0.0, 1.0), Vector2(-0.58, 0.62), Vector2(-0.72, -0.22),
	])
	_draw_layered_shape(point, radius, angle, shape, color)


func _draw_snowflake(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var shape := PackedVector2Array()
	for index in 12:
		var point_angle := TAU * float(index) / 12.0
		var length := 1.0 if index % 2 == 0 else 0.38
		shape.append(Vector2.from_angle(point_angle) * length)
	_draw_layered_shape(point, radius, angle, shape, color)


func _draw_sun_glint(point: Vector2, radius: float, angle: float) -> void:
	var shape := PackedVector2Array([
		Vector2(0.0, -1.2), Vector2(0.46, -0.34), Vector2(1.05, 0.0),
		Vector2(0.46, 0.34), Vector2(0.0, 1.2), Vector2(-0.46, 0.34),
		Vector2(-1.05, 0.0), Vector2(-0.46, -0.34),
	])
	draw_colored_polygon(_transform_points(point, radius + 1.3 * _effect_scale(), angle, shape), OUTLINE_COLOR)
	draw_colored_polygon(_transform_points(point, radius, angle, shape), Color(1.0, 0.76, 0.14, 0.98))
	if _preview_mode:
		draw_circle(point, maxf(radius * 0.27, 1.2), CORE_COLOR)


func _draw_star(point: Vector2, radius: float, angle: float, color: Color) -> void:
	var shape := PackedVector2Array()
	for index in 10:
		var point_angle := -PI * 0.5 + TAU * float(index) / 10.0
		var length := 1.0 if index % 2 == 0 else 0.43
		shape.append(Vector2.from_angle(point_angle) * length)
	_draw_layered_shape(point, radius, angle, shape, color)


func _draw_layered_shape(point: Vector2, radius: float, angle: float, shape: PackedVector2Array, color: Color) -> void:
	var scale_factor := _effect_scale()
	if _preview_mode:
		draw_circle(point, radius * 1.55, Color(color.r, color.g, color.b, 0.15))
	draw_colored_polygon(_transform_points(point, radius + 1.25 * scale_factor, angle, shape), OUTLINE_COLOR)
	draw_colored_polygon(_transform_points(point, radius, angle, shape), color)
	if _preview_mode:
		draw_circle(point, maxf(radius * 0.24, 1.1), CORE_COLOR)


func _transform_points(point: Vector2, radius: float, angle: float, shape: PackedVector2Array) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for local_point in shape:
		transformed.append(point + (local_point * radius).rotated(angle))
	return transformed
