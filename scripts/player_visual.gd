class_name PlayerVisual
extends Node2D

const FRAME_ROOT := "res://assets/art/character_frames"
const WING_TEXTURE := preload("res://assets/art/character_rig/wing/time_wings.png")
const TRANSFER_LEAF_TEXTURE := preload("res://assets/art/fx/transfer_leaf.png")
const ROCK_FIRE_ATLAS := preload("res://assets/art/hazards/rock_fire_atlas.png")
const FAIRY_EFFECT := preload("res://scripts/fairy_effect.gd")
const OUTFIT_EFFECT := preload("res://scripts/outfit_effect.gd")
const OUTFIT_ROOT := "res://assets/art/outfits"
const OUTFIT_BACK_BOUNDS := {
	"outfit_moss": Rect2(79, 99, 105, 74), "outfit_fern": Rect2(77, 96, 104, 76),
	"outfit_sky": Rect2(79, 104, 104, 65), "outfit_ocean": Rect2(71, 95, 115, 72),
	"outfit_plum": Rect2(70, 100, 116, 77), "outfit_ember": Rect2(85, 84, 86, 104),
	"outfit_clay": Rect2(73, 94, 105, 89), "outfit_sun": Rect2(72, 90, 113, 91),
	"outfit_night": Rect2(87, 63, 91, 147),
}
const OUTFIT_FRONT_WIDTHS := {
	"outfit_moss": 182.0, "outfit_fern": 182.0, "outfit_sky": 182.0,
	"outfit_ocean": 182.0, "outfit_plum": 182.0, "outfit_ember": 183.0,
	"outfit_clay": 191.0, "outfit_sun": 184.0, "outfit_night": 287.0,
}
const BACK_FRAME_WIDTHS := {
	"climb_left": 109.0, "climb_right": 108.0, "climb_reach": 106.0,
	"hang": 112.0, "jump": 189.0, "hurt": 129.0, "fall": 191.0, "cheer": 136.0,
}
const FRAME_NAMES := ["climb_left", "climb_right", "climb_reach", "hang"]
const SKIN_IDS := ["M1", "M2", "M3", "F1", "F2", "F3"]
const FRAME_RATE := 8.0
const ART_SCALE := 0.49
const BASE_Y := -7.2
const TIME_WINGS_TARGET_SCALE := 0.72
const TIME_WINGS_REVEAL_SECONDS := 0.18
# Normalized source clasp position, independent of the texture import size.
const TIME_WING_ROOT_UV := Vector2(707.0 / 1415.0, 584.0 / 1111.0)
const FIRE_WING_ROOT := Vector2(256, 320) # Relative to the 512 x 512 atlas region.
# Original trail coordinates relative to the fire clasp at its base scale.
const FIRE_TRAIL_ROOT := Vector2(0, -12) + (FIRE_WING_ROOT - Vector2(256, 256)) * 0.32
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
var equipped_cosmetics := {"OUTFIT": "", "PET": ""}
var cosmetic_data: Dictionary = {}
var anchor_data: Dictionary = {}
var frame_metrics: Dictionary = {}
var fairy_effect: FairyEffect
var outfit_aura: OutfitEffect
var outfit_effect: OutfitEffect
var outfit_back_sprite: Sprite2D
var outfit_front_texture: Texture2D
var pet_preview_time := 0.0
var pet_preview_scale := Vector2.ONE
var _was_transferring := false
var _transfer_trail_alpha := 0.0
var _last_transfer_direction := 1.0
var _time_wings_reveal := 0.0
var _time_wings_was_active := false

func _ready() -> void:
	_build_visual()
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
	if player.time_wings_active and not _time_wings_was_active:
		_time_wings_reveal = 0.0
	if player.time_wings_active:
		_time_wings_reveal = minf(_time_wings_reveal + delta / TIME_WINGS_REVEAL_SECONDS, 1.0)
		var reveal := smoothstep(0.0, 1.0, _time_wings_reveal)
		var wing_pulse := sin(Time.get_ticks_msec() * 0.010) * 0.003
		var reveal_scale := TIME_WINGS_TARGET_SCALE * lerpf(0.70, 1.0, reveal)
		time_wings.scale = Vector2(reveal_scale + wing_pulse, reveal_scale - wing_pulse * 0.5)
		time_wings.modulate.a = reveal
		time_wings.visible = true
	else:
		_time_wings_reveal = 0.0
		time_wings.modulate.a = 0.0
		time_wings.visible = false
	_time_wings_was_active = player.time_wings_active
	fire_wings.visible = player.fire_wings_active
	for trail in fire_trails: trail.visible = player.fire_wings_active
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
	if app_state in [GameManager.AppState.MENU, GameManager.AppState.INTRO, GameManager.AppState.SHOP, GameManager.AppState.CHARACTER_SELECT, GameManager.AppState.MAP, GameManager.AppState.CREDITS]:
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
	var requested_texture := frame_textures.get(requested_frame) as Texture2D
	if requested_frame == "front" and outfit_front_texture != null:
		requested_texture = outfit_front_texture
	if frame_name == requested_frame and sprite.texture == requested_texture:
		return
	frame_name = requested_frame
	sprite.texture = requested_texture
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
	_load_anchors()
	_load_outfit_art()
	var current := frame_name
	frame_name = ""
	_set_frame(current)

