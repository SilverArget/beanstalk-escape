class_name PetFollower
extends Node2D

const FOLLOW_OFFSET := Vector2(52.0, -10.0)
const FOLLOW_SPEED := 9.0
const TARGET_HEIGHT := 68.0

var target: PlayerController
var cinematic_anchor: Sprite2D
var pet_id := ""
var sprite: Sprite2D
var cinematic_sprite: Sprite2D
var motion_time := 0.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.z_index = 4
	add_child(sprite)

func setup(player: PlayerController, final_character: Sprite2D) -> void:
	target = player
	cinematic_anchor = final_character
	global_position = target.global_position + FOLLOW_OFFSET
	if cinematic_anchor != null:
		cinematic_sprite = Sprite2D.new()
		cinematic_sprite.name = "Pet"
		cinematic_sprite.position = Vector2(-92.0, -18.0)
		cinematic_sprite.z_index = -1
		cinematic_anchor.add_child(cinematic_sprite)
	_update_visibility()

func set_pet(item: Dictionary) -> void:
	pet_id = str(item.get("id", ""))
	var texture: Texture2D
	if not pet_id.is_empty():
		texture = load("res://assets/art/pets/%s" % str(item.get("image", ""))) as Texture2D
	sprite.texture = texture
	_apply_scale(sprite, false)
	if cinematic_sprite != null:
		cinematic_sprite.texture = texture
		_apply_scale(cinematic_sprite, true)
	_update_visibility()

func _process(delta: float) -> void:
	if target == null:
		return
	motion_time += delta
	var death_drop := 0.0
	var body := target.get_node_or_null("Body") as PlayerVisual
	if body != null and body.sprite != null:
		death_drop = maxf(body.sprite.position.y - PlayerVisual.BASE_Y, 0.0)
	var desired := target.global_position + FOLLOW_OFFSET + Vector2(0.0, death_drop)
	global_position = global_position.lerp(desired, 1.0 - exp(-FOLLOW_SPEED * delta))
	sprite.position.y = sin(motion_time * 4.8) * 3.0
	sprite.rotation = sin(motion_time * 3.2) * 0.055
	if cinematic_sprite != null:
		cinematic_sprite.position.y = -18.0 + sin(motion_time * 4.8) * 5.0
		cinematic_sprite.rotation = sin(motion_time * 3.2) * 0.055
	_update_visibility()

func snapshot() -> Dictionary:
	var shown := cinematic_sprite != null and cinematic_sprite.visible
	var point := cinematic_sprite.global_position if shown else global_position
	return {"id": pet_id, "visible": shown or sprite.visible, "x": point.x, "y": point.y}

func _apply_scale(target_sprite: Sprite2D, inside_scaled_parent: bool) -> void:
	if target_sprite.texture == null:
		target_sprite.scale = Vector2.ONE
		return
	var scale_factor := TARGET_HEIGHT / maxf(target_sprite.texture.get_height(), 1.0)
	if inside_scaled_parent:
		scale_factor /= 0.49
	target_sprite.scale = Vector2.ONE * scale_factor

func _update_visibility() -> void:
	var has_pet := not pet_id.is_empty() and sprite != null and sprite.texture != null
	var in_cinematic := has_pet and cinematic_anchor != null and cinematic_anchor.visible
	if sprite != null:
		sprite.visible = has_pet and not in_cinematic and target != null and target.visible
	if cinematic_sprite != null:
		cinematic_sprite.visible = in_cinematic
