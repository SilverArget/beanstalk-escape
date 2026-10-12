extends SceneTree

var failures := 0

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await physics_frame
	game.restart()
	game.spider.global_position = Vector2(0.0, 10000.0)
	game.spider.set_physics_process(false)
	game.beans.set_physics_process(false)
	var player := game.player
	player.set_physics_process(false)

	# Cross the exact Stage 2 -> 3 boundary from the far trunk edge. The same
	# physical stem must seat the player on the middle route without recovery.
	player.reset_run(Vector2(-Balance.TRUNK_HALF_WIDTH, -Balance.STAGE_HEIGHT * 2.0 + 1.0))
	player.global_position.y = -Balance.STAGE_HEIGHT * 2.0 - 1.0
	player._sync_stage_mode()
	var entry_ok := player.active_branch == 1 \
		and player.support_state == PlayerController.SupportState.SUPPORTED \
		and player.on_support \
		and is_equal_approx(player.global_position.x, game.stages.branch_x_at(1, player.global_position.y))
	check(entry_ok, "STAGE3-ENTRY", "branch=%d state=%s x=%.2f" % [player.active_branch, player.support_state_name(), player.global_position.x])

	var contract: Dictionary = game.get_node("World").qa_visual_contract()
	var separated: bool = contract.stage_3_layout == "continuous_middle_with_separate_side_vines" \
		and int(contract.split_union_count) == 0 \
		and int(contract.transfer_bridge_count) == 0 \
		and is_equal_approx(float(contract.side_vine_entry_world_y), -Balance.STAGE_HEIGHT * 2.0 + 240.0)
	check(separated, "STAGE3-SEPARATE-VINES", "layout=%s split=%d bridges=%d entry_y=%.1f" % [contract.stage_3_layout, contract.split_union_count, contract.transfer_bridge_count, contract.side_vine_entry_world_y])

	# Before the first support gap, one command launches one airborne transfer.
	player.reset_run(Vector2(0.0, -Balance.STAGE_HEIGHT * 2.0 - 400.0))
	player.active_branch = 1
	player.global_position.x = game.stages.branch_x_at(1, player.global_position.y)
	var accepted := player._begin_branch_transition(1)
	var rejected_overlap := not player.request_branch_direction(-1)
	var visual := player.get_node("Body") as PlayerVisual
	visual._process(0.0)
	var jump_frame: bool = visual.visual_snapshot().frame == "jump"
	var max_arc := 0.0
	var ticks := 0
	while player.support_state == PlayerController.SupportState.TRANSFERRING and ticks < 100:
		player._update_branch_movement(1.0 / 120.0)
		max_arc = maxf(max_arc, player.transition_base_y - player.global_position.y)
		ticks += 1
	var duration := float(ticks) / 120.0
	var jump_ok: bool = accepted and rejected_overlap and jump_frame \
		and player.active_branch == 2 \
		and player.support_state == PlayerController.SupportState.SUPPORTED \
		and absf(max_arc - Balance.BRANCH_ARC_HEIGHT) <= 0.2 \
		and absf(duration - Balance.BRANCH_TRANSITION_SECONDS) <= 0.001
	check(jump_ok, "STAGE3-AIR-JUMP", "accepted=%s overlap_rejected=%s frame=%s arc=%.2f duration=%.3f branch=%d" % [str(accepted), str(rejected_overlap), visual.visual_snapshot().frame, max_arc, duration, player.active_branch])

	var solution := ReachabilityValidator.solve_stages_1_to_5(StageDatabase.CANONICAL_VARIANT)
	var stage_3_commands := 0
	for command: Dictionary in solution.commands:
		if int(command.stage) == 3:
			stage_3_commands += 1
	var witness_ok := bool(solution.valid) and stage_3_commands == 10
	check(witness_ok, "STAGE3-ROUTE-WITNESS", "valid=%s commands=%d stage3=%d" % [str(solution.valid), solution.commands.size(), stage_3_commands])

	game._start_debug_stage(3)
	var debug_ok := game.stages.stage_for_y(player.global_position.y) == 3 \
		and player.active_branch == 1 \
		and is_equal_approx(game.spider.global_position.y - player.global_position.y, Balance.START_DISTANCE)
	check(debug_ok, "STAGE3-DEBUG-START", "stage=%d branch=%d distance=%.1f" % [game.stages.stage_for_y(player.global_position.y), player.active_branch, game.spider.global_position.y - player.global_position.y])

	game.queue_free()
	await physics_frame
	print("RESULT passed=%d failed=%d" % [5 - failures, failures])
	quit(failures)
