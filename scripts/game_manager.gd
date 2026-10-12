class_name GameManager
extends Node2D

const TIME_WINGS_ORB := preload("res://assets/art/gpt/items/wing_orb.png")

enum State { PLAYING, PLAYER_DEAD, PROTOTYPE_COMPLETE }
enum AppState { MENU, INTRO, PLAYING, PAUSED, PLAYER_DEAD, GAME_COMPLETE, SHOP, CHARACTER_SELECT }
enum DeathCause { NONE, FALL, CAUGHT, OBSTACLE }
var state := State.PLAYING
var app_state := AppState.MENU
var death_cause := DeathCause.NONE
@onready var player: PlayerController = $Player
@onready var spider: SpiderController = $Spider
@onready var gauge: SpiderDistanceGauge = $HUD/Gauge
@onready var stages: StageManager = $StageManager
@onready var beans: BeanSpawner = $BeanSpawner
@onready var audio: BeanstalkAudio = $Audio
@onready var platform_services: Node = get_node("/root/PlatformServices")
var total_time := 0.0
var close_calls := 0
var danger_was_active := false
var shake_remaining := 0.0
var close_text_remaining := 0.0
var danger_pulse_remaining := 0.0
var skills_used := 0
var best_spider_distance := 0.0
var time_wings_remaining := 0.0
var time_wings_started_remaining := 0.0
var time_wings_used_stage := {}
var tutorial_remaining := 0.0
var tutorial_text := ""
var touch_actions := {}
var dead_restart_delay := 0.0
var confirm_pending := false
var reduced_motion := false
var ui_theme: Theme
var stage_restart_count := 0
var stage_restart_start_distance := 0.0
var last_time_command_source := ""
var save_manager := SaveManager.new()
var economy := EconomyManager.new()
var golds := GoldManager.new()
var reward_toast_remaining := 0.0
var level_up_remaining := 0.0
var double_reward_remaining := 0.0
var last_stage_gold_reward := 0
var death_count_by_stage := {}
var continue_used_this_run := false
var continue_checkpoint := {}
var completed_since_interstitial := 0
var platform_pause_active := false
var paused_by_platform := false
const INTRO_BEAT_SECONDS := [2.3, 3.0, 2.3]
const CAMERA_PLAY_POSITION := Vector2(0.0, -120.0)
const INTRO_LOOK_UP_POSITION := Vector2(0.0, -210.0)
const INTRO_GUARDIAN_SCALE := Vector2.ONE * 1.35
const INTRO_VISUAL_MODES := ["climb", "summit", "guardian"]
var intro_active := false
var intro_beat := 0
var intro_t := 0.0
var debug_start_stage := 1
var meta_ui: MetaShopUI

func _ready() -> void:
	process_physics_priority = 10
	save_manager.configure_platform(platform_services)
	if not economy.initialize(save_manager):
		push_error("Economy config could not be loaded")
	_apply_debug_meta_overrides()
	save_manager.profile_loaded.connect(economy.reload_profile)
	economy.level_up.connect(_on_level_up)
	platform_services.platform_pause_changed.connect(_on_platform_pause_changed)
	platform_services.platform_audio_changed.connect(audio.set_platform_audio_enabled)
	platform_services.ownership_changed.connect(_on_remove_ads_ownership_changed)
	audio.set_platform_audio_enabled(platform_services.is_platform_audio_enabled())
	golds.name = "GoldManager"
	add_child(golds)
	golds.setup(player, stages, economy, audio)
	stages.prototype_completed.connect(_on_prototype_completed)
	stages.stage_completed.connect(_on_stage_completed)
	_ensure_actions()
	_setup_hud()
	layout_hud_for_viewport(get_viewport_rect().size)
	get_viewport().size_changed.connect(func(): layout_hud_for_viewport(get_viewport_rect().size))
	_show_menu()

func _physics_process(delta: float) -> void:
	reward_toast_remaining = maxf(reward_toast_remaining - delta, 0.0)
	level_up_remaining = maxf(level_up_remaining - delta, 0.0)
	double_reward_remaining = maxf(double_reward_remaining - delta, 0.0)
	if dead_restart_delay > 0.0:
		dead_restart_delay = maxf(dead_restart_delay - delta, 0.0)
		if dead_restart_delay <= 0.0 and confirm_pending and app_state == AppState.PLAYER_DEAD:
			confirm_pending = false
			restart_stage()
			return
	if app_state == AppState.INTRO:
		_update_intro(delta)
		_update_hud()
		_publish_readonly_web_state()
		return
	if app_state in [AppState.PAUSED, AppState.MENU, AppState.PLAYER_DEAD, AppState.GAME_COMPLETE, AppState.SHOP, AppState.CHARACTER_SELECT]:
		_apply_impact_fx(0.0)
		_update_hud()
		_publish_readonly_web_state()
		return
	total_time += delta
	shake_remaining = maxf(shake_remaining - delta, 0.0)
	close_text_remaining = maxf(close_text_remaining - delta, 0.0)
	danger_pulse_remaining = maxf(danger_pulse_remaining - delta, 0.0)
	_apply_impact_fx(delta)
	if time_wings_remaining > 0.0:
		time_wings_remaining = maxf(time_wings_remaining - delta, 0.0)
		if time_wings_remaining <= 0.0:
			player.time_wings_active = false
			player.remove_from_group("time_wings_active")
	if tutorial_remaining > 0.0:
		tutorial_remaining = maxf(tutorial_remaining - delta, 0.0)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	stages.update_progress(player.global_position.y)
	_remember_continue_checkpoint()
	best_spider_distance = maxf(best_spider_distance, gauge.distance_px)
	if gauge.level == "DANGER" and not danger_was_active:
		danger_was_active = true
		danger_pulse_remaining = 0.22
	elif gauge.level != "DANGER" and danger_was_active:
		close_calls += 1
		close_text_remaining = 0.60
		danger_was_active = false
	if _spider_can_catch():
		_die(DeathCause.CAUGHT)
	_update_hud()
	_publish_readonly_web_state()

