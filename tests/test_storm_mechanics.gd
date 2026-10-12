extends SceneTree

var failures := 0
var game: GameManager
var storm: StormMechanics

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await physics_frame
	game.app_state = GameManager.AppState.PLAYING
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	storm = game.storm
	storm.set_physics_process(false)
	storm.configure_sandbox(3)
	test_wind_contract()
	test_break_contract()
	test_web_contract()
	test_triple_bean_contract()
	game.queue_free()
	await physics_frame
	quit(failures)

func place_player(lane: int, climbed: float) -> void:
	game.player.global_position = Vector2(Balance.ROUTE_X[lane], storm.stage_bottom_y - climbed)
	game.player.active_branch = lane
	game.player.movement_mode = PlayerController.MovementMode.ATTACHED
	game.player.support_state = PlayerController.SupportState.SUPPORTED
	game.player.on_support = true

func test_wind_contract() -> void:
	var offset := 0.0
	var speed := 0.0
	var mid_y := storm.stage_bottom_y - (float(storm.wind.anchor) + 110.0)
	for _tick in 600:
		var step := storm.step_support_wind(offset, speed, mid_y, 1.0 / 120.0, false)
		offset = step.x
		speed = step.y
	var bounded := offset <= StormMechanics.SUPPORT_OFFSET_LIMIT + 0.001 and speed <= StormMechanics.WIND_MAX_OFFSET_SPEED + 0.001
	var full_force := storm.wind_force_at(mid_y, false)
	var time_force := storm.wind_force_at(mid_y, true)
	var transfer := storm.step_transfer_wind(7.9, 24.0, mid_y, 1.0, false)
	var transfer_bounded := absf(transfer.x) <= StormMechanics.TRANSFER_OFFSET_LIMIT and is_zero_approx(transfer.y)
	check(bounded and transfer_bounded and is_equal_approx(time_force, full_force * 0.5) and game.death_cause == GameManager.DeathCause.NONE, "STORM-WIND", "offset=%.3f speed=%.3f transfer=%.3f force=%.1f/%.1f death=%s" % [offset, speed, transfer.x, full_force, time_force, GameManager.DeathCause.keys()[game.death_cause]])

func test_break_contract() -> void:
	storm.reset_run()
	place_player(int(storm.breakable.lane), float(storm.breakable.anchor) + 40.0)
	storm._update_breakable(1.59, storm.stage_bottom_y - game.player.global_position.y)
	var held := bool(storm.breakable.touched) and not bool(storm.breakable.broken)
	storm._update_breakable(0.01, storm.stage_bottom_y - game.player.global_position.y)
	var broke := bool(storm.breakable.broken)
	var support_gone := not game.stages.has_route_support_at(storm.stage_number, int(storm.breakable.lane), (float(storm.breakable.anchor) + 40.0) / Balance.STAGE_HEIGHT)
	game.player._update_branch_movement(0.0)
	var recovery := game.player.support_state == PlayerController.SupportState.FALLING_RECOVERY
	storm.reset_run()
	place_player(int(storm.breakable.lane), float(storm.breakable.anchor) + 40.0)
	game.player.time_wings_active = true
	storm._update_breakable(1.60, storm.stage_bottom_y - game.player.global_position.y)
	var time_half := is_equal_approx(float(storm.breakable.clock), 0.80) and not bool(storm.breakable.broken)
	storm._update_breakable(1.60, storm.stage_bottom_y - game.player.global_position.y)
	check(held and broke and support_gone and recovery and time_half and bool(storm.breakable.broken), "STORM-BREAK", "held=%s broke=%s support_gone=%s recovery=%s time_half=%s" % [str(held), str(broke), str(support_gone), str(recovery), str(time_half)])
	game.player.time_wings_active = false

func test_web_contract() -> void:
	storm.reset_run()
	place_player(1, float(storm.web.anchor))
	storm._update_web(0.0, float(storm.web.anchor))
	var active := bool(storm.web.active)
	var entry_rejected := not game.player.branch_graph.can_transfer(game.stages, 1, int(storm.web.lane), game.player.global_position.y)
	storm._update_web(1.99, float(storm.web.anchor) + 1.0)
	var held := bool(storm.web.active)
	storm._update_web(0.01, float(storm.web.anchor) + 1.0)
	var expired := not bool(storm.web.active) and game.stages.can_enter_route_at(storm.stage_number, int(storm.web.lane), (float(storm.web.anchor) + 1.0) / Balance.STAGE_HEIGHT)
	storm.reset_run()
	place_player(1, float(storm.web.anchor))
	game.player.time_wings_active = true
	storm._update_web(0.0, float(storm.web.anchor))
	storm._update_web(2.0, float(storm.web.anchor) + 1.0)
	var time_half := bool(storm.web.active) and is_equal_approx(float(storm.web.clock), 1.0)
	storm._update_web(2.0, float(storm.web.anchor) + 1.0)
	check(active and entry_rejected and held and expired and time_half and not bool(storm.web.active), "STORM-WEB", "entry_rejected=%s normal_2s=%s time_clock=%.2f" % [str(entry_rejected), str(expired), float(storm.web.clock)])
	game.player.time_wings_active = false

func test_triple_bean_contract() -> void:
	game.beans.reset_run()
	storm.reset_run()
	storm._update_rain(float(storm.rain.anchor) - 360.0)
	var three: bool = (storm.rain.beans as Array).size() == 3 and game.beans.warning_count == 3
	var spacing_ok := true
	for index in 3:
		var bean := storm.rain.beans[index] as BeanProjectile
		var expected_y := storm.stage_bottom_y - (float(storm.rain.anchor) + float(index) * 50.0) - 120.0
		spacing_ok = spacing_ok and is_equal_approx(bean.landing_y, expected_y)
		storm._update_rain(float(storm.rain.anchor) + float(index) * 50.0)
	var released := not (storm.rain.released as Array).has(false)
	check(three and spacing_ok and released, "STORM-BEAN-RAIN", "count=%d spacing=%s released=%s" % [storm.rain.beans.size(), str(spacing_ok), str(storm.rain.released)])
