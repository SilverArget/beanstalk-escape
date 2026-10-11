extends SceneTree

var failures := 0

func _initialize() -> void:
	var scene := load("res://scenes/character_rig.tscn") as PackedScene
	var rig := scene.instantiate() as CharacterRig
	get_root().add_child(rig)
	await process_frame
	_check(rig.part_sprites.size() == 22, "G3A-RIG-01 22 named rigid parts")
	_check(rig.part_sprites.keys().all(func(name): return name in CharacterRig.PART_NAMES), "G3A-RIG-02 part names match contract")
	var m1_contract := rig.rig_contract()
	var m1_paths := _animation_signature(rig.animation_player)
	_check(rig.set_skin("F1"), "G3A-RIG-03 F1 mounts without pose changes")
	var f1_contract := rig.rig_contract()
	var f1_paths := _animation_signature(rig.animation_player)
	_check(m1_contract.cell_size == f1_contract.cell_size and m1_contract.local_pivot == f1_contract.local_pivot, "G3A-RIG-04 canvas and local pivots are identical")
	_check(m1_paths == f1_paths and m1_paths.size() == 7, "G3A-RIG-05 one seven-animation pilot set serves both skins")
	_check(m1_contract.visible_size == Vector2(44, 108) and m1_contract.collider_size == Vector2(30, 86), "G3A-RIG-06 scale lock and common collider unchanged")
	_check(m1_contract.wing_anchor == f1_contract.wing_anchor, "G3A-RIG-07 wing anchor is shared")
	var alpha_ok := true
	for path in CharacterRig.SKIN_TEXTURES.values():
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		alpha_ok = alpha_ok and image != null and image.get_format() in [Image.FORMAT_RGBA8, Image.FORMAT_RGBAF, Image.FORMAT_RGBAH]
		if image != null:
			alpha_ok = alpha_ok and image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0.0
	_check(alpha_ok, "G3A-RIG-08 true RGBA with transparent outer corners")
	rig.queue_free()
	await process_frame
	print("RESULT test_gate3a_rig PASS=%d FAIL=%d" % [8 - failures, failures])
	quit(failures)

func _animation_signature(player: AnimationPlayer) -> Dictionary:
	var result := {}
	for animation_name in ["idle", "climb_loop", "branch_takeoff", "branch_midair", "branch_landing", "hurt", "skill_time"]:
		if not player.has_animation(animation_name):
			continue
		var animation := player.get_animation(animation_name)
		var tracks := []
		for track_index in animation.get_track_count():
			tracks.append([str(animation.track_get_path(track_index)), animation.track_get_key_count(track_index)])
		result[animation_name] = tracks
	return result

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS " + label)
	else:
		failures += 1
		print("FAIL " + label)
