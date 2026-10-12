extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, name: String, detail: String) -> void:
	if condition:
		passed += 1
		print("PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("FAIL %s %s" % [name, detail])

func run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.restart()
	game.debug_sandbox = "rocks"
	game._start_debug_stage(3)
	game.rocks.start_sandbox()
	var snapshots := game.rocks.snapshot()
	var kinds: Array = snapshots.map(func(value: Dictionary): return value.kind)
	var lanes_ok: bool = snapshots[0].routes == [0] and snapshots[1].routes == [1] and snapshots[2].routes == [2] and snapshots[3].routes == [0, 1] and snapshots[4].routes == [1, 2]
	var ordered: bool = true
	for index in range(1, snapshots.size()): ordered = ordered and float(snapshots[index].anchor_y) < float(snapshots[index - 1].anchor_y)
	check(kinds == ["S", "R", "F", "WALL", "M"] and lanes_ok and ordered, "ROCK-SPAWNS", "kinds=%s lanes=%s" % [kinds, lanes_ok])

	var rolling := game.rocks.hazards[1]
	rolling.released = true
	var normal_y := rolling.position.y
	rolling.advance_threat_clock(1.0, false, game.player.global_position.y)
	var normal_distance := rolling.position.y - normal_y
	rolling._reset_position()
	rolling.released = true
	var slow_y := rolling.position.y
	rolling.advance_threat_clock(1.0, true, game.player.global_position.y)
	var slow_distance := rolling.position.y - slow_y
	var falling := game.rocks.hazards[2]
	var warning_y := falling.position.y
	falling.advance_threat_clock(0.5, true, falling.anchor_y + 1.0)
	check(is_equal_approx(slow_distance, normal_distance * 0.5) and is_equal_approx(falling.position.y, warning_y), "ROCK-TIME", "normal=%.1f slow=%.1f warning_static=%s" % [normal_distance, slow_distance, falling.position.y == warning_y])

	var fixed := game.rocks.hazards[0]
	game.rocks.hazards = [fixed]
	game.player.global_position = fixed.global_position + Vector2(0.0, 120.0)
	game.rocks.previous_player_position = fixed.global_position - Vector2(0.0, 120.0)
	game.rocks._physics_process(1.0 / 120.0)
	game.rocks._physics_process(1.0 / 120.0)
	check(game.rocks.hit_count == 1 and game.player.rock_penalty_count == 1 and is_equal_approx(game.player.knockback_remaining, Balance.ROCK_KNOCKBACK_SECONDS) and is_equal_approx(game.player.stun_remaining, Balance.ROCK_STUN_SECONDS) and game.spider.boost_start_count == 0, "ROCK-SINGLE-HIT", "hits=%d penalty=%d spider_boost=%d" % [game.rocks.hit_count, game.player.rock_penalty_count, game.spider.boost_start_count])

	game.rocks.previous_player_position = fixed.global_position - Vector2(0.0, 140.0)
	game.player.global_position = fixed.global_position + Vector2(0.0, 140.0)
	check(game.rocks._swept_contact(fixed), "FIRE-SWEPT", "crossed=280px radius=%.1f" % fixed.collision_radius())

	game.player.global_position = Vector2(0.0, -Balance.STAGE_HEIGHT * 2.0)
	game.player.reset_run(game.player.global_position)
	game.app_state = GameManager.AppState.PLAYING
	var started := game.try_fire_wings()
	var second_rejected := not game.try_fire_wings()
	game._physics_process(0.1)
	game.player.global_position.y = -Balance.STAGE_HEIGHT * 3.0 - 1.0
	game.stages.update_progress(game.player.global_position.y)
	var carried := game.player.fire_wings_active and game.fire_wings_remaining > 9.8
	game._physics_process(9.9)
	var exact_end := not game.player.fire_wings_active and game.fire_wings_remaining <= 0.0001
	var next_stage_ready := game.try_fire_wings()
	check(started and second_rejected and is_equal_approx(game.player.climb_speed(), Balance.PLAYER_VERTICAL_SPEED * Balance.FIRE_WINGS_SPEED_SCALE) and carried and exact_end and next_stage_ready, "FIRE-WINGS", "speed=%.1f duration=%.1f carried=%s next_ready=%s" % [Balance.PLAYER_VERTICAL_SPEED * Balance.FIRE_WINGS_SPEED_SCALE, Balance.FIRE_WINGS_SECONDS, carried, next_stage_ready])

	print("RESULT PASS %d / FAIL %d" % [passed, failed])
	game.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
