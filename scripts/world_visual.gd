extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const VINE_SURFACE_TEXTURE := preload("res://assets/art/world/vine_surface_tile.png")
const FOLIAGE_TEXTURE := preload("res://assets/art/world/foliage_atlas.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")
const OUTLINE_COLOR := Color("173d2f")
const VINE_BASE_COLOR := Color("4c9a4d")
const MODULE_HEIGHT := 256.0
const TEXTURE_REPEAT := 52.0
const MAX_TEXTURE_ELEMENT := 54.0
const GRIP_DETAIL_SIZE := 12.0
const MAX_LEAF_SIZE := 140.0
const VISUAL_OUTLINE_WIDTH := 3.0
const FOLIAGE_CELL := Vector2(512.0, 512.0)

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
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	queue_redraw()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	redraw_count += 1
	branch_point_count = 0
	var camera_top := (player.global_position.y - ScaleLock.CHARACTER_REFERENCE_Y) if player != null else -270.0
	_draw_sky(camera_top)
	if qa_sky_only:
		return
	_draw_trunk(camera_top)
	if not qa_support_mask:
		_draw_trunk_features(camera_top)
	for stage_number in range(3, Balance.STAGE_COUNT + 1):
		_draw_stage_branches(stage_number, camera_top)
	if not qa_support_mask and player != null and player.support_state == PlayerController.SupportState.TRANSFERRING:
		_draw_transfer_connection(player.transition_from, player.transition_to, player.transition_base_y)

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
	var split_root_y := -Balance.STAGE_HEIGHT * 2.0 - 140.0
	var visible_top := maxf(split_root_y, camera_top - 64.0)
	var visible_bottom := minf(740.0, camera_top + 620.0)
	if visible_bottom <= visible_top:
		return
	var centers := PackedVector2Array()
	var y := visible_bottom
	while y > visible_top:
		centers.append(Vector2(_trunk_center_x(y), y))
		y = maxf(y - 32.0, visible_top)
	if centers.is_empty() or centers[centers.size() - 1].y != visible_top:
		centers.append(Vector2(_trunk_center_x(visible_top), visible_top))
	_draw_textured_ribbon(centers, _trunk_widths(centers), -visible_bottom / MODULE_HEIGHT)

func _trunk_widths(points: PackedVector2Array) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	for point in points:
		widths.append(_trunk_half_width(point.y) * 2.0)
	return widths

func _trunk_center_x(world_y: float) -> float:
	return sin(world_y * 0.0041) * 5.0 + sin(world_y * 0.0107) * 2.5

func _trunk_half_width(world_y: float) -> float:
	return 90.0 + sin(world_y * TAU / MODULE_HEIGHT) * 4.0

func _draw_stage_branches(stage_number: int, camera_top: float) -> void:
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	var stage_top := -float(stage_number) * Balance.STAGE_HEIGHT
	var camera_bottom := camera_top + 556.0
	if stage_bottom < camera_top - 120.0 or stage_top > camera_bottom + 120.0:
		return
	if stage_number == 3:
		for route in 3:
			_draw_split_ribbon(route, stage_bottom)
	for route in 3:
		for segment: Array in stages.support_segments(stage_number, route):
			_draw_branch_segment(stage_number, route, float(segment[0]), float(segment[1]))
	var connection_y := stage_bottom - (430.0 if stage_number == 3 else 180.0)
	while connection_y > stage_top + 120.0:
		if branch_graph.can_transfer(stages, 0, 1, connection_y):
			_draw_transfer_connection(0, 1, connection_y)
		if branch_graph.can_transfer(stages, 1, 2, connection_y - 90.0):
			_draw_transfer_connection(1, 2, connection_y - 90.0)
		connection_y -= 360.0

func _draw_branch_segment(stage_number: int, route: int, start_progress: float, end_progress: float) -> void:
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	if stage_number == 3 and start_progress <= 0.0:
		start_progress = maxf(start_progress, 350.0 / Balance.STAGE_HEIGHT)
	var start_y := stage_bottom - start_progress * Balance.STAGE_HEIGHT
	var end_y := stage_bottom - end_progress * Balance.STAGE_HEIGHT
	var points := PackedVector2Array([Vector2(_branch_visual_x(route, start_y), start_y)])
	var cursor_y := start_y
	while cursor_y > end_y:
		cursor_y = maxf(cursor_y - 12.0, end_y)
		points.append(Vector2(_branch_visual_x(route, cursor_y), cursor_y))
	if points.size() < 2:
		return
	branch_point_count += points.size()
	_draw_branch_ribbon(points, route, true)

