extends SceneTree

const OUTPUT_ROOT := "res://../03-test/qa/art-reference/pilot"
const RIG_ONLY_ROOT := OUTPUT_ROOT + "/rig-only"
const MEASUREMENTS_PATH := OUTPUT_ROOT + "/measurements.json"
const PILOT_ANIMATIONS := ["idle", "climb_loop", "branch_takeoff", "branch_midair", "branch_landing", "hurt", "skill_time"]
const MEASURE_BACKGROUNDS := {
	"sunny": Color("80d5f4"),
	"twilight": Color("735a9e"),
	"storm": Color("313c68"),
}
const ALPHA_THRESHOLD := 127

var measurement_document: Dictionary
var active_game: GameManager
var active_game_rig: CharacterRig
var local_alpha_points: Dictionary = {}
var stage3_branch_image: Image

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("NOT RUN G3A-CAPTURE requires a rendered 960x540 window")
		quit(2)
		return
	var skin := OS.get_environment("BEANSTALK_SKIN").to_upper()
	if skin not in ["M1", "F1"]:
		skin = "M1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_ROOT.path_join(skin.to_lower()).path_join("frames")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RIG_ONLY_ROOT))
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	get_root().add_child(game)
	await process_frame
	game.start_game()
	var rig := game.player.body as CharacterRig
	rig.set_skin(skin)
	active_game = game
	active_game_rig = rig
	_prepare_measurement_document(skin)
	_cache_contact_part_pixels(rig)
	await _capture_game_frame(game, rig, skin, "stage-1", 1, false)
	await _capture_game_frame(game, rig, skin, "stage-3", 3, false)
	await _capture_game_frame(game, rig, skin, "storm-flat-313c68", 3, true)
	stage3_branch_image = await _capture_stage3_branch_reference(rig)
	game.app_state = GameManager.AppState.PLAYING
	game._update_hud()
	# Freeze gameplay so physics cannot overwrite a sampled rig pose or end the
	# run while the deterministic 30 FPS evidence sequence is being rendered.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture_skill_frame(rig, skin)
	var frame_number := 0
	for animation_name in PILOT_ANIMATIONS:
		var frame_count := 30 if animation_name in ["idle", "climb_loop"] else 18
		for local_frame in frame_count:
			var duration := rig.animation_player.get_animation(animation_name).length
			var sample_time := (float(local_frame) / float(maxi(frame_count - 1, 1))) * duration
			rig.seek_animation(animation_name, sample_time)
			await process_frame
			await RenderingServer.frame_post_draw
			var image := get_root().get_texture().get_image()
			image.save_png(OUTPUT_ROOT.path_join(skin.to_lower()).path_join("frames").path_join("%05d-%s-%02d.png" % [frame_number, animation_name, local_frame]))
			var measurement := await _capture_rig_only(skin, animation_name, local_frame, sample_time)
			if animation_name == "climb_loop":
				measurement["stage3_contacts"] = _measure_stage3_contacts(image, rig)
			measurement_document.skins[skin].animations[animation_name].append(measurement)
			frame_number += 1
	_write_measurements()
	print("PASS G3A-CAPTURE skin=%s frames=%d" % [skin, frame_number])
	quit(0)

func _capture_game_frame(game: GameManager, rig: CharacterRig, skin: String, label: String, stage_number: int, storm: bool) -> void:
	game.player.global_position = Vector2(0, -Balance.STAGE_HEIGHT * (float(stage_number) - 0.35))
	game.spider.global_position = game.player.global_position + Vector2(0, Balance.START_DISTANCE)
	game.player._sync_stage_mode()
	game.stages.update_progress(game.player.global_position.y)
	game.get_node("World").qa_storm_background = storm
	rig.set_outline_background(Color("313c68") if storm else Color("80d5f4"))
	rig.seek_animation("climb_loop", 0.20)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	image.save_png(OUTPUT_ROOT.path_join("%s-%s-960x540.png" % [skin.to_lower(), label]))

func _capture_stage3_branch_reference(rig: CharacterRig) -> Image:
	rig.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	rig.visible = true
	return image

func _capture_skill_frame(rig: CharacterRig, skin: String) -> void:
	rig.seek_animation("skill_time", 0.45)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	image.save_png(OUTPUT_ROOT.path_join("%s-skill-time-960x540.png" % skin.to_lower()))

