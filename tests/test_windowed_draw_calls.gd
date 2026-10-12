extends SceneTree

const SAMPLE_FRAMES := 60
const STAGES := [1, 8, 16, 30]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	for stage_number in STAGES:
		_prepare_stage(game, stage_number)
		for warmup in 12:
			await process_frame
		var calls: Array[int] = []
		for frame in SAMPLE_FRAMES:
			await process_frame
			calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var distribution := _visible_distribution(game)
		print("DRAW_CALLS stage=%d avg=%.1f min=%d max=%d visible=%s materials=%s branch_points=%d" % [
			stage_number, _average(calls), calls.min(), calls.max(),
			JSON.stringify(distribution.nodes), JSON.stringify(distribution.materials), int(game.get_node("World").get("branch_point_count")),
		])
	game.queue_free()
	await process_frame
	quit(0)

func _prepare_stage(game: GameManager, stage_number: int) -> void:
	var start_y := game.stages.stage_bottom_y(stage_number)
	game.player.reset_run(Vector2(0.0, start_y))
	game.spider.reset_run(Vector2(0.0, start_y + Balance.START_DISTANCE))
	game.stages.current_stage = stage_number
	game.app_state = GameManager.AppState.PLAYING
	game.player.set_physics_process(false)
	game.spider.set_physics_process(false)
	game.rocks.reset_run()
	game.storm.reset_run()
	game.rocks.refresh_active_window(true)
	game.storm.refresh_active_window(true)

func _average(values: Array[int]) -> float:
	var total := 0
	for value in values:
		total += value
	return float(total) / float(values.size())

func _visible_distribution(game: GameManager) -> Dictionary:
	var nodes := {"world": 0, "leaf_detail": 0, "gold": 0, "bean": 0, "rock": 0, "storm": 0, "sky": 0, "hud": 0, "player": 0, "spider": 0, "other": 0}
	var materials := {"none": 0}
	for node in game.find_children("*", "CanvasItem", true, false):
		var item := node as CanvasItem
		if not item.is_visible_in_tree():
			continue
		var kind := _kind_for(item)
		nodes[kind] = int(nodes.get(kind, 0)) + 1
		var material_key := "none"
		if item.material != null:
			material_key = "%s:%d" % [item.material.get_class(), item.material.get_instance_id()]
		materials[material_key] = int(materials.get(material_key, 0)) + 1
	return {"nodes": nodes, "materials": materials}

func _kind_for(item: CanvasItem) -> String:
	var path := ""
	var script := item.get_script() as Script
	if script != null:
		path = script.resource_path.get_file()
	if path == "world_visual.gd": return "world"
	if path == "world_sky_visual.gd": return "sky"
	if path == "gold_collectible.gd": return "gold"
	if path in ["bean_projectile.gd", "bean_visual.gd"]: return "bean"
	if path == "rock_hazard.gd": return "rock"
	if path == "storm_mechanics.gd": return "storm"
	if path == "player_visual.gd": return "player"
	if path == "spider_visual.gd": return "spider"
	if item is Control or item.get_parent() is CanvasLayer: return "hud"
	return "other"