func _unhandled_input(event: InputEvent) -> void:
	if app_state == AppState.INTRO and _is_intro_skip_event(event):
		_finish_intro()
		return
	if event is InputEventKey and event.pressed and not event.echo and _debug_state_enabled():
		if event.physical_keycode == KEY_3:
			_debug_evidence_stage(3)
			return
		if event.physical_keycode == KEY_4:
			_debug_evidence_stage(4)
			beans.spawn_bean(player.active_branch, player.global_position.y + 180.0, "gate-b-evidence")
			return
		if event.physical_keycode == KEY_9:
			spider.global_position = player.global_position + Vector2(0, 48)
			return
	if event.is_action_pressed("mute"):
		audio.toggle_mute()
		_update_hud()
		return
	if app_state == AppState.PLAYING and event.is_action_pressed("move_left") and not (event is InputEventKey and event.echo):
		dispatch_command("move_left", "keyboard")
	elif app_state == AppState.PLAYING and event.is_action_pressed("move_right") and not (event is InputEventKey and event.echo):
		dispatch_command("move_right", "keyboard")
	if event.is_action_pressed("ui_accept") and not (event is InputEventKey and event.echo):
		_request_confirm()
	if event.is_action_pressed("pause") and app_state == AppState.PLAYING:
		_pause_game()
	elif event.is_action_pressed("pause") and app_state == AppState.PAUSED:
		_resume_game()
	if event.is_action_pressed("time_wings"):
		dispatch_command("time_wings", "keyboard")
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and app_state == AppState.PLAYING:
		_pause_game()

func _debug_evidence_stage(stage_number: int) -> void:
	if not _debug_state_enabled() or stage_number < 1 or stage_number > Balance.STAGE_COUNT:
		return
	player.global_position = Vector2(0, -Balance.STAGE_HEIGHT * (float(stage_number) - 0.35))
	spider.global_position = player.global_position + Vector2(0, Balance.START_DISTANCE)
	player._sync_stage_mode()
	stages.update_progress(player.global_position.y)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and app_state == AppState.INTRO:
		_finish_intro()
		return
	if event.pressed and app_state != AppState.PLAYING:
		_request_confirm()
		return
	if app_state != AppState.PLAYING:
		return
	if event.pressed:
		var wings_button := get_node_or_null("HUD/TouchWings") as Button
		if wings_button != null and Rect2(wings_button.position, wings_button.size).has_point(event.position):
			touch_actions[event.index] = "time_wings"
			dispatch_command("time_wings", "mobile")
			return
		var action := "move_left" if event.position.x < 172.0 else "move_right"
		touch_actions[event.index] = action
		Input.action_press(action)
		dispatch_command(action, "mobile")
	elif touch_actions.has(event.index):
		var released_action: String = touch_actions[event.index]
		touch_actions.erase(event.index)
		if released_action != "time_wings" and not touch_actions.values().has(released_action):
			Input.action_release(released_action)

func restart() -> void:
	_clear_direction_inputs()
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	player.reset_run(Vector2(0, 0))
	spider.reset_run(Vector2(0, Balance.START_DISTANCE))
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	stages.reset_run()
	golds.reset_run()
	golds.visible = true
	state = State.PLAYING
	app_state = AppState.PLAYING
	death_cause = DeathCause.NONE
	dead_restart_delay = 0.0
	confirm_pending = false
	total_time = 0.0
	close_calls = 0
	danger_was_active = false
	shake_remaining = 0.0
	close_text_remaining = 0.0
	danger_pulse_remaining = 0.0
	_apply_impact_fx(0.0)
	skills_used = 0
	best_spider_distance = 0.0
	time_wings_remaining = 0.0
	time_wings_started_remaining = 0.0
	stage_restart_count = 0
	stage_restart_start_distance = 0.0
	time_wings_used_stage.clear()
	death_count_by_stage.clear()
	continue_used_this_run = false
	continue_checkpoint = {}
	completed_since_interstitial = 0
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	_show_tutorial_for_stage(1)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_remember_continue_checkpoint()
	_update_hud()

func start_game() -> void:
	audio.play_sfx("ui_click")
	restart()
	_begin_intro()

func _begin_intro() -> void:
	intro_active = true
	intro_beat = 0
	intro_t = 0.0
	app_state = AppState.INTRO
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	golds.visible = false
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position = CAMERA_PLAY_POSITION
		camera.offset = Vector2.ZERO
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null:
		spider_body.visible = false
		spider_body.scale = Vector2.ONE
	$HUD/IntroSummit.visible = false
	_update_intro_presentation()
	_update_hud()

func _update_intro(delta: float) -> void:
	intro_t += delta
	var duration: float = INTRO_BEAT_SECONDS[intro_beat]
	var progress := clampf(intro_t / duration, 0.0, 1.0)
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		if intro_beat == 0:
			camera.position = CAMERA_PLAY_POSITION.lerp(INTRO_LOOK_UP_POSITION, progress * progress * (3.0 - 2.0 * progress))
		elif intro_beat == 2:
			camera.position = CAMERA_PLAY_POSITION
			if not reduced_motion and intro_t < 0.34:
				var shake_strength := 9.0 * (1.0 - intro_t / 0.34)
				camera.offset = Vector2.from_angle(intro_t * TAU * 18.0) * shake_strength
			else:
				camera.offset = Vector2.ZERO
	$HUD/IntroSummit.modulate.a = clampf(progress * 4.0, 0.0, 1.0) if intro_beat == 1 else 1.0
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null and intro_beat == 2:
		spider_body.visible = true
		spider_body.scale = INTRO_GUARDIAN_SCALE
		spider_body.position = Vector2.ZERO
		spider.global_position = player.global_position + CAMERA_PLAY_POSITION + Vector2(0.0, 18.0)
	if intro_t < duration:
		return
	intro_t = 0.0
	intro_beat += 1
	if intro_beat >= INTRO_BEAT_SECONDS.size():
		_finish_intro()
		return
	_update_intro_presentation()

func _update_intro_presentation() -> void:
	var messages := [
		"THE TOP OF THE BEANSTALK IS\nTHE TOP OF THE WORLD.",
		"WE CLIMB IT TO JUMP FROM\nTHE HIGHEST POINT ON EARTH.",
		"BUT THE GUARDIAN\nWILL TRY TO STOP US.",
	]
	$HUD/IntroText.text = messages[intro_beat]
	_layout_intro_text(get_viewport_rect().size)
	$HUD/IntroSummit.visible = intro_beat == 1
	$HUD/IntroSummit.modulate = Color.WHITE
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null:
		spider_body.visible = intro_beat == 2
		spider_body.scale = INTRO_GUARDIAN_SCALE if intro_beat == 2 else Vector2.ONE
	if intro_beat == 2:
		spider.global_position = player.global_position + CAMERA_PLAY_POSITION + Vector2(0.0, 18.0)
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.position = CAMERA_PLAY_POSITION
		audio.play_sfx("spider_scream")

