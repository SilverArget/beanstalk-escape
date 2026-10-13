extends SceneTree

const TrailEffectScript := preload("res://scripts/trail_effect.gd")
const TRAILS := [
	{"id": "trail_leaf", "effect_name": "LEAF FALL", "price": 200},
	{"id": "trail_cloud", "effect_name": "CLOUD BLOOM", "price": 500},
	{"id": "trail_star", "effect_name": "STAR DUST", "price": 1000},
]

var failures := 0

func _init() -> void:
	root.size = Vector2i(960, 540)
	var world := Node2D.new()
	root.add_child(world)
	var branch := Node2D.new()
	branch.z_index = 0
	world.add_child(branch)
	var player := Node2D.new()
	player.z_index = 5
	world.add_child(player)
	var body := Node2D.new()
	player.add_child(body)
	var identities: Array[String] = []
	for item in TRAILS:
		var effect := TrailEffectScript.new()
		body.add_child(effect)
		effect.configure(item)
		identities.append(effect.shape_identity())
		var player_position := Vector2(480.0, 400.0)
		for frame in 61:
			player_position.y -= 3.0
			effect.update_trail(player_position, true, false, 1.0 / 60.0)
		var climb_points := effect.point_positions()
		_check(climb_points.any(func(point: Vector2): return point.y > player_position.y), "%s leaves world-space points below climber after one second" % item.id)
		var climb_span := climb_points[-1].y - climb_points[0].y if climb_points.size() >= 2 else 0.0
		_check(absf(climb_span) >= 120.0 and absf(climb_span) <= 200.0, "%s leaves a 120-200 px climbing trail" % item.id)
		_check(effect.point_count() <= 40, "%s stays within the 40-point budget while climbing" % item.id)
		var effect_z := _effective_z(effect)
		_check(effect_z > _effective_z(branch) and effect_z < _effective_z(player), "%s effective z is above branches and below the character" % item.id)
		var state := effect.snapshot()
		_check(state.has("screen_first") and state.has("screen_last") and state.has("z"), "%s snapshot exposes screen endpoints and z data" % item.id)
		if state.has("screen_first") and state.has("screen_last"):
			_check(_inside_viewport(_snapshot_point(state.screen_first), root.size) and _inside_viewport(_snapshot_point(state.screen_last), root.size), "%s trail endpoints transform inside the viewport" % item.id)

		effect.clear()
		for frame in 25:
			var progress := float(frame) / 24.0
			var arc_position := Vector2(40.0 + 180.0 * progress, 260.0 - sin(progress * PI) * 48.0)
			effect.update_trail(arc_position, true, true, 1.0 / 60.0)
		var transfer_points := effect.point_positions()
		var min_x := INF
		var max_x := -INF
		for point in transfer_points:
			min_x = minf(min_x, point.x)
			max_x = maxf(max_x, point.x)
		_check(max_x - min_x >= 120.0, "%s draws the branch-transfer path across x" % item.id)
		_check(effect.point_count() <= 40, "%s stays within the 40-point budget during transfer" % item.id)
		effect.free()

	_check(identities.duplicate().reduce(func(unique: Array, identity: String):
		if identity not in unique: unique.append(identity)
		return unique, []).size() == 3, "all three trails have distinct shape identities")

	var economy_file := FileAccess.open("res://config/economy.json", FileAccess.READ)
	var config: Dictionary = JSON.parse_string(economy_file.get_as_text())
	var configured: Array = config.cosmetics.filter(func(item: Dictionary): return str(item.get("slot", "")) == "TRAIL")
	_check(configured.size() == 3, "three trails are configured")
	for index in TRAILS.size():
		var expected: Dictionary = TRAILS[index]
		var actual: Dictionary = configured.filter(func(item: Dictionary): return str(item.get("id", "")) == str(expected.id))[0]
		_check(int(actual.get("price", -1)) == int(expected.price), "%s price is %d" % [expected.id, expected.price])
		_check(int(actual.get("level", -1)) == index + 1, "%s level is %d" % [expected.id, index + 1])
		_check(str(actual.get("effect_name", "")) == str(expected.effect_name), "%s effect name is configured" % expected.id)
	if configured.size() == 3:
		_check(int(configured[0].price) < int(configured[1].price) and int(configured[1].price) < int(configured[2].price), "trail prices increase with effect richness")

	if failures == 0:
		print("PASS: readable world-space trail effects")
	quit(failures)

func _effective_z(item: CanvasItem) -> int:
	var result := item.z_index
	var parent := item.get_parent() as CanvasItem
	while item.z_as_relative and parent != null:
		result += parent.z_index
		item = parent
		parent = item.get_parent() as CanvasItem
	return result

func _inside_viewport(point: Vector2, viewport_size: Vector2i) -> bool:
	return point.x >= 0.0 and point.y >= 0.0 and point.x <= viewport_size.x and point.y <= viewport_size.y

func _snapshot_point(value: Dictionary) -> Vector2:
	return Vector2(float(value.get("x", -1.0)), float(value.get("y", -1.0)))

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % label)
