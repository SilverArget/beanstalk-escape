extends SceneTree

const OUTPUT_ROOT := "res://../03-test/qa/world"
const SEAM_ROOT := OUTPUT_ROOT + "/seam"
const MEASUREMENTS_PATH := OUTPUT_ROOT + "/measurements.json"
const STAGE_SAMPLES := [
	{"label": "stage-1", "stage": 1, "position": Vector2(0.0, -525.0)},
	{"label": "stage-2", "stage": 2, "position": Vector2(0.0, -2025.0)},
	{"label": "stage-3", "stage": 3, "position": Vector2(0.0, -3440.0)},
	{"label": "stage-4", "stage": 4, "position": Vector2(0.0, -5025.0)},
	{"label": "stage-5", "stage": 5, "position": Vector2(0.0, -6525.0)},
]
const SURFACE_COLORS := [
	Color("173d2f"), Color("4c9a4d"), Color("276346"), Color("b8dd72"),
	Color("397447"), Color("4e9556"), Color("5aa860"), Color("77bb58"),
]

var game: GameManager
var world: Node2D
var rig: CharacterRig
var document := {
	"generated_by": "res://tests/capture_gate3a_world.gd",
	"resolution": [960, 540],
	"frames": [],
	"seam_frames": [],
}

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("NOT RUN G3A-WORLD-CAPTURE requires a rendered 960x540 window")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SEAM_ROOT))
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	get_root().add_child(game)
	await process_frame
	game.start_game()
	await process_frame
	world = game.get_node("World") as Node2D
	rig = game.player.body as CharacterRig
	rig.set_skin("M1")
	rig.seek_animation("climb_loop", 0.20)
	document["visual_contract"] = world.qa_visual_contract()
	for sample: Dictionary in STAGE_SAMPLES:
		await _capture_stage(sample)
	for index in 13:
		await _capture_seam(index)
	var file := FileAccess.open(MEASUREMENTS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(document, "\t") + "\n")
	print("PASS G3A-WORLD-CAPTURE stages=%d seam=%d" % [document.frames.size(), document.seam_frames.size()])
	quit(0)

func _capture_stage(sample: Dictionary) -> void:
	await _place_player(sample.position)
	rig.visible = false
	var background := await _render_frame()
	rig.visible = true
	var image := await _render_frame()
	image.save_png(OUTPUT_ROOT.path_join("%s-960x540.png" % sample.label))
	var measurement := _measure_frame(image, background, int(sample.stage), game.player.global_position)
	measurement["file"] = "%s-960x540.png" % sample.label
	measurement["label"] = sample.label
	document.frames.append(measurement)

func _capture_seam(index: int) -> void:
	var shift := float(index) * 64.0
	await _place_player(Vector2(0.0, -260.0 - shift))
	var image := await _render_frame()
	var file_name := "seam-%02d.png" % index
	image.save_png(SEAM_ROOT.path_join(file_name))
	var scan_y := clampi(roundi((world.get_global_transform_with_canvas() * Vector2(0.0, game.player.global_position.y + 150.0)).y), 0, image.get_height() - 1)
	document.seam_frames.append({
		"file": file_name,
		"camera_shift_px": shift,
		"module_quarter_step": shift / 64.0,
		"surface_scan_y": scan_y,
		"trunk_visible_width_px": _best_surface_run(image, 480, scan_y, 160, 200).width,
	})

func _place_player(position: Vector2) -> void:
	game.process_mode = Node.PROCESS_MODE_INHERIT
	for settle_frame in 30:
		game.player.global_position = position
		game.spider.global_position = position + Vector2(0.0, Balance.START_DISTANCE * 2.0)
		game.player._sync_stage_mode()
		game.stages.update_progress(position.y)
		rig.seek_animation("climb_loop", 0.20)
		world.queue_redraw()
		await physics_frame
	game.player.global_position = position
	game.spider.global_position = position + Vector2(0.0, Balance.START_DISTANCE * 2.0)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame

func _render_frame() -> Image:
	world.queue_redraw()
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()

