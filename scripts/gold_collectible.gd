class_name GoldCollectible
extends Node2D

signal collected(placement_id: String)

const COIN_TEXTURE := preload("res://assets/art/items/gold_coin.png")
const FEEDBACK_DURATION := 0.4
const MAGNET_DURATION := 0.15

var placement_id := ""
var player: PlayerController
var taken := false
var sparkle_remaining := 0.0
var sprite := Sprite2D.new()
var redraw_count := 0
var visual_lane := 1
var magnet_elapsed := 0.0
var magnet_origin := Vector2.ZERO
var magnet_active := false
var sparkle_origin := Vector2.ZERO

func setup(id: String, target: PlayerController) -> void:
	placement_id = id
	player = target
	visual_lane = target.stages.route_for_x(global_position.x) if target != null and target.stages != null else 1

func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.texture = COIN_TEXTURE
	sprite.scale = Vector2.ONE * 0.82
	add_child(sprite)
	if player != null and player.stages != null and player.stages.stage_for_y(global_position.y) > 2:
		sprite.position.x = ScaleLock.vine_visual_offset(visual_lane, global_position.y)
	queue_redraw()

func _physics_process(delta: float) -> void:
	var game := get_parent().get_parent() as GameManager
	if game != null and game.app_state != GameManager.AppState.PLAYING:
		return
	if not taken and player != null:
		var eligible := visual_lane == player.active_branch or (player.movement_mode == PlayerController.MovementMode.TRANSITION and visual_lane == player.transition_to)
		if not eligible:
			magnet_active = false
			magnet_elapsed = 0.0
		elif magnet_active or sprite.global_position.distance_to(player.global_position) <= 90.0:
			if not magnet_active:
				magnet_active = true
				magnet_origin = sprite.global_position
			magnet_elapsed = minf(magnet_elapsed + delta, MAGNET_DURATION)
			var progress := magnet_elapsed / MAGNET_DURATION
			sprite.global_position = magnet_origin.lerp(player.global_position, progress * progress)
			if progress >= 1.0 or sprite.global_position.distance_to(player.global_position) <= 8.0:
				_pick_up()
	if sparkle_remaining > 0.0:
		sparkle_remaining = maxf(sparkle_remaining - delta, 0.0)
		queue_redraw()
		if sparkle_remaining <= 0.0:
			queue_free()

func _pick_up() -> void:
	taken = true
	sparkle_origin = sprite.position
	sparkle_remaining = FEEDBACK_DURATION
	sprite.modulate.a = 1.0
	var pop := create_tween()
	pop.tween_property(sprite, "scale", Vector2.ONE * 0.82 * 1.6, 0.08)
	pop.tween_property(sprite, "scale", Vector2.ZERO, 0.12)
	collected.emit(placement_id)

func _process(_delta: float) -> void:
	if not taken:
		sprite.rotation = sin(Time.get_ticks_msec() * 0.004) * 0.08
		sprite.modulate.a = 0.92 + sin(Time.get_ticks_msec() * 0.008) * 0.08

func _draw() -> void:
	redraw_count += 1
	if sparkle_remaining <= 0.0:
		return
	var progress := 1.0 - sparkle_remaining / FEEDBACK_DURATION
	var elapsed := progress * FEEDBACK_DURATION
	if elapsed < 0.1:
		draw_circle(sparkle_origin, 16.0 * (1.0 + elapsed * 5.0), Color(1.0, 0.97, 0.7, 1.0 - elapsed / 0.1))
	for index in 6:
		var angle := TAU * float(index) / 6.0 + 0.3
		var center := sparkle_origin + Vector2.from_angle(angle) * (8.0 + progress * 32.0)
		var points := PackedVector2Array()
		for tip in 8:
			points.append(center + Vector2.from_angle(float(tip) * TAU / 8.0) * (5.0 if tip % 2 == 0 else 1.8) * (1.0 - progress))
		draw_colored_polygon(points, Color(1.0, 0.88, 0.35, 1.0 - progress))

func feedback_snapshot() -> Dictionary:
	return {"t": sparkle_remaining, "duration": FEEDBACK_DURATION}
