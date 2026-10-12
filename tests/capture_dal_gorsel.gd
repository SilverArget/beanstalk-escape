extends SceneTree

const OUTPUT_ROOT := "res://../03-test/qa/dal-gorsel"
const STAGES := [1, 3, 8, 16, 30]
const SAMPLE_FRAMES := 30

var game: GameManager
var report := {"resolution": [960, 540], "renderer": "Compatibility", "stages": []}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("NOT RUN DAL-GORSEL requires a rendered window")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.start_game()
	await process_frame
	for stage_number in STAGES:
		await _capture_stage(stage_number)
	var output := FileAccess.open(OUTPUT_ROOT.path_join("measurements.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	print("DAL-GORSEL-CAPTURE: PASS stages=%d output=%s" % [report.stages.size(), ProjectSettings.globalize_path(OUTPUT_ROOT)])
	game.queue_free()
	await process_frame
	quit(0)

func _capture_stage(stage_number: int) -> void:
	var y := game.stages.stage_bottom_y(stage_number) - game.stages.stage_length(stage_number) * 0.35
	var lane := 1
	if stage_number >= 3:
		for candidate in 3:
			if game.stages.is_route_open_at(stage_number, candidate, 0.35):
				lane = candidate
				break
	var x := 0.0 if stage_number <= 2 else float(Balance.ROUTE_X[lane])
	game.player.reset_run(Vector2(x, y))
	game.spider.reset_run(Vector2(x, y + Balance.START_DISTANCE * 2.0))
	game.stages.current_stage = stage_number
	game.app_state = GameManager.AppState.PLAYING
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	game.player._sync_stage_mode()
	game.player._update_vine_visual_offset()
	game.rocks.reset_run()
	game.storm.reset_run()
	game.rocks.refresh_active_window(true)
	game.storm.refresh_active_window(true)
	game.stages.stage_banner_remaining = 0.0
	game.tutorial_remaining = 0.0
	game._update_hud()
	var camera := game.player.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	var world := game.get_node("World") as Node2D
	world.queue_redraw()
	for warmup in 12:
		await process_frame
	var calls: Array[int] = []
	for sample in SAMPLE_FRAMES:
		await process_frame
		calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	var file_name := "etap-%02d-960x540.png" % stage_number
	var image := root.get_texture().get_image()
	var save_error := image.save_png(OUTPUT_ROOT.path_join(file_name))
	var average := _average(calls)
	world.visible = false
	await process_frame
	await process_frame
	var calls_without_world := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	world.visible = true
	await process_frame
	report.stages.append({"stage": stage_number, "file": file_name, "draw_calls_avg": average, "draw_calls_min": calls.min(), "draw_calls_max": calls.max(), "draw_calls_without_world": calls_without_world, "world_draw_delta": int(round(average)) - calls_without_world, "save_error": save_error})
	print("DAL-GORSEL stage=%d draw_calls_avg=%.1f min=%d max=%d frame=%s" % [stage_number, average, calls.min(), calls.max(), file_name])

func _average(values: Array[int]) -> float:
	var total := 0
	for value in values:
		total += value
	return float(total) / float(values.size())