func _finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	intro_beat = 0
	intro_t = 0.0
	# Rebuild the exact normal run start so watching and skipping are identical.
	player.reset_run(Vector2.ZERO)
	spider.reset_run(Vector2(0.0, Balance.START_DISTANCE))
	beans.reset_run()
	if debug_start_stage > 1:
		_start_debug_stage(debug_start_stage)
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	golds.visible = true
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.position = CAMERA_PLAY_POSITION
		camera.offset = Vector2.ZERO
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null:
		spider_body.visible = true
		spider_body.position = Vector2.ZERO
		spider_body.scale = Vector2.ONE
	$HUD/IntroSummit.visible = false
	app_state = AppState.PLAYING
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	audio.play_music("music_game")
	_update_hud()
	_publish_readonly_web_state()

func _is_intro_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER or event.physical_keycode == KEY_SPACE)
	if event is InputEventMouseButton:
		return event.pressed
	return event is InputEventScreenTouch and event.pressed

func restart_stage() -> void:
	audio.play_sfx("ui_click")
	_clear_direction_inputs()
	var stage_number := stages.current_stage
	var start_y := -float(stage_number - 1) * Balance.STAGE_HEIGHT
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	shake_remaining = 0.0
	close_text_remaining = 0.0
	danger_pulse_remaining = 0.0
	_apply_impact_fx(0.0)
	player.reset_run(Vector2(0, start_y))
	spider.reset_run(Vector2(0, start_y + SpiderController.retry_gap_for_stage(stage_number)))
	stage_restart_count += 1
	stage_restart_start_distance = spider.global_position.y - player.global_position.y
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	time_wings_remaining = 0.0
	time_wings_started_remaining = 0.0
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	time_wings_used_stage.erase(stage_number)
	state = State.PLAYING
	app_state = AppState.PLAYING
	death_cause = DeathCause.NONE
	dead_restart_delay = 0.0
	confirm_pending = false
	_show_tutorial_for_stage(stage_number)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_update_hud()
	_publish_readonly_web_state()

func _on_prototype_completed() -> void:
	state = State.PROTOTYPE_COMPLETE
	app_state = AppState.GAME_COMPLETE
	_update_hud()

func _on_stage_completed(stage_number: int) -> void:
	var player_body := player.get_node_or_null("Body")
	if player_body != null and player_body.has_method("play_celebration"):
		player_body.play_celebration()
	var reward := economy.complete_stage(stage_number)
	last_stage_gold_reward = int(reward.gold)
	reward_toast_remaining = 2.0
	double_reward_remaining = 2.0 if platform_services.is_rewarded_supported() else 0.0
	$HUD/RewardToast.text = "+%d GOLD  +%d XP" % [reward.gold, reward.xp]
	completed_since_interstitial += 1
	if stage_number >= economy.value("interstitial_min_stage") and completed_since_interstitial >= economy.value("interstitial_completed_stage_interval"):
		if platform_services.show_interstitial("stage_transition"):
			completed_since_interstitial = 0
	if stage_number < Balance.STAGE_COUNT:
		_show_tutorial_for_stage(stage_number + 1)

func try_time_wings() -> bool:
	var stage_number := stages.stage_for_y(player.global_position.y)
	if app_state != AppState.PLAYING or stage_number < Balance.TIME_WINGS_STAGE or time_wings_used_stage.has(stage_number) or time_wings_remaining > 0.0:
		return false
	time_wings_used_stage[stage_number] = true
	time_wings_remaining = Balance.TIME_WINGS_SECONDS
	time_wings_started_remaining = time_wings_remaining
	player.time_wings_active = true
	player.add_to_group("time_wings_active")
	skills_used += 1
	_update_hud()
	return true

func dispatch_command(command: String, source := "runtime") -> bool:
	if command == "move_left" or command == "move_right":
		if app_state != AppState.PLAYING:
			return false
		return player.request_branch_direction(-1 if command == "move_left" else 1)
	if command == "time_wings":
		last_time_command_source = source
		return try_time_wings()
	return false

func _die(cause: DeathCause = DeathCause.CAUGHT) -> void:
	if app_state == AppState.PLAYER_DEAD:
		return
	state = State.PLAYER_DEAD
	app_state = AppState.PLAYER_DEAD
	death_cause = cause
	_remember_continue_checkpoint()
	var dead_stage := stages.stage_for_y(player.global_position.y)
	death_count_by_stage[dead_stage] = int(death_count_by_stage.get(dead_stage, 0)) + 1
	dead_restart_delay = 0.25
	confirm_pending = false
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(false)
	_update_hud()
	call_deferred("_focus_default_death_action")
	_publish_readonly_web_state()

func _request_confirm() -> void:
	if app_state == AppState.MENU:
		_show_character_select()
	elif app_state == AppState.INTRO:
		_finish_intro()
	elif app_state == AppState.PLAYER_DEAD:
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.visible and not focused.disabled:
			focused.pressed.emit()
		else:
			_focus_default_death_action()
	elif app_state == AppState.GAME_COMPLETE:
		restart()
		_begin_intro()

func _spider_can_catch() -> bool:
	var claw_half_width := ScaleLock.BRANCH_CENTER_GAP + ScaleLock.BRANCH_WIDTH * 0.5
	return gauge.distance_px <= Balance.CATCH_DISTANCE and absf(player.global_position.x - spider.global_position.x) <= claw_half_width

func _pause_game() -> void:
	audio.play_sfx("ui_click")
	_clear_direction_inputs()
	app_state = AppState.PAUSED
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(false)
	_update_hud()

func _resume_game() -> void:
	if platform_pause_active:
		return
	audio.play_sfx("ui_click")
	app_state = AppState.PLAYING
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(true)
	_update_hud()

func _show_menu() -> void:
	app_state = AppState.MENU
	if meta_ui != null:
		meta_ui.visible = false
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	golds.visible = false
	_update_hud()

func _show_shop() -> void:
	app_state = AppState.SHOP
	meta_ui.open_shop()
	_update_hud()

func _show_character_select() -> void:
	app_state = AppState.CHARACTER_SELECT
	meta_ui.open_character_select()
	_update_hud()

