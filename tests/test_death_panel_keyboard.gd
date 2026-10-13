extends SceneTree

const MainScene = preload("res://scenes/main.tscn")

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := MainScene.instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.start_game()
	game.tutorial_active = false
	game._enter_player_dead(GameManager.DeathCause.FALL)
	await process_frame
	await process_frame

	var continue_button := game.get_node("HUD/ContinueAd") as Button
	var retry_button := game.get_node("HUD/RetryStage") as Button
	var focused := game.get_viewport().gui_get_focus_owner() as Button
	_check(focused == continue_button, "death panel focuses the first visible action")
	var focus_style := continue_button.get_theme_stylebox("focus") as StyleBoxFlat
	var hover_style := continue_button.get_theme_stylebox("hover") as StyleBoxFlat
	_check(focus_style != null and hover_style != null and focus_style.bg_color != hover_style.bg_color and focus_style.border_width_left > hover_style.border_width_left, "focused death action has a distinct highlight")

	await _press_key(KEY_RIGHT)
	_check(game.get_viewport().gui_get_focus_owner() == retry_button, "ArrowRight focuses RESTART")
	await _press_key(KEY_LEFT)
	_check(game.get_viewport().gui_get_focus_owner() == continue_button, "ArrowLeft returns to WATCH AD")
	await _press_key(KEY_D)
	_check(game.get_viewport().gui_get_focus_owner() == retry_button, "D focuses the next visible death action")
	await _press_key(KEY_ENTER)
	_check(game.app_state == GameManager.AppState.PLAYING, "Enter presses only the focused RESTART action")

	print("test_death_panel_keyboard.gd: %d PASS / %d FAIL" % [passed, failed])
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventKey.new()
	released.physical_keycode = keycode
	released.pressed = false
	Input.parse_input_event(released)
	await process_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