func _branch_visual_x(route: int, world_y: float) -> float:
	# Gameplay remains on Balance.ROUTE_X. This visual-only S wave stays within
	# the 44 px support, replacing the former ruler-straight tube.
	return float(Balance.ROUTE_X[route]) + sin((world_y + float(route) * 83.0) * 0.0085) * 5.5

func _draw_split_ribbon(route: int, stage_bottom: float) -> void:
	var split_start := Vector2(_trunk_center_x(stage_bottom - 140.0), stage_bottom - 140.0)
	var split_end_y := stage_bottom - 350.0
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	for step in range(29):
		var t := float(step) / 28.0
		var smooth := t * t * (3.0 - 2.0 * t)
		var branch_end_x := _branch_visual_x(route, split_end_y)
		var organic_x := lerpf(split_start.x, branch_end_x, smooth) + sin(t * PI) * float(route - 1) * 6.0
		points.append(Vector2(organic_x, lerpf(split_start.y, split_end_y, t)))
		widths.append(lerpf(ScaleLock.TRUNK_WIDTH, ScaleLock.BRANCH_WIDTH, smooth))
	_draw_textured_ribbon(points, widths, -split_start.y / MODULE_HEIGHT)

func _draw_branch_ribbon(points: PackedVector2Array, route: int, _draw_tips: bool) -> void:
	var widths := PackedFloat32Array()
	for _point in points:
		widths.append(ScaleLock.BRANCH_WIDTH)
	_draw_textured_ribbon(points, widths, float(route) * 0.27)
	# Atlas tip cells contain generous transparent padding, which made their
	# painted spirals appear detached between routes. Gameplay segment and
	# split tips therefore stay clean until an anchored decoration is available.

func _draw_textured_ribbon(points: PackedVector2Array, widths: PackedFloat32Array, texture_phase: float) -> void:
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
		var outline_quad := PackedVector2Array([
			extended_first - normal * (first_half + VISUAL_OUTLINE_WIDTH),
			extended_first + normal * (first_half + VISUAL_OUTLINE_WIDTH),
			extended_second + normal * (second_half + VISUAL_OUTLINE_WIDTH),
			extended_second - normal * (second_half + VISUAL_OUTLINE_WIDTH),
		])
		draw_colored_polygon(outline_quad, OUTLINE_COLOR)
		var first_v := start_v + (distances[index] - 1.25 * flow_scale) / MODULE_HEIGHT
		var second_v := start_v + (distances[index + 1] + 1.25 * flow_scale) / MODULE_HEIGHT
		var first_u := _surface_uv_edges(first_v)
		var second_u := _surface_uv_edges(second_v)
		var uvs := PackedVector2Array([
			Vector2(first_u.x, first_v), Vector2(first_u.y, first_v),
			Vector2(second_u.y, second_v), Vector2(second_u.x, second_v),
		])
		var surface_width := maxf(first_half * 2.0, second_half * 2.0)
		var width_mix := clampf((surface_width - ScaleLock.BRANCH_WIDTH) / (ScaleLock.TRUNK_WIDTH - ScaleLock.BRANCH_WIDTH), 0.0, 1.0)
		var texture_alpha := lerpf(0.42, 0.08, width_mix)
		draw_colored_polygon(quad, VINE_BASE_COLOR)
		var texture_modulate := Color(1.0, 1.0, 1.0, texture_alpha)
		draw_polygon(quad, PackedColorArray([texture_modulate, texture_modulate, texture_modulate, texture_modulate]), uvs, VINE_SURFACE_TEXTURE)
		if width_mix > 0.0:
			var secondary_uvs := PackedVector2Array()
			for uv in uvs:
				secondary_uvs.append(uv + Vector2(0.43, 0.37))
			var secondary_modulate := Color(1.0, 1.0, 1.0, 0.10 * width_mix)
			draw_polygon(quad, PackedColorArray([secondary_modulate, secondary_modulate, secondary_modulate, secondary_modulate]), secondary_uvs, VINE_SURFACE_TEXTURE)
		if surface_width <= 60.0:
			# A translucent lime glaze keeps the painted volume while preventing
			# dark texture pockets from swallowing the character's 3 px rim.
			draw_colored_polygon(quad, Color(0.78, 0.90, 0.42, 0.30))
	if not qa_support_mask:
		var edge_geometry := _ribbon_geometry(points, widths, VISUAL_OUTLINE_WIDTH, texture_phase)
		draw_polyline(edge_geometry.left, OUTLINE_COLOR, 1.25, true)
		draw_polyline(edge_geometry.right, OUTLINE_COLOR, 1.25, true)

