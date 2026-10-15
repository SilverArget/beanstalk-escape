extends SceneTree

const TEST_PATH := "user://qa/test_hair_refund_profile.json"

var passed := 0
var failed := 0


func _init() -> void:
	_cleanup()
	_write_legacy_hair_profile()

	var first_profile := SaveManager.new(TEST_PATH).load_profile()
	_check(int(first_profile.meta.gold) == 500, "owned BLONDE refunds 400 gold")
	_check(not first_profile.shop.owned.has("hair_blonde"), "retired hair removed from owned items")
	_check(not first_profile.shop.equipped.has("HAIR"), "retired HAIR equipment slot removed")
	_check(bool(first_profile.meta.get("hair_refund_done", false)), "hair refund migration flag stored")

	var second_profile := SaveManager.new(TEST_PATH).load_profile()
	_check(int(second_profile.meta.gold) == 500, "second load does not refund again")
	_check(bool(second_profile.meta.get("hair_refund_done", false)), "refund flag survives reload")

	print("test_hair_refund.gd: %d PASS / %d FAIL" % [passed, failed])
	_cleanup()
	quit(0 if failed == 0 else 1)


func _write_legacy_hair_profile() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"version": 4,
		"meta": {"gold": 100, "xp": 0, "level": 1},
		"progression": {"completed_stages": [], "skipped_stages": [], "treasures_claimed": []},
		"daily": {"day_index": 0, "last_claim_date": ""},
		"purchases": {"remove_ads": false},
		"shop": {
			"owned": ["M1", "F1", "hair_blonde"],
			"equipped": {"HAIR": "hair_blonde", "OUTFIT": "", "PET": "", "TRAIL": ""},
			"selected_character": "M1",
		},
	}, "\t"))
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
