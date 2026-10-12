extends SceneTree

var failures := 0

func _check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func _action_has_key(action: String, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _initialize() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame

	var arrows_ok := _action_has_key("move_left", KEY_LEFT) and _action_has_key("move_right", KEY_RIGHT)
	_check(arrows_ok, "INPUT-ARROWS", "left=%s right=%s" % [str(_action_has_key("move_left", KEY_LEFT)), str(_action_has_key("move_right", KEY_RIGHT))])

	game._show_character_select()
	await process_frame
	await process_frame
	var focused := game.get_viewport().gui_get_focus_owner()
	var focus_ok := focused == game.meta_ui.start_button
	_check(focus_ok, "CHARACTER-SELECT-FOCUS", "focus=%s" % (focused.name if focused != null else "none"))

	game.app_state = GameManager.AppState.PLAYING
	game.player.support_state = PlayerController.SupportState.TRANSFERRING
	var visual := game.player.get_node("Body") as PlayerVisual
	visual.celebrate_remaining = 0.75
	visual._process(0.0)
	var snapshot := visual.visual_snapshot()
	var jump_ok: bool = snapshot.mode == "jump" and snapshot.frame == "jump"
	_check(jump_ok, "TRANSFER-JUMP-PRIORITY", "mode=%s frame=%s celebration=%.2f" % [snapshot.mode, snapshot.frame, visual.celebrate_remaining])

	game.queue_free()
	await process_frame
	print("RESULT input_contract PASS=%d FAIL=%d" % [3 - failures, failures])
	quit(0 if failures == 0 else 1)
