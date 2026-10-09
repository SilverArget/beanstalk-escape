extends SceneTree

const OUT_DIR := "res://../03-test/qa/scale"
const PLAYER_OUTLINE := Color("152238")
const VINE_FILL := Color("4c9a4d")
var failures := 0
var results := {}

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await physics_frame
	game.start_game()
	game.spider.global_position = Vector2(0, 10000)
	await _position(game, Vector2(0, -500), 1)
	await _capture("production-stage1.png", "stage1", game)
	await _position(game, Vector2(0, -644), 1)
	await _capture("production-stage1-scroll-144.png", "seam_scroll_144", game)
	await _position(game, Vector2(0, -788), 1)
	await _capture("production-stage1-scroll-288.png", "seam_scroll_288", game)
	await _position(game, Vector2(0, -Balance.STAGE_HEIGHT * 2.0 - 500.0), 1)
	game.tutorial_text = "CHANGE BRANCH"
	game.tutorial_remaining = 3.0
	game._update_hud()
	await _capture("production-stage3-supported.png", "stage3", game)
	game.player._begin_branch_transition(1)
	while game.player.transition_progress < 0.48:
		await physics_frame
	await _capture("production-stage3-transfer-mid.png", "transfer_mid", game)
	while game.player.support_state == PlayerController.SupportState.TRANSFERRING:
		await physics_frame
	await _capture("production-stage3-transfer-end.png", "transfer_end", game)
	var file := FileAccess.open(OUT_DIR.path_join("production-measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"reference_size": [960, 540], "source": "rendered production frames sampled by exact pixel colors", "frames": results, "status": "PASS" if failures == 0 else "FAIL"}, "\t"))
	game.queue_free()
	quit(failures)

func _position(game: GameManager, position: Vector2, branch_id: int) -> void:
	game.player.reset_run(position)
	game.player.active_branch = branch_id
	game.player.global_position.x = game.stages.branch_x_at(branch_id, position.y)
	game.spider.global_position = game.player.global_position + Vector2(0, 10000)
	var camera := game.player.get_node("Camera2D") as Camera2D
	camera.reset_smoothing()
	await process_frame
	await RenderingServer.frame_post_draw

func _capture(file_name: String, kind: String, game: GameManager) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := OUT_DIR.path_join(file_name)
	var save_error := image.save_png(path)
	var opaque := _count_transparent(image) == 0
	var char_bounds := _bounds_for_color(image, PLAYER_OUTLINE)
	var record := {"size": [image.get_width(), image.get_height()], "opaque": opaque, "character_bounds": [char_bounds.position.x, char_bounds.position.y, char_bounds.size.x, char_bounds.size.y]}
	if kind == "stage1":
		var trunk_span := _color_span_in_window(image, 100, VINE_FILL, 380, 580)
		record["trunk_span_y100"] = trunk_span
		check(save_error == OK and opaque and char_bounds.size == Vector2i(44, 108) and char_bounds.position.y + 54 == int(ScaleLock.CHARACTER_REFERENCE_Y) and trunk_span == 180, "T02/VIS02", "%s char=%s reference_y=%d trunk_span=%d opaque=%s" % [file_name, str(char_bounds), char_bounds.position.y + 54, trunk_span, str(opaque)])
	elif kind == "stage3":
		var sample_y := 250
		var widths := []
		var centers := []
		for expected_center in [330, 480, 630]:
			var bounds := _color_bounds_in_window(image, sample_y, VINE_FILL, expected_center - 30, expected_center + 30)
			widths.append(bounds.y - bounds.x + 1)
			centers.append((bounds.x + bounds.y) * 0.5)
		record["branch_widths_y250"] = widths
		record["branch_centers_y250"] = centers
		var hint_visible := (game.get_node("HUD/Tutorial") as Label).text == "CHANGE BRANCH"
		check(save_error == OK and opaque and widths == [44, 44, 44] and centers == [329.5, 479.5, 629.5] and hint_visible, "VIS03", "%s widths=%s centers=%s hint_visible=%s opaque=%s" % [file_name, str(widths), str(centers), str(hint_visible), str(opaque)])
	elif kind.begins_with("seam_scroll"):
		var spans := []
		for sample_y in [210, 260, 310]:
			spans.append(_color_span_in_window(image, sample_y, VINE_FILL, 380, 580))
		var wrong_hint := (game.get_node("HUD/Tutorial") as Label).text == "CHANGE BRANCH"
		record["trunk_spans"] = spans
		check(save_error == OK and opaque and spans == [180, 180, 180] and not wrong_hint, "VIS12", "%s trunk_spans=%s visible_seams=0 change_branch=%s opaque=%s" % [file_name, str(spans), str(wrong_hint), str(opaque)])
	else:
		check(save_error == OK and opaque and char_bounds.size.x > 0 and char_bounds.size.y > 0, "VIS03-transfer", "%s character_bounds=%s state=%s progress=%.3f opaque=%s" % [file_name, str(char_bounds), game.player.support_state_name(), game.player.transition_progress, str(opaque)])
	results[kind] = record

func _bounds_for_color(image: Image, color: Color) -> Rect2i:
	var min_point := Vector2i(image.get_width(), image.get_height())
	var max_point := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).is_equal_approx(color):
				min_point = Vector2i(mini(min_point.x, x), mini(min_point.y, y))
				max_point = Vector2i(maxi(max_point.x, x), maxi(max_point.y, y))
	return Rect2i(min_point, max_point - min_point + Vector2i.ONE) if max_point.x >= 0 else Rect2i()

func _runs_for_color(image: Image, y: int, color: Color) -> Array:
	return _run_segments_for_color(image, y, color).map(func(run): return run[1] - run[0] + 1)

func _color_span_in_window(image: Image, y: int, color: Color, from_x: int, to_x: int) -> int:
	var bounds := _color_bounds_in_window(image, y, color, from_x, to_x)
	return bounds.y - bounds.x + 1 if bounds.x >= 0 else 0

func _color_bounds_in_window(image: Image, y: int, color: Color, from_x: int, to_x: int) -> Vector2i:
	var first := -1
	var last := -1
	for x in range(from_x, to_x + 1):
		if image.get_pixel(x, y).is_equal_approx(color):
			if first < 0:
				first = x
			last = x
	return Vector2i(first, last)

func _run_segments_for_color(image: Image, y: int, color: Color) -> Array:
	var runs := []
	var start := -1
	for x in image.get_width():
		var match := image.get_pixel(x, y).is_equal_approx(color)
		if match and start < 0:
			start = x
		elif not match and start >= 0:
			runs.append([start, x - 1])
			start = -1
	if start >= 0:
		runs.append([start, image.get_width() - 1])
	return runs

func _count_transparent(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.999:
				count += 1
	return count
