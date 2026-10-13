extends SceneTree

const PREVIOUS_TOTAL_LENGTH := 89200
const GOLD_CLEARANCE_PX := 16.0

var failures := 0

func _initialize() -> void:
	var stages := StageDatabase.canonical_stages()
	var manager := StageManager.new()
	root.add_child(manager)
	await process_frame
	_check_tempo(stages)
	_check_reachability(stages, manager)
	_check_gold(stages, manager)
	print("STAGE-TEMPO: PASS %d / FAIL %d" % [3 - failures, failures])
	manager.queue_free()
	quit(0 if failures == 0 else 1)

func _check_tempo(stages: Array) -> void:
	var valid := stages.size() == 30
	var total := 0
	for index in stages.size():
		var stage: Dictionary = stages[index]
		var expected_length := int(round((1600.0 + 600.0 * float(index) / 29.0) / 10.0)) * 10
		valid = valid and int(stage.length) == expected_length
		valid = valid and stage.encounters.size() == _expected_encounters(index + 1)
		total += int(stage.length)
	valid = valid and total < PREVIOUS_TOTAL_LENGTH and total >= 56000 and total <= 58000
	valid = valid and float(stages[-1].length) / Balance.PLAYER_VERTICAL_SPEED < 24.0
	_check(valid, "tempo data controls all 30 lengths and encounter counts")

func _check_reachability(stages: Array, manager: StageManager) -> void:
	var valid := true
	for stage: Dictionary in stages:
		var previous_anchor := -1
		var previous_route := 1
		for encounter: Dictionary in stage.encounters:
			var anchor := int(encounter.anchor)
			valid = valid and anchor >= StageDatabase.WARNING_LEAD
			valid = valid and int(encounter.occupancy[1]) <= int(stage.length)
			if previous_anchor >= 0:
				valid = valid and anchor - previous_anchor >= 220
			if int(stage.number) >= 3:
				var target := int(encounter.witness)
				valid = valid and _route_survives(encounter, target)
				if previous_anchor >= 0:
					var available := float(anchor - previous_anchor) / Balance.PLAYER_VERTICAL_SPEED
					valid = valid and float(absi(target - previous_route)) * Balance.BRANCH_TRANSITION_SECONDS <= available
				previous_route = target
			previous_anchor = anchor
	valid = valid and manager.patterns_are_reachable(manager.patterns)
	for variant in StageDatabase.QA_VARIANTS:
		valid = valid and bool(ReachabilityValidator.solve_stages_1_to_5(String(variant)).valid)
		for agent in AntiCheeseHarness.DETERMINISTIC_AGENTS:
			valid = valid and not bool(AntiCheeseHarness.run_deterministic(String(agent), String(variant), 30).completed)
	_check(valid, "all authored witnesses remain reachable with safe spacing")

func _check_gold(stages: Array, manager: StageManager) -> void:
	var economy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/economy.json"))
	var minimum := int(economy.stage_gold_count_min)
	var maximum := int(economy.stage_gold_count_max)
	var valid := minimum == 8 and maximum == 12
	for stage: Dictionary in stages:
		var count := minimum + posmod(int(stage.number) * 2, maximum - minimum + 1)
		var placements := GoldPlacementData.placements_for_stage(int(stage.number), count, manager)
		valid = valid and placements.size() >= 8 and placements.size() <= 12
		for placement: Dictionary in placements:
			var local_height := -float(placement.position.y) - float(stage.start_height)
			valid = valid and local_height > 0.0 and local_height < float(stage.length)
			for encounter: Dictionary in stage.encounters:
				if local_height + GOLD_CLEARANCE_PX < float(encounter.anchor) or local_height - GOLD_CLEARANCE_PX > float(encounter.occupancy[1]):
					continue
				var survives := _route_survives(encounter, int(placement.route))
				if not survives:
					print("GOLD-CONFLICT stage=%d gold=%s height=%.1f route=%d encounter=%s occupancy=%s" % [stage.number, placement.id, local_height, placement.route, encounter.id, str(encounter.occupancy)])
				valid = valid and survives
	_check(valid, "each stage keeps 8-12 reachable gold placements clear of threats")

func _expected_encounters(stage_number: int) -> int:
	if stage_number <= 5:
		return 5
	if stage_number <= 15:
		return 6
	if stage_number <= 25:
		return 7
	return 8

func _route_survives(encounter: Dictionary, route: int) -> bool:
	for threat: Dictionary in StageDatabase.threats_for_recipe(encounter.recipe):
		var kind := String(threat.kind)
		if kind == "FORK" and not threat.supports.has(route):
			return false
		if kind in ["BEAN", "S", "R", "F", "K", "WEB"] and int(threat.lane) == route:
			return false
		if kind in ["WALL", "M"] and threat.lanes.has(route):
			return false
	return true

func _check(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + label)
	if not condition:
		failures += 1
