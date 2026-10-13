extends Node2D

const FRAMES := [
	preload("res://assets/art/gpt/spider/climb_1.png"),
	preload("res://assets/art/gpt/spider/climb_2.png"),
	preload("res://assets/art/gpt/spider/climb_3.png"),
	preload("res://assets/art/gpt/spider/climb_4.png"),
	preload("res://assets/art/gpt/spider/attack.png"),
	preload("res://assets/art/gpt/spider/angry.png"),
	preload("res://assets/art/gpt/spider/stunned.png"),
	preload("res://assets/art/gpt/spider/idle.png"),
]

# The source frames are tightly cropped 176x152 images. At the old 0.64 scale
# their opaque area was too short to reach the viewport from the spider's real
# chase position. Keep the gameplay body untouched and frame this giant visual
# against the lower edge whenever its natural world position falls below it.
const VISUAL_SCALE := 2.15
const EDGE_REVEAL_PX := 72.0
const BASE_POSITION := Vector2(0, -8)
const FRAME_ALPHA_TOP := [31.0, 43.0, 31.0, 40.0, 24.0, 37.0, 33.0, 40.0]
const FRAME_ALPHA_BOTTOM := 144.0
const SAFE_ALPHA_TOP := 43.0

var sprite := Sprite2D.new()
var web_line := Line2D.new()
var current_frame := 7

func _ready() -> void:
	web_line.width = 2.0
	web_line.default_color = Color(0.88, 0.94, 1.0, 0.72)
	web_line.antialiased = true
	web_line.visible = false
	add_child(web_line)
	sprite.texture = FRAMES[current_frame]
	sprite.scale = Vector2(VISUAL_SCALE, VISUAL_SCALE)
	sprite.position = BASE_POSITION
	add_child(sprite)

func _process(_delta: float) -> void:
	var spider := get_parent() as SpiderController
	if spider == null:
		return
	var frame := 7
	if spider.boost_remaining > 0.0:
		frame = 5
	elif spider.player != null and spider.player.time_wings_active:
		frame = 6
	elif spider.distance_to_player() <= Balance.GAUGE_MAX_DISTANCE * 0.20:
		frame = 4
	elif absf(spider.velocity.y) > 1.0:
		var frame_msec := 75 if spider.is_following_horizontal() and _stage_number(spider) <= 2 else 140
		frame = int(Time.get_ticks_msec() / frame_msec) % 4
	current_frame = frame
	sprite.texture = FRAMES[current_frame]
	_update_follow_pose(spider)
	_apply_bottom_edge_framing()

func _stage_number(spider: SpiderController) -> int:
	if spider.stages == null or spider.player == null:
		return 1
	return spider.stages.stage_for_y(spider.player.global_position.y)

func _update_follow_pose(spider: SpiderController) -> void:
	var moving := spider.is_following_horizontal()
	var direction := signf(spider.horizontal_motion_speed)
	var stage_number := _stage_number(spider)
	var lean := 0.16 if stage_number >= 3 else 0.10
	sprite.rotation = direction * lean if moving else move_toward(sprite.rotation, 0.0, 0.035)
	web_line.visible = moving and stage_number >= 3
	if web_line.visible:
		var sway := clampf(spider.horizontal_motion_speed / 900.0, -1.0, 1.0)
		web_line.points = PackedVector2Array([Vector2(-sway * 34.0, -280.0), Vector2(0.0, -38.0)])

func visibility_snapshot() -> Dictionary:
	if sprite.texture == null or not is_inside_tree():
		return {"on_screen": false, "visible_px": 0.0}
	var texture_height := float(sprite.texture.get_height())
	var top_local := float(FRAME_ALPHA_TOP[current_frame]) - texture_height * 0.5
	var bottom_local := FRAME_ALPHA_BOTTOM - texture_height * 0.5
	var canvas_transform := sprite.get_global_transform_with_canvas()
	var screen_top := (canvas_transform * Vector2(0.0, top_local)).y
	var screen_bottom := (canvas_transform * Vector2(0.0, bottom_local)).y
	if screen_top > screen_bottom:
		var swap := screen_top
		screen_top = screen_bottom
		screen_bottom = swap
	var viewport_height := get_viewport_rect().size.y
	var visible_px := maxf(minf(screen_bottom, viewport_height) - maxf(screen_top, 0.0), 0.0)
	return {"on_screen": visible_px > 0.5, "visible_px": snappedf(visible_px, 0.1)}

func _apply_bottom_edge_framing() -> void:
	sprite.position = BASE_POSITION
	if sprite.texture == null or not is_inside_tree():
		return
	var texture_height := float(sprite.texture.get_height())
	var safe_top_local := SAFE_ALPHA_TOP - texture_height * 0.5
	var screen_top := (sprite.get_global_transform_with_canvas() * Vector2(0.0, safe_top_local)).y
	var desired_top := get_viewport_rect().size.y - EDGE_REVEAL_PX
	if screen_top <= desired_top:
		return
	var body_transform := get_global_transform_with_canvas()
	var screen_origin := body_transform * Vector2.ZERO
	var screen_unit_y := body_transform * Vector2.DOWN
	var pixels_per_world_unit := maxf((screen_unit_y - screen_origin).length(), 0.001)
	sprite.position.y -= (screen_top - desired_top) / pixels_per_world_unit
