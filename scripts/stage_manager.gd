class_name StageManager
extends Node

signal stage_completed(stage_number: int)
signal prototype_completed
const BRANCH_HALF_WIDTH := 18.0
const STAGE_3_SPLIT_HEIGHT := 350.0
const STAGES := [
	{"number": 1, "layout": "TRUNK", "bean_slots": [], "skill_slots": []},
	{"number": 2, "layout": "SIMPLE_ROUTE_CHANGE", "bean_slots": [], "skill_slots": []},
	{"number": 3, "layout": "THREE_BRANCH_SPLIT", "bean_slots": [], "skill_slots": []},
	{"number": 4, "layout": "THREE_BRANCHES", "bean_slots": [], "skill_slots": []},
	{"number": 5, "layout": "THREE_BRANCHES", "bean_slots": [], "skill_slots": []},
]
var current_stage := 1
var completion_count := 0
var completed_stages: Dictionary = {}
var run_seed := Balance.PATTERN_SEED
var patterns: Array = []
var summit_flash_count := 0
var stage_banner := ""
var stage_banner_remaining := 0.0

func _ready() -> void: patterns = generate_patterns(run_seed)
func _physics_process(delta: float) -> void:
	if stage_banner_remaining > 0.0:
		stage_banner_remaining = maxf(stage_banner_remaining - delta, 0.0)

func update_progress(player_y: float) -> void:
	var reached := mini(int(floor(-player_y / Balance.STAGE_HEIGHT)), Balance.STAGE_COUNT)
	while current_stage <= reached and current_stage <= Balance.STAGE_COUNT:
		_complete_stage(current_stage)
		current_stage += 1
func _complete_stage(stage_number: int) -> void:
	if completed_stages.has(stage_number): return
	completed_stages[stage_number] = true
	completion_count += 1
	summit_flash_count += 3
	stage_banner = "STAGE %d COMPLETE" % stage_number
	stage_banner_remaining = Balance.STAGE_COMPLETE_SECONDS
	stage_completed.emit(stage_number)
	if stage_number == Balance.STAGE_COUNT: prototype_completed.emit()
func reset_run() -> void:
	current_stage = 1
	completion_count = 0
	completed_stages.clear()
	summit_flash_count = 0
	stage_banner = ""
	stage_banner_remaining = 0.0
	patterns = generate_patterns(run_seed)
func generate_patterns(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array = []
	for stage_index in Balance.STAGE_COUNT:
		var stage_number := stage_index + 1
		var route_end_progress := [1.0, 1.0, 1.0]
		var open_routes := [0, 1, 2]
		if stage_number == 2:
			rng.randi_range(0, 2) # Preserve later stage pattern data from the previous seed stream.
			route_end_progress[1] = 0.55
			route_end_progress[0] = 0.995
		elif stage_number == 3:
			route_end_progress = [1.0, 0.78, 0.46]
		elif stage_number == 4:
			route_end_progress[0] = 0.64
		elif stage_number == 5:
			route_end_progress[1] = 0.78
		for route in 3:
			if route_end_progress[route] < 1.0:
				open_routes.erase(route)
		var bean_slots: Array = []
		if stage_number >= 4:
			for slot_index in 4:
				var blocked := 0
				if stage_number == 4:
					blocked = [0, [0, 2][rng.randi_range(0, 1)], [0, 2][rng.randi_range(0, 1)], 1][slot_index]
				else:
					blocked = [2, [0, 2][rng.randi_range(0, 1)], 1, [1, 2][rng.randi_range(0, 1)]][slot_index]
				var slot_progress := 0.18 + slot_index * 0.20
				var safe_routes := [0, 1, 2]
				safe_routes.erase(blocked)
				safe_routes = safe_routes.filter(func(route: int) -> bool: return route_end_progress[route] > slot_progress)
				if safe_routes.is_empty():
					blocked = (blocked + 1) % 3
					safe_routes = [0, 1, 2].filter(func(route: int) -> bool: return route != blocked and route_end_progress[route] > slot_progress)
				var safety_route: int = safe_routes[rng.randi_range(0, safe_routes.size() - 1)]
				bean_slots.append({"progress": slot_progress, "blocked_route": blocked, "safe_routes": safe_routes, "safety_route": safety_route, "warning_seconds": Balance.BEAN_WARNING_SECONDS})
		result.append({"stage": stage_number, "entry": 1, "open_routes": open_routes, "route_end_progress": route_end_progress, "bean_slots": bean_slots})
	return result
func pattern_hash(seed_value: int) -> int: return hash(var_to_str(generate_patterns(seed_value)))
func patterns_are_reachable(candidate: Array) -> bool:
	var reachable_routes: Array[int] = []
	for segment: Dictionary in candidate:
		if segment.open_routes.size() < 1:
			return false
		for progress: float in segment.route_end_progress:
			if progress < 0.0 or progress > 1.0:
				return false
		if reachable_routes.is_empty():
			reachable_routes = [int(segment.get("entry", 1))]
		var events: Array[Dictionary] = []
		for route in 3:
			var end_progress: float = segment.route_end_progress[route]
			if end_progress < 1.0:
				var allowed: Array[int] = []
				for candidate_route in 3:
					if float(segment.route_end_progress[candidate_route]) > end_progress:
						allowed.append(candidate_route)
				events.append({"progress": end_progress, "allowed": allowed, "warning": Balance.ROUTE_DEAD_END_WARNING_SECONDS})
		for slot: Dictionary in segment.bean_slots:
			var allowed: Array[int] = []
			for route_value in slot.safe_routes:
				var route := int(route_value)
				if float(segment.route_end_progress[route]) > float(slot.progress):
					allowed.append(route)
			events.append({"progress": float(slot.progress), "allowed": allowed, "warning": float(slot.warning_seconds)})
		events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.progress) < float(b.progress))
		var previous_progress := 0.0
		for event: Dictionary in events:
			var available_seconds := maxf((float(event.progress) - previous_progress) * Balance.STAGE_DURATION_SECONDS, float(event.warning))
			reachable_routes = _reachable_targets(reachable_routes, event.allowed, available_seconds)
			if reachable_routes.is_empty():
				return false
			previous_progress = float(event.progress)
		var end_routes: Array[int] = []
		for route in 3:
			if float(segment.route_end_progress[route]) >= 1.0:
				end_routes.append(route)
		reachable_routes = _reachable_targets(reachable_routes, end_routes, (1.0 - previous_progress) * Balance.STAGE_DURATION_SECONDS)
		if reachable_routes.is_empty():
			return false
	return true

