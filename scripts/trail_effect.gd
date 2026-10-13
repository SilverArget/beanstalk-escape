class_name TrailEffect
extends Node2D

const MAX_POINTS := 48
const GAME_MAX_POINTS := 24
const GAME_LEAF_PARTICLES := 9
const GAME_STAR_PARTICLES := 6
const GAME_REDRAW_INTERVAL_FRAMES := 2
const GAME_REDRAW_PHASE := 0
const TEXTURE_SIZE := 32
const TEXTURE_RADIUS := 12.0
const LIFETIME := 1.1
const SAMPLE_INTERVAL := 0.035
const MIN_DISTANCE := 5.0
const WORLD_Z_INDEX := 4
const PREVIEW_Z_OFFSET := -1
const PREVIEW_SCROLL_SPEED := 280.0
const OUTLINE_COLOR := Color(0.025, 0.09, 0.07, 0.62)
const STAR_RIBBON_WIDTH := 14.0
const STAR_CORE_WIDTH := 6.0
const STAR_MIN_RADIUS := 8.0
const STAR_RIBBON_ALPHA := 0.90
const CLOUD_BUBBLE_SPACING := 12.0
const CLOUD_MAX_GAME_BUBBLES := 8
const CLOUD_RIBBON_WIDTH := 13.0

static var _shared_game_textures: Dictionary = {}

var trail_id := ""
var effect_name := ""
var points: Array[Dictionary] = []
var _sample_elapsed := SAMPLE_INTERVAL
var _sequence := 0
var _preview_mode := false
var _redraw_frame := 0
var _game_textures: Dictionary = {}

func _init() -> void:
	top_level = true
	z_as_relative = false
	z_index = WORLD_Z_INDEX
	position = Vector2.ZERO
	visible = false
	if _shared_game_textures.is_empty():
		_shared_game_textures = _create_game_textures()
	_game_textures = _shared_game_textures

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
		_request_game_redraw()
		return
	_sample_elapsed += delta
	var local_position := to_local(world_position)
	var far_enough := points.is_empty() or local_position.distance_to(Vector2(points[-1].position)) >= MIN_DISTANCE
	if _sample_elapsed >= SAMPLE_INTERVAL and far_enough:
		points.append({"position": local_position, "age": 0.0, "seed": _sequence, "transfer": transferring})
		_sequence += 1
		_sample_elapsed = 0.0
		while points.size() > _point_limit():
			points.pop_front()
	_request_game_redraw()

func set_preview_mode(enabled: bool) -> void:
	if _preview_mode == enabled:
		return
	_preview_mode = enabled
	clear()
	top_level = not enabled
	z_as_relative = enabled
	z_index = PREVIEW_Z_OFFSET if enabled else WORLD_Z_INDEX
	position = Vector2.ZERO
	while points.size() > _point_limit():
		points.pop_front()

func update_preview(local_emitter_position: Vector2, delta: float) -> void:
	set_preview_mode(true)
	_age_points(delta)
	for point in points:
		point.position = Vector2(point.position) + Vector2.DOWN * PREVIEW_SCROLL_SPEED * delta
	if not visible:
		queue_redraw()
		return
	_sample_elapsed += delta
	var far_enough := points.is_empty() or local_emitter_position.distance_to(Vector2(points[-1].position)) >= MIN_DISTANCE
	if _sample_elapsed >= SAMPLE_INTERVAL and far_enough:
		points.append({"position": local_emitter_position, "age": 0.0, "seed": _sequence, "transfer": false})
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
		result.append(to_global(Vector2(point.position)))
	return result

func shape_identity() -> String:
	match trail_id:
		"trail_leaf": return "leaf_ribbon"
		"trail_cloud": return "cloud_clusters"
		"trail_star": return "star_sparkles"
	return "none"

func snapshot() -> Dictionary:
	var screen_first := Vector2.ZERO
	var screen_last := Vector2.ZERO
	if not points.is_empty():
		var local_to_viewport := get_global_transform_with_canvas()
		screen_first = local_to_viewport * Vector2(points[0].position)
		screen_last = local_to_viewport * Vector2(points[-1].position)
	return {
		"id": trail_id,
		"points": point_count(),
		"visible": visible and not points.is_empty(),
		"screen_first": {"x": screen_first.x, "y": screen_first.y},
		"screen_last": {"x": screen_last.x, "y": screen_last.y},
		"z": {"index": z_index, "effective": effective_z_index(), "relative": z_as_relative, "top_level": top_level},
		"preview": _preview_mode,
	}

