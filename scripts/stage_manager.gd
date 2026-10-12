class_name StageManager
extends Node

signal stage_completed(stage_number: int)
signal prototype_completed
const BRANCH_HALF_WIDTH := 18.0
const STAGE_3_SPLIT_HEIGHT := 350.0
var current_stage := 1
var completion_count := 0
var completed_stages: Dictionary = {}
var run_seed := Balance.PATTERN_SEED
var run_variant := StageDatabase.CANONICAL_VARIANT
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
	var result: Array = []
	for stage: Dictionary in StageDatabase.stages_for_variant(run_variant):
		var stage_number := int(stage.number)
		var route_end_progress := [1.0, 1.0, 1.0]
		var open_routes := [0, 1, 2]
		var trunk_features: Array = []
		var support_windows: Array = []
		var bean_slots: Array = []
		for encounter: Dictionary in stage.encounters:
			var kind := String(encounter.recipe.kind)
			if kind == "GUIDE" or kind == "BULGE":
				trunk_features.append({"id": encounter.id, "kind": kind, "x": float(encounter.recipe.x), "warning_height": encounter.warning_height, "occupancy": encounter.occupancy})
			elif kind == "FORK":
				support_windows.append({"id": encounter.id, "start_progress": float(encounter.anchor) / float(stage.length), "end_progress": float(encounter.occupancy[1]) / float(stage.length), "supports": encounter.recipe.supports.duplicate(), "warning_progress": float(encounter.warning_height) / float(stage.length)})
			elif kind == "BEAN":
				var blocked := int(encounter.recipe.lane)
				var slot_progress := float(encounter.anchor) / float(stage.length)
				var safe_routes := [0, 1, 2]
				safe_routes.erase(blocked)
				var safety_route := int(encounter.witness)
				bean_slots.append({"id": encounter.id, "anchor": encounter.anchor, "warning_height": encounter.warning_height, "occupancy": encounter.occupancy, "progress": slot_progress, "blocked_route": blocked, "safe_routes": safe_routes, "safety_route": safety_route, "warning_seconds": Balance.BEAN_WARNING_SECONDS, "count": int(encounter.recipe.get("count", 1))})
		result.append({"stage": stage_number, "entry": 1, "open_routes": open_routes, "route_end_progress": route_end_progress, "trunk_features": trunk_features, "support_windows": support_windows, "bean_slots": bean_slots, "encounters": stage.encounters, "variant": run_variant})
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
	for window: Dictionary in pattern.get("support_windows", []):
		if progress >= float(window.start_progress) and progress <= float(window.end_progress) and not window.supports.has(route):
			return false
	return true

func support_segments(stage_number: int, route: int) -> Array:
	var segments: Array = []
	var cursor := 0.0
	for window: Dictionary in pattern_for_stage(stage_number).get("support_windows", []):
		if window.supports.has(route):
			continue
		var gap_start := float(window.start_progress)
		var gap_end := float(window.end_progress)
		if gap_start > cursor:
			segments.append([cursor, gap_start])
		cursor = maxf(cursor, gap_end)
	if cursor < 1.0:
		segments.append([cursor, 1.0])
	return segments

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
	var progress := progress_in_stage(player_y)
	for window: Dictionary in pattern.get("support_windows", []):
		if window.supports.has(route):
			continue
		if progress >= float(window.start_progress) and progress <= float(window.end_progress):
			return 0.0
		if progress < float(window.start_progress):
			return (float(window.start_progress) - progress) * Balance.STAGE_HEIGHT
	return INF

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
