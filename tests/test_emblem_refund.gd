extends SceneTree

const TEST_PATH := "user://qa/test_emblem_refund_profile.json"
const REFUNDS := {
	"emblem_leaf": 150, "emblem_star": 150,
	"emblem_sun": 400, "emblem_bolt": 400,
	"emblem_spider": 900, "emblem_crown": 900,
}
var passed := 0
var failed := 0

class FakePlatformService:
	extends Node
	var stored: Dictionary = {}
	var writes := 0
	func storage_set(value: Dictionary, callback: Callable) -> void:
		stored = value.duplicate(true)
		writes += 1
		callback.call(true)

func _init() -> void:
	_cleanup()
	for item_id in REFUNDS:
		_write(_legacy([item_id, item_id]))
		var first := SaveManager.new(TEST_PATH).load_profile()
		_check(int(first.meta.gold) == 100 + int(REFUNDS[item_id]), "%s refunds %d once despite duplicate ownership" % [item_id, REFUNDS[item_id]])
		_check(not first.shop.owned.has(item_id) and not first.shop.equipped.has("EMBLEM"), "%s ownership and equipment removed" % item_id)
		_check(bool(first.meta.get("emblem_refund_done", false)), "refund flag set")
		_check(int(SaveManager.new(TEST_PATH).load_profile().meta.gold) == int(first.meta.gold), "reload keeps persisted refund without duplication")

	var all_owned: Array = REFUNDS.keys()
	all_owned.append_array(["M2", "outfit_moss", "fairy_leaf", "trail_leaf", "hair_blonde"])
	var legacy := _legacy(all_owned)
	legacy.meta.hair_refund_done = false
	_write(legacy)
	var save := SaveManager.new(TEST_PATH)
	var profile := save.load_profile()
	_check(int(profile.meta.gold) == 3400, "six emblems refund 2900 plus independent 400 hair refund")
	_check(profile.shop.owned == ["M1", "F1", "M2", "outfit_moss", "fairy_leaf", "trail_leaf"], "unrelated ownership preserved")
	_check(profile.shop.equipped == {"OUTFIT": "outfit_moss", "PET": "fairy_leaf", "TRAIL": "trail_leaf"}, "outfit, pet and trail equipment preserved")
	_check(profile.shop.selected_character == "M2" and int(profile.meta.xp) == 23 and int(profile.meta.level) == 3, "character and progression unchanged")
	_check(save.write_meta({"gold": 3400, "xp": 23, "level": 3}), "meta write succeeds")
	_check(bool(SaveManager.new(TEST_PATH).load_profile().meta.emblem_refund_done), "meta write preserves refund flag")
	_check(save.write_meta_and_shop({"gold": 3400, "xp": 23, "level": 3}, profile.shop), "combined meta and shop write succeeds")
	_check(int(SaveManager.new(TEST_PATH).load_profile().meta.gold) == 3400, "combined write and reload do not repeat refund")

	legacy = _legacy(REFUNDS.keys())
	legacy.meta.emblem_refund_done = true
	_write(legacy)
	profile = SaveManager.new(TEST_PATH).load_profile()
	_check(int(profile.meta.gold) == 100 and profile.shop.owned == ["M1", "F1"], "completed flag prevents refund but still strips retired items")
	_write(_legacy([]))
	profile = SaveManager.new(TEST_PATH).load_profile()
	_check(int(profile.meta.gold) == 100 and not profile.shop.equipped.has("EMBLEM"), "equipped but unowned emblem earns no refund")
	legacy = _legacy([])
	legacy.shop = {"owned": "invalid", "equipped": {"EMBLEM": "emblem_sun"}}
	_write(legacy)
	_check(int(SaveManager.new(TEST_PATH).load_profile().meta.gold) == 100, "malformed ownership earns no refund")
	_cleanup()
	profile = SaveManager.new(TEST_PATH).load_profile()
	_check(int(profile.meta.gold) == 0 and bool(profile.meta.emblem_refund_done), "fresh profile has completed flag and no refund")

	var platform := FakePlatformService.new()
	save = SaveManager.new(TEST_PATH)
	save.load_profile()
	save.platform_service = platform
	save._on_bridge_profile_loaded(true, _legacy(REFUNDS.keys()))
	_check(platform.writes == 1 and int(platform.stored.meta.gold) == 3000, "legacy bridge profile refunds all six and persists to bridge")
	_check(bool(platform.stored.meta.emblem_refund_done) and not platform.stored.shop.equipped.has("EMBLEM"), "bridge persists flag and removes equipment")
	save._on_bridge_profile_loaded(true, platform.stored.duplicate(true))
	_check(platform.writes == 1 and int(save.profile.meta.gold) == 3000, "migrated bridge reload does not refund again")
	save._on_bridge_profile_loaded(true, _legacy(REFUNDS.keys()))
	_check(int(save.profile.meta.gold) == 3000 and int(platform.stored.meta.gold) == 3000, "stale legacy bridge cannot duplicate refund")
	_check(int(SaveManager.new(TEST_PATH).load_profile().meta.gold) == 3000, "bridge refund survives local reload")
	save.platform_service = null
	platform.free()
	_cleanup()
	print("test_emblem_refund.gd: %d PASS / %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _legacy(owned: Array) -> Dictionary:
	return {
		"version": 4,
		"progression": {"completed_stages": [], "skipped_stages": [], "treasures_claimed": []},
		"purchases": {"remove_ads": false},
		"meta": {"gold": 100, "xp": 23, "level": 3, "hair_refund_done": true},
		"shop": {
			"owned": ["M1", "F1"] + owned,
			"equipped": {"EMBLEM": "emblem_sun", "OUTFIT": "outfit_moss", "PET": "fairy_leaf", "TRAIL": "trail_leaf"},
			"selected_character": "M2",
		},
	}

func _write(value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_PATH.get_base_dir())
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
