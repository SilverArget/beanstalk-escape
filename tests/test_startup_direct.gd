extends SceneTree

var passed := 0
var failed := 0
const PROFILE_PATH := "user://qa/startup_direct_profile.json"

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS " + label)
	else:
		failed += 1
		print("FAIL " + label)

func _run() -> void:
	var saved := SaveManager.new(PROFILE_PATH)
	saved.load_profile()
	saved.write_shop({"owned": ["M1", "F1"], "selected_character": "F1", "equipped": {}})
	saved.mark_stage_completed(5)
	for load_index in 2:
		var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
		game.save_manager = SaveManager.new(PROFILE_PATH)
		root.add_child(game)
		_check(game.app_state == GameManager.AppState.INTRO and game.intro_active, "LOAD-%d automatic intro before first frame" % load_index)
		_check(not game.get_node("HUD/MenuLogo").visible and not game.get_node("HUD/NewRun").visible and not game.meta_ui.visible, "LOAD-%d no menu or character select" % load_index)
		_check((game.player.get_node("Body") as PlayerVisual).skin_id == "F1" and game.mode == GameManager.MODE_NORMAL, "LOAD-%d saved character" % load_index)
		_check(game.save_manager.bridge_loaded and game.platform_services.platform_audio_changed.is_connected(game.audio.set_platform_audio_enabled), "LOAD-%d platform initialization retained" % load_index)
		game.platform_services.platform_audio_changed.emit(false)
		game._finish_intro()
		_check(game.app_state == GameManager.AppState.PLAYING and not game.audio.platform_audio_enabled, "LOAD-%d muted audio does not block play" % load_index)
		_check(game.tutorial_active == not bool(game.save_manager.meta_systems_snapshot().tutorial_completed), "LOAD-%d tutorial follows saved rule" % load_index)
		game.platform_services.platform_audio_changed.emit(true)
		_check(game.audio.platform_audio_enabled, "LOAD-%d audio can resume" % load_index)
		game._finish_onboarding()
		game._pause_game()
		_check(game.get_node("HUD/DeathMenu").visible, "LOAD-%d paused menu action visible" % load_index)
		game.get_node("HUD/DeathMenu").pressed.emit()
		_check(game.app_state == GameManager.AppState.MENU and game.get_node("HUD/NewRun").visible and game.daily_card.visible, "LOAD-%d pause returns to menu" % load_index)
		game.get_node("HUD/Shop").pressed.emit()
		_check(game.app_state == GameManager.AppState.SHOP and game.meta_ui.visible, "LOAD-%d shop retained" % load_index)
		game.meta_ui.close()
		game.get_node("HUD/Map").pressed.emit()
		_check(game.app_state == GameManager.AppState.MAP and game.meta_ui.visible, "LOAD-%d map retained" % load_index)
		game.meta_ui.close()
		game.get_node("HUD/NewRun").pressed.emit()
		_check(game.app_state == GameManager.AppState.INTRO and game.stages.current_stage == 1 and game.save_manager.progression_snapshot().completed_stages.has(5), "LOAD-%d NEW RUN retains restart and progression behavior" % load_index)
		game._finish_intro()
		game._enter_player_dead(GameManager.DeathCause.CAUGHT)
		game.get_node("HUD/DeathMenu").pressed.emit()
		_check(game.app_state == GameManager.AppState.MENU, "LOAD-%d death returns to menu" % load_index)
		game.queue_free()
		await process_frame
	DirAccess.remove_absolute(PROFILE_PATH)
	print("RESULT startup_direct PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
