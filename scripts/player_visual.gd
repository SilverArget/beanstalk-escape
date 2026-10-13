class_name PlayerVisual
extends Node2D

const FRAME_ROOT := "res://assets/art/character_frames"
const HAIR_LUMA_PATH := "res://tools/hair_masks/hair_luma.json"
const WING_TEXTURE := preload("res://assets/art/character_rig/wing/time_wings.png")
const TRANSFER_LEAF_TEXTURE := preload("res://assets/art/fx/transfer_leaf.png")
const ROCK_FIRE_ATLAS := preload("res://assets/art/hazards/rock_fire_atlas.png")
const FAIRY_EFFECT := preload("res://scripts/fairy_effect.gd")
const FRAME_NAMES := ["climb_left", "climb_right", "climb_reach", "hang"]
const SKIN_IDS := ["M1", "M2", "M3", "F1", "F2", "F3"]
const FRAME_RATE := 8.0
const ART_SCALE := 0.49
const BASE_Y := -7.2
const PET_PREVIEW_HEIGHT := 60.0
const PET_PREVIEW_BOUNDS := {}

var skin_id := "M1"
var mode := "hang"
var frame_name := "hang"
var climb_time := 0.0
var hurt_remaining := 0.0
var celebrate_remaining := 0.0
var death_offset := 0.0
var last_penalty := 0
var frame_textures: Dictionary = {}
var sprite: Sprite2D
var time_wings: Sprite2D
var fire_wings: Sprite2D
var takeoff_particles: CPUParticles2D
var transfer_trails: Array[Line2D] = []
var fire_trails: Array[Polygon2D] = []
var flash_material: ShaderMaterial
var cosmetic_sprites: Dictionary = {}
var equipped_cosmetics := {"HAIR": "", "OUTFIT": "", "EMBLEM": "", "PET": "", "TRAIL": ""}
var cosmetic_data: Dictionary = {}
var anchor_data: Dictionary = {}
var outfit_masks: Dictionary = {}
var hair_masks: Dictionary = {}
var hair_luma_data: Dictionary = {}
var frame_metrics: Dictionary = {}
var fairy_effect: FairyEffect
var pet_preview_time := 0.0
var pet_preview_scale := Vector2.ONE
var _was_transferring := false
var _transfer_trail_alpha := 0.0
var _last_transfer_direction := 1.0

func _ready() -> void:
	_build_visual()
	_load_hair_luma()
	_load_skin(OS.get_environment("BEANSTALK_SKIN"))
	_set_frame("hang")

