class_name ReplayVerifier
extends RefCounted

const PHYSICS_HZ := 120
const STEP := 1.0 / float(PHYSICS_HZ)

static func checkpoint_hash(snapshot: Dictionary) -> int:
	return hash(JSON.stringify(snapshot))

static func run_stages_1_to_5(game: GameManager, commands: Array, expected_hashes: Array = []) -> Dictionary:
	var actions_by_tick := {}
	var checkpoints_by_tick := {}
	for command: Dictionary in commands:
		var target := int(command.target)
		var route_cursor := _route_before(commands, command)
		for issue_tick_value in command.issue_ticks:
			var issue_tick := int(issue_tick_value)
			var direction := signi(target - route_cursor)
			actions_by_tick[issue_tick] = "move_right" if direction > 0 else "move_left"
			route_cursor += direction
		checkpoints_by_tick[int(command.checkpoint_tick)] = command
	var hashes: Array = []
	var expected_from_solution: Array = []
	var minimum_gap := INF
	var last_tick := int(ceil(5.0 * Balance.STAGE_HEIGHT / Balance.PLAYER_VERTICAL_SPEED * PHYSICS_HZ)) + PHYSICS_HZ
	for tick in last_tick:
		if actions_by_tick.has(tick):
			game.dispatch_command(String(actions_by_tick[tick]), "replay")
		_tick_real_scene(game)
		minimum_gap = minf(minimum_gap, game.spider.distance_to_player())
		if checkpoints_by_tick.has(tick):
			var snapshot := _checkpoint_snapshot(game)
			hashes.append(checkpoint_hash(snapshot))
			expected_from_solution.append(int((checkpoints_by_tick[tick] as Dictionary).expected_hash))
		if game.app_state == GameManager.AppState.PLAYER_DEAD or game.app_state == GameManager.AppState.GAME_COMPLETE:
			break
	var comparison := expected_hashes if not expected_hashes.is_empty() else expected_from_solution
	return {
		"completed": game.app_state == GameManager.AppState.GAME_COMPLETE,
		"bean_hits": game.beans.hit_count,
		"minimum_gap": minimum_gap,
		"hashes": hashes,
		"hashes_match": hashes == comparison,
		"death_cause": GameManager.DeathCause.keys()[game.death_cause],
		"final_stage": game.stages.stage_for_y(game.player.global_position.y),
		"final_route": game.player.active_branch,
		"final_y": game.player.global_position.y,
		"support_state": game.player.support_state_name(),
	}

static func _route_before(commands: Array, sought: Dictionary) -> int:
	var route := 1
	for command: Dictionary in commands:
		if command == sought:
			return route
		route = int(command.target)
	return route

static func _tick_real_scene(game: GameManager) -> void:
	if game.app_state != GameManager.AppState.PLAYING:
		game._physics_process(STEP)
		return
	game.player._physics_process(STEP)
	game.beans._physics_process(STEP)
	for bean in game.get_tree().get_nodes_in_group("beans"):
		if bean.active:
			bean.advance_threat_clock(STEP, game.player.time_wings_active)
	game.spider._physics_process(STEP)
	game._physics_process(STEP)

static func _checkpoint_snapshot(game: GameManager) -> Dictionary:
	return {
		"stage": game.stages.stage_for_y(game.player.global_position.y),
		"route": game.player.active_branch,
		"support": game.player.support_state_name(),
		"transition_count": game.player.branch_transition_count,
		"bean_hits": game.beans.hit_count,
		"death": GameManager.DeathCause.keys()[game.death_cause],
	}
