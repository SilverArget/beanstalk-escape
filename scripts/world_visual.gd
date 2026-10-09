extends Node2D

const TRUNK_TEXTURE := preload("res://assets/art/gpt/world/trunk_seamless.png")
const SPLIT_TEXTURE := preload("res://assets/art/gpt/world/split.png")
const BRANCH_TEXTURE := preload("res://assets/art/gpt/world/branch.png")
const TIP_TEXTURE := preload("res://assets/art/gpt/world/tip.png")
const LEAF_TEXTURES := [preload("res://assets/art/gpt/world/leaf_1.png"), preload("res://assets/art/gpt/world/leaf_2.png"), preload("res://assets/art/gpt/world/leaf_3.png"), preload("res://assets/art/gpt/world/leaf_4.png")]
const TENDRIL_TEXTURES := [preload("res://assets/art/gpt/world/tendril_1.png"), preload("res://assets/art/gpt/world/tendril_2.png"), preload("res://assets/art/gpt/world/tendril_3.png")]
const CLOUD_TEXTURES := [preload("res://assets/art/gpt/items/cloud_1.png"), preload("res://assets/art/gpt/items/cloud_2.png"), preload("res://assets/art/gpt/items/cloud_3.png"), preload("res://assets/art/gpt/items/cloud_4.png")]
const HILLS := preload("res://assets/art/background/hills1.png")
const MOUNTAIN := preload("res://assets/art/background/mountain2.png")

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager
var redraw_accumulator := 0.0
var sky_texture: ImageTexture
var redraw_count := 0
var branch_point_count := 0

func _ready() -> void:
	_build_sky_texture()

func _process(delta: float) -> void:
	redraw_accumulator += delta
	if redraw_accumulator >= 1.0 / 15.0:
		redraw_accumulator = 0.0
		queue_redraw()

func _draw() -> void:
	redraw_count += 1
	branch_point_count = 0
	var center_y := player.global_position.y if player != null else 0.0
	var top_y := center_y - 430.0
	var bottom_y := center_y + 350.0
	_draw_sky(top_y, bottom_y, center_y)
	_draw_parallax(top_y, bottom_y, center_y)
	if stages == null: return
	for pattern: Dictionary in stages.patterns:
		var stage_top := -float(pattern.stage) * Balance.STAGE_HEIGHT
		var stage_bottom := -float(pattern.stage - 1) * Balance.STAGE_HEIGHT
		if stage_bottom < top_y - 120.0 or stage_top > bottom_y + 120.0: continue
		if pattern.stage <= 2:
			_draw_trunk(stage_bottom, stage_top, pattern.stage, top_y, bottom_y)
		else:
			for route in 3: _draw_branch(pattern, route, stage_bottom, top_y, bottom_y)
			if pattern.stage == 3 and stage_bottom >= top_y - 220.0 and stage_bottom <= bottom_y + 220.0:
				_draw_centered_texture(SPLIT_TEXTURE, Vector2(0, stage_bottom - 135.0), Vector2(0.78, 0.78))

func _build_sky_texture() -> void:
	var image := Image.create(1, 1024, false, Image.FORMAT_RGBA8)
	for row in image.get_height():
		image.set_pixel(0, row, sky_color_at(float(row) / float(image.get_height() - 1)))
	sky_texture = ImageTexture.create_from_image(image)

func sky_color_at(normalized_y: float) -> Color:
	return Palette.SKY_TOP.lerp(Palette.SKY_BOTTOM, clampf(normalized_y, 0.0, 1.0))

func _draw_sky(top_y: float, bottom_y: float, _center_y: float) -> void:
	draw_texture_rect(sky_texture, Rect2(-920, top_y, 1840, bottom_y - top_y), false)

