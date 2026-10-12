extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String, detail: String) -> void:
	if condition:
		passed += 1
		print("PASS %s %s" % [label, detail])
	else:
		failed += 1
		print("FAIL %s %s" % [label, detail])

func _make_game() -> GameManager:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	return game

func _run() -> void:
	var skip_game := await _make_game()
	skip_game.start_game()
	var intro_started: bool = skip_game.app_state == GameManager.AppState.INTRO and skip_game.intro_active and skip_game._readonly_state_snapshot().intro.visual_mode == "climb"
	skip_game._finish_intro()
	var skip_snapshot := [skip_game.player.global_position, skip_game.spider.global_position, skip_game.beans.hit_count, skip_game.total_time]
	_check(intro_started and skip_game.app_state == GameManager.AppState.PLAYING and not skip_game.intro_active, "INTRO-SKIP", "state=%s gap=%.1f" % [GameManager.AppState.keys()[skip_game.app_state], skip_game.spider.distance_to_player()])
	skip_game.queue_free()
	await process_frame

	var complete_game := await _make_game()
	complete_game.start_game()
	complete_game._update_intro(float(GameManager.INTRO_BEAT_SECONDS[0]) + 0.01)
	var summit_visible: bool = complete_game.intro_beat == 1 and complete_game._readonly_state_snapshot().intro.visual_mode == "summit" and complete_game.get_node("HUD/IntroSummit").visible
	_check(summit_visible, "INTRO-SUMMIT", "mode=%s texture=%s" % [complete_game._readonly_state_snapshot().intro.visual_mode, str(complete_game.get_node("HUD/IntroSummit").texture != null)])
	complete_game._update_intro(float(GameManager.INTRO_BEAT_SECONDS[1]) + 0.01)
	complete_game._update_intro(0.10)
	var guardian_body := complete_game.spider.get_node("Body") as Node2D
	var guardian_visible: bool = complete_game.intro_beat == 2 and complete_game._readonly_state_snapshot().intro.visual_mode == "guardian" and guardian_body.visible and guardian_body.scale == GameManager.INTRO_GUARDIAN_SCALE
	_check(guardian_visible, "INTRO-GUARDIAN", "mode=%s scale=%.2f shake=%.2f" % [complete_game._readonly_state_snapshot().intro.visual_mode, guardian_body.scale.x, complete_game.player.get_node("Camera2D").offset.length()])
	complete_game._update_intro(float(GameManager.INTRO_BEAT_SECONDS[2]) + 0.01)
	var complete_snapshot := [complete_game.player.global_position, complete_game.spider.global_position, complete_game.beans.hit_count, complete_game.total_time]
	_check(complete_game.app_state == GameManager.AppState.PLAYING and not complete_game.intro_active, "INTRO-COMPLETE", "state=%s duration=%.1f" % [GameManager.AppState.keys()[complete_game.app_state], 7.6])
	var presentation_reset: bool = not complete_game.get_node("HUD/IntroSummit").visible and guardian_body.scale == Vector2.ONE and complete_game.player.get_node("Camera2D").offset == Vector2.ZERO
	_check(skip_snapshot == complete_snapshot and complete_game.player.global_position == Vector2.ZERO and complete_game.spider.global_position == Vector2(0.0, Balance.START_DISTANCE) and presentation_reset, "INTRO-EQUIVALENCE", "skip_and_complete_start_equal=%s presentation_reset=%s" % [str(skip_snapshot == complete_snapshot), str(presentation_reset)])
	complete_game.queue_free()
	await process_frame

	print("RESULT intro_smoke PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
