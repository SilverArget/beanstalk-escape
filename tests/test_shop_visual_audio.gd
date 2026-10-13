extends SceneTree

const TEST_PATH := "user://qa/test_shop_visual_audio.json"
const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
const HAIR_STRAND_POINTS := {
	"m1": Vector2i(243, 59),
	"m2": Vector2i(267, 100),
	"m3": Vector2i(260, 77),
	"f1": Vector2i(292, 82),
}
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
	var shop_preview := MetaShopUI.new()
	root.add_child(shop_preview)
	shop_preview.size = Vector2(960, 540)
	shop_preview.setup(economy, null)
	var pets_fit := true
	var pets_clear_body := true
	var pets_grounded := true
	var pets_proportional := true
	for skin in SKINS:
		shop_preview.preview.set_skin(skin)
		for item in economy.cosmetic_catalog("PET"):
			shop_preview.preview.set_cosmetics({"HAIR": "", "OUTFIT": "", "EMBLEM": "", "PET": item.id, "TRAIL": ""}, economy.cosmetic_catalog())
			shop_preview.preview.show_front_preview()
			var rects := _preview_rects(shop_preview, skin, item)
			var body_rect: Rect2 = rects.body
			var pet_rect: Rect2 = rects.pet
			var host_rect := Rect2(Vector2.ZERO, shop_preview.preview_host.size)
			var gap := pet_rect.position.x - body_rect.end.x
			var height_ratio := pet_rect.size.y / body_rect.size.y
			pets_fit = pets_fit and host_rect.encloses(body_rect) and host_rect.encloses(pet_rect)
			pets_clear_body = pets_clear_body and gap >= 2.0 and gap <= 10.0 and not body_rect.intersects(pet_rect)
			pets_grounded = pets_grounded and absf(pet_rect.end.y - body_rect.end.y) <= 3.0
			pets_proportional = pets_proportional and height_ratio >= 0.22 and height_ratio <= 0.28
	_check(pets_fit, "all six pets and all characters fit the 960x540 preview host")
	_check(pets_clear_body, "all six pets sit 2-10 px to the right without overlap")
	_check(pets_grounded, "all six pets share the character foot line")
	_check(pets_proportional, "all six pets are 22-28 percent of character height")
	shop_preview.free()
	var all_pixels_ok := true
	for skin in SKINS:
		pet_preview.set_skin(skin)
		pet_preview.show_front_preview()
		var metrics := _pixel_metrics(skin, "front")
		print("PIXEL %s/front hair=%d/%d face DE(hair)=%.2f hair DL=%.2f tunic DE(outfit)=%.2f" % [skin.to_upper(), metrics.hair_mask_pixels, metrics.head_opaque_pixels, metrics.face_hair_delta_e, metrics.hair_delta_l, metrics.tunic_outfit_delta_e])
		all_pixels_ok = all_pixels_ok and metrics.face_hair_delta_e < 3.0 and metrics.hair_delta_l >= 15.0 and metrics.tunic_outfit_delta_e >= 10.0
		_check(metrics.hair_mask_pixels >= metrics.head_opaque_pixels * 0.35, "%s front hair mask covers at least 35%% of opaque head pixels" % skin.to_upper())
		_check(_hair_regressions_pass(skin), "%s front hair mask covers strands and excludes the collar" % skin.to_upper())
		_check(_anchor_inside_outfit(skin, "front", "emblem_center"), "%s front emblem center is inside outfit mask" % skin.to_upper())
		_check(_anchor_inside_outfit(skin, "hang", "emblem_center"), "%s hang emblem center is inside outfit mask" % skin.to_upper())
		_check(not _pet_overlaps_body(skin, pet_preview, pet_layer), "%s front pet bbox does not overlap body bbox" % skin.to_upper())
	_check(all_pixels_ok, "front face/hair/outfit isolation for six skins")
	pet_preview.free()
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
	var outfit_rect := outfit.get_used_rect()
	var head_opaque_pixels := 0
	for y in source.get_height():
		for x in source.get_width():
			var pixel := source.get_pixel(x, y)
			var in_hair := hair.get_pixel(x, y).a > 0.5
			var in_outfit := outfit.get_pixel(x, y).a > 0.5
			if y < outfit_rect.position.y and pixel.a > 0.5:
				head_opaque_pixels += 1
			var hair_result := _dye_hair(pixel, Color("241b18")) if in_hair else pixel
			# FERN CHECK is the second OUTFIT card reported by the browser QA pass.
			var outfit_result := _dye_outfit(pixel, Color("4f8b55")) if in_outfit else pixel
			var nx := (float(x) - used.position.x) / maxf(used.size.x, 1.0)
			var ny := (float(y) - used.position.y) / maxf(used.size.y, 1.0)
			# The upper head box contains the fringe by design. Sample the lower
			# central face so correct bang coverage is not reported as dyed skin.
			var in_face_box := nx >= 0.38 and nx <= 0.62 and ny >= 0.22 and ny <= 0.31
			if in_face_box and pixel.a > 0.2 and _is_skin_tone(pixel):
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
		"hair_mask_pixels": hair_count,
		"head_opaque_pixels": head_opaque_pixels,
	}

