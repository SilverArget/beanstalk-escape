extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const VINE_SURFACE_TEXTURE := preload("res://assets/art/world/vine_surface_tile_v3.png")
const BRANCH_SURFACE_TEXTURE := preload("res://assets/art/world/bean_branch_surface_v1.png")
const BRANCH_DETAILS_TEXTURE := preload("res://assets/art/world/bean_branch_details_v1.png")
const FOLIAGE_TEXTURE := preload("res://assets/art/world/foliage_atlas.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")
const OUTLINE_COLOR := Color8(50, 105, 84)
const VINE_BASE_COLOR := Color("4c9a4d")
const MODULE_HEIGHT := 256.0
const TEXTURE_REPEAT := 52.0
const MAX_TEXTURE_ELEMENT := 54.0
const GRIP_DETAIL_SIZE := 12.0
const MAX_LEAF_SIZE := 140.0
const VISUAL_OUTLINE_WIDTH := 3.0
const FOLIAGE_CELL := Vector2(512.0, 512.0)
const BRANCH_DETAIL_GRID := Vector2(4.0, 2.0)
const BRANCH_NODE_SPACING := 150.0
const STAGE_3_ENTRY_HEIGHT := 350.0
const SIDE_VINE_ENTRY_DEPTH := 240.0
const SIDE_VINE_OFFSCREEN_X := 560.0

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

var branch_graph := BranchGraph.new()
var redraw_count := 0
var branch_point_count := 0
var qa_storm_background := false
var qa_support_mask := false
var qa_support_mask_include_outline := false
var qa_sky_only := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	redraw_count += 1
	branch_point_count = 0
	var camera_top := player.global_position.y - ScaleLock.CHARACTER_REFERENCE_Y if player != null else -270.0
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera_top = camera.get_screen_center_position().y - get_viewport_rect().size.y * 0.5
	_draw_sky(camera_top)
	if qa_sky_only:
		return
	_draw_trunk(camera_top)
	if not qa_support_mask:
		_draw_trunk_features(camera_top)
	for stage_number in range(3, Balance.STAGE_COUNT + 1):
		_draw_stage_branches(stage_number, camera_top)

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
	var transition_top_y := -Balance.STAGE_HEIGHT * 2.0 - STAGE_3_ENTRY_HEIGHT
	var visible_top := maxf(transition_top_y, camera_top - 64.0)
	var visible_bottom := minf(740.0, camera_top + 620.0)
	if visible_bottom <= visible_top:
		return
	var centers := PackedVector2Array()
	var y := visible_bottom
	while y > visible_top:
		centers.append(Vector2(_main_stem_center_x(y), y))
		y = maxf(y - 32.0, visible_top)
	if centers.is_empty() or centers[centers.size() - 1].y != visible_top:
		centers.append(Vector2(_main_stem_center_x(visible_top), visible_top))
	_draw_textured_ribbon(centers, _trunk_widths(centers), -visible_bottom / MODULE_HEIGHT, true, true)

func _trunk_widths(points: PackedVector2Array) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for point in points:
		widths.append(_main_stem_width(point.y))
	return widths

