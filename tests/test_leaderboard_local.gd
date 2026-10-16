extends SceneTree

const Save = preload("res://scripts/save_manager.gd")
const Service = preload("res://scripts/leaderboard_service.gd")
const MainScene = preload("res://scenes/main.tscn")

var passed := 0
var failed := 0
var response: Dictionary = {}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "user://qa/leaderboard_%d.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var legacy := FileAccess.open(path, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"version": 4, "meta": {"gold": 137, "xp": 42, "level": 2},
		"shop": {"owned": ["M1", "F1"], "selected_character": "F1"}}))
	legacy.close()
	var save := Save.new(path)
	var profile := save.load_profile()
	_check(profile.best_score == 0 and profile.leaderboard_local.is_empty() and profile.player_name == "", "old profile receives leaderboard defaults")
	_check(profile.meta.gold == 137 and profile.meta.xp == 42 and profile.shop.selected_character == "F1", "migration preserves currency and character")
	var service := Service.new()
	root.add_child(service)
	service.configure(save)
	var first := save.record_run_score("FIRST", 100, "F1")
	_check(first.new_best and first.best == 100 and first.rank == 1, "first positive score is a new best")
	service.submit_score("FIRST", 100, _receive)
	_check(save.profile.leaderboard_local.size() == 1 and response.entries.size() == 1, "record then submit stores one run")
	_check(response.ok and response.source == "local" and response.player_rank == 1 and response.entries[0].is_player, "local callback supplies ranks and player highlight")
	var low := save.record_run_score("LOW", 50, "M1")
	_check(not low.new_best and low.best == 100 and low.rank == 2, "lower score keeps best")
	service.submit_score("LOW", 50, _receive)
	for index in range(2, 12):
		service.submit_score("RUN %d" % index, 100 + index * 10, _receive)
	service.fetch_top(10, _receive)
	_check(response.entries.size() == 10 and save.profile.leaderboard_local.size() == 10, "twelve submissions retain ten scores")
	var descending := true
	for index in range(1, response.entries.size()):
		descending = descending and response.entries[index - 1].score >= response.entries[index].score
	_check(descending and response.entries[0].score == 210 and response.entries[9].score == 120, "top ten descend and discard the lowest two")
	_check(not service.online_adapter.enabled() and service.online_adapter.requests_started == 0 and service.get_child_count() == 0, "blank endpoint/key creates no HTTP requests")
	var stored: Dictionary = Save.new(path).load_profile()
	_check(stored.best_score == 210 and stored.leaderboard_local.size() == 10 and stored.meta.gold == 137, "scores persist without changing wallet")
	_check(stored.leaderboard_local[0].has("character") and stored.leaderboard_local[0].has("date"), "local records contain character and date")
	service.fetch_top(3, _receive)
	_check(response.entries.size() == 3, "fetch respects limit")
	service.submit_score("TIE", 210, _receive)
	_check(response.player_rank == 1 and response.entries[0].name == "TIE" and response.entries[0].is_player, "equal scores identify the latest run")
	service.submit_score("OUTSIDE", 0, _receive)
	_check(response.player_rank == 11 and not response.entries.any(func(entry: Dictionary): return bool(entry.is_player)), "outside top ten has rank without highlighting another run")

	var game := MainScene.instantiate() as GameManager
	game.save_manager = save
	root.add_child(game)
	await process_frame
	game.start_game()
	game.tutorial_active = false
	game.score = 12840
	game.run_coins = 7
	game.current_lives = 0
	game._enter_player_dead(GameManager.DeathCause.FALL)
	await process_frame
	_check(game.death_phase == "continue" and game.get_node("HUD/ContinueAd").visible and game.get_node("HUD/NoThanks").visible, "death starts with continue and no thanks")
	_check(not game.result_recorded and int(save.profile.best_score) == 210, "continue offer does not finalize score")
	game._continue_after_reward()
	_check(game.current_lives == 1 and game.app_state == GameManager.AppState.PLAYING and game.death_phase == "", "rewarded continue retains one life")
	game.current_lives = 0
	game._enter_player_dead(GameManager.DeathCause.FALL)
	await process_frame
	await _press_key(KEY_RIGHT)
	_check(game.get_viewport().gui_get_focus_owner() == game.get_node("HUD/NoThanks"), "arrow selects no thanks")
	await _press_key(KEY_ENTER)
	_check(game.death_phase == "result" and game.result_new_best and save.profile.best_score == 12840, "no thanks saves score and enters result")
	_check(game.get_node("HUD/Dead").text == "NEW HIGH SCORE!" and game.get_node("HUD/RunCoinsResult").text == "+7 COINS", "result displays high score and run coins")
	_check(not game.leaderboard_visible, "summary appears before leaderboard")
	await _press_key(KEY_SPACE)
	_check(game.leaderboard_visible and game.leaderboard_source == "local" and game.leaderboard_entries.size() == 10, "key reveals device leaderboard")
	_check(game.leaderboard_entries[0].name == "CLASSIC CLIMBER" and game.leaderboard_entries[0].is_player, "empty player name uses economy display name")
	_check(game._visible_death_actions().size() == 3 and game.get_node("HUD/RestartRun").text == "PLAY AGAIN", "result has play again shop and menu")
	await _press_key(KEY_RIGHT)
	_check(game.get_viewport().gui_get_focus_owner() == game.get_node("HUD/DeathShop"), "result arrow selects shop")
	for size in [Vector2(960, 540), Vector2(540, 960)]:
		game.layout_hud_for_viewport(size)
		var contained := true
		var viewport_rect := Rect2(Vector2.ZERO, size)
		for control: Control in [game.get_node("HUD/Dead"), game.get_node("HUD/RunBest"), game.get_node("HUD/RunCoinsResult"), game.get_node("HUD/LeaderboardTitle"), game.get_node("HUD/LeaderboardSource"), game.get_node("HUD/RestartRun"), game.get_node("HUD/DeathShop"), game.get_node("HUD/DeathMenu")]:
			contained = contained and viewport_rect.encloses(control.get_rect())
		for row in game.leaderboard_rows:
			contained = contained and viewport_rect.encloses(row.get_rect()) and row.get_rect().end.y < game.get_node("HUD/RestartRun").position.y
		_check(contained, "numeric panel bounds %dx%d (not visual QA)" % [size.x, size.y])
	game._menu_from_death()
	_check(game.get_node("HUD/MenuBest").text == "BEST 12,840" and game.death_phase == "", "menu shows saved best")
	game.start_game()
	game.tutorial_active = false
	game.score = 12
	game.economy.config["ad_revive_max_per_stage"] = 1
	var stage: int = game.stages.stage_for_y(game.player.global_position.y)
	game.ad_revives_by_stage[stage] = 1
	game.current_lives = 0
	game._enter_player_dead(GameManager.DeathCause.FALL)
	_check(game.death_phase == "result" and not game.get_node("HUD/ContinueAd").visible and not game.result_new_best, "exhausted continue skips directly to result")
	await create_timer(1.05).timeout
	_check(game.leaderboard_visible, "leaderboard opens after one second")
	var old_generation: int = game.run_generation
	game._restart_run_from_death()
	_check(game.run_generation == old_generation + 1 and game.score == 0 and game.current_lives == 3, "play again starts fresh three-life run")
	game.queue_free()
	service.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
	print("test_leaderboard_local.gd: %d PASS / %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _receive(value: Dictionary) -> void:
	response = value

func _press_key(keycode: Key) -> void:
	var pressed := InputEventKey.new()
	pressed.keycode = keycode
	pressed.physical_keycode = keycode
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await process_frame
	var released := InputEventKey.new()
	released.keycode = keycode
	released.physical_keycode = keycode
	Input.parse_input_event(released)
	await process_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)
