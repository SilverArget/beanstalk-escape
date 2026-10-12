class_name StageDatabase
extends RefCounted

const CANONICAL_VARIANT := "canonical_v1"
const MIRROR_VARIANT := "mirror_v1"
const QA_VARIANTS := [CANONICAL_VARIANT, MIRROR_VARIANT]
const RELEASE_ALLOWLIST := []
const STAGE_LENGTH := 2800
const WARNING_LEAD := 360
const OCCUPANCY_HEIGHT := 220

const STAGE_DEFINITIONS := [
	{
		"number": 1, "title": "Ground Awakening", "branch_graph": "TRUNK", "skill_unlock": "none",
		"witness": [0.20, 0.80, 0.50, 0.20, 0.80],
		"encounters": [
			{"id": "S01-E01", "anchor": 500, "recipe": {"kind": "GUIDE", "x": 0.20}, "witness": 0.20, "objective": "Follow the left surface; climbing stays automatic."},
			{"id": "S01-E02", "anchor": 950, "recipe": {"kind": "GUIDE", "x": 0.80}, "witness": 0.80, "objective": "Traverse the full trunk surface."},
			{"id": "S01-E03", "anchor": 1400, "recipe": {"kind": "GUIDE", "x": 0.50}, "witness": 0.50, "objective": "Release input while automatic climbing continues."},
			{"id": "S01-E04", "anchor": 1850, "recipe": {"kind": "GUIDE", "x": 0.20}, "witness": 0.20, "objective": "Choose direction under spider audio pressure."},
			{"id": "S01-E05", "anchor": 2300, "recipe": {"kind": "GUIDE", "x": 0.80}, "witness": 0.80, "objective": "Reach the right exit corridor."},
		],
	},
	{
		"number": 2, "title": "First Fork", "branch_graph": "TRUNK", "skill_unlock": "none",
		"witness": [0.80, 0.20, 0.50, 0.80, 0.20],
		"encounters": [
			{"id": "S02-E01", "anchor": 500, "recipe": {"kind": "BULGE", "x": 0.80}, "witness": 0.80, "objective": "Pass the first bark bulge on its right."},
			{"id": "S02-E02", "anchor": 970, "recipe": {"kind": "BULGE", "x": 0.20}, "witness": 0.20, "objective": "Read the opposite bulge early."},
			{"id": "S02-E03", "anchor": 1430, "recipe": {"kind": "BULGE", "x": 0.50}, "witness": 0.50, "objective": "Take the central surface corridor."},
			{"id": "S02-E04", "anchor": 1890, "recipe": {"kind": "BULGE", "x": 0.80}, "witness": 0.80, "objective": "Follow the right curve continuously."},
			{"id": "S02-E05", "anchor": 2350, "recipe": {"kind": "BULGE", "x": 0.20}, "witness": 0.20, "objective": "Make the final trunk-side change."},
		],
	},
	{
		"number": 3, "title": "Three Vines", "branch_graph": "G3", "skill_unlock": "none",
		"witness": [0, 1, 2, 1, 0],
		"encounters": [
			{"id": "S03-E01", "anchor": 500, "recipe": {"kind": "FORK", "supports": [0, 1]}, "witness": 0, "objective": "Move from C to supported L."},
			{"id": "S03-E02", "anchor": 950, "recipe": {"kind": "FORK", "supports": [1, 2]}, "witness": 1, "objective": "Leave the visible L tip for C."},
			{"id": "S03-E03", "anchor": 1400, "recipe": {"kind": "FORK", "supports": [0, 2]}, "witness": 2, "objective": "Leave the visible C tip for R."},
			{"id": "S03-E04", "anchor": 1850, "recipe": {"kind": "FORK", "supports": [0, 1]}, "witness": 1, "objective": "Leave the R tip for C."},
			{"id": "S03-E05", "anchor": 2300, "recipe": {"kind": "FORK", "supports": [0, 2]}, "witness": 0, "objective": "Exit on L through the final fork."},
		],
	},
	{
		"number": 4, "title": "Falling Beans", "branch_graph": "G3", "skill_unlock": "none",
		"witness": [0, 1, 2, 0, 1],
		"encounters": [
			{"id": "S04-E01", "anchor": 500, "recipe": {"kind": "BEAN", "lane": 1, "count": 1}, "witness": 0, "objective": "Leave the first center bean on L."},
			{"id": "S04-E02", "anchor": 950, "recipe": {"kind": "BEAN", "lane": 0, "count": 1}, "witness": 1, "objective": "Read the new L target and use C."},
			{"id": "S04-E03", "anchor": 1400, "recipe": {"kind": "BEAN", "lane": 1, "count": 1}, "witness": 2, "objective": "Evade the repeated bean on R."},
			{"id": "S04-E04", "anchor": 1850, "recipe": {"kind": "BEAN", "lane": 2, "count": 1}, "witness": 0, "objective": "Use the open two-transfer corridor to L."},
			{"id": "S04-E05", "anchor": 2300, "recipe": {"kind": "BEAN", "lane": 0, "count": 1}, "witness": 1, "objective": "Take the calm center exit."},
		],
	},
	{
		"number": 5, "title": "Violet Wings", "branch_graph": "G3", "skill_unlock": "TIME",
		"witness": [2, 1, 0, 2, 1],
		"encounters": [
			{"id": "S05-E01", "anchor": 500, "recipe": {"kind": "BEAN", "lane": 1, "count": 1}, "witness": 2, "objective": "Show TIME READY while R stays safe."},
			{"id": "S05-E02", "anchor": 960, "recipe": {"kind": "BEAN", "lane": 2, "count": 1}, "witness": 1, "objective": "Track a Time-slowed bean from C."},
			{"id": "S05-E03", "anchor": 1440, "recipe": {"kind": "BEAN", "lane": 1, "count": 1}, "witness": 0, "objective": "Keep player speed unchanged on L."},
			{"id": "S05-E04", "anchor": 1900, "recipe": {"kind": "BEAN", "lane": 0, "count": 1}, "witness": 2, "objective": "Use the open two-transfer corridor to R."},
			{"id": "S05-E05", "anchor": 2370, "recipe": {"kind": "BEAN", "lane": 2, "count": 1}, "witness": 1, "objective": "Let Time end without moving the threat."},
		],
	},
]

