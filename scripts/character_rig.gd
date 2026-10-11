class_name CharacterRig
extends Node2D

const SKIN_TEXTURES := {
	"M1": "res://assets/art/character_rig/skins/m1/parts_sheet.png",
	"F1": "res://assets/art/character_rig/skins/f1/parts_sheet.png",
}
const PART_NAMES := [
	"head_neutral", "head_hurt", "hair_back", "hair_front", "torso", "pelvis",
	"upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "hand_l_open", "hand_r_open",
	"hand_l_grip", "hand_r_grip", "thigh_l", "thigh_r", "shin_l", "shin_r",
	"foot_l", "foot_r", "accessory", "wing_anchor",
]
const CELL_WIDTH := 209.0
const CELL_HEIGHT := 313.5
const ART_SCALE := 0.16
const CELL_CLIP_MARGIN := Vector2(30, 8)
const WING_COLOR := Color("9969ec")
const CLIMB_BODY_OFFSET := Vector2(8, 0)

var skin_id := "M1"
var part_sprites: Dictionary = {}
var bones: Dictionary = {}
var animation_player: AnimationPlayer
var skeleton: Node2D
var wing_left: Polygon2D
var wing_right: Polygon2D
var cutout_material: ShaderMaterial
var non_hair_material: ShaderMaterial
var _last_state := ""
var _last_penalty := 0

func _ready() -> void:
	_build_rig()
	_build_animations()
	var requested := OS.get_environment("BEANSTALK_SKIN").to_upper()
	set_skin(requested if SKIN_TEXTURES.has(requested) else "M1")
	play_animation("idle")

