extends SceneTree

const TEST_PATH := "user://qa/test_save_bridge_queue.json"
var passed := 0
var failed := 0

class FakePlatformService:
	extends Node

	var stored: Dictionary = {}
	var pending_value: Dictionary = {}
	var pending_callback := Callable()
	var get_callback := Callable()
	var set_in_flight := false

	func storage_get(callback: Callable) -> void:
		get_callback = callback

	func complete_get(success: bool, value: Variant) -> void:
		var callback := get_callback
		get_callback = Callable()
		callback.call(success, value)

	func storage_set(value: Dictionary, callback := Callable()) -> void:
		if set_in_flight:
			return
		set_in_flight = true
		pending_value = value.duplicate(true)
		pending_callback = callback

	func complete_set(success := true) -> void:
		if success:
			stored = pending_value.duplicate(true)
		var callback := pending_callback
		pending_callback = Callable()
		pending_value = {}
		set_in_flight = false
		callback.call(success)

func _init() -> void:
	_cleanup()
	_write_starting_profile()
	var platform := FakePlatformService.new()
	var save := SaveManager.new(TEST_PATH)
	save.configure_platform(platform)
	var economy := EconomyManager.new()
	_check(economy.initialize(save), "config loads")
	platform.complete_get(false, null)

	_check(economy.buy("outfit_moss"), "buy starts bridge write")
	_check(economy.equip("outfit_moss"), "equip is queued while write is in flight")
	_check(economy.select_character("M2"), "character selection joins queued latest state")
	platform.complete_set()
	_check(platform.set_in_flight, "dirty queue starts one follow-up write")
	platform.complete_set()

	var final_meta: Dictionary = platform.stored.get("meta", {})
	var final_shop: Dictionary = platform.stored.get("shop", {})
	var final_equipped: Dictionary = final_shop.get("equipped", {})
	_check(int(final_meta.get("gold", -1)) == 0, "latest gold reaches bridge")
	_check(final_shop.get("owned", []).has("outfit_moss"), "latest ownership reaches bridge")
	_check(str(final_equipped.get("OUTFIT", "")) == "outfit_moss", "latest equipment reaches bridge")
	_check(str(final_shop.get("selected_character", "")) == "M2", "latest character reaches bridge")

	var stale := platform.stored.duplicate(true)
	stale.meta.save_seq = maxi(int(stale.meta.save_seq) - 1, 0)
	stale.meta.gold = 999
	stale.shop.owned = ["M1", "F1"]
	stale.shop.equipped.OUTFIT = ""
	stale.shop.selected_character = "M1"
	save._on_bridge_profile_loaded(true, stale)
	_check(platform.set_in_flight, "older bridge profile queues local repair")
	platform.complete_set()
	var reloaded := SaveManager.new(TEST_PATH).load_profile()
	_check(int(reloaded.meta.gold) == 0 and reloaded.shop.owned.has("outfit_moss") and reloaded.shop.equipped.OUTFIT == "outfit_moss" and reloaded.shop.selected_character == "M2", "older bridge profile does not overwrite local state")

	print("test_save_bridge_queue.gd: %d PASS / %d FAIL" % [passed, failed])
	save.platform_service = null
	platform.free()
	_cleanup()
	quit(0 if failed == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)

func _write_starting_profile() -> void:
	var directory := TEST_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 4,
		"meta": {"gold": 150, "xp": 0, "level": 3, "hair_refund_done": true, "emblem_refund_done": true, "save_seq": 4},
		"progression": {"completed_stages": [], "skipped_stages": [], "treasures_claimed": []},
		"daily": {"day_index": 0, "last_claim_date": ""},
		"purchases": {"remove_ads": false},
		"shop": {
			"owned": ["M1", "F1", "M2"],
			"equipped": {"OUTFIT": "", "PET": "", "TRAIL": ""},
			"selected_character": "M1",
		},
		"replay": {
			"nightmare_unlocked": false,
			"challenges": {},
			"records": {
				"NORMAL": {"best_time": 0.0, "completions": 0},
				"NIGHTMARE": {"best_time": 0.0, "completions": 0},
			},
		},
		"meta_systems": {
			"tutorial_completed": false,
			"settings": {"sound": true, "music": true, "ghost": true},
			"ghosts": {"NORMAL": {}, "NIGHTMARE": {}},
		},
	}, "\t"))
	file.close()

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
