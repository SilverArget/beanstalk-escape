extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const BRANCH_DETAILS_TEXTURE := preload("res://assets/art/world/vine_details_atlas_v2.png")
const FOLIAGE_TEXTURE := preload("res://assets/art/world/foliage_atlas.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")
const MODULE_HEIGHT := 256.0
const MAX_TEXTURE_ELEMENT := 54.0
const GRIP_DETAIL_SIZE := 12.0
const MAX_LEAF_SIZE := 140.0
const VISUAL_OUTLINE_WIDTH := 1.0
# Two complete cylinders exchange depth; neither is a full-width backing plate.
const SHOOT_PITCH := 610.0
const SHOOT_PROFILE := [0.0, 0.035, 0.09, 0.18, 0.30, 0.43, 0.56, 0.69, 0.81, 0.91, 0.965, 1.0]
const SHOOT_COLORS := [Color("164b24"), Color("237329"), Color("37a925"), Color("61d62b"), Color("9aef45"), Color("85e939"), Color("63d52c"), Color("43b526"), Color("2a9227"), Color("207127"), Color("185526"), Color("164b24")]
const SHOOT_EDGE_FEATHER := 1.5
const SHOOT_FIBER_TILE := Vector2(64.0, 256.0)
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
var shoot_fiber_texture: ImageTexture
var detail_vertices := PackedVector2Array()
var detail_uvs := PackedVector2Array()
var detail_indices := PackedInt32Array()

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
	branch_point_count = 0
	var camera_top := cached_camera_top if not is_inf(cached_camera_top) else _camera_top()
	if qa_sky_only:
		return
	_draw_trunk(camera_top)
	if not qa_support_mask:
		_draw_trunk_features(camera_top)
	_draw_stage_branches(camera_top)
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
	pass

func _draw_trunk(camera_top: float) -> void:
	# World-Y phase continues through the narrowing middle vine into Stage 3.
	var transition_top_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
	var visible_top := maxf(transition_top_y, camera_top - 64.0 - SURFACE_CACHE_MARGIN_PX)
	var visible_bottom := minf(740.0, camera_top + 620.0 + SURFACE_CACHE_MARGIN_PX)
	if visible_bottom <= visible_top:
		return
	var centers := PackedVector2Array()
	var y := visible_bottom
	while y > visible_top:
		centers.append(Vector2(_main_stem_center_x(y), y))
		y = maxf((ceil(y / 12.0) - 1.0) * 12.0, visible_top)
	if centers.is_empty() or centers[centers.size() - 1].y != visible_top:
		centers.append(Vector2(_main_stem_center_x(visible_top), visible_top))
	_draw_textured_ribbon(centers, _trunk_widths(centers))
	if not qa_support_mask:
		_draw_stem_growth(visible_top, visible_bottom)

func _trunk_widths(points: PackedVector2Array) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for point in points:
		var width := _main_stem_width(point.y)
		# Match the branch's actual painted width at the join, without changing
		# the authored main-stem width or any support calculation.
		var join_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
		var join_mix := 1.0 - smoothstep(join_y, join_y + 96.0, point.y)
		width += (_branch_painted_width(1, point.y) - ScaleLock.BRANCH_WIDTH) * join_mix
		widths.append(width)
	return widths

func _draw_stem_growth(top_y: float, bottom_y: float) -> void:
	# Stable world-space nodes survive surface-cache scrolls without popping.
	var node := int(ceil(top_y / 157.0))
	while float(node) * 157.0 < bottom_y:
		var y := float(node) * 157.0 + sin(float(node) * 2.3) * 23.0
		var side := -1.0 if posmod(node, 2) == 0 else 1.0
		if posmod(node, 3) == 0:
			var curl_size := 76.0 + 12.0 * _detail_noise(1, 0, node, 3)
			var curl_angle := -side * 0.55
			var curl_root := Vector2(_main_stem_center_x(y + 57.0) - side * _main_stem_width(y + 57.0) * 0.34, y + 57.0)
			var curl_center := curl_root - Vector2(0.0, curl_size * 0.4).rotated(curl_angle)
			_draw_branch_detail_sprite(6 + posmod(node, 2), curl_center, Vector2.ONE * curl_size, curl_angle, side > 0.0)
		node += 1

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

