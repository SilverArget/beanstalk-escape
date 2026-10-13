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
	_check(all_characters_available, "six packaged character skins available")
	_check(all_anchors_valid, "54 frame head anchors valid")
	_check(all_masks_present, "54 frame outfit masks available")
	var stage_ten_reward := economy.map_treasure(10)
	var has_hat := not economy.cosmetic_catalog("HAT").is_empty()
	_check(economy.cosmetic_catalog("HAIR").is_empty() and not has_hat, "HAT and HAIR catalogs removed")
	_check(str(stage_ten_reward.get("type", "")) == "gold" and int(stage_ten_reward.get("amount", 0)) == 900, "stage 10 retired SILVER reward replaced with 900 gold")
	economy.gold = 1000
	economy.level = 1
	_check(not economy.buy("emblem_sun") and economy.locked_reason("emblem_sun") == "LV 3", "level lock")
	economy.gold = 100
	_check(not economy.buy("emblem_leaf") and economy.locked_reason("emblem_leaf") == "NEED 50 GOLD", "gold shortfall")
	economy.gold = 150
	_check(economy.buy("emblem_leaf") and economy.gold == 0 and economy.shop.owned.has("emblem_leaf"), "purchase")
	var equipped_ok: bool = economy.equip("emblem_leaf") and economy.shop.equipped.EMBLEM == "emblem_leaf"
	var unequipped_ok: bool = economy.equip("emblem_leaf") and economy.shop.equipped.EMBLEM == ""
	_check(equipped_ok and unequipped_ok, "equip and unequip")
	economy.equip("emblem_leaf")
	var loaded_save := SaveManager.new(TEST_PATH)
	var loaded := EconomyManager.new()
	var load_ok := loaded.initialize(loaded_save)
	_check(load_ok and loaded.shop.owned.has("emblem_leaf") and loaded.shop.equipped.EMBLEM == "emblem_leaf" and loaded.gold == 0, "save and load")
	var shop := MetaShopUI.new()
	root.add_child(shop)
	await process_frame
	shop.size = Vector2(960, 540)
	shop.setup(economy, null)
	var preview_was_back := shop.preview_back
	var exit_button_kept_back := false
	for child in shop.footer.get_children():
		if child is Button and child != shop.view_toggle_button and child.text == "BACK":
			exit_button_kept_back = true
	shop.view_toggle_button.pressed.emit()
	var has_drawn_turn_icon := shop.view_toggle_button.get_node_or_null("TurnIcon") != null
	_check(shop.view_toggle_button.text == "TURN" and shop.preview_back != preview_was_back and exit_button_kept_back and has_drawn_turn_icon, "preview TURN icon toggles view while exit stays BACK")
	shop.queue_free()
	_write_legacy_hat_profile()
	var legacy_save := SaveManager.new(TEST_PATH)
	var legacy_profile := legacy_save.load_profile()
	var legacy_shop: Dictionary = legacy_profile.get("shop", {})
	var legacy_equipped: Dictionary = legacy_shop.get("equipped", {})
	_check(legacy_shop.get("owned", []).has("hat_leaf") and not legacy_equipped.has("HAT") and not legacy_equipped.has("HAIR"), "legacy HAT save loads and retired slots are ignored")
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
