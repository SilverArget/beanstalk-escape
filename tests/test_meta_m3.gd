extends SceneTree

const TEST_PATH := "user://qa/test_meta_m3_profile.json"
var passed := 0
var failed := 0

func _init() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var save := SaveManager.new(TEST_PATH)
	var economy := EconomyManager.new()
	_check(economy.initialize(save), "config loads")
	var all_characters_available := true
	var all_anchors_valid := true
	var all_masks_present := true
	var all_hair_masks_valid := true
	var frame_names := ["climb_left", "climb_right", "climb_reach", "jump", "hurt", "fall", "cheer", "hang", "front"]
	for skin_id in ["M1", "M2", "M3", "F1", "F2", "F3"]:
		all_characters_available = all_characters_available and economy.character_available(skin_id)
		var root := "res://assets/art/character_frames/%s" % skin_id.to_lower()
		var anchor_file := FileAccess.open("%s/anchors.json" % root, FileAccess.READ)
		if anchor_file == null:
			all_anchors_valid = false
		else:
			var parsed: Variant = JSON.parse_string(anchor_file.get_as_text())
			var anchors: Dictionary = parsed.get("frames", {}) if parsed is Dictionary else {}
			for frame_name in frame_names:
				var anchor: Dictionary = anchors.get(frame_name, {})
				all_anchors_valid = all_anchors_valid and anchor.has("head_center") and anchor.has("head_width") and anchor.has("face_view")
				all_masks_present = all_masks_present and ResourceLoader.exists("%s/%s_outfit_mask.png" % [root, frame_name])
				all_hair_masks_valid = all_hair_masks_valid and _hair_mask_is_isolated(root, frame_name)
	_check(all_characters_available, "six packaged character skins available")
	_check(all_anchors_valid, "54 frame head anchors valid")
	_check(all_masks_present, "54 frame outfit masks available")
	_check(all_hair_masks_valid, "54 hair masks exclude outfit pixels")
	var hair_catalog := economy.cosmetic_catalog("HAIR")
	var has_hat := not economy.cosmetic_catalog("HAT").is_empty()
	_check(hair_catalog.size() == 3 and not has_hat and str(hair_catalog[2].get("source", "")) == "MAP TREASURE", "HAT removed and three HAIR items configured")
	economy.gold = 1000
	economy.level = 1
	_check(not economy.buy("face_goggles") and economy.locked_reason("face_goggles") == "LV 3", "level lock")
	economy.gold = 100
	_check(not economy.buy("hair_dark") and economy.locked_reason("hair_dark") == "NEED 50 GOLD", "gold shortfall")
	economy.gold = 150
	_check(economy.buy("hair_dark") and economy.gold == 0 and economy.shop.owned.has("hair_dark"), "purchase")
	var equipped_ok: bool = economy.equip("hair_dark") and economy.shop.equipped.HAIR == "hair_dark"
	var unequipped_ok: bool = economy.equip("hair_dark") and economy.shop.equipped.HAIR == ""
	_check(equipped_ok and unequipped_ok, "equip and unequip")
	economy.equip("hair_dark")
	var loaded_save := SaveManager.new(TEST_PATH)
	var loaded := EconomyManager.new()
	var load_ok := loaded.initialize(loaded_save)
	_check(load_ok and loaded.shop.owned.has("hair_dark") and loaded.shop.equipped.HAIR == "hair_dark" and loaded.gold == 0, "save and load")
	_write_legacy_hat_profile()
	var legacy_save := SaveManager.new(TEST_PATH)
	var legacy_profile := legacy_save.load_profile()
	var legacy_shop: Dictionary = legacy_profile.get("shop", {})
	var legacy_equipped: Dictionary = legacy_shop.get("equipped", {})
	_check(legacy_shop.get("owned", []).has("hat_leaf") and not legacy_equipped.has("HAT") and legacy_equipped.has("HAIR"), "legacy HAT save loads and is ignored")
	print("test_meta_m3.gd: %d PASS / %d FAIL" % [passed, failed])
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	quit(0 if failed == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _hair_mask_is_isolated(root: String, frame_name: String) -> bool:
	var source_path := "%s/%s.png" % [root, frame_name]
	var hair_path := "%s/%s_hair_mask.png" % [root, frame_name]
	var outfit_path := "%s/%s_outfit_mask.png" % [root, frame_name]
	if not ResourceLoader.exists(hair_path):
		return false
	var source_texture := load(source_path) as Texture2D
	var hair_texture := load(hair_path) as Texture2D
	var outfit_texture := load(outfit_path) as Texture2D
	if source_texture == null or hair_texture == null or outfit_texture == null:
		return false
	var source := source_texture.get_image()
	var hair := hair_texture.get_image()
	var outfit := outfit_texture.get_image()
	var selected := 0
	for y in hair.get_height():
		for x in hair.get_width():
			if hair.get_pixel(x, y).a <= 0.05:
				continue
			selected += 1
			var pixel := source.get_pixel(x, y)
			if outfit.get_pixel(x, y).a > 0.05:
				return false
	return selected > 100

func _skin_like(color: Color) -> bool:
	var red := color.r * 255.0
	var green := color.g * 255.0
	var blue := color.b * 255.0
	var cb := 128.0 - 0.168736 * red - 0.331264 * green + 0.5 * blue
	var cr := 128.0 + 0.5 * red - 0.418688 * green - 0.081312 * blue
	return cb >= 72.0 and cb <= 132.0 and cr >= 132.0 and cr <= 184.0 and red > green * 0.92

func _write_legacy_hat_profile() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 1,
		"meta": {"gold": 0, "xp": 0, "level": 1},
		"progression": {"skipped_stages": []},
		"purchases": {"remove_ads": false},
		"shop": {
			"owned": ["M1", "F1", "hat_leaf"],
			"equipped": {"HAT": "hat_leaf", "FACE": "", "TRAIL": "", "OUTFIT": ""},
			"selected_character": "M1",
		},
	}, "\t"))
