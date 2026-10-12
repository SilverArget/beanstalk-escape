extends SceneTree

const PHYSICS_HZ := 120
const ROCK_STAGES := [6, 12, 22, 28]

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String, detail: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s - %s" % [label, detail])
	else:
		failed += 1
		print("FAIL: %s - %s" % [label, detail])

func _new_game() -> GameManager:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.restart()
	return game

func _run() -> void:
	var early_game := await _new_game()
	for stage_number in range(1, 6):
		var bean_count: int = early_game.stages.pattern_for_stage(stage_number).bean_slots.size()
		_check(bean_count > 0, "EARLY-BEANS-S%02d" % stage_number, "bean_slots=%d" % bean_count)
	var caught_tick := -1
	var left_stage_one := false
	for tick in 40 * PHYSICS_HZ:
		await physics_frame
		if early_game.app_state == GameManager.AppState.PLAYER_DEAD:
			caught_tick = tick + 1
			break
		if early_game.stages.stage_for_y(early_game.player.global_position.y) != 1:
			left_stage_one = true
			break
	var caught_seconds := float(caught_tick) / PHYSICS_HZ if caught_tick > 0 else -1.0
	_check(
		caught_tick > 0 and not left_stage_one and early_game.beans.hit_count > 0,
		"IDLE-STAGE-1-CAUGHT",
		"caught_seconds=%.2f bean_hits=%d stage=%d" % [caught_seconds, early_game.beans.hit_count, early_game.stages.stage_for_y(early_game.player.global_position.y)]
	)
	early_game.queue_free()
	await process_frame

	for stage_number in ROCK_STAGES:
		var game := await _new_game()
		game._start_debug_stage(stage_number)
		var first_slot: Dictionary = game.stages.pattern_for_stage(stage_number).rock_slots[0]
		var hit_route := int(first_slot.routes[0])
		game.player.global_position.x = float(Balance.ROUTE_X[hit_route])
		game.player.active_branch = hit_route
		game.rocks.sync_after_player_teleport()
		var start_gap := game.spider.distance_to_player()
		var hit_tick := -1
		for tick in 10 * PHYSICS_HZ:
			await physics_frame
			if game.rocks.hit_count > 0:
				hit_tick = tick + 1
				break
		var minimum_gap := game.spider.distance_to_player()
		if hit_tick > 0:
			game.rocks.set_physics_process(false)
			game.beans.set_physics_process(false)
			game.storm.set_physics_process(false)
			while game.player.knockback_remaining > 0.0 or game.player.stun_remaining > 0.0:
				await physics_frame
				minimum_gap = minf(minimum_gap, game.spider.distance_to_player())
			for tick in 5 * PHYSICS_HZ:
				await physics_frame
				minimum_gap = minf(minimum_gap, game.spider.distance_to_player())
		var final_gap := game.spider.distance_to_player()
		_check(
			hit_tick > 0 and minimum_gap >= 56.0 and final_gap > minimum_gap,
			"STAGE-START-K1-S%02d" % stage_number,
			"start=%.1f hit_seconds=%.2f min=%.1f final=%.1f hits=%d" % [start_gap, float(hit_tick) / PHYSICS_HZ if hit_tick > 0 else -1.0, minimum_gap, final_gap, game.rocks.hit_count]
		)
		game.queue_free()
		await process_frame

	print("EARLY-BEANS-STAGE-START-K1: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