func _draw_parallax(top_y: float, bottom_y: float, center_y: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	for layer in 3:
		var drift := fmod(now * (5.0 + layer * 3.0), 1400.0)
		for cloud_index in 3:
			var x := -780.0 + fmod(float(cloud_index * 510 + layer * 230) + drift, 1560.0)
			var y := top_y + 100.0 + layer * 150.0 + sin(now * 0.25 + cloud_index) * 15.0
			var texture: Texture2D = CLOUD_TEXTURES[(layer + cloud_index) % CLOUD_TEXTURES.size()]
			var scale_value := 0.32 + layer * 0.13
			draw_set_transform(Vector2(x, y), 0.0, Vector2(scale_value, scale_value))
			draw_texture(texture, -texture.get_size() * 0.5, Palette.CLOUD_TINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(690, top_y + 82), 46.0, Palette.ACCENT_PROGRESS_LIGHT)
	if center_y > -Balance.STAGE_HEIGHT * 1.2:
		draw_set_transform(Vector2(-610, bottom_y - 150), 0.0, Vector2(0.8, 0.8))
		draw_texture(MOUNTAIN, -MOUNTAIN.get_size() * 0.5, Palette.DISTANT)
		draw_set_transform(Vector2(0, bottom_y - 70), 0.0, Vector2(1.45, 1.45))
		draw_texture(HILLS, -HILLS.get_size() * 0.5, Palette.WORLD_LEAF)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for offset in [-590.0, 610.0]:
		var points := PackedVector2Array()
		for i in 10:
			var y := bottom_y - float(i) * 100.0
			points.append(Vector2(offset + sin(y * 0.006 + now * 0.15) * 25.0, y))
		draw_polyline(points, Palette.DISTANT, 18.0, true)

func _draw_trunk(bottom_y: float, top_y: float, stage_number: int, view_top: float, view_bottom: float) -> void:
	var clipped_bottom := minf(bottom_y, view_bottom + 120.0)
	var clipped_top := maxf(top_y, view_top - 120.0)
	if clipped_top >= clipped_bottom: return
	var points := PackedVector2Array()
	var count := maxi(12, ceili(absf(clipped_top - clipped_bottom) / 70.0))
	for index in range(count + 1):
		var t := float(index) / float(count)
		var y := lerpf(clipped_bottom, clipped_top, t)
		var x := sin(y * 0.0043 + stage_number * 0.8) * 28.0 + sin(y * 0.009) * 9.0
		points.append(Vector2(x, y))
	branch_point_count += points.size()
	draw_polyline(points, Palette.WORLD_STALK_EDGE, Balance.TRUNK_HALF_WIDTH * 2.0 + 46.0, true)
	draw_polyline(points, Palette.WORLD_STALK, Balance.TRUNK_HALF_WIDTH * 2.0 + 20.0, true)
	var highlight := PackedVector2Array()
	for point in points: highlight.append(point + Vector2(-Balance.TRUNK_HALF_WIDTH * 0.42, 0))
	draw_polyline(highlight, Palette.WORLD_STALK_HIGHLIGHT, 13.0, true)
	_draw_vertical_tiles(TRUNK_TEXTURE, clipped_top, clipped_bottom, 0.0, 2.82)
	_decorate_vine(points, stage_number)

func _draw_branch(pattern: Dictionary, route: int, stage_bottom: float, view_top: float, view_bottom: float) -> void:
	var end_y := stage_bottom - float(pattern.route_end_progress[route]) * Balance.STAGE_HEIGHT
	var clipped_bottom := minf(stage_bottom, view_bottom + 120.0)
	var clipped_top := maxf(end_y, view_top - 120.0)
	if clipped_top >= clipped_bottom: return
	var points := PackedVector2Array()
	var count := maxi(8, ceili(absf(clipped_top - clipped_bottom) / 65.0))
	for index in range(count + 1):
		var t := float(index) / float(count)
		var y := lerpf(clipped_bottom, clipped_top, t)
		points.append(Vector2(stages.branch_x_at(route, y) + sin(y * 0.012 + route * 2.1) * 11.0, y))
	branch_point_count += points.size()
	draw_polyline(points, Palette.WORLD_STALK_EDGE, StageManager.BRANCH_HALF_WIDTH * 2.0 + 24.0, true)
	draw_polyline(points, Palette.WORLD_STALK, StageManager.BRANCH_HALF_WIDTH * 2.0 + 8.0, true)
	var highlight := PackedVector2Array()
	for point in points: highlight.append(point + Vector2(-12, 0))
	draw_polyline(highlight, Palette.WORLD_STALK_HIGHLIGHT, 7.0, true)
	_draw_branch_tiles(points)
	_decorate_vine(points, int(pattern.stage) * 3 + route)
	if pattern.route_end_progress[route] < 1.0 and is_equal_approx(clipped_top, end_y):
		_draw_tip(points[points.size() - 1])

func _decorate_vine(points: PackedVector2Array, seed_value: int) -> void:
	if points.size() < 3: return
	for index in range(1, points.size() - 1, 3):
		var side := -1.0 if (index + seed_value) % 2 == 0 else 1.0
		var sway := sin(Time.get_ticks_msec() * 0.0015 + index + seed_value) * 0.08
		var leaf: Texture2D = LEAF_TEXTURES[(index + seed_value) % LEAF_TEXTURES.size()]
		draw_set_transform(points[index] + Vector2(side * 42.0, 0), side * 1.18 + sway, Vector2(0.25 * side, 0.25))
		draw_texture(leaf, -leaf.get_size() * 0.5)
		var tendril: Texture2D = TENDRIL_TEXTURES[(index + seed_value) % TENDRIL_TEXTURES.size()]
		draw_set_transform(points[index] + Vector2(side * 58.0, -20.0), sway, Vector2(0.22 * side, 0.22))
		draw_texture(tendril, -tendril.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_tip(point: Vector2) -> void:
	_draw_centered_texture(TIP_TEXTURE, point + Vector2(0, -38), Vector2(0.38, 0.38))

func _draw_vertical_tiles(texture: Texture2D, top_y: float, bottom_y: float, x: float, width_scale: float) -> void:
	var tile_height: float = float(texture.get_height())
	var first_center: float = floorf(top_y / tile_height) * tile_height + tile_height * 0.5
	var y: float = first_center
	while y < bottom_y + tile_height:
		_draw_centered_texture(texture, Vector2(x, y), Vector2(width_scale, 1.0))
		y += tile_height

func _draw_branch_tiles(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var scale_value: float = 0.48
	var display_height: float = float(BRANCH_TEXTURE.get_height()) * scale_value
	var bottom_y: float = points[0].y
	var top_y: float = points[points.size() - 1].y
	var y: float = bottom_y - display_height * 0.5
	while y > top_y - display_height * 0.5:
		var nearest: Vector2 = points[0]
		for point in points:
			if absf(point.y - y) < absf(nearest.y - y):
				nearest = point
		_draw_centered_texture(BRANCH_TEXTURE, Vector2(nearest.x, y), Vector2(scale_value, scale_value))
		y -= display_height * 0.88

func _draw_centered_texture(texture: Texture2D, position: Vector2, scale_value: Vector2) -> void:
	draw_set_transform(position, 0.0, scale_value)
	draw_texture(texture, -texture.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
