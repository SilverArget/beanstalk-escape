extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _ok(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		print("FAIL: %s" % label)

func _run() -> void:
	_check_schema_and_tempo()
	_check_debuts()
	_check_witnesses()
	_check_mirror()
	await _check_final_flow()
	print("STAGE-DATABASE-1-30-FINAL: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check_schema_and_tempo() -> void:
	var stages := StageDatabase.canonical_stages()
	var valid := stages.size() == 30 and Balance.STAGE_COUNT == 30
	var previous_target := 0
	for index in stages.size():
		var stage: Dictionary = stages[index]
		valid = valid and int(stage.number) == index + 1 and not String(stage.title).is_empty()
		valid = valid and int(stage.start_height) == previous_target and int(stage.target_height) == int(stage.start_height) + int(stage.length)
		valid = valid and stage.encounters.size() >= 9 and stage.witness.size() == stage.encounters.size()
		valid = valid and not String(stage.theme).is_empty() and not String(stage.branch_graph).is_empty()
		var last_anchor := 0
		for encounter: Dictionary in stage.encounters:
			valid = valid and not String(encounter.id).is_empty() and not String(encounter.objective).is_empty()
			valid = valid and int(encounter.anchor) > last_anchor and int(encounter.warning_height) == int(encounter.anchor) - 360
			valid = valid and int(encounter.occupancy[0]) == int(encounter.anchor) and int(encounter.occupancy[1]) <= int(stage.length)
			last_anchor = int(encounter.anchor)
		previous_target = int(stage.target_height)
	_ok(valid, "1-30 required fields, cumulative lengths and >=9 events")

func _check_debuts() -> void:
	var first := {}
	for stage: Dictionary in StageDatabase.canonical_stages():
		for encounter: Dictionary in stage.encounters:
			for threat: Dictionary in StageDatabase.threats_for_recipe(encounter.recipe):
				var kind := String(threat.kind)
				if not first.has(kind): first[kind] = int(stage.number)
	var expected := {"BEAN": 4, "S": 6, "R": 8, "V": 16, "K": 19, "WEB": 20, "F": 21, "WALL": 22, "M": 26}
	var valid := true
	for kind in expected: valid = valid and int(first.get(kind, -1)) == int(expected[kind])
	valid = valid and String(StageDatabase.stage(5).skill_unlock) == "TIME" and String(StageDatabase.stage(10).skill_unlock) == "FIRE"
	valid = valid and String(StageDatabase.stage(15).tutorial_trigger) == "none"
	valid = valid and SpiderController.pressure_profile(20).pressure == 12.0 and SpiderController.pressure_profile(25).g_lo == 156.0
	valid = valid and SpiderController.pressure_profile(29).g_lo == 108.0 and SpiderController.pressure_profile(30).g_lo == 156.0
	_ok(valid, "section 10 debuts, skill locks and 20/25/29/30 pressure bands")

func _check_witnesses() -> void:
	var valid := true
	for stage: Dictionary in StageDatabase.canonical_stages():
		if int(stage.number) < 6: continue
		var route := 1
		for encounter: Dictionary in stage.encounters:
			var target := int(encounter.witness)
			var blocked: Array[int] = []
			for threat: Dictionary in StageDatabase.threats_for_recipe(encounter.recipe):
				var kind := String(threat.kind)
				if kind in ["BEAN", "S", "R", "F", "K", "WEB"]: blocked.append(int(threat.lane))
				elif kind in ["WALL", "M"]:
					for lane in threat.lanes: blocked.append(int(lane))
			valid = valid and target not in blocked and absi(target - route) * Balance.BRANCH_TRANSITION_SECONDS <= 1.25
			route = target
	_ok(valid, "every canonical no-skill witness avoids authored threat lanes")

func _check_mirror() -> void:
	var canonical := StageDatabase.stages_for_variant(StageDatabase.CANONICAL_VARIANT)
	var mirrored := StageDatabase.stages_for_variant(StageDatabase.MIRROR_VARIANT)
	var valid := canonical.size() == 30 and mirrored.size() == 30
	for index in canonical.size():
		var source: Dictionary = canonical[index]
		var target: Dictionary = mirrored[index]
		valid = valid and source.length == target.length and source.encounters.size() == target.encounters.size()
		for event_index in source.encounters.size():
			var a: Dictionary = source.encounters[event_index]
			var b: Dictionary = target.encounters[event_index]
			valid = valid and a.anchor == b.anchor
			if a.witness is int:
				valid = valid and int(b.witness) == 2 - int(a.witness)
			elif a.witness is float:
				valid = valid and is_equal_approx(float(b.witness), 1.0 - float(a.witness))
			var a_threats := StageDatabase.threats_for_recipe(a.recipe)
			var b_threats := StageDatabase.threats_for_recipe(b.recipe)
			for threat_index in a_threats.size():
				if String(a_threats[threat_index].kind) == "V":
					valid = valid and int(b_threats[threat_index].direction) == -int(a_threats[threat_index].direction)
	_ok(valid, "mirror keeps timing and mirrors lanes, witnesses and wind")

func _check_final_flow() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game._on_prototype_completed()
	var started := game.app_state == GameManager.AppState.FINAL_CINEMATIC and game.final_character.visible
	game._update_final_cinematic(GameManager.FINAL_CINEMATIC_SECONDS)
	var completed := game.app_state == GameManager.AppState.GAME_COMPLETE and game.final_t == GameManager.FINAL_CINEMATIC_SECONDS
	var stats := game._stats_text()
	var stats_complete := "TIME" in stats and "DEATHS / RETRIES" in stats and "GOLD COLLECTED" in stats
	game._complete_menu()
	var menu := game.app_state == GameManager.AppState.MENU
	_ok(started and completed and stats_complete and menu, "Stage 30 -> 8s skippable cinematic -> stats -> menu")
	game.queue_free()
	await process_frame
