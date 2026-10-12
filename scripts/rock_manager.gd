class_name RockManager
extends Node2D

var player: PlayerController
var stages: StageManager
var hazards: Array[RockHazard] = []
var sandbox_active := false
var hit_count := 0
var invulnerability_remaining := 0.0
var hit_ids: Dictionary = {}
var warning_ids: Dictionary = {}
var previous_player_position := Vector2.ZERO
var campaign_slots_by_stage: Dictionary = {}
var loaded_stages: Dictionary = {}
var active_center_stage := -1

func setup(target: PlayerController, stage_manager: StageManager) -> void:
	player = target
	stages = stage_manager
	previous_player_position = player.global_position

func start_sandbox() -> void:
	reset_run()
	_clear_active_hazards()
	sandbox_active = true
	var base_y := stages.stage_bottom_y(3)
	_spawn("rocks-s", "S", [0], base_y - 500.0)
	_spawn("rocks-r", "R", [1], base_y - 930.0)
	_spawn("rocks-f", "F", [2], base_y - 1360.0)
	_spawn("rocks-wall", "WALL", [0, 1], base_y - 1790.0)
	_spawn("rocks-m", "M", [1, 2], base_y - 2220.0)

func reset_run() -> void:
	_clear_active_hazards()
	sandbox_active = false
	hit_count = 0
	hit_ids.clear()
	warning_ids.clear()
	invulnerability_remaining = 0.0
	if player != null: previous_player_position = player.global_position
	_build_campaign_catalog()
	refresh_active_window(true)

func _clear_active_hazards() -> void:
	for hazard in hazards:
		if is_instance_valid(hazard): hazard.queue_free()
	hazards.clear()
	loaded_stages.clear()
	active_center_stage = -1

func _build_campaign_catalog() -> void:
	campaign_slots_by_stage.clear()
	if stages == null:
		return
	for pattern: Dictionary in stages.patterns:
		var stage_slots: Array = []
		for slot: Dictionary in pattern.get("rock_slots", []):
			var descriptor := slot.duplicate(true)
			descriptor["anchor_y"] = stages.stage_bottom_y(int(pattern.stage)) - float(slot.anchor)
			stage_slots.append(descriptor)
		campaign_slots_by_stage[int(pattern.stage)] = stage_slots

func refresh_active_window(force := false) -> void:
	if sandbox_active or player == null or stages == null:
		return
	var center_stage := stages.stage_for_y(player.global_position.y)
	if not force and center_stage == active_center_stage:
		return
	active_center_stage = center_stage
	var wanted: Dictionary = {}
	for stage_number in range(maxi(1, center_stage - 1), mini(Balance.STAGE_COUNT, center_stage + 1) + 1):
		wanted[stage_number] = true
	for stage_value in loaded_stages.keys():
		var loaded_stage := int(stage_value)
		if wanted.has(loaded_stage):
			continue
		for index in range(hazards.size() - 1, -1, -1):
			var hazard := hazards[index]
			if int(hazard.get_meta("campaign_stage", -1)) == loaded_stage:
				hazards.remove_at(index)
				if is_instance_valid(hazard): hazard.queue_free()
		loaded_stages.erase(loaded_stage)
	for stage_value in wanted.keys():
		var stage_number := int(stage_value)
		if loaded_stages.has(stage_number):
			continue
		for descriptor: Dictionary in campaign_slots_by_stage.get(stage_number, []):
			var hazard := _spawn(String(descriptor.id), String(descriptor.kind), descriptor.routes, float(descriptor.anchor_y))
			hazard.set_meta("campaign_stage", stage_number)
		loaded_stages[stage_number] = true

func _spawn(id: String, kind: String, routes: Array, anchor_y: float) -> RockHazard:
	var hazard := RockHazard.new()
	hazard.add_to_group("rocks")
	hazard.add_to_group("run_transient")
	add_child(hazard)
	hazard.setup(id, kind, routes, anchor_y, stages)
	hazards.append(hazard)
	return hazard

func _physics_process(delta: float) -> void:
	var game := get_parent() as GameManager
	if player == null or game == null or game.app_state != GameManager.AppState.PLAYING:
		return
	refresh_active_window()
	invulnerability_remaining = maxf(invulnerability_remaining - delta, 0.0)
	for hazard in hazards:
		if player.global_position.y <= hazard.anchor_y + 360.0 and not warning_ids.has(hazard.hazard_id):
			warning_ids[hazard.hazard_id] = true
			var audio := get_parent().get_node_or_null("Audio") as BeanstalkAudio
			if audio != null: audio.play_sfx("bean_warning_creak")
		hazard.advance_threat_clock(delta, player.time_wings_active, player.global_position.y)
		if _swept_contact(hazard) and invulnerability_remaining <= 0.0 and not hit_ids.has(hazard.hazard_id):
			hit_ids[hazard.hazard_id] = true
			invulnerability_remaining = Balance.ROCK_INVULNERABILITY_SECONDS
			hit_count += 1
			player.apply_rock_hit(hazard.hazard_id)
	previous_player_position = player.global_position

func _swept_contact(hazard: RockHazard) -> bool:
	var radius := hazard.collision_radius() + ScaleLock.COLLIDER_WIDTH * 0.5
	for center in hazard.collision_centers():
		var previous_center := center + (hazard.previous_position - hazard.global_position)
		var relative_start := previous_center - previous_player_position
		var relative_end := center - player.global_position
		if _segment_distance_to_origin(relative_start, relative_end) <= radius:
			return true
	return false

static func _segment_distance_to_origin(start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.000001:
		return start.length()
	var t := clampf(-start.dot(segment) / segment.length_squared(), 0.0, 1.0)
	return (start + segment * t).length()

func snapshot() -> Array:
	var result := []
	for hazard in hazards: result.append(hazard.snapshot())
	return result