func render_profile() -> Dictionary:
	var particle_limit := MAX_POINTS if _preview_mode else GAME_LEAF_PARTICLES
	var max_draw_calls := 0
	match trail_id:
		"trail_leaf":
			particle_limit = MAX_POINTS if _preview_mode else GAME_LEAF_PARTICLES
			max_draw_calls = (MAX_POINTS - 1) * 2 + MAX_POINTS * 3 if _preview_mode else 2 + GAME_LEAF_PARTICLES
		"trail_cloud":
			particle_limit = MAX_POINTS if _preview_mode else CLOUD_MAX_GAME_BUBBLES
			max_draw_calls = MAX_POINTS * 6 if _preview_mode else 3 + CLOUD_MAX_GAME_BUBBLES
		"trail_star":
			particle_limit = MAX_POINTS if _preview_mode else GAME_STAR_PARTICLES
			max_draw_calls = (MAX_POINTS - 1) * 3 + MAX_POINTS * 4 if _preview_mode else 3 + GAME_STAR_PARTICLES
	return {
		"point_limit": _point_limit(),
		"particle_limit": particle_limit,
		"max_draw_calls": max_draw_calls,
		"polygon_draw_calls": 0 if not _preview_mode else particle_limit * 2,
		"redraw_interval_frames": 1 if _preview_mode else GAME_REDRAW_INTERVAL_FRAMES,
		"redraw_phase": 0 if _preview_mode else GAME_REDRAW_PHASE,
		"preview": _preview_mode,
	}

func effective_z_index() -> int:
	var result := z_index
	var item: CanvasItem = self
	var parent := item.get_parent() as CanvasItem
	while item.z_as_relative and parent != null:
		result += parent.z_index
		item = parent
		parent = item.get_parent() as CanvasItem
	return result

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
	_draw_ribbon(Color(0.24, 0.86, 0.28, 0.82), 10.0)
	var draw_points: Array[Dictionary] = points if _preview_mode else _sampled_points(GAME_LEAF_PARTICLES)
	for point in draw_points:
		var fade := _fade(point)
		var seed := float(int(point.seed))
		var center := Vector2(point.position) + Vector2(sin(seed * 1.7 + float(point.age) * 8.0) * 5.0, float(point.age) * 18.0)
		var angle := seed * 2.1 + float(point.age) * 7.0
		if _preview_mode:
			var axis := Vector2(cos(angle), sin(angle))
			var side := axis.orthogonal()
			var leaf := PackedVector2Array([center + axis * 8.0, center + side * 5.0, center - axis * 8.0, center - side * 5.0])
			_draw_closed_outline(leaf, fade)
			draw_colored_polygon(leaf, Color(0.34, 0.94, 0.32, 0.94 * fade))
			draw_line(center - axis * 6.0, center + axis * 6.0, Color(0.84, 1.0, 0.55, 0.82 * fade), 1.5)
		else:
			_draw_game_texture("leaf", center, 8.0, angle, fade)

func _draw_cloud_wake() -> void:
	if _preview_mode:
		_draw_cloud_preview_bubbles()
		return
	var path := PackedVector2Array()
	var fades := PackedFloat32Array()
	for point in points:
		path.append(Vector2(point.position))
		fades.append(_fade(point))
	_draw_cloud_ribbon(path, fades)
	var geometry := cloud_wake_geometry(path)
	var bubble_centers: PackedVector2Array = geometry.bubble_centers
	for index in bubble_centers.size():
		var source_index := maxi(points.size() - 1 - index, 0)
		var point: Dictionary = points[source_index]
		var fade := _fade(point)
		var grow := lerpf(0.72, 1.35, float(point.age) / LIFETIME)
		var radius := (6.0 + float(int(point.seed) % 3) * 0.6) * grow
		var center := bubble_centers[index]
		_draw_game_texture("cloud", center, radius + 1.5, 0.0, fade)

func _draw_cloud_preview_bubbles() -> void:
	for index in range(points.size() - 1, -1, -1):
		var point: Dictionary = points[index]
		var fade := _fade(point)
		var grow := lerpf(0.72, 1.55, float(point.age) / LIFETIME)
		var center := Vector2(point.position)
		for bubble in 2:
			var offset := Vector2((float(bubble) - 0.5) * 6.0, -absf(float(bubble) - 0.5) * 1.8)
			var radius := (6.0 + float((int(point.seed) + bubble) % 3) * 1.2) * grow
			draw_circle(center + offset, radius + 1.5, Color(OUTLINE_COLOR, OUTLINE_COLOR.a * fade))
			draw_circle(center + offset, radius, Color(0.68, 0.88, 1.0, 0.72 * fade))
			draw_circle(center + offset, radius * 0.66, Color(0.94, 0.98, 1.0, 0.88 * fade))

