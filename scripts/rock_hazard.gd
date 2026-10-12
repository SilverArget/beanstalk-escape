class_name RockHazard
extends Node2D

const ATLAS := preload("res://assets/art/hazards/rock_fire_atlas.png")
const CELL_SIZE := Vector2(512.0, 512.0)

var hazard_id := ""
var kind := "S"
var routes: Array[int] = [1]
var anchor_y := 0.0
var released := false
var threat_time := 0.0
var previous_position := Vector2.ZERO
var stages: StageManager
var sprite := Sprite2D.new()
var redraw_count := 0

func setup(id: String, recipe_kind: String, lane_values: Array, at_y: float, stage_manager: StageManager) -> void:
	hazard_id = id
	kind = recipe_kind
	routes.clear()
	for lane in lane_values:
		routes.append(int(lane))
	anchor_y = at_y
	stages = stage_manager
	var cell := {"S": Vector2i(0, 0), "R": Vector2i(1, 0), "F": Vector2i(2, 0), "WALL": Vector2i(0, 1), "M": Vector2i(1, 1)}.get(kind, Vector2i.ZERO) as Vector2i
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = Rect2(Vector2(cell) * CELL_SIZE, CELL_SIZE)
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = Vector2.ONE * (0.26 if kind == "WALL" else (0.23 if kind == "S" else 0.18))
	add_child(sprite)
	_reset_position()
	_update_vine_visual_offset()
	previous_position = global_position
	queue_redraw()

func _reset_position() -> void:
	var route := routes[0] if not routes.is_empty() else 1
	var x := stages.branch_x_at(route, anchor_y) if stages != null else float(Balance.ROUTE_X[route])
	match kind:
		"R", "F": position = Vector2(x, anchor_y - 180.0)
		"M": position = Vector2(x, anchor_y - 110.0)
		"WALL": position = Vector2((float(Balance.ROUTE_X[routes[0]]) + float(Balance.ROUTE_X[routes[-1]])) * 0.5, anchor_y - 105.0)
		_: position = Vector2(x, anchor_y - 100.0)

func advance_threat_clock(delta: float, time_active: bool, player_y: float) -> void:
	previous_position = global_position
	var was_released := released
	if not released and player_y <= anchor_y:
		released = true
	if not released:
		sprite.rotation = sin(Time.get_ticks_msec() * 0.022) * (0.045 if kind == "F" else 0.015)
		return
	if released != was_released:
		queue_redraw()
	var scale := Balance.TIME_WINGS_SLOW_SCALE if time_active else 1.0
	threat_time += delta * scale
	match kind:
		"R":
			position.y += Balance.ROCK_ROLL_SPEED * delta * scale
			sprite.rotation += Balance.ROCK_ROLL_SPEED * delta * scale / 26.0
		"F":
			position.y += Balance.ROCK_FALL_SPEED * delta * scale
			sprite.rotation += 1.8 * delta * scale
		"M":
			var cycle := fposmod(threat_time, 2.8)
			var t := cycle if cycle < 1.0 else (1.0 if cycle < 1.4 else (2.4 - cycle if cycle < 2.4 else 0.0))
			var p := float(Balance.ROUTE_X[routes[0]])
			var q := float(Balance.ROUTE_X[routes[1]])
			position.x = lerpf(p, q, clampf(t, 0.0, 1.0))
	_update_vine_visual_offset()

func _update_vine_visual_offset() -> void:
	if sprite == null or stages == null or stages.stage_for_y(global_position.y) <= 2 or routes.is_empty():
		if sprite != null: sprite.position.x = 0.0
		return
	var offset := ScaleLock.vine_visual_offset(routes[0], global_position.y)
	if kind in ["M", "WALL"] and routes.size() > 1:
		offset = (ScaleLock.vine_visual_offset(routes[0], global_position.y) + ScaleLock.vine_visual_offset(routes[-1], global_position.y)) * 0.5
	sprite.position.x = offset

func collision_centers() -> Array[Vector2]:
	var result: Array[Vector2] = []
	if kind == "WALL":
		for route in routes:
			result.append(Vector2(float(Balance.ROUTE_X[route]), global_position.y))
	else:
		result.append(global_position)
	return result

func collision_radius() -> float:
	return 31.0 if kind == "M" else (24.0 if kind in ["R", "F"] else 42.0)

func _draw() -> void:
	redraw_count += 1
	if not released:
		draw_circle(Vector2(0.0, -46.0), 11.0, Color("ffd55c"))
		draw_line(Vector2(0.0, -62.0), Vector2(0.0, -52.0), Color("142b39"), 3.0, true)
		if kind == "M":
			draw_line(Vector2(-72.0, 42.0), Vector2(72.0, 42.0), Color(1.0, 0.82, 0.28, 0.65), 4.0, true)
	if kind in ["R", "M"] and released:
		for index in 3:
			draw_circle(Vector2(-34.0 - index * 10.0, 24.0 + index * 3.0), 5.0 - index, Color(0.72, 0.62, 0.42, 0.45))

func snapshot() -> Dictionary:
	return {"id": hazard_id, "kind": kind, "routes": routes.duplicate(), "anchor_y": anchor_y, "released": released, "position": global_position, "threat_time": threat_time}
