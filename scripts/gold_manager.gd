class_name GoldManager
extends Node2D

var player: PlayerController
var stages: StageManager
var economy: EconomyManager
var audio: BeanstalkAudio
var collected_ids: Dictionary = {}

func setup(target: PlayerController, stage_manager: StageManager, economy_manager: EconomyManager, audio_manager: BeanstalkAudio) -> void:
	player = target
	stages = stage_manager
	economy = economy_manager
	audio = audio_manager

func reset_run() -> void:
	for child in get_children():
		child.free()
	collected_ids.clear()
	for stage_number in range(1, Balance.STAGE_COUNT + 1):
		var count := economy.stage_gold_count(stage_number)
		for placement: Dictionary in GoldPlacementData.placements_for_stage(stage_number, count, stages):
			_spawn(placement)

func _spawn(placement: Dictionary) -> void:
	var coin := GoldCollectible.new()
	coin.name = String(placement.id)
	coin.position = placement.position
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
