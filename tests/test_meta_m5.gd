extends SceneTree

const TEST_PATH := "user://qa/test_meta_m5_profile.json"
const SaveManagerType = preload("res://scripts/save_manager.gd")
const MainScene = preload("res://scenes/main.tscn")
var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var save = SaveManagerType.new(TEST_PATH)
	save.load_profile()
	_check(not bool(save.meta_systems_snapshot().tutorial_completed), "tutorial starts incomplete")
	_check(save.write_settings({"sound": false, "music": true, "ghost": false}), "settings write")
	_check(save.mark_tutorial_completed(), "tutorial completion write")
	var trace := [
		{"t": 0.0, "x": -90.0, "y": 0.0, "branch": -1},
		{"t": 0.1, "x": 0.0, "y": -12.0, "branch": 0},
	]
	_check(save.record_stage_ghost("NORMAL", 1, 9.5, trace), "normal ghost write")
	_check(not save.record_stage_ghost("NORMAL", 1, 10.0, trace), "slower ghost rejected")
	_check(save.record_stage_ghost("NIGHTMARE", 1, 8.5, trace), "nightmare ghost stored separately")
	var loaded = SaveManagerType.new(TEST_PATH)
	var systems := loaded.meta_systems_snapshot()
	_check(bool(systems.tutorial_completed) and not bool(systems.settings.sound) and bool(systems.settings.music) and not bool(systems.settings.ghost), "settings and tutorial persist")
	_check(is_equal_approx(float(systems.ghosts.NORMAL["1"].time), 9.5) and is_equal_approx(float(systems.ghosts.NIGHTMARE["1"].time), 8.5), "mode-specific ghost bests persist")
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.has_node("HUD/Settings") and scene.has_node("HUD/HowToPlay") and scene.has_node("HUD/Credits"), "required menu actions exist")
	_check(_menu_has_no_control_overlap(scene, Vector2(960, 540)) and _menu_has_no_control_overlap(scene, Vector2(844, 390)), "menu controls do not overlap at target sizes")
	var snapshot: Dictionary = scene._readonly_state_snapshot()
	_check(snapshot.has("tutorial") and snapshot.has("ghost"), "debug state exposes tutorial and ghost")
	print("test_meta_m5.gd: %d PASS / %d FAIL" % [passed, failed])
	scene.queue_free()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	quit(0 if failed == 0 else 1)

func _menu_has_no_control_overlap(game: Node, size: Vector2) -> bool:
	game.layout_hud_for_viewport(size)
	var names := ["NewRun", "Shop", "Map", "Nightmare", "Settings", "HowToPlay", "Credits", "GetMoreGold", "RemoveAds"]
	var rects: Array[Rect2] = []
	for node_name in names:
		var control := game.get_node("HUD/%s" % node_name) as Control
		for rect in rects:
			if rect.intersects(Rect2(control.position, control.size), true):
				return false
		rects.append(Rect2(control.position, control.size))
	var daily := game.get_node("HUD/DailyCard") as Control
	for rect in rects:
		if rect.intersects(Rect2(daily.position, daily.size), true):
			return false
	return true

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