static func cloud_wake_geometry(source_points: PackedVector2Array) -> Dictionary:
	var bubbles := PackedVector2Array()
	if source_points.is_empty():
		return {"ribbon_points": source_points.duplicate(), "bubble_centers": bubbles}
	bubbles.append(source_points[-1])
	var distance_since_bubble := 0.0
	for index in range(source_points.size() - 1, 0, -1):
		var cursor := source_points[index]
		var target := source_points[index - 1]
		var segment_length := cursor.distance_to(target)
		if segment_length <= 0.001:
			continue
		var direction := cursor.direction_to(target)
		var remaining := segment_length
		while distance_since_bubble + remaining >= CLOUD_BUBBLE_SPACING and bubbles.size() < CLOUD_MAX_GAME_BUBBLES:
			var step := CLOUD_BUBBLE_SPACING - distance_since_bubble
			cursor += direction * step
			remaining -= step
			bubbles.append(cursor)
			distance_since_bubble = 0.0
		if bubbles.size() >= CLOUD_MAX_GAME_BUBBLES:
			break
		distance_since_bubble += remaining
	return {"ribbon_points": source_points.duplicate(), "bubble_centers": bubbles}

func _draw_cloud_ribbon(path: PackedVector2Array, fades: PackedFloat32Array) -> void:
	if path.size() < 2:
		return
	_draw_faded_polyline(path, fades, CLOUD_RIBBON_WIDTH + 3.0, OUTLINE_COLOR)
	_draw_faded_polyline(path, fades, CLOUD_RIBBON_WIDTH, Color(0.68, 0.88, 1.0, 0.78))
	_draw_faded_polyline(path, fades, 5.5, Color(0.94, 0.98, 1.0, 0.90))

func _draw_faded_polyline(path: PackedVector2Array, fades: PackedFloat32Array, width: float, color: Color) -> void:
	var colors := PackedColorArray()
	for index in path.size():
		var fade := fades[index]
		colors.append(Color(color, color.a * fade))
	draw_polyline_colors(path, colors, width, false)

func _draw_star_wake() -> void:
	_draw_star_ribbon()
	var draw_points: Array[Dictionary] = points if _preview_mode else _sampled_points(GAME_STAR_PARTICLES)
	for point in draw_points:
		var fade := _fade(point)
		var center := Vector2(point.position)
		var radius := STAR_MIN_RADIUS + float(int(point.seed) % 3)
		if _preview_mode:
			var star := _star_points(center, radius, radius * 0.42)
			var outline_star := _star_points(center, radius + 1.5, (radius + 1.5) * 0.42)
			draw_colored_polygon(outline_star, Color(OUTLINE_COLOR, OUTLINE_COLOR.a * fade))
			draw_colored_polygon(star, Color(1.0, 0.78, 0.16, 0.96 * fade))
			draw_line(center + Vector2(-radius * 1.7, 0.0), center + Vector2(radius * 1.7, 0.0), Color(1.0, 0.95, 0.58, 0.78 * fade), 1.5)
			draw_line(center + Vector2(0.0, -radius * 1.7), center + Vector2(0.0, radius * 1.7), Color(1.0, 0.95, 0.58, 0.78 * fade), 1.5)
		else:
			_draw_game_texture("star", center, radius + 1.5, 0.0, fade)

func _draw_star_ribbon() -> void:
	if points.size() < 2:
		return
	if _preview_mode:
		for index in range(1, points.size()):
			var alpha := minf(_fade(points[index - 1]), _fade(points[index]))
			var from := Vector2(points[index - 1].position)
			var to := Vector2(points[index].position)
			draw_line(from, to, Color(OUTLINE_COLOR, OUTLINE_COLOR.a * alpha), STAR_RIBBON_WIDTH + 3.0, true)
			draw_line(from, to, Color(1.0, 0.66, 0.08, STAR_RIBBON_ALPHA * alpha), STAR_RIBBON_WIDTH, true)
			draw_line(from, to, Color(1.0, 0.94, 0.48, 0.94 * alpha), STAR_CORE_WIDTH, true)
		return
	_draw_batched_ribbon(OUTLINE_COLOR, STAR_RIBBON_WIDTH + 3.0)
	_draw_batched_ribbon(Color(1.0, 0.66, 0.08, STAR_RIBBON_ALPHA), STAR_RIBBON_WIDTH)
	_draw_batched_ribbon(Color(1.0, 0.94, 0.48, 0.94), STAR_CORE_WIDTH)

