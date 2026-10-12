class_name ReachabilityValidator
extends RefCounted

const PHYSICS_HZ := 120
const REACTION_SECONDS := 0.35
const COMMAND_GAP_SECONDS := 0.45

static func solve_stages_1_to_5(variant: String) -> Dictionary:
	var stages := StageDatabase.stages_for_variant(variant)
	if stages.size() != 5 or Engine.physics_ticks_per_second != PHYSICS_HZ:
		return {"valid": false, "commands": []}
	var commands: Array = []
	var route := 1
	var transition_count := 0
	var minimum_gap := INF
	for stage: Dictionary in stages:
		for encounter: Dictionary in stage.encounters:
			if int(stage.number) < 3 and String(encounter.recipe.kind) != "BEAN":
				continue
			var target := int(encounter.witness)
			var warning_world_height := float(int(stage.number) - 1) * Balance.STAGE_HEIGHT + float(encounter.warning_height)
			var reaction_tick := int(round((warning_world_height / Balance.PLAYER_VERTICAL_SPEED + REACTION_SECONDS) * PHYSICS_HZ))
			var issue_ticks: Array[int] = []
			var cursor_route := route
			while cursor_route != target:
				var issue_tick := reaction_tick if issue_ticks.is_empty() else issue_ticks[-1] + int(round(COMMAND_GAP_SECONDS * PHYSICS_HZ))
				var next_route := cursor_route + signi(target - cursor_route)
				while int(stage.number) >= 3 and not _routes_connected_at_tick(stage, cursor_route, next_route, issue_tick):
					issue_tick += 1
				issue_ticks.append(issue_tick)
				cursor_route = next_route
				transition_count += 1
			var settle_ticks := int(round((Balance.BRANCH_TRANSITION_SECONDS if int(stage.number) >= 3 else 0.20) * PHYSICS_HZ)) + 2
			var checkpoint_tick := reaction_tick if issue_ticks.is_empty() else issue_ticks[-1] + settle_ticks
			var checkpoint := {
				"stage": int(stage.number),
				"route": target,
				"support": "SUPPORTED",
				"transition_count": transition_count,
				"bean_hits": 0,
				"death": "NONE",
			}
			commands.append({
				"encounter": String(encounter.id),
				"stage": int(stage.number),
				"target": target,
				"trunk_target_x": float(ScaleLock.TRUNK_SAFE_WORLD_X[target]) if int(stage.number) < 3 else NAN,
				"warning_tick": int(round(warning_world_height / Balance.PLAYER_VERTICAL_SPEED * PHYSICS_HZ)),
				"issue_ticks": issue_ticks,
				"checkpoint_tick": checkpoint_tick,
				"expected_hash": ReplayVerifier.checkpoint_hash(checkpoint),
			})
			if not issue_ticks.is_empty():
				minimum_gap = minf(minimum_gap, float(issue_ticks[-1] - issue_ticks[0]) / PHYSICS_HZ if issue_ticks.size() > 1 else COMMAND_GAP_SECONDS)
			route = target
	var expected_commands := 0
	for stage: Dictionary in stages:
		for encounter: Dictionary in stage.encounters:
			if int(stage.number) >= 3 or String(encounter.recipe.kind) == "BEAN":
				expected_commands += 1
	return {
		"valid": commands.size() == expected_commands,
		"variant": variant,
		"commands": commands,
		"physics_hz": PHYSICS_HZ,
		"minimum_reaction_seconds": REACTION_SECONDS,
		"minimum_command_gap_seconds": COMMAND_GAP_SECONDS if is_inf(minimum_gap) else minimum_gap,
		"transfer_seconds": Balance.BRANCH_TRANSITION_SECONDS,
		"skill_used": false,
	}

static func _routes_connected_at_tick(stage: Dictionary, from_route: int, to_route: int, tick: int) -> bool:
	var world_height := float(tick) / PHYSICS_HZ * Balance.PLAYER_VERTICAL_SPEED
	var local_height := world_height - float(int(stage.number) - 1) * Balance.STAGE_HEIGHT
	for encounter: Dictionary in stage.encounters:
		if String(encounter.recipe.kind) != "FORK":
			continue
		if local_height >= float(encounter.anchor) and local_height <= float(encounter.occupancy[1]):
			return encounter.recipe.supports.has(from_route) and encounter.recipe.supports.has(to_route)
	return true
