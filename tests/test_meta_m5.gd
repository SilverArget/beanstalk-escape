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
	_check(_menu_layout_is_clear(scene, Vector2(960, 540)) and _menu_layout_is_clear(scene, Vector2(844, 390)), "menu grid clears logo prompt daily and ad actions")
	_check(_ghost_is_distinct_and_behind_player(scene), "ghost uses a visible pale silhouette and outline behind the player")
	scene._start_onboarding()
	_check(scene.tutorial_active and scene.stages.current_stage == 1 and scene.stages.stage_for_y(scene.player.global_position.y) >= 3 and scene.player.transition_state_name() == "ATTACHED", "tutorial uses a separate three-branch practice segment before stage 1")
	var accepted: bool = scene.dispatch_command("move_left", "test")
	scene.player._physics_process(0.016)
	scene._update_onboarding(0.016)
	_check(accepted and scene.tutorial_step == 2, "one accepted branch change completes tutorial step 1")
	scene.on_bean_hit()
	_check(scene.tutorial_step == 2 and scene.tutorial_step_elapsed == 0.0, "tutorial bean hit repeats step 2")
	_check(_tutorial_panel_clears_hud(scene, Vector2(960, 540)) and _tutorial_panel_clears_hud(scene, Vector2(844, 390)), "tutorial panel clears gameplay HUD at target sizes")
	scene.tutorial_active = false
	scene.app_state = scene.AppState.GAME_COMPLETE
	scene._update_hud()
	_check(_result_layout_is_clear(scene, Vector2(960, 540)) and _result_layout_is_clear(scene, Vector2(844, 390)), "result panel separates stats six badges and actions")
	var snapshot: Dictionary = scene._readonly_state_snapshot()
	_check(snapshot.has("tutorial") and snapshot.has("ghost"), "debug state exposes tutorial and ghost")
	print("test_meta_m5.gd: %d PASS / %d FAIL" % [passed, failed])
	scene.free()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	quit(0 if failed == 0 else 1)

func _menu_layout_is_clear(game: Node, size: Vector2) -> bool:
	game.layout_hud_for_viewport(size)
	var names := ["MenuLogo", "Menu", "NewRun", "Shop", "Map", "Nightmare", "Settings", "HowToPlay", "Credits", "GetMoreGold", "RemoveAds"]
	var rects: Array[Rect2] = []
	for node_name in names:
		var control := game.get_node("HUD/%s" % node_name) as Control
		if not control.visible:
			continue
		for rect in rects:
			if rect.intersects(Rect2(control.position, control.size), true):
				return false
		rects.append(Rect2(control.position, control.size))
	var daily := game.get_node("HUD/DailyCard") as Control
	for rect in rects:
		if rect.intersects(Rect2(daily.position, daily.size), true):
			return false
	var first_row: Array = [game.get_node("HUD/NewRun"), game.get_node("HUD/Shop"), game.get_node("HUD/Map")]
	if game.get_node("HUD/Nightmare").visible:
		first_row.append(game.get_node("HUD/Nightmare"))
	var row_left: float = first_row[0].position.x
	var row_right: float = first_row[-1].position.x + first_row[-1].size.x
	if absf((row_left + row_right) * 0.5 - size.x * 0.5) >= 1.0:
		return false
	var commerce: Array = [game.get_node("HUD/GetMoreGold"), game.get_node("HUD/RemoveAds")].filter(func(control): return control.visible)
	if not commerce.is_empty():
		var commerce_left: float = commerce[0].position.x
		var commerce_right: float = commerce[-1].position.x + commerce[-1].size.x
		if absf((commerce_left + commerce_right) * 0.5 - size.x * 0.5) >= 1.0:
			return false
	return true

func _ghost_is_distinct_and_behind_player(game: Node) -> bool:
	var ghost := game.ghost_sprite as Sprite2D
	var outline := ghost.get_node("Outline") as Sprite2D
	return ghost.modulate.a >= 0.39 and ghost.modulate.b > ghost.modulate.r and outline.modulate.a > ghost.modulate.a and ghost.z_index < game.player.z_index

func _tutorial_panel_clears_hud(game: Node, size: Vector2) -> bool:
	game.layout_hud_for_viewport(size)
	game._update_hud()
	var panel := game.get_node("HUD/TutorialPanel") as Control
	var skip := game.get_node("HUD/TutorialSkip") as Control
	if panel.position.y + panel.size.y > 112.0 or skip.position.y + skip.size.y > 172.0:
		return false
	if Rect2(panel.position, panel.size).intersects(Rect2(skip.position, skip.size), true):
		return false
	for node_name in ["GoldStatus", "XPStatus", "XPBar", "Gauge", "MiniMap", "StageCounter", "TouchLeft", "TouchRight"]:
		var control := game.get_node("HUD/%s" % node_name) as Control
		if control.visible and (Rect2(panel.position, panel.size).intersects(Rect2(control.position, control.size), true) or Rect2(skip.position, skip.size).intersects(Rect2(control.position, control.size), true)):
			return false
	return true

func _result_layout_is_clear(game: Node, size: Vector2) -> bool:
	game.layout_hud_for_viewport(size)
	game._update_hud()
	if not game.has_node("HUD/ResultPanel") or game.player.visible or game.spider.visible:
		return false
	var content_names := ["Complete", "Stats", "Replay", "Challenge0", "Challenge1", "Challenge2", "Challenge3", "Challenge4", "Challenge5"]
	var action_names := ["CompleteNewRun", "CompleteNightmare", "CompleteMenu"]
	var content_rects: Array[Rect2] = []
	for node_name in content_names:
		var control := game.get_node("HUD/%s" % node_name) as Control
		if not control.visible:
			return false
		var rect := Rect2(control.position, control.size)
		for other in content_rects:
			if rect.intersects(other, true):
				return false
		content_rects.append(rect)
	for action_name in action_names:
		var action := game.get_node("HUD/%s" % action_name) as Control
		var action_rect := Rect2(action.position, action.size)
		for content_rect in content_rects:
			if action_rect.intersects(content_rect, true):
				return false
	return true

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
