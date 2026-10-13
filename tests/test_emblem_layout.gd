extends SceneTree

const LAYOUT_PATH := "res://assets/art/character_frames/emblem_layout.json"
const EMBLEM_PATH := "res://assets/art/cosmetics/emblem_star.png"
const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
const BACK_FRAMES := ["climb_left", "climb_right", "climb_reach", "hang", "jump", "fall"]

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var preview := PlayerVisual.new()
	root.add_child(preview)
	await process_frame
	var emblem := preview.cosmetic_sprites.get("EMBLEM") as Sprite2D
	var emblem_image := Image.load_from_file(ProjectSettings.globalize_path(EMBLEM_PATH))
	emblem.texture = ImageTexture.create_from_image(emblem_image)
	preview.emblem_visible_bounds = preview.EMBLEM_VISIBLE_BOUNDS["emblem_star.png"]
	preview.equipped_cosmetics["EMBLEM"] = "emblem_star"
	_check(emblem.z_index > preview.sprite.z_index, "emblem renders above character hair")
	var layout := _load_layout()
	for skin in SKINS:
		var ratios: Array[float] = []
		for frame in BACK_FRAMES:
			_load_source_frame(preview, skin, frame)
			var measured := _measure_anchor(preview, emblem, layout, skin, frame)
			ratios.append(float(measured.ratio))
			_check(bool(measured.valid), "%s %s emblem geometry" % [skin.to_upper(), frame])
		print("RATIO %s min=%.3f max=%.3f avg=%.3f" % [skin.to_upper(), ratios.min(), ratios.max(), _average(ratios)])
	print("test_emblem_layout.gd: %d PASS / %d FAIL" % [passed, failed])
	preview.free()
	quit(0 if failed == 0 else 1)

func _load_source_frame(preview: PlayerVisual, skin: String, frame: String) -> void:
	var path := "res://assets/art/character_frames/%s/%s.png" % [skin, frame]
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	var texture := ImageTexture.create_from_image(image)
	preview.skin_id = skin.to_upper()
	preview.frame_textures[frame] = texture
	preview.frame_metrics[frame] = {
		"texture_size": texture.get_size(),
		"used": Rect2i(Vector2i.ZERO, Vector2i(int(texture.get_width()), int(texture.get_height() * 0.75))),
	}
	preview.call("_load_emblem_layout")
	preview.frame_name = ""
	preview.call("_set_frame", frame)

func _load_layout() -> Dictionary:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}

func _measure_anchor(preview: PlayerVisual, emblem: Sprite2D, layout: Dictionary, skin: String, frame: String) -> Dictionary:
	var measurement: Dictionary = layout.get(skin, {}).get(frame, {})
	var center: Array = measurement.get("emblem_center", [])
	if center.size() != 2 or not bool(measurement.get("emblem_visible", false)):
		return {"valid": false, "ratio": 0.0}
	var shoulder := float(measurement.get("shoulder_y", 0.0))
	var belt := float(measurement.get("belt_y", 0.0))
	var back_width := float(measurement.get("back_width", 0.0))
	var visible_width := preview.emblem_visible_bounds.size.x * absf(emblem.scale.x)
	var ratio := visible_width / (back_width * preview.ART_SCALE)
	var source_center := Vector2(float(center[0]), float(center[1]))
	var expected_center := preview.sprite.position + (source_center - preview.sprite.texture.get_size() * 0.5) * preview.ART_SCALE
	var visible_offset := preview.emblem_visible_bounds.get_center() - emblem.texture.get_size() * 0.5
	var actual_center := emblem.position + visible_offset * emblem.scale
	var vertical_ratio := (source_center.y - shoulder) / (belt - shoulder)
	return {
		"valid": emblem.visible and ratio >= 0.35 and ratio <= 0.45 \
			and actual_center.distance_to(expected_center) <= 1.0 \
			and source_center.y >= shoulder and source_center.y <= belt \
			and vertical_ratio >= 0.40 and vertical_ratio <= 0.60,
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
