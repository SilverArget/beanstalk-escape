extends SceneTree

const STAGES := [3, 8, 16, 30]
const PROGRESS := 0.42

var game: Node
var world: Node2D
var output_dir := ""
var reference_dir := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("FAIL ribbon pixels require a rendered Compatibility window")
		quit(2)
		return
	output_dir = OS.get_environment("RIBBON_OUTPUT")
	reference_dir = OS.get_environment("RIBBON_REFERENCE")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://../03-test/qa/ribbon-regression/current")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	world = game.get_node("World") as Node2D
	_hide_non_world()
	var failures := 0
	for stage_number in STAGES:
		await _place_stage(stage_number)
		var image := await _capture(false)
		var mask := await _capture(true)
		var image_path := output_dir.path_join("stage-%02d.png" % stage_number)
		var mask_path := output_dir.path_join("stage-%02d-mask.png" % stage_number)
		image.save_png(image_path)
		mask.save_png(mask_path)
		var calls := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var stripe := _stripe_score(image, stage_number)
		var difference := -1.0
		var periodic_error := -1.0
		if not reference_dir.is_empty():
			var reference := Image.load_from_file(reference_dir.path_join("stage-%02d.png" % stage_number))
			var reference_mask := Image.load_from_file(reference_dir.path_join("stage-%02d-mask.png" % stage_number))
			difference = _masked_mean_absolute_difference(image, mask, reference, reference_mask)
			periodic_error = _periodic_row_error(image, mask, reference, reference_mask)
			if difference >= 2.0 / 255.0:
				failures += 1
		if stage_number >= 8 and calls > 250:
			failures += 1
		print("RIBBON stage=%d mad_255=%.3f periodic_error_255=%.3f joint_jump_255=%.3f draw_calls=%d" % [stage_number, difference * 255.0, periodic_error * 255.0, stripe * 255.0, calls])
	game.queue_free()
	await process_frame
	print("RIBBON_RESULT PASS=%d FAIL=%d" % [STAGES.size() - failures, failures])
	quit(0 if failures == 0 else 1)

func _hide_non_world() -> void:
	for child in game.get_children():
		if child == world:
			continue
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false

func _place_stage(stage_number: int) -> void:
	var y: float = float(game.stages.stage_bottom_y(stage_number)) - float(game.stages.stage_length(stage_number)) * PROGRESS
	game.player.global_position = Vector2(0.0, y)
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	var camera := game.player.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	camera.force_update_scroll()
	await process_frame
	camera.force_update_scroll()
	if _has_property(world, "cached_camera_top"):
		world.set("cached_camera_top", camera.get_screen_center_position().y - 270.0)
	world.queue_redraw()
	await process_frame
	await process_frame

func _capture(mask_mode: bool) -> Image:
	world.set("qa_support_mask", mask_mode)
	world.queue_redraw()
	RenderingServer.force_draw(true)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	world.set("qa_support_mask", false)
	return image

func _masked_mean_absolute_difference(image: Image, mask: Image, reference: Image, reference_mask: Image) -> float:
	var difference := 0.0
	var samples := 0
	for y in image.get_height():
		for x in image.get_width():
			if not _is_mask_pixel(mask.get_pixel(x, y)) and not _is_mask_pixel(reference_mask.get_pixel(x, y)):
				continue
			var pixel := image.get_pixel(x, y)
			var expected := reference.get_pixel(x, y)
			difference += absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b)
			samples += 3
	return difference / maxf(float(samples), 1.0)

func _periodic_row_error(image: Image, mask: Image, reference: Image, reference_mask: Image) -> float:
	var phase_error := PackedFloat32Array()
	var phase_samples := PackedInt32Array()
	phase_error.resize(12)
	phase_samples.resize(12)
	for y in range(20, image.get_height() - 20):
		var row_error := 0.0
		var row_samples := 0
		for x in image.get_width():
			if not _is_mask_pixel(mask.get_pixel(x, y)) and not _is_mask_pixel(reference_mask.get_pixel(x, y)):
				continue
			var pixel := image.get_pixel(x, y)
			var expected := reference.get_pixel(x, y)
			row_error += absf(pixel.r - expected.r) + absf(pixel.g - expected.g) + absf(pixel.b - expected.b)
			row_samples += 3
		if row_samples > 0:
			var phase := y % 12
			phase_error[phase] += row_error / float(row_samples)
			phase_samples[phase] += 1
	var minimum := INF
	var maximum := 0.0
	for phase in 12:
		if phase_samples[phase] == 0:
			continue
		var mean := phase_error[phase] / float(phase_samples[phase])
		minimum = minf(minimum, mean)
		maximum = maxf(maximum, mean)
	return maximum - minimum if not is_inf(minimum) else 0.0

func _stripe_score(image: Image, stage_number: int) -> float:
	var stage_bottom: float = float(game.stages.stage_bottom_y(stage_number))
	var stage_length: float = float(game.stages.stage_length(stage_number))
	var camera := game.player.get_node("Camera2D") as Camera2D
	var camera_top := camera.get_screen_center_position().y - 270.0
	var maximum := 0.0
	for route in 3:
		for segment: Array in game.stages.support_segments(stage_number, route):
			var start_y: float = stage_bottom - maxf(float(segment[0]), (stage_bottom - (camera_top + 520.0)) / stage_length) * stage_length
			var end_y: float = stage_bottom - minf(float(segment[1]), (stage_bottom - (camera_top + 20.0)) / stage_length) * stage_length
			var joint_y: float = start_y - 12.0
			while joint_y > end_y:
				var screen := world.get_global_transform_with_canvas() * Vector2([-150.0, 0.0, 150.0][route], joint_y)
				var row := clampi(int(round(screen.y)), 2, image.get_height() - 3)
				var center_x := clampi(int(round(screen.x)), 24, image.get_width() - 25)
				maximum = maxf(maximum, absf(_row_luma(image, center_x, row - 1) - _row_luma(image, center_x, row + 1)))
				joint_y -= 12.0
	return maximum

func _row_luma(image: Image, center_x: int, y: int) -> float:
	var total := 0.0
	for x in range(center_x - 16, center_x + 17):
		var pixel := image.get_pixel(x, y)
		total += pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
	return total / 33.0

func _is_mask_pixel(pixel: Color) -> bool:
	return pixel.r > 0.9 and pixel.g > 0.9 and pixel.b > 0.9

func _has_property(object: Object, property_name: String) -> bool:
	for property: Dictionary in object.get_property_list():
		if String(property.name) == property_name:
			return true
	return false
