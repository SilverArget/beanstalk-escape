extends SceneTree

const SAMPLE_FRAMES := 300
const FRAME_BUDGET_MS := 8.0

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String, detail: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s — %s" % [label, detail])
	else:
		failed += 1
		print("FAIL: %s — %s" % [label, detail])

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	var requested := int(OS.get_environment("BEANSTALK_PERF_FRAMES"))
	var frame_count := requested if requested > 0 else SAMPLE_FRAMES
	await _measure_case(game, "menu", 0, frame_count)
	for stage_number in [1, 6, 16, 30]:
		_prepare_stage(game, stage_number)
		await _measure_case(game, "stage-%d" % stage_number, stage_number, frame_count)
	game.queue_free()
	await process_frame
	print("PERFORMANCE-WINDOWING: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _prepare_stage(game: GameManager, stage_number: int) -> void:
	var start_y := game.stages.stage_bottom_y(stage_number)
	game.player.reset_run(Vector2(0.0, start_y))
	game.spider.reset_run(Vector2(0.0, start_y + Balance.START_DISTANCE))
	game.stages.current_stage = stage_number
	game.app_state = GameManager.AppState.PLAYING
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	if stage_number == 1:
		game.golds.reset_run()
	game.rocks.reset_run()
	game.storm.reset_run()
	if game.rocks.has_method("refresh_active_window"):
		game.rocks.call("refresh_active_window", true)
	if game.storm.has_method("refresh_active_window"):
		game.storm.call("refresh_active_window", true)

func _measure_case(game: GameManager, label: String, stage_number: int, frame_count: int) -> void:
	for warmup in 5:
		await process_frame
	var started := Time.get_ticks_usec()
	for frame in frame_count:
		await process_frame
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0
	var average_ms := elapsed_ms / float(frame_count)
	var active_rocks := game.rocks.hazards.size()
	var active_storm := game.storm.campaign_slots.size()
	var bounded := active_rocks <= 30 and active_storm <= 30
	var timing_ok := average_ms <= FRAME_BUDGET_MS
	_check(timing_ok and bounded, label, "avg=%.3fms frames=%d rocks=%d storm=%d" % [average_ms, frame_count, active_rocks, active_storm])
