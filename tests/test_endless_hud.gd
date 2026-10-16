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
	game.restart()
	game.tutorial_active = false
	game._update_hud()
	_check(game.score == 0.0 and game.run_coins == 0, "new run starts at zero")
	for frame in 120:
		await physics_frame
	var snapshot := game._readonly_state_snapshot()
	_check(snapshot.score > 0, "normal physics simulation earns climb score")
	_check(not snapshot.hud_stage_counter_visible and not game.get_node("HUD/StageCounter").visible, "stage counter hidden in snapshot and HUD")
	for name in ["MiniMap", "StageBanner", "RewardToast", "DoubleStageReward", "RetryStage", "SkipStageAd", "GoldStatus", "XPStatus", "XPBar"]:
		_check(not game.get_node("HUD/" + name).visible, name + " hidden during play")
	_check(snapshot.hud_score_text == game._format_run_number(snapshot.score) and snapshot.best_score == 0, "snapshot exposes formatted score and default best")
	# Isolate the HUD accounting for deterministic movement and pickup checks.
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	game.rocks.set_physics_process(false)
	game.storm.set_physics_process(false)
	game.golds.set_physics_process(false)
	game.score_previous_y = game.player.global_position.y
	game.golds.combo = 5
	var before := game.score
	game.player.position.y -= 100.0
	game._physics_process(0.0)
	_check(is_equal_approx(game.score - before, 50.0), "100 climbed pixels with X5 earn 50 score")
	before = game.score
	game.player.position.y += 100.0
	game._physics_process(0.0)
	_check(is_equal_approx(game.score, before), "fall never subtracts score")
	game.tutorial_active = true
	game.player.position.y -= 100.0
	game._physics_process(0.0)
	_check(is_equal_approx(game.score, before), "tutorial climb earns no score")
	game.tutorial_active = false
	game.app_state = GameManager.AppState.INTRO
	game.player.position.y -= 100.0
	game._physics_process(0.0)
	_check(is_equal_approx(game.score, before), "story climb earns no score")
	game.app_state = GameManager.AppState.PLAYING
	game.golds.reset_combo()
	var coins: Array[Node] = game.golds.get_children()
	for coin in coins:
		coin.set_physics_process(false)
	var expected_coins := 0
	for index in 2:
		# Both pickups start before either flight arrives: each retains its own reward.
		var coin := coins[index] as GoldCollectible
		coin.taken = true
		game.golds._on_collected(coin.name)
		expected_coins += game.economy.value("gold_per_collectible") * (index + 1)
	await create_timer(0.6).timeout
	_check(game.run_coins == expected_coins, "overlapping coin flights retain X1 and X2 gold rewards")
	_check(game.get_node("HUD/RunCoins").text == game._format_run_number(expected_coins), "arrival updates run coin counter")
	_check(not game.get_node("HUD/RunCoins").text.contains("●"), "coin counter has no unsupported bullet glyph")
	for viewport in [Vector2(960, 540), Vector2(1280, 720), Vector2(540, 960), Vector2(320, 640)]:
		game.layout_hud_for_viewport(viewport)
		var score_rect: Rect2 = game.get_node("HUD/Score").get_rect()
		var coins_rect: Rect2 = game.get_node("HUD/RunCoins").get_rect()
		game.show_gold_combo(5)
		game.gold_combo_tween.custom_step(0.06)
		var combo := game.get_node("HUD/GoldCombo") as Label
		var combo_right := combo.get_global_transform() * Vector2(combo.size.x, combo.size.y * 0.5)
		_check(combo_right.x <= viewport.x - 12.0 and combo.position.y >= coins_rect.end.y and combo.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "animated combo stays below coins and 12 pixels inside right edge at " + str(viewport))
		_check(score_rect.end.x <= viewport.x and score_rect.position.x >= 0 and not score_rect.intersects(game.get_node("HUD/Mute").get_rect()) and not score_rect.intersects(game.get_node("HUD/Lives").get_rect()) and score_rect.end.y <= coins_rect.position.y, "score bounds and controls do not overlap at " + str(viewport))
	game.current_lives = 3
	game.hit_invulnerability_remaining = 0.0
	game.on_bean_hit()
	_check(is_equal_approx(game.score, before) and game.run_coins == expected_coins, "life loss preserves score and run coins")
	game._enter_player_dead(GameManager.DeathCause.OBSTACLE)
	game._continue_after_reward()
	_check(is_equal_approx(game.score, before) and game.run_coins == expected_coins, "ad revival preserves score and run coins")
	game.app_state = GameManager.AppState.MENU
	game._update_hud()
	_check(game.get_node("HUD/GoldStatus").visible and game.get_node("HUD/XPStatus").visible and not game.get_node("HUD/Score").visible, "menu shows account balances")
	_check(game._format_run_number(12840) == "12,840", "score uses comma thousands separator")
	game.restart()
	_check(game.score == 0.0 and game.run_coins == 0, "next run resets both counters")
	print("test_endless_hud.gd: %d PASS / %d FAIL" % [passed, failed])
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failed == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: " + label)
	else:
		failed += 1
		push_error("FAIL: " + label)
