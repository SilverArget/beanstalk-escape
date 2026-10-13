extends SceneTree

const DT := 1.0 / 60.0
const POSITION_EPSILON := 1.0
const MAX_REASONABLE_SPEED := 1000.0

var failures := 0
var checks := 0

func check(ok: bool, id: String, detail: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func _initialize() -> void:
	Engine.physics_ticks_per_second = 60
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await physics_frame
	game.restart()
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	game.rocks.set_physics_process(false)
	game.storm.set_physics_process(false)

	var right_result := _measure_branch_follow(game, 1)
	check(bool(right_result.ok), "STAGE3-RIGHT", str(right_result))
	var left_result := _measure_branch_follow(game, -1)
	check(bool(left_result.ok), "STAGE3-LEFT", str(left_result))

	var trunk_y := -Balance.STAGE_HEIGHT * 0.5
	game.player.reset_run(Vector2(-Balance.TRUNK_HALF_WIDTH, trunk_y))
	game.spider.reset_run(Vector2(0.0, trunk_y + Balance.START_DISTANCE))
	var reset_aligned := is_equal_approx(game.spider.global_position.x, game.player.global_position.x)
	game.player.global_position.x = Balance.TRUNK_HALF_WIDTH
	var trunk_start_x := game.spider.global_position.x
	var trunk_max_step := 0.0
	for _tick in 30:
		var before_x := game.spider.global_position.x
		game.spider._physics_process(DT)
		trunk_max_step = maxf(trunk_max_step, absf(game.spider.global_position.x - before_x))
	var trunk_ok := reset_aligned \
		and game.spider.global_position.x > trunk_start_x \
		and absf(game.spider.target_x - game.player.global_position.x) <= POSITION_EPSILON \
		and trunk_max_step <= MAX_REASONABLE_SPEED * DT + 0.01
	check(trunk_ok, "STAGE1-TRUNK", "reset=%s start=%.2f end=%.2f target=%.2f max_step=%.3f" % [str(reset_aligned), trunk_start_x, game.spider.global_position.x, game.spider.target_x, trunk_max_step])

	var snapshot := game._readonly_state_snapshot()
	var snapshot_ok: bool = snapshot.spider.has("x") and snapshot.spider.has("target_x")
	check(snapshot_ok, "SNAPSHOT", str(snapshot.spider))

	game.queue_free()
	await physics_frame
	print("RESULT passed=%d failed=%d" % [checks - failures, failures])
	quit(failures)

func _measure_branch_follow(game: GameManager, direction: int) -> Dictionary:
	var player := game.player
	var spider := game.spider
	var stage_y := -Balance.STAGE_HEIGHT * 2.0 - 400.0
	var start_branch := 1
	player.reset_run(Vector2(Balance.ROUTE_X[start_branch], stage_y))
	player.active_branch = start_branch
	player.transition_from = start_branch
	player.transition_to = start_branch
	player.global_position.x = Balance.ROUTE_X[start_branch]
	spider.reset_run(Vector2(0.0, stage_y + Balance.START_DISTANCE))
	var start_x := spider.global_position.x
	var vertical_speed := SpiderController.speed_for_state(Balance.START_DISTANCE, 3, 0.0, false, false)
	var accepted := player._begin_branch_transition(direction)
	var first_motion_time := -1.0
	var transition_end_time := -1.0
	var arrival_time := -1.0
	var max_step := 0.0
	for tick in 90:
		if player.movement_mode == PlayerController.MovementMode.TRANSITION:
			player._update_branch_movement(DT)
		elif transition_end_time < 0.0:
			transition_end_time = tick * DT
		var before_x := spider.global_position.x
		spider._physics_process(DT)
		var step := absf(spider.global_position.x - before_x)
		max_step = maxf(max_step, step)
		var elapsed := (tick + 1) * DT
		if first_motion_time < 0.0 and absf(spider.global_position.x - start_x) > 0.01:
			first_motion_time = elapsed
		if arrival_time < 0.0 and absf(spider.global_position.x - Balance.ROUTE_X[player.transition_to]) <= POSITION_EPSILON:
			arrival_time = elapsed
	if transition_end_time < 0.0 and player.movement_mode != PlayerController.MovementMode.TRANSITION:
		transition_end_time = Balance.BRANCH_TRANSITION_SECONDS
	var arrived_after_transition := arrival_time >= 0.0 and transition_end_time >= 0.0 and arrival_time - transition_end_time <= 0.4 + DT
	var vertical_unchanged := absf(spider.velocity.y + vertical_speed) <= 0.01
	var ok := accepted \
		and first_motion_time > 0.0 and first_motion_time <= 0.4 + DT \
		and arrived_after_transition \
		and max_step <= MAX_REASONABLE_SPEED * DT + 0.01 \
		and vertical_unchanged
	return {
		"ok": ok,
		"accepted": accepted,
		"motion_s": first_motion_time,
		"transition_end_s": transition_end_time,
		"arrival_s": arrival_time,
		"max_step": max_step,
		"vertical_unchanged": vertical_unchanged,
		"x": spider.global_position.x,
		"target": Balance.ROUTE_X[player.transition_to],
	}
