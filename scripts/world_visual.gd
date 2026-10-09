extends Node2D

const TRUNK_TEXTURE := preload("res://assets/art/gpt/world/trunk_contour.png")
const SPLIT_TEXTURE := preload("res://assets/art/gpt/world/split.png")
const BRANCH_SEAMLESS := preload("res://assets/art/gpt/world/branch_seamless.png")
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
const LEGACY_STALK_DRAW_ENABLED := false
const WORLD_REDRAW_HZ := 0.0
const SPLIT_OVERLAP_PX := 132.0
const TRUNK_WORLD_WIDTH := 672.0
const BRANCH_WORLD_WIDTH := 112.0
const TRUNK_OVERSCAN_PX := 420.0
const BRANCH_OVERLAP_PX := 100.0

func _ready() -> void:
	_build_sky_texture()
	queue_redraw()
	set_process(false)

func _draw() -> void:
	redraw_count += 1
	branch_point_count = 0
	var top_y := -Balance.STAGE_HEIGHT * Balance.STAGE_COUNT - 500.0
	var bottom_y := 500.0
	var center_y := (top_y + bottom_y) * 0.5
	_draw_sky(top_y, bottom_y, center_y)
	_draw_parallax(top_y, bottom_y, center_y)
	if stages == null: return
	if top_y <= 120.0 and bottom_y >= -Balance.STAGE_HEIGHT * 2.0 - 120.0:
		_draw_trunk()
	for pattern: Dictionary in stages.patterns:
		var stage_top := -float(pattern.stage) * Balance.STAGE_HEIGHT
		var stage_bottom := -float(pattern.stage - 1) * Balance.STAGE_HEIGHT
		if stage_bottom < top_y - 120.0 or stage_top > bottom_y + 120.0: continue
		if pattern.stage > 2:
			for route in 3: _draw_branch(pattern, route, stage_bottom, top_y, bottom_y)
			if pattern.stage == 3:
				var split_scale := TRUNK_WORLD_WIDTH / float(SPLIT_TEXTURE.get_width())
				var split_height := float(SPLIT_TEXTURE.get_height()) * split_scale
				var split_bottom := stage_bottom + SPLIT_OVERLAP_PX
				var split_top := split_bottom - split_height
				if split_top <= bottom_y + 120.0 and split_bottom >= top_y - 120.0:
					_draw_centered_texture(SPLIT_TEXTURE, Vector2(0, split_bottom - split_height * 0.5), Vector2(split_scale, split_scale))

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
	for band in 10:
		for cloud_index in 2:
			var x := -690.0 + float((band * 337 + cloud_index * 720) % 1380)
			var y := bottom_y - 180.0 - float(band) * 620.0 + float(cloud_index) * 210.0
			var texture: Texture2D = CLOUD_TEXTURES[(band + cloud_index) % CLOUD_TEXTURES.size()]
			var scale_value := 0.34 + float((band + cloud_index) % 3) * 0.08
			draw_set_transform(Vector2(x, y), 0.0, Vector2(scale_value, scale_value))
			draw_texture(texture, -texture.get_size() * 0.5, Palette.CLOUD_TINT)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(690, top_y + 82), 46.0, Palette.ACCENT_PROGRESS_LIGHT)
	draw_set_transform(Vector2(-610, bottom_y - 150), 0.0, Vector2(0.8, 0.8))
	draw_texture(MOUNTAIN, -MOUNTAIN.get_size() * 0.5, Palette.DISTANT)
	draw_set_transform(Vector2(0, bottom_y - 70), 0.0, Vector2(1.45, 1.45))
	draw_texture(HILLS, -HILLS.get_size() * 0.5, Palette.WORLD_LEAF)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for offset in [-590.0, 610.0]:
		var points := PackedVector2Array()
		for i in 62:
			var y := bottom_y - float(i) * 100.0
			points.append(Vector2(offset + sin(y * 0.006) * 25.0, y))
		draw_polyline(points, Palette.DISTANT, 18.0, true)

func _draw_trunk() -> void:
	var world_top := -Balance.STAGE_HEIGHT * 2.0
	var world_bottom := TRUNK_OVERSCAN_PX
	var world_height := world_bottom - world_top
	var scale_value := Vector2(TRUNK_WORLD_WIDTH / float(TRUNK_TEXTURE.get_width()), world_height / float(TRUNK_TEXTURE.get_height()))
	_draw_centered_texture(TRUNK_TEXTURE, Vector2(0, (world_top + world_bottom) * 0.5), scale_value)

func _draw_branch(pattern: Dictionary, route: int, stage_bottom: float, view_top: float, view_bottom: float) -> void:
	var end_y := stage_bottom - float(pattern.route_end_progress[route]) * Balance.STAGE_HEIGHT
	if end_y > view_bottom + 120.0 or stage_bottom < view_top - 120.0: return
	var points := PackedVector2Array()
	var count := maxi(8, ceili(absf(end_y - stage_bottom) / 65.0))
	for index in range(count + 1):
		var t := float(index) / float(count)
		var y := lerpf(stage_bottom, end_y, t)
		points.append(Vector2(stages.branch_x_at(route, y) + sin(y * 0.012 + route * 2.1) * 11.0, y))
	branch_point_count += points.size()
	_draw_branch_contour(points)
	_decorate_vine(points, int(pattern.stage) * 3 + route)
	if pattern.route_end_progress[route] < 1.0:
		_draw_tip(points[points.size() - 1])

func _decorate_vine(points: PackedVector2Array, seed_value: int) -> void:
	if points.size() < 3: return
	for index in range(2, points.size() - 1, 5):
		var side := -1.0 if (index + seed_value) % 2 == 0 else 1.0
		var sway := sin(float(index + seed_value)) * 0.06
		var leaf: Texture2D = LEAF_TEXTURES[(index + seed_value) % LEAF_TEXTURES.size()]
		draw_set_transform(points[index] + Vector2(side * 42.0, 0), side * 1.18 + sway, Vector2(0.25 * side, 0.25))
		draw_texture(leaf, -leaf.get_size() * 0.5)
		var tendril: Texture2D = TENDRIL_TEXTURES[(index + seed_value) % TENDRIL_TEXTURES.size()]
		draw_set_transform(points[index] + Vector2(side * 58.0, -20.0), sway, Vector2(0.22 * side, 0.22))
		draw_texture(tendril, -tendril.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_tip(point: Vector2) -> void:
	_draw_centered_texture(TIP_TEXTURE, point + Vector2(0, -38), Vector2(0.38, 0.38))

func _draw_branch_contour(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var bottom_y: float = points[0].y
	var top_y: float = points[points.size() - 1].y
	var center_y := (bottom_y + top_y) * 0.5
	var center_x := 0.0
	for point in points:
		center_x += point.x
	center_x /= float(points.size())
	var world_height := bottom_y - top_y + BRANCH_OVERLAP_PX * 2.0
	var scale_value := Vector2(BRANCH_WORLD_WIDTH / float(BRANCH_SEAMLESS.get_width()), world_height / float(BRANCH_SEAMLESS.get_height()))
	_draw_centered_texture(BRANCH_SEAMLESS, Vector2(center_x, center_y), scale_value)

func _draw_centered_texture(texture: Texture2D, position: Vector2, scale_value: Vector2) -> void:
	draw_set_transform(position, 0.0, scale_value)
	draw_texture(texture, -texture.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