func _draw_stage_branches(camera_top: float) -> void:
	var visible_bottom := camera_top + 556.0 + 160.0 + SURFACE_CACHE_MARGIN_PX
	var visible_top := camera_top - 160.0 - SURFACE_CACHE_MARGIN_PX
	for route in 3:
		# Union touching support intervals before clipping or building geometry.
		# A stage/support boundary is not a botanical endpoint.
		var spans: Array[Vector3] = []
		for stage_number in range(3, Balance.STAGE_COUNT + 1):
			var bottom := stages.stage_bottom_y(stage_number)
			var length := stages.stage_length(stage_number)
			for segment: Array in stages.support_segments(stage_number, route):
				spans.append(Vector3(bottom - float(segment[0]) * length, bottom - float(segment[1]) * length, stage_number))
		spans.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x > b.x)
		var joined: Array[Vector3] = []
		for span in spans:
			if not joined.is_empty() and span.x >= joined[joined.size() - 1].y - 0.01:
				joined[joined.size() - 1].y = minf(joined[joined.size() - 1].y, span.y)
			else:
				joined.append(span)
		for span in joined:
			var start_y := minf(span.x, visible_bottom)
			var end_y := maxf(span.y, visible_top)
			if start_y <= end_y:
				continue
			var stage_number := int(span.z)
			var bottom := stages.stage_bottom_y(stage_number)
			var length := stages.stage_length(stage_number)
			_draw_branch_segment(stage_number, route, (bottom - start_y) / length, (bottom - end_y) / length, is_equal_approx(start_y, span.x), is_equal_approx(end_y, span.y))

func _draw_branch_segment(stage_number: int, route: int, start_progress: float, end_progress: float, show_start_tip := true, show_end_tip := true) -> void:
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	var cap_start := start_progress > 0.0 and show_start_tip
	if stage_number == 3 and route == 1 and start_progress <= 0.0:
		start_progress = STAGE_3_ENTRY_HEIGHT / stage_length
	if end_progress <= start_progress:
		return
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
		cursor_y = maxf((ceilf(cursor_y / 12.0) - 1.0) * 12.0, end_y)
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
		widths.append(_branch_painted_width(route, point.y))
	# Taper the retained ribbon itself. Painting a taper over a full-width ribbon
	# leaves the old square silhouette visible underneath.
	if cap_start:
		_taper_branch_endpoint(points, widths, true)
	if cap_end:
		_taper_branch_endpoint(points, widths, false)
	_draw_textured_ribbon(points, widths)
	if cap_start and not qa_support_mask:
		_draw_branch_tip_detail(points[0], (points[0] - points[1]).normalized(), route, true)
	if cap_end and not qa_support_mask:
		_draw_branch_tip_detail(points[points.size() - 1], (points[points.size() - 1] - points[points.size() - 2]).normalized(), route, false)

func _branch_painted_width(route: int, world_y: float) -> float:
	var spacing: float = BRANCH_NODE_SPACING[route]
	var node_phase := fposmod(-world_y + float(route) * 47.0, spacing)
	var node_distance := minf(node_phase, spacing - node_phase)
	var node_weight := 0.5 + 0.5 * cos(clampf(node_distance / 30.0, 0.0, 1.0) * PI)
	var breathing := sin((-world_y + float(route) * 67.0) * TAU / 390.0) * 4.5
	return clampf(45.0 + breathing + node_weight * 5.5, 36.0, 56.0)

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
	# Keep curled tips; restart tips previously used leaf atlas cells.
	if is_restart:
		return
	var normal := Vector2(-direction.y, direction.x)
	var side := -1.0 if (route + int(is_restart)) % 2 == 0 else 1.0
	var cell := 6 + route % 2
	var size := Vector2(54.0, 54.0)
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
		var angle := lerpf(-0.28, 0.28, _detail_noise(stage_number, route, node_index, 2)) * outside
		var ornament := _detail_noise(stage_number, route, node_index, 4)
		if ornament > 0.67:
			var tendril_center := Vector2(stem_x + outside * 29.0, node_y - lerpf(48.0, 61.0, ornament))
			_draw_branch_detail_sprite(6 + (node_index & 1), tendril_center, Vector2(lerpf(58.0, 74.0, scale), lerpf(58.0, 74.0, scale)), angle * 0.7, outside < 0.0)
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