func _close_meta_ui() -> void:
	_show_menu()

func _start_selected_run() -> void:
	start_game()

func _continue_with_ad() -> void:
	if app_state != AppState.PLAYER_DEAD or continue_used_this_run:
		return
	platform_services.show_rewarded("continue_in_stage", _continue_after_reward)

func _continue_after_reward() -> void:
	if app_state != AppState.PLAYER_DEAD:
		return
	continue_used_this_run = true
	var safe_position: Vector2 = continue_checkpoint.get("position", player.global_position)
	player.reset_run(safe_position)
	var safe_stage := stages.stage_for_y(safe_position.y)
	spider.reset_run(safe_position + Vector2(0, SpiderController.retry_gap_for_stage(safe_stage)))
	_resume_after_death()

func _remember_continue_checkpoint() -> void:
	if app_state != AppState.PLAYING or not player.on_support or player.support_state != PlayerController.SupportState.SUPPORTED:
		return
	continue_checkpoint = {
		"position": player.global_position,
		"stage": stages.stage_for_y(player.global_position.y),
	}

func _resume_after_death() -> void:
	state = State.PLAYING
	app_state = AppState.PLAYING
	death_cause = DeathCause.NONE
	dead_restart_delay = 0.0
	confirm_pending = false
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(true)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_update_hud()

func _restart_run_from_death() -> void:
	if app_state == AppState.PLAYER_DEAD:
		restart()
		_begin_intro()

func _menu_from_death() -> void:
	if app_state == AppState.PLAYER_DEAD:
		_show_menu()

func _focus_default_death_action() -> void:
	if app_state != AppState.PLAYER_DEAD:
		return
	var target := $HUD/ContinueAd as Button if $HUD/ContinueAd.visible else $HUD/RetryStage as Button
	target.grab_focus()

func _skip_stage_with_ad() -> void:
	if app_state != AppState.PLAYER_DEAD:
		return
	var stage_number := stages.stage_for_y(player.global_position.y)
	if int(death_count_by_stage.get(stage_number, 0)) < economy.value("skip_stage_death_count"):
		return
	platform_services.show_rewarded("skip_stage", _skip_stage_after_reward.bind(stage_number))

func _skip_stage_after_reward(stage_number: int) -> void:
	if app_state != AppState.PLAYER_DEAD or stage_number >= Balance.STAGE_COUNT:
		return
	save_manager.mark_stage_skipped(stage_number)
	stages.current_stage = stage_number + 1
	var next_y := -float(stage_number) * Balance.STAGE_HEIGHT
	player.reset_run(Vector2(0, next_y))
	spider.reset_run(Vector2(0, next_y + SpiderController.retry_gap_for_stage(stage_number + 1)))
	golds.reset_run()
	_resume_after_death()

func _double_stage_reward_with_ad() -> void:
	if double_reward_remaining <= 0.0 or last_stage_gold_reward <= 0:
		return
	double_reward_remaining = 0.0
	platform_services.show_rewarded("double_stage_reward", func(): economy.grant_gold(last_stage_gold_reward))

func _get_more_gold_with_ad() -> void:
	platform_services.show_rewarded("get_more_gold", func(): economy.grant_gold(economy.value("get_more_gold_reward")))

func _on_platform_pause_changed(value: bool) -> void:
	platform_pause_active = value
	if value and app_state == AppState.PLAYING:
		paused_by_platform = true
		_pause_game()
	elif not value and paused_by_platform and app_state == AppState.PAUSED:
		paused_by_platform = false
		_resume_game()

func _on_remove_ads_ownership_changed(value: bool) -> void:
	save_manager.set_remove_ads(value)
	_update_hud()

func _show_tutorial_for_stage(stage_number: int) -> void:
	var messages := {1: "MOVE LEFT / RIGHT", 2: "AVOID", 3: "CHANGE BRANCH", 5: "PRESS F"}
	tutorial_text = messages.get(stage_number, "")
	tutorial_remaining = Balance.TUTORIAL_SECONDS if tutorial_text != "" else 0.0

func show_bean_tutorial() -> void:
	if tutorial_text != "DODGE THE BEANS":
		tutorial_text = "DODGE THE BEANS"
		tutorial_remaining = Balance.TUTORIAL_SECONDS

func on_bean_hit() -> void:
	if not reduced_motion:
		shake_remaining = 0.20

func _apply_impact_fx(_delta: float) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		if shake_remaining > 0.0 and not reduced_motion and app_state == AppState.PLAYING:
			var progress := 1.0 - shake_remaining / 0.20
			camera.offset = Vector2.from_angle(progress * TAU * 7.0) * (6.0 * shake_remaining / 0.20)
		else:
			camera.offset = Vector2.ZERO
	var close_label := player.get_node_or_null("CloseCall") as Label
	if close_label != null:
		close_label.visible = close_text_remaining > 0.0 and app_state == AppState.PLAYING

