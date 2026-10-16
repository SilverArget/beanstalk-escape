extends SceneTree

const TRUNK_GOLD_INSET := 18.0
const EPSILON := 0.001

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var save_path := "user://test_gold_support_placement.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	var economy := EconomyManager.new()
	var stages := StageManager.new()
	_check(economy.initialize(SaveManager.new(save_path)), "economy config loads")
	stages.reset_run()
	var old_total := 0
	var new_total := 0
	var ids := {}
	# Optional pre-change snapshot for the brief's before/after measurement.
	var legacy: GDScript
	if FileAccess.file_exists("res://.godot/brief6_legacy_gold.gd"):
		legacy = GDScript.new()
		legacy.source_code = FileAccess.get_file_as_string("res://.godot/brief6_legacy_gold.gd").replace("class_name GoldPlacementData", "")
		_check(legacy.reload() == OK, "pre-change placement snapshot loads")
	for stage_number in range(1, Balance.STAGE_COUNT + 1):
		var expected_count := economy.stage_gold_count(stage_number)
		var placements := GoldPlacementData.placements_for_stage(stage_number, expected_count, stages)
		_check(placements.size() > 0 and placements.size() <= expected_count, "stage %03d respects gold budget %d" % [stage_number, expected_count])
		if stage_number >= 4 and stage_number <= 40:
			new_total += placements.size()
			if legacy != null:
				old_total += legacy.placements_for_stage(stage_number, 8 + posmod(stage_number * 2, 5), stages).size()
		for placement: Dictionary in placements:
			_check(not ids.has(placement.id), "%s is unique" % String(placement.id))
			ids[placement.id] = true
			var position: Vector2 = placement.position
			var supported := _on_trunk(position) if stage_number <= 2 else _on_route_support(stage_number, placement, stages)
			_check(supported, "%s is on reachable support" % String(placement.id))
			var definition := StageDatabase.stage(stage_number, stages.run_variant)
			var probe: Array = []
			GoldPlacementData._append_coin(probe, stage_number, Vector2(position.x, stages.stage_bottom_y(stage_number) - position.y), int(placement.route), definition.encounters, stages)
			_check(probe.size() == 1, "%s respects hazard clearance" % String(placement.id))
	print("GOLD-AVERAGE stages 4-40: old=%s new=%.3f" % ["%.3f" % (float(old_total) / 37.0) if legacy != null else "NOT MEASURED (snapshot absent)", float(new_total) / 37.0])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	stages.free()
	economy = null
	print("GOLD-SUPPORT-PLACEMENT: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _on_trunk(position: Vector2) -> bool:
	return absf(position.x - _trunk_center_x(position.y)) <= _trunk_half_width(position.y) - TRUNK_GOLD_INSET + EPSILON

func _on_route_support(stage_number: int, placement: Dictionary, stages: StageManager) -> bool:
	var route := int(placement.route)
	var position: Vector2 = placement.position
	# Transition coins follow a sine arc between adjacent branch centers.
	# Their collection route remains the nearer endpoint of that transfer.
	if absf(position.x - float(Balance.ROUTE_X[route])) > absf(float(Balance.ROUTE_X[1]) - float(Balance.ROUTE_X[0])) * 0.5 + EPSILON:
		return false
	var progress := (stages.stage_bottom_y(stage_number) - position.y) / stages.stage_length(stage_number)
	for segment: Array in stages.support_segments(stage_number, route):
		if progress >= float(segment[0]) - EPSILON and progress <= float(segment[1]) + EPSILON:
			return true
	return false

func _trunk_center_x(world_y: float) -> float:
	return sin(world_y * TAU / 560.0) * 10.0 + sin(world_y * TAU / 910.0 + 0.7) * 4.0

func _trunk_half_width(world_y: float) -> float:
	return 90.0 + sin(world_y * TAU / 470.0) * 7.0 + sin(world_y * TAU / 150.0) * 3.0

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		print("FAIL: %s" % label)
