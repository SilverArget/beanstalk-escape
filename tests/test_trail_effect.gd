extends SceneTree

const TrailEffectScript := preload("res://scripts/trail_effect.gd")
const MetaShopUIScript := preload("res://scripts/meta_shop_ui.gd")
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
		_check(effect.point_count() <= 48, "%s stays within the 48-point budget while climbing" % item.id)
		var effect_z := effect.effective_z_index()
		_check(effect_z == 4 and effect_z > _effective_z(branch) and effect_z < _effective_z(player), "%s uses real canvas z 4 above branches and below the character" % item.id)
		var state := effect.snapshot()
		_check(state.has("screen_first") and state.has("screen_last") and state.has("z"), "%s snapshot exposes screen endpoints and z data" % item.id)
		_check(state.z.index == 4 and state.z.effective == 4 and not state.z.relative and state.z.top_level, "%s reports its absolute world draw order" % item.id)
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
		_check(effect.point_count() <= 48, "%s stays within the 48-point budget during transfer" % item.id)

		effect.clear()
		effect.set_preview_mode(true)
		for frame in 34:
			var preview_time := float(frame) / 60.0
			effect.update_preview(Vector2(sin(preview_time * 4.2) * 10.0, 24.0), 1.0 / 60.0)
		var preview_points := effect.point_positions()
		var preview_span := preview_points[0].y - preview_points[-1].y if preview_points.size() >= 2 else 0.0
		var preview_min_x := INF
		var preview_max_x := -INF
		for point in preview_points:
			preview_min_x = minf(preview_min_x, point.x)
			preview_max_x = maxf(preview_max_x, point.x)
		var preview_state := effect.snapshot()
		_check(preview_points.size() >= 8 and preview_span >= 60.0, "%s fills a continuous downward preview trail within 0.6 seconds" % item.id)
		_check(preview_max_x - preview_min_x >= 7.0, "%s preview trail has a readable S-curve" % item.id)
		_check(preview_state.preview and not preview_state.z.top_level and preview_state.z.relative and preview_state.z.index == -1, "%s preview stays local, scaled and behind the character" % item.id)
		effect.free()

	_check(TrailEffectScript.STAR_RIBBON_WIDTH >= 10.0 and TrailEffectScript.STAR_CORE_WIDTH >= 4.0 and TrailEffectScript.STAR_RIBBON_ALPHA >= 0.8, "star wake has a wide opaque ribbon with a light-gold core")
	_check(TrailEffectScript.STAR_MIN_RADIUS >= 5.0, "star wake particles are at least 10 px across")

	var shop := MetaShopUIScript.new()
	shop.size = Vector2(960.0, 540.0)
	shop.call("_build")
	shop.active_tab = "TRAIL"
	shop.call("_layout")
	_check(is_equal_approx(shop.preview.scale.x, 0.82) and shop.preview.position.y <= shop.preview_host.size.y * 0.4, "trail preview shrinks into the host's upper part")
	shop.active_tab = "OUTFIT"
	shop.preview_item = {"slot": "TRAIL"}
	shop.call("_layout")
	_check(is_equal_approx(shop.preview.scale.x, 1.45), "leaving the TRAIL tab restores the full-size preview")
	shop.preview_item = {}
	shop.call("_layout")
	_check(is_equal_approx(shop.preview.scale.x, 1.45) and is_equal_approx(shop.preview.position.y, shop.preview_host.size.y * 0.52), "non-trail preview keeps its existing scale and position")
	shop.free()

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