static func canonical_stages() -> Array:
	var result: Array = []
	var definitions: Array = STAGE_DEFINITIONS.duplicate(true)
	definitions.append_array(_stages_6_to_15())
	definitions.append_array(_stages_16_to_30())
	var accumulated_height := 0
	for definition_value in definitions:
		var stage: Dictionary = (definition_value as Dictionary).duplicate(true)
		stage["length"] = int(stage.get("length", STAGE_LENGTH))
		stage["start_height"] = accumulated_height
		accumulated_height += int(stage.length)
		stage["target_height"] = accumulated_height
		stage["theme"] = String(stage.get("theme", "sunny"))
		stage["qa_seed_set"] = QA_VARIANTS.duplicate()
		stage["release_allowlist"] = RELEASE_ALLOWLIST.duplicate()
		stage["checkpoint"] = "stage_start"
		stage["tutorial_trigger"] = "none" if int(stage.number) >= 15 else "encounter_warning_once"
		stage["end_transition"] = "next_stage_immediate_with_three_async_pulses"
		stage["nominal_duration_no_fire"] = float(stage.length) / Balance.PLAYER_VERTICAL_SPEED
		stage["validation_status"] = "NOT_RUN"
		stage["encounters"] = _paced_encounters(stage) if int(stage.number) <= 5 else _densify_encounters(stage)
		stage["witness"] = stage.encounters.map(func(encounter: Dictionary) -> Variant: return encounter.witness)
		for encounter: Dictionary in stage.encounters:
			var anchor := int(encounter.anchor)
			encounter["warning_height"] = anchor - WARNING_LEAD
			encounter["occupancy"] = [anchor, anchor + int(encounter.get("occupancy_height", OCCUPANCY_HEIGHT))]
		result.append(stage)
	return result