func _skin_exists(requested_skin: String) -> bool:
	return ResourceLoader.exists("%s/%s/hang.png" % [FRAME_ROOT, requested_skin.to_lower()])

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
	for slot in ["PET"]:
		var item_id := str(equipped_cosmetics.get(slot, ""))
		var layer := cosmetic_sprites.get(slot) as Sprite2D
		if layer == null:
			continue
		layer.visible = not item_id.is_empty() and cosmetic_data.has(item_id)
		if layer.visible:
			var image_name := str(cosmetic_data[item_id].get("image", ""))
			var art_folder := "pets"
			var art_path := "res://assets/art/%s/%s" % [art_folder, image_name]
			layer.texture = load(art_path)
			if slot == "PET" and layer.texture != null:
				var preview_bounds: Rect2 = PET_PREVIEW_BOUNDS.get(image_name, Rect2(Vector2.ZERO, layer.texture.get_size()))
				var pet_scale := PET_PREVIEW_HEIGHT / maxf(preview_bounds.size.y, 1.0)
				layer.scale = Vector2.ONE * pet_scale
				pet_preview_scale = layer.scale
	if fairy_effect != null:
		var pet_id := str(equipped_cosmetics.get("PET", ""))
		fairy_effect.configure(cosmetic_data.get(pet_id, {}))
	_load_outfit_art()
	var current := frame_name
	frame_name = ""
	_set_frame(current)

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
	var wing_anchor_data: Array = frame_anchor.get("outfit_back", [head_center.x, head_center.y + head_width * 0.38])
	var wing_anchor: Vector2 = source_to_local.call(Vector2(float(wing_anchor_data[0]), float(wing_anchor_data[1])))
	time_wings.position = wing_anchor
	fire_wings.position = wing_anchor
	for trail in fire_trails:
		trail.position = wing_anchor
	var pet := cosmetic_sprites.get("PET") as Sprite2D
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
	if outfit_back_sprite != null:
		var outfit_anchor_data: Array = frame_anchor.get("outfit_back", [head_center.x, head_center.y + head_width * 0.38, head_width * 1.45])
		var back_outfit_id := str(equipped_cosmetics.get("OUTFIT", ""))
		var art_bounds: Rect2 = OUTFIT_BACK_BOUNDS.get(back_outfit_id, Rect2(64, 64, 128, 128))
		var target_width := float(outfit_anchor_data[2]) if outfit_anchor_data.size() >= 3 else head_width * 1.45
		var art_scale := ART_SCALE * target_width / maxf(art_bounds.size.x, 1.0)
		var shoulder: Vector2 = source_to_local.call(Vector2(float(outfit_anchor_data[0]), float(outfit_anchor_data[1])))
		var visible_center_x := art_bounds.get_center().x - float(outfit_back_sprite.texture.get_width()) * 0.5 if outfit_back_sprite.texture != null else 0.0
		var visible_top_y := art_bounds.position.y - float(outfit_back_sprite.texture.get_height()) * 0.5 if outfit_back_sprite.texture != null else 0.0
		outfit_back_sprite.position = shoulder - Vector2(visible_center_x, visible_top_y) * art_scale
		outfit_back_sprite.scale = Vector2.ONE * art_scale
		outfit_back_sprite.visible = outfit_back_sprite.texture != null and frame_name != "front"
	var outfit_id := str(equipped_cosmetics.get("OUTFIT", ""))
	var effect_width := float(OUTFIT_FRONT_WIDTHS.get(outfit_id, head_width * 1.65)) if frame_name == "front" else float(BACK_FRAME_WIDTHS.get(frame_name, head_width * 1.65))
	var effect_size := Vector2(effect_width * ART_SCALE, (482.0 if frame_name == "front" else texture_size.y * 0.79) * ART_SCALE)
	if outfit_aura != null:
		outfit_aura.position = sprite.position
		outfit_aura.set_body_box(effect_size)
		outfit_aura.visible = not outfit_aura.effect_name.is_empty() and outfit_aura.effect_name == "SUN RAYS"
	if outfit_effect != null:
		outfit_effect.position = sprite.position
		outfit_effect.set_body_box(effect_size)
		outfit_effect.visible = not outfit_effect.effect_name.is_empty()