func _process(_delta: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	if player.bean_penalty_count != _last_penalty:
		_last_penalty = player.bean_penalty_count
		play_animation("hurt")
		return
	if animation_player.current_animation == "hurt" and animation_player.is_playing():
		return
	if player.time_wings_active:
		play_animation("skill_time")
	elif player.support_state == PlayerController.SupportState.TRANSFERRING:
		if player.transition_progress < 0.15:
			play_animation("branch_takeoff")
		elif player.transition_progress < 0.85:
			play_animation("branch_midair")
		else:
			play_animation("branch_landing")
	else:
		play_animation("climb_loop")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_1:
		set_skin("M1")
	elif event.physical_keycode == KEY_2:
		set_skin("F1")

func set_skin(requested_skin: String) -> bool:
	var normalized := requested_skin.to_upper()
	if not SKIN_TEXTURES.has(normalized):
		return false
	var texture := load(SKIN_TEXTURES[normalized]) as Texture2D
	if texture == null:
		return false
	if texture.get_width() != 1254 or texture.get_height() != 1254:
		push_error("CharacterRig skin atlas must be 1254x1254: " + normalized)
		return false
	for sprite: Sprite2D in part_sprites.values():
		sprite.texture = texture
	non_hair_material.set_shader_parameter("suppress_stray_red", normalized == "F1")
	skin_id = normalized
	return true

func play_animation(animation_name: String, restart := false) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	if restart or _last_state != animation_name:
		animation_player.play(animation_name)
		_last_state = animation_name

func seek_animation(animation_name: String, time_seconds: float) -> void:
	play_animation(animation_name, true)
	animation_player.seek(time_seconds, true)
	animation_player.pause()

func rig_contract() -> Dictionary:
	return {
		"skin": skin_id,
		"parts": PART_NAMES.duplicate(),
		"atlas_size": Vector2i(1254, 1254),
		"cell_size": Vector2(CELL_WIDTH, CELL_HEIGHT),
		"local_pivot": Vector2.ZERO,
		"visible_size": Vector2(ScaleLock.CHARACTER_WIDTH, ScaleLock.CHARACTER_HEIGHT),
		"collider_size": Vector2(ScaleLock.COLLIDER_WIDTH, ScaleLock.COLLIDER_HEIGHT),
		"wing_anchor": bones.wing_anchor.position,
	}

func _build_rig() -> void:
	cutout_material = ShaderMaterial.new()
	var cutout_shader := Shader.new()
	cutout_shader.code = """
shader_type canvas_item;
uniform bool suppress_stray_red = false;
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	vec2 step_px = TEXTURE_PIXEL_SIZE * 6.0;
	float support = 0.0;
	support += step(0.18, texture(TEXTURE, UV + vec2(step_px.x, 0.0)).a);
	support += step(0.18, texture(TEXTURE, UV - vec2(step_px.x, 0.0)).a);
	support += step(0.18, texture(TEXTURE, UV + vec2(0.0, step_px.y)).a);
	support += step(0.18, texture(TEXTURE, UV - vec2(0.0, step_px.y)).a);
	bool red_fringe = suppress_stray_red && pixel.r > 0.45 && pixel.g < 0.30 && pixel.b < 0.22 && pixel.r > pixel.g * 2.6;
	if (pixel.a < 0.18 || support < 3.5 || red_fringe) { discard; }
	COLOR = pixel * COLOR;
}
"""
	cutout_material.shader = cutout_shader
	non_hair_material = cutout_material.duplicate() as ShaderMaterial
	non_hair_material.set_shader_parameter("suppress_stray_red", true)
	skeleton = Node2D.new()
	skeleton.name = "Skeleton"
	skeleton.position = CLIMB_BODY_OFFSET
	skeleton.z_index = 10
	add_child(skeleton)
	var pelvis := _add_bone("pelvis", skeleton, Vector2(0, 15))
	var torso := _add_bone("torso", pelvis, Vector2(0, -21))
	var head := _add_bone("head", torso, Vector2(0, -27))
	var upper_arm_l := _add_bone("upper_arm_l", torso, Vector2(-11, 0))
	var upper_arm_r := _add_bone("upper_arm_r", torso, Vector2(11, 0))
	var forearm_l := _add_bone("forearm_l", upper_arm_l, Vector2(0, 18))
	var forearm_r := _add_bone("forearm_r", upper_arm_r, Vector2(0, 18))
	var hand_l := _add_bone("hand_l", forearm_l, Vector2(0, 16))
	var hand_r := _add_bone("hand_r", forearm_r, Vector2(0, 16))
	var thigh_l := _add_bone("thigh_l", pelvis, Vector2(-7, 6))
	var thigh_r := _add_bone("thigh_r", pelvis, Vector2(7, 6))
	var shin_l := _add_bone("shin_l", thigh_l, Vector2(0, 19))
	var shin_r := _add_bone("shin_r", thigh_r, Vector2(0, 19))
	var foot_l := _add_bone("foot_l", shin_l, Vector2(0, 18))
	var foot_r := _add_bone("foot_r", shin_r, Vector2(0, 18))
	var accessory := _add_bone("accessory", torso, Vector2(0, 2))
	var wing_anchor := _add_bone("wing_anchor", torso, Vector2(0, 1))

	_add_part("hair_back", head, 2, -5)
	_add_part("head_neutral", head, 0, 4)
	_add_part("head_hurt", head, 1, 4).visible = false
	_add_part("hair_front", head, 3, 5)
	_add_part("torso", torso, 4, 2)
	_add_part("pelvis", pelvis, 5, 3)
	_add_part("upper_arm_l", upper_arm_l, 6, 0)
	_add_part("upper_arm_r", upper_arm_r, 7, 6)
	_add_part("forearm_l", forearm_l, 8, 0)
	_add_part("forearm_r", forearm_r, 9, 6)
	_add_part("hand_l_open", hand_l, 10, 1)
	_add_part("hand_r_open", hand_r, 11, 7)
	_add_part("hand_l_grip", hand_l, 12, 1).visible = false
	_add_part("hand_r_grip", hand_r, 13, 7).visible = false
	_add_part("thigh_l", thigh_l, 14, 1)
	_add_part("thigh_r", thigh_r, 15, 5)
	_add_part("shin_l", shin_l, 16, 1)
	_add_part("shin_r", shin_r, 17, 5)
	_add_part("foot_l", foot_l, 18, 1)
	_add_part("foot_r", foot_r, 19, 5)
	_add_part("accessory", accessory, 20, -7)
	_add_part("wing_anchor", wing_anchor, 21, -6)
	_configure_part_pose()
	_build_time_wings(wing_anchor)

	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)

func _add_bone(bone_name: String, parent: Node, bone_position: Vector2) -> Node2D:
	var bone := Node2D.new()
	bone.name = bone_name
	bone.position = bone_position
	parent.add_child(bone)
	bones[bone_name] = bone
	return bone

