extends Node2D

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

var branch_graph := BranchGraph.new()
var redraw_count := 0
var branch_point_count := 0

func _ready() -> void:
	queue_redraw()
	set_process(true)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	redraw_count += 1
	branch_point_count = 0
	var top_y := -Balance.STAGE_HEIGHT * Balance.STAGE_COUNT - 600.0
	var bottom_y := 600.0
	_draw_sky(top_y, bottom_y)
	_draw_trunk()
	for stage_number in range(3, Balance.STAGE_COUNT + 1):
		_draw_stage_branches(stage_number)
	if player != null and player.support_state == PlayerController.SupportState.TRANSFERRING:
		_draw_transfer_connection(player.transition_from, player.transition_to, player.transition_base_y, Color("f5d26b"))

func _draw_sky(top_y: float, bottom_y: float) -> void:
	draw_rect(Rect2(-1000.0, top_y, 2000.0, bottom_y - top_y), Palette.SKY_TOP)
	for band in 12:
		var y := bottom_y - float(band) * 2600.0
		draw_circle(Vector2(-350.0 + float((band * 193) % 700), y), 90.0, Palette.CLOUD_TINT)

func _draw_trunk() -> void:
	var stage_three_bottom := -Balance.STAGE_HEIGHT * 2.0
	var trunk_top := stage_three_bottom - 140.0
	var trunk_rect := Rect2(-ScaleLock.TRUNK_WIDTH * 0.5, trunk_top, ScaleLock.TRUNK_WIDTH, 740.0 - trunk_top)
	draw_rect(trunk_rect.grow(ScaleLock.OUTLINE_WIDTH), Color("173d2f"))
	draw_rect(trunk_rect, Color("4c9a4d"))
	var y := 520.0
	while y > trunk_top:
		draw_line(Vector2(-70, y), Vector2(-56, y - ScaleLock.GRIP_DETAIL), Color("276346"), ScaleLock.OUTLINE_WIDTH)
		draw_line(Vector2(58, y - 20), Vector2(72, y - 32), Color("77bb58"), ScaleLock.OUTLINE_WIDTH)
		y -= ScaleLock.TEXTURE_ELEMENT_MAX

func _draw_stage_branches(stage_number: int) -> void:
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	var stage_top := -float(stage_number) * Balance.STAGE_HEIGHT
	for route in 3:
		var points := PackedVector2Array()
		if stage_number == 3:
			points.append(Vector2(0.0, stage_bottom - 140.0))
			for step in range(1, 8):
				var t := float(step) / 7.0
				var smooth := t * t * (3.0 - 2.0 * t)
				points.append(Vector2(lerpf(0.0, Balance.ROUTE_X[route], smooth), lerpf(stage_bottom - 140.0, stage_bottom - 350.0, t)))
		var cursor_y := stage_bottom - (350.0 if stage_number == 3 else 0.0)
		if points.is_empty():
			points.append(Vector2(Balance.ROUTE_X[route], cursor_y))
		while cursor_y > stage_top:
			cursor_y = maxf(cursor_y - 120.0, stage_top)
			points.append(Vector2(Balance.ROUTE_X[route], cursor_y))
		branch_point_count += points.size()
		draw_polyline(points, Color("173d2f"), ScaleLock.BRANCH_WIDTH + ScaleLock.OUTLINE_WIDTH * 2.0, true)
		draw_polyline(points, Color("4c9a4d"), ScaleLock.BRANCH_WIDTH, true)
		for point_index in range(1, points.size(), 2):
			var point := points[point_index]
			draw_line(point + Vector2(-12, 0), point + Vector2(12, -8), Color("77bb58"), ScaleLock.OUTLINE_WIDTH)
	var connection_y := stage_bottom - (430.0 if stage_number == 3 else 180.0)
	while connection_y > stage_top + 120.0:
		_draw_transfer_connection(0, 1, connection_y, Color("3d8144"))
		_draw_transfer_connection(1, 2, connection_y - 90.0, Color("3d8144"))
		connection_y -= 360.0

func _draw_transfer_connection(from_branch: int, to_branch: int, world_y: float, color: Color) -> void:
	var points := PackedVector2Array()
	for step in 13:
		points.append(branch_graph.transfer_point(stages, from_branch, to_branch, world_y, float(step) / 12.0))
	draw_polyline(points, Color("173d2f"), 12.0, true)
	draw_polyline(points, color, 7.0, true)

func sky_color_at(normalized_y: float) -> Color:
	return Palette.SKY_TOP.lerp(Palette.SKY_BOTTOM, clampf(normalized_y, 0.0, 1.0))