func play_celebration() -> void:
	celebrate_remaining = 0.75

func preview_tick(delta: float) -> void:
	if outfit_aura != null:
		outfit_aura.set_preview_mode(true)
	if outfit_effect != null:
		outfit_effect.set_preview_mode(true)
	if fairy_effect != null:
		fairy_effect.set_preview_mode(true)
	pet_preview_time += delta
	var preview_bob := sin(pet_preview_time * 3.2) * 5.0
	sprite.position = Vector2(0.0, BASE_Y + preview_bob)
	_update_cosmetic_anchors()
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

func show_back_preview() -> void:
	_set_frame("hang")
	sprite.position = Vector2(0.0, BASE_Y)
	_update_cosmetic_anchors()

func _load_outfit_art() -> void:
	outfit_front_texture = null
	if outfit_back_sprite != null:
		outfit_back_sprite.texture = null
	var outfit_id := str(equipped_cosmetics.get("OUTFIT", ""))
	var item: Dictionary = cosmetic_data.get(outfit_id, {})
	if outfit_id.is_empty() or item.is_empty():
		if outfit_aura != null:
			outfit_aura.configure({}, true)
		if outfit_effect != null:
			outfit_effect.configure({})
		return
	var front_path := "%s/front/%s/%s.png" % [OUTFIT_ROOT, skin_id.to_lower(), outfit_id]
	var back_path := "%s/back/%s.png" % [OUTFIT_ROOT, outfit_id]
	if ResourceLoader.exists(front_path):
		outfit_front_texture = load(front_path) as Texture2D
	if outfit_back_sprite != null and ResourceLoader.exists(back_path):
		outfit_back_sprite.texture = load(back_path) as Texture2D
	if outfit_effect != null:
		outfit_effect.configure(item)
	if outfit_aura != null:
		outfit_aura.configure(item, true)

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
	fire_wings.offset = fire_texture.get_size() * 0.5 - FIRE_WING_ROOT
	fire_wings.scale = Vector2.ONE * 0.32
	fire_wings.z_index = -1
	fire_wings.visible = false
	add_child(fire_wings)
	for side in [-1.0, 1.0]:
		var trail := Polygon2D.new()
		var points := PackedVector2Array([Vector2(side * 22.0, -19.0), Vector2(side * 58.0, -7.0), Vector2(side * 30.0, 5.0), Vector2(side * 16.0, 2.0)])
		for index in points.size():
			points[index] -= FIRE_TRAIL_ROOT
		trail.polygon = points
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
	time_wings.offset = WING_TEXTURE.get_size() * (Vector2(0.5, 0.5) - TIME_WING_ROOT_UV)
	time_wings.scale = Vector2.ONE * TIME_WINGS_TARGET_SCALE * 0.70
	time_wings.z_index = -1
	time_wings.modulate.a = 0.0
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
	vec3 flashed_rgb = mix(pixel.rgb, vec3(1.0), flash_amount);
	COLOR = vec4(mix(backdrop_color, flashed_rgb, pixel.a), max(pixel.a, backdrop_alpha));
}
"""
	flash_material.shader = shader
	sprite.material = flash_material
	add_child(sprite)
	outfit_back_sprite = Sprite2D.new()
	outfit_back_sprite.name = "OutfitBack"
	outfit_back_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	outfit_back_sprite.z_index = 1
	outfit_back_sprite.visible = false
	add_child(outfit_back_sprite)
	for slot in ["PET"]:
		var layer := Sprite2D.new()
		layer.name = "%sCosmetic" % slot.capitalize()
		layer.centered = true
		layer.scale = Vector2.ONE * 0.17
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.z_index = 2
		layer.visible = false
		add_child(layer)
		cosmetic_sprites[slot] = layer
	fairy_effect = FAIRY_EFFECT.new()
	fairy_effect.name = "FairyEffect"
	fairy_effect.z_index = 1
	fairy_effect.visible = false
	add_child(fairy_effect)
	outfit_aura = OUTFIT_EFFECT.new()
	outfit_aura.name = "OutfitAura"
	outfit_aura.z_index = -1
	outfit_aura.visible = false
	add_child(outfit_aura)
	outfit_effect = OUTFIT_EFFECT.new()
	outfit_effect.name = "OutfitEffect"
	outfit_effect.z_index = 2
	outfit_effect.visible = false
	add_child(outfit_effect)
	for slot in ["PET"]:
		(cosmetic_sprites[slot] as Sprite2D).z_index = 3

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
