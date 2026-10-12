class_name CharacterRig
extends Node2D

const SKIN_TEXTURES := {
	"M1": "res://assets/art/character_rig/skins/m1/parts_sheet.png",
	"F1": "res://assets/art/character_rig/skins/f1/parts_sheet.png",
}
const WING_TEXTURE := "res://assets/art/character_rig/wing/time_wings.png"
const PART_NAMES := [
	"head_neutral", "head_hurt", "hair_back", "hair_front", "torso", "pelvis",
	"upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "hand_l_open", "hand_r_open",
	"hand_l_grip", "hand_r_grip", "thigh_l", "thigh_r", "shin_l", "shin_r",
	"foot_l", "foot_r", "accessory", "wing_anchor",
]
const CELL_WIDTH := 209.0
const CELL_HEIGHT := 313.5
const ART_SCALE := 0.10
const CELL_CLIP_MARGIN := Vector2.ZERO
const CLIMB_BODY_OFFSET := Vector2(8, 0)
static var _outline_mask_cache: Dictionary = {}

var skin_id := "M1"
var part_sprites: Dictionary = {}
var outline_sprites: Dictionary = {}
var bones: Dictionary = {}
var animation_player: AnimationPlayer
var skeleton: Node2D
var time_wings: Sprite2D
var cutout_material: ShaderMaterial
var non_hair_material: ShaderMaterial
var outline_material: ShaderMaterial
var outline_non_hair_material: ShaderMaterial
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
	if not _outline_mask_cache.has(normalized):
		_outline_mask_cache[normalized] = _build_outline_mask(texture)
	var outline_texture := _outline_mask_cache[normalized] as Texture2D
	for part_name: String in outline_sprites:
		var outline_sprite := outline_sprites[part_name] as Sprite2D
		outline_sprite.texture = outline_texture
		(outline_sprite.material as ShaderMaterial).set_shader_parameter("suppress_stray_red", normalized == "F1" and part_name not in ["head_neutral", "head_hurt", "hair_back", "hair_front"])
	non_hair_material.set_shader_parameter("suppress_stray_red", normalized == "F1")
	outline_non_hair_material.set_shader_parameter("suppress_stray_red", normalized == "F1")
	skin_id = normalized
	return true

func _build_outline_mask(texture: Texture2D) -> Texture2D:
	var source := texture.get_image()
	var mask := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for part_index in PART_NAMES.size():
		var cell_x := part_index % 6
		var cell_y := part_index / 6
		var left := roundi(float(cell_x) * CELL_WIDTH)
		var top := roundi(float(cell_y) * CELL_HEIGHT)
		var right := roundi(float(cell_x + 1) * CELL_WIDTH)
		var bottom := roundi(float(cell_y + 1) * CELL_HEIGHT)
		var width := right - left
		var height := bottom - top
		var visited := PackedByteArray()
		visited.resize(width * height)
		var largest: Array[Vector2i] = []
		for local_y in height:
			for local_x in width:
				var start_index := local_y * width + local_x
				if visited[start_index] or source.get_pixel(left + local_x, top + local_y).a8 <= 127:
					continue
				var component: Array[Vector2i] = []
				var queue: Array[Vector2i] = [Vector2i(local_x, local_y)]
				visited[start_index] = 1
				var queue_index := 0
				while queue_index < queue.size():
					var current := queue[queue_index]
					queue_index += 1
					component.append(current)
					for offset_y in range(-1, 2):
						for offset_x in range(-1, 2):
							var next := current + Vector2i(offset_x, offset_y)
							if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
								continue
							var next_index := next.y * width + next.x
							if not visited[next_index] and source.get_pixel(left + next.x, top + next.y).a8 > 127:
								visited[next_index] = 1
								queue.append(next)
				if component.size() > largest.size():
					largest = component
		for point in largest:
			mask.set_pixel(left + point.x, top + point.y, Color.WHITE)
	return ImageTexture.create_from_image(mask)

func play_animation(animation_name: String, restart := false) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	time_wings.visible = animation_name == "skill_time"
	if restart or _last_state != animation_name:
		animation_player.play(animation_name)
		_last_state = animation_name

func seek_animation(animation_name: String, time_seconds: float) -> void:
	play_animation(animation_name, true)
	animation_player.seek(time_seconds, true)
	animation_player.pause()

