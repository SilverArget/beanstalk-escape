extends Control

var game: GameManager

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null or game.app_state != GameManager.AppState.PLAYING:
		return
	var amount := clampf((game.gauge.normalized_danger - 0.45) / 0.55, 0.0, 1.0)
	if amount <= 0.0:
		return
	var color := Palette.DANGER_SPIDER
	color.a = amount * 0.48
	var edge := 24.0 + amount * 34.0
	draw_rect(Rect2(0, 0, size.x, edge), color, true)
	draw_rect(Rect2(0, size.y - edge, size.x, edge), color, true)
	draw_rect(Rect2(0, 0, edge, size.y), color, true)
	draw_rect(Rect2(size.x - edge, 0, edge, size.y), color, true)
