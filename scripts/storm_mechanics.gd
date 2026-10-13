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
var wind := {"lane": 1, "anchor": 260.0, "direction": 1.0, "gain": 1.0, "length": 220.0, "life_spent": false}
var breakable := {"lane": 1, "anchor": 760.0, "length": 160.0, "touched": false, "clock": 0.0, "broken": false, "life_spent": false}
var web := {"lane": 2, "anchor": 1280.0, "length": 180.0, "warning": false, "fired": false, "active": false, "clock": 0.0, "dissolve": 0.0, "life_spent": false}
var rain := {"lane": 0, "anchor": 1900.0, "warned": false, "released": [false, false, false], "beans": []}
var wind_audio_announced := false
var break_audio_announced := false
var web_audio_announced := false
var campaign_slots: Array = []
var campaign_slots_by_stage: Dictionary = {}
var active_center_stage := -1
var redraw_count := 0
var redraw_elapsed := 0.0
var visual_was_active := false
var nightmare_modifiers := StageDatabase.nightmare_modifiers()

func _ready() -> void:
	process_physics_priority = -5
	queue_redraw()

func configure_sandbox(for_stage := 3) -> void:
	stage_number = for_stage
	stage_bottom_y = stages.stage_bottom_y(stage_number)
	reset_run()
	sandbox_active = true
	campaign_slots.clear()
	if beans != null:
		beans.sandbox_mode = true
	queue_redraw()

func reset_run() -> void:
	wind.life_spent = false
	breakable.touched = false
	breakable.clock = 0.0
	breakable.broken = false
	breakable.life_spent = false
	web.warning = false
	web.fired = false
	web.active = false
	web.clock = 0.0
	web.dissolve = 0.0
	web.life_spent = false
	rain.warned = false
	rain.released = [false, false, false]
	rain.beans = []
	wind_audio_announced = false
	break_audio_announced = false
	web_audio_announced = false
	campaign_slots.clear()
	campaign_slots_by_stage.clear()
	active_center_stage = -1
	if stages != null:
		stages.clear_runtime_hazards()
		for pattern: Dictionary in stages.patterns:
			var stage_slots: Array = []
			for source: Dictionary in pattern.get("storm_slots", []):
				var slot := source.duplicate(true)
				slot["stage"] = int(pattern.stage)
				slot["stage_bottom_y"] = stages.stage_bottom_y(int(pattern.stage))
				slot["clock"] = 0.0
				slot["touched"] = false
				slot["active"] = false
				slot["finished"] = false
				slot["life_spent"] = false
				slot["warning_visible_seconds"] = 0.0
				stage_slots.append(slot)
			campaign_slots_by_stage[int(pattern.stage)] = stage_slots
	refresh_active_window(true)
	if beans != null:
		beans.sandbox_mode = sandbox_active
	queue_redraw()

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var game := get_parent() as GameManager
	if game == null or game.app_state != GameManager.AppState.PLAYING:
		return
	if not sandbox_active:
		refresh_active_window()
		_update_campaign(delta)
		_update_visual_redraw(delta, _campaign_visual_active())
		return
	var climbed := stage_bottom_y - player.global_position.y
	_update_wind_audio(climbed)
	_update_breakable(delta, climbed)
	_update_web(delta, climbed)
	_update_rain(climbed)
	_update_sandbox_contacts(climbed)
	_update_visual_redraw(delta, true)

func _update_visual_redraw(delta: float, visual_active: bool) -> void:
	redraw_elapsed += delta
	if visual_active != visual_was_active:
		visual_was_active = visual_active
		queue_redraw()
	if visual_active and redraw_elapsed >= 1.0 / 30.0:
		redraw_elapsed = fmod(redraw_elapsed, 1.0 / 30.0)
		queue_redraw()

func _campaign_visual_active() -> bool:
	for slot: Dictionary in campaign_slots:
		var climbed := float(slot.stage_bottom_y) - player.global_position.y
		if climbed >= float(slot.warning_height) and climbed <= float(slot.occupancy[1]) + 180.0:
			return true
	return false

func refresh_active_window(force := false) -> void:
	if sandbox_active or player == null or stages == null:
		return
	var center_stage := stages.stage_for_y(player.global_position.y)
	if not force and center_stage == active_center_stage:
		return
	active_center_stage = center_stage
	campaign_slots.clear()
	for stage_number in range(maxi(1, center_stage - 1), mini(Balance.STAGE_COUNT, center_stage + 1) + 1):
		for source: Dictionary in campaign_slots_by_stage.get(stage_number, []):
			campaign_slots.append(source)