func _draw_textured_ribbon(points: PackedVector2Array, widths: PackedFloat32Array) -> void:
	if points.size() < 2:
		return
	var strip := _ribbon_geometry(points, widths, 0.0)
	if qa_support_mask:
		var mask_width := VISUAL_OUTLINE_WIDTH if qa_support_mask_include_outline else 0.0
		var mask := _ribbon_geometry(points, widths, mask_width)
		var vertices := PackedVector2Array()
		var indices := PackedInt32Array()
		for index in points.size():
			vertices.append(mask.left[index])
			vertices.append(mask.right[index])
			if index > 0:
				var base := (index - 1) * 2
				indices.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))
		draw_mesh(_build_ribbon_mesh(vertices, PackedVector2Array(), indices), null, Transform2D.IDENTITY, Color.WHITE)
		return
	if shoot_fiber_texture == null:
		shoot_fiber_texture = _make_shoot_fiber_texture()
	# Two meshes total, one per depth layer, including fibers, contact shadows
	# and feathered edges. Physical shoots swap layers only at their side-by-side
	# contact, where their projected interiors no longer overlap.
	# Keep world-anchored rows: clipping/cache movement must not move a crossing.
	var rows := PackedVector2Array()
	var row_widths := PackedFloat32Array()
	for index in range(points.size() - 1):
		rows.append(points[index])
		row_widths.append(widths[index])
		var upper_y := points[index + 1].y
		var lower_y := points[index].y
		var cursor_y := floorf(lower_y / 6.0) * 6.0
		while cursor_y > upper_y:
			if cursor_y < lower_y:
				var t := inverse_lerp(lower_y, upper_y, cursor_y)
				rows.append(points[index].lerp(points[index + 1], t))
				row_widths.append(lerpf(widths[index], widths[index + 1], t))
			cursor_y -= 6.0
	rows.append(points[points.size() - 1])
	row_widths.append(widths[widths.size() - 1])
	# Split both depth swaps and outer-edge ownership changes. Across a sine
	# zero the two cylinders exchange silhouette sides; without that exact row,
	# both interpolated edges retreat inside the envelope and leave a notch.
	for index in range(rows.size() - 2, -1, -1):
		var a := rows[index].y
		var b := rows[index + 1].y
		for phase_offset in [0.0, PI * 0.5]:
			if sin(_shoot_phase(a) + phase_offset) * sin(_shoot_phase(b) + phase_offset) >= 0.0:
				continue
			var lower := a
			var upper := b
			for iteration in 16:
				var middle := (lower + upper) * 0.5
				if sin(_shoot_phase(lower) + phase_offset) * sin(_shoot_phase(middle) + phase_offset) > 0.0:
					lower = middle
				else:
					upper = middle
			var t := inverse_lerp(a, b, (lower + upper) * 0.5)
			rows.insert(index + 1, rows[index].lerp(rows[index + 1], t))
			row_widths.insert(index + 1, lerpf(row_widths[index], row_widths[index + 1], t))
	strip = _ribbon_geometry(rows, row_widths, 0.0)
	for layer in 2:
		var vertices := PackedVector2Array()
		var colors := PackedColorArray()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		var columns := SHOOT_PROFILE.size() + 10
		for index in range(rows.size() - 1):
			var middle_y := (rows[index].y + rows[index + 1].y) * 0.5
			var front_shoot := 0 if cos(_shoot_phase(middle_y)) >= 0.0 else 1
			var shoot := front_shoot if layer == 1 else 1 - front_shoot
			var base := vertices.size()
			for row in [index, index + 1]:
				_append_shoot_row(vertices, colors, uvs, strip.left[row], strip.right[row], rows[row].y, shoot, front_shoot)
			for column in range(columns - 1):
				var offset := base + column
				indices.append_array(PackedInt32Array([offset, offset + 1, offset + columns + 1, offset, offset + columns + 1, offset + columns]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draw_mesh_cache.append(mesh)
		draw_mesh(mesh, shoot_fiber_texture)

func _append_shoot_row(vertices: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, left: Vector2, right: Vector2, world_y: float, shoot: int, front_shoot: int) -> void:
	var across := right - left
	var width := across.length()
	var normal := across.normalized()
	var phase := _shoot_phase(world_y)
	var winding := sin(phase)
	# The authored envelope alone owns the silhouette. Winding changes the
	# interior overlap, never the outer width or the constant-pixel edge fringe.
	var radius := width * 0.5 / (1.0 + absf(winding))
	var side := 1.0 if shoot == 0 else -1.0
	var center_offset := side * winding * radius
	var center := (left + right) * 0.5 + normal * center_offset
	var front_offset := (1.0 if front_shoot == 0 else -1.0) * winding * radius
	var diameter := maxf(radius * 2.0, 0.001)
	var profile: Array = SHOOT_PROFILE.duplicate()
	# Extra samples put the contact shadow's falloff at the occluder's actual
	# edge, including on a wide trunk, rather than smearing it across a face.
	for edge in [-1.0, 1.0]:
		for distance in [0.0, 2.5, 6.0]:
			profile.append(clampf((front_offset + edge * (radius + distance) - center_offset + radius) / diameter, 0.0, 1.0))
	# One dark edge with a 1.5 px alpha fringe, in the same mesh as the body.
	profile.append(minf(1.0 / diameter, 0.035))
	profile.append(maxf(1.0 - 1.0 / diameter, 0.965))
	profile.append(-SHOOT_EDGE_FEATHER / diameter)
	profile.append(1.0 + SHOOT_EDGE_FEATHER / diameter)
	profile.sort()
	var depth := cos(phase + float(shoot) * PI)
	var light := lerpf(0.67, 1.05, (depth + 1.0) * 0.5)
	light *= 0.97 + 0.03 * sin(world_y * TAU / 347.0 + float(shoot))
	for value: float in profile:
		var u := clampf(value, 0.0, 1.0)
		var color := _shoot_surface_color(u)
		var shadow := 1.0
		if shoot != front_shoot:
			var x := center_offset + (u - 0.5) * diameter
			var distance := maxf(absf(x - front_offset) - radius, 0.0)
			# At the side-by-side crossing, front/back identity changes. Fade the
			# contact shadow to zero there so both incident rows shade identically.
			var overlap := smoothstep(0.0, 0.25, absf(cos(phase)))
			shadow -= 0.32 * overlap * (1.0 - smoothstep(0.0, 6.0, distance))
		var alpha := 1.0
		if value < 0.0 or value > 1.0:
			alpha = 0.0
		vertices.append(center + normal * ((value - 0.5) * diameter))
		colors.append(Color(color.r * light * shadow, color.g * light * shadow, color.b * light * shadow, alpha))
		# Local cross-section and world height make fibers follow the winding
		# shoot, with fixed pixel density and no reset at stage/cache boundaries.
		uvs.append(Vector2(value * diameter / SHOOT_FIBER_TILE.x + float(shoot) * 0.37, -world_y / SHOOT_FIBER_TILE.y))

func _shoot_surface_color(u: float) -> Color:
	for index in range(SHOOT_PROFILE.size() - 1):
		if u <= SHOOT_PROFILE[index + 1]:
			var t := inverse_lerp(SHOOT_PROFILE[index], SHOOT_PROFILE[index + 1], u)
			return SHOOT_COLORS[index].lerp(SHOOT_COLORS[index + 1], t)
	return SHOOT_COLORS[SHOOT_COLORS.size() - 1]

func _make_shoot_fiber_texture() -> ImageTexture:
	# Small, neutral pigment map generated once, not on surface-cache redraws.
	# Integer frequencies wrap seamlessly; long, gently wandering fibers and
	# broad brush variation add texture without painting another spiral band.
	var image := Image.create(128, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		var v := float(y) / 256.0 * TAU
		for x in 128:
			var u := float(x) / 128.0 * TAU
			var drift := sin(v) * 0.15 + sin(v * 3.0 + u) * 0.05
			var fiber := sin(u * 23.0 + drift * 3.0) * sin(u * 9.0 - drift)
			var vein := pow(maxf(sin(u * 13.0 + sin(v * 2.0) * 0.4), 0.0), 10.0)
			var brush := sin(u * 3.0 + sin(v)) * sin(v * 5.0 + u * 2.0)
			var pigment := 0.94 + fiber * 0.025 - vein * 0.055 + brush * 0.02
			image.set_pixel(x, y, Color(pigment, pigment, pigment, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _shoot_phase(world_y: float) -> float:
	# Absolute height, shared by trunk and all branches: no phase reset at
	# stage boundaries, no camera-relative swimming and no tiled rope motif.
	return world_y * TAU / SHOOT_PITCH + sin(world_y * TAU / 1370.0) * 0.22

func _build_ribbon_mesh(vertices: PackedVector2Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	draw_mesh_cache.append(mesh)
	return mesh

func _ribbon_geometry(points: PackedVector2Array, widths: PackedFloat32Array, extra_width: float) -> Dictionary:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var join_y := _stage_3_bottom_y() - STAGE_3_ENTRY_HEIGHT
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
		# The authored transition has a vertical end tangent. Share its exact
		# cross-section on both meshes rather than leaving two angled end caps.
		if is_equal_approx(points[index].y, join_y) and is_equal_approx(points[index].x, _branch_visual_x(1, join_y)):
			normal = Vector2.RIGHT
		var half_width := widths[index] * 0.5 + extra_width
		left.append(points[index] - normal * half_width)
		right.append(points[index] + normal * half_width)
	return {"left": left, "right": right}

func _draw_trunk_features(camera_top: float) -> void:
	pass

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
		"surface_texture": "procedural_longitudinal_shoot_fibers",
		"branch_surface_texture": "procedural_longitudinal_shoot_fibers",
		"shoot_meshes_per_ribbon": 2,
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
