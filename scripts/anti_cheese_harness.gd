class_name AntiCheeseHarness
extends RefCounted

const DETERMINISTIC_AGENTS := ["no_input", "hold_right", "hold_left", "repress_right_0_5", "repress_left_0_5"]
const RANDOM_ACTION_TICKS := 24
const TRANSFER_TICKS := 48

static func run_deterministic(agent: String, variant: String, final_stage: int) -> Dictionary:
	var route := 1
	if agent.contains("right"):
		route = 2
	elif agent.contains("left"):
		route = 0
	for stage: Dictionary in StageDatabase.stages_for_variant(variant):
		if int(stage.number) > final_stage:
			break
		for encounter: Dictionary in stage.encounters:
			if not _route_survives(encounter, route):
				var closing_speed := Balance.BEAN_FALL_SPEED + Balance.PLAYER_VERTICAL_SPEED
				var contact_delay := (120.0 - Balance.BEAN_HIT_RADIUS) / closing_speed
				return {"completed": false, "failed_stage": stage.number, "encounter": encounter.id, "route": route, "hit_seconds": (float(stage.start_height) + float(encounter.anchor)) / Balance.PLAYER_VERTICAL_SPEED + contact_delay}
	return {"completed": true, "failed_stage": 0, "encounter": "", "route": route}

static func run_random_experiment(attempts_per_variant: int, final_stage: int) -> Dictionary:
	var wins := 0
	var variants := {}
	for variant_index in StageDatabase.QA_VARIANTS.size():
		var variant := String(StageDatabase.QA_VARIANTS[variant_index])
		var variant_wins := 0
		for policy_seed in attempts_per_variant:
			if _run_random(1000003 * (variant_index + 1) + policy_seed, variant, final_stage):
				variant_wins += 1
				wins += 1
		variants[variant] = {"attempts": attempts_per_variant, "wins": variant_wins}
	var attempts := attempts_per_variant * StageDatabase.QA_VARIANTS.size()
	return {"attempts": attempts, "wins": wins, "rate": float(wins) / float(attempts), "upper_95": clopper_pearson_upper(wins, attempts), "variants": variants}

static func clopper_pearson_upper(successes: int, attempts: int) -> float:
	if attempts <= 0 or successes >= attempts:
		return 1.0
	var low := 0.0
	var high := 1.0
	for _iteration in 70:
		var midpoint := (low + high) * 0.5
		if _binomial_cdf(successes, attempts, midpoint) > 0.05:
			low = midpoint
		else:
			high = midpoint
	return high

static func _binomial_cdf(successes: int, attempts: int, probability: float) -> float:
	if probability <= 0.0:
		return 1.0
	if probability >= 1.0:
		return 0.0
	var term := pow(1.0 - probability, attempts)
	var result := term
	for count in range(1, successes + 1):
		term *= float(attempts - count + 1) / float(count) * probability / (1.0 - probability)
		result += term
	return result

static func _run_random(policy_seed: int, variant: String, final_stage: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = policy_seed
	var route := 1
	var transfer_ready_tick := 0
	var events := _hazard_events(variant, final_stage)
	var event_index := 0
	var final_definition := StageDatabase.stage(final_stage)
	var last_tick := int(float(final_definition.get("target_height", Balance.STAGE_HEIGHT * final_stage)) / Balance.PLAYER_VERTICAL_SPEED * ReachabilityValidator.PHYSICS_HZ)
	for tick in range(0, last_tick + 1, RANDOM_ACTION_TICKS):
		while event_index < events.size() and int(events[event_index].tick) <= tick:
			if not _route_survives(events[event_index].encounter, route):
				return false
			event_index += 1
		var choice := rng.randi_range(0, 4)
		if choice == 1 and tick >= transfer_ready_tick and route > 0:
			route -= 1
			transfer_ready_tick = tick + TRANSFER_TICKS
		elif choice == 2 and tick >= transfer_ready_tick and route < 2:
			route += 1
			transfer_ready_tick = tick + TRANSFER_TICKS
	while event_index < events.size():
		if not _route_survives(events[event_index].encounter, route):
			return false
		event_index += 1
	return true

static func _hazard_events(variant: String, final_stage: int) -> Array:
	var events: Array = []
	for stage: Dictionary in StageDatabase.stages_for_variant(variant):
		if int(stage.number) > final_stage:
			continue
		for encounter: Dictionary in stage.encounters:
			var height := float(stage.start_height) + float(encounter.anchor)
			events.append({"tick": int(round(height / Balance.PLAYER_VERTICAL_SPEED * ReachabilityValidator.PHYSICS_HZ)), "encounter": encounter})
	return events

static func _route_survives(encounter: Dictionary, route: int) -> bool:
	var kind := String(encounter.recipe.kind)
	if kind == "FORK":
		return encounter.recipe.supports.has(route)
	if kind == "BEAN":
		return int(encounter.recipe.lane) != route
	return true
