class_name TrailEffect
extends Node2D

const MAX_POINTS := 40
const LIFETIME := 0.90
const SAMPLE_INTERVAL := 0.035
const MIN_DISTANCE := 5.0

var trail_id := ""
var effect_name := ""
var points: Array[Dictionary] = []
var _sample_elapsed := SAMPLE_INTERVAL
var _sequence := 0

func _init() -> void:
	top_level = true
	z_index = -6
	position = Vector2.ZERO
	visible = false

func configure(item: Dictionary) -> void:
	var next_id := str(item.get("id", ""))
	if next_id != trail_id:
		clear()
	trail_id = next_id
	effect_name = str(item.get("effect_name", ""))
	visible = not trail_id.is_empty()
	queue_redraw()

func update_trail(world_position: Vector2, moving: bool, transferring: bool, delta: float) -> void:
	_age_points(delta)
	if not visible or not moving:
		queue_redraw()
		return
	_sample_elapsed += delta
	var far_enough := points.is_empty() or world_position.distance_to(Vector2(points[-1].position)) >= MIN_DISTANCE
	if _sample_elapsed >= SAMPLE_INTERVAL and far_enough:
		points.append({"position": world_position, "age": 0.0, "seed": _sequence, "transfer": transferring})
		_sequence += 1
		_sample_elapsed = 0.0
		while points.size() > MAX_POINTS:
			points.pop_front()
	queue_redraw()

func clear() -> void:
	points.clear()
	_sample_elapsed = SAMPLE_INTERVAL
	queue_redraw()

func point_count() -> int:
	return points.size()

func point_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point in points:
		result.append(Vector2(point.position))
	return result

func shape_identity() -> String:
	match trail_id:
		"trail_leaf": return "leaf_ribbon"
		"trail_cloud": return "cloud_clusters"
		"trail_star": return "star_sparkles"
	return "none"

func snapshot() -> Dictionary:
	return {"id": trail_id, "points": point_count(), "visible": visible and not points.is_empty()}

func _age_points(delta: float) -> void:
	for point in points:
		point.age = float(point.age) + delta
	while not points.is_empty() and float(points[0].age) >= LIFETIME:
		points.pop_front()

func _draw() -> void:
	if points.is_empty():
		return
	match trail_id:
		"trail_leaf": _draw_leaf_wake()
		"trail_cloud": _draw_cloud_wake()
		"trail_star": _draw_star_wake()

func _draw_leaf_wake() -> void:
	_draw_ribbon(Color(0.28, 0.82, 0.31, 0.52), 3.2)
	for point in points:
		var fade := _fade(point)
		var seed := float(int(point.seed))
		var center := Vector2(point.position) + Vector2(sin(seed * 1.7 + float(point.age) * 8.0) * 5.0, float(point.age) * 18.0)
		var angle := seed * 2.1 + float(point.age) * 7.0
		var axis := Vector2(cos(angle), sin(angle))
		var side := axis.orthogonal()
		var leaf := PackedVector2Array([center + axis * 7.0, center + side * 3.4, center - axis * 7.0, center - side * 3.4])
		draw_colored_polygon(leaf, Color(0.34, 0.94, 0.32, 0.88 * fade))
		draw_line(center - axis * 5.0, center + axis * 5.0, Color(0.84, 1.0, 0.55, 0.75 * fade), 1.0)

func _draw_cloud_wake() -> void:
	for point in points:
		var fade := _fade(point)
		var grow := lerpf(0.72, 1.55, float(point.age) / LIFETIME)
		var center := Vector2(point.position)
		for bubble in 3:
			var offset := Vector2(float(bubble - 1) * 5.2, -absf(float(bubble - 1)) * 1.8)
			var radius := (5.0 + float((int(point.seed) + bubble) % 3) * 1.3) * grow
			draw_circle(center + offset, radius, Color(0.68, 0.88, 1.0, 0.24 * fade))
			draw_circle(center + offset, radius * 0.66, Color(0.94, 0.98, 1.0, 0.62 * fade))

func _draw_star_wake() -> void:
	_draw_ribbon(Color(1.0, 0.69, 0.12, 0.32), 2.0)
	for point in points:
		var fade := _fade(point)
		var center := Vector2(point.position)
		var radius := 3.5 + float(int(point.seed) % 3)
		draw_colored_polygon(_star_points(center, radius, radius * 0.42), Color(1.0, 0.78, 0.16, 0.96 * fade))
		draw_line(center + Vector2(-radius * 1.7, 0.0), center + Vector2(radius * 1.7, 0.0), Color(1.0, 0.95, 0.58, 0.55 * fade), 1.0)
		draw_line(center + Vector2(0.0, -radius * 1.7), center + Vector2(0.0, radius * 1.7), Color(1.0, 0.95, 0.58, 0.55 * fade), 1.0)

func _draw_ribbon(color: Color, width: float) -> void:
	if points.size() < 2:
		return
	for index in range(1, points.size()):
		var alpha := minf(_fade(points[index - 1]), _fade(points[index]))
		draw_line(Vector2(points[index - 1].position), Vector2(points[index].position), Color(color, color.a * alpha), width, true)

func _star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for index in 10:
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + float(index) * PI / 5.0
		vertices.append(center + Vector2.from_angle(angle) * radius)
	return vertices

func _fade(point: Dictionary) -> float:
	return clampf(1.0 - float(point.age) / LIFETIME, 0.0, 1.0)
