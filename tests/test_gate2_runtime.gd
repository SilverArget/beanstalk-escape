extends SceneTree

var failures := 0

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func make_game() -> GameManager:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await physics_frame
	game.start_game()
	game.spider.global_position = Vector2(0, 10000)
	await physics_frame
	return game

func _initialize() -> void:
	test_runtime_encounter_geometry()
	test_spider_formula_and_gauge()
	await test_spider_catch_and_retry()
	await test_bean_timeline()
	await test_time_wings_command_and_clock()
	quit(failures)

func test_runtime_encounter_geometry() -> void:
	var stages := StageManager.new()
	stages.reset_run()
	var stage_one: Dictionary = stages.pattern_for_stage(1)
	var stage_two: Dictionary = stages.pattern_for_stage(2)
	var stage_three: Dictionary = stages.pattern_for_stage(3)
	var trunk_ok: bool = stage_one.trunk_features.size() == 5 and stage_two.trunk_features.size() == 5
	trunk_ok = trunk_ok and stage_one.trunk_features[0].kind == "GUIDE" and stage_two.trunk_features[0].kind == "BULGE"
	var windows_ok: bool = stage_three.support_windows.size() == 5
	var before := 499.0 / 2800.0
	var inside := 610.0 / 2800.0
	var after := 721.0 / 2800.0
	# S03-E01 keeps L/C and visibly ends R only for A..A+220.
	windows_ok = windows_ok and stages.is_route_open_at(3, 2, before) and not stages.is_route_open_at(3, 2, inside) and stages.is_route_open_at(3, 2, after)
	windows_ok = windows_ok and stages.is_route_open_at(3, 0, inside) and stages.is_route_open_at(3, 1, inside)
	var right_segments: Array = stages.support_segments(3, 2)
	check(trunk_ok and windows_ok and right_segments.size() >= 2, "G2-RUNTIME-01", "trunk=%s windows=%s right_segments=%s" % [str(trunk_ok), str(windows_ok), str(right_segments)])
	stages.free()

func test_spider_formula_and_gauge() -> void:
	var profiles_ok := SpiderController.pressure_profile(1) == {"g_lo": 180.0, "pressure": 0.0}
	profiles_ok = profiles_ok and SpiderController.pressure_profile(20) == {"g_lo": 180.0, "pressure": 12.0}
	profiles_ok = profiles_ok and SpiderController.pressure_profile(25) == {"g_lo": 156.0, "pressure": 12.0}
	profiles_ok = profiles_ok and SpiderController.pressure_profile(29) == {"g_lo": 108.0, "pressure": 12.0}
	profiles_ok = profiles_ok and SpiderController.pressure_profile(30) == {"g_lo": 156.0, "pressure": 12.0}
	var base_speed := SpiderController.speed_for_state(288.0, 1, 0.0, false, false)
	var pressure_speed := SpiderController.speed_for_state(234.0, 20, 0.0, false, false)
	var bean_speed := SpiderController.speed_for_state(180.0, 1, 0.0, true, false)
	var time_speed := SpiderController.speed_for_state(180.0, 1, 0.0, false, true)
	var catchup_on := SpiderController.catchup_state(420.0, false, 0.0, 0.25)
	var catchup_held := SpiderController.catchup_state(380.0, true, float(catchup_on.blend), 0.25)
	var catchup_off := SpiderController.catchup_state(365.0, true, 1.0, 0.01)
	var catchup_ok: bool = catchup_on.active and absf(float(catchup_on.blend) - 0.5) < 0.001 and catchup_held.active and is_equal_approx(float(catchup_held.blend), 1.0) and not catchup_off.active and is_zero_approx(float(catchup_off.blend))
	catchup_ok = catchup_ok and SpiderController.speed_for_state(900.0, 1, 1.0, false, true) >= 200.0
	var gauge_ok := SpiderDistanceGauge.level_for_gap(240.0) == "GREEN" and SpiderDistanceGauge.level_for_gap(239.9) == "YELLOW"
	gauge_ok = gauge_ok and SpiderDistanceGauge.level_for_gap(180.0) == "YELLOW" and SpiderDistanceGauge.level_for_gap(179.9) == "ORANGE"
	gauge_ok = gauge_ok and SpiderDistanceGauge.level_for_gap(96.0) == "ORANGE" and SpiderDistanceGauge.level_for_gap(95.9) == "RED"
	gauge_ok = gauge_ok and SpiderDistanceGauge.level_for_gap(56.0) == "RED" and SpiderDistanceGauge.level_for_gap(55.9) == "DANGER"
	check(profiles_ok and is_equal_approx(base_speed, 100.0) and absf(pressure_speed - 100.0) < 0.01 and absf(bean_speed - 101.2) < 0.01 and absf(time_speed - 44.0) < 0.01 and gauge_ok and catchup_ok, "T06", "profiles=%s speeds=%.2f/%.2f/%.2f/%.2f gauge=%s catchup=%s" % [str(profiles_ok), base_speed, pressure_speed, bean_speed, time_speed, str(gauge_ok), str(catchup_ok)])

