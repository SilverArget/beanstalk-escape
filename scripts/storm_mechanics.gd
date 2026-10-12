class_name StormMechanics
extends Node2D

const WIND_ACCELERATION := 80.0
const WIND_MAX_OFFSET_SPEED := 24.0
const SUPPORT_OFFSET_LIMIT := 12.0
const TRANSFER_OFFSET_LIMIT := 8.0
const BREAK_SECONDS := 1.60
const WEB_SECONDS := 2.00
const WEB_DISSOLVE_SECONDS := 0.25

@onready var player: PlayerController = get_parent().get_node_or_null("Player") as PlayerController
@onready var stages: StageManager = get_parent().get_node_or_null("StageManager") as StageManager
@onready var beans: BeanSpawner = get_parent().get_node_or_null("BeanSpawner") as BeanSpawner
@onready var audio: BeanstalkAudio = get_parent().get_node_or_null("Audio") as BeanstalkAudio

var sandbox_active := false
var stage_number := 3
var stage_bottom_y := 0.0
var wind := {"lane": 1, "anchor": 260.0, "direction": 1.0, "gain": 1.0, "length": 220.0}
var breakable := {"lane": 1, "anchor": 760.0, "length": 160.0, "touched": false, "clock": 0.0, "broken": false}
var web := {"lane": 2, "anchor": 1280.0, "length": 180.0, "warning": false, "fired": false, "active": false, "clock": 0.0, "dissolve": 0.0}
var rain := {"lane": 0, "anchor": 1900.0, "warned": false, "released": [false, false, false], "beans": []}
var wind_audio_announced := false
var break_audio_announced := false
var web_audio_announced := false

func _ready() -> void:
	process_physics_priority = -5
	queue_redraw()

func configure_sandbox(for_stage := 3) -> void:
	sandbox_active = true
	stage_number = for_stage
	stage_bottom_y = -float(stage_number - 1) * Balance.STAGE_HEIGHT
	reset_run()
	if beans != null:
		beans.sandbox_mode = true
	queue_redraw()

func reset_run() -> void:
	breakable.touched = false
	breakable.clock = 0.0
	breakable.broken = false
	web.warning = false
	web.fired = false
	web.active = false
	web.clock = 0.0
	web.dissolve = 0.0
	rain.warned = false
	rain.released = [false, false, false]
	rain.beans = []
	wind_audio_announced = false
	break_audio_announced = false
	web_audio_announced = false
	if stages != null:
		stages.clear_runtime_hazards()
	if beans != null:
		beans.sandbox_mode = sandbox_active
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not sandbox_active or player == null:
		return
	var climbed := stage_bottom_y - player.global_position.y
	_update_wind_audio(climbed)
	_update_breakable(delta, climbed)
	_update_web(delta, climbed)
	_update_rain(climbed)
	queue_redraw()

func threat_scale(time_active: bool) -> float:
	return Balance.TIME_WINGS_SLOW_SCALE if time_active else 1.0

func wind_envelope(climbed: float) -> float:
	var local := climbed - float(wind.anchor)
	if local < 0.0 or local > float(wind.length):
		return 0.0
	if local < 40.0:
		return local / 40.0
	if local <= 180.0:
		return 1.0
	return (220.0 - local) / 40.0

func wind_force_at(world_y: float, time_active: bool) -> float:
	if not sandbox_active:
		return 0.0
	var climbed := stage_bottom_y - world_y
	return float(wind.direction) * WIND_ACCELERATION * float(wind.gain) * wind_envelope(climbed) * threat_scale(time_active)

func step_support_wind(offset: float, offset_velocity: float, world_y: float, delta: float, time_active: bool) -> Vector2:
	var acceleration := wind_force_at(world_y, time_active) - 16.0 * offset - 8.0 * offset_velocity
	offset_velocity = clampf(offset_velocity + acceleration * delta, -WIND_MAX_OFFSET_SPEED, WIND_MAX_OFFSET_SPEED)
	offset = clampf(offset + offset_velocity * delta, -SUPPORT_OFFSET_LIMIT, SUPPORT_OFFSET_LIMIT)
	if (offset >= SUPPORT_OFFSET_LIMIT and offset_velocity > 0.0) or (offset <= -SUPPORT_OFFSET_LIMIT and offset_velocity < 0.0):
		offset_velocity = 0.0
	return Vector2(offset, offset_velocity)

