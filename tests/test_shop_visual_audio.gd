extends SceneTree

const TEST_PATH := "user://qa/test_shop_visual_audio.json"
const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var save := SaveManager.new(TEST_PATH)
	var economy := EconomyManager.new()
	_check(economy.initialize(save), "economy loads")
	_check(economy.cosmetic_catalog("FACE").is_empty(), "FACE catalog removed")
	_check(economy.cosmetic_catalog("OUTFIT").size() == 9, "nine outfits")
	_check(economy.cosmetic_catalog("EMBLEM").size() == 6, "six emblems")
	_check(economy.cosmetic_catalog("PET").size() == 6, "six pets")
	var migrated := save._sanitize_shop({"owned": ["M1", "face_mask"], "equipped": {"FACE": "face_mask"}})
	_check(not migrated.owned.has("face_mask") and migrated.equipped.keys() == ["HAIR", "OUTFIT", "EMBLEM", "PET", "TRAIL"], "legacy FACE data removed and slots normalized")
	var pet_preview := PlayerVisual.new()
	root.add_child(pet_preview)
	await process_frame
	pet_preview.set_cosmetics({"HAIR": "", "OUTFIT": "", "EMBLEM": "", "PET": "pet_squirrel", "TRAIL": ""}, economy.cosmetic_catalog())
	pet_preview.show_front_preview()
	var pet_layer := pet_preview.cosmetic_sprites.get("PET") as Sprite2D
	_check(pet_layer != null and pet_layer.visible and pet_layer.texture != null and absf(pet_layer.position.x) <= 92.0, "pet visible inside front preview")
	pet_preview.queue_free()
	var all_pixels_ok := true
	for skin in SKINS:
		var metrics := _pixel_metrics(skin, "front")
		print("PIXEL %s/front face DE(hair)=%.2f hair DL=%.2f tunic DE(outfit)=%.2f" % [skin.to_upper(), metrics.face_hair_delta_e, metrics.hair_delta_l, metrics.tunic_outfit_delta_e])
		all_pixels_ok = all_pixels_ok and metrics.face_hair_delta_e < 3.0 and metrics.hair_delta_l >= 15.0 and metrics.tunic_outfit_delta_e >= 10.0
	_check(all_pixels_ok, "front face/hair/outfit isolation for six skins")
	var audio := BeanstalkAudio.new()
	root.add_child(audio)
	await process_frame
	audio.set_sound_enabled(false)
	var master := AudioServer.get_bus_index("Master")
	_check(AudioServer.is_bus_mute(master) or AudioServer.get_bus_volume_db(master) <= -60.0, "sound off mutes Master bus")
	audio.set_sound_enabled(true)
	_check(not AudioServer.is_bus_mute(master) and AudioServer.get_bus_volume_db(master) > -60.0, "sound on restores Master bus")
	audio.set_music_enabled(false)
	_check(audio.music.volume_db <= -60.0, "music off silences music")
	audio.set_music_enabled(true)
	_check(audio.music.volume_db > -60.0, "music on restores music")
	_check(save.write_settings({"sound": false, "music": false, "ghost": true}), "audio settings save immediately")
	var reloaded := SaveManager.new(TEST_PATH)
	var reloaded_settings: Dictionary = reloaded.meta_systems_snapshot().settings
	_check(not bool(reloaded_settings.sound) and not bool(reloaded_settings.music), "new SaveManager reads muted settings")
	var game := GameManager.new()
	game.audio = audio
	var can_apply_loaded_audio := game.has_method("_apply_loaded_profile")
	_check(can_apply_loaded_audio, "startup profile applies audio settings")
	if can_apply_loaded_audio:
		game.call("_apply_loaded_profile", reloaded.load_profile())
		_check(AudioServer.is_bus_mute(master) and audio.music.volume_db <= -60.0, "startup profile mutes Master and music")
	game.free()
	print("test_shop_visual_audio.gd: %d PASS / %d FAIL" % [passed, failed])
	audio.free()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	quit(0 if failed == 0 else 1)

