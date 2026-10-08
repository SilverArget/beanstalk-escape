class_name StageManager
extends Node

signal stage_completed(stage_number: int)
signal prototype_completed
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
			var closed := rng.randi_range(0, 2)
			route_end_progress[closed] = 0.55
		elif stage_number == 3:
			route_end_progress = [0.72, 1.0, 0.82]
		elif stage_number >= 4:
			var closed := rng.randi_range(0, 2)
			var closes_after := 0.64 if stage_number == 4 else 0.78
			route_end_progress[closed] = closes_after
		for route in 3:
			if route_end_progress[route] < 1.0:
				open_routes.erase(route)
		var bean_slots: Array = []
		if stage_number >= 4:
			for slot_index in 4:
				var blocked := rng.randi_range(0, 2)
				var safety_route := (blocked + 1 + rng.randi_range(0, 1)) % 3
				if route_end_progress[safety_route] <= 0.18 + slot_index * 0.20:
					safety_route = 1
				var safe_routes := [0, 1, 2]
				safe_routes.erase(blocked)
				bean_slots.append({"progress": 0.18 + slot_index * 0.20, "blocked_route": blocked, "safe_routes": safe_routes, "warning_seconds": Balance.BEAN_WARNING_SECONDS})
		result.append({"stage": stage_number, "entry": 1, "open_routes": open_routes, "route_end_progress": route_end_progress, "bean_slots": bean_slots})
	return result
func pattern_hash(seed_value: int) -> int: return hash(var_to_str(generate_patterns(seed_value)))
func patterns_are_reachable(candidate: Array) -> bool:
	for segment: Dictionary in candidate:
		if segment.open_routes.size() < 1: return false
		for progress: float in segment.route_end_progress:
			if progress < 0.0 or progress > 1.0: return false
	return true

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

func is_route_open_at(stage_number: int, route: int, progress: float) -> bool:
	var pattern := pattern_for_stage(stage_number)
	return progress < float(pattern.route_end_progress[route])

func current_route_open(player_y: float, x: float) -> bool:
	return is_route_open_at(stage_for_y(player_y), route_for_x(x), progress_in_stage(player_y))

func next_dead_end_distance(player_y: float, x: float) -> float:
	var stage_number := stage_for_y(player_y)
	var route := route_for_x(x)
	var pattern := pattern_for_stage(stage_number)
	var end_progress := float(pattern.route_end_progress[route])
	var progress := progress_in_stage(player_y)
	if end_progress >= 1.0 or progress >= end_progress:
		return INF if end_progress >= 1.0 else 0.0
	return (end_progress - progress) * Balance.STAGE_HEIGHT
