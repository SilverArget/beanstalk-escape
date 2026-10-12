extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := "user://test_meta_m1.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var save := SaveManager.new(save_path)
	var economy := EconomyManager.new()
	_check(economy.initialize(save), "economy config loads")
	_check(economy.stage_gold_count(1) >= 8 and economy.stage_gold_count(1) <= 12, "stage gold count is configured range")
	for index in 100:
		economy.collect_gold()
	var after_level := economy.snapshot()
	_check(after_level.level == 2 and after_level.gold == 150 and after_level.xp == 0, "gold XP threshold and level reward")
	var stage_reward := economy.complete_stage(3)
	_check(stage_reward.gold == 26 and stage_reward.xp == 10, "stage reward formula")
	var loaded := EconomyManager.new()
	_check(loaded.initialize(SaveManager.new(save_path)), "saved profile reloads")
	_check(loaded.snapshot() == economy.snapshot(), "wallet XP and level persist")
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt = null
	var fallback := SaveManager.new(save_path).load_profile()
	_check(fallback.meta == {"gold": 0, "xp": 0, "level": 1}, "corrupt save uses safe defaults")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("META_M1_TEST passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