func _anchor_inside_outfit(skin: String, frame: String, anchor_name: String) -> bool:
	var anchor_path := "res://assets/art/character_frames/%s/anchors.json" % skin
	var file := FileAccess.open(anchor_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var frame_data: Dictionary = (parsed as Dictionary).get("frames", {}).get(frame, {})
	var point: Array = frame_data.get(anchor_name, [])
	if point.size() != 2:
		return false
	var mask_path := "res://assets/art/character_frames/%s/%s_outfit_mask.png" % [skin, frame]
	var outfit := Image.load_from_file(ProjectSettings.globalize_path(mask_path))
	var x := clampi(roundi(float(point[0])), 0, outfit.get_width() - 1)
	var y := clampi(roundi(float(point[1])), 0, outfit.get_height() - 1)
	return outfit.get_pixel(x, y).a > 0.5

func _pet_overlaps_body(skin: String, visual: PlayerVisual, pet_layer: Sprite2D) -> bool:
	if pet_layer == null or pet_layer.texture == null:
		return true
	var body_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/character_frames/%s/front.png" % skin))
	var pet_path := "res://assets/art/pets/%s" % str(visual.cosmetic_data["pet_squirrel"].image)
	var pet_image := Image.load_from_file(ProjectSettings.globalize_path(pet_path))
	var body_used := _visible_rect(body_image, 0.5)
	var pet_used := _visible_rect(pet_image, 0.04)
	var body_top_left := visual.sprite.position + (Vector2(body_used.position) - Vector2(body_image.get_size()) * 0.5) * PlayerVisual.ART_SCALE
	var body_rect := Rect2(body_top_left, Vector2(body_used.size) * PlayerVisual.ART_SCALE)
	var pet_top_left := pet_layer.position + (Vector2(pet_used.position) - Vector2(pet_image.get_size()) * 0.5) * pet_layer.scale
	var pet_rect := Rect2(pet_top_left, Vector2(pet_used.size) * pet_layer.scale)
	return body_rect.intersects(pet_rect)

func _preview_rects(shop: MetaShopUI, skin: String, item: Dictionary) -> Dictionary:
	var visual := shop.preview
	var pet_layer := visual.cosmetic_sprites.get("PET") as Sprite2D
	var body_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/character_frames/%s/front.png" % skin))
	var pet_image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/pets/%s" % str(item.image)))
	var body_used := _visible_rect(body_image, 0.5)
	var pet_used := _visible_rect(pet_image, 0.04)
	var body_top_left := visual.sprite.position + (Vector2(body_used.position) - Vector2(body_image.get_size()) * 0.5) * PlayerVisual.ART_SCALE
	var pet_top_left := pet_layer.position + (Vector2(pet_used.position) - Vector2(pet_image.get_size()) * 0.5) * pet_layer.scale
	return {
		"body": Rect2(visual.position + body_top_left * visual.scale, Vector2(body_used.size) * PlayerVisual.ART_SCALE * visual.scale),
		"pet": Rect2(visual.position + pet_top_left * visual.scale, Vector2(pet_used.size) * pet_layer.scale * visual.scale),
	}

func _visible_rect(image: Image, minimum_alpha: float) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < minimum_alpha:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)

func _hair_regressions_pass(skin: String) -> bool:
	var root_path := "res://assets/art/character_frames/%s/front" % skin
	var hair := Image.load_from_file(ProjectSettings.globalize_path(root_path + "_hair_mask.png"))
	var outfit := Image.load_from_file(ProjectSettings.globalize_path(root_path + "_outfit_mask.png"))
	var outfit_rect := outfit.get_used_rect()
	if HAIR_STRAND_POINTS.has(skin):
		var strand: Vector2i = HAIR_STRAND_POINTS[skin]
		if hair.get_pixelv(strand).a <= 0.5:
			return false
	var cutoff := outfit_rect.position.y - 6
	var center_x := outfit_rect.get_center().x
	for y in range(cutoff, hair.get_height()):
		for x in hair.get_width():
			if hair.get_pixel(x, y).a <= 0.5:
				continue
			if skin != "f1" or absf(float(x - center_x)) <= 45.0:
				return false
	return true

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

func _is_skin_tone(pixel: Color) -> bool:
	var red := pixel.r * 255.0
	var green := pixel.g * 255.0
	var blue := pixel.b * 255.0
	var cb := 128.0 - 0.168736 * red - 0.331264 * green + 0.5 * blue
	var cr := 128.0 + 0.5 * red - 0.418688 * green - 0.081312 * blue
	return cb >= 72.0 and cb <= 132.0 and cr >= 132.0 and cr <= 184.0 and red > green * 0.92

func _delta_e_rgb(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 100.0

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
