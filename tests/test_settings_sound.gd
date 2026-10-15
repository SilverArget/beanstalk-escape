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

func _click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = control.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var saves := SaveManager.new(TEST_PATH)
	for sound in [false, true]:
		for music in [false, true]:
			var legacy := saves._default_profile()
			legacy.meta.gold = 321
			legacy.meta_systems.settings = {"sound": sound, "music": music, "ghost": false}
			var migrated := saves._sanitize_profile(legacy)
			_check(migrated.meta_systems.settings == {"sound": sound and music, "ghost": true} and migrated.meta.gold == 321, "legacy sound=%s music=%s migration with ghost enabled" % [sound, music])
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.save_manager = saves
	game._apply_loaded_profile(saves._default_profile())
	var legacy_profile := saves._default_profile()
	legacy_profile.meta_systems.settings.ghost = false
	game._apply_loaded_profile(legacy_profile)
	_check(game.meta_settings.ghost, "loaded legacy ghost=false uses enabled default")
	var master := AudioServer.get_bus_index("Master")
	for viewport_size in [Vector2i(960, 540), Vector2i(1586, 669), Vector2i(540, 960)]:
		root.size = viewport_size
		await process_frame
		game._show_settings()
		await process_frame
		var rects: Array[Rect2] = []
		var clear := true
		for name in ["InfoTitle", "SettingsSound", "InfoBack"]:
			var control := game.get_node("HUD/" + name) as Control
			var rect := control.get_global_rect()
			clear = clear and control.visible and Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(rect) and is_equal_approx(rect.get_center().x, viewport_size.x * 0.5)
			for other in rects:
				clear = clear and not rect.intersects(other, true)
			rects.append(rect)
		_check(clear and not game.get_node("HUD/InfoBody").visible and game.get_node("HUD/InfoBody").text.is_empty() and not game.has_node("HUD/SettingsMusic") and not game.has_node("HUD/SettingsGhost"), "%s centered settings with only title, music and back" % viewport_size)
		await _click(game.get_node("HUD/SettingsSound"))
		_check(not game.meta_settings.sound and not game.audio.sound_enabled and AudioServer.is_bus_mute(master) and game.audio.music.volume_db <= -60.0 and game.get_node("HUD/Mute").text == "MUSIC OFF" and game.get_node("HUD/SettingsSound").text == "MUSIC OFF", "%s MUSIC mutes all audio and syncs menu" % viewport_size)
		var mute := InputEventKey.new()
		mute.physical_keycode = KEY_M
		mute.pressed = true
		root.push_input(mute)
		await process_frame
		mute = InputEventKey.new()
		mute.physical_keycode = KEY_M
		root.push_input(mute)
		await process_frame
		_check(game.meta_settings.sound and game.audio.sound_enabled and not AudioServer.is_bus_mute(master) and game.audio.music.volume_db > -60.0 and game.get_node("HUD/SettingsSound").text == "MUSIC ON" and game.get_node("HUD/Mute").text == "MUSIC ON", "%s M restores unified audio setting" % viewport_size)
		game.ghost_playback = [{"t": 1.0, "x": 0.0, "y": 0.0}]
		game._update_ghost(0.0)
		_check(game.meta_settings.ghost and game.ghost_sprite.visible, "%s ghost playback remains enabled without settings button" % viewport_size)
		await _click(game.get_node("HUD/InfoBack"))
		_check(game.app_state == GameManager.AppState.MENU, "%s BACK opens menu" % viewport_size)
		await _click(game.get_node("HUD/Mute"))
		var reloaded := SaveManager.new(TEST_PATH)
		_check(reloaded.meta_systems_snapshot().settings == {"sound": false, "ghost": true} and AudioServer.is_bus_mute(master), "%s menu MUSIC persists one audio setting" % viewport_size)
		game._apply_loaded_profile(saves._default_profile())
	game.audio.set_platform_audio_enabled(false)
	game.audio.set_sound_enabled(true)
	_check(AudioServer.is_bus_mute(master), "platform audio lock retained")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("RESULT settings_sound PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