func step_transfer_wind(offset: float, offset_velocity: float, world_y: float, delta: float, time_active: bool) -> Vector2:
	offset_velocity = clampf(offset_velocity + wind_force_at(world_y, time_active) * delta, -WIND_MAX_OFFSET_SPEED, WIND_MAX_OFFSET_SPEED)
	offset = clampf(offset + offset_velocity * delta, -TRANSFER_OFFSET_LIMIT, TRANSFER_OFFSET_LIMIT)
	if (absf(offset) >= TRANSFER_OFFSET_LIMIT and signf(offset_velocity) == signf(offset)):
		offset_velocity = 0.0
	return Vector2(offset, offset_velocity)

func _update_wind_audio(climbed: float) -> void:
	if wind_envelope(climbed) > 0.0 and not wind_audio_announced:
		wind_audio_announced = true
		if audio != null:
			audio.announce_storm_role("storm_wind")

func _update_breakable(delta: float, climbed: float) -> void:
	if bool(breakable.broken):
		return
	var inside := climbed >= float(breakable.anchor) and climbed <= float(breakable.anchor) + float(breakable.length)
	if inside and player.active_branch == int(breakable.lane) and player.support_state == PlayerController.SupportState.SUPPORTED:
		breakable.touched = true
		if not break_audio_announced:
			break_audio_announced = true
			if audio != null:
				audio.announce_storm_role("branch_crack")
	if not bool(breakable.touched):
		return
	breakable.clock = minf(float(breakable.clock) + delta * threat_scale(player.time_wings_active), BREAK_SECONDS)
	if float(breakable.clock) >= BREAK_SECONDS:
		breakable.broken = true
		stages.set_runtime_break(stage_number, int(breakable.lane), float(breakable.anchor), float(breakable.anchor) + float(breakable.length), true)
		if audio != null:
			audio.announce_storm_role("branch_break")

func _update_web(delta: float, climbed: float) -> void:
	if climbed >= float(web.anchor) - 300.0:
		web.warning = true
	if climbed >= float(web.anchor) and not bool(web.fired):
		web.fired = true
		web.active = true
		web.clock = WEB_SECONDS
		stages.set_runtime_web(stage_number, int(web.lane), float(web.anchor), float(web.anchor) + float(web.length), true)
		if not web_audio_announced:
			web_audio_announced = true
			if audio != null:
				audio.announce_storm_role("web_shot")
	if bool(web.active):
		web.clock = maxf(float(web.clock) - delta * threat_scale(player.time_wings_active), 0.0)
		if float(web.clock) <= 0.0001:
			web.active = false
			web.dissolve = WEB_DISSOLVE_SECONDS
			stages.set_runtime_web(stage_number, int(web.lane), float(web.anchor), float(web.anchor) + float(web.length), false)
	elif float(web.dissolve) > 0.0:
		web.dissolve = maxf(float(web.dissolve) - delta, 0.0)

func _update_rain(climbed: float) -> void:
	if not bool(rain.warned) and climbed >= float(rain.anchor) - 360.0:
		rain.warned = true
		for index in 3:
			var target_climb := float(rain.anchor) + float(index) * 50.0
			var target_y := stage_bottom_y - target_climb
			var bean := beans.spawn_bean(int(rain.lane), target_y, "storm-rain-%d" % index)
			rain.beans.append(bean)
	if not bool(rain.warned):
		return
	for index in 3:
		if not bool(rain.released[index]) and climbed >= float(rain.anchor) + float(index) * 50.0:
			rain.released[index] = true
			var bean := rain.beans[index] as BeanProjectile
			if is_instance_valid(bean):
				bean.request_release()

func snapshot() -> Dictionary:
	return {
		"sandbox": sandbox_active,
		"wind": {"strength": wind_envelope(stage_bottom_y - player.global_position.y) if player != null else 0.0, "direction": wind.direction},
		"breakable": breakable.duplicate(true),
		"web": web.duplicate(true),
		"rain": {"warned": rain.warned, "released": rain.released.duplicate(), "count": rain.beans.size()},
	}

