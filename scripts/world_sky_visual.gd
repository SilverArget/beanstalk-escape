class_name WorldSkyVisual
extends Node2D

const ATMOSPHERE_TEXTURE := preload("res://assets/art/world/sunny_atmosphere.png")
const SKY_TOP := Color("366bb4")
const SKY_BOTTOM := Color("80d5f4")

var player: PlayerController
var stages: StageManager

func setup(target: PlayerController, stage_manager: StageManager) -> void:
	player = target
	stages = stage_manager

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	var camera_top := player.global_position.y - ScaleLock.CHARACTER_REFERENCE_Y
	var camera_center_x := player.global_position.x
	if camera != null:
		camera_top = camera.get_screen_center_position().y - get_viewport_rect().size.y * 0.5
		camera_center_x = camera.get_screen_center_position().x
	var view_rect := Rect2(camera_center_x - 488.0, camera_top - 8.0, 976.0, 556.0)
	var world := get_parent()
	if bool(world.get("qa_support_mask")):
		draw_rect(view_rect, Color.BLACK)
		return
	if bool(world.get("qa_storm_background")):
		draw_rect(view_rect, Color("313c68"))
		return
	for band in 24:
		var t := float(band) / 23.0
		var band_y := view_rect.position.y + view_rect.size.y * t
		draw_rect(Rect2(view_rect.position.x, band_y, view_rect.size.x, view_rect.size.y / 23.0 + 1.0), SKY_TOP.lerp(SKY_BOTTOM, t))
	draw_texture_rect(ATMOSPHERE_TEXTURE, view_rect, false, Color(1.0, 1.0, 1.0, 0.72))
	var stage_number := stages.stage_for_y(player.global_position.y) if stages != null else 1
	var stage_progress := stages.progress_in_stage(player.global_position.y) if stages != null else 0.0
	var rock_mix := clampf((float(stage_number) - 5.0 + stage_progress) / 2.0, 0.0, 1.0)
	var violet_mix := clampf((float(stage_number) - 10.0 + stage_progress) / 2.0, 0.0, 1.0)
	var storm_mix := clampf((float(stage_number) - 15.0 + stage_progress) / 2.0, 0.0, 1.0)
	var lightning_mix := clampf((float(stage_number) - 20.0 + stage_progress) / 2.0, 0.0, 1.0)
	var upper_cloud_mix := clampf((float(stage_number) - 25.0 + stage_progress) / 2.0, 0.0, 1.0)
	var summit_mix := clampf((float(stage_number) - 29.0 + stage_progress), 0.0, 1.0)
	if rock_mix > 0.0:
		draw_rect(view_rect, Color(0.34, 0.38, 0.47, 0.18 * rock_mix))
	if violet_mix > 0.0:
		draw_rect(view_rect, Color(0.29, 0.16, 0.46, 0.30 * violet_mix))
		for fog_index in 4:
			var fog_y := view_rect.position.y + fposmod(float(fog_index) * 151.0 - camera_top * 0.08, view_rect.size.y)
			draw_circle(Vector2(view_rect.get_center().x + sin(float(fog_index) * 2.1) * 260.0, fog_y), 150.0, Color(0.70, 0.56, 0.82, 0.035 * violet_mix))
	if storm_mix > 0.0:
		draw_rect(view_rect, Color(0.10, 0.16, 0.25, 0.32 * storm_mix * (1.0 - summit_mix)))
	if lightning_mix > 0.0:
		var distant_flash := pow(maxf(sin(Time.get_ticks_msec() * 0.0017 + float(stage_number)), 0.0), 18.0)
		draw_rect(view_rect, Color(0.72, 0.77, 0.92, distant_flash * 0.16 * lightning_mix * (1.0 - summit_mix)))
	if upper_cloud_mix > 0.0:
		for fog_index in 5:
			var fog_y := view_rect.position.y + fposmod(float(fog_index) * 127.0 - camera_top * 0.06, view_rect.size.y)
			draw_circle(Vector2(view_rect.get_center().x + sin(float(fog_index) * 1.8) * 300.0, fog_y), 190.0, Color(0.74, 0.79, 0.84, 0.075 * upper_cloud_mix * (1.0 - summit_mix)))
	if summit_mix > 0.0:
		draw_rect(view_rect, Color(1.0, 0.78, 0.34, 0.24 * summit_mix))
	_draw_far_vines(camera_top)

func _draw_far_vines(camera_top: float) -> void:
	var drift := fposmod(-camera_top * 0.12, 420.0)
	for index in 4:
		var side := -1.0 if index % 2 == 0 else 1.0
		var x := side * (300.0 + float(index / 2) * 92.0)
		var start_y := camera_top - 180.0 + drift + float(index) * 105.0
		var points := PackedVector2Array()
		for step in 10:
			var y := start_y + float(step) * 82.0
			points.append(Vector2(x + sin((y + float(index) * 57.0) * 0.008) * 24.0, y))
		draw_polyline(points, Color(0.12, 0.38, 0.37, 0.12), 30.0, true)