func _draw_ribbon(color: Color, width: float) -> void:
	if points.size() < 2:
		return
	if _preview_mode:
		for index in range(1, points.size()):
			var alpha := minf(_fade(points[index - 1]), _fade(points[index]))
			draw_line(Vector2(points[index - 1].position), Vector2(points[index].position), Color(OUTLINE_COLOR, OUTLINE_COLOR.a * alpha), width + 3.0, true)
			draw_line(Vector2(points[index - 1].position), Vector2(points[index].position), Color(color, color.a * alpha), width, true)
		return
	_draw_batched_ribbon(OUTLINE_COLOR, width + 3.0)
	_draw_batched_ribbon(color, width)

func _draw_batched_ribbon(color: Color, width: float) -> void:
	var path := PackedVector2Array()
	var colors := PackedColorArray()
	for point in points:
		path.append(Vector2(point.position))
		colors.append(Color(color, color.a * _fade(point)))
	draw_polyline_colors(path, colors, width, false)

func _sampled_points(limit: int) -> Array[Dictionary]:
	if points.size() <= limit:
		return points
	var sampled: Array[Dictionary] = []
	var stride := ceili(float(points.size()) / float(limit))
	for index in range(points.size() - 1, -1, -stride):
		sampled.append(points[index])
		if sampled.size() >= limit:
			break
	return sampled

func _point_limit() -> int:
	return MAX_POINTS if _preview_mode else GAME_MAX_POINTS

func _draw_closed_outline(vertices: PackedVector2Array, fade: float) -> void:
	var outline := vertices.duplicate()
	outline.append(vertices[0])
	draw_polyline(outline, Color(OUTLINE_COLOR, OUTLINE_COLOR.a * fade), 1.5, true)

func _star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var vertices := PackedVector2Array()
	for index in 10:
		var radius := outer_radius if index % 2 == 0 else inner_radius
		var angle := -PI * 0.5 + float(index) * PI / 5.0
		vertices.append(center + Vector2.from_angle(angle) * radius)
	return vertices

func _fade(point: Dictionary) -> float:
	return clampf(1.0 - float(point.age) / LIFETIME, 0.0, 1.0)

func _request_game_redraw() -> void:
	_redraw_frame += 1
	if _redraw_frame % GAME_REDRAW_INTERVAL_FRAMES == GAME_REDRAW_PHASE:
		queue_redraw()

func _draw_game_texture(texture_name: String, point: Vector2, radius: float, angle: float, opacity: float) -> void:
	var texture := _game_textures.get(texture_name) as Texture2D
	if texture == null:
		return
	draw_set_transform(point, angle, Vector2.ONE * radius / TEXTURE_RADIUS)
	draw_texture(texture, Vector2.ONE * -TEXTURE_SIZE * 0.5, Color(1.0, 1.0, 1.0, opacity))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _create_game_textures() -> Dictionary:
	return {
		"leaf": _svg_texture('<polygon points="16,3 27,16 16,29 5,16" fill="#57f052" stroke="#061712" stroke-opacity=".62" stroke-width="3"/><path d="M8 22 24 10" stroke="#d6ff8c" stroke-width="2"/>'),
		"cloud": _svg_texture('<circle cx="16" cy="16" r="12" fill="#061712" fill-opacity=".62"/><circle cx="16" cy="16" r="10" fill="#addfff" fill-opacity=".78"/><circle cx="16" cy="16" r="6.5" fill="#f0faff" fill-opacity=".9"/>'),
		"star": _svg_texture('<polygon points="16,1 20,11 31,11 22,18 26,29 16,22 6,29 10,18 1,11 12,11" fill="#ffc72b" stroke="#061712" stroke-opacity=".62" stroke-width="3"/><path d="M2 16H30M16 2V30" stroke="#fff294" stroke-width="2"/>'),
	}

func _svg_texture(body: String) -> ImageTexture:
	var image := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">%s</svg>' % body
	if image.load_svg_from_string(svg) != OK:
		return null
	return ImageTexture.create_from_image(image)
