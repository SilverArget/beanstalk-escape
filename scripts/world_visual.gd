extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")
const CLOUD_COLOR := Color("fff2dc")
const OUTLINE_COLOR := Color("173d2f")
const TRUNK_COLOR := Color("4c9a4d")
const TRUNK_SHADOW := Color("276346")
const VEIN_COLOR := Color("b8dd72")
const BRANCH_COLORS := [Color("397447"), Color("4e9556"), Color("5aa860")]
const MODULE_HEIGHT := 256.0
const TEXTURE_REPEAT := 52.0
const GRIP_DETAIL_SIZE := 12.0
const MAX_LEAF_SIZE := 140.0
const VISUAL_OUTLINE_WIDTH := 3.0

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

var branch_graph := BranchGraph.new()
var redraw_count := 0
var branch_point_count := 0
var qa_storm_background := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	redraw_count += 1
	branch_point_count = 0
	var camera_top := (player.global_position.y - ScaleLock.CHARACTER_REFERENCE_Y) if player != null else -270.0
	_draw_sky(camera_top)
	_draw_trunk()
	_draw_trunk_features()
	for stage_number in range(3, Balance.STAGE_COUNT + 1):
		_draw_stage_branches(stage_number)
	if player != null and player.support_state == PlayerController.SupportState.TRANSFERRING:
		_draw_transfer_connection(player.transition_from, player.transition_to, player.transition_base_y, Color("f5d26b"))