func set_outline_background(_background: Color) -> void:
	# Kept as a compatibility hook for deterministic capture scripts. The
	# production shader needs no player/world position or caller-supplied color.
	pass

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
	bool red_fringe = suppress_stray_red && pixel.r > 0.45 && pixel.g < 0.30 && pixel.b < 0.22 && pixel.r > pixel.g * 2.6;
	if (pixel.a < 0.18 || red_fringe) { discard; }
	COLOR = pixel * COLOR;
}
"""
	cutout_material.shader = cutout_shader
	non_hair_material = cutout_material.duplicate() as ShaderMaterial
	non_hair_material.set_shader_parameter("suppress_stray_red", true)
	# Compatibility-safe silhouette copies sit behind every textured part. The
	# authored dark edge stays in the cutout; this adds the same thin contrast
	# halo geometry and fixed dark/light palette to M1 and F1.
	outline_material = ShaderMaterial.new()
	var outline_shader := Shader.new()
	outline_shader.code = """
shader_type canvas_item;
uniform bool suppress_stray_red = false;
uniform vec4 inner_outline : source_color = vec4(0.035, 0.045, 0.070, 1.0);
uniform vec4 outer_outline : source_color = vec4(1.0, 0.98, 0.90, 1.0);
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 region_min = vec2(0.0);
uniform vec2 region_max = vec2(1.0);
float linear_channel(float value) {
	return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4);
}
float relative_luminance(vec3 color) {
	return 0.2126 * linear_channel(color.r) + 0.7152 * linear_channel(color.g) + 0.0722 * linear_channel(color.b);
}
void fragment() {
	float outer_alpha = 0.0;
	// Two-atlas-pixel sampling is subpixel at the 0.10 production art scale
	// and keeps the thin outer ring continuous on both skin silhouettes.
	for (int y = -20; y <= 20; y += 2) {
		for (int x = -20; x <= 20; x += 2) {
			int distance_squared = x * x + y * y;
			if (distance_squared <= 400) {
				vec2 sample_uv = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE;
				if (any(lessThan(sample_uv, region_min)) || any(greaterThanEqual(sample_uv, region_max))) { continue; }
				vec4 neighbour = texture(TEXTURE, sample_uv);
				bool red_fringe = suppress_stray_red && neighbour.r > 0.45 && neighbour.g < 0.30 && neighbour.b < 0.22 && neighbour.r > neighbour.g * 2.6;
				float alpha = red_fringe ? 0.0 : neighbour.a;
				outer_alpha = max(outer_alpha, alpha);
			}
		}
	}
	if (outer_alpha < 0.50) { discard; }
	vec4 background = textureLod(screen_texture, SCREEN_UV, 0.0);
	float background_luminance = relative_luminance(background.rgb);
	float dark_luminance = relative_luminance(inner_outline.rgb);
	float light_luminance = relative_luminance(outer_outline.rgb);
	float dark_contrast = (max(background_luminance, dark_luminance) + 0.05) / (min(background_luminance, dark_luminance) + 0.05);
	float light_contrast = (max(background_luminance, light_luminance) + 0.05) / (min(background_luminance, light_luminance) + 0.05);
	vec4 contrast_outline = light_contrast > dark_contrast ? outer_outline : inner_outline;
	// The painted cutouts retain their authored dark edge. This silhouette copy
	// is the thin contrast halo outside that edge, so every exposed halo pixel
	// follows the same fixed two-color selection rule.
	COLOR = contrast_outline;
}
"""
	outline_material.shader = outline_shader
	outline_non_hair_material = outline_material.duplicate() as ShaderMaterial
	outline_non_hair_material.set_shader_parameter("suppress_stray_red", true)
	skeleton = Node2D.new()
	skeleton.name = "Skeleton"
	skeleton.position = CLIMB_BODY_OFFSET
	skeleton.scale = Vector2(1.12, 1.02)
	skeleton.z_index = 10
	add_child(skeleton)
	var pelvis := _add_bone("pelvis", skeleton, Vector2(0, 15))
	var torso := _add_bone("torso", pelvis, Vector2(0, -15))
	var head := _add_bone("head", torso, Vector2(0, -27))
	var upper_arm_l := _add_bone("upper_arm_l", torso, Vector2(-14.5, 0))
	var upper_arm_r := _add_bone("upper_arm_r", torso, Vector2(14, 0))
	var forearm_l := _add_bone("forearm_l", upper_arm_l, Vector2(0, 14))
	var forearm_r := _add_bone("forearm_r", upper_arm_r, Vector2(0, 14))
	var hand_l := _add_bone("hand_l", forearm_l, Vector2(0, 13))
	var hand_r := _add_bone("hand_r", forearm_r, Vector2(0, 13))
	var thigh_l := _add_bone("thigh_l", pelvis, Vector2(-20, 6))
	var thigh_r := _add_bone("thigh_r", pelvis, Vector2(12.5, 6))
	var shin_l := _add_bone("shin_l", thigh_l, Vector2(0, 19))
	var shin_r := _add_bone("shin_r", thigh_r, Vector2(0, 19))
	var foot_l := _add_bone("foot_l", shin_l, Vector2(0, 18))
	var foot_r := _add_bone("foot_r", shin_r, Vector2(0, 18))
	var accessory := _add_bone("accessory", torso, Vector2(0, 2))
	var wing_anchor := _add_bone("wing_anchor", torso, Vector2(0, -8))

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
	sprite.region_rect = Rect2(
		cell_origin + CELL_CLIP_MARGIN,
		Vector2(CELL_WIDTH - CELL_CLIP_MARGIN.x * 2.0, CELL_HEIGHT - CELL_CLIP_MARGIN.y * 2.0)
	)
	sprite.region_filter_clip_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.material = cutout_material if part_name in ["head_neutral", "head_hurt", "hair_back", "hair_front"] else non_hair_material
	sprite.scale = Vector2.ONE * ART_SCALE
	# Reserve a global band below every textured part for the silhouette copies.
	# This keeps outlines above the world/background without drawing over joints.
	sprite.z_index = z + 20
	parent.add_child(sprite)
	var outline := Sprite2D.new()
	outline.name = part_name + "_outline"
	outline.region_enabled = true
	outline.region_rect = sprite.region_rect
	outline.region_filter_clip_enabled = true
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var part_outline_material := (outline_material if part_name in ["head_neutral", "head_hurt", "hair_back", "hair_front"] else outline_non_hair_material).duplicate() as ShaderMaterial
	part_outline_material.set_shader_parameter("region_min", cell_origin / Vector2(1254.0, 1254.0))
	part_outline_material.set_shader_parameter("region_max", (cell_origin + Vector2(CELL_WIDTH, CELL_HEIGHT)) / Vector2(1254.0, 1254.0))
	outline.material = part_outline_material
	outline.z_index = -20
	sprite.add_child(outline)
	part_sprites[part_name] = sprite
	outline_sprites[part_name] = outline
	return sprite

func _configure_part_pose() -> void:
	# The approved neutral/hurt cells contain the complete identity hair. The
	# separately mounted hair layers remain in the shared contract, but are not
	# composited a second time (which masked faces and duplicated F1's ponytail).
	part_sprites.hair_back.visible = false
	part_sprites.hair_front.visible = false
	# Every art cutout crosses its parent joint. These overlaps are deliberately
	# larger than the bilinear edge fringe so no pose can expose a transparent
	# seam between rigid pieces.
	part_sprites.head_neutral.position = Vector2(-1, 4)
	part_sprites.head_hurt.position = Vector2(-1, 4)
	part_sprites.torso.position = Vector2(0, -7)
	part_sprites.torso.scale = Vector2(ART_SCALE * 1.73, ART_SCALE)
	part_sprites.pelvis.position = Vector2(0, -12)
	part_sprites.pelvis.scale = Vector2(ART_SCALE * 1.73, ART_SCALE)
	for part_name in ["upper_arm_l", "upper_arm_r"]:
		part_sprites[part_name].position = Vector2(0, 1)
		part_sprites[part_name].scale = Vector2.ONE * (ART_SCALE * 1.25)
	for part_name in ["forearm_l", "forearm_r"]:
		part_sprites[part_name].position = Vector2(0, 7)
	for part_name in ["hand_l_open", "hand_r_open", "hand_l_grip", "hand_r_grip"]:
		part_sprites[part_name].position = Vector2(0, 7)
	for part_name in ["thigh_l", "thigh_r"]:
		part_sprites[part_name].position = Vector2(0, 6)
	for part_name in ["shin_l", "shin_r"]:
		part_sprites[part_name].position = Vector2(0, 4)
	for part_name in ["foot_l", "foot_r"]:
		part_sprites[part_name].position = Vector2(0, 8)
	part_sprites.accessory.position = Vector2(0, 5)
	part_sprites.accessory.scale = Vector2.ONE * (ART_SCALE * 0.90)
	part_sprites.wing_anchor.position = Vector2(3, 3)
	part_sprites.wing_anchor.scale = Vector2.ONE * (ART_SCALE * 0.72)
	part_sprites.wing_anchor.visible = false

func _build_time_wings(anchor: Node2D) -> void:
	time_wings = Sprite2D.new()
	time_wings.name = "time_wings"
	time_wings.texture = load(WING_TEXTURE) as Texture2D
	time_wings.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	time_wings.material = cutout_material
	time_wings.z_index = -8
	time_wings.scale = Vector2.ONE * 0.001
	time_wings.visible = false
	anchor.add_child(time_wings)
	var wing_outline := Sprite2D.new()
	wing_outline.name = "time_wings_outline"
	wing_outline.texture = time_wings.texture
	wing_outline.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	wing_outline.material = outline_material
	wing_outline.z_index = -1
	time_wings.add_child(wing_outline)

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
	_add_values(animation, "Skeleton/pelvis/torso:position", [0.0, 0.5, 1.0], [Vector2(0, -15), Vector2(0, -16), Vector2(0, -15)])
	_add_values(animation, "Skeleton/pelvis/torso/head:rotation", [0.0, 0.5, 1.0], [-0.025, 0.025, -0.025])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l:rotation", [0.0, 1.0], [2.90, 2.90])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l/forearm_l:rotation", [0.0, 1.0], [0.05, 0.05])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r:rotation", [0.0, 1.0], [-2.72, -2.72])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r/forearm_r:rotation", [0.0, 1.0], [-0.35, -0.35])
	_add_values(animation, "Skeleton/pelvis/thigh_l:rotation", [0.0, 1.0], [0.55, 0.55])
	_add_values(animation, "Skeleton/pelvis/thigh_l/shin_l:rotation", [0.0, 1.0], [-0.75, -0.75])
	_add_values(animation, "Skeleton/pelvis/thigh_r:rotation", [0.0, 1.0], [-0.55, -0.55])
	_add_values(animation, "Skeleton/pelvis/thigh_r/shin_r:rotation", [0.0, 1.0], [0.75, 0.75])
	_set_grip_tracks(animation, [0.0, 1.0], [true, true])
	return animation

func _make_climb() -> Animation:
	var animation := Animation.new()
	animation.length = 0.8
	animation.loop_mode = Animation.LOOP_LINEAR
	var times := [0.0, 0.2, 0.4, 0.6, 0.8]
	# Four contact poses: one hand/foot pair reaches while the other pair pulls.
	# The root moves only one pixel; locomotion reads as gripping, not bouncing.
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l:rotation", times, [2.90, 3.00, 2.75, 2.72, 2.90])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r:rotation", times, [-2.72, -2.75, -2.90, -3.00, -2.72])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_l/forearm_l:rotation", times, [0.05, 0.00, 0.35, 0.35, 0.05])
	_add_values(animation, "Skeleton/pelvis/torso/upper_arm_r/forearm_r:rotation", times, [-0.35, -0.35, -0.05, 0.00, -0.35])
	_add_values(animation, "Skeleton/pelvis/thigh_l:rotation", times, [0.55, 0.82, 0.78, 0.32, 0.55])
	_add_values(animation, "Skeleton/pelvis/thigh_r:rotation", times, [-0.55, -0.32, -0.38, -0.82, -0.55])
	_add_values(animation, "Skeleton/pelvis/thigh_l/shin_l:rotation", times, [-0.75, -1.30, -1.20, -0.50, -0.75])
	_add_values(animation, "Skeleton/pelvis/thigh_r/shin_r:rotation", times, [0.75, 0.50, 0.55, 1.30, 0.75])
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
	var values := [Vector2(0.003, 0.001), Vector2(0.020, 0.034), Vector2.ONE * 0.045, Vector2(0.043, 0.046)]
	_add_values(animation, "Skeleton/pelvis/torso/wing_anchor/time_wings:scale", times, values)
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
