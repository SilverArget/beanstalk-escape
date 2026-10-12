extends SceneTree

const ROCK_KINDS := ["S", "R", "F", "WALL", "M"]
const BANDS := [
	{"stage": 6, "legacy": {"g_lo": 180.0, "pressure": 0.0}},
	{"stage": 15, "legacy": {"g_lo": 180.0, "pressure": 4.0}},
	{"stage": 20, "legacy": {"g_lo": 180.0, "pressure": 12.0}},
	{"stage": 25, "legacy": {"g_lo": 156.0, "pressure": 12.0}},
	{"stage": 29, "legacy": {"g_lo": 108.0, "pressure": 12.0}},
	{"stage": 30, "legacy": {"g_lo": 156.0, "pressure": 12.0}},
]

var passed := 0
var failed := 0

func _init() -> void:
	for band: Dictionary in BANDS:
		var stage_number := int(band.stage)
		var before := SpiderController.simulate_rock_penalty_safety(stage_number, band.legacy)
		var after := SpiderController.simulate_rock_penalty_safety(stage_number)
		for kind: String in ROCK_KINDS:
			var safe := float(after.minimum_gap) >= 56.0
			var recovers := float(after.final_gap) > float(after.post_penalty_gap)
			if safe and recovers:
				passed += 1
				print("PASS: K1-%s-S%02d min=%.1f->%.1f post=%.1f final=%.1f" % [kind, stage_number, float(before.minimum_gap), float(after.minimum_gap), float(after.post_penalty_gap), float(after.final_gap)])
			else:
				failed += 1
				print("FAIL: K1-%s-S%02d min=%.1f->%.1f post=%.1f final=%.1f" % [kind, stage_number, float(before.minimum_gap), float(after.minimum_gap), float(after.post_penalty_gap), float(after.final_gap)])
	print("ROCK-K1-SAFETY: PASS %d / FAIL %d" % [passed, failed])
	quit(0 if failed == 0 else 1)
