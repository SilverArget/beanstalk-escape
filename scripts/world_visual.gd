extends Node2D

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center_y := player.global_position.y if player != null else 0.0
	var top_y := center_y - 520.0
	var bottom_y := center_y + 380.0
	draw_rect(Rect2(-780, top_y, 1560, bottom_y - top_y), Color("91cae8"), true)
	if stages == null:
		return
	for pattern: Dictionary in stages.patterns:
		var stage_top := -float(pattern.stage) * Balance.STAGE_HEIGHT
		var stage_bottom := -float(pattern.stage - 1) * Balance.STAGE_HEIGHT
		if stage_bottom < top_y or stage_top > bottom_y:
			continue
		if pattern.stage <= 2:
			draw_line(Vector2(0, stage_bottom), Vector2(0, stage_top), Color("397447"), Balance.TRUNK_HALF_WIDTH * 2.0 + 40.0, true)
			draw_line(Vector2(0, stage_bottom), Vector2(0, stage_top), Color("4e9556"), Balance.TRUNK_HALF_WIDTH * 2.0, true)
			continue
		for route in 3:
			var x: float = Balance.ROUTE_X[route]
			var end_y := stage_bottom - float(pattern.route_end_progress[route]) * Balance.STAGE_HEIGHT
			var color := Color("4e9556") if route == 1 else Color("5aa860")
			var branch_start := Vector2(0, stage_bottom) if pattern.stage == 3 else Vector2(x, stage_bottom)
			var join_y := minf(stage_bottom - 180.0, end_y)
			var points := PackedVector2Array([branch_start, Vector2(x, join_y), Vector2(x, end_y)])
			draw_polyline(points, color, 42.0, true)
			if pattern.route_end_progress[route] < 1.0:
				draw_circle(Vector2(x, end_y), 24.0, Color("397447"))