static func _stages_6_to_15() -> Array:
	return [
		_late_stage(6, "Rock Roots", 2800, "rock_cloud", [2, 1, 0, 1, 2], [
			[500, [_hazard("S", 1)], 2], [950, [_hazard("S", 2)], 1], [1400, [_hazard("S", 1)], 0], [1850, [_hazard("S", 0)], 1], [2300, [_hazard("S", 1)], 2]]),
		_late_stage(7, "Stone and Seed", 2800, "rock_cloud", [0, 1, 2, 1, 0], [
			[500, [_hazard("S", 1)], 0], [970, [_hazard("BEAN", 0)], 1], [1440, [_hazard("S", 0), _hazard("BEAN", 1)], 2], [1910, [_hazard("S", 2)], 1], [2380, [_hazard("S", 1), _hazard("BEAN", 2)], 0]]),
		_late_stage(8, "The Rolling Boulder", 2800, "rock_cloud", [2, 0, 1, 2, 0], [
			[500, [_hazard("R", 1)], 2], [950, [_hazard("R", 2)], 0], [1400, [_hazard("R", 0)], 1], [1850, [_hazard("S", 0), _hazard("R", 1)], 2], [2300, [_hazard("R", 2)], 0]]),
		_late_stage(9, "Crossfire", 2800, "rock_cloud", [0, 2, 1, 0, 2], [
			[500, [_hazard("R", 1), _hazard("BEAN", 2)], 0], [970, [_hazard("R", 0), _hazard("BEAN", 1)], 2], [1440, [_hazard("R", 2), _hazard("BEAN", 0)], 1], [1910, [_hazard("S", 2), _hazard("BEAN", 1)], 0], [2380, [_hazard("R", 1), _hazard("BEAN", 0)], 2]]),
		_late_stage(10, "Fire Ascension", 3000, "rock_cloud", [0, 1, 2, 1, 0], [
			[500, [_hazard("BEAN", 1)], 0], [1000, [_hazard("S", 0)], 1], [1500, [_hazard("R", 1)], 2], [2000, [_hazard("BEAN", 2)], 1], [2500, [_hazard("S", 1), _hazard("BEAN", 2)], 0]], "FIRE"),
		_late_stage(11, "Purple Glide", 3000, "violet_twilight", [2, 1, 0, 1], [
			[500, [_hazard("S", 1)], 2], [1120, [_hazard("BEAN", 2)], 1], [1820, [_hazard("R", 1)], 0], [2500, [_hazard("S", 0)], 1]]),
		_late_stage(12, "The Stone Locks", 3000, "violet_twilight", [0, 2, 1, 2, 0], [
			[500, [_hazard("S", 1), _hazard("S", 2)], 0], [990, [_hazard("S", 0), _hazard("S", 1)], 2], [1485, [_hazard("S", 0), _hazard("S", 2)], 1], [1990, [_hazard("S", 0), _hazard("S", 1)], 2], [2500, [_hazard("S", 1), _hazard("S", 2)], 0]]),
		_late_stage(13, "Twisting Junction", 3000, "violet_twilight", [2, 0, 1, 2, 0], [
			[500, [_hazard("S", 0), _hazard("BEAN", 1)], 2], [1000, [_hazard("S", 1), _hazard("BEAN", 2)], 0], [1510, [_hazard("S", 2), _hazard("BEAN", 0)], 1], [2010, [_hazard("S", 0), _hazard("R", 1)], 2], [2500, [_hazard("S", 1), _hazard("BEAN", 2)], 0]], "none", true),
		_late_stage(14, "Final Lesson", 3000, "violet_twilight", [1, 0, 2, 1, 0], [
			[500, [_hazard("BEAN", 0), _hazard("S", 2)], 1], [995, [_hazard("R", 1), _hazard("BEAN", 2)], 0], [1490, [_hazard("S", 0), _hazard("BEAN", 1)], 2], [1995, [_hazard("R", 2), _hazard("S", 0)], 1], [2500, [_hazard("S", 1), _hazard("BEAN", 2)], 0]]),
		_late_stage(15, "Into the Unknown", 3000, "violet_twilight", [2, 1, 0, 2, 1], [
			[500, [_hazard("S", 0), _hazard("BEAN", 1)], 2], [990, [_hazard("R", 2), _hazard("BEAN", 0)], 1], [1485, [_hazard("S", 1), _hazard("R", 2)], 0], [1990, [_hazard("BEAN", 0), _hazard("S", 1)], 2], [2500, [_hazard("R", 0), _hazard("BEAN", 2)], 1]])
	]

