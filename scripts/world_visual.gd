extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const VINE_SURFACE_TEXTURE := preload("res://assets/art/world/vine_helix_tile_v4.png")
const BRANCH_SURFACE_TEXTURE := preload("res://assets/art/world/bean_branch_surface_v1.png")
const BRANCH_DETAILS_TEXTURE := preload("res://assets/art/world/vine_details_atlas_v2.png")
const FOLIAGE_TEXTURE := preload("res://assets/art/world/foliage_atlas.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")
const OUTLINE_COLOR := Color8(25, 68, 49)
const VINE_BASE_COLOR := Color("4c9a4d")
const MODULE_HEIGHT := 256.0
const TEXTURE_REPEAT := 52.0
const MAX_TEXTURE_ELEMENT := 54.0
const GRIP_DETAIL_SIZE := 12.0
const MAX_LEAF_SIZE := 140.0
const VISUAL_OUTLINE_WIDTH := 5.0
const FOLIAGE_CELL := Vector2(512.0, 512.0)
const BRANCH_DETAIL_GRID := Vector2(4.0, 2.0)
const BRANCH_NODE_SPACING := [173.0, 211.0, 187.0]
const STAGE_3_ENTRY_HEIGHT := 350.0
const SIDE_VINE_MIN_ENTRY_DEPTH := 360.0
const SIDE_VINE_ENTRY_DEPTH_PER_X := 1.9
const SIDE_VINE_OFFSCREEN_X := 560.0
const SURFACE_CACHE_SCROLL_PX := 192.0
const SURFACE_CACHE_MARGIN_PX := 384.0
const SKY_VISUAL := preload("res://scripts/world_sky_visual.gd")

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

var branch_graph := BranchGraph.new()
var redraw_count := 0
var branch_point_count := 0
var qa_storm_background := false
var qa_support_mask := false
var qa_support_mask_include_outline := false
var qa_sky_only := false
var cached_camera_top := INF
var sky_visual: Node2D
var draw_mesh_cache: Array[ArrayMesh] = []
var detail_vertices := PackedVector2Array()
var detail_uvs := PackedVector2Array()
var detail_indices := PackedInt32Array()
var outline_vertices := PackedVector2Array()
var outline_indices := PackedInt32Array()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sky_visual = SKY_VISUAL.new()
	sky_visual.name = "Sky"
	sky_visual.z_index = -100
	sky_visual.setup(player, stages)
	add_child(sky_visual)
	cached_camera_top = _camera_top()
	queue_redraw()
	set_process(true)

func _process(_delta: float) -> void:
	var current_camera_top := _camera_top()
	if absf(current_camera_top - cached_camera_top) >= SURFACE_CACHE_SCROLL_PX:
		cached_camera_top = current_camera_top
		queue_redraw()

func _camera_top() -> float:
	var result := player.global_position.y - ScaleLock.CHARACTER_REFERENCE_Y if player != null else -270.0
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			result = camera.get_screen_center_position().y - get_viewport_rect().size.y * 0.5
	return result

func _draw() -> void:
	redraw_count += 1
	# Canvas draw commands retain mesh RIDs, not the local Resource references.
	# Keep each rebuilt mesh alive until the next surface-cache redraw.
	draw_mesh_cache.clear()
	detail_vertices.clear()
	detail_uvs.clear()
	detail_indices.clear()
	outline_vertices.clear()
	outline_indices.clear()
	branch_point_count = 0
	var camera_top := cached_camera_top if not is_inf(cached_camera_top) else _camera_top()
	if qa_sky_only:
		return
	_draw_trunk(camera_top)
	if not qa_support_mask:
		_draw_trunk_features(camera_top)
	for stage_number in range(3, Balance.STAGE_COUNT + 1):
		_draw_stage_branches(stage_number, camera_top)
	_flush_outlines()
	_flush_branch_details()

