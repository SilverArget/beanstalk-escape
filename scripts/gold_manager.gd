class_name GoldManager
extends Node2D

var player: PlayerController
var stages: StageManager
var economy: EconomyManager
var audio: BeanstalkAudio
var collected_ids: Dictionary = {}
var placements_by_stage: Dictionary = {}
var loaded_stages: Dictionary = {}
var active_center_stage := -1

func setup(target: PlayerController, stage_manager: StageManager, economy_manager: EconomyManager, audio_manager: BeanstalkAudio) -> void:
	player = target
	stages = stage_manager
	economy = economy_manager
	audio = audio_manager

func reset_run() -> void:
	for child in get_children():
		child.free()
	collected_ids.clear()
	placements_by_stage.clear()
	loaded_stages.clear()
	active_center_stage = -1
	for stage_number in range(1, Balance.STAGE_COUNT + 1):
		var count := economy.stage_gold_count(stage_number)
		placements_by_stage[stage_number] = GoldPlacementData.placements_for_stage(stage_number, count, stages)
	refresh_active_window(true)

func _physics_process(_delta: float) -> void:
	if player == null or stages == null:
		return
	var game := get_parent() as GameManager
	if game != null and game.app_state == GameManager.AppState.PLAYING:
		refresh_active_window()

func refresh_active_window(force := false) -> void:
	if player == null or stages == null:
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
		for child in get_children():
			if int(child.get_meta("campaign_stage", -1)) == loaded_stage:
				child.queue_free()
		loaded_stages.erase(loaded_stage)
	for stage_value in wanted.keys():
		var stage_number := int(stage_value)
		if loaded_stages.has(stage_number):
			continue
		for placement: Dictionary in placements_by_stage.get(stage_number, []):
			if not collected_ids.has(String(placement.id)):
				_spawn(placement, stage_number)
		loaded_stages[stage_number] = true

func _spawn(placement: Dictionary, stage_number: int) -> void:
	var coin := GoldCollectible.new()
	coin.name = String(placement.id)
	coin.position = placement.position
	coin.set_meta("campaign_stage", stage_number)
	coin.setup(String(placement.id), player)
	coin.collected.connect(_on_collected)
	add_child(coin)

func _on_collected(placement_id: String) -> void:
	if collected_ids.has(placement_id):
		return
	collected_ids[placement_id] = true
	economy.collect_gold()
	audio.play_sfx("gold_pickup")

func active_feedback_snapshot() -> Array:
	var result := []
	for child in get_children():
		if child is GoldCollectible and child.sparkle_remaining > 0.0:
			result.append(child.feedback_snapshot())
	return result
