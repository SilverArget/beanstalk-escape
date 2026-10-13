class_name GoldPlacementData
extends RefCounted

static func placements_for_stage(stage_number: int, count: int, stages: StageManager) -> Array:
	var result: Array = []
	var definition := StageDatabase.stage(stage_number)
	var encounters: Array = definition.get("encounters", [])
	for index in count:
		var progress := float(index + 1) / float(count + 1)
		var world_y := stages.stage_bottom_y(stage_number) - progress * stages.stage_length(stage_number)
		var encounter_index := mini(int(floor(progress * encounters.size())), encounters.size() - 1)
		var witness: Variant = encounters[encounter_index].witness
		var trunk_witness := float(witness)
		if stage_number <= 2 and typeof(witness) == TYPE_INT:
			trunk_witness = float(ScaleLock.TRUNK_SAFE_NORMALIZED_X[int(witness)])
		var route := stages.route_for_x((trunk_witness - 0.5) * 2.0 * Balance.TRUNK_HALF_WIDTH) if stage_number <= 2 else int(witness)
		var world_x := (trunk_witness - 0.5) * 2.0 * (Balance.TRUNK_HALF_WIDTH - 12.0) if stage_number <= 2 else stages.branch_x_at(route, world_y)
		result.append({
			"id": "S%02d-G%02d" % [stage_number, index + 1],
			"stage": stage_number,
			"route": route,
			"position": Vector2(world_x, world_y),
		})
	return result
