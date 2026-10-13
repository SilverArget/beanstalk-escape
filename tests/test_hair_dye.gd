extends SceneTree

const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
const ECONOMY_PATH := "res://config/economy.json"
const LUMA_PATH := "res://tools/hair_masks/hair_luma.json"
const REGIONS_PATH := "res://tools/hair_masks/hair_regions.json"

var passed := 0
var failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var economy := _load_json(ECONOMY_PATH)
	var luma_data := _load_json(LUMA_PATH)
	var regions := _load_json(REGIONS_PATH)
	var blonde := _catalog_item(economy.get("cosmetics", []), "hair_blonde")
	_check(blonde.get("ramp", []).size() == 3, "BLONDE defines a three-stop ramp")
	_check(luma_data.has("skins"), "hair luma data exists")
	if failed > 0:
		_finish()
		return

	var visual := PlayerVisual.new()
	root.add_child(visual)
	await process_frame
	for skin in SKINS:
		visual.set_skin(skin)
		visual.show_front_preview()
		visual.set_cosmetics({"HAIR": "hair_blonde", "OUTFIT": "", "EMBLEM": "", "PET": "", "TRAIL": ""}, economy.get("cosmetics", []))
		var source := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/character_frames/%s/front.png" % skin))
		var mask := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/character_frames/%s/front_hair_mask.png" % skin))
		var frame_luma: Dictionary = luma_data.skins[skin].front
		var ramp: Array = blonde.ramp
		var metrics := _measure(source, mask, float(frame_luma.p5), float(frame_luma.p95), ramp)
		var feature_counts := _feature_mask_counts(mask, source.get_used_rect(), regions.skins[skin].feature_boxes.front)
		print("HAIR %s pixels=%d mean=(%.3f, %.3f, %.3f) outside_delta=%.4f" % [
			skin.to_upper(), metrics.pixels, metrics.mean.r, metrics.mean.g, metrics.mean.b,
			metrics.outside_delta,
		])
		_check(is_equal_approx(float(visual.flash_material.get_shader_parameter("hair_luma_min")), float(frame_luma.p5)), "%s front p5 reaches shader" % skin.to_upper())
		_check(is_equal_approx(float(visual.flash_material.get_shader_parameter("hair_luma_max")), float(frame_luma.p95)), "%s front p95 reaches shader" % skin.to_upper())
		_check(visual.flash_material.get_shader_parameter("hair_mid_color").is_equal_approx(Color(str(ramp[1]))), "%s BLONDE ramp reaches shader" % skin.to_upper())
		_check(metrics.mean.r > metrics.mean.g and metrics.mean.g > metrics.mean.b and metrics.mean.r - metrics.mean.b > 0.25, "%s BLONDE is golden (R>G>B, R-B>0.25)" % skin.to_upper())
		_check(feature_counts.eye_left == 0, "%s left eye has no hair-mask pixels" % skin.to_upper())
		_check(feature_counts.eye_right == 0, "%s right eye has no hair-mask pixels" % skin.to_upper())
		_check(feature_counts.mouth == 0, "%s mouth has no hair-mask pixels" % skin.to_upper())
		_check(metrics.outside_delta <= 0.005, "%s pixels outside hair mask are unchanged" % skin.to_upper())

	visual.free()
	_finish()


func _measure(source: Image, mask: Image, p5: float, p95: float, ramp: Array) -> Dictionary:
	var total := Color(0, 0, 0, 0)
	var pixels := 0
	var outside_delta := 0.0
	var outside_pixels := 0
	for y in source.get_height():
		for x in source.get_width():
			var original := source.get_pixel(x, y)
			if original.a < 0.78:
				continue
			var in_hair := mask.get_pixel(x, y).a > 0.5
			var rendered := _dye_hair(original, p5, p95, ramp) if in_hair else original
			var delta := absf(original.r - rendered.r) + absf(original.g - rendered.g) + absf(original.b - rendered.b)
			if in_hair:
				total += rendered
				pixels += 1
			else:
				outside_delta += delta
				outside_pixels += 1
	return {
		"pixels": pixels,
		"mean": total / maxf(float(pixels), 1.0),
		"outside_delta": outside_delta / maxf(float(outside_pixels), 1.0),
	}


func _dye_hair(pixel: Color, p5: float, p95: float, ramp: Array) -> Color:
	var normalized := clampf((_luma(pixel) - p5) / maxf(p95 - p5, 0.001), 0.0, 1.0)
	normalized = smoothstep(0.0, 1.0, normalized)
	var shadow := Color(str(ramp[0]))
	var middle := Color(str(ramp[1]))
	var highlight := Color(str(ramp[2]))
	var dyed := shadow.lerp(middle, normalized * 2.0) if normalized < 0.5 else middle.lerp(highlight, (normalized - 0.5) * 2.0)
	dyed.a = pixel.a
	return dyed


func _feature_mask_counts(mask: Image, used: Rect2i, boxes: Dictionary) -> Dictionary:
	var counts := {"eye_left": 0, "eye_right": 0, "mouth": 0}
	for feature in counts:
		var box: Array = boxes.get(feature, [])
		if box.size() != 4:
			counts[feature] = -1
			continue
		var left := clampi(used.position.x + roundi(float(box[0]) * used.size.x), 0, mask.get_width())
		var top := clampi(used.position.y + roundi(float(box[1]) * used.size.y), 0, mask.get_height())
		var right := clampi(used.position.x + roundi(float(box[2]) * used.size.x), 0, mask.get_width())
		var bottom := clampi(used.position.y + roundi(float(box[3]) * used.size.y), 0, mask.get_height())
		var center := Vector2((left + right) * 0.5, (top + bottom) * 0.5)
		var radius := Vector2(maxf((right - left) * 0.5, 1.0), maxf((bottom - top) * 0.5, 1.0))
		for y in range(top, bottom):
			for x in range(left, right):
				var normalized := (Vector2(x, y) - center) / radius
				if normalized.length_squared() <= 1.0 and mask.get_pixel(x, y).a > 0.5:
					counts[feature] += 1
	return counts


func _luma(pixel: Color) -> float:
	return pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114


func _catalog_item(items: Array, item_id: String) -> Dictionary:
	for item in items:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)


func _finish() -> void:
	print("test_hair_dye.gd: %d PASS / %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)
