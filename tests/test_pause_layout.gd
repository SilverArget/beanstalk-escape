extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		print("FAIL " + label)

func _click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var saves := SaveManager.new("user://qa/pause_legacy_settings.json")
	var legacy := saves._default_profile()
	legacy.meta.gold = 321
	legacy.meta_systems.settings = {"sound": false, "music": true, "ghost": false, "reduced_motion": true, "reduce_effects": true}
	var sanitized := saves._sanitize_profile(legacy)
	_check(sanitized.meta_systems.settings == {"sound": false, "music": true, "ghost": false} and sanitized.meta.gold == 321, "legacy effects fields ignored; saved settings and gold retained")
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	game._finish_intro()
	game._finish_onboarding()
	game.shake_remaining = 0.20
	game._apply_impact_fx(0.0)
	_check(not (game.player.get_node("Camera2D") as Camera2D).offset.is_zero_approx(), "full impact shake retained")
	for viewport_size in [Vector2i(960, 540), Vector2i(1586, 669), Vector2i(540, 960)]:
		root.size = viewport_size
		await process_frame
		game._pause_game()
		await process_frame
		var menu := game.get_node("HUD/PauseMenu") as Button
		var title := game.get_node("HUD/Pause") as Label
		var menu_rect := menu.get_global_rect()
		var screen := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_check(game.get_node_or_null("HUD/ReduceMotion") == null and game.find_children("*", "CheckButton", true, false).is_empty(), "%s no effects toggle" % viewport_size)
		_check(title.visible and menu.visible and screen.encloses(menu_rect) and title.get_global_rect().end.y + 16.0 <= menu_rect.position.y and is_equal_approx(menu_rect.get_center().x, viewport_size.x * 0.5) and is_equal_approx(title.get_global_rect().get_center().x, viewport_size.x * 0.5), "%s centered title and menu" % viewport_size)
		await _click(menu)
		_check(game.app_state == GameManager.AppState.MENU, "%s menu mouse click" % viewport_size)
		game.get_node("HUD/NewRun").pressed.emit()
		game._finish_intro()
		game._finish_onboarding()
		game._enter_player_dead(GameManager.DeathCause.CAUGHT)
		await process_frame
		var death_menu := game.get_node("HUD/DeathMenu") as Button
		var death_width := minf(230.0, (viewport_size.x - 30.0) * 0.5)
		var death_x := maxf((viewport_size.x - death_width * 2.0 - 10.0) * 0.5, 8.0)
		_check(death_menu.visible and death_menu.position.is_equal_approx(Vector2(death_x + death_width + 10.0, viewport_size.y * 0.40 + 58.0)) and death_menu.size == Vector2(death_width, 52.0), "%s death layout unchanged" % viewport_size)
		game.get_node("HUD/NewRun").pressed.emit()
		game._finish_intro()
		game._finish_onboarding()
	game.queue_free()
	await process_frame
	print("RESULT pause_layout PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
