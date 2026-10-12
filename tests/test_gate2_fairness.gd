extends SceneTree

var failures := 0

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func make_game(variant: String) -> GameManager:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await physics_frame
	game.stages.run_variant = variant
	game.start_game()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	game.audio.set_process(false)
	return game

func _initialize() -> void:
	test_deterministic_anti_cheese()
	test_random_experiment()
	test_pressure_safety()
	await test_reachability_and_replay()
	await test_audio_ring_and_pause()
	quit(failures)

func test_deterministic_anti_cheese() -> void:
	var failures_found := []
	for variant in StageDatabase.QA_VARIANTS:
		for agent in AntiCheeseHarness.DETERMINISTIC_AGENTS:
			var result := AntiCheeseHarness.run_deterministic(String(agent), String(variant), 5)
			if bool(result.completed):
				failures_found.append("%s:%s" % [variant, agent])
	check(failures_found.is_empty(), "T14-deterministic", "runs=10 completed=%s" % str(failures_found))
	var no_input := AntiCheeseHarness.run_deterministic("no_input", StageDatabase.CANONICAL_VARIANT, 1)
	var stopped_in_stage_1: bool = not bool(no_input.completed) and int(no_input.failed_stage) == 1 and float(no_input.hit_seconds) > 3.0
	check(stopped_in_stage_1, "T14-no-input-stage1", "encounter=%s hit_seconds=%.3f completed=%s" % [no_input.encounter, no_input.hit_seconds, str(no_input.completed)])

func test_random_experiment() -> void:
	var experiment := AntiCheeseHarness.run_random_experiment(1500, 5)
	var count_ok: bool = int(experiment.attempts) == 3000 and int(experiment.variants.size()) == 2
	var bounds_ok: bool = float(experiment.rate) >= 0.0 and float(experiment.upper_95) >= float(experiment.rate) and float(experiment.upper_95) <= 1.0
	check(count_ok and bounds_ok, "T14-random-partial", "stage1-5 attempts=%d wins=%d rate=%.6f cp95_upper=%.6f acceptance_30_stage=NOT_RUN" % [experiment.attempts, experiment.wins, experiment.rate, experiment.upper_95])

func test_pressure_safety() -> void:
	var equations := SpiderController.pressure_equilibrium_table()
	var equations_ok: bool = equations == [288.0, 261.0, 234.0, 210.0, 162.0, 210.0]
	var k1 := SpiderController.simulate_bean_penalty_safety(1)
	var k1_ok: bool = float(k1.minimum_gap) >= 56.0 and float(k1.final_gap) > float(k1.post_penalty_gap)
	check(equations_ok and k1_ok, "T06-K1", "equilibria=%s min=%.3f post=%.3f final=%.3f" % [str(equations), k1.minimum_gap, k1.post_penalty_gap, k1.final_gap])

func test_reachability_and_replay() -> void:
	for variant in StageDatabase.QA_VARIANTS:
		var solution := ReachabilityValidator.solve_stages_1_to_5(String(variant))
		var tempo_ok: bool = bool(solution.valid) and float(solution.minimum_reaction_seconds) >= 0.35 and float(solution.minimum_command_gap_seconds) >= 0.15 and is_equal_approx(float(solution.transfer_seconds), 0.40)
		var first_game := await make_game(String(variant))
		var baseline := ReplayVerifier.run_stages_1_to_5(first_game, solution.commands)
		first_game.queue_free()
		await physics_frame
		var second_game := await make_game(String(variant))
		var verified := ReplayVerifier.run_stages_1_to_5(second_game, solution.commands, baseline.hashes)
		var damage_free: bool = int(baseline.bean_hits) == 0 and int(verified.bean_hits) == 0
		var replay_ok: bool = bool(baseline.completed) and damage_free and bool(verified.hashes_match) and bool(verified.completed)
		check(tempo_ok and replay_ok, "T15-%s" % variant, "commands=%d hashes=%d match=%s hits=%d min_gap=%.3f completed=%s death=%s final=%s/%s y=%.2f support=%s" % [solution.commands.size(), baseline.hashes.size(), str(verified.hashes_match), verified.bean_hits, verified.minimum_gap, str(verified.completed), baseline.death_cause, baseline.final_stage, baseline.final_route, baseline.final_y, baseline.support_state])
		check(damage_free and float(baseline.minimum_gap) >= 120.0, "T06-K2-%s" % variant, "damage_free=%s minimum_gap=%.3f skills=false" % [str(damage_free), baseline.minimum_gap])
		second_game.queue_free()
		await physics_frame

func test_audio_ring_and_pause() -> void:
	var game := await make_game(StageDatabase.CANONICAL_VARIANT)
	for index in BeanstalkAudio.EVENT_RING_CAPACITY + 3:
		game.audio.play_sfx("bean_warning_creak")
	var events := game.audio.audio_event_snapshot()
	var ring_ok: bool = events.size() == BeanstalkAudio.EVENT_RING_CAPACITY and events[-1].event == "bean_warning_creak" and events[-1].has("t")
	game.player.global_position.y = -4.0 * Balance.STAGE_HEIGHT - 10.0
	var started := game.dispatch_command("time_wings", "test")
	game._physics_process(1.0)
	var before_pause := game.time_wings_remaining
	game._pause_game()
	for _tick in 240:
		game._physics_process(1.0 / 120.0)
	var pause_ok: bool = started and is_equal_approx(game.time_wings_remaining, before_pause)
	var snapshot := game._readonly_state_snapshot()
	var readonly_ok: bool = snapshot.has("audio_events") and snapshot.audio_events.size() == BeanstalkAudio.EVENT_RING_CAPACITY and not snapshot.has("set_audio_events")
	check(ring_ok and pause_ok and readonly_ok, "T07-audio/T10-pause", "ring=%d last=%s wings=%.3f frozen=%s readonly=%s" % [events.size(), events[-1].event, before_pause, str(pause_ok), str(readonly_ok)])
	game.queue_free()
	await physics_frame
