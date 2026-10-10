extends SceneTree

var failures := 0

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func approximate_array(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in actual.size():
		if not is_equal_approx(float(actual[index]), float(expected[index])):
			return false
	return true

func _initialize() -> void:
	test_gate2_balance_contract()
	test_stage_records()
	test_encounter_schema()
	test_variant_catalog()
	test_stage_manager_uses_database()
	quit(failures)

func test_gate2_balance_contract() -> void:
	check(Balance.PLAYER_VERTICAL_SPEED == 100.0 and Balance.STAGE_HEIGHT == 2800.0 and Balance.STAGE_DURATION_SECONDS == 28.0, "G2-DATA-01", "v_base=%.1f stage_height=%.1f duration=%.1f" % [Balance.PLAYER_VERTICAL_SPEED, Balance.STAGE_HEIGHT, Balance.STAGE_DURATION_SECONDS])

func test_stage_records() -> void:
	var records := StageDatabase.canonical_stages()
	var starts_ok := true
	var defaults_ok := records.size() == 5
	var encounter_count := 0
	for index in records.size():
		var stage: Dictionary = records[index]
		starts_ok = starts_ok and stage.number == index + 1 and stage.start_height == index * 2800 and stage.target_height == (index + 1) * 2800
		defaults_ok = defaults_ok and stage.length == 2800 and stage.theme == "sunny" and stage.qa_seed_set == ["canonical_v1", "mirror_v1"] and stage.release_allowlist.is_empty()
		defaults_ok = defaults_ok and stage.branch_graph == ("TRUNK" if stage.number <= 2 else "G3") and stage.skill_unlock == ("TIME" if stage.number == 5 else "none")
		encounter_count += stage.encounters.size()
	check(starts_ok and defaults_ok and encounter_count == 25, "G2-DATA-02", "stages=%d encounters=%d starts=%s defaults=%s" % [records.size(), encounter_count, str(starts_ok), str(defaults_ok)])

func test_encounter_schema() -> void:
	var schema_ok := true
	var recipe_counts := {}
	for stage: Dictionary in StageDatabase.canonical_stages():
		for encounter: Dictionary in stage.encounters:
			schema_ok = schema_ok and encounter.warning_height == encounter.anchor - 360 and encounter.occupancy == [encounter.anchor, encounter.anchor + 220]
			schema_ok = schema_ok and not encounter.id.is_empty() and encounter.has("witness") and encounter.has("objective")
			var kind: String = encounter.recipe.kind
			recipe_counts[kind] = int(recipe_counts.get(kind, 0)) + 1
	check(schema_ok and recipe_counts == {"GUIDE": 5, "BULGE": 5, "FORK": 5, "BEAN": 10}, "G2-DATA-03", "schema=%s recipes=%s" % [str(schema_ok), str(recipe_counts)])

func test_variant_catalog() -> void:
	var canonical := StageDatabase.stages_for_variant("canonical_v1")
	var mirrored := StageDatabase.stages_for_variant("mirror_v1")
	var first_c: Dictionary = canonical[0].encounters[0]
	var first_m: Dictionary = mirrored[0].encounters[0]
	var fork_c: Dictionary = canonical[2].encounters[0]
	var fork_m: Dictionary = mirrored[2].encounters[0]
	var bean_c: Dictionary = canonical[3].encounters[0]
	var bean_m: Dictionary = mirrored[3].encounters[0]
	var mirror_ok: bool = first_c.recipe.x == 0.20 and is_equal_approx(first_m.recipe.x, 0.80)
	mirror_ok = mirror_ok and fork_c.recipe.supports == [0, 1] and fork_m.recipe.supports == [2, 1]
	mirror_ok = mirror_ok and bean_c.recipe.lane == 1 and bean_m.recipe.lane == 1 and approximate_array(mirrored[0].witness, [0.80, 0.20, 0.50, 0.80, 0.20])
	check(StageDatabase.QA_VARIANTS == ["canonical_v1", "mirror_v1"] and StageDatabase.RELEASE_ALLOWLIST.is_empty() and mirror_ok, "G2-DATA-04", "qa=%s allowlist=%s mirror=%s x=%s/%s fork=%s/%s bean=%s/%s witness=%s" % [str(StageDatabase.QA_VARIANTS), str(StageDatabase.RELEASE_ALLOWLIST), str(mirror_ok), str(first_c.recipe.x), str(first_m.recipe.x), str(fork_c.recipe.supports), str(fork_m.recipe.supports), str(bean_c.recipe.lane), str(bean_m.recipe.lane), str(mirrored[0].witness)])

func test_stage_manager_uses_database() -> void:
	var manager := StageManager.new()
	manager.run_variant = "canonical_v1"
	manager.reset_run()
	var patterns_ok: bool = manager.patterns.size() == 5 and manager.pattern_for_stage(4).bean_slots.size() == 5 and manager.pattern_for_stage(5).bean_slots.size() == 5
	var mapping_ok: bool = manager.stage_for_y(-2799.0) == 1 and manager.stage_for_y(-2800.0) == 2 and is_equal_approx(manager.progress_in_stage(-4200.0), 0.5)
	check(patterns_ok and mapping_ok, "G2-DATA-05", "patterns=%d s4_beans=%d s5_beans=%d mapping=%s" % [manager.patterns.size(), manager.pattern_for_stage(4).bean_slots.size(), manager.pattern_for_stage(5).bean_slots.size(), str(mapping_ok)])
	manager.free()