func _draw_sky(camera_top: float) -> void:
	# Camera X follows the active branch from Stage 3 onward. Keep the painted
	# plate locked to the actual camera center so no project clear-color strip
	# can enter at either viewport edge.
	var camera_center_x := player.global_position.x if player != null else 0.0
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera_center_x = camera.get_screen_center_position().x
	var view_rect := Rect2(camera_center_x - 488.0, camera_top - 8.0, 976.0, 556.0)
	if qa_support_mask:
		draw_rect(view_rect, Color.BLACK)
		return
	if qa_storm_background:
		draw_rect(view_rect, Color("313c68"))
		return
	for band in 24:
		var t := float(band) / 23.0
		var band_y := view_rect.position.y + view_rect.size.y * t
		draw_rect(Rect2(view_rect.position.x, band_y, view_rect.size.x, view_rect.size.y / 23.0 + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	# The image_gen plate already contains cream clouds. The former draw_circle
	# cloud clusters are deliberately gone; no primitive placeholder remains.
	draw_texture_rect(ATMOSPHERE_TEXTURE, view_rect, false, Color(1.0, 1.0, 1.0, 0.72))
	var stage_number := stages.stage_for_y(player.global_position.y) if stages != null and player != null else 1
	var stage_progress := stages.progress_in_stage(player.global_position.y) if stages != null and player != null else 0.0
	var rock_mix := clampf((float(stage_number) - 5.0 + stage_progress) / 2.0, 0.0, 1.0)
	var violet_mix := clampf((float(stage_number) - 10.0 + stage_progress) / 2.0, 0.0, 1.0)
	var storm_mix := clampf((float(stage_number) - 15.0 + stage_progress) / 2.0, 0.0, 1.0)
	var lightning_mix := clampf((float(stage_number) - 20.0 + stage_progress) / 2.0, 0.0, 1.0)
	var upper_cloud_mix := clampf((float(stage_number) - 25.0 + stage_progress) / 2.0, 0.0, 1.0)
	var summit_mix := clampf((float(stage_number) - 29.0 + stage_progress) / 1.0, 0.0, 1.0)
	if rock_mix > 0.0:
		draw_rect(view_rect, Color(0.34, 0.38, 0.47, 0.18 * rock_mix))
	if violet_mix > 0.0:
		draw_rect(view_rect, Color(0.29, 0.16, 0.46, 0.30 * violet_mix))
		for fog_index in 4:
			var fog_y := view_rect.position.y + fposmod(float(fog_index) * 151.0 - camera_top * 0.08, view_rect.size.y)
			draw_circle(Vector2(view_rect.get_center().x + sin(float(fog_index) * 2.1) * 260.0, fog_y), 150.0, Color(0.70, 0.56, 0.82, 0.035 * violet_mix))
	if storm_mix > 0.0:
		draw_rect(view_rect, Color(0.10, 0.16, 0.25, 0.32 * storm_mix * (1.0 - summit_mix)))
	if lightning_mix > 0.0:
		var distant_flash := pow(maxf(sin(Time.get_ticks_msec() * 0.0017 + float(stage_number)), 0.0), 18.0)
		draw_rect(view_rect, Color(0.72, 0.77, 0.92, distant_flash * 0.16 * lightning_mix * (1.0 - summit_mix)))
	if upper_cloud_mix > 0.0:
		for fog_index in 5:
			var fog_y := view_rect.position.y + fposmod(float(fog_index) * 127.0 - camera_top * 0.06, view_rect.size.y)
			draw_circle(Vector2(view_rect.get_center().x + sin(float(fog_index) * 1.8) * 300.0, fog_y), 190.0, Color(0.74, 0.79, 0.84, 0.075 * upper_cloud_mix * (1.0 - summit_mix)))
	if summit_mix > 0.0:
		draw_rect(view_rect, Color(1.0, 0.78, 0.34, 0.24 * summit_mix))
	_draw_far_vines(camera_top)

func _draw_far_vines(camera_top: float) -> void:
	var drift := fposmod(-camera_top * 0.12, 420.0)
	for index in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := side * (300.0 + float(index / 2) * 92.0)
		var start_y := camera_top - 180.0 + drift + float(index) * 105.0
		var points := PackedVector2Array()
		for step in 10:
			var y := start_y + float(step) * 82.0
			points.append(Vector2(x + sin((y + float(index) * 57.0) * 0.008) * 24.0, y))
		draw_polyline(points, Color(0.12, 0.38, 0.37, 0.12), 30.0, true)

func _draw_foreground_foliage(camera_top: float) -> void:
	var drift := fposmod(-camera_top * 0.52, 720.0)
	for index in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var center := Vector2(side * 468.0, camera_top - 100.0 + fposmod(drift + float(index) * 211.0, 760.0))
		_draw_foliage_sprite(4, center, Vector2(MAX_LEAF_SIZE, MAX_LEAF_SIZE), side < 0.0, Color(1.0, 1.0, 1.0, 0.32))

func _draw_trunk(camera_top: float) -> void:
	# One continuous ribbon becomes the middle Stage 3 vine. Because the width,
	# centerline, UV and glaze all live in this draw call, there is no fork seam.
	var transition_top_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
	var visible_top := maxf(transition_top_y, camera_top - 64.0 - SURFACE_CACHE_MARGIN_PX)
	var visible_bottom := minf(740.0, camera_top + 620.0 + SURFACE_CACHE_MARGIN_PX)
	if visible_bottom <= visible_top:
		return
	var centers := PackedVector2Array()
	var y := visible_bottom
	while y > visible_top:
		centers.append(Vector2(_main_stem_center_x(y), y))
		y = maxf(y - 32.0, visible_top)
	if centers.is_empty() or centers[centers.size() - 1].y != visible_top:
		centers.append(Vector2(_main_stem_center_x(visible_top), visible_top))
	_draw_textured_ribbon(centers, _trunk_widths(centers), -visible_bottom / MODULE_HEIGHT, true, true, false, 0, 0, false, true)

func _trunk_widths(points: PackedVector2Array) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for point in points:
		widths.append(_main_stem_width(point.y))
	return widths

func _main_stem_center_x(world_y: float) -> float:
	var stage_3_bottom := _stage_3_bottom_y()
	if world_y >= stage_3_bottom:
		return _trunk_center_x(world_y)
	var t := clampf((stage_3_bottom - world_y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
	var smooth := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return lerpf(_trunk_center_x(stage_3_bottom), _branch_visual_x(1, stage_3_bottom - STAGE_3_ENTRY_HEIGHT), smooth)

func _main_stem_width(world_y: float) -> float:
	var stage_3_bottom := _stage_3_bottom_y()
	if world_y >= stage_3_bottom:
		return _trunk_half_width(world_y) * 2.0
	var t := clampf((stage_3_bottom - world_y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
	var smooth := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return lerpf(_trunk_half_width(stage_3_bottom) * 2.0, ScaleLock.BRANCH_WIDTH, smooth)

func _trunk_center_x(world_y: float) -> float:
	return sin(world_y * TAU / 560.0) * 10.0 + sin(world_y * TAU / 910.0 + 0.7) * 4.0

func _trunk_half_width(world_y: float) -> float:
	return 90.0 + sin(world_y * TAU / 470.0) * 7.0 + sin(world_y * TAU / 150.0) * 3.0

func _draw_stage_branches(stage_number: int, camera_top: float) -> void:
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	var stage_top := stage_bottom - stage_length
	var camera_bottom := camera_top + 556.0
	if stage_bottom < camera_top - 120.0 - SURFACE_CACHE_MARGIN_PX or stage_top > camera_bottom + 120.0 + SURFACE_CACHE_MARGIN_PX:
		return
	var visible_start := clampf((stage_bottom - (camera_bottom + 160.0 + SURFACE_CACHE_MARGIN_PX)) / stage_length, 0.0, 1.0)
	var visible_end := clampf((stage_bottom - (camera_top - 160.0 - SURFACE_CACHE_MARGIN_PX)) / stage_length, 0.0, 1.0)
	for route in 3:
		for segment: Array in stages.support_segments(stage_number, route):
			var authored_start := float(segment[0])
			var authored_end := float(segment[1])
			var clipped_start := maxf(authored_start, visible_start)
			var clipped_end := minf(authored_end, visible_end)
			if clipped_end <= clipped_start:
				continue
			_draw_branch_segment(stage_number, route, clipped_start, clipped_end, is_equal_approx(clipped_start, authored_start), is_equal_approx(clipped_end, authored_end))

func _draw_branch_segment(stage_number: int, route: int, start_progress: float, end_progress: float, show_start_tip := true, show_end_tip := true) -> void:
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	var cap_start := start_progress > 0.0 and show_start_tip
	if stage_number == 3 and route == 1 and start_progress <= 0.0:
		start_progress = STAGE_3_ENTRY_HEIGHT / stage_length
	var start_y := stage_bottom - start_progress * stage_length
	var end_y := stage_bottom - end_progress * stage_length
	var points := PackedVector2Array()
	if stage_number == 3 and route != 1 and start_progress <= 0.0:
		points = _side_vine_entry_points(route, stage_bottom)
		cap_start = false
	elif cap_start and not qa_support_mask:
		points = _restart_vine_entry_points(route, start_y)
	else:
		points.append(Vector2(_branch_visual_x(route, start_y), start_y))
	var cursor_y := start_y
	while cursor_y > end_y:
		cursor_y = maxf(cursor_y - 12.0, end_y)
		points.append(Vector2(_branch_visual_x(route, cursor_y), cursor_y))
	if points.size() < 2:
		return
	branch_point_count += points.size()
	_draw_branch_ribbon(points, route, cap_start, show_end_tip)
	_draw_branch_details(stage_number, route, start_y, end_y)

func _restart_vine_entry_points(route: int, start_y: float) -> PackedVector2Array:
	# A returning support is a separate vine: outer routes curl in from beyond
	# the screen edge, while the middle route emerges from behind the right vine.
	# This is decorative lead-in only and never changes support/collision data.
	var target_x := _branch_visual_x(route, start_y)
	var source_x := SIDE_VINE_OFFSCREEN_X
	if route == 0:
		source_x = -SIDE_VINE_OFFSCREEN_X
	elif route == 1:
		source_x = _branch_visual_x(2, start_y)
	return _smooth_vertical_entry_points(source_x, target_x, start_y)

func _side_vine_entry_points(route: int, stage_bottom: float) -> PackedVector2Array:
	var side := -1.0 if route == 0 else 1.0
	return _smooth_vertical_entry_points(side * SIDE_VINE_OFFSCREEN_X, _branch_visual_x(route, stage_bottom), stage_bottom)

func _smooth_vertical_entry_points(source_x: float, target_x: float, target_y: float) -> PackedVector2Array:
	# Cubic Hermite path with vertical tangents at both ends. Scaling the rise
	# with horizontal travel keeps the steepest tangent under 40 degrees and
	# the tightest radius above roughly 120 px, without a horizontal shelf.
	var points := PackedVector2Array()
	var travel_x := absf(target_x - source_x)
	var depth := maxf(SIDE_VINE_MIN_ENTRY_DEPTH, travel_x * SIDE_VINE_ENTRY_DEPTH_PER_X)
	var steps := maxi(30, int(ceil(depth / 12.0)))
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var smooth := t * t * (3.0 - 2.0 * t)
		points.append(Vector2(lerpf(source_x, target_x, smooth), lerpf(target_y + depth, target_y, t)))
	return points

func _branch_visual_x(route: int, world_y: float) -> float:
	return float(Balance.ROUTE_X[route]) + ScaleLock.vine_visual_offset(route, world_y)

func _draw_branch_ribbon(points: PackedVector2Array, route: int, cap_start: bool, cap_end: bool) -> void:
	var widths := PackedFloat32Array()
	for point in points:
		var spacing: float = BRANCH_NODE_SPACING[route]
		var node_phase := fposmod(-point.y + float(route) * 47.0, spacing)
		var node_distance := minf(node_phase, spacing - node_phase)
		var node_weight := 0.5 + 0.5 * cos(clampf(node_distance / 30.0, 0.0, 1.0) * PI)
		var breathing := sin((-point.y + float(route) * 67.0) * TAU / 390.0) * 4.5
		widths.append(clampf(45.0 + breathing + node_weight * 5.5, 36.0, 56.0))
	# Taper the retained ribbon itself. Painting a taper over a full-width ribbon
	# leaves the old square silhouette visible underneath.
	if cap_start:
		_taper_branch_endpoint(points, widths, true)
	if cap_end:
		_taper_branch_endpoint(points, widths, false)
	# All routes share one material phase; world position must not turn the
	# center vine yellow while its neighbours remain green.
	_draw_textured_ribbon(points, widths, 0.5, true, true, false, 0, 0, true)
	if cap_start and not qa_support_mask:
		_draw_branch_tip_detail(points[0], (points[0] - points[1]).normalized(), route, true)
	if cap_end and not qa_support_mask:
		_draw_branch_tip_detail(points[points.size() - 1], (points[points.size() - 1] - points[points.size() - 2]).normalized(), route, false)

func _taper_branch_endpoint(points: PackedVector2Array, widths: PackedFloat32Array, at_start: bool) -> void:
	var endpoint_index := 0 if at_start else points.size() - 1
	var distance := 0.0
	for offset in range(mini(6, points.size())):
		var index := offset if at_start else points.size() - 1 - offset
		if offset > 0:
			var previous := index - 1 if at_start else index + 1
			distance += points[index].distance_to(points[previous])
		var t := clampf(distance / 42.0, 0.0, 1.0)
		var smooth := t * t * (3.0 - 2.0 * t)
		widths[index] = lerpf(2.0, widths[index], smooth)
	widths[endpoint_index] = 2.0

func _draw_branch_tip_detail(base: Vector2, direction: Vector2, route: int, is_restart: bool) -> void:
	# Atlas quads remain in the shared detail mesh. The curled shoot/leaf hides
	# the mathematical endpoint without restoring a round pipe cap.
	var normal := Vector2(-direction.y, direction.x)
	var side := -1.0 if (route + int(is_restart)) % 2 == 0 else 1.0
	var cell := route % 4 if is_restart else 6 + route % 2
	var size := Vector2(62.0, 62.0) if is_restart else Vector2(54.0, 54.0)
	_draw_branch_detail_sprite(cell, base - direction * 12.0 + normal * side * 9.0, size, direction.angle() + PI * 0.5, side < 0.0)

func _draw_branch_details(stage_number: int, route: int, start_y: float, end_y: float) -> void:
	if qa_support_mask:
		return
	var spacing: float = BRANCH_NODE_SPACING[route]
	var phase := fposmod(float(stage_number * 43 + route * 71), spacing)
	var first_height := -start_y + 46.0
	var node_height := first_height + fposmod(phase - first_height, spacing)
	var node_y := -node_height
	var node_index := int(floor((node_height - phase) / spacing))
	while node_y > end_y + 32.0:
		var direction_noise := _detail_noise(stage_number, route, node_index, 0)
		var outside := -1.0 if direction_noise < 0.5 else 1.0
		if route == 0 and direction_noise < 0.78:
			outside = -1.0
		elif route == 2 and direction_noise < 0.78:
			outside = 1.0
		var stem_x := _branch_visual_x(route, node_y)
		var scale := lerpf(0.84, 1.18, _detail_noise(stage_number, route, node_index, 1))
		var leaf_size := Vector2(78.0, 78.0) * scale
		var angle := lerpf(-0.28, 0.28, _detail_noise(stage_number, route, node_index, 2)) * outside
		var cell := int(floor(_detail_noise(stage_number, route, node_index, 3) * 4.0)) % 4
		# The stem root sits over the knot and the leaf overlaps the ribbon edge.
		var leaf_center := Vector2(stem_x + outside * (27.0 + leaf_size.x * 0.06), node_y - 4.0)
		_draw_branch_detail_sprite(cell, leaf_center, leaf_size, angle, outside < 0.0)
		var ornament := _detail_noise(stage_number, route, node_index, 4)
		if ornament > 0.67:
			var tendril_center := Vector2(stem_x + outside * 29.0, node_y - lerpf(48.0, 61.0, ornament))
			_draw_branch_detail_sprite(6 + (node_index & 1), tendril_center, Vector2(lerpf(58.0, 74.0, scale), lerpf(58.0, 74.0, scale)), angle * 0.7, outside < 0.0)
		elif ornament < 0.24:
			_draw_branch_detail_sprite(4 + (node_index & 1), Vector2(stem_x, node_y), Vector2(52.0, 52.0) * scale, angle * 0.35, node_index % 2 == 0)
		node_y -= spacing
		node_index += 1

func _detail_noise(stage_number: int, route: int, node_index: int, channel: int) -> float:
	var seed := float(stage_number * 97 + route * 193 + node_index * 53 + channel * 29)
	return fposmod(sin(seed * 0.731) * 43758.5453, 1.0)

func _draw_branch_detail_sprite(cell: int, center: Vector2, size: Vector2, rotation: float, flip_x: bool) -> void:
	var column := cell % int(BRANCH_DETAIL_GRID.x)
	var row := cell / int(BRANCH_DETAIL_GRID.x)
	var uv_min := Vector2(float(column), float(row)) / BRANCH_DETAIL_GRID
	var uv_max := Vector2(float(column + 1), float(row + 1)) / BRANCH_DETAIL_GRID
	var basis := Transform2D(rotation, center)
	var base := detail_vertices.size()
	detail_vertices.append(basis * Vector2(-size.x * 0.5, -size.y * 0.5))
	detail_vertices.append(basis * Vector2(size.x * 0.5, -size.y * 0.5))
	detail_vertices.append(basis * Vector2(size.x * 0.5, size.y * 0.5))
	detail_vertices.append(basis * Vector2(-size.x * 0.5, size.y * 0.5))
	var left_u := uv_max.x if flip_x else uv_min.x
	var right_u := uv_min.x if flip_x else uv_max.x
	detail_uvs.append(Vector2(left_u, uv_min.y))
	detail_uvs.append(Vector2(right_u, uv_min.y))
	detail_uvs.append(Vector2(right_u, uv_max.y))
	detail_uvs.append(Vector2(left_u, uv_max.y))
	detail_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

func _flush_branch_details() -> void:
	if detail_vertices.is_empty():
		return
	var mesh := _build_ribbon_mesh(detail_vertices, detail_uvs, detail_indices)
	draw_mesh(mesh, BRANCH_DETAILS_TEXTURE)

func _draw_textured_ribbon(points: PackedVector2Array, widths: PackedFloat32Array, texture_phase: float, draw_outline := true, world_locked_v := false, tangent_uv := false, outline_start_trim := 0, outline_end_trim := 0, branch_material := false, blend_to_branch_material := false) -> void:
	if points.size() < 2:
		return
	var distances := PackedFloat32Array([0.0])
	for point_index in range(1, points.size()):
		distances.append(distances[point_index - 1] + points[point_index - 1].distance_to(points[point_index]))
	var total_distance := distances[distances.size() - 1]
	var vertical_span := absf(points[points.size() - 1].y - points[0].y)
	# Follow the ribbon tangent, then normalize to the same world-Y phase at
	# both ends. This removes the fan-like UV stretch at the Y split without
	# introducing a texture jump where the split meets trunk or branches.
	var endpoint_flow_scale := vertical_span / total_distance if vertical_span > 1.0 and total_distance > 0.0 else 1.0
	# Never stretch a 52 px source feature beyond the §5.1 54 px ceiling.
	var flow_scale := maxf(TEXTURE_REPEAT / MAX_TEXTURE_ELEMENT, endpoint_flow_scale)
	var start_v := -points[0].y / MODULE_HEIGHT if vertical_span > 1.0 else texture_phase
	var extra_width := VISUAL_OUTLINE_WIDTH if qa_support_mask and qa_support_mask_include_outline else 0.0
	var strip := _ribbon_geometry(points, widths, extra_width, texture_phase)
	var mesh_vertices := PackedVector2Array()
	var mesh_uvs := PackedVector2Array()
	var mesh_indices := PackedInt32Array()
	for index in points.size():
		var left: Vector2 = strip.left[index]
		var right: Vector2 = strip.right[index]
		mesh_vertices.append(left)
		mesh_vertices.append(right)
		var center_v := start_v + distances[index] * flow_scale / MODULE_HEIGHT
		if qa_support_mask:
			mesh_uvs.append(Vector2.ZERO)
			mesh_uvs.append(Vector2.RIGHT)
		elif tangent_uv:
			# The source fibers run along V. Mapping V to path distance makes them
			# follow a curved transfer arch instead of forming a vertical barcode.
			mesh_uvs.append(Vector2(texture_phase - widths[index] * 0.5 / 512.0, center_v))
			mesh_uvs.append(Vector2(texture_phase + widths[index] * 0.5 / 512.0, center_v))
		elif branch_material:
			# Every lane samples the same green-lit local band. World-X sampling made
			# the center lane land on the atlas' yellow highlight column.
			var local_half_u := widths[index] * 0.5 / 512.0
			mesh_uvs.append(Vector2(0.19 - local_half_u, center_v))
			mesh_uvs.append(Vector2(0.19 + local_half_u, center_v))
		elif world_locked_v:
			var left_v := -left.y / MODULE_HEIGHT
			var right_v := -right.y / MODULE_HEIGHT
			var left_u := _surface_u(left.x, left_v)
			var right_u := _surface_u(right.x, right_v)
			if blend_to_branch_material:
				var stage_3_bottom := _stage_3_bottom_y()
				var mix_amount := clampf((stage_3_bottom - points[index].y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
				mix_amount = mix_amount * mix_amount * (3.0 - 2.0 * mix_amount)
				var local_half_u := widths[index] * 0.5 / 512.0
				left_u = lerpf(left_u, 0.19 - local_half_u, mix_amount)
				right_u = lerpf(right_u, 0.19 + local_half_u, mix_amount)
			mesh_uvs.append(Vector2(left_u, left_v))
			mesh_uvs.append(Vector2(right_u, right_v))
		else:
			mesh_uvs.append(Vector2(_surface_u(left.x, center_v), center_v))
			mesh_uvs.append(Vector2(_surface_u(right.x, center_v), center_v))
	for index in range(points.size() - 1):
		var left := index * 2
		var right := left + 1
		var next_left := left + 2
		var next_right := left + 3
		mesh_indices.append_array(PackedInt32Array([left, right, next_right, left, next_right, next_left]))
	if not mesh_vertices.is_empty():
		var ribbon_mesh := _build_ribbon_mesh(mesh_vertices, mesh_uvs, mesh_indices)
		if qa_support_mask:
			draw_mesh(ribbon_mesh, null, Transform2D.IDENTITY, Color.WHITE)
		else:
			# One indexed mesh replaces hundreds of identical per-segment canvas
			# commands. UVs and overlap geometry are unchanged.
			draw_mesh(ribbon_mesh, VINE_SURFACE_TEXTURE)
	if not qa_support_mask and draw_outline:
		var edge_geometry := _ribbon_geometry(points, widths, VISUAL_OUTLINE_WIDTH, texture_phase)
		_batch_edge_pair(edge_geometry.left, edge_geometry.right, VISUAL_OUTLINE_WIDTH, outline_start_trim, outline_end_trim)

func _batch_edge_pair(left: PackedVector2Array, right: PackedVector2Array, width: float, start_trim: int, end_trim: int) -> void:
	var finish := left.size() - end_trim
	if finish - start_trim < 2:
		return
	for edge: PackedVector2Array in [left, right]:
		for index in range(start_trim, finish - 1):
			var direction := (edge[index + 1] - edge[index]).normalized()
			var normal := Vector2(-direction.y, direction.x) * width * 0.5
			var base := outline_vertices.size()
			outline_vertices.append(edge[index] - normal)
			outline_vertices.append(edge[index] + normal)
			outline_vertices.append(edge[index + 1] + normal)
			outline_vertices.append(edge[index + 1] - normal)
			outline_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

func _flush_outlines() -> void:
	if outline_vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = outline_vertices
	arrays[Mesh.ARRAY_INDEX] = outline_indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh_cache.append(mesh)
	draw_mesh(mesh, null, Transform2D.IDENTITY, OUTLINE_COLOR)

func _build_ribbon_mesh(vertices: PackedVector2Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh_cache.append(mesh)
	return mesh

func _surface_u(world_x: float, flow_v: float) -> float:
	# The v2 source has no centered motif. World-X phase makes overlapping
	# split ribbons sample identical paint, while the slow drift avoids a
	# ruler-straight vertical repeat without mirroring the source.
	return 0.5 + world_x / 512.0 + sin(flow_v * TAU / 7.3) * 0.035

func _ribbon_geometry(points: PackedVector2Array, widths: PackedFloat32Array, extra_width: float, texture_phase: float) -> Dictionary:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var left_uv := PackedVector2Array()
	var right_uv := PackedVector2Array()
	for index in points.size():
		var tangent: Vector2
		if index == 0:
			tangent = points[1] - points[0]
		elif index == points.size() - 1:
			tangent = points[index] - points[index - 1]
		else:
			tangent = points[index + 1] - points[index - 1]
		tangent = tangent.normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var half_width := widths[index] * 0.5 + extra_width
		left.append(points[index] - normal * half_width)
		right.append(points[index] + normal * half_width)
		# World-locked vertical UVs join trunk/split/branch without mirrored
		# modules. A long-period lateral offset breaks the former V repetition.
		var v := -points[index].y / MODULE_HEIGHT + texture_phase * 0.0
		left_uv.append(Vector2(_surface_u(left[left.size() - 1].x, v), v))
		right_uv.append(Vector2(_surface_u(right[right.size() - 1].x, v), v))
	var polygon := PackedVector2Array()
	var uvs := PackedVector2Array()
	polygon.append_array(left)
	uvs.append_array(left_uv)
	for reverse_index in range(right.size() - 1, -1, -1):
		polygon.append(right[reverse_index])
		uvs.append(right_uv[reverse_index])
	return {"polygon": polygon, "uvs": uvs, "left": left, "right": right}

func _draw_trunk_features(camera_top: float) -> void:
	var camera_bottom := camera_top + 556.0
	for stage_number in [1, 2]:
		var stage_bottom := stages.stage_bottom_y(stage_number)
		for feature: Dictionary in stages.pattern_for_stage(stage_number).trunk_features:
			var center_x := lerpf(-ScaleLock.TRUNK_WIDTH * 0.5, ScaleLock.TRUNK_WIDTH * 0.5, float(feature.x))
			var top_y := stage_bottom - float(feature.occupancy[1])
			var bottom_y := stage_bottom - float(feature.warning_height)
			if bottom_y < camera_top - 100.0 or top_y > camera_bottom + 100.0:
				continue
			var side := -1.0 if feature.x >= 0.5 else 1.0
			var cell := 0 if feature.kind == "GUIDE" else 4
			var size := Vector2(54.0, 54.0) if feature.kind == "GUIDE" else Vector2(86.0, 86.0)
			_draw_foliage_sprite(cell, Vector2(center_x + side * 36.0, (top_y + bottom_y) * 0.5), size, side < 0.0)

func _draw_foliage_sprite(cell: int, center: Vector2, size: Vector2, flip_x := false, modulate := Color.WHITE) -> void:
	if qa_support_mask:
		return
	var column := cell % 3
	var row := cell / 3
	var source := Rect2(Vector2(float(column), float(row)) * FOLIAGE_CELL, FOLIAGE_CELL)
	var destination_size := Vector2(minf(size.x, MAX_LEAF_SIZE), minf(size.y, MAX_LEAF_SIZE))
	var destination := Rect2(center - destination_size * 0.5, destination_size)
	if flip_x:
		destination.position.x += destination.size.x
		destination.size.x *= -1.0
	draw_texture_rect_region(FOLIAGE_TEXTURE, destination, source, modulate)

func sky_color_at(normalized_y: float) -> Color:
	return SKY_TOP.lerp(SKY_BOTTOM, clampf(normalized_y, 0.0, 1.0))

func qa_branch_visual_deviation(route: int, world_y: float) -> float:
	return absf(_branch_visual_x(route, world_y) - float(Balance.ROUTE_X[route]))

func qa_point_inside_support(world_point: Vector2) -> bool:
	var stage_number := stages.stage_for_y(world_point.y)
	if stage_number <= 2:
		return absf(world_point.x - _trunk_center_x(world_point.y)) <= _trunk_half_width(world_point.y)
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	var progress := (stage_bottom - world_point.y) / stage_length
	if stage_number == 3 and progress * stage_length <= STAGE_3_ENTRY_HEIGHT:
		if absf(world_point.x - _main_stem_center_x(world_point.y)) <= _main_stem_width(world_point.y) * 0.5:
			return true
	for route in 3:
		for segment: Array in stages.support_segments(stage_number, route):
			if progress >= float(segment[0]) and progress <= float(segment[1]) and absf(world_point.x - _branch_visual_x(route, world_point.y)) <= ScaleLock.BRANCH_WIDTH * 0.5:
				return true
	return false

func qa_visual_contract() -> Dictionary:
	return {
		"module_height_px": MODULE_HEIGHT,
		"trunk_nominal_width_px": ScaleLock.TRUNK_WIDTH,
		"trunk_render_width_range_px": [160.0, 200.0],
		"branch_width_px": [36.0, 56.0],
		"branch_centers_world_x": Balance.ROUTE_X.duplicate(),
		"texture_repeat_px": MAX_TEXTURE_ELEMENT,
		"grip_detail_px": GRIP_DETAIL_SIZE,
		"max_leaf_px": MAX_LEAF_SIZE,
		"outline_px": VISUAL_OUTLINE_WIDTH,
		"surface_texture": "res://assets/art/world/vine_helix_tile_v4.png",
		"branch_surface_texture": "res://assets/art/world/vine_helix_tile_v4.png",
		"branch_detail_atlas": "res://assets/art/world/vine_details_atlas_v2.png",
		"branch_node_spacing_px": BRANCH_NODE_SPACING.duplicate(),
		"stage_3_layout": "continuous_middle_with_separate_side_vines",
		"split_union_count": 0,
		"transfer_bridge_count": 0,
		"side_vine_entry_world_y": _stage_3_bottom_y() + maxf(SIDE_VINE_MIN_ENTRY_DEPTH, absf(SIDE_VINE_OFFSCREEN_X - float(Balance.ROUTE_X[2])) * SIDE_VINE_ENTRY_DEPTH_PER_X),
		"side_vine_entry_world_x": [-SIDE_VINE_OFFSCREEN_X, SIDE_VINE_OFFSCREEN_X],
		"foliage_atlas": "res://assets/art/world/foliage_atlas.png",
		"procedural_circle_cloud_count": 0,
		"flat_polygon_leaf_count": 0,
		"airborne_transfer_foliage_count": 0,
		"gameplay_branch_tip_foliage_count": 0,
		"atmosphere_layers": ["painted_far_plate", "distant_bean_silhouettes", "cream_clouds_in_plate", "imagegen_foreground_foliage"],
	}

func _stage_3_bottom_y() -> float:
	if stages != null:
		return stages.stage_bottom_y(3)
	return -float(StageDatabase.stage(3).start_height)