func threat_scale(time_active: bool) -> float:
	return Balance.TIME_WINGS_SLOW_SCALE if time_active else 1.0

func nightmare_scale(key: String) -> float:
	var game := get_parent() as GameManager
	return float(nightmare_modifiers.get(key, 1.0)) if game != null and game.is_nightmare_mode() else 1.0

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
		var force := 0.0
		for slot: Dictionary in campaign_slots:
			if String(slot.kind) != "V":
				continue
			var climbed := float(slot.stage_bottom_y) - world_y
			var local := climbed - float(slot.anchor)
			var length := float(slot.occupancy[1]) - float(slot.occupancy[0])
			if local < 0.0 or local > length:
				continue
			var edge := minf(40.0, length * 0.25)
			var envelope := minf(minf(local / edge, (length - local) / edge), 1.0)
			force += float(slot.direction) * WIND_ACCELERATION * float(slot.gain) * maxf(envelope, 0.0)
		return force * threat_scale(time_active) * nightmare_scale("wind_force_scale")
	var climbed := stage_bottom_y - world_y
	return float(wind.direction) * WIND_ACCELERATION * float(wind.gain) * wind_envelope(climbed) * threat_scale(time_active) * nightmare_scale("wind_force_scale")

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
	breakable.clock = minf(float(breakable.clock) + delta * threat_scale(player.time_wings_active) * nightmare_scale("break_clock_scale"), BREAK_SECONDS)
	if float(breakable.clock) >= BREAK_SECONDS:
		breakable.broken = true
		stages.set_runtime_break(stage_number, int(breakable.lane), float(breakable.anchor), float(breakable.anchor) + float(breakable.length), true)
		if inside and player.active_branch == int(breakable.lane) and not bool(breakable.life_spent):
			breakable.life_spent = true
			_notify_environment_hit("branch_break", true)
		if audio != null:
			audio.announce_storm_role("branch_break")

func _update_web(delta: float, climbed: float) -> void:
	if climbed >= float(web.anchor) - 300.0:
		web.warning = true
	if climbed >= float(web.anchor) and not bool(web.fired):
		web.fired = true
		web.active = true
		web.clock = WEB_SECONDS * nightmare_scale("web_duration_scale")
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

func _update_sandbox_contacts(climbed: float) -> void:
	if wind_envelope(climbed) > 0.0 and absf(player.support_offset) >= SUPPORT_OFFSET_LIMIT - 0.05 and not bool(wind.life_spent):
		wind.life_spent = true
		_notify_environment_hit("wind")
	var in_web := climbed >= float(web.anchor) and climbed <= float(web.anchor) + float(web.length)
	if bool(web.active) and in_web and player.active_branch == int(web.lane) and not bool(web.life_spent):
		web.life_spent = true
		_notify_environment_hit("web")

func _notify_environment_hit(kind: String, respawn_from_checkpoint := false) -> void:
	var game := get_parent() as GameManager
	if game != null:
		game.on_environment_hit(kind, respawn_from_checkpoint)

func snapshot() -> Dictionary:
	var campaign: Array = []
	for slot: Dictionary in campaign_slots:
		campaign.append({
			"kind": {"V": "wind", "K": "break", "WEB": "web", "RAIN": "rain"}.get(String(slot.kind), String(slot.kind).to_lower()),
			"lane": int(slot.lane),
			"start_y": float(slot.stage_bottom_y) - float(slot.anchor),
			"end_y": float(slot.stage_bottom_y) - float(slot.occupancy[1]),
			"phase": _campaign_phase(slot),
			"warning_visible_seconds": float(slot.warning_visible_seconds),
		})
	return {
		"sandbox": sandbox_active,
		"campaign_active": campaign_slots.filter(func(slot: Dictionary) -> bool: return bool(slot.active)).size(),
		"campaign": campaign,
		"wind": {"strength": wind_envelope(stage_bottom_y - player.global_position.y) if player != null else 0.0, "direction": wind.direction},
		"breakable": breakable.duplicate(true),
		"web": web.duplicate(true),
		"rain": {"warned": rain.warned, "released": rain.released.duplicate(), "count": rain.beans.size()},
	}

func _campaign_phase(slot: Dictionary) -> String:
	if bool(slot.finished):
		return "broken" if String(slot.kind) == "K" else "cleared"
	var climbed := float(slot.stage_bottom_y) - player.global_position.y if player != null else -INF
	if climbed < float(slot.warning_height):
		return "idle"
	if String(slot.kind) == "K" and bool(slot.touched):
		return "cracking"
	if bool(slot.active):
		return "active"
	if climbed > float(slot.occupancy[1]):
		return "cleared"
	return "warning"

