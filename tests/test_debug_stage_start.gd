extends SceneTree

const SURVIVAL_SECONDS := 3.0
const PHYSICS_HZ := 60

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String, detail: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s - %s" % [label, detail])
	else:
		failed += 1
		print("FAIL: %s - %s" % [label, detail])

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	var failed_stages: Array[int] = []
	for stage_number in range(2, Balance.STAGE_COUNT + 1):
		game.restart()
		game._start_debug_stage(stage_number)
		var spawn_stage := game.stages.stage_for_y(game.player.global_position.y)
		var start_gap := game.spider.distance_to_player()
		var death_tick := -1
		for tick in int(SURVIVAL_SECONDS * PHYSICS_HZ):
			await physics_frame
			if game.app_state != GameManager.AppState.PLAYING and death_tick < 0:
				death_tick = tick
		var alive := game.app_state == GameManager.AppState.PLAYING
		var current_stage := game.stages.stage_for_y(game.player.global_position.y)
		if spawn_stage != stage_number or not alive:
			failed_stages.append(stage_number)
		_check(
			spawn_stage == stage_number and alive and is_equal_approx(start_gap, Balance.START_DISTANCE),
			"DEBUG-STAGE-%02d" % stage_number,
			"spawn=%d after_3s=%d alive=%s death_tick=%d gap=%.1f rock_hits=%d" % [spawn_stage, current_stage, alive, death_tick, start_gap, game.rocks.hit_count]
		)
	game.restart()
	var normal_stage := game.stages.stage_for_y(game.player.global_position.y)
	var normal_gap := game.spider.distance_to_player()
	_check(
		normal_stage == 1 and game.player.global_position.is_equal_approx(Vector2.ZERO) and is_equal_approx(normal_gap, Balance.START_DISTANCE),
		"NORMAL-STAGE-1",
		"stage=%d player_y=%.1f gap=%.1f" % [normal_stage, game.player.global_position.y, normal_gap]
	)
	game.queue_free()
	await process_frame
	print("DEBUG-STAGE-START: PASS %d / FAIL %d failed_stages=%s" % [passed, failed, failed_stages])
	quit(0 if failed == 0 else 1)
