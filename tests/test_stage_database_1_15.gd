extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	_check_schema()
	_check_debuts_and_skills()
	_check_canonical_witnesses()
	_check_mirror_contract()
	_check_main_scene_loads()
	print("STAGE-DATABASE-1-15: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _ok(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		print("FAIL: %s" % label)

func _check_schema() -> void:
	var stages := StageDatabase.canonical_stages()
	var valid := stages.size() == 15
	var expected_counts := [10, 10, 10, 10, 10, 5, 5, 5, 5, 5, 4, 5, 5, 5, 5]
	var previous_target := 0
	for index in stages.size():
		var stage: Dictionary = stages[index]
		valid = valid and int(stage.number) == index + 1 and not String(stage.title).is_empty()
		valid = valid and int(stage.start_height) == previous_target and int(stage.target_height) == int(stage.start_height) + int(stage.length)
		valid = valid and stage.encounters.size() == expected_counts[index] and stage.witness.size() == expected_counts[index]
		valid = valid and not String(stage.theme).is_empty() and not String(stage.branch_graph).is_empty()
		var last_anchor := 0
		for encounter: Dictionary in stage.encounters:
			valid = valid and not String(encounter.id).is_empty() and not String(encounter.objective).is_empty()
			valid = valid and int(encounter.anchor) > last_anchor and int(encounter.warning_height) == int(encounter.anchor) - 360
			valid = valid and int(encounter.occupancy[0]) == int(encounter.anchor) and int(encounter.occupancy[1]) == int(encounter.anchor) + 220
			last_anchor = int(encounter.anchor)
		previous_target = int(stage.target_height)
	_ok(valid, "1-15 required fields, lengths and event counts")

func _check_debuts_and_skills() -> void:
	var first := {}
	for stage: Dictionary in StageDatabase.canonical_stages():
		for encounter: Dictionary in stage.encounters:
			for threat: Dictionary in StageDatabase.threats_for_recipe(encounter.recipe):
				var kind := String(threat.kind)
				if not first.has(kind): first[kind] = int(stage.number)
	var valid := int(first.get("BEAN", -1)) == 4 and int(first.get("S", -1)) == 6 and int(first.get("R", -1)) == 8
	valid = valid and not first.has("V") and not first.has("K") and not first.has("WEB") and not first.has("F") and not first.has("WALL") and not first.has("M")
	valid = valid and String(StageDatabase.stage(5).skill_unlock) == "TIME" and String(StageDatabase.stage(10).skill_unlock) == "FIRE"
	valid = valid and String(StageDatabase.stage(13).branch_graph) == "J13" and String(StageDatabase.stage(15).tutorial_trigger) == "none"
	_ok(valid, "mechanic debut order, skill unlocks and Stage 13/15 contracts")

func _check_canonical_witnesses() -> void:
	var valid := true
	for stage: Dictionary in StageDatabase.canonical_stages():
		if int(stage.number) < 6: continue
		var route := 1
		for encounter: Dictionary in stage.encounters:
			var target := int(encounter.witness)
			var blocked: Array[int] = []
			for threat: Dictionary in StageDatabase.threats_for_recipe(encounter.recipe):
				if String(threat.kind) in ["BEAN", "S", "R", "F"]: blocked.append(int(threat.lane))
				elif String(threat.kind) == "WALL":
					for lane in threat.lanes: blocked.append(int(lane))
			valid = valid and target not in blocked and absi(target - route) * Balance.BRANCH_TRANSITION_SECONDS <= 1.25
			route = target
	_ok(valid, "canonical no-skill witnesses avoid every authored threat lane")

func _check_mirror_contract() -> void:
	var canonical := StageDatabase.stages_for_variant(StageDatabase.CANONICAL_VARIANT)
	var mirrored := StageDatabase.stages_for_variant(StageDatabase.MIRROR_VARIANT)
	var valid := canonical.size() == mirrored.size()
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
	_ok(valid, "mirror keeps timing and mirrors integer witnesses")

func _check_main_scene_loads() -> void:
	_ok(ResourceLoader.load("res://scenes/main.tscn") is PackedScene, "merged gameplay scene and scripts load")