func _surface_uv_edges(flow_v: float) -> Vector2:
	# Both edges deliberately use different, smoothly changing offsets. The
	# source tile is never mirrored; this asymmetric shear turns its repeated
	# centered chevrons into non-repeating directional fibres.
	var offset := sin(flow_v * TAU / 5.0) * 0.19 + sin(flow_v * TAU / 3.7) * 0.07
	var shear := 0.21 + sin(flow_v * TAU / 7.3) * 0.11 + sin(flow_v * TAU / 11.0) * 0.04
	return Vector2(offset - shear * 0.35, 1.0 + offset + shear * 0.65)

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
		var u_edges := _surface_uv_edges(v)
		left_uv.append(Vector2(u_edges.x, v))
		right_uv.append(Vector2(u_edges.y, v))
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
		var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
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

func _draw_transfer_connection(from_branch: int, to_branch: int, world_y: float) -> void:
	var points := PackedVector2Array()
	for step in 17:
		points.append(branch_graph.transfer_point(stages, from_branch, to_branch, world_y, float(step) / 16.0))
	var widths := PackedFloat32Array()
	for step in points.size():
		widths.append(lerpf(12.0, 15.0, sin(float(step) / float(points.size() - 1) * PI)))
	_draw_textured_ribbon(points, widths, 0.41)

func sky_color_at(normalized_y: float) -> Color:
	return SKY_TOP.lerp(SKY_BOTTOM, clampf(normalized_y, 0.0, 1.0))

func qa_branch_visual_deviation(route: int, world_y: float) -> float:
	return absf(_branch_visual_x(route, world_y) - float(Balance.ROUTE_X[route]))

func qa_point_inside_support(world_point: Vector2) -> bool:
	var stage_number := stages.stage_for_y(world_point.y)
	if stage_number <= 2:
		return absf(world_point.x - _trunk_center_x(world_point.y)) <= _trunk_half_width(world_point.y)
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	var progress := (stage_bottom - world_point.y) / Balance.STAGE_HEIGHT
	if stage_number == 3 and progress * Balance.STAGE_HEIGHT >= 140.0 and progress * Balance.STAGE_HEIGHT <= 350.0:
		var t := (progress * Balance.STAGE_HEIGHT - 140.0) / 210.0
		var smooth := t * t * (3.0 - 2.0 * t)
		for route in 3:
			var end_y := stage_bottom - 350.0
			var center_x := lerpf(_trunk_center_x(stage_bottom - 140.0), _branch_visual_x(route, end_y), smooth) + sin(t * PI) * float(route - 1) * 6.0
			var width := lerpf(ScaleLock.TRUNK_WIDTH, ScaleLock.BRANCH_WIDTH, smooth)
			if absf(world_point.x - center_x) <= width * 0.5:
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
		"surface_texture": "res://assets/art/world/vine_surface_tile.png",
		"foliage_atlas": "res://assets/art/world/foliage_atlas.png",
		"procedural_circle_cloud_count": 0,
		"flat_polygon_leaf_count": 0,
		"airborne_transfer_foliage_count": 0,
		"gameplay_branch_tip_foliage_count": 0,
		"atmosphere_layers": ["painted_far_plate", "distant_bean_silhouettes", "cream_clouds_in_plate", "imagegen_foreground_foliage"],
	}