func test_spider_catch_and_retry() -> void:
	var game := await make_game()
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.player.global_position = Vector2(Balance.ROUTE_X[0], -1000.0)
	game.spider.global_position = Vector2(0.0, -972.0)
	game.gauge.update_from_positions(game.player.global_position.y, game.spider.global_position.y)
	var left_catch := game._spider_can_catch()
	game.player.global_position.x = ScaleLock.BRANCH_CENTER_GAP + ScaleLock.BRANCH_WIDTH * 0.5 + 1.0
	var outside_claw := not game._spider_can_catch()
	game.stages.current_stage = 1
	game.restart_stage()
	var retry_ok := is_equal_approx(game.stage_restart_start_distance, 240.0) and SpiderController.retry_gap_for_stage(24) == 240.0 and SpiderController.retry_gap_for_stage(25) == 180.0
	check(left_catch and outside_claw and retry_ok, "T06-catch", "left=%s outside=%s retry=%.1f future25=%.1f" % [str(left_catch), str(outside_claw), game.stage_restart_start_distance, SpiderController.retry_gap_for_stage(25)])
	game.queue_free()
	await physics_frame

func test_bean_timeline() -> void:
	var game := await make_game()
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	var slot: Dictionary = game.stages.pattern_for_stage(4).bean_slots[0]
	var warning_y := -(3.0 * Balance.STAGE_HEIGHT + float(slot.warning_height))
	game.player.global_position = Vector2(Balance.ROUTE_X[0], warning_y)
	game.beans._physics_process(0.0)
	game.audio._process(0.0)
	var bean := get_first_node_in_group("beans") as BeanProjectile
	var warning_ok: bool = bean != null and bean.get_node("Warning").visible and not bean.falling and game.audio.played_roles.has("bean_warning_creak")
	if bean != null:
		bean.advance_threat_clock(1.59, false)
	var held_before_minimum: bool = bean != null and not bean.falling
	game.player.global_position.y = -(3.0 * Balance.STAGE_HEIGHT + float(slot.anchor))
	game.beans._physics_process(0.0)
	var still_waiting: bool = bean != null and not bean.falling
	if bean != null:
		bean.advance_threat_clock(0.01, false)
		game.beans._physics_process(0.0)
	var released: bool = bean != null and bean.falling and bean.warning_visible_seconds >= Balance.BEAN_WARNING_SECONDS
	if bean != null:
		game.beans.force_contact(bean)
		game.beans.force_contact(bean)
	var one_penalty: bool = game.beans.hit_count == 1 and game.player.bean_penalty_count == 1 and game.spider.boost_start_count == 1 and is_equal_approx(game.spider.boost_remaining, 2.0)
	game.spider.apply_bean_boost()
	game.spider.advance_active_clocks(1.99)
	var boost_timeline: bool = game.spider.boost_remaining > 0.0 and game.spider.boost_start_count == 2
	game.spider.advance_active_clocks(0.01)
	boost_timeline = boost_timeline and game.spider.boost_remaining <= 0.0001
	check(warning_ok and held_before_minimum and still_waiting and released and one_penalty and boost_timeline, "T07", "warning=%s held=%s release=%s visible=%.2f one_penalty=%s boost2s=%s sound=%s" % [str(warning_ok), str(held_before_minimum and still_waiting), str(released), bean.warning_visible_seconds if bean != null else -1.0, str(one_penalty), str(boost_timeline), str(game.audio.played_roles.has("bean_warning_creak"))])
	game.queue_free()
	await physics_frame

func test_time_wings_command_and_clock() -> void:
	var game := await make_game()
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	game.player.global_position = Vector2(0, -4.0 * Balance.STAGE_HEIGHT - 10.0)
	var keyboard_ok: bool = game.dispatch_command("time_wings", "keyboard")
	var player_y := game.player.global_position.y
	for _tick in 600:
		game._physics_process(1.0 / 120.0)
	var halfway := game.time_wings_remaining
	game._pause_game()
	for _tick in 120:
		game._physics_process(1.0 / 120.0)
	var pause_frozen: bool = is_equal_approx(game.time_wings_remaining, halfway)
	game._resume_game()
	for _tick in 600:
		game._physics_process(1.0 / 120.0)
	var exact_clock: bool = game.time_wings_remaining <= 0.0001 and not game.player.time_wings_active
	var player_unchanged: bool = is_equal_approx(game.player.global_position.y, player_y)
	game.time_wings_used_stage.erase(5)
	var mobile_ok: bool = game.dispatch_command("time_wings", "mobile") and game.last_time_command_source == "mobile"
	var slow_bean := (load("res://scenes/bean_projectile.tscn") as PackedScene).instantiate() as BeanProjectile
	root.add_child(slow_bean)
	slow_bean.setup(1, -1000.0)
	slow_bean.falling = true
	var bean_start_y := slow_bean.position.y
	slow_bean.advance_threat_clock(1.0, true)
	var threats_only: bool = absf(slow_bean.position.y - bean_start_y - 110.0) < 0.01
	check(keyboard_ok and mobile_ok and absf(halfway - 5.0) < 0.001 and pause_frozen and exact_clock and player_unchanged and threats_only and Engine.time_scale == 1.0, "T10/T12", "keyboard=%s mobile=%s halfway=%.3f pause=%s exact=%s player_same=%s bean_slow=%s global_scale=%.1f" % [str(keyboard_ok), str(mobile_ok), halfway, str(pause_frozen), str(exact_clock), str(player_unchanged), str(threats_only), Engine.time_scale])
	slow_bean.queue_free()
	game.queue_free()
	await physics_frame
