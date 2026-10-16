class_name WorldSkyVisual
extends Node2D

const SKY_DAY := preload("res://assets/art/world/v2/sky_day.png")
const SKY_SUNSET := preload("res://assets/art/world/v2/sky_sunset.png")
const FAR_STALKS := [
	preload("res://assets/art/world/v2/far_stalks_a.png"),
	preload("res://assets/art/world/v2/far_stalks_b.png"),
]
const PARALLAX_SPEEDS := [0.06, 0.14]
const FAR_TILE_HEIGHT := 1024.0

var player: PlayerController
var stages: StageManager
var redraw_count := 0
var redraw_elapsed := 0.0
var camera_top := -270.0
var far_silhouettes: Array[Texture2D] = []

func setup(target: PlayerController, stage_manager: StageManager) -> void:
	player = target
	stages = stage_manager

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Clean and flatten each source once, never during a redraw. Multiplying
	# coloured RGB by a tint retained dark outlines and muddied the sunset.
	for source: Texture2D in FAR_STALKS:
		far_silhouettes.append(_make_far_silhouette(source))
	set_process(true)
	queue_redraw()

func _make_far_silhouette(source: Texture2D) -> Texture2D:
	var image := source.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			# Blue/violet ghost vines and magenta key fringe are distinct from
			# the source's yellow-green stalks (whose red is above blue).
			var ghost := smoothstep(0.015, 0.055, pixel.b - pixel.r)
			var magenta := smoothstep(0.0, 0.04, minf(pixel.r, pixel.b) - pixel.g)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, pixel.a * (1.0 - maxf(ghost, magenta))))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var camera_center := player.global_position + Vector2(0.0, -120.0)
	if camera != null:
		camera_center = camera.get_screen_center_position()
	camera_top = camera_center.y - get_viewport_rect().size.y * 0.5
	global_position = camera_center
	redraw_elapsed += delta
	if redraw_elapsed >= 0.05:
		redraw_elapsed = fmod(redraw_elapsed, 0.05)
		queue_redraw()

func sunset_mix_at(stage_number: int, stage_progress: float) -> float:
	# Day through Stage 11; continuous transition from the start of 12 to 20.
	return smoothstep(12.0, 20.0, float(stage_number) + stage_progress)

func _draw() -> void:
	redraw_count += 1
	if player == null:
		return
	var view_rect := Rect2(-488.0, -278.0, 976.0, 556.0)
	var world := get_parent()
	if bool(world.get("qa_support_mask")):
		draw_rect(view_rect, Color.BLACK)
		return
	if bool(world.get("qa_storm_background")):
		draw_rect(view_rect, Color("313c68"))
		return
	var stage_number := stages.stage_for_y(player.global_position.y) if stages != null else 1
	var progress := stages.progress_in_stage(player.global_position.y) if stages != null else 0.0
	var sunset := sunset_mix_at(stage_number, progress)
	draw_texture_rect(SKY_DAY, view_rect, false)
	if sunset > 0.0:
		draw_texture_rect(SKY_SUNSET, view_rect, false, Color(1.0, 1.0, 1.0, sunset))
	_draw_far_vines(camera_top, sunset)
	# Keep storm and distant lightning restrained; no rock/violet/summit wash
	# or primitive circular fog clouds compete with the foreground.
	var storm := smoothstep(15.0, 17.0, float(stage_number) + progress)
	if storm > 0.0:
		draw_rect(view_rect, Color(0.48, 0.30, 0.62, 0.075 * storm))
	if stage_number >= 20:
		var flash := pow(maxf(sin(Time.get_ticks_msec() * 0.0017 + float(stage_number)), 0.0), 18.0)
		draw_rect(view_rect, Color(0.86, 0.83, 0.95, flash * 0.055))

func _draw_far_vines(top_y: float, sunset := 0.0) -> void:
	for layer in 2:
		var tint := Color("99d9df").lerp(Color("c8a5df") if layer == 0 else Color("ffc5a5"), sunset)
		tint.a = 0.14 if layer == 0 else 0.19
		var first_y := -278.0 + fposmod(-top_y * PARALLAX_SPEEDS[layer], FAR_TILE_HEIGHT) - FAR_TILE_HEIGHT
		for tile in 2:
			var destination := Rect2(-488.0, first_y + float(tile) * FAR_TILE_HEIGHT, 976.0, FAR_TILE_HEIGHT)
			draw_texture_rect(far_silhouettes[layer], destination, false, tint)
