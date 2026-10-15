extends SceneTree

const TEST_PATH := "user://qa/test_settings_sound.json"
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

func _click(control: Control, touch := false) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			var finger := InputEventScreenTouch.new()
			finger.position = control.get_global_rect().get_center()
			finger.pressed = pressed
			event = finger
		else:
			var mouse := InputEventMouseButton.new()
			mouse.position = control.get_global_rect().get_center()
			mouse.global_position = mouse.position
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.pressed = pressed
			event = mouse
		root.push_input(event)
		await process_frame

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var saves := SaveManager.new(TEST_PATH)
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.save_manager = saves
	game._apply_loaded_profile(saves._default_profile())
	_check(not game.has_node("HUD/Settings") and not game.has_node("HUD/SettingsSound") and not game.has_method("_show_settings"), "settings screen and menu action removed")
	var button := game.get_node("HUD/Mute") as Button
	var master := AudioServer.get_bus_index("Master")
	for viewport_size in [Vector2i(960, 540), Vector2i(1586, 669), Vector2i(540, 960)]:
		root.size = viewport_size
		await process_frame
		for nightmare in [false, true]:
			saves.profile = saves._default_profile()
			saves.profile.replay.nightmare_unlocked = nightmare
			game._show_menu()
			game.layout_hud_for_viewport(Vector2(viewport_size))
			await process_frame
			var first := game.get_node("HUD/HowToPlay") as Button
			var last := game.get_node("HUD/Credits") as Button
			var new_run := game.get_node("HUD/NewRun") as Button
			var map := game.get_node("HUD/Nightmare" if nightmare else "HUD/Map") as Button
			_check(not button.visible and is_equal_approx((first.position.x + last.get_rect().end.x) * 0.5, viewport_size.x * 0.5) and is_equal_approx(last.position.x - first.get_rect().end.x, 8.0) and is_equal_approx((new_run.position.x + map.get_rect().end.x) * 0.5, viewport_size.x * 0.5), "%s centered menu nightmare=%s without sound button" % [viewport_size, nightmare])
		game.restart()
		game.tutorial_active = false
		game._update_hud()
		game.layout_hud_for_viewport(Vector2(viewport_size))
		# Freeze simulation only; GUI input still traverses the real viewport.
		game.set_physics_process(false)
		game.player.set_physics_process(false)
		game.spider.set_physics_process(false)
		game.beans.set_physics_process(false)
		var rect := button.get_global_rect()
		var clear := button.visible and button.text.is_empty() and button.mouse_filter == Control.MOUSE_FILTER_STOP and Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(rect) and rect.size == Vector2(56, 56)
		for name in ["Lives", "StageCounter", "GoldStatus", "XPStatus", "XPBar", "TimeWings", "TimeWingsOrb", "TimeWingsBar", "TimeWingsNotice", "FireWings", "Gauge", "StageBanner", "Tutorial", "TutorialPanel", "TutorialSkip", "TouchLeft", "TouchRight", "TouchWings", "TouchFire"]:
			clear = clear and not rect.intersects((game.get_node("HUD/" + name) as Control).get_global_rect(), true)
		_check(clear, "%s icon clear of HUD and mobile controls at %s" % [viewport_size, rect])
		var branch := game.player.active_branch
		await _click(button)
		_check(not game.meta_settings.sound and not button.sound_enabled and AudioServer.is_bus_mute(master) and game.player.active_branch == branch and game.touch_actions.is_empty(), "%s mouse toggles all audio without movement" % viewport_size)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_M
		key.pressed = true
		root.push_input(key)
		await process_frame
		key = InputEventKey.new()
		key.physical_keycode = KEY_M
		root.push_input(key)
		await process_frame
		_check(game.meta_settings.sound and button.sound_enabled and not AudioServer.is_bus_mute(master), "%s M synchronizes speaker" % viewport_size)
		await _click(button, true)
		var reloaded := SaveManager.new(TEST_PATH)
		_check(not game.meta_settings.sound and not button.sound_enabled and reloaded.meta_systems_snapshot().settings.sound == false and game.touch_actions.is_empty() and game.player.active_branch == branch and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"), "%s touch persists sound without movement" % viewport_size)
		game._apply_loaded_profile(saves._default_profile())
	game.audio.set_platform_audio_enabled(false)
	_check(AudioServer.is_bus_mute(master), "platform audio lock preserved")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("RESULT settings_sound PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