func _capture_rig_only(skin: String, animation_name: String, local_frame: int, sample_time: float) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.visible = false
	viewport.add_child(background)
	var isolated_rig := (load("res://scenes/character_rig.tscn") as PackedScene).instantiate() as CharacterRig
	isolated_rig.position = Vector2(480, 270)
	viewport.add_child(isolated_rig)
	get_root().add_child(viewport)
	isolated_rig.set_skin(skin)
	isolated_rig.seek_animation(animation_name, sample_time)
	if animation_name == "skill_time" and local_frame in [0, 17]:
		print("G3A-WING skin=%s frame=%d visible=%s scale=%s texture=%s" % [skin, local_frame, isolated_rig.time_wings.visible, isolated_rig.time_wings.scale, isolated_rig.time_wings.texture != null])
	var image := await _render_viewport(viewport)
	image.save_png(RIG_ONLY_ROOT.path_join("%s-%s-%02d.png" % [skin.to_lower(), animation_name, local_frame]))
	var full_bounds := _alpha_bounds(image)
	var result := {
		"frame": local_frame,
		"time_seconds": snappedf(sample_time, 0.0001),
		"head_to_foot_px": 0,
		"body_width_px": 0,
		"alpha127_components": _component_count(image, full_bounds),
		"contrast_boundary_ge_3_ratio": {},
	}
	for background_name: String in MEASURE_BACKGROUNDS:
		background.color = MEASURE_BACKGROUNDS[background_name]
		background.visible = true
		viewport.transparent_bg = false
		isolated_rig.set_outline_background(MEASURE_BACKGROUNDS[background_name])
		var flat_image := await _render_viewport(viewport)
		result.contrast_boundary_ge_3_ratio[background_name] = snappedf(
			_boundary_contrast_ratio(image, flat_image, MEASURE_BACKGROUNDS[background_name]), 0.0001
		)
	background.visible = false
	viewport.transparent_bg = true
	var original_visibility := _part_visibility(isolated_rig)
	_show_only_parts(isolated_rig, original_visibility, [
		"head_neutral", "head_hurt", "torso", "pelvis",
		"thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
	])
	var height_image := await _render_viewport(viewport)
	result.head_to_foot_px = _alpha_bounds(height_image).size.y
	_show_only_parts(isolated_rig, original_visibility, ["torso", "pelvis"])
	var body_image := await _render_viewport(viewport)
	result.body_width_px = _alpha_bounds(body_image).size.x
	viewport.queue_free()
	await process_frame
	return result

func _render_viewport(viewport: SubViewport) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _part_visibility(rig: CharacterRig) -> Dictionary:
	var result := {}
	for part_name: String in rig.part_sprites:
		result[part_name] = (rig.part_sprites[part_name] as Sprite2D).visible
	return result

func _show_only_parts(rig: CharacterRig, original_visibility: Dictionary, keep: Array) -> void:
	for part_name: String in rig.part_sprites:
		(rig.part_sprites[part_name] as Sprite2D).visible = original_visibility[part_name] and part_name in keep
	rig.time_wings.visible = false

func _alpha_bounds(image: Image) -> Rect2i:
	var used := image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2i()
	var left := used.end.x
	var top := used.end.y
	var right := used.position.x - 1
	var bottom := used.position.y - 1
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a8 > ALPHA_THRESHOLD:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1) if right >= left else Rect2i()

func _component_count(image: Image, bounds: Rect2i) -> int:
	if bounds.size == Vector2i.ZERO:
		return 0
	var visited := PackedByteArray()
	visited.resize(bounds.size.x * bounds.size.y)
	var components := 0
	for local_y in bounds.size.y:
		for local_x in bounds.size.x:
			var start_index := local_y * bounds.size.x + local_x
			if visited[start_index] or image.get_pixel(bounds.position.x + local_x, bounds.position.y + local_y).a8 <= ALPHA_THRESHOLD:
				continue
			components += 1
			var queue := [Vector2i(local_x, local_y)]
			visited[start_index] = 1
			var queue_index := 0
			while queue_index < queue.size():
				var current: Vector2i = queue[queue_index]
				queue_index += 1
				for offset_y in range(-1, 2):
					for offset_x in range(-1, 2):
						var next := current + Vector2i(offset_x, offset_y)
						if next.x < 0 or next.y < 0 or next.x >= bounds.size.x or next.y >= bounds.size.y:
							continue
						var next_index := next.y * bounds.size.x + next.x
						if not visited[next_index] and image.get_pixel(bounds.position.x + next.x, bounds.position.y + next.y).a8 > ALPHA_THRESHOLD:
							visited[next_index] = 1
							queue.append(next)
	return components

