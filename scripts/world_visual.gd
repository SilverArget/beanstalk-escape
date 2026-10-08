extends Node2D

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var center_y := player.global_position.y if player != null else 0.0
	var top_y := center_y - 520.0
	var bottom_y := center_y + 380.0
	draw_rect(Rect2(-520, top_y, 1040, bottom_y - top_y), Color("91cae8"), true)
	draw_line(Vector2(0, 300), Vector2(0, -Balance.STAGE_HEIGHT), Color("397447"), 82.0, true)
	if stages == null:
		return
	for pattern: Dictionary in stages.patterns:
		var stage_top := -float(pattern.stage) * Balance.STAGE_HEIGHT
		var stage_bottom := -float(pattern.stage - 1) * Balance.STAGE_HEIGHT
		if stage_bottom < top_y or stage_top > bottom_y:
			continue
		for route in 3:
			var x: float = Balance.ROUTE_X[route]
			var end_y := stage_bottom - float(pattern.route_end_progress[route]) * Balance.STAGE_HEIGHT
			var color := Color("4e9556") if pattern.stage < 3 or route == 1 else Color("5aa860")
			var width := 62.0 if pattern.stage == 1 else 34.0
			draw_line(Vector2(x, stage_bottom), Vector2(x, end_y), color, width, true)
			if pattern.route_end_progress[route] < 1.0:
				draw_circle(Vector2(x, end_y), 24.0, Color("397447"))
