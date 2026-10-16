extends SceneTree

const GAME_SCRIPT = preload("res://scripts/game_manager.gd")
var passes := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
	print(("PASS " if ok else "FAIL ") + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for sample in [[0.0, 1.0], [90.0, 1.5], [180.0, 2.0], [300.0, 2.0]]:
		check(is_equal_approx(Balance.speed_scale_for_time(sample[0]), sample[1]), "speed at %s s" % sample[0])
	var player := PlayerController.new()
	player.name = "Player"
	root.add_child(player)
	player.set_physics_process(false)
	check(is_equal_approx(player.climb_speed(), 125.0), "base climb 125 px/s")
	player.speed_scale = 2.0
	check(is_equal_approx(player.climb_speed(), 250.0), "scaled climb 250 px/s")
	check(is_equal_approx(player.branch_transition_seconds() / Balance.BRANCH_TRANSITION_SECONDS, 2.0 / 3.0), "transition duration 2/3")
	player.fire_wings_active = true
	check(is_equal_approx(player.climb_speed(), 250.0 * Balance.FIRE_WINGS_SPEED_SCALE), "fire wings multiply run speed")
	player.fire_wings_active = false
	player.apply_bean_hit()
	check(is_equal_approx(player.knockback_remaining, Balance.BEAN_KNOCKBACK_SECONDS) and is_equal_approx(player.stun_remaining, Balance.BEAN_STUN_SECONDS), "penalty durations unchanged")
	var spider := SpiderController.new()
	root.add_child(spider)
	spider.set_physics_process(false)
	spider.global_position = Vector2(0.0, 300.0)
	await physics_frame
	spider._physics_process(1.0 / 60.0)
	var base_speed := SpiderController.speed_for_state(300.0, 1, 0.0, false, false)
	check(is_equal_approx(-spider.velocity.y, base_speed * 2.0), "spider vertical speed scales x2")
	check(is_equal_approx(spider.speed_ratio, base_speed / Balance.PLAYER_VERTICAL_SPEED), "spider ratio excludes run scale")
	player.global_position.x = 100.0
	spider.global_position.x = 0.0
	spider._update_horizontal_follow(1.0 / 60.0, 1)
	check(is_equal_approx(spider.global_position.x, Balance.SPIDER_TRUNK_FOLLOW_SPEED * 2.0 / 60.0), "spider trunk follow scales x2")
	spider.begin_danger(true)
	check(is_equal_approx(spider.distance_to_player(), 56.0), "danger gap remains 56 px")
	var stages := StageManager.new()
	stages.stage_records = [{"template": 20, "tier": 2}]
	spider.stages = stages
	spider._danger_tracking = false
	spider.global_position = Vector2(0.0, 300.0)
	spider._physics_process(1.0 / 60.0)
	check(is_equal_approx(-spider.velocity.y, SpiderController.speed_for_state(300.0, 20, 0.0, false, false) * 2.0), "runtime pressure uses chunk template")
	stages.free()
	spider.free()
	player.free()
	print("RESULT PASS=%d FAIL=%d" % [passes, failures])
	quit(1 if failures > 0 else 0)
