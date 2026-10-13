extends SceneTree

const SKINS := ["m1", "m2", "m3", "f1", "f2", "f3"]
const BACK_FRAMES := ["climb_left", "climb_right", "climb_reach", "hang", "jump", "fall"]
const ALPHA_THRESHOLD := 0.10
const MIN_RATIO := 0.35
const MAX_RATIO := 0.45

# Hand-checked from the source frame pixels. These independent safety
# boundaries keep the visible emblem below hair and above the belt.
const HAIR_BOTTOM := {
	"m1": {"climb_left": 143, "climb_right": 143, "climb_reach": 149, "hang": 145, "jump": 148, "fall": 154},
	"m2": {"climb_left": 143, "climb_right": 143, "climb_reach": 149, "hang": 145, "jump": 148, "fall": 154},
	"m3": {"climb_left": 143, "climb_right": 143, "climb_reach": 149, "hang": 140, "jump": 148, "fall": 154},
	"f1": {"climb_left": 147, "climb_right": 147, "climb_reach": 152, "hang": 149, "jump": 151, "fall": 157},
	"f2": {"climb_left": 149, "climb_right": 146, "climb_reach": 152, "hang": 150, "jump": 151, "fall": 157},
	"f3": {"climb_left": 150, "climb_right": 148, "climb_reach": 158, "hang": 154, "jump": 151, "fall": 157},
}
const BELT_TOP := {
	"m1": {"climb_left": 173, "climb_right": 170, "climb_reach": 181, "hang": 170, "jump": 185, "fall": 197},
	"m2": {"climb_left": 172, "climb_right": 171, "climb_reach": 180, "hang": 171, "jump": 188, "fall": 203},
	"m3": {"climb_left": 174, "climb_right": 173, "climb_reach": 181, "hang": 170, "jump": 187, "fall": 197},
	"f1": {"climb_left": 176, "climb_right": 172, "climb_reach": 183, "hang": 171, "jump": 188, "fall": 206},
	"f2": {"climb_left": 172, "climb_right": 168, "climb_reach": 178, "hang": 170, "jump": 186, "fall": 205},
	"f3": {"climb_left": 178, "climb_right": 186, "climb_reach": 192, "hang": 187, "jump": 209, "fall": 202},
}

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var visual := PlayerVisual.new()
	root.add_child(visual)
	visual.set_cosmetics(
		{"OUTFIT": "", "EMBLEM": "emblem_star", "PET": "", "TRAIL": ""},
		[{"id": "emblem_star", "slot": "EMBLEM", "image": "emblem_star.png"}],
	)
	for skin in SKINS:
		_check(visual.set_skin(skin), "%s skin loads" % skin.to_upper())
		for frame in BACK_FRAMES:
			visual._set_frame(frame)
			var measured := _measure_rendered_emblem(visual, skin, frame)
			_check(bool(measured.valid), "%s %s alpha geometry" % [skin.to_upper(), frame])
			print("RATIO %s %s %.3f" % [skin.to_upper(), frame, float(measured.ratio)])
	print("test_emblem_layout.gd: %d PASS / %d FAIL" % [passed, failed])
	visual.free()
	quit(0 if failed == 0 else 1)

func _measure_rendered_emblem(visual: PlayerVisual, skin: String, frame: String) -> Dictionary:
	var frame_texture := load("res://assets/art/character_frames/%s/%s.png" % [skin, frame]) as Texture2D
	var mask_texture := load("res://assets/art/character_frames/%s/%s_outfit_mask.png" % [skin, frame]) as Texture2D
	var frame_image := frame_texture.get_image() if frame_texture != null else null
	var outfit_mask := mask_texture.get_image() if mask_texture != null else null
	if frame_image == null or frame_image.is_empty() or outfit_mask == null or outfit_mask.is_empty():
		return {"valid": false, "ratio": 0.0}
	var emblem := visual.cosmetic_sprites.get("EMBLEM") as Sprite2D
	var visible_bounds: Rect2 = visual.emblem_visible_bounds
	var visible_center_local := emblem.position + (visible_bounds.get_center() - emblem.texture.get_size() * 0.5) * emblem.scale
	var texture_size := Vector2(frame_image.get_size())
	var source_center := (visible_center_local - visual.sprite.position) / PlayerVisual.ART_SCALE + texture_size * 0.5
	var visible_width_source := visible_bounds.size.x * emblem.scale.x / PlayerVisual.ART_SCALE
	var visible_height_source := visible_bounds.size.y * emblem.scale.y / PlayerVisual.ART_SCALE
	var torso_window := _alpha_bounds(outfit_mask)
	var frame_anchor: Dictionary = visual.anchor_data.get(frame, {})
	var outfit_anchor: Array = frame_anchor.get("outfit_back", [source_center.x])
	var torso_hint := int(round(float(outfit_anchor[0])))
	var torso_span := _opaque_span(frame_image, int(round(source_center.y)), torso_window.position.x, torso_window.end.x, torso_hint)
	if torso_span.size() != 2:
		return {"valid": false, "ratio": 0.0}
	var torso_width := float(torso_span[1] - torso_span[0] + 1)
	var ratio := visible_width_source / torso_width
	var emblem_left := source_center.x - visible_width_source * 0.5
	var emblem_right := source_center.x + visible_width_source * 0.5
	var emblem_top := source_center.y - visible_height_source * 0.5
	var emblem_bottom := source_center.y + visible_height_source * 0.5
	var torso_center := (float(torso_span[0]) + float(torso_span[1])) * 0.5
	var centered := absf(source_center.x - torso_center) <= torso_width * 0.15
	var inside_torso := emblem_left >= float(torso_span[0]) and emblem_right <= float(torso_span[1])
	var below_hair := emblem_top > float(HAIR_BOTTOM[skin][frame])
	var above_belt := emblem_bottom < float(BELT_TOP[skin][frame])
	return {
		"valid": ratio >= MIN_RATIO and ratio <= MAX_RATIO and centered and inside_torso and below_hair and above_belt,
		"ratio": ratio,
	}

func _alpha_bounds(image: Image) -> Rect2i:
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > ALPHA_THRESHOLD:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	return Rect2i(left, top, right - left + 1, bottom - top + 1)

func _opaque_span(image: Image, y: int, from_x: int, to_x: int, hint_x: int) -> Array:
	var runs: Array = []
	var start := -1
	for x in range(maxi(from_x, 0), mini(to_x, image.get_width())):
		var opaque := image.get_pixel(x, y).a > ALPHA_THRESHOLD
		if opaque and start < 0:
			start = x
		if start >= 0 and (not opaque or x == mini(to_x, image.get_width()) - 1):
			var finish := x - 1 if not opaque else x
			runs.append([start, finish])
			start = -1
	for run in runs:
		if hint_x >= int(run[0]) and hint_x <= int(run[1]):
			return run
	var widest: Array = []
	for run in runs:
		if widest.is_empty() or int(run[1]) - int(run[0]) > int(widest[1]) - int(widest[0]):
			widest = run
	return widest

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS: %s" % label)
	else:
		failed += 1
		push_error("FAIL: %s" % label)