static func _stages_16_to_30() -> Array:
	return [
		_late_stage(16, "Windbreak", 3000, "storm", [1, 0, 2, 1, 0], [
			[500, [_wind(1)], 1], [1000, [_wind(1)], 0], [1500, [_wind(-1)], 2], [2000, [_wind(-1), _hazard("BEAN", 0)], 1], [2500, [_wind(1)], 0]]),
		_late_stage(17, "Whistling Seeds", 3000, "storm", [2, 0, 1, 2, 0], [
			[500, [_wind(-1), _hazard("BEAN", 1)], 2], [995, [_wind(1), _hazard("BEAN", 2)], 0], [1490, [_wind(-1), _hazard("BEAN", 0)], 1], [1995, [_wind(1), _hazard("BEAN", 1)], 2], [2500, [_wind(-1), _hazard("BEAN", 2)], 0]]),
		_late_stage(18, "Wind over Stone", 3000, "storm", [0, 1, 2, 0, 1], [
			[500, [_wind(1), _hazard("S", 1)], 0], [990, [_wind(-1), _hazard("S", 0)], 1], [1490, [_wind(-1), _hazard("S", 1)], 2], [1990, [_wind(1), _hazard("S", 2)], 0], [2500, [_wind(1), _hazard("S", 0)], 1]]),
		_late_stage(19, "Snapping Vines", 3000, "storm", [0, 1, 2, 1, 0], [
			[500, [_hazard("K", 1)], 0], [1000, [_hazard("K", 0)], 1], [1500, [_hazard("K", 1), _hazard("BEAN", 0)], 2], [2000, [_hazard("K", 2), _hazard("S", 0)], 1], [2500, [_hazard("K", 1), _wind(1)], 0]]),
		_late_stage(20, "Spider Web", 3000, "storm", [2, 1, 0, 2, 1], [
			[500, [_hazard("WEB", 1)], 2], [1000, [_hazard("WEB", 2), _hazard("BEAN", 0)], 1], [1500, [_hazard("WEB", 1), _hazard("S", 2)], 0], [2000, [_hazard("WEB", 0), _hazard("K", 1)], 2], [2500, [_hazard("WEB", 2), _wind(-1)], 1]]),
		_late_stage(21, "Cracking Heights", 3000, "lightning_rock", [0, 1, 2, 0, 1], [
			[500, [_hazard("F", 1)], 0], [1000, [_hazard("F", 0), _hazard("BEAN", 2)], 1], [1500, [_hazard("F", 1), _hazard("S", 0)], 2], [2000, [_hazard("F", 2), _hazard("WEB", 1)], 0], [2500, [_hazard("F", 0), _wind(1)], 1]]),
		_late_stage(22, "The Rock Wall", 3000, "lightning_rock", [2, 0, 1, 2, 0], [
			[500, [_multi_hazard("WALL", [0, 1])], 2], [1000, [_multi_hazard("WALL", [1, 2])], 0], [1500, [_multi_hazard("WALL", [0, 2])], 1], [2000, [_multi_hazard("WALL", [0, 1]), _wind(-1)], 2], [2500, [_multi_hazard("WALL", [1, 2])], 0]]),
		_late_stage(23, "Bean Monsoon", 3000, "lightning_rock", [1, 2, 0, 1, 2], [
			[500, [_hazard("BEAN", 0, 3), _hazard("BEAN", 2, 3)], 1], [995, [_hazard("BEAN", 0, 3), _hazard("BEAN", 1, 3)], 2], [1495, [_hazard("BEAN", 1, 3), _hazard("BEAN", 2, 3)], 0], [2000, [_hazard("BEAN", 0, 3), _hazard("BEAN", 2, 3)], 1], [2500, [_hazard("BEAN", 0, 3), _hazard("BEAN", 1, 3)], 2]]),
		_late_stage(24, "Crushing Rhythm", 3000, "lightning_rock", [0, 2, 1, 0, 2], [
			[500, [_hazard("BEAN", 1, 3), _hazard("R", 2)], 0], [990, [_hazard("BEAN", 0, 3), _hazard("R", 1)], 2], [1480, [_hazard("BEAN", 2, 3), _hazard("R", 0)], 1], [1980, [_hazard("BEAN", 1, 3), _hazard("R", 2)], 0], [2500, [_hazard("BEAN", 0, 3), _hazard("R", 1)], 2]]),
		_late_stage(25, "The Hunter Closes", 3000, "lightning_rock", [1, 0, 2, 1, 0], [
			[500, [_hazard("F", 0), _hazard("BEAN", 2, 3)], 1], [990, [_hazard("WEB", 1), _hazard("R", 2)], 0], [1490, [_multi_hazard("WALL", [0, 1])], 2], [1990, [_hazard("F", 2), _hazard("BEAN", 0, 3)], 1], [2500, [_hazard("K", 1), _hazard("S", 2)], 0]]),
		_late_stage(26, "The Moving Stones", 3000, "upper_cloud", [0, 2, 0, 2, 1], [
			[500, [_multi_hazard("M", [1, 2])], 0], [1000, [_multi_hazard("M", [0, 1])], 2], [1500, [_multi_hazard("M", [1, 2])], 0], [2000, [_multi_hazard("M", [0, 1])], 2], [2500, [_hazard("F", 0), _hazard("BEAN", 2)], 1]]),
		_late_stage(27, "Crosswind Labyrinth", 3000, "upper_cloud", [2, 0, 2, 0, 1], [
			[500, [_multi_hazard("M", [0, 1]), _wind(-1, 1.2)], 2], [990, [_multi_hazard("M", [1, 2]), _wind(1, 1.2)], 0], [1480, [_multi_hazard("M", [0, 1]), _wind(1, 1.2)], 2], [1970, [_multi_hazard("M", [1, 2]), _wind(-1, 1.2)], 0], [2500, [_hazard("S", 0), _hazard("BEAN", 2), _wind(1, 1.2)], 1]]),
		_late_stage(28, "All Against You", 3000, "upper_cloud", [0, 2, 1, 0, 2], [
			[500, [_hazard("BEAN", 1, 3), _hazard("R", 2), _wind(1, 1.2)], 0], [990, [_multi_hazard("WALL", [0, 1]), _wind(-1, 1.2)], 2], [1480, [_hazard("F", 0), _hazard("WEB", 2), _wind(1)], 1], [1980, [_multi_hazard("M", [1, 2]), _wind(1, 1.2)], 0], [2500, [_hazard("K", 0), _hazard("BEAN", 1, 3), _wind(-1)], 2]]),
		_late_stage(29, "Last Chase", 3000, "upper_cloud", [2, 0, 1, 2, 0], [
			[500, [_hazard("WEB", 0), _hazard("F", 1), _wind(-1)], 2], [990, [_multi_hazard("M", [1, 2]), _wind(1, 1.2)], 0], [1480, [_hazard("BEAN", 0, 3), _hazard("R", 2)], 1], [1970, [_multi_hazard("WALL", [0, 1]), _wind(-1, 1.2)], 2], [2470, [_hazard("F", 1), _hazard("BEAN", 2, 3), _wind(1)], 0]]),
		_late_stage(30, "Summit", 3000, "summit", [0, 1, 2, 1], [
			[500, [_hazard("BEAN", 1), _hazard("S", 2)], 0], [1140, [_hazard("R", 0), _hazard("BEAN", 2)], 1], [1800, [_hazard("F", 1), _hazard("S", 0)], 2], [2460, [_hazard("BEAN", 0), _hazard("S", 2)], 1]])
	]