func _draw_sky(camera_top: float) -> void:
	var view_rect := Rect2(-480.0, camera_top - 8.0, 960.0, 556.0)
	if qa_storm_background:
		draw_rect(view_rect, Color("313c68"))
		return
	# Exact palette endpoints remain beneath the painted plate. Drawing narrow
	# bands avoids the former flat-blue field and keeps the gradient deterministic.
	for band in 24:
		var t := float(band) / 23.0
		var band_y := view_rect.position.y + view_rect.size.y * t
		draw_rect(Rect2(view_rect.position.x, band_y, view_rect.size.x, view_rect.size.y / 23.0 + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	# image_gen background: distant bean silhouettes, cream clouds and soft
	# corner foliage. It follows the camera as the farthest parallax plate.
	draw_texture_rect(ATMOSPHERE_TEXTURE, view_rect, false, Color(1.0, 1.0, 1.0, 0.58))
	_draw_far_vines(camera_top)
	_draw_cloud_layer(camera_top)
	_draw_foreground_foliage(camera_top)

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
		draw_polyline(points, Color(0.12, 0.38, 0.37, 0.16), 30.0, true)

func _draw_cloud_layer(camera_top: float) -> void:
	var drift := fposmod(-camera_top * 0.25, 620.0)
	for index in 5:
		var x := -420.0 + float(index) * 215.0
		var y := camera_top - 90.0 + fposmod(drift + float(index) * 137.0, 650.0)
		var tint := Color(CLOUD_COLOR, 0.42)
		draw_circle(Vector2(x, y), 34.0, tint)
		draw_circle(Vector2(x + 38.0, y + 8.0), 47.0, tint)
		draw_circle(Vector2(x + 82.0, y + 15.0), 30.0, tint)

func _draw_foreground_foliage(camera_top: float) -> void:
	var drift := fposmod(-camera_top * 0.52, 720.0)
	for index in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var center := Vector2(side * 455.0, camera_top - 100.0 + fposmod(drift + float(index) * 211.0, 760.0))
		_draw_leaf(center, side, MAX_LEAF_SIZE, Color(0.08, 0.29, 0.22, 0.20), false)

func _draw_trunk() -> void:
	var split_root_y := -Balance.STAGE_HEIGHT * 2.0 - 140.0
	var top_y := split_root_y
	var bottom_y := 740.0
	var outer := _trunk_polygon(top_y, bottom_y, VISUAL_OUTLINE_WIDTH)
	var inner := _trunk_polygon(top_y, bottom_y, 0.0)
	draw_colored_polygon(outer, OUTLINE_COLOR)
	draw_colored_polygon(inner, TRUNK_COLOR)
	var vein := PackedVector2Array()
	var y := bottom_y
	while y >= top_y:
		vein.append(Vector2(_trunk_center_x(y) - 24.0 + sin(y * 0.010) * 13.0, y))
		y -= 24.0
	draw_polyline(vein, TRUNK_SHADOW, 7.0, true)
	draw_polyline(vein, VEIN_COLOR, VISUAL_OUTLINE_WIDTH, true)
	y = bottom_y - 18.0
	var feature_index := 0
	while y > top_y + 18.0:
		var side := -1.0 if feature_index % 2 == 0 else 1.0
		var center_x := _trunk_center_x(y) + side * (_trunk_half_width(y) - 22.0)
		draw_circle(Vector2(center_x, y), GRIP_DETAIL_SIZE * 0.5 + VISUAL_OUTLINE_WIDTH, OUTLINE_COLOR)
		draw_circle(Vector2(center_x, y - 1.0), GRIP_DETAIL_SIZE * 0.5, Color("77bb58"))
		draw_line(Vector2(center_x - side * 2.0, y - 3.0), Vector2(center_x - side * 6.0, y - 7.0), VEIN_COLOR, 2.0, true)
		y -= TEXTURE_REPEAT
		feature_index += 1

func _trunk_polygon(top_y: float, bottom_y: float, expansion: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var y := bottom_y
	while y > top_y:
		var center_x := _trunk_center_x(y)
		var half_width := _trunk_half_width(y) + expansion
		left.append(Vector2(center_x - half_width, y))
		right.append(Vector2(center_x + half_width, y))
		y = maxf(y - 24.0, top_y)
	var result := PackedVector2Array()
	for point in left: result.append(point)
	for index in range(right.size() - 1, -1, -1): result.append(right[index])
	return result

func _trunk_center_x(world_y: float) -> float:
	return sin(world_y * 0.0041) * 5.0 + sin(world_y * 0.0107) * 2.5

func _trunk_half_width(world_y: float) -> float:
	return 90.0 + sin(world_y * TAU / MODULE_HEIGHT) * 4.0

func _draw_stage_branches(stage_number: int) -> void:
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	var stage_top := -float(stage_number) * Balance.STAGE_HEIGHT
	if stage_number == 3:
		for route in 3:
			_draw_split_ribbon(route, stage_bottom)
	for route in 3:
		for segment: Array in stages.support_segments(stage_number, route):
			_draw_branch_segment(stage_number, route, float(segment[0]), float(segment[1]))
	var connection_y := stage_bottom - (430.0 if stage_number == 3 else 180.0)
	while connection_y > stage_top + 120.0:
		if branch_graph.can_transfer(stages, 0, 1, connection_y):
			_draw_transfer_connection(0, 1, connection_y, BRANCH_COLORS[1])
		if branch_graph.can_transfer(stages, 1, 2, connection_y - 90.0):
			_draw_transfer_connection(1, 2, connection_y - 90.0, BRANCH_COLORS[1])
		connection_y -= 360.0

func _draw_branch_segment(stage_number: int, route: int, start_progress: float, end_progress: float) -> void:
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	var points := PackedVector2Array()
	if stage_number == 3 and start_progress <= 0.0:
		start_progress = maxf(start_progress, 350.0 / Balance.STAGE_HEIGHT)
	var start_y := stage_bottom - start_progress * Balance.STAGE_HEIGHT
	var end_y := stage_bottom - end_progress * Balance.STAGE_HEIGHT
	if points.is_empty():
		points.append(Vector2(Balance.ROUTE_X[route], start_y))
	var cursor_y := minf(points[-1].y, start_y)
	while cursor_y > end_y:
		cursor_y = maxf(cursor_y - 84.0, end_y)
		var sway := sin((cursor_y + float(route) * 71.0) * 0.008) * 2.5
		points.append(Vector2(float(Balance.ROUTE_X[route]) + sway, cursor_y))
	if points.size() < 2:
		return
	branch_point_count += points.size()
	_draw_branch_ribbon(points, route)

func _draw_split_ribbon(route: int, stage_bottom: float) -> void:
	var split_start := Vector2(_trunk_center_x(stage_bottom - 140.0), stage_bottom - 140.0)
	var points := PackedVector2Array()
	for step in range(8):
		var t := float(step) / 7.0
		var smooth := t * t * (3.0 - 2.0 * t)
		var organic_x := lerpf(split_start.x, float(Balance.ROUTE_X[route]), smooth) + sin(t * PI) * float(route - 1) * 7.0
		points.append(Vector2(organic_x, lerpf(split_start.y, stage_bottom - 350.0, t)))
	_draw_branch_ribbon(points, route)

func _draw_branch_ribbon(points: PackedVector2Array, route: int) -> void:
	var width := ScaleLock.BRANCH_WIDTH
	draw_polyline(points, OUTLINE_COLOR, width + VISUAL_OUTLINE_WIDTH * 2.0, true)
	draw_polyline(points, BRANCH_COLORS[route], width, true)
	var highlight := PackedVector2Array()
	for point in points:
		highlight.append(point + Vector2(-width * 0.20, 0.0))
	draw_polyline(highlight, Color("77bb58"), 4.0, true)
	for endpoint in [points[0], points[-1]]:
		draw_circle(endpoint, width * 0.5 + VISUAL_OUTLINE_WIDTH, OUTLINE_COLOR)
		draw_circle(endpoint, width * 0.5, BRANCH_COLORS[route])
		draw_circle(endpoint + Vector2(-width * 0.20, -3.0), 3.0, VEIN_COLOR)
	_draw_leaf(points[-1] + Vector2(18.0 if route != 0 else -18.0, 8.0), 1.0 if route != 0 else -1.0, 72.0, BRANCH_COLORS[route], true)

func _draw_trunk_features() -> void:
	for stage_number in [1, 2]:
		var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
		for feature: Dictionary in stages.pattern_for_stage(stage_number).trunk_features:
			var center_x := lerpf(-ScaleLock.TRUNK_WIDTH * 0.5, ScaleLock.TRUNK_WIDTH * 0.5, float(feature.x))
			var top_y := stage_bottom - float(feature.occupancy[1])
			var bottom_y := stage_bottom - float(feature.warning_height)
			if feature.kind == "GUIDE":
				var guide := PackedVector2Array([Vector2(center_x, bottom_y), Vector2(center_x + 6.0, (top_y + bottom_y) * 0.5), Vector2(center_x, top_y)])
				draw_polyline(guide, OUTLINE_COLOR, 14.0, true)
				draw_polyline(guide, VEIN_COLOR, 8.0, true)
			else:
				var side := -1.0 if feature.x >= 0.5 else 1.0
				_draw_leaf(Vector2(side * 74.0, (top_y + bottom_y) * 0.5), side, 78.0, Color("286b3e"), true)

func _draw_leaf(center: Vector2, direction: float, length: float, color: Color, outlined: bool) -> void:
	var leaf_length := minf(length, MAX_LEAF_SIZE)
	var half_height := leaf_length * 0.28
	var points := PackedVector2Array([center, center + Vector2(direction * leaf_length * 0.45, -half_height), center + Vector2(direction * leaf_length, 0.0), center + Vector2(direction * leaf_length * 0.45, half_height)])
	if outlined:
		var outline_points := PackedVector2Array()
		for point in points:
			outline_points.append(center + (point - center) * 1.06)
		draw_colored_polygon(outline_points, OUTLINE_COLOR)
	draw_colored_polygon(points, color)
	draw_line(center, center + Vector2(direction * leaf_length * 0.82, 0.0), Color(VEIN_COLOR, color.a), 2.0, true)

func _draw_transfer_connection(from_branch: int, to_branch: int, world_y: float, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 13:
		points.append(branch_graph.transfer_point(stages, from_branch, to_branch, world_y, float(step) / 12.0))
	draw_polyline(points, OUTLINE_COLOR, 16.0, true)
	draw_polyline(points, color, 10.0, true)
	draw_polyline(points, Color("77bb58"), 3.0, true)

func sky_color_at(normalized_y: float) -> Color:
	return SKY_TOP.lerp(SKY_BOTTOM, clampf(normalized_y, 0.0, 1.0))

func qa_visual_contract() -> Dictionary:
	return {
		"module_height_px": MODULE_HEIGHT,
		"trunk_nominal_width_px": ScaleLock.TRUNK_WIDTH,
		"trunk_render_width_range_px": [172.0, 188.0],
		"branch_width_px": ScaleLock.BRANCH_WIDTH,
		"branch_centers_world_x": Balance.ROUTE_X.duplicate(),
		"texture_repeat_px": TEXTURE_REPEAT,
		"grip_detail_px": GRIP_DETAIL_SIZE,
		"max_leaf_px": MAX_LEAF_SIZE,
		"outline_px": VISUAL_OUTLINE_WIDTH,
		"atmosphere_layers": ["painted_far_plate", "distant_bean_silhouettes", "cream_clouds", "foreground_foliage"],
	}
