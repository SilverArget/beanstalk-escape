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
	Engine.time_scale = 1.0
	await test_t01_auto_climb()
	await test_t02_scale_and_trunk()
	await test_t03_transfer()
	await test_t04_support_loss()
	await test_t05_collider_and_hit()
	quit(failures)

func test_t01_auto_climb() -> void:
	var game := await make_game()
	var start_y := game.player.global_position.y
	for _tick in 120:
		await physics_frame
	var climbed := start_y - game.player.global_position.y
	check(absf(climbed - Balance.PLAYER_VERTICAL_SPEED) <= 2.0 and not InputMap.has_action("jump") and not InputMap.has_action("climb"), "T01", "ticks=120 climbed=%.3f expected=%.3f manual_actions=false" % [climbed, Balance.PLAYER_VERTICAL_SPEED])
	game.queue_free()
	await physics_frame

func test_t02_scale_and_trunk() -> void:
	var game := await make_game()
	var shape := game.player.get_node("CollisionShape2D").shape as CapsuleShape2D
	var safe_centers_ok := ScaleLock.TRUNK_SAFE_WORLD_X == [-54.0, 0.0, 54.0]
	var surface_ok := true
	for center_x: float in ScaleLock.TRUNK_SAFE_WORLD_X:
		surface_ok = surface_ok and absf(center_x) + shape.radius <= ScaleLock.TRUNK_WIDTH * 0.5 - 8.0
	check(ScaleLock.CHARACTER_HEIGHT == 108.0 and ScaleLock.TRUNK_WIDTH == 180.0 and ScaleLock.BRANCH_WIDTH == 44.0 and ScaleLock.BRANCH_CENTER_GAP == 150.0 and shape.height == 86.0 and shape.radius * 2.0 == 30.0 and safe_centers_ok and surface_ok, "T02", "char=44x108 collider=30x86 trunk=180 branch=44 centers=150 safe_x=%s" % str(ScaleLock.TRUNK_SAFE_WORLD_X))
	game.queue_free()
	await physics_frame

func test_t03_transfer() -> void:
	var game := await make_game()
	var player := game.player
	player.set_physics_process(false)
	var all_accepted := true
	var max_curve_error := 0.0
	var durations := []
	var endpoints := []
	for hz in [30.0, 60.0, 120.0]:
		player.reset_run(Vector2(0, -Balance.STAGE_HEIGHT * 2.0 - 500.0))
		player.active_branch = 1
		player.global_position.x = game.stages.branch_x_at(1, player.global_position.y)
		var start_y := player.global_position.y
		all_accepted = all_accepted and player._begin_branch_transition(1)
		var ticks := 0
		while player.support_state == PlayerController.SupportState.TRANSFERRING and ticks < 100:
			player._update_branch_movement(1.0 / hz)
			var expected := player.branch_graph.transfer_point(game.stages, 1, 2, player.transition_base_y, player.transition_progress)
			max_curve_error = maxf(max_curve_error, player.global_position.distance_to(expected))
			ticks += 1
		durations.append(float(ticks) / hz)
		endpoints.append(player.global_position)
		all_accepted = all_accepted and player.global_position.y < start_y
	var endpoint_spread := (endpoints[0] as Vector2).distance_to(endpoints[2] as Vector2)
	check(all_accepted and player.active_branch == 2 and player.support_state == PlayerController.SupportState.SUPPORTED and player.on_support and durations == [0.4, 0.4, 0.4] and max_curve_error <= 1.0 and endpoint_spread <= 1.0, "T03", "single_press=true fps=30/60/120 durations=%s branch=%d curve_error=%.3f endpoint_spread=%.3f state=%s" % [str(durations), player.active_branch, max_curve_error, endpoint_spread, player.support_state_name()])
	game.queue_free()
	await physics_frame

func test_t04_support_loss() -> void:
	var game := await make_game()
	var player := game.player
	var dead_tip_y := -Balance.STAGE_HEIGHT * 2.0 - Balance.STAGE_HEIGHT * 0.46
	player.reset_run(Vector2(Balance.ROUTE_X[2], dead_tip_y + 1.0))
	player.active_branch = 2
	player._sync_stage_mode()
	var recovery_entries := 0
	var supported_after_loss := 0
	var previous_state := player.support_state
	var recovery_start_y := 0.0
	var first_recovery_velocity := 0.0
	var recovery_elapsed := 0.0
	for _tick in 120:
		await physics_frame
		if player.support_state == PlayerController.SupportState.FALLING_RECOVERY and previous_state != PlayerController.SupportState.FALLING_RECOVERY:
			recovery_entries += 1
			recovery_start_y = player.global_position.y
			first_recovery_velocity = player.recovery_velocity_y
		if recovery_entries > 0 and player.support_state == PlayerController.SupportState.SUPPORTED:
			supported_after_loss += 1
		if recovery_entries > 0 and game.app_state == GameManager.AppState.PLAYING:
			recovery_elapsed += 1.0 / float(Engine.physics_ticks_per_second)
		previous_state = player.support_state
		if game.app_state == GameManager.AppState.PLAYER_DEAD:
			break
	var fell := player.global_position.y - recovery_start_y
	var summit_route_stays_open := game.stages.is_route_open_at(5, 2, 1.0)
	check(recovery_entries == 1 and supported_after_loss == 0 and first_recovery_velocity >= 120.0 and fell > 25.0 and recovery_elapsed >= 0.34 and recovery_elapsed <= 0.37 and game.app_state == GameManager.AppState.PLAYER_DEAD and summit_route_stays_open, "T04", "recovery_entries=%d supported_after_loss=%d initial_vy=%.3f fell=%.3f recovery_s=%.3f dead_tip_death=%s summit_open=%s" % [recovery_entries, supported_after_loss, first_recovery_velocity, fell, recovery_elapsed, GameManager.AppState.keys()[game.app_state], str(summit_route_stays_open)])
	game.queue_free()
	await physics_frame

func test_t05_collider_and_hit() -> void:
	var game := await make_game()
	var player := game.player
	player.reset_run(Vector2(0, -Balance.STAGE_HEIGHT * 2.0 - 500.0))
	player.active_branch = 1
	player.global_position.x = game.stages.branch_x_at(1, player.global_position.y)
	player._begin_branch_transition(-1)
	while player.support_state == PlayerController.SupportState.TRANSFERRING:
		await physics_frame
	var center_error := absf(player.global_position.x - game.stages.branch_x_at(0, player.global_position.y))
	var before := player.bean_penalty_count
	player.apply_bean_hit()
	var once := player.bean_penalty_count == before + 1
	check(center_error <= 1.0 and once and player.get_node("Body").position == Vector2.ZERO, "T05", "center_error=%.3f one_hit_one_penalty=%s body_reset=%s" % [center_error, str(once), str(player.get_node("Body").position == Vector2.ZERO)])
	game.queue_free()
	await physics_frame