static func _hazard(kind: String, lane: int, count := 1) -> Dictionary:
	var result := {"kind": kind, "lane": lane}
	if kind == "BEAN": result["count"] = count
	return result

static func _multi_hazard(kind: String, lanes: Array) -> Dictionary:
	return {"kind": kind, "lanes": lanes.duplicate()}

static func _wind(direction: int, gain := 1.0) -> Dictionary:
	return {"kind": "V", "direction": direction, "gain": gain}

static func _late_stage(number: int, title: String, length: int, theme: String, witness: Array, rows: Array, skill := "none", junction := false) -> Dictionary:
	var encounters: Array = []
	for index in rows.size():
		var row: Array = rows[index]
		var threats: Array = row[1]
		var recipe: Dictionary = (threats[0] as Dictionary).duplicate(true) if threats.size() == 1 else {"kind": "COMBO", "threats": threats.duplicate(true)}
		encounters.append({"id": "S%02d-E%02d" % [number, index + 1], "anchor": int(row[0]), "recipe": recipe, "witness": int(row[2]), "objective": "Read the telegraph and reach the canonical safe lane."})
	return {"number": number, "title": title, "branch_graph": "J13" if junction else "G3", "skill_unlock": skill, "length": length, "theme": theme, "witness": witness, "encounters": encounters, "junction_override": junction}

static func _densify_encounters(stage: Dictionary) -> Array:
	var result: Array = stage.encounters.duplicate(true)
	var target_count := 9
	while result.size() < target_count:
		var best_index := 0
		var best_gap := -1
		for index in range(result.size() - 1):
			var gap := int((result[index + 1] as Dictionary).anchor) - int((result[index] as Dictionary).anchor)
			if gap > best_gap:
				best_gap = gap
				best_index = index
		var left: Dictionary = result[best_index]
		var right: Dictionary = result[best_index + 1]
		var inserted: Dictionary = left.duplicate(true)
		inserted["id"] = "S%02d-X%02d" % [int(stage.number), result.size() + 1]
		inserted["anchor"] = int(round((float(left.anchor) + float(right.anchor)) * 0.5))
		inserted["occupancy_height"] = 120
		inserted["objective"] = "Keep the established safe route through the denser rhythm."
		result.insert(best_index + 1, inserted)
	return result

