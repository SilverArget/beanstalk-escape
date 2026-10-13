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
	game.stages.current_stage = 3
	game.restart_stage()
	var stage_start_y := game.stages.stage_bottom_y(3)
	var safe_y := stage_start_y - 240.0
	game.player.reset_run(Vector2(game.stages.branch_x_at(1, safe_y), safe_y))
	game._remember_continue_checkpoint()

	game.on_bean_hit()
	_check(game.current_lives == 2, "first hit spends one life")
	game.hit_invulnerability_remaining = 0.0
	game.on_rock_hit()
	_check(game.current_lives == 1, "second hit spends one life")
	game.hit_invulnerability_remaining = 0.0
	game.on_bean_hit()
	game._update_hud()
	_check(game.current_lives == 0 and game.app_state == GameManager.AppState.PLAYER_DEAD and game.get_node("HUD/ContinueAd").visible, "third hit opens revive panel")

	var death_y := game.player.global_position.y
	game._continue_with_ad()
	_check(game.platform_services.fake_ad_snapshot().active, "rewarded fallback opens fake ad")
	game.platform_services._finish_fake_ad(true)
	_check(game.app_state == GameManager.AppState.PLAYING and game.current_lives == 1 and is_equal_approx(game.player.global_position.y, death_y), "fake reward revives at same height with one life")

	game.hit_invulnerability_remaining = 0.0
	game.on_bean_hit()
	game.restart_stage()
	_check(game.app_state == GameManager.AppState.PLAYING and game.current_lives == 3 and is_equal_approx(game.player.global_position.y, stage_start_y), "restart returns to stage start with full lives")

	game.tutorial_active = true
	var tutorial_lives: int = game.current_lives
	game.hit_invulnerability_remaining = 0.0
	game.on_bean_hit()
	_check(game.current_lives == tutorial_lives, "tutorial hit spends no life")
	game.tutorial_active = false

	game.hit_invulnerability_remaining = 0.0
	game.on_rock_hit()
	var after_first_hit: int = game.current_lives
	game.on_bean_hit()
	_check(game.current_lives == after_first_hit and game.hit_invulnerability_remaining > 0.0, "invulnerability blocks a second life loss")

	var snapshot := game._readonly_state_snapshot()
	_check(snapshot.has("lives") and snapshot.has("revive_panel") and snapshot.has("fake_ad"), "web snapshot exposes lives and revive state")
	print("test_lives.gd: %d PASS / %d FAIL" % [passed, failed])
	game.free()
	quit(0 if failed == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
