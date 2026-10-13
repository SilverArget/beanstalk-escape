class_name GoldPlacementData
extends RefCounted

const HAZARD_CLEARANCE_PX := 16.0

static func placements_for_stage(stage_number: int, count: int, stages: StageManager) -> Array:
	var result: Array = []
	var definition := StageDatabase.stage(stage_number)
	var encounters: Array = definition.get("encounters", [])
	for index in count:
		var progress := float(index + 1) / float(count + 1)
		var local_height := progress * stages.stage_length(stage_number)
		var encounter := _nearest_encounter(encounters, local_height)
		var witness: Variant = encounter.get("witness", 1)
		var trunk_witness := float(witness)
		if stage_number <= 2 and typeof(witness) == TYPE_INT:
			trunk_witness = float(ScaleLock.TRUNK_SAFE_NORMALIZED_X[int(witness)])
		var preferred_route := stages.route_for_x((trunk_witness - 0.5) * 2.0 * Balance.TRUNK_HALF_WIDTH) if stage_number <= 2 else int(witness)
		var safe_placement := _safe_placement(encounters, local_height, preferred_route, stages.stage_length(stage_number))
		local_height = float(safe_placement.height)
		var route := int(safe_placement.route)
		var world_y := stages.stage_bottom_y(stage_number) - local_height
		var world_x := (trunk_witness - 0.5) * 2.0 * (Balance.TRUNK_HALF_WIDTH - 12.0) if stage_number <= 2 else stages.branch_x_at(route, world_y)
		if stage_number <= 2 and route != preferred_route:
			var safe_witness := float(ScaleLock.TRUNK_SAFE_NORMALIZED_X[route])
			world_x = (safe_witness - 0.5) * 2.0 * (Balance.TRUNK_HALF_WIDTH - 12.0)
		result.append({
			"id": "S%02d-G%02d" % [stage_number, index + 1],
			"stage": stage_number,
			"route": route,
			"position": Vector2(world_x, world_y),
		})
	return result

static func _nearest_encounter(encounters: Array, local_height: float) -> Dictionary:
	var nearest := {}
	var nearest_distance := INF
	for encounter: Dictionary in encounters:
		var distance := absf(float(encounter.anchor) - local_height)
		if distance < nearest_distance:
			nearest = encounter
			nearest_distance = distance
	return nearest

static func _safe_route_for_height(encounters: Array, local_height: float, preferred_route: int) -> int:
	var candidates := [preferred_route, 0, 1, 2]
	for route_value in candidates:
		var route := int(route_value)
		var safe := true
		for encounter: Dictionary in encounters:
			if local_height + HAZARD_CLEARANCE_PX < float(encounter.anchor) or local_height - HAZARD_CLEARANCE_PX > float(encounter.occupancy[1]):
				continue
			if not _route_survives(encounter, route):
				safe = false
				break
		if safe:
			return route
	return -1

static func _safe_placement(encounters: Array, desired_height: float, preferred_route: int, stage_length: float) -> Dictionary:
	for step in 61:
		var distance := float(step) * 4.0
		var candidates := [desired_height] if step == 0 else [desired_height - distance, desired_height + distance]
		for height_value in candidates:
			var height := clampf(float(height_value), HAZARD_CLEARANCE_PX, stage_length - HAZARD_CLEARANCE_PX)
			var route := _safe_route_for_height(encounters, height, preferred_route)
			if route >= 0:
				return {"height": height, "route": route}
	return {"height": desired_height, "route": preferred_route}

static func _route_survives(encounter: Dictionary, route: int) -> bool:
	for threat: Dictionary in StageDatabase.threats_for_recipe(encounter.recipe):
		var kind := String(threat.kind)
		if kind == "FORK" and not threat.supports.has(route):
			return false
		if kind in ["BEAN", "S", "R", "F", "K", "WEB"] and int(threat.lane) == route:
			return false
		if kind in ["WALL", "M"] and threat.lanes.has(route):
			return false
	return true