static func threats_for_recipe(recipe: Dictionary) -> Array:
	return recipe.threats if String(recipe.kind) == "COMBO" else [recipe]

static func _paced_encounters(stage: Dictionary) -> Array:
	var source: Array = stage.encounters
	var result: Array = []
	for index in 10:
		var template: Dictionary = (source[index % source.size()] as Dictionary).duplicate(true)
		# Stage 1 starts targeting the idle center lane at the third encounter;
		# Stages 2-3 alternate beans with their authored teaching encounters.
		var use_bean := int(stage.number) >= 4 or (int(stage.number) == 1 and index >= 2 and index % 2 == 0) or (int(stage.number) in [2, 3] and index % 2 == 1)
		template["id"] = "S%02d-E%02d" % [int(stage.number), index + 1]
		# 230 px is 1.84 s at the 125 px/s tempo. Ten occupancies remain inside
		# the 2800 px early-stage boundary while keeping the established rhythm.
		template["anchor"] = 500 + index * 230
		if int(stage.number) == 3 and not use_bean and index > 0:
			template["witness"] = int((result[-1] as Dictionary).witness)
		if use_bean:
			# Trunk beans cycle across center, left and right. The first Stage 1
			# bean targets the no-input center lane; the first three cover every
			# fixed-position strategy while leaving two reachable safe lanes.
			var trunk_bean_index := int(index / 2) - 1 if int(stage.number) == 1 else int((index - 1) / 2)
			var trunk_cycle := [1, 0, 2]
			var blocked: int = int(trunk_cycle[trunk_bean_index % trunk_cycle.size()]) if int(stage.number) <= 2 else (index + int(stage.number)) % 3
			if int(stage.number) == 3:
				var preceding_supports: Array = (result[-1] as Dictionary).recipe.supports
				template["witness"] = int(preceding_supports[0])
				if index + 1 < 10:
					var next_supports: Array = (source[(index + 1) % source.size()] as Dictionary).recipe.supports
					for supported_route in preceding_supports:
						if next_supports.has(supported_route):
							template["witness"] = int(supported_route)
							break
				for route in 3:
					if route != int(template.witness):
						blocked = route
						break
			template["recipe"] = {"kind": "BEAN", "lane": blocked, "count": 2 if int(stage.number) == 5 else 1}
			if int(stage.number) != 3:
				template["witness"] = (blocked + 1) % 3
			template["objective"] = "Read the warning and keep one safe route."
		result.append(template)
	return result

static func stages_for_variant(variant: String) -> Array:
	var stages := canonical_stages()
	if variant == CANONICAL_VARIANT:
		return stages
	if variant != MIRROR_VARIANT:
		return []
	for stage: Dictionary in stages:
		stage["witness"] = _mirror_sequence(stage.witness)
		for encounter: Dictionary in stage.encounters:
			encounter["witness"] = _mirror_position(encounter.witness)
			var recipe: Dictionary = encounter.recipe
			_mirror_recipe(recipe)
	return stages

static func _mirror_recipe(recipe: Dictionary) -> void:
	match String(recipe.kind):
		"GUIDE", "BULGE":
			recipe["x"] = 1.0 - float(recipe.x)
		"FORK":
			recipe["supports"] = _mirror_sequence(recipe.supports)
		"BEAN", "S", "R", "F", "K", "WEB":
			recipe["lane"] = 2 - int(recipe.lane)
		"WALL", "M":
			recipe["lanes"] = _mirror_sequence(recipe.lanes)
		"V":
			recipe["direction"] = -int(recipe.direction)
		"COMBO":
			for threat: Dictionary in recipe.threats: _mirror_recipe(threat)

static func stage(stage_number: int, variant := CANONICAL_VARIANT) -> Dictionary:
	var stages := stages_for_variant(variant)
	if stage_number < 1 or stage_number > stages.size():
		return {}
	return (stages[stage_number - 1] as Dictionary).duplicate(true)

static func _mirror_sequence(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_mirror_position(value))
	return result

static func _mirror_position(value: Variant) -> Variant:
	if value is int:
		return 2 - int(value)
	if value is float:
		return 1.0 - float(value)
	return value
