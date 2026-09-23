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

func _ready() -> void: patterns = generate_patterns(run_seed)
func update_progress(player_y: float) -> void:
	var reached := mini(int(floor(-player_y / Balance.STAGE_HEIGHT)), Balance.STAGE_COUNT)
	while current_stage <= reached and current_stage <= Balance.STAGE_COUNT:
		_complete_stage(current_stage)
		current_stage += 1
func _complete_stage(stage_number: int) -> void:
	if completed_stages.has(stage_number): return
	completed_stages[stage_number] = true
	completion_count += 1
	stage_completed.emit(stage_number)
	if stage_number == Balance.STAGE_COUNT: prototype_completed.emit()
func reset_run() -> void:
	current_stage = 1
	completion_count = 0
	completed_stages.clear()
	patterns = generate_patterns(run_seed)
func generate_patterns(seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array = []
	var reachable := [1]
	for stage_index in Balance.STAGE_COUNT:
		var exits: Array = [1] if stage_index == 0 else [rng.randi_range(0, 2)]
		if stage_index > 0 and rng.randi_range(0, 1) == 1: exits.append((exits[0] + 1) % 3)
		var entry: int = reachable[rng.randi_range(0, reachable.size() - 1)]
		result.append({"stage": stage_index + 1, "entry": entry, "open_routes": exits, "bean_slots": []})
		reachable = exits
	return result
func pattern_hash(seed_value: int) -> int: return hash(var_to_str(generate_patterns(seed_value)))
func patterns_are_reachable(candidate: Array) -> bool:
	var reachable := [1]
	for segment: Dictionary in candidate:
		if not reachable.has(segment.entry): return false
		reachable = segment.open_routes
	return true