func _draw() -> void:
	if not sandbox_active:
		return
	_draw_wind()
	_draw_breakable()
	_draw_web()
	_draw_rain_rhythm()

func _lane_x(lane: int) -> float:
	return float(Balance.ROUTE_X[lane])

func _world_y(climbed: float) -> float:
	return stage_bottom_y - climbed

func _draw_wind() -> void:
	var center_y := _world_y(float(wind.anchor) + 110.0)
	var direction := float(wind.direction)
	for index in 5:
		var y := center_y - 72.0 + float(index) * 34.0
		var start := Vector2(-265.0 if direction > 0.0 else 265.0, y)
		var finish := start + Vector2(direction * (120.0 + float(index % 2) * 34.0), -6.0)
		draw_line(start, finish, Color(0.78, 0.94, 0.88, 0.72), 3.0, true)
		draw_circle(finish, 6.0, Color(0.52, 0.72, 0.31, 0.92))
	var arrow_x := -235.0 if direction > 0.0 else 235.0
	var tip := Vector2(arrow_x + direction * 72.0, center_y)
	draw_line(Vector2(arrow_x, center_y), tip, Color(1.0, 0.91, 0.42), 8.0, true)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-direction * 22.0, -15.0), tip + Vector2(-direction * 22.0, 15.0)]), Color(1.0, 0.91, 0.42))

func _draw_breakable() -> void:
	var x := _lane_x(int(breakable.lane))
	var y0 := _world_y(float(breakable.anchor))
	var y1 := _world_y(float(breakable.anchor) + float(breakable.length))
	var shake := 0.0
	if bool(breakable.touched) and not bool(breakable.broken):
		shake = sin(Time.get_ticks_msec() * 0.045) * 3.0 * float(breakable.clock) / BREAK_SECONDS
	if bool(breakable.broken):
		draw_line(Vector2(x - 25.0, y0 + 24.0), Vector2(x + 34.0, y0 + 64.0), Color("6f4a28"), 18.0, true)
		return
	for step in 4:
		var y := lerpf(y0, y1, float(step + 1) / 5.0)
		draw_polyline(PackedVector2Array([Vector2(x - 18.0 + shake, y - 9.0), Vector2(x + 3.0 + shake, y), Vector2(x - 15.0 + shake, y + 11.0)]), Color("3b291d"), 4.0, true)

func _draw_web() -> void:
	if not bool(web.warning) and not bool(web.active) and float(web.dissolve) <= 0.0:
		return
	var x := _lane_x(int(web.lane))
	var y0 := _world_y(float(web.anchor))
	var y1 := _world_y(float(web.anchor) + float(web.length))
	if bool(web.warning) and not bool(web.active) and float(web.clock) <= 0.0:
		var spider_pos := Vector2(x + 92.0, y0 + 118.0)
		draw_circle(spider_pos, 18.0, Color("39213f"))
		draw_line(spider_pos, Vector2(x, y0), Color(0.92, 0.94, 0.82, 0.70), 3.0, true)
		return
	var alpha := 0.82 if bool(web.active) else clampf(float(web.dissolve) / WEB_DISSOLVE_SECONDS, 0.0, 1.0) * 0.55
	for spoke in 5:
		var y := lerpf(y0, y1, float(spoke) / 4.0)
		draw_line(Vector2(x - 27.0, y), Vector2(x + 27.0, y - 22.0), Color(0.95, 0.97, 0.86, alpha), 3.0, true)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(x, y0), Vector2(x + side * 27.0, y1), Color(0.95, 0.97, 0.86, alpha), 3.0, true)

func _draw_rain_rhythm() -> void:
	if not bool(rain.warned):
		return
	var x := _lane_x(int(rain.lane))
	var y := _world_y(float(rain.anchor))
	for index in 3:
		var pulse := 7.0 + sin(Time.get_ticks_msec() * 0.012 - float(index) * 1.3) * 2.0
		draw_circle(Vector2(x - 24.0 + float(index) * 24.0, y + 72.0), pulse, Color(0.98, 0.78, 0.24, 0.88))
