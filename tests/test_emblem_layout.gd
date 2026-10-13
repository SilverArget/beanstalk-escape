extends SceneTree

const TEST_PATH := "user://qa/test_emblem_layout.json"
const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
const BACK_FRAMES := ["climb_left", "climb_right", "climb_reach", "hang", "jump", "fall"]
const BACK_LANDMARKS := {
	"m1": {
		"climb_left": [89, 136, 152, 202], "climb_right": [91, 136, 155, 207],
		"climb_reach": [96, 140, 150, 202], "hang": [87, 132, 143, 215],
		"jump": [93, 130, 151, 213], "fall": [110, 148, 142, 218],
	},
	"m2": {
		"climb_left": [86, 135, 153, 203], "climb_right": [87, 133, 155, 205],
		"climb_reach": [91, 140, 153, 203], "hang": [84, 128, 143, 217],
		"jump": [91, 130, 161, 225], "fall": [101, 148, 136, 222],
	},
	"m3": {
		"climb_left": [88, 137, 153, 203], "climb_right": [88, 135, 156, 206],
		"climb_reach": [96, 145, 153, 203], "hang": [86, 130, 144, 218],
		"jump": [94, 136, 149, 211], "fall": [105, 148, 142, 218],
	},
	"f1": {
		"climb_left": [89, 136, 149, 199], "climb_right": [90, 135, 162, 208],
		"climb_reach": [96, 142, 152, 198], "hang": [90, 132, 142, 210],
		"jump": [93, 130, 151, 211], "fall": [126, 157, 142, 214],
	},
	"f2": {
		"climb_left": [91, 136, 148, 198], "climb_right": [91, 132, 159, 209],
		"climb_reach": [94, 143, 150, 200], "hang": [91, 128, 142, 216],
		"jump": [99, 131, 159, 221], "fall": [126, 157, 143, 217],
	},
	"f3": {
		"climb_left": [89, 129, 149, 199], "climb_right": [90, 129, 158, 208],
		"climb_reach": [95, 137, 145, 195], "hang": [87, 127, 143, 217],
		"jump": [98, 130, 152, 214], "fall": [121, 156, 142, 216],
	},
}

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var economy := EconomyManager.new()
	_check(economy.initialize(SaveManager.new(TEST_PATH)), "economy loads")
	var shop := MetaShopUI.new()
	root.add_child(shop)
	shop.size = Vector2(960, 540)
	shop.setup(economy, null)
	await process_frame
	_check(shop.view_toggle_button.text == "BACK", "front preview offers BACK")
	shop.active_tab = "EMBLEM"
	shop.refresh()
	await process_frame
	_check(shop.preview_back and shop.preview.frame_name == "hang" and shop.view_toggle_button.text == "FRONT", "emblem back preview offers FRONT")
	shop.close()
	shop.open_character_select()
	await process_frame
	_check(not shop.preview_back and shop.preview.frame_name == "front" and shop.view_toggle_button.text == "BACK", "character select reopens on the front")
	var emblem := shop.preview.cosmetic_sprites.get("EMBLEM") as Sprite2D
	_check(emblem.z_index > shop.preview.sprite.z_index, "emblem renders above character hair")
	for skin in SKINS:
		var ratios: Array[float] = []
		for frame in BACK_FRAMES:
			var measured := _measure_anchor(skin, frame)
			ratios.append(float(measured.ratio))
			_check(bool(measured.valid), "%s %s emblem geometry" % [skin.to_upper(), frame])
		print("RATIO %s min=%.3f max=%.3f avg=%.3f" % [skin.to_upper(), ratios.min(), ratios.max(), _average(ratios)])
	print("test_emblem_layout.gd: %d PASS / %d FAIL" % [passed, failed])
	shop.free()
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	quit(0 if failed == 0 else 1)

func _measure_anchor(skin: String, frame: String) -> Dictionary:
	var file := FileAccess.open("res://assets/art/character_frames/%s/anchors.json" % skin, FileAccess.READ)
	if file == null:
		return {"valid": false, "ratio": 0.0}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"valid": false, "ratio": 0.0}
	var anchor: Dictionary = (parsed as Dictionary).get("frames", {}).get(frame, {})
	var center: Array = anchor.get("emblem_center", [])
	var landmarks: Array = BACK_LANDMARKS.get(skin, {}).get(frame, [])
	if center.size() != 2 or landmarks.size() != 4:
		return {"valid": false, "ratio": 0.0}
	var shoulder := float(landmarks[0])
	var belt := float(landmarks[1])
	var left := float(landmarks[2])
	var right := float(landmarks[3])
	var back_width := right - left + 1.0
	var emblem_width := float(anchor.get("emblem_width", 0.0))
	var ratio := emblem_width / back_width
	var expected_center := Vector2(round((left + right) * 0.5), round(shoulder + (belt - shoulder) * 0.45))
	var actual_center := Vector2(float(center[0]), float(center[1]))
	var half_width := emblem_width * 0.5
	var inside_back := actual_center.x - half_width >= left and actual_center.x + half_width <= right
	var above_belt := actual_center.y + half_width <= belt
	return {
		"valid": ratio >= 0.35 and ratio <= 0.45 and actual_center == expected_center and inside_back and above_belt,
		"ratio": ratio,
	}

func _average(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
