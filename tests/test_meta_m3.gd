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
	economy.gold = 1000
	economy.level = 1
	_check(not economy.buy("face_goggles") and economy.locked_reason("face_goggles") == "LV 3", "level lock")
	economy.gold = 100
	_check(not economy.buy("hat_leaf") and economy.locked_reason("hat_leaf") == "NEED 50 GOLD", "gold shortfall")
	economy.gold = 150
	_check(economy.buy("hat_leaf") and economy.gold == 0 and economy.shop.owned.has("hat_leaf"), "purchase")
	var equipped_ok: bool = economy.equip("hat_leaf") and economy.shop.equipped.HAT == "hat_leaf"
	var unequipped_ok: bool = economy.equip("hat_leaf") and economy.shop.equipped.HAT == ""
	_check(equipped_ok and unequipped_ok, "equip and unequip")
	economy.equip("hat_leaf")
	var loaded_save := SaveManager.new(TEST_PATH)
	var loaded := EconomyManager.new()
	var load_ok := loaded.initialize(loaded_save)
	_check(load_ok and loaded.shop.owned.has("hat_leaf") and loaded.shop.equipped.HAT == "hat_leaf" and loaded.gold == 0, "save and load")
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