func _pixel_metrics(skin: String, frame: String) -> Dictionary:
	var root_path := "res://assets/art/character_frames/%s/%s" % [skin, frame]
	var source := Image.load_from_file(ProjectSettings.globalize_path(root_path + ".png"))
	var hair := Image.load_from_file(ProjectSettings.globalize_path(root_path + "_hair_mask.png"))
	var outfit := Image.load_from_file(ProjectSettings.globalize_path(root_path + "_outfit_mask.png"))
	if source == null or hair == null or outfit == null or source.is_empty() or hair.is_empty() or outfit.is_empty():
		return {"hair_delta_l": -999.0, "tunic_hair_delta_e": 999.0, "tunic_outfit_delta_e": -999.0, "hair_outfit_delta_e": 999.0}
	var used := source.get_used_rect()
	var hair_l_before := 0.0
	var hair_l_after := 0.0
	var hair_count := 0
	var outfit_delta := 0.0
	var outfit_count := 0
	var tunic_hair_delta := 0.0
	var hair_outfit_delta := 0.0
	var face_hair_delta := 0.0
	var face_count := 0
	for y in source.get_height():
		for x in source.get_width():
			var pixel := source.get_pixel(x, y)
			var in_hair := hair.get_pixel(x, y).a > 0.5
			var in_outfit := outfit.get_pixel(x, y).a > 0.5
			var hair_result := _dye_hair(pixel, Color("241b18")) if in_hair else pixel
			# FERN CHECK is the second OUTFIT card reported by the browser QA pass.
			var outfit_result := _dye_outfit(pixel, Color("4f8b55")) if in_outfit else pixel
			var nx := (float(x) - used.position.x) / maxf(used.size.x, 1.0)
			var ny := (float(y) - used.position.y) / maxf(used.size.y, 1.0)
			var in_face_box := nx >= 0.36 and nx <= 0.64 and ny >= 0.16 and ny <= 0.32
			if in_face_box and pixel.a > 0.2:
				face_count += 1
				face_hair_delta += _delta_e_rgb(pixel, hair_result)
			if in_hair:
				hair_count += 1
				hair_l_before += _luma(pixel)
				hair_l_after += _luma(hair_result)
				hair_outfit_delta += _delta_e_rgb(pixel, outfit_result)
			if in_outfit:
				outfit_count += 1
				outfit_delta += _delta_e_rgb(pixel, outfit_result)
				tunic_hair_delta += _delta_e_rgb(pixel, hair_result)
	if hair_count == 0 or outfit_count == 0:
		return {"hair_delta_l": -999.0, "tunic_hair_delta_e": 999.0, "tunic_outfit_delta_e": -999.0, "hair_outfit_delta_e": 999.0}
	return {
		"face_hair_delta_e": face_hair_delta / max(face_count, 1),
		"hair_delta_l": (hair_l_before - hair_l_after) / hair_count,
		"tunic_hair_delta_e": tunic_hair_delta / outfit_count,
		"tunic_outfit_delta_e": outfit_delta / outfit_count,
		"hair_outfit_delta_e": hair_outfit_delta / hair_count,
	}

func _dye_hair(pixel: Color, tint: Color) -> Color:
	var value := lerpf(0.35, 1.10, smoothstep(0.05, 0.75, _luma(pixel) / 100.0))
	var dyed := Color(tint.r * value, tint.g * value, tint.b * value, pixel.a)
	if _luma(tint) < 18.0:
		dyed = Color(dyed.r * 0.18, dyed.g * 0.18, dyed.b * 0.18, dyed.a)
	return dyed

func _dye_outfit(pixel: Color, tint: Color) -> Color:
	var value := lerpf(0.42, 1.34, _luma(pixel) / 100.0)
	var dyed := Color(tint.r * value, tint.g * value, tint.b * value, pixel.a)
	return pixel.lerp(dyed, 0.90)

func _luma(pixel: Color) -> float:
	return (pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114) * 100.0

func _delta_e_rgb(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 100.0

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
