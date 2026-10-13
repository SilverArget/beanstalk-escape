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
	for stage_number in range(1, Balance.STAGE_COUNT + 1):
		var expected_count := economy.stage_gold_count(stage_number)
		var placements := GoldPlacementData.placements_for_stage(stage_number, expected_count, stages)
		_check(placements.size() == expected_count, "stage %02d keeps %d gold" % [stage_number, expected_count])
		for placement: Dictionary in placements:
			var position: Vector2 = placement.position
			var supported := _on_trunk(position) if stage_number <= 2 else _on_route_support(stage_number, placement, stages)
			_check(supported, "%s is on reachable support" % String(placement.id))
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
	if not is_equal_approx(position.x, float(Balance.ROUTE_X[route])):
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