func _add_part(part_name: String, parent: Node2D, part_index: int, z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = part_name
	sprite.region_enabled = true
	var cell_origin := Vector2(float(part_index % 6) * CELL_WIDTH, float(part_index / 6) * CELL_HEIGHT)
	# Shared insets reject image-gen debris on atlas borders. Head cells receive
	# an extra far-side crop to remove the last detached F1 ponytail fragment.
	var far_margin_x := 60.0 if part_name in ["head_neutral", "head_hurt"] else CELL_CLIP_MARGIN.x
	sprite.region_rect = Rect2(
		cell_origin + CELL_CLIP_MARGIN,
		Vector2(CELL_WIDTH - CELL_CLIP_MARGIN.x - far_margin_x, CELL_HEIGHT - CELL_CLIP_MARGIN.y * 2.0)
	)
	sprite.region_filter_clip_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.material = cutout_material if part_name in ["head_neutral", "head_hurt", "hair_back", "hair_front"] else non_hair_material
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.z_index = z
	parent.add_child(sprite)
	part_sprites[part_name] = sprite
	return sprite

func _configure_part_pose() -> void:
	# The approved neutral/hurt cells contain the complete identity hair. The
	# separately mounted hair layers remain in the shared contract, but are not
	# composited a second time (which masked faces and duplicated F1's ponytail).
	part_sprites.hair_back.visible = false
	part_sprites.hair_front.visible = false
	part_sprites.head_neutral.position = Vector2(-2, -2)
	part_sprites.head_hurt.position = Vector2(-2, -2)
	part_sprites.torso.position = Vector2(0, 7)
	part_sprites.pelvis.position = Vector2(0, 4)
	for part_name in ["upper_arm_l", "upper_arm_r"]:
		part_sprites[part_name].position = Vector2(0, 8)
	for part_name in ["forearm_l", "forearm_r"]:
		part_sprites[part_name].position = Vector2(0, 7)
	for part_name in ["thigh_l", "thigh_r"]:
		part_sprites[part_name].position = Vector2(0, 9)
	for part_name in ["shin_l", "shin_r"]:
		part_sprites[part_name].position = Vector2(0, 8)
	part_sprites.accessory.position = Vector2(5, 5)
	part_sprites.accessory.scale = Vector2.ONE * (ART_SCALE * 0.78)
	part_sprites.wing_anchor.position = Vector2(3, 3)
	part_sprites.wing_anchor.scale = Vector2.ONE * (ART_SCALE * 0.72)

func _build_time_wings(anchor: Node2D) -> void:
	wing_left = Polygon2D.new()
	wing_left.name = "time_wing_l"
	wing_left.polygon = PackedVector2Array([Vector2.ZERO, Vector2(-38, -31), Vector2(-48, -5), Vector2(-40, 27), Vector2(-8, 11)])
	wing_left.color = WING_COLOR
	wing_left.z_index = -8
	wing_left.scale = Vector2.ONE * 0.01
	anchor.add_child(wing_left)
	wing_right = Polygon2D.new()
	wing_right.name = "time_wing_r"
	wing_right.polygon = PackedVector2Array([Vector2.ZERO, Vector2(38, -31), Vector2(48, -5), Vector2(40, 27), Vector2(8, 11)])
	wing_right.color = WING_COLOR
	wing_right.z_index = -8
	wing_right.scale = Vector2.ONE * 0.01
	anchor.add_child(wing_right)

func _build_animations() -> void:
	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_idle())
	library.add_animation("climb_loop", _make_climb())
	library.add_animation("branch_takeoff", _make_branch_phase("takeoff"))
	library.add_animation("branch_midair", _make_branch_phase("midair"))
	library.add_animation("branch_landing", _make_branch_phase("landing"))
	library.add_animation("hurt", _make_hurt())
	library.add_animation("skill_time", _make_wing_open())
	animation_player.add_animation_library("", library)

func _make_idle() -> Animation:
	var animation := Animation.new()
	animation.length = 1.0
	animation.loop_mode = Animation.LOOP_LINEAR
	_add_values(animation, "Skeleton/pelvis/torso:position", [0.0, 0.5, 1.0], [Vector2(0, -21), Vector2(0, -22), Vector2(0, -21)])
	_add_values(animation, "Skeleton/pelvis/torso/head:rotation", [0.0, 0.5, 1.0], [-0.025, 0.025, -0.025])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l:rotation", [0.0, 1.0], [-0.68, -0.68])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l/forearm_l:rotation", [0.0, 1.0], [1.80, 1.80])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r:rotation", [0.0, 1.0], [2.18, 2.18])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r/forearm_r:rotation", [0.0, 1.0], [0.75, 0.75])
	_add_values(animation, "Skeleton/pelvis/thigh_l:rotation", [0.0, 1.0], [-0.66, -0.66])
	_add_values(animation, "Skeleton/pelvis/thigh_l/shin_l:rotation", [0.0, 1.0], [1.83, 1.83])
	_add_values(animation, "Skeleton/pelvis/thigh_r:rotation", [0.0, 1.0], [0.29, 0.29])
	_add_values(animation, "Skeleton/pelvis/thigh_r/shin_r:rotation", [0.0, 1.0], [2.29, 2.29])
	_set_grip_tracks(animation, [0.0, 1.0], [true, true])
	return animation