func _main_stem_center_x(world_y: float) -> float:
	var stage_3_bottom := -Balance.STAGE_HEIGHT * 2.0
	if world_y >= stage_3_bottom:
		return _trunk_center_x(world_y)
	var t := clampf((stage_3_bottom - world_y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
	var smooth := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return lerpf(_trunk_center_x(stage_3_bottom), _branch_visual_x(1, stage_3_bottom - STAGE_3_ENTRY_HEIGHT), smooth)

func _main_stem_width(world_y: float) -> float:
	var stage_3_bottom := -Balance.STAGE_HEIGHT * 2.0
	if world_y >= stage_3_bottom:
		return _trunk_half_width(world_y) * 2.0
	var t := clampf((stage_3_bottom - world_y) / STAGE_3_ENTRY_HEIGHT, 0.0, 1.0)
	var smooth := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
	return lerpf(_trunk_half_width(stage_3_bottom) * 2.0, ScaleLock.BRANCH_WIDTH, smooth)

func _trunk_center_x(world_y: float) -> float:
	return sin(world_y * 0.0041) * 5.0 + sin(world_y * 0.0107) * 2.5

func _trunk_half_width(world_y: float) -> float:
	return 90.0 + sin(world_y * TAU / MODULE_HEIGHT) * 4.0

func _draw_stage_branches(stage_number: int, camera_top: float) -> void:
	var stage_bottom := stages.stage_bottom_y(stage_number)
	var stage_length := stages.stage_length(stage_number)
	var stage_top := stage_bottom - stage_length
	var camera_bottom := camera_top + 556.0
	if stage_bottom < camera_top - 120.0 or stage_top > camera_bottom + 120.0:
		return
	var visible_start := clampf((stage_bottom - (camera_bottom + 160.0)) / stage_length, 0.0, 1.0)
	var visible_end := clampf((stage_bottom - (camera_top - 160.0)) / stage_length, 0.0, 1.0)
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
		start_progress = STAGE_3_ENTRY_HEIGHT / Balance.STAGE_HEIGHT
	var start_y := stage_bottom - start_progress * stage_length
	var end_y := stage_bottom - end_progress * stage_length
	var points := PackedVector2Array()
	if stage_number == 3 and route != 1 and start_progress <= 0.0:
		points = _side_vine_entry_points(route, stage_bottom)
		cap_start = false
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
	_draw_branch_details(route, start_y, end_y)

func _side_vine_entry_points(route: int, stage_bottom: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var side := -1.0 if route == 0 else 1.0
	for step in 17:
		var t := float(step) / 16.0
		var smooth := t * t * (3.0 - 2.0 * t)
		var y := lerpf(stage_bottom + SIDE_VINE_ENTRY_DEPTH, stage_bottom, t)
		var x := lerpf(side * SIDE_VINE_OFFSCREEN_X, _branch_visual_x(route, stage_bottom), smooth)
		points.append(Vector2(x, y))
	return points

func _branch_visual_x(route: int, world_y: float) -> float:
	# Gameplay remains on Balance.ROUTE_X. This visual-only S wave stays within
	# the 44 px support, replacing the former ruler-straight tube.
	return float(Balance.ROUTE_X[route]) + sin((world_y + float(route) * 83.0) * 0.0085) * 5.5

func _draw_branch_ribbon(points: PackedVector2Array, route: int, cap_start: bool, cap_end: bool) -> void:
	var widths := PackedFloat32Array()
	for point in points:
		var node_phase := fposmod(-point.y + float(route) * 31.0, BRANCH_NODE_SPACING)
		var node_distance := minf(node_phase, BRANCH_NODE_SPACING - node_phase)
		var node_weight := 0.5 + 0.5 * cos(clampf(node_distance / 30.0, 0.0, 1.0) * PI)
		widths.append(ScaleLock.BRANCH_WIDTH + node_weight * 3.0)
	# All routes share one material phase; world position must not turn the
	# center vine yellow while its neighbours remain green.
	_draw_textured_ribbon(points, widths, 0.5, true, true, false, 0, 0, true)
	if cap_start and not qa_support_mask:
		_draw_branch_tip(points[0], (points[0] - points[1]).normalized(), route)
	if cap_end and not qa_support_mask:
		_draw_branch_tip(points[points.size() - 1], (points[points.size() - 1] - points[points.size() - 2]).normalized(), route)

func _draw_branch_tip(base: Vector2, direction: Vector2, route: int) -> void:
	# The taper ends exactly at the gameplay endpoint: no rounded pipe cap and
	# no visual promise of support beyond the real segment.
	var normal := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array([
		base - direction * 20.0,
		base - direction * 12.0 + normal * 0.8,
		base - direction * 5.0 - normal * 0.6,
		base,
	])
	var widths := PackedFloat32Array([ScaleLock.BRANCH_WIDTH, 38.0, 20.0, 2.0])
	_draw_textured_ribbon(points, widths, float(route) * 0.27, true, false, true, 0, 0, true)
	# A painted bud and paired leaf conceal the mathematical endpoint. Separate
	# stems still end independently; this never draws a bridge or Y union.
	draw_circle(base - direction * 3.0, 7.0, Color("5cad50"))
	_draw_branch_detail_sprite(4 + route % 2, base - direction * 15.0, Vector2(42.0, 42.0), direction.angle() + PI * 0.5, false)

func _draw_branch_details(route: int, start_y: float, end_y: float) -> void:
	if qa_support_mask:
		return
	var node_y := start_y - 82.0
	var node_index := 0
	while node_y > end_y + 32.0:
		var outside := -1.0 if route == 0 else (1.0 if route == 2 else (-1.0 if node_index % 2 == 0 else 1.0))
		var stem_x := _branch_visual_x(route, node_y)
		var leaf_center := Vector2(stem_x + outside * 39.0, node_y)
		_draw_branch_detail_sprite(node_index % 2, leaf_center, Vector2(40.0, 40.0), 0.0, outside < 0.0)
		if node_index % 3 == 1:
			var tendril_center := Vector2(stem_x + outside * 38.0, node_y - 54.0)
			_draw_branch_detail_sprite(2 + node_index % 2, tendril_center, Vector2(36.0, 36.0), 0.0, outside < 0.0)
		node_y -= BRANCH_NODE_SPACING
		node_index += 1

func _draw_branch_detail_sprite(cell: int, center: Vector2, size: Vector2, rotation: float, flip_x: bool) -> void:
	var cell_size := Vector2(BRANCH_DETAILS_TEXTURE.get_width(), BRANCH_DETAILS_TEXTURE.get_height()) / BRANCH_DETAIL_GRID
	var column := cell % int(BRANCH_DETAIL_GRID.x)
	var row := cell / int(BRANCH_DETAIL_GRID.x)
	var source := Rect2(Vector2(float(column), float(row)) * cell_size, cell_size)
	draw_set_transform(center, rotation, Vector2(-1.0 if flip_x else 1.0, 1.0))
	draw_texture_rect_region(BRANCH_DETAILS_TEXTURE, Rect2(-size * 0.5, size), source)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_textured_ribbon(points: PackedVector2Array, widths: PackedFloat32Array, texture_phase: float, draw_outline := true, world_locked_v := false, tangent_uv := false, outline_start_trim := 0, outline_end_trim := 0, branch_material := false) -> void:
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
	for index in range(points.size() - 1):
		var first := points[index]
		var second := points[index + 1]
		var tangent := (second - first).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		# Adjacent textured quads overlap by 1.25 px. The UV remains locked to
		# world Y, so the overlap is identical paint rather than a visible cap.
		var extended_first := first - tangent * 1.25
		var extended_second := second + tangent * 1.25
		var first_half := widths[index] * 0.5
		var second_half := widths[index + 1] * 0.5
		var quad := PackedVector2Array([
			extended_first - normal * first_half,
			extended_first + normal * first_half,
			extended_second + normal * second_half,
			extended_second - normal * second_half,
		])
		if qa_support_mask:
			if qa_support_mask_include_outline:
				var mask_outline_quad := PackedVector2Array([
					extended_first - normal * (first_half + VISUAL_OUTLINE_WIDTH),
					extended_first + normal * (first_half + VISUAL_OUTLINE_WIDTH),
					extended_second + normal * (second_half + VISUAL_OUTLINE_WIDTH),
					extended_second - normal * (second_half + VISUAL_OUTLINE_WIDTH),
				])
				draw_colored_polygon(mask_outline_quad, Color.WHITE)
			else:
				draw_colored_polygon(quad, Color.WHITE)
			continue
		var first_v := -extended_first.y / MODULE_HEIGHT if world_locked_v else start_v + (distances[index] - 1.25 * flow_scale) / MODULE_HEIGHT
		var second_v := -extended_second.y / MODULE_HEIGHT if world_locked_v else start_v + (distances[index + 1] + 1.25 * flow_scale) / MODULE_HEIGHT
		var first_left := extended_first - normal * first_half
		var first_right := extended_first + normal * first_half
		var second_left := extended_second - normal * second_half
		var second_right := extended_second + normal * second_half
		var uvs: PackedVector2Array
		if tangent_uv:
			# The source fibers run along V. Mapping V to path distance makes them
			# follow a curved transfer arch instead of forming a vertical barcode.
			var first_u := texture_phase - first_half / 512.0
			var second_u := texture_phase + first_half / 512.0
			var third_u := texture_phase + second_half / 512.0
			var fourth_u := texture_phase - second_half / 512.0
			uvs = PackedVector2Array([
				Vector2(first_u, first_v), Vector2(second_u, first_v),
				Vector2(third_u, second_v), Vector2(fourth_u, second_v),
			])
		elif world_locked_v:
			var first_left_v := -first_left.y / MODULE_HEIGHT
			var first_right_v := -first_right.y / MODULE_HEIGHT
			var second_right_v := -second_right.y / MODULE_HEIGHT
			var second_left_v := -second_left.y / MODULE_HEIGHT
			uvs = PackedVector2Array([
				Vector2(_surface_u(first_left.x, first_left_v), first_left_v), Vector2(_surface_u(first_right.x, first_right_v), first_right_v),
				Vector2(_surface_u(second_right.x, second_right_v), second_right_v), Vector2(_surface_u(second_left.x, second_left_v), second_left_v),
			])
		else:
			uvs = PackedVector2Array([
				Vector2(_surface_u(first_left.x, first_v), first_v), Vector2(_surface_u(first_right.x, first_v), first_v),
				Vector2(_surface_u(second_right.x, second_v), second_v), Vector2(_surface_u(second_left.x, second_v), second_v),
			])
		var texture_modulate := Color.WHITE
		# One world-locked paint source crosses trunk, fork and supports. Changing
		# textures at either join produced a horizontal tone/phase step.
		var surface_texture: Texture2D = VINE_SURFACE_TEXTURE
		draw_polygon(quad, PackedColorArray([texture_modulate, texture_modulate, texture_modulate, texture_modulate]), uvs, surface_texture)
		# This glaze is a uniform material treatment for every narrow support. It
		# never depends on the player position or follows the camera/player.
		var glaze_alpha := 0.14
		if glaze_alpha > 0.001:
			draw_colored_polygon(quad, Color(0.78, 0.90, 0.42, glaze_alpha))
	if not qa_support_mask and draw_outline:
		var edge_geometry := _ribbon_geometry(points, widths, VISUAL_OUTLINE_WIDTH, texture_phase)
		_draw_trimmed_edge_pair(edge_geometry.left, edge_geometry.right, VISUAL_OUTLINE_WIDTH, outline_start_trim, outline_end_trim)

func _draw_trimmed_edge_pair(left: PackedVector2Array, right: PackedVector2Array, width: float, start_trim: int, end_trim: int) -> void:
	var finish := left.size() - end_trim
	for index in range(start_trim, finish - 1):
		draw_line(left[index], left[index + 1], OUTLINE_COLOR, width, true)
		draw_line(right[index], right[index + 1], OUTLINE_COLOR, width, true)

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
		"trunk_render_width_range_px": [172.0, 188.0],
		"branch_width_px": ScaleLock.BRANCH_WIDTH,
		"branch_centers_world_x": Balance.ROUTE_X.duplicate(),
		"texture_repeat_px": MAX_TEXTURE_ELEMENT,
		"grip_detail_px": GRIP_DETAIL_SIZE,
		"max_leaf_px": MAX_LEAF_SIZE,
		"outline_px": VISUAL_OUTLINE_WIDTH,
		"surface_texture": "res://assets/art/world/vine_surface_tile_v3.png",
		"branch_surface_texture": "res://assets/art/world/vine_surface_tile_v3.png",
		"branch_detail_atlas": "res://assets/art/world/bean_branch_details_v1.png",
		"branch_node_spacing_px": BRANCH_NODE_SPACING,
		"stage_3_layout": "continuous_middle_with_separate_side_vines",
		"split_union_count": 0,
		"transfer_bridge_count": 0,
		"side_vine_entry_world_y": -Balance.STAGE_HEIGHT * 2.0 + SIDE_VINE_ENTRY_DEPTH,
		"side_vine_entry_world_x": [-SIDE_VINE_OFFSCREEN_X, SIDE_VINE_OFFSCREEN_X],
		"foliage_atlas": "res://assets/art/world/foliage_atlas.png",
		"procedural_circle_cloud_count": 0,
		"flat_polygon_leaf_count": 0,
		"airborne_transfer_foliage_count": 0,
		"gameplay_branch_tip_foliage_count": 0,
		"atmosphere_layers": ["painted_far_plate", "distant_bean_silhouettes", "cream_clouds_in_plate", "imagegen_foreground_foliage"],
	}