func _measure_frame(image: Image, background: Image, stage_number: int, player_position: Vector2) -> Dictionary:
	var surface_runs := []
	if stage_number <= 2:
		surface_runs.append(_best_surface_run(image, 480, 270, 160, 200))
	else:
		var center_ranges := [[300, 450], [451, 509], [510, 660]]
		for route in 3:
			var screen_x := 480 + int(Balance.ROUTE_X[route])
			var run := _best_surface_run(image, screen_x, 270, 36, 56, 130, int(center_ranges[route][0]), int(center_ranges[route][1]))
			run["route"] = route
			surface_runs.append(run)
	return {
		"stage": stage_number,
		"player_world": [snappedf(player_position.x, 0.1), snappedf(player_position.y, 0.1)],
		"surface_runs": surface_runs,
		"branch_centers_world_x": Balance.ROUTE_X.duplicate(),
		"largest_texture_element_px": float(world.qa_visual_contract().texture_repeat_px),
		"largest_leaf_px": float(world.qa_visual_contract().max_leaf_px),
		"outline_px": float(world.qa_visual_contract().outline_px),
		"character_boundary_contrast_ge_3_ratio": snappedf(_character_contrast(image, background), 0.0001),
	}

func _surface_run(image: Image, expected_x: int, expected_y: int) -> Dictionary:
	var y := clampi(expected_y, 0, image.get_height() - 1)
	var center := clampi(expected_x, 0, image.get_width() - 1)
	var found := -1
	for radius in 25:
		for candidate in [center - radius, center + radius]:
			if candidate >= 0 and candidate < image.get_width() and _is_surface(image.get_pixel(candidate, y)):
				found = candidate
				break
		if found >= 0:
			break
	if found < 0:
		return {"scan_y": y, "left": -1, "right": -1, "center_x": expected_x, "width": 0}
	var left := found
	var right := found
	var misses := 0
	while left > 0 and misses < 3:
		left -= 1
		misses = 0 if _is_surface(image.get_pixel(left, y)) else misses + 1
	left += misses
	misses = 0
	while right < image.get_width() - 1 and misses < 3:
		right += 1
		misses = 0 if _is_surface(image.get_pixel(right, y)) else misses + 1
	right -= misses
	return {"scan_y": y, "left": left, "right": right, "center_x": int(round((left + right) * 0.5)), "width": right - left + 1}

func _best_surface_run(image: Image, expected_x: int, expected_y: int, minimum_width: int, maximum_width: int, x_search_radius := 0, minimum_center := -1, maximum_center := 10000) -> Dictionary:
	var best := {"scan_y": expected_y, "left": -1, "right": -1, "center_x": expected_x, "width": 0}
	var best_score := INF
	for offset in range(0, 241, 4):
		for direction in [-1, 1]:
			var y: int = expected_y + offset * int(direction)
			if y < 8 or y >= image.get_height() - 8:
				continue
			for x_offset in range(-x_search_radius, x_search_radius + 1, 8 if x_search_radius > 0 else 1):
				var run := _surface_run(image, expected_x + x_offset, y)
				var width := int(run.width)
				if width < minimum_width or width > maximum_width or int(run.center_x) < minimum_center or int(run.center_x) > maximum_center:
					continue
				var target := float(minimum_width + maximum_width) * 0.5
				var score := absf(float(width) - target) + float(offset) * 0.002 + absf(float(int(run.center_x) - expected_x)) * 0.01
				if score < best_score:
					best_score = score
					best = run
	return best

func _is_surface(pixel: Color) -> bool:
	for target in SURFACE_COLORS:
		if maxf(maxf(absf(pixel.r - target.r), absf(pixel.g - target.g)), absf(pixel.b - target.b)) <= 0.10:
			return true
	return false

func _character_contrast(image: Image, background: Image) -> float:
	var center := game.player.get_global_transform_with_canvas().origin
	var bounds := Rect2i(clampi(roundi(center.x) - 80, 1, image.get_width() - 2), clampi(roundi(center.y) - 80, 1, image.get_height() - 2), 160, 170)
	bounds.size.x = mini(bounds.size.x, image.get_width() - bounds.position.x - 1)
	bounds.size.y = mini(bounds.size.y, image.get_height() - bounds.position.y - 1)
	var mask := {}
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if _color_delta(image.get_pixel(x, y), background.get_pixel(x, y)) > 0.06:
				mask[Vector2i(x, y)] = true
	var passing := 0
	var total := 0
	for point: Vector2i in mask:
		var boundary := false
		for offset_y in range(-1, 2):
			for offset_x in range(-1, 2):
				if not mask.has(point + Vector2i(offset_x, offset_y)):
					boundary = true
		if not boundary:
			continue
		total += 1
		if _contrast_ratio(image.get_pixelv(point), background.get_pixelv(point)) >= 3.0:
			passing += 1
	return float(passing) / float(total) if total > 0 else 0.0

func _color_delta(first: Color, second: Color) -> float:
	return maxf(maxf(absf(first.r - second.r), absf(first.g - second.g)), absf(first.b - second.b))

func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)

func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)

func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
