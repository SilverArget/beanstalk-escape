extends Control

var game: GameManager

func _draw() -> void:
	draw_line(Vector2(24, 24), Vector2(24, size.y - 24), Color("24402f"), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(4, size.y - 4), "GROUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("24402f"))
	var summit_color := Color("f1d55b")
	if game != null and game.stages.summit_flash_count > 0:
		summit_color = Color("fff3a1") if int(Time.get_ticks_msec() / 120) % 2 == 0 else Color("b98d25")
	draw_string(ThemeDB.fallback_font, Vector2(2, 12), "SUMMIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, summit_color)
	for stage in 30:
		var t := float(stage) / 29.0
		var y := lerpf(size.y - 28.0, 28.0, t)
		var active := stage < Balance.STAGE_COUNT
		draw_circle(Vector2(24, y), 3.5 if active else 2.0, Color("f1d55b") if active else Color("6f7f79"))
	if game == null:
		return
	var total_height := Balance.STAGE_HEIGHT * Balance.STAGE_COUNT
	var progress := clampf(-game.player.global_position.y / total_height, 0.0, 1.0)
	var player_y := lerpf(size.y - 28.0, 28.0, progress)
	draw_circle(Vector2(24, player_y), 7.0, Color("ffffff"))
