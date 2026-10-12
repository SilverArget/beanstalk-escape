class_name PlayerVisual
extends Node2D

const FRAME_ROOT := "res://assets/art/character_frames"
const WING_TEXTURE := preload("res://assets/art/character_rig/wing/time_wings.png")
const FRAME_NAMES := ["climb_left", "climb_right", "climb_reach", "hang"]
const FRAME_RATE := 8.0
const ART_SCALE := 0.49
const BASE_Y := -7.2

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
var flash_material: ShaderMaterial

func _ready() -> void:
	_build_visual()
	_load_skin(OS.get_environment("BEANSTALK_SKIN"))
	_set_frame("hang")

func _process(delta: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	if player.bean_penalty_count != last_penalty:
		last_penalty = player.bean_penalty_count
		hurt_remaining = 0.32
	hurt_remaining = maxf(hurt_remaining - delta, 0.0)
	celebrate_remaining = maxf(celebrate_remaining - delta, 0.0)
	time_wings.visible = player.time_wings_active
	if time_wings.visible:
		var wing_pulse := sin(Time.get_ticks_msec() * 0.010) * 0.002
		time_wings.scale = Vector2(0.045 + wing_pulse, 0.045 - wing_pulse * 0.5)
	_update_mode(player, delta)
	flash_material.set_shader_parameter("flash_amount", 0.78 if hurt_remaining > 0.18 else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.physical_keycode == KEY_1:
		set_skin("M1")
	elif event.physical_keycode == KEY_2:
		set_skin("F1")

func _update_mode(player: PlayerController, delta: float) -> void:
	var game := player.get_parent()
	var app_state := int(game.get("app_state")) if game != null else 1
	if app_state == 0:
		_set_mode("menu", "hang")
	elif app_state == 3:
		if mode != "death":
			death_offset = 0.0
		death_offset = minf(death_offset + delta * 76.0, 92.0)
		_set_mode("death", "fall")
		sprite.position = Vector2(0.0, BASE_Y + death_offset)
	elif app_state == 4 or celebrate_remaining > 0.0:
		_set_mode("celebrate", "cheer")
	elif hurt_remaining > 0.0:
		_set_mode("hurt", "hurt")
	elif player.support_state == PlayerController.SupportState.FALLING_RECOVERY:
		_set_mode("fall", "fall")
	elif player.support_state == PlayerController.SupportState.TRANSFERRING:
		_set_mode("jump", "jump")
	else:
		mode = "climb"
		climb_time += delta * FRAME_RATE
		var frame_index := int(floor(climb_time)) % FRAME_NAMES.size()
		_set_frame(FRAME_NAMES[frame_index])
		# A full alternating hand cycle yields a clearly readable 3.5 px body lift.
		sprite.position = Vector2(0.0, BASE_Y - 3.5 * absf(sin(climb_time * PI * 0.5)))

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

func set_skin(requested_skin: String) -> bool:
	var normalized := requested_skin.to_upper()
	if normalized not in ["M1", "F1"]:
		return false
	_load_skin(normalized)
	return true

func _load_skin(requested_skin: String) -> void:
	var normalized := requested_skin.to_upper()
	skin_id = normalized if normalized in ["M1", "F1"] else "M1"
	frame_textures.clear()
	for requested_frame in ["climb_left", "climb_right", "climb_reach", "jump", "hurt", "fall", "cheer", "hang"]:
		frame_textures[requested_frame] = load("%s/%s/%s.png" % [FRAME_ROOT, skin_id.to_lower(), requested_frame])
	var current := frame_name
	frame_name = ""
	_set_frame(current)

func play_celebration() -> void:
	celebrate_remaining = 0.75

func visual_snapshot() -> Dictionary:
	return {"mode": mode, "frame": frame_name, "skin": skin_id}

func _build_visual() -> void:
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
