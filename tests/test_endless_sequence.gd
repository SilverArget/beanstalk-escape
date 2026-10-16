extends SceneTree

var passes := 0
var failures := 0

func _initialize() -> void:
	var balance_script = load("res://config/balance.gd")
	var database = load("res://scripts/stage_database.gd")
	var manager_script = load("res://scripts/stage_manager.gd")
	var manager = manager_script.new()
	root.add_child(manager)
	await process_frame
	manager.reset_run(12345)
	var stages: Array = database.stages_for_variant(database.CANONICAL_VARIANT)
	_check(stages.size() == 240 and manager.patterns.size() == 240, "240 cached records and patterns")
	var speed_ok := true
	for sample in [[-10.0, 1.0], [0.0, 1.0], [90.0, 1.5], [180.0, 2.0], [500.0, 2.0]]:
		speed_ok = speed_ok and is_equal_approx(balance_script.speed_scale_for_time(sample[0]), sample[1])
	_check(speed_ok, "speed ramp clamps at both ends")
	var tiers_ok := true
	for sample in [[0.0, 0], [19.99, 0], [20.0, 1], [40.0, 2], [60.0, 3], [1000.0, 3]]:
		tiers_ok = tiers_ok and balance_script.difficulty_tier_for_time(sample[0]) == sample[1]
	for tier in 4:
		tiers_ok = tiers_ok and balance_script.tier_name(tier) == ["EASY", "NORMAL", "HARD", "EXPERT"][tier]
	_check(tiers_ok, "20-second difficulty boundaries and names")
	var inverse_ok := true
	for sample in [[-1.0, 0.0], [0.0, 0.0], [14062.5, 90.0], [33750.0, 180.0], [48750.0, 240.0]]:
		inverse_ok = inverse_ok and absf(balance_script.estimated_time_for_height(sample[0]) - sample[1]) < 0.00001
	_check(inverse_ok, "height inverse on quadratic and linear sections")
	var entry_ok := true
	var geometry_ok := true
	var pools_ok := true
	var recency_ok := true
	var manager_ok := true
	var templates: Array = database.canonical_stages()
	var accumulated := 0.0
	var expert_count := 0
	var repeated_slot := -1
	var junction_slot := -1
	for index in stages.size():
		var record: Dictionary = stages[index]
		var number := index + 1
		var template := int(record.template)
		var tier := int(record.tier)
		if index < 3:
			entry_ok = entry_ok and template == number
		else:
			var seconds: float = balance_script.estimated_time_for_height(accumulated)
			var expected_tier := mini(int(floor(seconds / 20.0)), 3)
			pools_ok = pools_ok and tier == expected_tier and template >= 4 and template <= [8, 14, 22, 30][tier]
			if seconds >= 60.0:
				expert_count += 1
				pools_ok = pools_ok and tier == 3
			for previous in range(maxi(0, index - 3), index):
				recency_ok = recency_ok and template != int(stages[previous].template)
		geometry_ok = geometry_ok and int(record.number) == number and float(record.start_height) == accumulated
		geometry_ok = geometry_ok and record.length == templates[template - 1].length and record.encounters == templates[template - 1].encounters
		accumulated += float(record.length)
		geometry_ok = geometry_ok and float(record.target_height) == accumulated
		var midpoint := -(float(record.start_height) + float(record.length) * 0.5)
		manager_ok = manager_ok and manager.stage_for_y(midpoint) == number and is_equal_approx(manager.progress_in_stage(midpoint), 0.5)
		manager_ok = manager_ok and manager.template_for_stage(number) == template and manager.tier_for_stage(number) == tier
		manager_ok = manager_ok and database.template_for(number) == template
		if index < stages.size() - 1:
			manager_ok = manager_ok and manager.stage_for_y(-float(record.target_height)) == number + 1
		if template == 13 and number != 13:
			junction_slot = number
		if repeated_slot < 0 and template >= 4:
			for previous in range(3, index):
				if int(stages[previous].template) == template:
					repeated_slot = number
	_check(entry_ok, "first three chunks retain trunk and branch entry")
	_check(geometry_ok, "contiguous accumulated heights and unchanged template payloads")
	_check(pools_ok and expert_count > 0, "cumulative tier pools including expert after 60 seconds")
	_check(recency_ok, "no template repeats within previous three chunks")
	_check(manager_ok and manager.stage_for_y(-accumulated - 100.0) == 240, "manager lookup and progress across all 240 chunks")
	var sequence_text := var_to_str(stages)
	var pattern_text := var_to_str(manager.patterns)
	manager.reset_run(98765)
	_check(var_to_str(database.stages_for_variant(database.CANONICAL_VARIANT)) != sequence_text and var_to_str(manager.patterns) != pattern_text, "new seed rebuilds sequence and pattern caches")
	manager.reset_run(12345)
	_check(var_to_str(database.stages_for_variant(database.CANONICAL_VARIANT)) == sequence_text and var_to_str(manager.patterns) == pattern_text, "same seed reproduces sequence and patterns")
	var mirrored: Array = database.stages_for_variant(database.MIRROR_VARIANT)
	var mirror_ok := mirrored.size() == 240
	for index in mirrored.size():
		mirror_ok = mirror_ok and mirrored[index].template == stages[index].template and mirrored[index].start_height == stages[index].start_height
		for encounter_index in mirrored[index].encounters.size():
			var a: Dictionary = stages[index].encounters[encounter_index]
			var b: Dictionary = mirrored[index].encounters[encounter_index]
			var expected: float = 1.0 - float(a.witness) if a.witness is float else 2.0 - float(a.witness)
			mirror_ok = mirror_ok and is_equal_approx(float(b.witness), expected)
	_check(mirror_ok, "mirror keeps chunk order and mirrors every witness")
	var original: Dictionary = database.stage(repeated_slot)
	stages[repeated_slot - 1].encounters[0].recipe["test_only"] = true
	var isolated: bool = database.stage(repeated_slot) == original
	var returned: Dictionary = database.stage(repeated_slot)
	returned.encounters.clear()
	isolated = isolated and database.stage(repeated_slot) == original
	_check(isolated and not templates[int(original.template) - 1].encounters[0].recipe.has("test_only"), "returned records cannot mutate cache or templates")
	_check(junction_slot > 0 and not manager.transfer_window_open(junction_slot, 1.0) and not manager.transfer_window_open(junction_slot, 400.0 / 1850.0) and manager.transfer_window_open(junction_slot, 200.0 / 1850.0), "transfer restriction follows template 13 at a different chunk number")
	var events := {"chunks": 0, "finished": 0}
	manager.stage_completed.connect(func(_number: int) -> void: events.chunks += 1)
	manager.prototype_completed.connect(func() -> void: events.finished += 1)
	manager.update_progress(-float(manager.stage_target_height(239)))
	var completion_ok: bool = events.chunks == 239 and events.finished == 0 and manager.stage_banner.is_empty()
	manager.update_progress(-accumulated)
	manager.update_progress(-accumulated)
	_check(completion_ok and events.chunks == 240 and events.finished == 1 and manager.stage_banner.is_empty(), "silent chunk completion and one final signal at chunk 240")
	var worst_us := 0
	for attempt in 100:
		var started := Time.get_ticks_usec()
		var record: Dictionary = database.stage(200)
		worst_us = maxi(worst_us, Time.get_ticks_usec() - started)
		if int(record.number) != 200:
			worst_us = 5000
	print("stage(200) worst of 100 cached calls: %d us" % worst_us)
	_check(worst_us < 5000, "cached stage(200) stays below 5 ms")
	var previous_seed: int = manager.run_seed
	manager.reset_run()
	_check(manager.run_seed != previous_seed and manager.completion_count == 0 and manager.patterns.size() == 240 and database.stage(200) == manager.stage_records[199], "new run randomizes seed and resets aligned caches")
	manager.free()
	print("ENDLESS-SEQUENCE: PASS %d / FAIL %d" % [passes, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + label)
	if condition:
		passes += 1
	else:
		failures += 1