func _boundary_contrast_ratio(mask: Image, flat_image: Image, background: Color) -> float:
	var bounds := _alpha_bounds(mask)
	var passing := 0
	var total := 0
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			if mask.get_pixel(x, y).a8 <= ALPHA_THRESHOLD:
				continue
			var boundary := false
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					if mask.get_pixel(x + offset_x, y + offset_y).a8 <= ALPHA_THRESHOLD:
						boundary = true
			if not boundary:
				continue
			total += 1
			if _contrast_ratio(flat_image.get_pixel(x, y), background) >= 3.0:
				passing += 1
	return float(passing) / float(total) if total > 0 else 0.0

func _contrast_ratio(first: Color, second: Color) -> float:
	var first_luminance := _relative_luminance(first)
	var second_luminance := _relative_luminance(second)
	return (maxf(first_luminance, second_luminance) + 0.05) / (minf(first_luminance, second_luminance) + 0.05)

func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) + 0.7152 * _linear_channel(color.g) + 0.0722 * _linear_channel(color.b)

func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)

func _prepare_measurement_document(skin: String) -> void:
	measurement_document = {
		"generated_by": "res://tests/capture_gate3a_pilot.gd",
		"alpha_threshold": ALPHA_THRESHOLD,
		"contrast_threshold": 3.0,
		"backgrounds": {"sunny": "#80D5F4", "twilight": "#735A9E", "storm": "#313C68"},
		"skins": {},
	}
	if skin != "M1" and FileAccess.file_exists(MEASUREMENTS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MEASUREMENTS_PATH))
		if parsed is Dictionary:
			measurement_document = parsed
	measurement_document.skins[skin] = {"animations": {}}
	for animation_name in PILOT_ANIMATIONS:
		measurement_document.skins[skin].animations[animation_name] = []

func _write_measurements() -> void:
	var file := FileAccess.open(MEASUREMENTS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(measurement_document, "\t") + "\n")

func _cache_contact_part_pixels(rig: CharacterRig) -> void:
	local_alpha_points.clear()
	for part_name in ["hand_l_grip", "hand_r_grip", "foot_l", "foot_r"]:
		var sprite := rig.part_sprites[part_name] as Sprite2D
		var texture_image := sprite.texture.get_image()
		var points := PackedVector2Array()
		var region := sprite.region_rect
		for local_y in int(region.size.y):
			for local_x in int(region.size.x):
				var source_x := int(region.position.x) + local_x
				var source_y := int(region.position.y) + local_y
				if texture_image.get_pixel(source_x, source_y).a8 > ALPHA_THRESHOLD:
					points.append(Vector2(local_x + 0.5, local_y + 0.5) - region.size * 0.5)
		local_alpha_points[part_name] = points

func _measure_stage3_contacts(image: Image, rig: CharacterRig) -> Array:
	var result := []
	var rig_center_x := int(round(rig.skeleton.get_global_transform_with_canvas().origin.x))
	var branch_edges := _branch_edges_by_row(stage3_branch_image if stage3_branch_image != null else image, rig_center_x)
	for part_name in ["hand_l_grip", "hand_r_grip", "foot_l", "foot_r"]:
		var sprite := rig.part_sprites[part_name] as Sprite2D
		if not sprite.visible:
			continue
		var side := "left" if part_name.contains("_l") else "right"
		var transform := sprite.get_global_transform_with_canvas()
		var best_gap := INF
		var best_point := Vector2.ZERO
		var best_edges := Vector2i.ZERO
		for local_point: Vector2 in local_alpha_points[part_name]:
			var screen_point := transform * local_point
			var row := clampi(int(round(screen_point.y)), 0, image.get_height() - 1)
			if not branch_edges.has(row):
				continue
			var edges: Vector2i = branch_edges[row]
			var edge_x := edges.x if side == "left" else edges.y
			var gap := absf(screen_point.x - float(edge_x))
			if gap < best_gap:
				best_gap = gap
				best_point = screen_point
				best_edges = edges
		result.append({
			"part": part_name,
			"point": [snappedf(best_point.x, 0.1), snappedf(best_point.y, 0.1)],
			"branch_left": best_edges.x,
			"branch_right": best_edges.y,
			"nearest_edge_gap_px": snappedf(best_gap, 0.1),
		})
	return result

func _branch_edges_by_row(image: Image, center_x: int) -> Dictionary:
	var result := {}
	for y in image.get_height():
		var left := image.get_width()
		var right := -1
		for x in range(maxi(0, center_x - 48), mini(image.get_width(), center_x + 49)):
			var pixel := image.get_pixel(x, y)
			if pixel.g > 0.27 and pixel.g > pixel.r * 1.15 and pixel.g > pixel.b * 0.80:
				left = mini(left, x)
				right = maxi(right, x)
		if right >= left:
			result[y] = Vector2i(left, right)
	return result
