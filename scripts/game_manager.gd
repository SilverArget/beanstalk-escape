class_name GameManager
extends Node2D

enum State { PLAYING, PLAYER_DEAD, PROTOTYPE_COMPLETE }
enum AppState { MENU, PLAYING, PAUSED, PLAYER_DEAD, GAME_COMPLETE }
var state := State.PLAYING
var app_state := AppState.MENU
@onready var player: PlayerController = $Player
@onready var spider: SpiderController = $Spider
@onready var gauge: SpiderDistanceGauge = $HUD/Gauge
@onready var stages: StageManager = $StageManager
@onready var beans: BeanSpawner = $BeanSpawner
var total_time := 0.0
var close_calls := 0
var danger_was_active := false
var skills_used := 0
var best_spider_distance := INF
var time_wings_remaining := 0.0
var time_wings_used_stage := {}
var tutorial_remaining := 0.0
var tutorial_text := ""
var touch_actions := {}

func _ready() -> void:
	process_physics_priority = 10
	stages.prototype_completed.connect(_on_prototype_completed)
	stages.stage_completed.connect(_on_stage_completed)
	_ensure_actions()
	_setup_hud()
	_show_menu()

func _physics_process(delta: float) -> void:
	if app_state == AppState.PAUSED or app_state == AppState.MENU or app_state == AppState.PLAYER_DEAD or app_state == AppState.GAME_COMPLETE:
		_update_hud()
		return
	total_time += delta
	if time_wings_remaining > 0.0:
		time_wings_remaining = maxf(time_wings_remaining - delta, 0.0)
		if time_wings_remaining <= 0.0:
			player.time_wings_active = false
			player.remove_from_group("time_wings_active")
	if tutorial_remaining > 0.0:
		tutorial_remaining = maxf(tutorial_remaining - delta, 0.0)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	stages.update_progress(player.global_position.y)
	best_spider_distance = minf(best_spider_distance, gauge.distance_px)
	if gauge.level == "DANGER" and not danger_was_active:
		danger_was_active = true
	elif gauge.level != "DANGER" and danger_was_active:
		close_calls += 1
		danger_was_active = false
	if gauge.distance_px <= Balance.CATCH_DISTANCE:
		_die()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if app_state == AppState.MENU:
			start_game()
		elif app_state == AppState.PLAYER_DEAD:
			restart_stage()
		elif app_state == AppState.GAME_COMPLETE:
			restart()
	if event.is_action_pressed("pause") and app_state == AppState.PLAYING:
		_pause_game()
	elif event.is_action_pressed("pause") and app_state == AppState.PAUSED:
		_resume_game()
	if event.is_action_pressed("time_wings"):
		try_time_wings()

func restart() -> void:
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	player.reset_run(Vector2(0, 0))
	spider.reset_run(Vector2(0, Balance.START_DISTANCE))
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	stages.reset_run()
	state = State.PLAYING
	app_state = AppState.PLAYING
	total_time = 0.0
	close_calls = 0
	danger_was_active = false
	skills_used = 0
	best_spider_distance = INF
	time_wings_remaining = 0.0
	time_wings_used_stage.clear()
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	_show_tutorial_for_stage(1)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_update_hud()

func start_game() -> void:
	restart()

func restart_stage() -> void:
	var stage_number := stages.current_stage
	var start_y := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	player.reset_run(Vector2(0, start_y))
	spider.reset_run(Vector2(0, start_y + Balance.START_DISTANCE))
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	time_wings_remaining = 0.0
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	time_wings_used_stage.erase(stage_number)
	state = State.PLAYING
	app_state = AppState.PLAYING
	_show_tutorial_for_stage(stage_number)
	_update_hud()

func _on_prototype_completed() -> void:
	state = State.PROTOTYPE_COMPLETE
	app_state = AppState.GAME_COMPLETE
	_update_hud()

func _on_stage_completed(stage_number: int) -> void:
	if stage_number < Balance.STAGE_COUNT:
		_show_tutorial_for_stage(stage_number + 1)

func try_time_wings() -> bool:
	var stage_number := stages.stage_for_y(player.global_position.y)
	if app_state != AppState.PLAYING or stage_number < Balance.TIME_WINGS_STAGE or time_wings_used_stage.has(stage_number) or time_wings_remaining > 0.0:
		return false
	time_wings_used_stage[stage_number] = true
	time_wings_remaining = Balance.TIME_WINGS_SECONDS
	player.time_wings_active = true
	player.add_to_group("time_wings_active")
	skills_used += 1
	_update_hud()
	return true

func _die() -> void:
	state = State.PLAYER_DEAD
	app_state = AppState.PLAYER_DEAD
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	_update_hud()

func _pause_game() -> void:
	app_state = AppState.PAUSED
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(false)
	_update_hud()

func _resume_game() -> void:
	app_state = AppState.PLAYING
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(true)
	_update_hud()