func _reachable_targets(from_routes: Array[int], allowed_routes: Array, available_seconds: float) -> Array[int]:
	var result: Array[int] = []
	for target_value in allowed_routes:
		var target := int(target_value)
		for source in from_routes:
			var steps: int = absi(target - source)
			var required_seconds: float = float(steps) * (Balance.BRANCH_TRANSITION_SECONDS + Balance.BRANCH_COMMAND_BUFFER_SECONDS)
			if required_seconds <= available_seconds + 0.001:
				if not result.has(target):
					result.append(target)
				break
	return result

func stage_for_y(player_y: float) -> int:
	return clampi(int(floor(-player_y / Balance.STAGE_HEIGHT)) + 1, 1, Balance.STAGE_COUNT)

func progress_in_stage(player_y: float) -> float:
	var stage_start := float(stage_for_y(player_y) - 1) * Balance.STAGE_HEIGHT
	return clampf((-player_y - stage_start) / Balance.STAGE_HEIGHT, 0.0, 1.0)

func pattern_for_stage(stage_number: int) -> Dictionary:
	for pattern: Dictionary in patterns:
		if pattern.stage == stage_number:
			return pattern
	return patterns[0]

func route_for_x(x: float) -> int:
	var best := 0
	for route in 3:
		if absf(Balance.ROUTE_X[route] - x) < absf(Balance.ROUTE_X[best] - x):
			best = route
	return best

func branch_x_at(route: int, player_y: float) -> float:
	var stage_number := stage_for_y(player_y)
	if stage_number <= 2:
		return 0.0
	if stage_number == 3:
		var split_pixels := progress_in_stage(player_y) * Balance.STAGE_HEIGHT
		return lerpf(0.0, float(Balance.ROUTE_X[route]), clampf(split_pixels / STAGE_3_SPLIT_HEIGHT, 0.0, 1.0))
	return float(Balance.ROUTE_X[route])

func is_route_open_at(stage_number: int, route: int, progress: float) -> bool:
	var pattern := pattern_for_stage(stage_number)
	var end_progress := float(pattern.route_end_progress[route])
	return end_progress >= 1.0 or progress < end_progress

func route_end_world_y(stage_number: int, route: int) -> float:
	var stage_bottom := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	return stage_bottom - float(pattern_for_stage(stage_number).route_end_progress[route]) * Balance.STAGE_HEIGHT

func has_recovery_edge(stage_number: int, from_route: int, to_route: int) -> bool:
	var pattern := pattern_for_stage(stage_number)
	for edge in pattern.get("recovery_edges", []):
		if int(edge[0]) == from_route and int(edge[1]) == to_route:
			return true
	return false

func current_route_open(player_y: float, x: float) -> bool:
	return is_route_open_at(stage_for_y(player_y), route_for_x(x), progress_in_stage(player_y))

func next_dead_end_distance(player_y: float, x: float, active_route := -1) -> float:
	var stage_number := stage_for_y(player_y)
	var route := active_route if active_route >= 0 else route_for_x(x)
	var pattern := pattern_for_stage(stage_number)
	var end_progress := float(pattern.route_end_progress[route])
	var progress := progress_in_stage(player_y)
	if end_progress >= 1.0 or progress >= end_progress:
		return INF if end_progress >= 1.0 else 0.0
	return (end_progress - progress) * Balance.STAGE_HEIGHT

func open_routes_at(player_y: float) -> Array:
	var stage_number := stage_for_y(player_y)
	var progress := progress_in_stage(player_y)
	var routes := []
	for route in 3:
		if is_route_open_at(stage_number, route, progress):
			routes.append(route)
	return routes

func branch_targets_visible(player_y: float, viewport_height := 540.0) -> bool:
	if stage_for_y(player_y) != 3:
		return stage_for_y(player_y) > 3
	var split_start_y := -Balance.STAGE_HEIGHT * 2.0 - 140.0
	var split_end_y := -Balance.STAGE_HEIGHT * 2.0 - 350.0
	var camera_top_y := player_y - ScaleLock.CHARACTER_REFERENCE_Y
	var camera_bottom_y := camera_top_y + viewport_height
	return (split_start_y >= camera_top_y and split_start_y <= camera_bottom_y) or (split_end_y >= camera_top_y and split_end_y <= camera_bottom_y) or player_y <= split_end_y
