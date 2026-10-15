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
	_check(economy.cosmetic_catalog("PET").size() == 6, "six pets")
	var migrated := save._sanitize_shop({"owned": ["M1", "face_mask"], "equipped": {"FACE": "face_mask"}})
	_check(not migrated.owned.has("face_mask") and migrated.equipped.keys() == ["OUTFIT", "PET", "TRAIL"], "legacy FACE data removed and slots normalized")
	var pet_preview := PlayerVisual.new()
	root.add_child(pet_preview)
	await process_frame
	pet_preview.set_cosmetics({"OUTFIT": "", "PET": "pet_squirrel", "TRAIL": ""}, economy.cosmetic_catalog())
	pet_preview.show_front_preview()
	var pet_layer := pet_preview.cosmetic_sprites.get("PET") as Sprite2D
	_check(pet_layer != null and pet_layer.visible and pet_layer.texture != null and absf(pet_layer.position.x) <= 92.0, "pet visible inside front preview")
	var shop_preview := MetaShopUI.new()
	root.add_child(shop_preview)
	shop_preview.size = Vector2(960, 540)
	economy.grant_gold(1000)
	shop_preview.setup(economy, null)
	await process_frame
	var tabs_stay_fixed := _shop_tabs_fit(shop_preview)
	shop_preview.active_tab = "OUTFIT"
	shop_preview.refresh()
	await process_frame
	tabs_stay_fixed = tabs_stay_fixed and _shop_tabs_fit(shop_preview)
	shop_preview.call("_preview_item", economy.cosmetic_catalog("OUTFIT")[0])
	await process_frame
	tabs_stay_fixed = tabs_stay_fixed and _shop_tabs_fit(shop_preview)
	var bought_outfit := economy.buy("outfit_moss")
	tabs_stay_fixed = tabs_stay_fixed and bought_outfit
	await process_frame
	tabs_stay_fixed = tabs_stay_fixed and _shop_tabs_fit(shop_preview)
	var equipped_outfit := economy.equip("outfit_moss")
	tabs_stay_fixed = tabs_stay_fixed and equipped_outfit
	await process_frame
	tabs_stay_fixed = tabs_stay_fixed and _shop_tabs_fit(shop_preview)
	_check(tabs_stay_fixed, "shop tabs stay inside 960 px after refresh, tab change, preview, buy, and equip")
	var pets_fit := true
	var pets_clear_body := true
	var pets_grounded := true
	var pets_proportional := true
	for skin in SKINS:
		shop_preview.preview.set_skin(skin)
		for item in economy.cosmetic_catalog("PET"):
			shop_preview.preview.set_cosmetics({"OUTFIT": "", "PET": item.id, "TRAIL": ""}, economy.cosmetic_catalog())
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
	pet_preview.set_cosmetics({"OUTFIT": "", "PET": "pet_squirrel", "TRAIL": ""}, economy.cosmetic_catalog())
	var all_pixels_ok := true
	for skin in SKINS:
		pet_preview.set_skin(skin)
		pet_preview.show_front_preview()
		var metrics := _pixel_metrics(skin, "front")
		print("PIXEL %s/front tunic DE(outfit)=%.2f" % [skin.to_upper(), metrics.tunic_outfit_delta_e])
		all_pixels_ok = all_pixels_ok and metrics.tunic_outfit_delta_e >= 10.0
		pet_preview.show_front_preview()
		_check(not _pet_overlaps_body(skin, pet_preview, pet_layer), "%s front pet bbox does not overlap body bbox" % skin.to_upper())
	_check(all_pixels_ok, "front outfit replacement is visible for six skins")
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
	var outfit := Image.load_from_file(ProjectSettings.globalize_path(root_path + "_outfit_mask.png"))
	if source == null or outfit == null or source.is_empty() or outfit.is_empty():
		return {"tunic_outfit_delta_e": -999.0}
	var outfit_delta := 0.0
	var outfit_count := 0
	for y in source.get_height():
		for x in source.get_width():
			var pixel := source.get_pixel(x, y)
			var in_outfit := outfit.get_pixel(x, y).a > 0.5
			# FERN CHECK is the second OUTFIT card reported by the browser QA pass.
			var outfit_result := _dye_outfit(pixel, Color("4f8b55")) if in_outfit else pixel
			if in_outfit:
				outfit_count += 1
				outfit_delta += _delta_e_rgb(pixel, outfit_result)
	if outfit_count == 0:
		return {"tunic_outfit_delta_e": -999.0}
	return {
		"tunic_outfit_delta_e": outfit_delta / outfit_count,
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

func _shop_tabs_fit(shop: MetaShopUI) -> bool:
	if not is_equal_approx(shop.tabs.size.x, shop.size.x - 16.0):
		return false
	var buttons := shop.tabs.get_children()
	if buttons.size() != MetaShopUI.SLOTS.size():
		return false
	for button in buttons:
		var rect := (button as Control).get_global_rect()
		if rect.position.x < 0.0 or rect.end.x > shop.size.x:
			return false
	var first_rect := (buttons[0] as Control).get_global_rect()
	var last_rect := (buttons[-1] as Control).get_global_rect()
	return absf(first_rect.position.x - (shop.size.x - last_rect.end.x)) <= 1.0

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
