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
	for definition_value in STAGE_DEFINITIONS:
		var stage: Dictionary = (definition_value as Dictionary).duplicate(true)
		var stage_index := int(stage.number) - 1
		stage["length"] = STAGE_LENGTH
		stage["start_height"] = stage_index * STAGE_LENGTH
		stage["target_height"] = (stage_index + 1) * STAGE_LENGTH
		stage["theme"] = "sunny"
		stage["qa_seed_set"] = QA_VARIANTS.duplicate()
		stage["release_allowlist"] = RELEASE_ALLOWLIST.duplicate()
		stage["checkpoint"] = "stage_start"
		stage["tutorial_trigger"] = "encounter_warning_once"
		stage["end_transition"] = "next_stage_immediate_with_three_async_pulses"
		stage["nominal_duration_no_fire"] = Balance.STAGE_DURATION_SECONDS
		stage["validation_status"] = "NOT_RUN"
		stage["encounters"] = _paced_encounters(stage)
		for encounter: Dictionary in stage.encounters:
			var anchor := int(encounter.anchor)
			encounter["warning_height"] = anchor - WARNING_LEAD
			encounter["occupancy"] = [anchor, anchor + OCCUPANCY_HEIGHT]
		result.append(stage)
	return result

static func _paced_encounters(stage: Dictionary) -> Array:
	var source: Array = stage.encounters
	var result: Array = []
	for index in 10:
		var template: Dictionary = (source[index % source.size()] as Dictionary).duplicate(true)
		var use_bean := int(stage.number) >= 4 or (int(stage.number) == 1 and index >= 2 and index % 2 == 0) or (int(stage.number) == 2 or int(stage.number) == 3) and index % 2 == 1
		template["id"] = "S%02d-E%02d" % [int(stage.number), index + 1]
		# 240 px is 1.92 s at the 125 px/s tempo. Starting at 500 keeps every
		# warning safely inside its stage and leaves Stage 1's first bean after 3 s.
		template["anchor"] = 500 + index * 240
		if int(stage.number) == 3 and not use_bean and index > 0:
			template["witness"] = int((result[-1] as Dictionary).witness)
		if use_bean:
			var blocked: int = (0 if index % 4 < 2 else 2) if int(stage.number) <= 2 else (index + int(stage.number)) % 3
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
			match String(recipe.kind):
				"GUIDE", "BULGE":
					recipe["x"] = 1.0 - float(recipe.x)
				"FORK":
					recipe["supports"] = _mirror_sequence(recipe.supports)
				"BEAN":
					recipe["lane"] = 2 - int(recipe.lane)
	return stages

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
