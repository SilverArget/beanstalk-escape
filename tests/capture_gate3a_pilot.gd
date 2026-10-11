extends SceneTree

const OUTPUT_ROOT := "res://../03-test/qa/art-reference/pilot"
const RIG_ONLY_ROOT := OUTPUT_ROOT + "/rig-only"
const PILOT_ANIMATIONS := ["idle", "climb_loop", "branch_takeoff", "branch_midair", "branch_landing", "hurt", "skill_time"]

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
	await _capture_game_frame(game, rig, skin, "stage-1", 1, false)
	await _capture_game_frame(game, rig, skin, "stage-3", 3, false)
	await _capture_game_frame(game, rig, skin, "storm-flat-313c68", 3, true)
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
			await _capture_rig_only(skin, animation_name, local_frame, sample_time)
			frame_number += 1
	print("PASS G3A-CAPTURE skin=%s frames=%d" % [skin, frame_number])
	quit(0)

func _capture_game_frame(game: GameManager, rig: CharacterRig, skin: String, label: String, stage_number: int, storm: bool) -> void:
	game.player.global_position = Vector2(0, -Balance.STAGE_HEIGHT * (float(stage_number) - 0.35))
	game.spider.global_position = game.player.global_position + Vector2(0, Balance.START_DISTANCE)
	game.player._sync_stage_mode()
	game.stages.update_progress(game.player.global_position.y)
	game.get_node("World").qa_storm_background = storm
	rig.seek_animation("climb_loop", 0.20)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	image.save_png(OUTPUT_ROOT.path_join("%s-%s-960x540.png" % [skin.to_lower(), label]))

func _capture_skill_frame(rig: CharacterRig, skin: String) -> void:
	rig.seek_animation("skill_time", 0.45)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := get_root().get_texture().get_image()
	image.save_png(OUTPUT_ROOT.path_join("%s-skill-time-960x540.png" % skin.to_lower()))

func _capture_rig_only(skin: String, animation_name: String, local_frame: int, sample_time: float) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 540)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var isolated_rig := (load("res://scenes/character_rig.tscn") as PackedScene).instantiate() as CharacterRig
	isolated_rig.position = Vector2(480, 270)
	viewport.add_child(isolated_rig)
	get_root().add_child(viewport)
	await process_frame
	isolated_rig.set_skin(skin)
	isolated_rig.seek_animation(animation_name, sample_time)
	await process_frame
	if animation_name == "skill_time" and local_frame in [0, 17]:
		print("G3A-WING skin=%s frame=%d visible=%s scale=%s texture=%s" % [skin, local_frame, isolated_rig.time_wings.visible, isolated_rig.time_wings.scale, isolated_rig.time_wings.texture != null])
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(RIG_ONLY_ROOT.path_join("%s-%s-%02d.png" % [skin.to_lower(), animation_name, local_frame]))
	viewport.queue_free()
	await process_frame