func _make_climb() -> Animation:
	var animation := Animation.new()
	animation.length = 0.8
	animation.loop_mode = Animation.LOOP_LINEAR
	var times := [0.0, 0.2, 0.4, 0.6, 0.8]
	# Four contact poses: one hand/foot pair reaches while the other pair pulls.
	# The root moves only one pixel; locomotion reads as gripping, not bouncing.
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l:rotation", times, [-0.68, -3.95, -3.95, -0.68, -0.68])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r:rotation", times, [2.18, 2.18, 0.18, 0.18, 2.18])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l/forearm_l:rotation", times, [1.80, 1.57, 1.57, 1.80, 1.80])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r/forearm_r:rotation", times, [0.75, 0.75, 1.25, 1.25, 0.75])
	_add_values(animation, "Skeleton/pelvis/thigh_l:rotation", times, [-0.66, -0.46, -0.46, -0.66, -0.66])
	_add_values(animation, "Skeleton/pelvis/thigh_r:rotation", times, [0.29, 0.29, -0.03, -0.03, 0.29])
	_add_values(animation, "Skeleton/pelvis/thigh_l/shin_l:rotation", times, [1.83, 2.84, 2.84, 1.83, 1.83])
	_add_values(animation, "Skeleton/pelvis/thigh_r/shin_r:rotation", times, [2.29, 2.29, 1.38, 1.38, 2.29])
	_add_values(animation, "Skeleton/pelvis:position", times, [Vector2(0, 15), Vector2(0, 14), Vector2(0, 15), Vector2(0, 16), Vector2(0, 15)])
	_set_grip_tracks(animation, times, [true, true, true, true, true])
	return animation

func _make_branch_phase(phase: String) -> Animation:
	var animation := Animation.new()
	animation.length = 0.24 if phase != "midair" else 0.40
	var target_rotation := -0.25 if phase == "takeoff" else (0.20 if phase == "landing" else 0.0)
	_add_values(animation, "Skeleton/pelvis:rotation", [0.0, animation.length], [0.0, target_rotation])
	_add_values(animation, "Skeleton/pelvis:scale", [0.0, animation.length], [Vector2.ONE, Vector2(1.08, 0.92) if phase == "takeoff" else Vector2.ONE])
	return animation

func _make_hurt() -> Animation:
	var animation := Animation.new()
	animation.length = 0.35
	_add_values(animation, "Skeleton/pelvis:rotation", [0.0, 0.08, 0.35], [0.0, -0.18, 0.0])
	_add_discrete(animation, "Skeleton/pelvis/torso/head/head_neutral:visible", [0.0, 0.34], [false, true])
	_add_discrete(animation, "Skeleton/pelvis/torso/head/head_hurt:visible", [0.0, 0.34], [true, false])
	return animation

func _make_wing_open() -> Animation:
	var animation := Animation.new()
	animation.length = 0.6
	animation.loop_mode = Animation.LOOP_LINEAR
	var times := [0.0, 0.20, 0.45, 0.60]
	var values := [Vector2.ONE * 0.01, Vector2(0.45, 0.8), Vector2.ONE, Vector2(0.96, 1.03)]
	_add_values(animation, "Skeleton/pelvis/torso/wing_anchor/time_wing_l:scale", times, values)
	_add_values(animation, "Skeleton/pelvis/torso/wing_anchor/time_wing_r:scale", times, values)
	return animation

func _set_grip_tracks(animation: Animation, times: Array, values: Array) -> void:
	for side in ["l", "r"]:
		_add_discrete(animation, "Skeleton/pelvis/torso/upper_arm_%s/forearm_%s/hand_%s/hand_%s_open:visible" % [side, side, side, side], times, values.map(func(value: bool): return not value))
		_add_discrete(animation, "Skeleton/pelvis/torso/upper_arm_%s/forearm_%s/hand_%s/hand_%s_grip:visible" % [side, side, side, side], times, values)

func _add_values(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	for index in times.size():
		animation.track_insert_key(track, times[index], values[index])

func _add_discrete(animation: Animation, path: String, times: Array, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(path))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for index in times.size():
		animation.track_insert_key(track, times[index], values[index])