func _setup_hud() -> void:
	_apply_theme()
	var close_label := Label.new()
	close_label.name = "CloseCall"
	close_label.text = "CLOSE!"
	close_label.position = Vector2(-55.0, -92.0)
	close_label.size = Vector2(110.0, 30.0)
	close_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_label.theme = ui_theme
	close_label.add_theme_font_size_override("font_size", 22)
	close_label.add_theme_color_override("font_color", Color("ffe36b"))
	close_label.add_theme_color_override("font_outline_color", Color("142b39"))
	close_label.add_theme_constant_override("outline_size", 4)
	close_label.z_index = 10
	close_label.visible = false
	player.add_child(close_label)
	$HUD/Title.text = ""
	$HUD/Hint.text = ""
	$HUD/Dead.text = "CAUGHT\nENTER / TAP TO RETRY"
	$HUD/Complete.text = ""
	$HUD/Complete.position = Vector2(300, 170)
	_add_menu_logo()
	_add_label("Menu", Vector2(320, 300), "CHOOSE AN OPTION", 22)
	_add_action_button("NewRun", "NEW RUN", _show_character_select)
	_add_action_button("Shop", "SHOP", _show_shop)
	var intro_label := $HUD/IntroText as Label
	intro_label.theme = ui_theme
	intro_label.add_theme_font_size_override("font_size", 34)
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.add_theme_color_override("font_outline_color", Color("142b39"))
	intro_label.add_theme_constant_override("outline_size", 7)
	var intro_panel := StyleBoxFlat.new()
	intro_panel.bg_color = Color(0.025, 0.055, 0.075, 0.78)
	intro_panel.corner_radius_top_left = 16
	intro_panel.corner_radius_top_right = 16
	intro_panel.corner_radius_bottom_left = 16
	intro_panel.corner_radius_bottom_right = 16
	intro_panel.content_margin_left = 22.0
	intro_panel.content_margin_right = 22.0
	intro_panel.content_margin_top = 12.0
	intro_panel.content_margin_bottom = 12.0
	intro_label.add_theme_stylebox_override("normal", intro_panel)
	_add_label("Pause", Vector2(315, 235), "PAUSED - ESC TO RESUME", 22)
	_add_label("StageBanner", Vector2(360, 90), "", 20)
	_add_label("Tutorial", Vector2(360, 130), "", 22)
	_add_label("TimeWings", Vector2(690, 22), "", 16)
	_add_label("GoldStatus", Vector2(690, 62), "GOLD 0", 18)
	_add_label("XPStatus", Vector2(690, 87), "LV 1 · XP 0/100", 14)
	var xp_bar := ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(xp_bar)
	_add_label("RewardToast", Vector2(300, 152), "", 20)
	_add_label("LevelUpCard", Vector2(300, 202), "", 28)
	_add_action_button("ContinueAd", "CONTINUE (AD)", _continue_with_ad)
	_add_action_button("RetryStage", "RETRY STAGE", restart_stage)
	_add_action_button("RestartRun", "RESTART RUN", _restart_run_from_death)
	_add_action_button("DeathMenu", "MENU", _menu_from_death)
	_add_action_button("SkipStageAd", "SKIP STAGE (AD)", _skip_stage_with_ad)
	_add_action_button("DoubleStageReward", "DOUBLE +0 (AD)", _double_stage_reward_with_ad)
	_add_action_button("GetMoreGold", "GET 100 GOLD (AD)", _get_more_gold_with_ad)
	_add_action_button("RemoveAds", "REMOVE ADS", platform_services.purchase_remove_ads)
	var wings_orb := TextureRect.new()
	wings_orb.name = "TimeWingsOrb"
	wings_orb.texture = TIME_WINGS_ORB
	wings_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wings_orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wings_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wings_orb)
	_add_label("Stats", Vector2(300, 190), "", 18)
	_add_label("Replay", Vector2(300, 375), "", 18)
	var mini := Control.new()
	mini.name = "MiniMap"
	mini.set_script(load("res://scripts/mini_map.gd"))
	mini.position = Vector2(22, 86)
	mini.size = Vector2(48, 360)
	$HUD.add_child(mini)
	mini.game = self
	var danger_overlay := Control.new()
	danger_overlay.name = "DangerOverlay"
	danger_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	danger_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_overlay.set_script(load("res://scripts/danger_overlay.gd"))
	$HUD.add_child(danger_overlay)
	danger_overlay.game = self
	_add_mute_button()
	_add_reduce_motion_toggle()
	_add_touch_button("TouchLeft", Rect2(36, 392, 136, 132), "LEFT", "move_left")
	_add_touch_button("TouchRight", Rect2(180, 392, 136, 132), "RIGHT", "move_right")
	_add_touch_button("TouchWings", Rect2(760, 392, 150, 132), "TIME WINGS", "time_wings")
	meta_ui = MetaShopUI.new()
	meta_ui.name = "MetaShop"
	meta_ui.visible = false
	$HUD.add_child(meta_ui)
	meta_ui.setup(economy, player.get_node("Body") as PlayerVisual)
	meta_ui.closed.connect(_close_meta_ui)
	meta_ui.run_started.connect(_start_selected_run)

