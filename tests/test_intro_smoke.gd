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
	var intro_started := skip_game.app_state == GameManager.AppState.INTRO and skip_game.intro_active
	skip_game._finish_intro()
	var skip_snapshot := [skip_game.player.global_position, skip_game.spider.global_position, skip_game.beans.hit_count, skip_game.total_time]
	_check(intro_started and skip_game.app_state == GameManager.AppState.PLAYING and not skip_game.intro_active, "INTRO-SKIP", "state=%s gap=%.1f" % [GameManager.AppState.keys()[skip_game.app_state], skip_game.spider.distance_to_player()])
	skip_game.queue_free()
	await process_frame

	var complete_game := await _make_game()
	complete_game.start_game()
	for duration in GameManager.INTRO_BEAT_SECONDS:
		complete_game._update_intro(float(duration) + 0.01)
	var complete_snapshot := [complete_game.player.global_position, complete_game.spider.global_position, complete_game.beans.hit_count, complete_game.total_time]
	_check(complete_game.app_state == GameManager.AppState.PLAYING and not complete_game.intro_active, "INTRO-COMPLETE", "state=%s duration=%.1f" % [GameManager.AppState.keys()[complete_game.app_state], 7.6])
	_check(skip_snapshot == complete_snapshot and complete_game.player.global_position == Vector2.ZERO and complete_game.spider.global_position == Vector2(0.0, Balance.START_DISTANCE), "INTRO-EQUIVALENCE", "skip_and_complete_start_equal=%s" % str(skip_snapshot == complete_snapshot))
	complete_game.queue_free()
	await process_frame

	print("RESULT intro_smoke PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
