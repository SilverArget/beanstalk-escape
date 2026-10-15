extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL " + label)

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	game._show_menu()
	var resume := game.get_node("HUD/Resume") as Button
	_check(not resume.visible and not game._readonly_state_snapshot().resume_available, "no suspended run at launch")
	for run_mode in [GameManager.MODE_NORMAL, GameManager.MODE_NIGHTMARE]:
		game.save_manager.profile.replay.nightmare_unlocked = run_mode == GameManager.MODE_NIGHTMARE
		game.mode = run_mode
		game.restart()
		game.tutorial_active = false
		game.player.global_position = Vector2(37.0, -2400.0)
		game.spider.global_position = Vector2(-19.0, -1900.0)
		game.current_lives = 2
		var stage := game.stages.stage_for_y(game.player.global_position.y)
		var gold := game.economy.snapshot().duplicate(true)
		game._pause_game()
		game.get_node("HUD/PauseMenu").pressed.emit()
		await process_frame
		_check(resume.visible and game._readonly_state_snapshot().resume_available and root.gui_get_focus_owner() == resume, "%s resume visible and focused" % run_mode)
		for size in [Vector2i(960, 540), Vector2i(1586, 669), Vector2i(540, 960)]:
			root.size = size
			await process_frame
			game.layout_hud_for_viewport(Vector2(size))
			var screen := Rect2(Vector2.ZERO, Vector2(size))
			var buttons: Array[Control] = [resume, game.get_node("HUD/NewRun"), game.get_node("HUD/Shop"), game.get_node("HUD/Map"), game.get_node("HUD/HowToPlay"), game.get_node("HUD/Credits")]
			if game.get_node("HUD/Nightmare").visible:
				buttons.append(game.get_node("HUD/Nightmare"))
			for i in buttons.size():
				_check(screen.encloses(buttons[i].get_global_rect()), "%s %s inside screen" % [size, buttons[i].name])
				for j in range(i + 1, buttons.size()):
					_check(not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()), "%s buttons do not overlap" % size)
			_check(resume.get_global_rect().end.y < game.get_node("HUD/NewRun").get_global_rect().position.y, "resume above new run")
		for action in ["Shop", "Map", "HowToPlay", "Credits"]:
			game.get_node("HUD/" + action).pressed.emit()
			await process_frame
			if action in ["HowToPlay", "Credits"]:
				game.get_node("HUD/InfoBack").pressed.emit()
			else:
				game._close_meta_ui()
			await process_frame
			_check(resume.visible and game.resume_available, action + " BACK keeps resume")
		_check(game.player.global_position == Vector2(37.0, -2400.0) and game.spider.global_position == Vector2(-19.0, -1900.0), "suspended positions frozen")
		resume.pressed.emit()
		_check(game.app_state == GameManager.AppState.PLAYING and not game.resume_available and not resume.visible, "resume enters playing and consumes suspension")
		_check(game.player.global_position == Vector2(37.0, -2400.0) and game.spider.global_position == Vector2(-19.0, -1900.0) and game.stages.stage_for_y(game.player.global_position.y) == stage, "same stage and positions")
		_check(game.current_lives == 2 and game.economy.snapshot() == gold and game.mode == run_mode and game.golds.visible, "same lives gold mode and visible golds")
		_check(game.player.is_physics_processing() and game.spider.is_physics_processing() and game.beans.is_physics_processing(), "physics restored")
		game.audio._process(0.0)
		_check(game.audio.music.stream == game.audio.STREAMS.music_game and not game.audio.music.stream_paused, "game music restored")
		game._pause_game()
		game._menu_from_death()
		if run_mode == GameManager.MODE_NIGHTMARE:
			game.get_node("HUD/Nightmare").pressed.emit()
		else:
			game.get_node("HUD/NewRun").pressed.emit()
		_check(not game.resume_available and not resume.visible and game.mode == run_mode, "new run clears resume")
		game._finish_intro()
		game._finish_onboarding()
		game._enter_player_dead(GameManager.DeathCause.CAUGHT)
		game.get_node("HUD/DeathMenu").pressed.emit()
		_check(not resume.visible and not game.resume_available, "death menu has no resume")
	game.restart()
	game._pause_game()
	game._menu_from_death()
	game._on_prototype_completed()
	game._finish_final_cinematic()
	game._complete_menu()
	_check(not resume.visible and not game.resume_available, "completion has no resume")
	game.queue_free()
	await process_frame
	print("RESULT menu_resume PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