func layout_hud_for_viewport(viewport_size: Vector2) -> void:
	var width := maxf(viewport_size.x, 320.0)
	var height := maxf(viewport_size.y, 320.0)
	var portrait := width < height
	var menu_action_y := height - 60.0
	var logo_y := 84.0 if portrait else 20.0
	var logo_max_height := maxf(height - 140.0 - logo_y - 62.0, 80.0)
	var logo_width := minf(minf(width * 0.68, 620.0), logo_max_height * 1.5)
	var logo_height := logo_width / 1.5
	var logo := $HUD/MenuLogo as TextureRect
	logo.position = Vector2((width - logo_width) * 0.5, logo_y)
	logo.size = Vector2(logo_width, logo_height)
	var prompt := $HUD/Menu as Label
	prompt.position = Vector2(0.0, logo.position.y + logo.size.y + 10.0)
	prompt.size = Vector2(width, 44.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUD/Mute.position = Vector2(width - 136.0, 16.0)
	$HUD/Mute.size = Vector2(112.0, 52.0)
	var skill := $HUD/TimeWings as Label
	var skill_orb := $HUD/TimeWingsOrb as TextureRect
	skill_orb.position = Vector2(18.0, 78.0) if portrait else Vector2(width - 438.0, 14.0)
	skill_orb.size = Vector2(44.0, 44.0) if portrait else Vector2(48.0, 48.0)
	skill.position = Vector2(70.0, 82.0) if portrait else Vector2(width - 380.0, 24.0)
	skill.size = Vector2(width - 88.0, 30.0) if portrait else Vector2(220.0, 30.0)
	skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Keep the meta readout in the gap between the centered banners and the
	# right-side sound/gauge column. Explicit gaps matter because the HUD
	# contract treats touching Control edges as overlap.
	var meta_width := 140.0
	var meta_x := width - 290.0
	$HUD/GoldStatus.position = Vector2(meta_x, 62.0)
	$HUD/GoldStatus.size = Vector2(meta_width, 20.0)
	$HUD/XPStatus.position = Vector2(meta_x, 85.0)
	$HUD/XPStatus.size = Vector2(meta_width, 18.0)
	$HUD/XPBar.position = Vector2(meta_x, 106.0)
	$HUD/XPBar.size = Vector2(meta_width, 9.0)
	var death_width := minf(230.0, (width - 30.0) * 0.5)
	var death_gap := 10.0
	var death_total := death_width * 2.0 + death_gap
	var death_x := maxf((width - death_total) * 0.5, 8.0)
	for index in 4:
		var death_button: Button = [$HUD/ContinueAd, $HUD/RetryStage, $HUD/RestartRun, $HUD/DeathMenu][index]
		death_button.position = Vector2(death_x + (index % 2) * (death_width + death_gap), height * 0.40 + (index / 2) * 58.0)
		death_button.size = Vector2(death_width, 52.0)
	$HUD/SkipStageAd.position = Vector2((width - death_width) * 0.5, height * 0.40 + 116.0)
	$HUD/SkipStageAd.size = Vector2(death_width, 52.0)
	$HUD/DoubleStageReward.position = Vector2((width - 230.0) * 0.5, 188.0)
	$HUD/DoubleStageReward.size = Vector2(230.0, 52.0)
	$HUD/GetMoreGold.position = Vector2(18.0, menu_action_y)
	$HUD/GetMoreGold.size = Vector2(270.0, 52.0)
	$HUD/RemoveAds.position = Vector2(width - 288.0, menu_action_y)
	$HUD/RemoveAds.size = Vector2(270.0, 52.0)
	var menu_width := minf(250.0, width * 0.34)
	$HUD/NewRun.position = Vector2((width - menu_width) * 0.5, height - 126.0)
	$HUD/NewRun.size = Vector2(menu_width, 48.0)
	$HUD/Shop.position = Vector2((width - menu_width) * 0.5, height - 72.0)
	$HUD/Shop.size = Vector2(menu_width, 48.0)
	_layout_centered_label($HUD/RewardToast, width, 154.0, 30.0, 190.0)
	_layout_centered_label($HUD/LevelUpCard, width, 198.0, 42.0, 190.0)
	_layout_centered_label($HUD/StageBanner, width, 124.0 if portrait else 86.0, 30.0, 82.0 if portrait else 300.0)
	_layout_centered_label($HUD/Tutorial, width, 158.0 if portrait else 122.0, 36.0, 82.0 if portrait else 300.0)
	var map_height := minf(360.0, height - (370.0 if portrait else 112.0))
	$HUD/MiniMap.position = Vector2(16.0 if portrait else 22.0, 205.0 if portrait else 86.0)
	$HUD/MiniMap.size = Vector2(42.0 if portrait else 48.0, maxf(map_height, 80.0))
	$HUD/Gauge.position = Vector2(width - 44.0 if portrait else width - 54.0, 205.0 if portrait else 86.0)
	$HUD/Gauge.size = Vector2(28.0, maxf(map_height, 80.0))
	_layout_centered_label($HUD/Pause, width, height * 0.38, 42.0, 40.0)
	_layout_centered_label($HUD/Dead, width, height * 0.36, 80.0, 36.0)
	_layout_centered_label($HUD/Complete, width, height * 0.25, 48.0, 36.0)
	_layout_intro_text(Vector2(width, height))
	_layout_centered_label($HUD/Stats, width, height * 0.38, 140.0, 44.0)
	_layout_centered_label($HUD/Replay, width, height * 0.76, 44.0, 36.0)
	var touch_y := height - 148.0
	$HUD/TouchLeft.position = Vector2(18.0, touch_y)
	$HUD/TouchLeft.size = Vector2(104.0, 128.0)
	$HUD/TouchRight.position = Vector2(132.0, touch_y)
	$HUD/TouchRight.size = Vector2(104.0, 128.0)
	$HUD/TouchWings.position = Vector2(width - 140.0, touch_y)
	$HUD/TouchWings.size = Vector2(122.0, 128.0)
	$HUD/MetaShop.position = Vector2.ZERO
	$HUD/MetaShop.size = Vector2(width, height)

func _layout_centered_label(label: Label, width: float, y: float, height: float, side_margin: float) -> void:
	label.position = Vector2(side_margin, y)
	label.size = Vector2(maxf(width - side_margin * 2.0, 1.0), height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _layout_intro_text(viewport_size: Vector2) -> void:
	var guardian_beat := intro_active and intro_beat == 2
	var panel_y := 12.0 if guardian_beat else viewport_size.y * 0.34
	var panel_height := 96.0 if guardian_beat else 110.0
	_layout_centered_label($HUD/IntroText, viewport_size.x, panel_y, panel_height, 72.0)

func _add_label(name: String, pos: Vector2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = name
	label.position = pos
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.theme = ui_theme
	$HUD.add_child(label)
	return label

func _add_action_button(name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.theme = ui_theme
	button.custom_minimum_size = Vector2(0, 48)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(callback)
	$HUD.add_child(button)
	return button

func _apply_theme() -> void:
	var theme := Theme.new()
	var font: FontFile = load("res://assets/fonts/LilitaOne-Regular.ttf")
	theme.default_font = font
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Palette.UI_TEXT)
	theme.set_color("font_shadow_color", "Label", Palette.UI_SHADOW)
	theme.set_constant("shadow_offset_x", "Label", 2)
	theme.set_constant("shadow_offset_y", "Label", 2)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.UI_PANEL_SOFT
	normal.corner_radius_top_left = 14
	normal.corner_radius_top_right = 14
	normal.corner_radius_bottom_left = 14
	normal.corner_radius_bottom_right = 14
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Palette.ACCENT_PROGRESS
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_color("font_color", "Button", Palette.UI_TEXT)
	ui_theme = theme
	for control in [$HUD/Title, $HUD/Hint, $HUD/Dead, $HUD/Complete, $HUD/Gauge]:
		control.theme = ui_theme

func _add_menu_logo() -> void:
	var logo := TextureRect.new()
	logo.name = "MenuLogo"
	logo.texture = load("res://assets/ui/beanstalk-escape-logo-v1.png")
	logo.position = Vector2(220, 34)
	logo.size = Vector2(520, 300)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(logo)

func _add_mute_button() -> void:
	var button := Button.new()
	button.name = "Mute"
	button.theme = ui_theme
	button.position = Vector2(824, 18)
	button.size = Vector2(112, 52)
	button.pressed.connect(func(): audio.toggle_mute(); _update_hud())
	$HUD.add_child(button)

func _add_reduce_motion_toggle() -> void:
	var toggle := CheckButton.new()
	toggle.name = "ReduceMotion"
	toggle.theme = ui_theme
	toggle.text = "REDUCE EFFECTS"
	toggle.position = Vector2(372, 278)
	toggle.size = Vector2(220, 48)
	toggle.toggled.connect(func(value: bool): reduced_motion = value)
	$HUD.add_child(toggle)

func _add_touch_button(name: String, rect: Rect2, text: String, action: String) -> void:
	var button := Button.new()
	button.name = name
	button.theme = ui_theme
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = DisplayServer.is_touchscreen_available()
	$HUD.add_child(button)
	button.button_down.connect(_on_touch_action_down.bind(action))
	button.button_up.connect(_on_touch_action_up.bind(action))
	button.pressed.connect(_request_confirm)

func _on_touch_action_down(action: String) -> void:
	if action == "time_wings":
		dispatch_command("time_wings", "mobile")
	else:
		Input.action_press(action)
		player.request_branch_direction(-1 if action == "move_left" else 1)

func _on_touch_action_up(action: String) -> void:
	if action != "time_wings":
		Input.action_release(action)

func _clear_direction_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	touch_actions.clear()

func _update_hud() -> void:
	var playing := app_state == AppState.PLAYING
	var meta_visible := playing or app_state == AppState.GAME_COMPLETE
	$HUD/Menu.visible = app_state == AppState.MENU
	$HUD/Pause.visible = app_state == AppState.PAUSED
	$HUD/Dead.visible = app_state == AppState.PLAYER_DEAD
	$HUD/Dead.text = _death_text()
	$HUD/Complete.visible = app_state == AppState.GAME_COMPLETE
	$HUD/Stats.visible = app_state == AppState.GAME_COMPLETE
	$HUD/Replay.visible = app_state == AppState.GAME_COMPLETE
	$HUD/MenuLogo.visible = app_state == AppState.MENU
	$HUD/NewRun.visible = app_state == AppState.MENU
	$HUD/Shop.visible = app_state == AppState.MENU
	$HUD/IntroText.visible = app_state == AppState.INTRO
	$HUD/ReduceMotion.visible = app_state == AppState.PAUSED
	$HUD/Gauge.visible = playing
	$HUD/MiniMap.visible = playing
	$HUD/StageBanner.visible = playing
	$HUD/Tutorial.visible = playing
	$HUD/TimeWings.visible = playing
	$HUD/TimeWingsOrb.visible = playing
	$HUD/GoldStatus.visible = meta_visible
	$HUD/XPStatus.visible = meta_visible
	$HUD/XPBar.visible = meta_visible
	$HUD/RewardToast.visible = meta_visible and reward_toast_remaining > 0.0
	$HUD/LevelUpCard.visible = meta_visible and level_up_remaining > 0.0
	var death_visible := app_state == AppState.PLAYER_DEAD
	$HUD/ContinueAd.visible = death_visible and not continue_used_this_run and platform_services.is_rewarded_supported()
	$HUD/RetryStage.visible = death_visible
	$HUD/RestartRun.visible = death_visible
	$HUD/DeathMenu.visible = death_visible
	var dead_stage := stages.stage_for_y(player.global_position.y)
	$HUD/SkipStageAd.visible = death_visible and dead_stage < Balance.STAGE_COUNT and int(death_count_by_stage.get(dead_stage, 0)) >= economy.value("skip_stage_death_count") and platform_services.is_rewarded_supported()
	$HUD/DoubleStageReward.visible = meta_visible and double_reward_remaining > 0.0 and platform_services.is_rewarded_supported()
	$HUD/DoubleStageReward.text = "DOUBLE +%d (AD)" % last_stage_gold_reward
	$HUD/GetMoreGold.visible = app_state == AppState.MENU and platform_services.is_rewarded_supported()
	$HUD/GetMoreGold.text = "GET %d GOLD (AD)" % economy.value("get_more_gold_reward")
	$HUD/RemoveAds.visible = app_state == AppState.MENU and platform_services.is_payments_supported() and not platform_services.remove_ads_owned
	$HUD/TouchLeft.visible = playing and DisplayServer.is_touchscreen_available()
	$HUD/TouchRight.visible = playing and DisplayServer.is_touchscreen_available()
	$HUD/TouchWings.visible = playing and DisplayServer.is_touchscreen_available()
	$HUD/Mute.text = "SOUND OFF" if audio.muted else "SOUND ON"
	$HUD/StageBanner.text = stages.stage_banner if stages.stage_banner_remaining > 0.0 and app_state == AppState.PLAYING else ""
	var route_hint_visible := tutorial_text != "CHANGE BRANCH" or stages.branch_targets_visible(player.global_position.y, get_viewport_rect().size.y)
	$HUD/Tutorial.text = tutorial_text if tutorial_remaining > 0.0 and app_state == AppState.PLAYING and route_hint_visible else ""
	$HUD/TimeWings.text = _time_wings_status()
	var meta := economy.snapshot()
	$HUD/GoldStatus.text = "GOLD %d" % meta.gold
	$HUD/XPStatus.text = "LV %d · XP %d/%d" % [meta.level, meta.xp, meta.xp_threshold]
	$HUD/XPBar.max_value = meta.xp_threshold
	$HUD/XPBar.value = meta.xp
	_update_time_wings_orb()
	if app_state == AppState.GAME_COMPLETE:
		$HUD/Stats.text = _stats_text()
		$HUD/Complete.text = "YOU MADE IT - STAGE 5"
		$HUD/Replay.text = "ENTER / TAP TO PLAY AGAIN"
	else:
		$HUD/Stats.text = ""
		$HUD/Replay.text = ""
	$HUD/MiniMap.queue_redraw()

func _on_level_up(new_level: int, gold_reward: int) -> void:
	level_up_remaining = 2.4
	$HUD/LevelUpCard.text = "LEVEL UP · LV %d · +%d GOLD" % [new_level, gold_reward]

func _death_text() -> String:
	match death_cause:
		DeathCause.FALL:
			return "FELL FROM THE BEANSTALK"
		DeathCause.OBSTACLE:
			return "STRUCK BY AN OBSTACLE"
		_:
			return "CAUGHT BY THE SPIDER"

func _time_wings_status() -> String:
	var stage_number := stages.stage_for_y(player.global_position.y)
	if stage_number < Balance.TIME_WINGS_STAGE:
		return "F · TIME WINGS LOCKED"
	if time_wings_remaining > 0.0:
		return "F · TIME WINGS %.1fs" % time_wings_remaining
	if time_wings_used_stage.has(stage_number):
		return "F · TIME WINGS USED"
	return "F · TIME WINGS READY"

func _update_time_wings_orb() -> void:
	var orb := $HUD/TimeWingsOrb as TextureRect
	var stage_number := stages.stage_for_y(player.global_position.y)
	if stage_number < Balance.TIME_WINGS_STAGE:
		orb.modulate = Color(0.38, 0.38, 0.42, 0.55)
	elif time_wings_remaining > 0.0:
		var pulse := 0.86 + sin(Time.get_ticks_msec() * 0.012) * 0.14
		orb.modulate = Color(1.0, pulse, 1.0, 1.0)
	elif time_wings_used_stage.has(stage_number):
		orb.modulate = Color(0.52, 0.44, 0.58, 0.55)
	else:
		orb.modulate = Color.WHITE

func _stats_text() -> String:
	var total_seconds := int(round(total_time))
	var mm := total_seconds / 60
	var ss := total_seconds % 60
	var best_m := best_spider_distance / Balance.PIXELS_PER_METER
	return "TIME %02d:%02d\nBEAN HITS %d\nCLOSE CALLS %d\nSKILLS USED %d\nBEST SPIDER DISTANCE %.1fm" % [mm, ss, beans.hit_count, close_calls, skills_used, best_m]

func _publish_readonly_web_state() -> void:
	if not OS.has_feature("web") or not _debug_state_enabled():
		return
	JavaScriptBridge.eval("window.beanstalkState = %s;" % JSON.stringify(_readonly_state_snapshot()), true)

func _debug_state_enabled() -> bool:
	if OS.has_feature("web"):
		return "debug" in str(JavaScriptBridge.eval("window.location.hash", true)).to_lower()
	return OS.is_debug_build()

func _readonly_state_snapshot() -> Dictionary:
	var stage_number := stages.stage_for_y(player.global_position.y)
	var dead_end_route := player.active_branch if stage_number >= 3 else stages.route_for_x(player.global_position.x)
	var dead_end_distance := stages.next_dead_end_distance(player.global_position.y, player.global_position.x, dead_end_route)
	var spider_visibility := {"on_screen": false, "visible_px": 0.0}
	var spider_visual := spider.get_node_or_null("Body")
	if spider_visual != null and spider_visual.has_method("visibility_snapshot"):
		spider_visibility = spider_visual.visibility_snapshot()
	var player_visual := {"mode": "unknown", "frame": "unknown", "skin": "unknown"}
	var player_body := player.get_node_or_null("Body")
	if player_body != null and player_body.has_method("visual_snapshot"):
		player_visual = player_body.visual_snapshot()
	var state_beans := []
	for bean in get_tree().get_nodes_in_group("beans"):
		if bean.active:
			state_beans.append({
				"route": bean.blocked_route,
				"phase": "falling" if bean.falling else "warning",
				"y": bean.global_position.y,
				"warning_visible_seconds": bean.warning_visible_seconds,
			})
	return {
		"app_state": AppState.keys()[app_state],
		"intro": {"active": intro_active, "beat": intro_beat, "t": intro_t, "visual_mode": INTRO_VISUAL_MODES[intro_beat] if intro_active else "none"},
		"death_cause": DeathCause.keys()[death_cause],
		"stage": stages.stage_for_y(player.global_position.y),
		"player": {"x": player.global_position.x, "y": player.global_position.y, "vy": player.velocity.y},
		"player_visual": player_visual,
		"spider": {"y": spider.global_position.y, "distance": gauge.distance_px, "ratio": spider.speed_ratio, "boost": spider.boost_remaining > 0.0, "boost_remaining": spider.boost_remaining, "catchup_active": spider.catchup_active, "catchup_blend": spider.catchup_blend, "on_screen": spider_visibility.on_screen, "visible_px": spider_visibility.visible_px},
		"gauge_level": gauge.level,
		"time_wings": {"unlocked": stages.stage_for_y(player.global_position.y) >= Balance.TIME_WINGS_STAGE, "active": time_wings_remaining > 0.0, "remaining": time_wings_remaining, "started_remaining": time_wings_started_remaining, "used": time_wings_used_stage.has(stages.stage_for_y(player.global_position.y))},
		"audio_events": audio.audio_event_snapshot(),
		"gold_fx": golds.active_feedback_snapshot(),
		"tempo": {"stage_seconds": Balance.STAGE_DURATION_SECONDS, "events_in_stage": stages.pattern_for_stage(stage_number).encounters.size()},
		"fx": {"shake": shake_remaining, "close_text": close_text_remaining},
		"beans": state_beans,
		"next_dead_end": {"route": dead_end_route, "distance_px": null if is_inf(dead_end_distance) else dead_end_distance},
		"open_routes_at_player": stages.open_routes_at(player.global_position.y),
		"active_branch": player.active_branch,
		"support_state": player.support_state_name(),
		"transition_state": player.transition_state_name(),
		"branch_target": player.transition_to,
		"branch_transition_count": player.branch_transition_count,
		"on_support": player.on_support,
		"stats": {"time": total_time, "bean_hits": beans.hit_count, "close_calls": close_calls, "skills_used": skills_used, "best_distance": best_spider_distance},
		"restart": {"count": stage_restart_count, "start_distance": stage_restart_start_distance},
		"shop": economy.shop_snapshot(),
	}

func _apply_debug_meta_overrides() -> void:
	if not OS.has_feature("web"):
		return
	var hash := str(JavaScriptBridge.eval("window.location.hash", true))
	if "debug" not in hash.to_lower():
		return
	var raw := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).toString()", true))
	for pair in raw.split("&", false):
		var parts := pair.split("=", true, 1)
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		if parts[0] == "gold": economy.gold = maxi(int(parts[1]), 0)
		if parts[0] == "level": economy.level = maxi(int(parts[1]), 1)
		if parts[0] == "stage": debug_start_stage = clampi(int(parts[1]), 1, Balance.STAGE_COUNT)

func _start_debug_stage(stage_number: int) -> void:
	if stage_number <= 1 or stage_number > Balance.STAGE_COUNT:
		return
	var start_y := -Balance.STAGE_HEIGHT * float(stage_number - 1)
	player.reset_run(Vector2(0.0, start_y))
	spider.reset_run(Vector2(0.0, start_y + Balance.START_DISTANCE))
	stages.update_progress(start_y)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)

func _ensure_actions() -> void:
	_add_key_action("time_wings", [KEY_F])
	_add_key_action("pause", [KEY_ESCAPE, KEY_P])
	_add_key_action("mute", [KEY_M])
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