func _process(delta: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var penalty_count := player.bean_penalty_count + player.rock_penalty_count
	if penalty_count != last_penalty:
		last_penalty = penalty_count
		hurt_remaining = 0.32
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	celebrate_remaining = maxf(celebrate_remaining - delta, 0.0)
	time_wings.visible = player.time_wings_active
	fire_wings.visible = player.fire_wings_active
	for trail in fire_trails: trail.visible = player.fire_wings_active
	if time_wings.visible:
		var wing_pulse := sin(Time.get_ticks_msec() * 0.010) * 0.002
		time_wings.scale = Vector2(0.045 + wing_pulse, 0.045 - wing_pulse * 0.5)
	if fire_wings.visible:
		var fire_pulse := sin(Time.get_ticks_msec() * 0.014) * 0.008
		fire_wings.scale = Vector2(0.32 + fire_pulse, 0.32 - fire_pulse * 0.35)
		for index in fire_trails.size():
			fire_trails[index].modulate.a = 0.55 + 0.18 * sin(Time.get_ticks_msec() * 0.018 + float(index) * PI)
	_update_mode(player, delta)
	flash_material.set_shader_parameter("flash_amount", 0.78 if hurt_remaining > 0.18 else 0.0)
	_update_cosmetic_anchors()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_1:
		set_skin("M1")
	elif event.physical_keycode == KEY_2:
		set_skin("F1")

func _update_mode(player: PlayerController, delta: float) -> void:
	var game := player.get_parent()
	var app_state := int(game.get("app_state")) if game != null else GameManager.AppState.MENU
	if app_state == GameManager.AppState.PAUSED:
		return
	if app_state in [GameManager.AppState.MENU, GameManager.AppState.INTRO, GameManager.AppState.SHOP, GameManager.AppState.CHARACTER_SELECT, GameManager.AppState.MAP, GameManager.AppState.SETTINGS, GameManager.AppState.CREDITS]:
		_set_mode("menu", "hang")
	elif app_state == GameManager.AppState.PLAYER_DEAD:
		if mode != "death":
			death_offset = 0.0
		death_offset = minf(death_offset + delta * 76.0, 92.0)
		_set_mode("death", "fall")
		sprite.position = Vector2(0.0, BASE_Y + death_offset)
	elif player.support_state == PlayerController.SupportState.TRANSFERRING:
		var direction := signf(Balance.ROUTE_X[player.transition_to] - Balance.ROUTE_X[player.transition_from])
		scale.x = absf(scale.x) * (-1.0 if direction < 0.0 else 1.0)
		_last_transfer_direction = direction
		if not _was_transferring:
			takeoff_particles.restart()
			takeoff_particles.emitting = true
		_was_transferring = true
		_set_mode("jump", "jump")
	elif app_state == GameManager.AppState.GAME_COMPLETE or celebrate_remaining > 0.0:
		_set_mode("celebrate", "cheer")
	elif hurt_remaining > 0.0:
		_set_mode("hurt", "hurt")
	elif player.support_state == PlayerController.SupportState.FALLING_RECOVERY:
		_set_mode("fall", "fall")
	else:
		mode = "climb"
		climb_time += delta * FRAME_RATE
		var frame_index := int(floor(climb_time)) % FRAME_NAMES.size()
		_set_frame(FRAME_NAMES[frame_index])
		# A full alternating hand cycle yields a clearly readable 3.5 px body lift.
		sprite.position = Vector2(0.0, BASE_Y - 3.5 * absf(sin(climb_time * PI * 0.5)))
	if player.support_state != PlayerController.SupportState.TRANSFERRING:
		scale.x = absf(scale.x)
		_was_transferring = false
	_update_transfer_trails(player.support_state == PlayerController.SupportState.TRANSFERRING, delta)

func _update_transfer_trails(transferring: bool, delta: float) -> void:
	if transferring:
		_transfer_trail_alpha = 1.0
	else:
		_transfer_trail_alpha = maxf(_transfer_trail_alpha - delta / 0.28, 0.0)
	for trail in transfer_trails:
		# The whole body is mirrored in flight. Preserve that world-space side
		# while the residual trail fades after the body returns to +X scale.
		trail.scale.x = 1.0 if transferring else _last_transfer_direction
		trail.modulate.a = _transfer_trail_alpha
		trail.visible = _transfer_trail_alpha > 0.0

func _set_mode(new_mode: String, requested_frame: String) -> void:
	if mode != new_mode:
		mode = new_mode
		sprite.position = Vector2(0.0, BASE_Y)
	_set_frame(requested_frame)

func _set_frame(requested_frame: String) -> void:
	if frame_name == requested_frame and sprite.texture != null:
		return
	frame_name = requested_frame
	sprite.texture = frame_textures.get(requested_frame) as Texture2D
	flash_material.set_shader_parameter("outfit_mask_texture", outfit_masks.get(requested_frame))
	flash_material.set_shader_parameter("hair_mask_texture", hair_masks.get(requested_frame))
	var luma: Dictionary = hair_luma_data.get(skin_id.to_lower(), {}).get(requested_frame, {})
	flash_material.set_shader_parameter("hair_luma_min", float(luma.get("p5", 0.0)))
	flash_material.set_shader_parameter("hair_luma_max", float(luma.get("p95", 1.0)))
	_update_cosmetic_anchors()

func set_skin(requested_skin: String) -> bool:
	var normalized := requested_skin.to_upper()
	if normalized not in SKIN_IDS or not _skin_exists(normalized):
		return false
	_load_skin(normalized)
	return true

func _load_skin(requested_skin: String) -> void:
	var normalized := requested_skin.to_upper()
	skin_id = normalized if normalized in SKIN_IDS and _skin_exists(normalized) else "M1"
	frame_textures.clear()
	frame_metrics.clear()
	outfit_masks.clear()
	hair_masks.clear()
	for requested_frame in ["climb_left", "climb_right", "climb_reach", "jump", "hurt", "fall", "cheer", "hang", "front"]:
		var frame_texture := load("%s/%s/%s.png" % [FRAME_ROOT, skin_id.to_lower(), requested_frame]) as Texture2D
		frame_textures[requested_frame] = frame_texture
		# Keep the WebGL path GPU-only: texture readback emits INVALID_OPERATION on
		# some compatibility renderers while the shop preview is being rebuilt.
		var texture_size := frame_texture.get_size()
		frame_metrics[requested_frame] = {
			"texture_size": texture_size,
			"used": Rect2i(Vector2i.ZERO, Vector2i(int(texture_size.x), int(texture_size.y * 0.75))),
		}
		var mask_path := "%s/%s/%s_outfit_mask.png" % [FRAME_ROOT, skin_id.to_lower(), requested_frame]
		if ResourceLoader.exists(mask_path):
			outfit_masks[requested_frame] = load(mask_path)
		var hair_mask_path := "%s/%s/%s_hair_mask.png" % [FRAME_ROOT, skin_id.to_lower(), requested_frame]
		if ResourceLoader.exists(hair_mask_path):
			hair_masks[requested_frame] = load(hair_mask_path)
	_load_anchors()
	var current := frame_name
	frame_name = ""
	_set_frame(current)

func _skin_exists(requested_skin: String) -> bool:
	return ResourceLoader.exists("%s/%s/hang.png" % [FRAME_ROOT, requested_skin.to_lower()])

func _load_hair_luma() -> void:
	hair_luma_data.clear()
	var file := FileAccess.open(HAIR_LUMA_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		hair_luma_data = (parsed as Dictionary).get("skins", {}).duplicate(true)

func _load_anchors() -> void:
	anchor_data.clear()
	var path := "%s/%s/anchors.json" % [FRAME_ROOT, skin_id.to_lower()]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		anchor_data = (parsed as Dictionary).get("frames", {}).duplicate(true)

func set_cosmetics(equipped: Dictionary, catalog: Array) -> void:
	equipped_cosmetics = equipped.duplicate(true)
	cosmetic_data.clear()
	for item in catalog:
		cosmetic_data[str(item.get("id", ""))] = item
	for slot in ["EMBLEM", "PET", "TRAIL"]:
		var item_id := str(equipped_cosmetics.get(slot, ""))
		var layer := cosmetic_sprites.get(slot) as Sprite2D
		if layer == null:
			continue
		layer.visible = not item_id.is_empty() and cosmetic_data.has(item_id)
		if layer.visible:
			var image_name := str(cosmetic_data[item_id].get("image", ""))
			var art_folder := "pets" if slot == "PET" else "cosmetics"
			layer.texture = load("res://assets/art/%s/%s" % [art_folder, image_name])
			if slot == "PET" and layer.texture != null:
				var preview_bounds: Rect2 = PET_PREVIEW_BOUNDS.get(image_name, Rect2(Vector2.ZERO, layer.texture.get_size()))
				var pet_scale := PET_PREVIEW_HEIGHT / maxf(preview_bounds.size.y, 1.0)
				layer.scale = Vector2.ONE * pet_scale
				pet_preview_scale = layer.scale
	if fairy_effect != null:
		var pet_id := str(equipped_cosmetics.get("PET", ""))
		fairy_effect.configure(cosmetic_data.get(pet_id, {}))
	_update_cosmetic_anchors()
	var outfit_id := str(equipped_cosmetics.get("OUTFIT", ""))
	var outfit_enabled := not outfit_id.is_empty() and cosmetic_data.has(outfit_id)
	flash_material.set_shader_parameter("outfit_enabled", 1.0 if outfit_enabled else 0.0)
	if outfit_enabled:
		flash_material.set_shader_parameter("outfit_color", Color(str(cosmetic_data[outfit_id].get("tint", "ffffff"))))
	var hair_id := str(equipped_cosmetics.get("HAIR", ""))
	var hair_enabled := not hair_id.is_empty() and cosmetic_data.has(hair_id)
	flash_material.set_shader_parameter("hair_enabled", 1.0 if hair_enabled else 0.0)
	if hair_enabled:
		var ramp: Array = cosmetic_data[hair_id].get("ramp", [])
		if ramp.size() == 3:
			flash_material.set_shader_parameter("hair_shadow_color", Color(str(ramp[0])))
			flash_material.set_shader_parameter("hair_mid_color", Color(str(ramp[1])))
			flash_material.set_shader_parameter("hair_highlight_color", Color(str(ramp[2])))

func preview_cosmetic(item: Dictionary) -> void:
	var preview := equipped_cosmetics.duplicate(true)
	if not item.is_empty():
		preview[str(item.get("slot", ""))] = str(item.get("id", ""))
	set_cosmetics(preview, cosmetic_data.values())

func _update_cosmetic_anchors() -> void:
	if sprite.texture == null:
		return
	var metrics: Dictionary = frame_metrics.get(frame_name, {})
	var used: Rect2i = metrics.get("used", Rect2i())
	if used.size == Vector2i.ZERO:
		return
	var texture_size := Vector2(metrics.get("texture_size", sprite.texture.get_size()))
	var frame_anchor: Dictionary = anchor_data.get(frame_name, {})
	var center_data: Array = frame_anchor.get("head_center", [float(used.get_center().x), float(used.position.y) + float(used.size.y) * 0.25])
	var head_center := Vector2(float(center_data[0]), float(center_data[1]))
	var head_width := float(frame_anchor.get("head_width", float(used.size.x) * 0.42))
	var source_to_local := func(source_point: Vector2) -> Vector2:
		return sprite.position + (source_point - texture_size * 0.5) * ART_SCALE
	var emblem := cosmetic_sprites.get("EMBLEM") as Sprite2D
	var pet := cosmetic_sprites.get("PET") as Sprite2D
	var trail := cosmetic_sprites.get("TRAIL") as Sprite2D
	var emblem_data: Array = frame_anchor.get("emblem_center", [head_center.x, head_center.y + head_width * 1.65])
	emblem.position = source_to_local.call(Vector2(float(emblem_data[0]), float(emblem_data[1])))
	trail.position = source_to_local.call(Vector2(head_center.x, float(used.end.y) - float(used.size.y) * 0.08))
	var pet_data: Array = frame_anchor.get("pet_anchor", [])
	if frame_name == "front" and pet_data.size() == 2 and pet.texture != null:
		var pet_bottom_left: Vector2 = source_to_local.call(Vector2(float(pet_data[0]), float(pet_data[1])))
		var pet_id := str(equipped_cosmetics.get("PET", ""))
		var image_name := str(cosmetic_data.get(pet_id, {}).get("image", ""))
		var preview_bounds: Rect2 = PET_PREVIEW_BOUNDS.get(image_name, Rect2(Vector2.ZERO, pet.texture.get_size()))
		var visible_top_left_offset := (preview_bounds.position - pet.texture.get_size() * 0.5) * pet.scale
		pet.position = pet_bottom_left - Vector2(0.0, preview_bounds.size.y * pet.scale.y) - visible_top_left_offset
	else:
		pet.position = source_to_local.call(Vector2(head_center.x + head_width * 1.65, head_center.y + head_width * 1.75))
	pet.visible = pet.texture != null and not str(equipped_cosmetics.get("PET", "")).is_empty() and frame_name == "front"
	if fairy_effect != null:
		fairy_effect.position = pet.position
		fairy_effect.visible = pet.visible and not fairy_effect.effect_name.is_empty()
	if emblem.texture != null:
		var emblem_width := float(frame_anchor.get("emblem_width", head_width * 0.85))
		var emblem_scale := emblem_width * ART_SCALE / maxf(float(emblem.texture.get_width()), 1.0)
		emblem.scale = Vector2.ONE * emblem_scale

func play_celebration() -> void:
	celebrate_remaining = 0.75

func preview_tick(delta: float) -> void:
	pet_preview_time += delta
	show_front_preview()
	var pet := cosmetic_sprites.get("PET") as Sprite2D
	if pet != null and pet.visible:
		var bob := sin(pet_preview_time * 4.8) * 2.5
		var wing_pulse := sin(pet_preview_time * 16.0) * 0.045
		pet.position.y += bob
		pet.scale = pet_preview_scale * Vector2(1.0 + wing_pulse, 1.0 - wing_pulse * 0.55)
		fairy_effect.position = pet.position

func show_front_preview() -> void:
	_set_frame("front")
	sprite.position = Vector2(0.0, BASE_Y)
	_update_cosmetic_anchors()

func visual_snapshot() -> Dictionary:
	return {"mode": mode, "frame": frame_name, "skin": skin_id}

func _build_visual() -> void:
	takeoff_particles = CPUParticles2D.new()
	takeoff_particles.name = "TransferTakeoffTrail"
	takeoff_particles.amount = 7
	takeoff_particles.lifetime = maxf(Balance.BRANCH_TRANSITION_SECONDS, 0.30)
	takeoff_particles.one_shot = true
	takeoff_particles.explosiveness = 0.92
	takeoff_particles.local_coords = false
	takeoff_particles.texture = TRANSFER_LEAF_TEXTURE
	takeoff_particles.direction = Vector2(-1.0, -0.15)
	takeoff_particles.spread = 20.0
	takeoff_particles.gravity = Vector2(0.0, 24.0)
	takeoff_particles.initial_velocity_min = 58.0
	takeoff_particles.initial_velocity_max = 82.0
	takeoff_particles.scale_amount_min = 0.04
	takeoff_particles.scale_amount_max = 0.055
	takeoff_particles.angle_min = -28.0
	takeoff_particles.angle_max = 28.0
	takeoff_particles.angular_velocity_min = -160.0
	takeoff_particles.angular_velocity_max = 160.0
	takeoff_particles.color = Color(0.56, 0.82, 0.31, 0.92)
	takeoff_particles.position = Vector2(-5.0, 23.0)
	takeoff_particles.z_index = -3
	takeoff_particles.emitting = false
	add_child(takeoff_particles)
	_build_transfer_motion_trails()
	fire_wings = Sprite2D.new()
	fire_wings.name = "FireWings"
	var fire_texture := AtlasTexture.new()
	fire_texture.atlas = ROCK_FIRE_ATLAS
	fire_texture.region = Rect2(1024, 512, 512, 512)
	fire_wings.texture = fire_texture
	fire_wings.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	fire_wings.position = Vector2(0.0, -12.0)
	fire_wings.scale = Vector2.ONE * 0.32
	fire_wings.z_index = -1
	fire_wings.visible = false
	add_child(fire_wings)
	for side in [-1.0, 1.0]:
		var trail := Polygon2D.new()
		trail.polygon = PackedVector2Array([Vector2(side * 22.0, -19.0), Vector2(side * 58.0, -7.0), Vector2(side * 30.0, 5.0), Vector2(side * 16.0, 2.0)])
		trail.color = Color("ff8a24")
		trail.modulate.a = 0.65
		trail.z_index = -2
		trail.visible = false
		add_child(trail)
		fire_trails.append(trail)
	time_wings = Sprite2D.new()
	time_wings.name = "TimeWings"
	time_wings.texture = WING_TEXTURE
	time_wings.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	time_wings.position = Vector2(0.0, -13.0)
	time_wings.scale = Vector2.ONE * 0.045
	time_wings.z_index = -1
	time_wings.visible = false
	add_child(time_wings)
	sprite = Sprite2D.new()
	sprite.name = "FullBodyFrame"
	sprite.position = Vector2(0.0, BASE_Y)
	sprite.scale = Vector2.ONE * ART_SCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	flash_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float outfit_enabled : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outfit_color : source_color = vec4(1.0);
uniform sampler2D outfit_mask_texture : filter_linear;
uniform float hair_enabled : hint_range(0.0, 1.0) = 0.0;
uniform vec4 hair_shadow_color : source_color = vec4(0.05, 0.035, 0.027, 1.0);
uniform vec4 hair_mid_color : source_color = vec4(0.17, 0.11, 0.086, 1.0);
uniform vec4 hair_highlight_color : source_color = vec4(0.36, 0.27, 0.21, 1.0);
uniform float hair_luma_min = 0.0;
uniform float hair_luma_max = 1.0;
uniform sampler2D hair_mask_texture : filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.035, 0.043, 0.071, 1.0);
uniform float outline_source_px = 4.1;
uniform vec2 shadow_source_offset = vec2(0.0, 7.0);
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	vec2 step_size = TEXTURE_PIXEL_SIZE * outline_source_px;
	float outline_alpha = 0.0;
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + step_size * 0.707).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV - step_size * 0.707).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(step_size.x, -step_size.y) * 0.707).a);
	outline_alpha = max(outline_alpha, texture(TEXTURE, UV + vec2(-step_size.x, step_size.y) * 0.707).a);
	vec2 shadow_uv = UV - TEXTURE_PIXEL_SIZE * shadow_source_offset;
	vec2 blur = TEXTURE_PIXEL_SIZE * 3.0;
	float shadow_alpha = (
		texture(TEXTURE, shadow_uv).a
		+ texture(TEXTURE, shadow_uv + vec2(blur.x, 0.0)).a
		+ texture(TEXTURE, shadow_uv - vec2(blur.x, 0.0)).a
		+ texture(TEXTURE, shadow_uv + vec2(0.0, blur.y)).a
		+ texture(TEXTURE, shadow_uv - vec2(0.0, blur.y)).a
	) * 0.056;
	float border_alpha = max(outline_alpha - pixel.a, 0.0);
	float backdrop_alpha = max(border_alpha, shadow_alpha * (1.0 - outline_alpha));
	vec3 backdrop_color = mix(vec3(0.02, 0.025, 0.035), outline_color.rgb, step(shadow_alpha, border_alpha));
	// Offline masks isolate the original garment pixels for every skin/pose.
	// Hair, skin, face, gloves, boots, bag and the dark outline remain untouched.
	float cloth_mask = texture(outfit_mask_texture, UV).a * outfit_enabled * pixel.a;
	float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	vec3 dyed = outfit_color.rgb * mix(0.42, 1.34, luminance);
	vec3 outfitted_rgb = mix(pixel.rgb, dyed, cloth_mask * 0.90);
	// Normalize every skin/pose independently, then recolor through a three-stop ramp.
	float hair_mask = texture(hair_mask_texture, UV).a * hair_enabled * pixel.a;
	float normalized_luma = clamp((luminance - hair_luma_min) / max(hair_luma_max - hair_luma_min, 0.001), 0.0, 1.0);
	normalized_luma = smoothstep(0.0, 1.0, normalized_luma);
	vec3 dyed_hair = normalized_luma < 0.5
		? mix(hair_shadow_color.rgb, hair_mid_color.rgb, normalized_luma * 2.0)
		: mix(hair_mid_color.rgb, hair_highlight_color.rgb, (normalized_luma - 0.5) * 2.0);
	vec3 recolored_rgb = mix(outfitted_rgb, dyed_hair, hair_mask);
	vec3 flashed_rgb = mix(recolored_rgb, vec3(1.0), flash_amount);
	COLOR = vec4(mix(backdrop_color, flashed_rgb, pixel.a), max(pixel.a, backdrop_alpha));
}
"""
	flash_material.shader = shader
	sprite.material = flash_material
	add_child(sprite)
	for slot in ["TRAIL", "EMBLEM", "PET"]:
		var layer := Sprite2D.new()
		layer.name = "%sCosmetic" % slot.capitalize()
		layer.centered = true
		layer.scale = Vector2.ONE * (0.13 if slot == "EMBLEM" else 0.17)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.z_index = -2 if slot == "TRAIL" else 2
		layer.modulate.a = 0.68 if slot == "TRAIL" else 1.0
		layer.visible = false
		add_child(layer)
		cosmetic_sprites[slot] = layer
	fairy_effect = FAIRY_EFFECT.new()
	fairy_effect.name = "FairyEffect"
	fairy_effect.z_index = 1
	fairy_effect.visible = false
	add_child(fairy_effect)

func _build_transfer_motion_trails() -> void:
	var paths := [
		PackedVector2Array([Vector2(-7, 5), Vector2(-22, 1), Vector2(-39, 8), Vector2(-57, 3)]),
		PackedVector2Array([Vector2(-8, 15), Vector2(-23, 11), Vector2(-37, 17), Vector2(-52, 13)]),
		PackedVector2Array([Vector2(-6, 25), Vector2(-18, 21), Vector2(-31, 26), Vector2(-46, 22)]),
	]
	var colors := [Color(0.94, 1.0, 0.88, 0.94), Color(0.78, 0.94, 0.61, 0.92), Color(0.90, 1.0, 0.80, 0.88)]
	for index in paths.size():
		var trail := Line2D.new()
		trail.name = "TransferMotionTrail%d" % (index + 1)
		trail.points = paths[index]
		trail.width = 4.0 - float(index) * 0.4
		trail.default_color = colors[index]
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.joint_mode = Line2D.LINE_JOINT_ROUND
		trail.antialiased = true
		trail.z_index = -4
		trail.visible = false
		add_child(trail)
		transfer_trails.append(trail)
