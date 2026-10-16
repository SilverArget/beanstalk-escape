extends SceneTree

const POSES := ["climb_left", "climb_right", "climb_reach", "hang", "jump", "fall", "hurt", "cheer"]
var passes := 0
var failures := 0
var outfit_frames_checked := 0

func _init() -> void:
	var visual := PlayerVisual.new()
	visual._build_visual()
	visual._load_skin("F1")
	var file := FileAccess.open("res://config/economy.json", FileAccess.READ)
	var config: Dictionary = JSON.parse_string(file.get_as_text())
	var catalog: Array = config.cosmetics
	visual.set_cosmetics({"OUTFIT": "outfit_night", "PET": ""}, catalog)
	for pose in POSES:
		_check_pose(visual, pose, "res://assets/art/character_frames/f1/outfits/night/%s.png" % pose,
			"res://assets/art/character_frames/f1/%s.png" % pose)
	visual.show_front_preview()
	var front_path := "res://assets/art/outfits/front/f1/outfit_night.png"
	if not ResourceLoader.exists(front_path):
		front_path = "res://assets/art/character_frames/f1/front.png"
	_check(visual.sprite.texture != null and visual.sprite.texture.resource_path == front_path, "front keeps its existing texture selection")
	_check(not visual.outfit_back_sprite.visible, "front never draws the back overlay")

	visual._set_frame("climb_left")
	visual.set_cosmetics({"OUTFIT": "", "PET": ""}, catalog)
	_check(visual.sprite.texture.resource_path == "res://assets/art/character_frames/f1/climb_left.png", "removing outfit restores the current bare pose immediately")
	_check(not visual.outfit_back_sprite.visible, "removing outfit keeps the back overlay hidden")
	visual.set_cosmetics({"OUTFIT": "outfit_night", "PET": ""}, catalog)
	_check_pose(visual, "climb_left", "res://assets/art/character_frames/f1/outfits/night/climb_left.png",
		"res://assets/art/character_frames/f1/climb_left.png")
	_check(visual.set_skin("M1"), "skin change succeeds with outfit equipped")
	_check_pose(visual, "climb_left", "res://assets/art/character_frames/m1/outfits/night/climb_left.png",
		"res://assets/art/character_frames/m1/climb_left.png")
	var moss: Dictionary = {}
	for item in catalog:
		if str(item.get("id", "")) == "outfit_moss":
			moss = item
	_check(not moss.is_empty(), "preview uses a real catalog outfit")
	visual.preview_cosmetic(moss)
	_check_pose(visual, "climb_left", "res://assets/art/character_frames/m1/outfits/moss/climb_left.png",
		"res://assets/art/character_frames/m1/climb_left.png")
	if not ResourceLoader.exists("res://assets/art/character_frames/m1/outfits/moss/climb_left.png"):
		_check(visual.sprite.texture.resource_path == "res://assets/art/character_frames/m1/climb_left.png", "missing M1/moss pose falls back to the bare frame")
	else:
		print("SKIP: M1/moss missing-frame case; asset now exists")
	visual.free()
	if outfit_frames_checked == 0:
		print("SKIP: dressed-pose texture selection; no tested outfit pose assets exist")
	print("test_outfit_pose_frames.gd: %d PASS / %d FAIL; %d dressed frames checked" % [passes, failures, outfit_frames_checked])
	quit(0 if failures == 0 else 1)

func _check_pose(visual: PlayerVisual, pose: String, dressed_path: String, bare_path: String) -> void:
	var expected_path := bare_path
	if ResourceLoader.exists(dressed_path):
		expected_path = dressed_path
		outfit_frames_checked += 1
	visual._set_frame(pose)
	_check(visual.sprite.texture != null and visual.sprite.texture.resource_path == expected_path, "%s selects %s" % [pose, expected_path])
	visual._update_cosmetic_anchors()
	_check(not visual.outfit_back_sprite.visible, "%s never draws the back overlay" % pose)

func _check(condition: bool, label: String) -> void:
	if condition:
		passes += 1
	else:
		failures += 1
		push_error("FAIL: %s" % label)