func _show_menu() -> void:
	app_state = AppState.MENU
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	_update_hud()

func _show_tutorial_for_stage(stage_number: int) -> void:
	var messages := {1: "MOVE LEFT / RIGHT", 2: "AVOID", 3: "CHANGE BRANCH", 5: "PRESS F"}
	tutorial_text = messages.get(stage_number, "")
	tutorial_remaining = Balance.TUTORIAL_SECONDS if tutorial_text != "" else 0.0

func show_bean_tutorial() -> void:
	if stages.stage_for_y(player.global_position.y) == 4 and tutorial_text != "DODGE THE BEANS":
		tutorial_text = "DODGE THE BEANS"
		tutorial_remaining = Balance.TUTORIAL_SECONDS

func _setup_hud() -> void:
	$HUD/Title.text = "BEANSTALK ESCAPE"
	$HUD/Hint.text = ""
	$HUD/Dead.text = "CAUGHT\nENTER / TAP TO RETRY"
	$HUD/Complete.text = ""
	_add_label("Menu", Vector2(300, 210), "BEANSTALK ESCAPE\nPRESS ENTER / TAP TO START", 28)
	_add_label("Pause", Vector2(315, 235), "PAUSED - ESC TO RESUME", 22)
	_add_label("StageBanner", Vector2(360, 90), "", 20)
	_add_label("Tutorial", Vector2(360, 130), "", 22)
	_add_label("TimeWings", Vector2(690, 22), "", 16)
	_add_label("Stats", Vector2(300, 190), "", 18)
	var mini := Control.new()
	mini.name = "MiniMap"
	mini.set_script(load("res://scripts/mini_map.gd"))
	mini.position = Vector2(22, 86)
	mini.size = Vector2(48, 360)
	$HUD.add_child(mini)
	mini.game = self
	_add_touch_button("TouchLeft", Rect2(42, 430, 92, 78), "LEFT", "move_left")
	_add_touch_button("TouchRight", Rect2(150, 430, 92, 78), "RIGHT", "move_right")
	_add_touch_button("TouchWings", Rect2(760, 430, 150, 78), "TIME WINGS", "time_wings")

func _add_label(name: String, pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = name
	label.position = pos
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	$HUD.add_child(label)
	return label

func _add_touch_button(name: String, rect: Rect2, text: String, action: String) -> void:
	var button := Button.new()
	button.name = name
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(button)
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
	button.pressed.connect(func():
		if app_state == AppState.MENU: start_game()
		elif app_state == AppState.PLAYER_DEAD: restart_stage()
		elif app_state == AppState.GAME_COMPLETE: restart())

func _update_hud() -> void:
	$HUD/Menu.visible = app_state == AppState.MENU
	$HUD/Pause.visible = app_state == AppState.PAUSED
	$HUD/Dead.visible = app_state == AppState.PLAYER_DEAD
	$HUD/Complete.visible = app_state == AppState.GAME_COMPLETE
	$HUD/StageBanner.text = stages.stage_banner if stages.stage_banner_remaining > 0.0 and app_state == AppState.PLAYING else ""
	$HUD/Tutorial.text = tutorial_text if tutorial_remaining > 0.0 and app_state == AppState.PLAYING else ""
	$HUD/TimeWings.text = _time_wings_status()
	if app_state == AppState.GAME_COMPLETE:
		$HUD/Stats.text = _stats_text()
		$HUD/Complete.text = "YOU MADE IT - STAGE 5\nENTER / TAP TO PLAY AGAIN"
	else:
		$HUD/Stats.text = ""
	$HUD/MiniMap.queue_redraw()

func _time_wings_status() -> String:
	var stage_number := stages.stage_for_y(player.global_position.y)
	if stage_number < Balance.TIME_WINGS_STAGE:
		return "F · TIME WINGS LOCKED"
	if time_wings_remaining > 0.0:
		return "F · TIME WINGS %.1fs" % time_wings_remaining
	if time_wings_used_stage.has(stage_number):
		return "F · TIME WINGS USED"
	return "F · TIME WINGS READY"

func _stats_text() -> String:
	var total_seconds := int(round(total_time))
	var mm := total_seconds / 60
	var ss := total_seconds % 60
	var best_m := (best_spider_distance if best_spider_distance < INF else Balance.START_DISTANCE) / Balance.PIXELS_PER_METER
	return "TIME %02d:%02d\nBEAN HITS %d\nCLOSE CALLS %d\nSKILLS USED %d\nBEST SPIDER DISTANCE %.1fm" % [mm, ss, beans.hit_count, close_calls, skills_used, best_m]

func _ensure_actions() -> void:
	_add_key_action("time_wings", [KEY_F])
	_add_key_action("pause", [KEY_ESCAPE, KEY_P])
	_add_key_action("ui_accept", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])

func _add_key_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for keycode in keys:
		var exists := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == keycode:
				exists = true
		if not exists:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action, ev)