func _draw() -> void:
	redraw_count += 1
	if not sandbox_active:
		_draw_campaign()
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
	_draw_wind_field(center_y, direction, true)
	_draw_wind_arrow(direction, true)

func _draw_wind_field(center_y: float, direction: float, active: bool) -> void:
	var tick := Time.get_ticks_msec() * 0.001
	var y_offsets := PackedFloat32Array([-132.0, -70.0, -12.0, 58.0, 126.0])
	var lengths := PackedFloat32Array([420.0, 330.0, 510.0, 365.0, 455.0])
	var wind_color := Color(0.86, 0.98, 1.0, 0.72 if active else 0.56)
	var width_scale := 1.0 if active else 0.82
	for index in 5:
		var travel := fposmod(tick * 150.0 + float(index) * 223.0, 1120.0)
		var start_x := -560.0 + travel if direction > 0.0 else 560.0 - travel
		var start := Vector2(start_x, center_y + y_offsets[index])
		var curve_height := (28.0 + float(index) * 3.0) * (1.0 if index % 2 == 0 else -1.0)
		curve_height += sin(tick * 1.7 + float(index) * 1.31) * 8.0
		var sweep := PackedVector2Array()
		for point_index in 10:
			var t := float(point_index) / 9.0
			var arc := sin(t * PI) * curve_height
			var ripple := sin(t * TAU + tick * 1.5 + float(index)) * 5.0
			sweep.append(start + Vector2(direction * lengths[index] * t, arc + ripple))
		draw_polyline(PackedVector2Array([sweep[0], sweep[1], sweep[2], sweep[3]]), wind_color, 2.3 * width_scale, true)
		draw_polyline(PackedVector2Array([sweep[3], sweep[4], sweep[5], sweep[6]]), wind_color, 5.2 * width_scale, true)
		draw_polyline(PackedVector2Array([sweep[6], sweep[7], sweep[8], sweep[9]]), wind_color, 2.3 * width_scale, true)
	for leaf_index in 3:
		var leaf_travel := fposmod(tick * 185.0 + float(leaf_index) * 367.0, 1120.0)
		var leaf_x := -560.0 + leaf_travel if direction > 0.0 else 560.0 - leaf_travel
		var flutter := sin(tick * 4.2 + float(leaf_index) * 2.4)
		var leaf_center := Vector2(leaf_x, center_y - 92.0 + float(leaf_index) * 91.0 + flutter * 14.0)
		var heading := Vector2(direction, flutter * 0.28).normalized()
		var normal := Vector2(-heading.y, heading.x)
		var leaf := PackedVector2Array([
			leaf_center + heading * 15.0,
			leaf_center + normal * 8.0,
			leaf_center - heading * 12.0,
			leaf_center - normal * 8.0,
		])
		var leaf_color := Color(0.46, 0.69 - float(leaf_index) * 0.05, 0.27, 0.72 if active else 0.58)
		draw_colored_polygon(leaf, leaf_color)

func _draw_wind_arrow(direction: float, active: bool) -> void:
	if player == null:
		return
	var origin := player.global_position + Vector2(-132.0 * direction, -62.0)
	var tip := origin + Vector2(direction * 66.0, 0.0)
	var color := Color(1.0, 0.91, 0.42, 1.0 if active else 0.82)
	draw_line(origin, tip, color, 9.0 if active else 7.0, true)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-direction * 25.0, -17.0), tip + Vector2(-direction * 25.0, 17.0)]), color)

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

