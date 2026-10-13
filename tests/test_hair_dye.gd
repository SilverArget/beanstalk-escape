extends SceneTree

const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
const ECONOMY_PATH := "res://config/economy.json"
const LUMA_PATH := "res://tools/hair_masks/hair_luma.json"

var passed := 0
var failed := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var economy := _load_json(ECONOMY_PATH)
	var luma_data := _load_json(LUMA_PATH)
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
		print("HAIR %s pixels=%d mean=(%.3f, %.3f, %.3f) face_delta=%.4f outside_delta=%.4f" % [
			skin.to_upper(), metrics.pixels, metrics.mean.r, metrics.mean.g, metrics.mean.b,
			metrics.face_delta, metrics.outside_delta,
		])
		_check(is_equal_approx(float(visual.flash_material.get_shader_parameter("hair_luma_min")), float(frame_luma.p5)), "%s front p5 reaches shader" % skin.to_upper())
		_check(is_equal_approx(float(visual.flash_material.get_shader_parameter("hair_luma_max")), float(frame_luma.p95)), "%s front p95 reaches shader" % skin.to_upper())
		_check(visual.flash_material.get_shader_parameter("hair_mid_color").is_equal_approx(Color(str(ramp[1]))), "%s BLONDE ramp reaches shader" % skin.to_upper())
		_check(metrics.mean.r > metrics.mean.g and metrics.mean.g > metrics.mean.b and metrics.mean.r - metrics.mean.b > 0.25, "%s BLONDE is golden (R>G>B, R-B>0.25)" % skin.to_upper())
		_check(metrics.face_delta <= 0.005, "%s face box is unchanged" % skin.to_upper())
		_check(metrics.outside_delta <= 0.005, "%s pixels outside hair mask are unchanged" % skin.to_upper())

	visual.free()
	_finish()


func _measure(source: Image, mask: Image, p5: float, p95: float, ramp: Array) -> Dictionary:
	var total := Color(0, 0, 0, 0)
	var pixels := 0
	var face_delta := 0.0
	var face_pixels := 0
	var outside_delta := 0.0
	var outside_pixels := 0
	var used := source.get_used_rect()
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
			var nx := (float(x) - used.position.x) / maxf(used.size.x, 1.0)
			var ny := (float(y) - used.position.y) / maxf(used.size.y, 1.0)
			# Sample below the fringe so brown hair highlights that overlap the
			# forehead are not mistaken for dyed skin by the broad YCbCr filter.
			if nx >= 0.40 and nx <= 0.60 and ny >= 0.27 and ny <= 0.34 and _is_skin_tone(original):
				face_delta += delta
				face_pixels += 1
	return {
		"pixels": pixels,
		"mean": total / maxf(float(pixels), 1.0),
		"face_delta": face_delta / maxf(float(face_pixels), 1.0),
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


func _luma(pixel: Color) -> float:
	return pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114


func _is_skin_tone(pixel: Color) -> bool:
	var red := pixel.r * 255.0
	var green := pixel.g * 255.0
	var blue := pixel.b * 255.0
	var cb := 128.0 - 0.168736 * red - 0.331264 * green + 0.5 * blue
	var cr := 128.0 + 0.5 * red - 0.418688 * green - 0.081312 * blue
	return cb >= 77.0 and cb <= 127.0 and cr >= 133.0 and cr <= 173.0


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
