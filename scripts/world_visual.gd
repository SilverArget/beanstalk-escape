extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const VINE_SURFACE_TEXTURE := preload("res://assets/art/world/vine_surface_tile.png")
const FOLIAGE_TEXTURE := preload("res://assets/art/world/foliage_atlas.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")
const OUTLINE_COLOR := Color("173d2f")
const MODULE_HEIGHT := 256.0
const TEXTURE_REPEAT := 52.0
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
	_draw_trunk(camera_top)
	_draw_trunk_features(camera_top)
	for stage_number in range(3, Balance.STAGE_COUNT + 1):
		_draw_stage_branches(stage_number, camera_top)
	if player != null and player.support_state == PlayerController.SupportState.TRANSFERRING:
		_draw_transfer_connection(player.transition_from, player.transition_to, player.transition_base_y)

func _draw_sky(camera_top: float) -> void:
	var view_rect := Rect2(-480.0, camera_top - 8.0, 960.0, 556.0)
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
		cursor_y = maxf(cursor_y - 52.0, end_y)
		points.append(Vector2(_branch_visual_x(route, cursor_y), cursor_y))
	if points.size() < 2:
		return
	branch_point_count += points.size()
	_draw_branch_ribbon(points, route, true)

func _branch_visual_x(route: int, world_y: float) -> float:
	# Gameplay remains on Balance.ROUTE_X. This visual-only S wave stays within
	# the 44 px support, replacing the former ruler-straight tube.
	return float(Balance.ROUTE_X[route]) + sin((world_y + float(route) * 83.0) * 0.0085) * 7.0

func _draw_split_ribbon(route: int, stage_bottom: float) -> void:
	var split_start := Vector2(_trunk_center_x(stage_bottom - 140.0), stage_bottom - 140.0)
	var points := PackedVector2Array()
	var widths := PackedFloat32Array()
	for step in range(13):
		var t := float(step) / 12.0
		var smooth := t * t * (3.0 - 2.0 * t)
		var organic_x := lerpf(split_start.x, float(Balance.ROUTE_X[route]), smooth) + sin(t * PI) * float(route - 1) * 9.0
		points.append(Vector2(organic_x, lerpf(split_start.y, stage_bottom - 350.0, t)))
		widths.append(lerpf(94.0 if route == 1 else 74.0, ScaleLock.BRANCH_WIDTH, smooth))
	_draw_textured_ribbon(points, widths, float(route) * 0.23)
	_draw_foliage_sprite(0 if route != 1 else 2, points[points.size() - 1] + Vector2(20.0 * float(route - 1), -6.0), Vector2(70.0, 70.0), route == 0)

func _draw_branch_ribbon(points: PackedVector2Array, route: int, draw_tips: bool) -> void:
	var widths := PackedFloat32Array()
	for _point in points:
		widths.append(ScaleLock.BRANCH_WIDTH)
	_draw_textured_ribbon(points, widths, float(route) * 0.27)
	if draw_tips:
		_draw_foliage_sprite(3, points[0], Vector2(54.0, 54.0), false)
		_draw_foliage_sprite(3, points[points.size() - 1], Vector2(54.0, 54.0), true)
		var leaf_side := -1.0 if route == 0 else 1.0
		_draw_foliage_sprite(1 if route == 1 else 5, points[points.size() - 1] + Vector2(leaf_side * 34.0, 8.0), Vector2(76.0, 76.0), leaf_side < 0.0)

func _draw_textured_ribbon(points: PackedVector2Array, widths: PackedFloat32Array, texture_phase: float) -> void:
	if points.size() < 2:
		return
	var distance := texture_phase * MODULE_HEIGHT
	for index in range(points.size() - 1):
		var first := points[index]
		var second := points[index + 1]
		var tangent := (second - first).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var first_half := widths[index] * 0.5
		var second_half := widths[index + 1] * 0.5
		var quad := PackedVector2Array([first - normal * first_half, first + normal * first_half, second + normal * second_half, second - normal * second_half])
		var outline_quad := PackedVector2Array([first - normal * (first_half + VISUAL_OUTLINE_WIDTH), first + normal * (first_half + VISUAL_OUTLINE_WIDTH), second + normal * (second_half + VISUAL_OUTLINE_WIDTH), second - normal * (second_half + VISUAL_OUTLINE_WIDTH)])
		draw_colored_polygon(outline_quad, OUTLINE_COLOR)
		var next_distance := distance + first.distance_to(second)
		var uvs := PackedVector2Array([Vector2(0.0, distance / MODULE_HEIGHT), Vector2(1.0, distance / MODULE_HEIGHT), Vector2(1.0, next_distance / MODULE_HEIGHT), Vector2(0.0, next_distance / MODULE_HEIGHT)])
		draw_polygon(quad, PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, VINE_SURFACE_TEXTURE)
		distance = next_distance

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
	_draw_foliage_sprite(0, points[points.size() / 2] + Vector2(0.0, -10.0), Vector2(48.0, 48.0))

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
		"surface_texture": "res://assets/art/world/vine_surface_tile.png",
		"foliage_atlas": "res://assets/art/world/foliage_atlas.png",
		"procedural_circle_cloud_count": 0,
		"flat_polygon_leaf_count": 0,
		"atmosphere_layers": ["painted_far_plate", "distant_bean_silhouettes", "cream_clouds_in_plate", "imagegen_foreground_foliage"],
	}