func _update_campaign(delta: float) -> void:
	for slot: Dictionary in campaign_slots:
		var climbed := float(slot.stage_bottom_y) - player.global_position.y
		var anchor := float(slot.anchor)
		var end_height := float(slot.occupancy[1])
		var kind := String(slot.kind)
		if climbed >= float(slot.warning_height) and not bool(slot.finished):
			slot.warning_visible_seconds = float(slot.warning_visible_seconds) + delta
		if kind == "V":
			slot.active = climbed >= anchor and climbed <= end_height
			if bool(slot.active) and absf(player.support_offset) >= SUPPORT_OFFSET_LIMIT - 0.05 and not bool(slot.life_spent):
				slot.life_spent = true
				_notify_environment_hit("wind")
			continue
		if bool(slot.finished):
			continue
		if kind == "K":
			var inside := climbed >= anchor and climbed <= end_height
			if inside and player.active_branch == int(slot.lane) and player.support_state == PlayerController.SupportState.SUPPORTED:
				slot.touched = true
			if bool(slot.touched):
				slot.clock = minf(float(slot.clock) + delta * threat_scale(player.time_wings_active) * nightmare_scale("break_clock_scale"), BREAK_SECONDS)
				slot.active = true
				if float(slot.clock) >= BREAK_SECONDS:
					slot.finished = true
					slot.active = false
					stages.set_runtime_break(int(slot.stage), int(slot.lane), anchor, end_height, true)
					if inside and player.active_branch == int(slot.lane) and not bool(slot.life_spent):
						slot.life_spent = true
						_notify_environment_hit("branch_break", true)
		elif kind == "WEB":
			if climbed >= anchor and not bool(slot.active):
				slot.active = true
				slot.clock = WEB_SECONDS * nightmare_scale("web_duration_scale")
				stages.set_runtime_web(int(slot.stage), int(slot.lane), anchor, end_height, true)
			if bool(slot.active):
				var caught_in_web := climbed >= anchor and climbed <= end_height and player.active_branch == int(slot.lane)
				if caught_in_web and not bool(slot.life_spent):
					slot.life_spent = true
					_notify_environment_hit("web")
				slot.clock = maxf(float(slot.clock) - delta * threat_scale(player.time_wings_active), 0.0)
				if float(slot.clock) <= 0.0:
					slot.active = false
					slot.finished = true
					stages.set_runtime_web(int(slot.stage), int(slot.lane), anchor, end_height, false)

func _draw_campaign() -> void:
	var wind_slot: Dictionary = {}
	var wind_center_y := 0.0
	for slot: Dictionary in campaign_slots:
		var climbed := float(slot.stage_bottom_y) - player.global_position.y if player != null else -INF
		var anchor := float(slot.anchor)
		if climbed < float(slot.warning_height) or climbed > float(slot.occupancy[1]) + 180.0:
			continue
		var y0 := float(slot.stage_bottom_y) - anchor
		var y1 := float(slot.stage_bottom_y) - float(slot.occupancy[1])
		var kind := String(slot.kind)
		if kind == "V":
			if wind_slot.is_empty() or (bool(slot.active) and not bool(wind_slot.active)):
				wind_slot = slot
				wind_center_y = (y0 + y1) * 0.5
		elif kind == "K":
			_draw_campaign_break(slot, y0, y1)
		elif kind == "WEB":
			_draw_campaign_web(slot, y0, y1)
	if not wind_slot.is_empty():
		_draw_campaign_wind(wind_slot, wind_center_y)

func _draw_campaign_wind(slot: Dictionary, center_y: float) -> void:
	var direction := float(slot.direction)
	var active := bool(slot.active)
	_draw_wind_field(center_y, direction, active)
	_draw_wind_arrow(direction, active)

func _draw_campaign_break(slot: Dictionary, y0: float, y1: float) -> void:
	var x := _lane_x(int(slot.lane))
	if bool(slot.finished):
		draw_line(Vector2(x - 25.0, y0 + 24.0), Vector2(x + 34.0, y0 + 64.0), Color("6f4a28"), 18.0, true)
		return
	var shake := sin(Time.get_ticks_msec() * 0.045) * 3.0 * float(slot.clock) / BREAK_SECONDS if bool(slot.touched) else 0.0
	for step in 4:
		var y := lerpf(y0, y1, float(step + 1) / 5.0)
		draw_polyline(PackedVector2Array([Vector2(x - 18.0 + shake, y - 9.0), Vector2(x + 3.0 + shake, y), Vector2(x - 15.0 + shake, y + 11.0)]), Color("3b291d"), 4.0, true)

func _draw_campaign_web(slot: Dictionary, y0: float, y1: float) -> void:
	var x := _lane_x(int(slot.lane))
	if not bool(slot.active):
		draw_circle(Vector2(x + 92.0, y0 + 118.0), 18.0, Color("39213f"))
		draw_line(Vector2(x + 92.0, y0 + 118.0), Vector2(x, y0), Color(0.92, 0.94, 0.82, 0.70), 3.0, true)
		return
	for spoke in 5:
		var y := lerpf(y0, y1, float(spoke) / 4.0)
		draw_line(Vector2(x - 27.0, y), Vector2(x + 27.0, y - 22.0), Color(0.95, 0.97, 0.86, 0.82), 3.0, true)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(x, y0), Vector2(x + side * 27.0, y1), Color(0.95, 0.97, 0.86, 0.82), 3.0, true)
