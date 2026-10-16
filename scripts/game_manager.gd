class_name GameManager
extends Node2D

const TIME_WINGS_ICON := preload("res://assets/art/character_rig/wing/time_wings.png")
const PET_FOLLOWER := preload("res://scripts/pet_follower.gd")
const MODE_NORMAL := "NORMAL"
const MODE_NIGHTMARE := "NIGHTMARE"
const SPIDER_RED_ZONE_PX := 96.0

class SpeakerButton extends Button:
	var sound_enabled := true:
		set(value):
			if sound_enabled != value:
				sound_enabled = value
				queue_redraw()

	func _draw() -> void:
		var origin := size * 0.5 - Vector2(16, 16)
		var ink := get_theme_color("font_color")
		draw_colored_polygon(PackedVector2Array([
			origin + Vector2(2, 11), origin + Vector2(9, 11),
			origin + Vector2(17, 4), origin + Vector2(17, 28),
			origin + Vector2(9, 21), origin + Vector2(2, 21),
		]), ink)
		if sound_enabled:
			draw_arc(origin + Vector2(17, 16), 8, -PI * 0.35, PI * 0.35, 16, ink, 2, true)
			draw_arc(origin + Vector2(17, 16), 13, -PI * 0.35, PI * 0.35, 20, ink, 2, true)
		else:
			draw_line(origin + Vector2(1, 1), origin + Vector2(31, 31), ink, 3, true)

class HeartIcon extends Control:
	var filled := true
	var loss_tween: Tween

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(26.0, 26.0)
		pivot_offset = Vector2(13.0, 13.0)

	func _exit_tree() -> void:
		if loss_tween != null and loss_tween.is_valid():
			loss_tween.kill()

	func set_filled(value: bool) -> void:
		if filled == value:
			return
		filled = value
		queue_redraw()

	func animate_loss() -> void:
		if loss_tween != null and loss_tween.is_valid():
			loss_tween.kill()
		scale = Vector2.ONE
		modulate = Color.WHITE
		loss_tween = create_tween().set_parallel(true)
		loss_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		loss_tween.tween_property(self, "scale", Vector2(0.35, 0.35), 0.3)
		loss_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.3)
		loss_tween.chain().tween_callback(_reset_after_loss)

	func _reset_after_loss() -> void:
		scale = Vector2.ONE
		modulate = Color.WHITE

	func _draw() -> void:
		var outline := Color("142b39")
		var fill := Color("e8394a") if filled else Color(0.12, 0.16, 0.19, 0.48)
		_draw_heart(outline, 0.0)
		_draw_heart(fill, 1.8)

	func _draw_heart(color: Color, inset: float) -> void:
		var radius := 6.5 - inset * 0.45
		var left_center := Vector2(7.6 + inset * 0.35, 8.0 + inset * 0.35)
		var right_center := Vector2(18.4 - inset * 0.35, 8.0 + inset * 0.35)
		draw_circle(left_center, radius, color, true, -1.0, true)
		draw_circle(right_center, radius, color, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(1.2 + inset, 8.2 + inset * 0.35),
			Vector2(24.8 - inset, 8.2 + inset * 0.35),
			Vector2(13.0, 24.0 - inset),
		]), color)

enum State { PLAYING, PLAYER_DEAD, PROTOTYPE_COMPLETE }
enum AppState { MENU, INTRO, PLAYING, PAUSED, PLAYER_DEAD, FINAL_CINEMATIC, GAME_COMPLETE, SHOP, CHARACTER_SELECT, MAP, CREDITS }
enum DeathCause { NONE, FALL, CAUGHT, OBSTACLE }
var state := State.PLAYING
var app_state := AppState.MENU
var resume_available := false
var menu_help_open := false
var death_cause := DeathCause.NONE
@onready var player: PlayerController = $Player
@onready var spider: SpiderController = $Spider
@onready var gauge: SpiderDistanceGauge = $HUD/Gauge
@onready var stages: StageManager = $StageManager
@onready var beans: BeanSpawner = $BeanSpawner
@onready var rocks: RockManager = $RockManager
@onready var audio: BeanstalkAudio = $Audio
@onready var storm: StormMechanics = $StormMechanics
@onready var platform_services: Node = get_node("/root/PlatformServices")
var total_time := 0.0
var score := 0.0
var run_coins := 0
var score_previous_y := 0.0
var climb_previous_y := 0.0
var run_generation := 0
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
var time_wings_notice := ""
var time_wings_notice_remaining := 0.0
var time_wings_stage_intro_shown := false
var fire_wings_remaining := 0.0
var fire_wings_started_remaining := 0.0
var fire_wings_used_stage := {}
var tutorial_remaining := 0.0
var tutorial_text := ""
var touch_actions := {}
var dead_restart_delay := 0.0
var confirm_pending := false
var ui_theme: Theme
var stage_restart_count := 0
var stage_restart_start_distance := 0.0
var last_time_command_source := ""
var save_manager := SaveManager.new()
var leaderboard_service: Node
var death_phase := ""
var result_new_best := false
var result_best := 0
var result_recorded := false
var result_elapsed := 0.0
var leaderboard_visible := false
var leaderboard_entries: Array = []
var leaderboard_source := ""
var leaderboard_rows: Array[PanelContainer] = []
var ended_runs_since_interstitial := 0
var last_interstitial_msec := 0
var economy := EconomyManager.new()
var golds := GoldManager.new()
var gold_counter_tween: Tween
var gold_combo_tween: Tween
var reward_toast_remaining := 0.0
var level_up_remaining := 0.0
var double_reward_remaining := 0.0
var last_stage_gold_reward := 0
var death_count_by_stage := {}
var continue_used_this_run := false
var continue_checkpoint := {}
var max_lives := 3
var current_lives := 3
var hit_invulnerability_remaining := 0.0
var danger_remaining := 0.0
var danger_vignette: ColorRect
var danger_vignette_alpha := 0.0
var danger_pulse_elapsed := 0.0
var displayed_lives := -1
var ad_revives_by_stage := {}
var completed_since_interstitial := 0
var platform_pause_active := false
var paused_by_platform := false
var mode := MODE_NORMAL
var challenge_eligible := true
var damage_events := 0
var spider_red_zone_seen := false
var completed_stages := {}
var completion_committed := false
const INTRO_BEAT_SECONDS := [2.3, 3.0, 2.3]
const CAMERA_PLAY_POSITION := Vector2(0.0, -120.0)
const INTRO_LOOK_UP_POSITION := Vector2(0.0, -210.0)
const INTRO_GUARDIAN_SCALE := Vector2.ONE * 1.35
const INTRO_VISUAL_MODES := ["climb", "summit", "guardian"]
var intro_active := false
var intro_beat := 0
var intro_t := 0.0
var debug_start_stage := 1
var debug_sandbox := ""
var meta_ui: MetaShopUI
var daily_card: PanelContainer
var daily_reward_label: Label
var daily_claim_button: Button
const FINAL_CINEMATIC_SECONDS := 8.0
var final_t := 0.0
var final_character: Sprite2D
var final_wings: Polygon2D
var last_web_state_publish_msec := -1000
const WEB_STATE_INTERVAL_MSEC := 50
const GHOST_SAMPLE_SECONDS := 0.1
var meta_settings := {"sound": true, "ghost": true}
var tutorial_active := false
var tutorial_step := 0
var tutorial_force := false
var tutorial_step_elapsed := 0.0
var tutorial_transition_baseline := 0
var tutorial_catch_triggered := false
var tutorial_bean: BeanProjectile
var result_badges: Array[Label] = []
var ghost_sprite: Sprite2D
var ghost_outline: Sprite2D
var ghost_trace: Array = []
var ghost_playback: Array = []
var ghost_stage := 1
var ghost_stage_elapsed := 0.0
var ghost_sample_elapsed := 0.0
var ghost_best_time := 0.0
var pet_follower: Node2D

func _ready() -> void:
	process_physics_priority = 10
	save_manager.profile_loaded.connect(_apply_loaded_profile)
	save_manager.configure_platform(platform_services)
	if not economy.initialize(save_manager):
		push_error("Economy config could not be loaded")
	leaderboard_service = preload("res://scripts/leaderboard_service.gd").new()
	leaderboard_service.name = "LeaderboardService"
	add_child(leaderboard_service)
	leaderboard_service.configure(save_manager)
	max_lives = maxi(int(economy.config.get("lives_per_run", 3)), 1)
	current_lives = max_lives
	_apply_loaded_profile({"meta_systems": save_manager.meta_systems_snapshot()})
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
	rocks.setup(player, stages)
	stages.prototype_completed.connect(_on_prototype_completed)
	stages.stage_completed.connect(_on_stage_completed)
	_ensure_actions()
	_setup_hud()
	pet_follower = PET_FOLLOWER.new()
	pet_follower.name = "PetFollower"
	add_child(pet_follower)
	pet_follower.setup(player, final_character)
	_sync_pet()
	economy.changed.connect(_sync_pet)
	layout_hud_for_viewport(get_viewport_rect().size)
	get_viewport().size_changed.connect(func(): layout_hud_for_viewport(get_viewport_rect().size))
	_start_selected_run()

func _physics_process(delta: float) -> void:
	if app_state == AppState.PLAYER_DEAD and death_phase == "result" and not leaderboard_visible:
		result_elapsed += delta
		if result_elapsed >= 1.0:
			_show_leaderboard()
	if app_state == AppState.PLAYING and not tutorial_active:
		score += maxf(score_previous_y - player.global_position.y, 0.0) * 0.1 * clampi(golds.combo, 1, 5)
		economy.add_climb(maxf(climb_previous_y - player.global_position.y, 0.0))
	climb_previous_y = player.global_position.y
	economy.update_climb_save(delta)
	score_previous_y = player.global_position.y
	player.speed_scale = 1.0 if tutorial_active else Balance.speed_scale_for_time(total_time)
	_update_hit_invulnerability(delta)
	_update_danger(delta)
	reward_toast_remaining = maxf(reward_toast_remaining - delta, 0.0)
	time_wings_notice_remaining = maxf(time_wings_notice_remaining - delta, 0.0)
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
	if app_state == AppState.FINAL_CINEMATIC:
		_update_final_cinematic(delta)
		_update_hud()
		_publish_readonly_web_state()
		return
	if app_state in [AppState.PAUSED, AppState.MENU, AppState.PLAYER_DEAD, AppState.GAME_COMPLETE, AppState.SHOP, AppState.CHARACTER_SELECT, AppState.MAP, AppState.CREDITS]:
		_apply_impact_fx(0.0)
		_update_hud()
		_publish_readonly_web_state()
		return
	if not tutorial_active:
		total_time += delta
		player.speed_scale = Balance.speed_scale_for_time(total_time)
	if tutorial_active:
		_update_onboarding(delta)
	else:
		_update_ghost(delta)
	shake_remaining = maxf(shake_remaining - delta, 0.0)
	close_text_remaining = maxf(close_text_remaining - delta, 0.0)
	danger_pulse_remaining = maxf(danger_pulse_remaining - delta, 0.0)
	_apply_impact_fx(delta)
	if time_wings_remaining > 0.0:
		time_wings_remaining = maxf(time_wings_remaining - delta, 0.0)
		if time_wings_remaining <= 0.0:
			player.time_wings_active = false
			player.remove_from_group("time_wings_active")
	if fire_wings_remaining > 0.0:
		fire_wings_remaining = maxf(fire_wings_remaining - delta, 0.0)
		if fire_wings_remaining <= 0.0:
			player.fire_wings_active = false
	if tutorial_remaining > 0.0:
		tutorial_remaining = maxf(tutorial_remaining - delta, 0.0)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	if gauge.distance_px < SPIDER_RED_ZONE_PX:
		spider_red_zone_seen = true
	if not tutorial_active:
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

func _input(event: InputEvent) -> void:
	if app_state == AppState.PLAYER_DEAD and death_phase == "result" and not leaderboard_visible:
		if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_show_leaderboard()
			get_viewport().set_input_as_handled()
			return
	if app_state == AppState.PLAYER_DEAD and _handle_death_panel_keyboard(event):
		get_viewport().set_input_as_handled()
		return
	var is_time_wings_key: bool = event.is_action_pressed("time_wings") or (event is InputEventKey and event.physical_keycode == KEY_F and event.pressed)
	if app_state == AppState.PLAYING and is_time_wings_key and not (event is InputEventKey and event.echo):
		dispatch_command("time_wings", "keyboard")
		get_viewport().set_input_as_handled()

func _handle_death_panel_keyboard(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.is_action_pressed("ui_accept"):
		_request_confirm()
		return true
	var direction := 0
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or event.is_action_pressed("move_right"):
		direction = 1
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or event.is_action_pressed("move_left"):
		direction = -1
	if direction == 0:
		return false
	var actions := _visible_death_actions()
	if actions.is_empty():
		return true
	var focused := get_viewport().gui_get_focus_owner() as Button
	var focused_index := actions.find(focused)
	if focused_index < 0:
		focused_index = 0 if direction > 0 else actions.size() - 1
	else:
		focused_index = wrapi(focused_index + direction, 0, actions.size())
	actions[focused_index].grab_focus()
	return true

func _visible_death_actions() -> Array[Button]:
	var visible_actions: Array[Button] = []
	for button: Button in [$HUD/ContinueAd, $HUD/NoThanks, $HUD/RestartRun, $HUD/DeathShop, $HUD/DeathMenu]:
		if button.visible and not button.disabled:
			visible_actions.append(button)
	return visible_actions

func _unhandled_input(event: InputEvent) -> void:
	if app_state == AppState.INTRO and _is_intro_skip_event(event):
		_finish_intro()
		return
	if app_state == AppState.FINAL_CINEMATIC and _is_intro_skip_event(event):
		_finish_final_cinematic()
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
		_toggle_sound_setting()
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
	elif event.is_action_pressed("pause") and app_state == AppState.CREDITS:
		_show_menu()
	if event.is_action_pressed("fire_wings"):
		dispatch_command("fire_wings", "keyboard")
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and app_state == AppState.PLAYING:
		_pause_game()

func _exit_tree() -> void:
	economy.flush_climb_save()

func _debug_evidence_stage(stage_number: int) -> void:
	if not _debug_state_enabled() or stage_number < 1 or stage_number > Balance.STAGE_COUNT:
		return
	player.global_position = Vector2(0, -(stages.stage_start_height(stage_number) + stages.stage_length(stage_number) * 0.35))
	spider.reset_run(player.global_position + Vector2(0, _spider_start_gap(stage_number)))
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
		if wings_button != null and wings_button.visible and Rect2(wings_button.position, wings_button.size).has_point(event.position):
			touch_actions[event.index] = "time_wings"
			dispatch_command("time_wings", "mobile")
			return
		var fire_button := get_node_or_null("HUD/TouchFire") as Button
		if fire_button != null and fire_button.visible and Rect2(fire_button.position, fire_button.size).has_point(event.position):
			touch_actions[event.index] = "fire_wings"
			dispatch_command("fire_wings", "mobile")
			return
		var action := "move_left" if event.position.x < 172.0 else "move_right"
		touch_actions[event.index] = action
		Input.action_press(action)
		dispatch_command(action, "mobile")
	elif touch_actions.has(event.index):
		var released_action: String = touch_actions[event.index]
		touch_actions.erase(event.index)
		if released_action not in ["time_wings", "fire_wings"] and not touch_actions.values().has(released_action):
			Input.action_release(released_action)

func restart() -> void:
	economy.begin_run()
	resume_available = false
	_clear_direction_inputs()
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	beans.sandbox_mode = false
	rocks.reset_run()
	storm.reset_run()
	player.reset_run(Vector2(0, 0))
	climb_previous_y = player.global_position.y
	spider.reset_run(Vector2(0, _spider_start_gap(1)))
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	rocks.set_physics_process(true)
	storm.set_physics_process(true)
	player.visible = true
	spider.visible = true
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null:
		spider_body.visible = true
	stages.reset_run()
	golds.reset_run()
	golds.visible = true
	state = State.PLAYING
	app_state = AppState.PLAYING
	death_cause = DeathCause.NONE
	dead_restart_delay = 0.0
	confirm_pending = false
	total_time = 0.0
	score = 0.0
	run_coins = 0
	death_phase = ""
	result_new_best = false
	result_recorded = false
	result_elapsed = 0.0
	leaderboard_visible = false
	leaderboard_entries = []
	leaderboard_source = ""
	score_previous_y = player.global_position.y
	run_generation += 1
	player.speed_scale = 1.0
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
	time_wings_notice = ""
	time_wings_notice_remaining = 0.0
	time_wings_stage_intro_shown = false
	fire_wings_remaining = 0.0
	fire_wings_started_remaining = 0.0
	fire_wings_used_stage.clear()
	death_count_by_stage.clear()
	continue_used_this_run = false
	continue_checkpoint = {}
	current_lives = max_lives
	hit_invulnerability_remaining = 0.0
	ad_revives_by_stage.clear()
	completed_since_interstitial = 0
	challenge_eligible = mode == MODE_NORMAL and debug_start_stage == 1 and debug_sandbox.is_empty()
	damage_events = 0
	spider_red_zone_seen = false
	completed_stages.clear()
	completion_committed = false
	player.time_wings_active = false
	player.fire_wings_active = false
	player.remove_from_group("time_wings_active")
	_show_tutorial_for_stage(1)
	_reset_stage_ghost(1)
	_begin_danger(true)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_remember_continue_checkpoint()
	_update_hud()

func start_game() -> void:
	audio.play_sfx("ui_click")
	(player.get_node("Body") as PlayerVisual).set_skin(str(economy.shop.selected_character))
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
			if intro_t < 0.34:
				var shake_strength := 9.0 * (1.0 - intro_t / 0.34)
				camera.offset = Vector2.from_angle(intro_t * TAU * 18.0) * shake_strength
			else:
				camera.offset = Vector2.ZERO
	$HUD/IntroSummit.modulate.a = clampf(progress * 4.0, 0.0, 1.0) if intro_beat == 1 else 1.0
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null and intro_beat == 2:
		spider_body.visible = true
		spider_body.position = Vector2.ZERO
		_layout_intro_text(get_viewport_rect().size)
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
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera != null:
			camera.position = CAMERA_PLAY_POSITION
		_layout_intro_text(get_viewport_rect().size)
		audio.play_sfx("spider_scream")

func _finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	intro_beat = 0
	intro_t = 0.0
	# Rebuild the exact normal run start so watching and skipping are identical.
	player.reset_run(Vector2.ZERO)
	climb_previous_y = player.global_position.y
	spider.reset_run(Vector2(0.0, _spider_start_gap(1)))
	beans.reset_run()
	rocks.reset_run()
	storm.reset_run()
	if debug_start_stage > 1:
		_start_debug_stage(debug_start_stage)
	if debug_sandbox == "rocks":
		_start_debug_stage(3)
		rocks.start_sandbox()
	elif debug_sandbox == "storm":
		_start_debug_stage(3)
		storm.configure_sandbox(3)
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	rocks.set_physics_process(true)
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
	score_previous_y = player.global_position.y
	app_state = AppState.PLAYING
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	audio.play_music("music_game")
	if mode == MODE_NORMAL and (tutorial_force or not bool(save_manager.meta_systems_snapshot().tutorial_completed)):
		_start_onboarding()
	else:
		_begin_danger(true)
	_update_hud()
	_publish_readonly_web_state()

func _is_intro_skip_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER or event.physical_keycode == KEY_SPACE)
	if event is InputEventMouseButton:
		return event.pressed
	return event is InputEventScreenTouch and event.pressed

func restart_stage() -> void:
	golds.reset_combo()
	audio.play_sfx("ui_click")
	_clear_direction_inputs()
	var stage_number := stages.current_stage
	current_lives = max_lives
	hit_invulnerability_remaining = 0.0
	continue_used_this_run = false
	ad_revives_by_stage.erase(stage_number)
	challenge_eligible = false
	var start_y := stages.stage_bottom_y(stage_number)
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	rocks.reset_run()
	storm.reset_run()
	shake_remaining = 0.0
	close_text_remaining = 0.0
	danger_pulse_remaining = 0.0
	_apply_impact_fx(0.0)
	player.reset_run(Vector2(0, start_y))
	climb_previous_y = player.global_position.y
	spider.reset_run(Vector2(0, start_y + _spider_start_gap(stage_number)))
	_begin_danger(true)
	stage_restart_count += 1
	stage_restart_start_distance = spider.global_position.y - player.global_position.y
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	rocks.set_physics_process(true)
	time_wings_remaining = 0.0
	time_wings_started_remaining = 0.0
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	time_wings_used_stage.erase(stage_number)
	fire_wings_remaining = 0.0
	fire_wings_started_remaining = 0.0
	player.fire_wings_active = false
	fire_wings_used_stage.erase(stage_number)
	state = State.PLAYING
	app_state = AppState.PLAYING
	death_cause = DeathCause.NONE
	dead_restart_delay = 0.0
	confirm_pending = false
	_show_tutorial_for_stage(stage_number)
	_reset_stage_ghost(stage_number)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_update_hud()
	_publish_readonly_web_state()

func _on_prototype_completed() -> void:
	economy.flush_climb_save()
	resume_available = false
	state = State.PROTOTYPE_COMPLETE
	completed_stages[Balance.STAGE_COUNT] = true
	_commit_run_completion()
	_start_final_cinematic()

func _commit_run_completion() -> void:
	if completion_committed:
		return
	completion_committed = true
	var full_run := completed_stages.size() == Balance.STAGE_COUNT
	for stage_number in range(1, Balance.STAGE_COUNT + 1):
		full_run = full_run and completed_stages.has(stage_number)
	if not full_run:
		return
	var earned := {}
	if mode == MODE_NORMAL and challenge_eligible:
		earned = {
			"NO BEAN HIT": beans.hit_count == 0,
			"NO ROCK HIT": rocks.hit_count == 0,
			"NO DAMAGE": damage_events == 0,
			"UNDER 12 MINUTES": total_time < 720.0,
			"NO SKILLS": skills_used == 0,
			"ZERO SPIDER RED ZONE": not spider_red_zone_seen,
		}
	save_manager.record_completion(mode, total_time, earned)

func _start_final_cinematic() -> void:
	final_t = 0.0
	app_state = AppState.FINAL_CINEMATIC
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	rocks.set_physics_process(false)
	$HUD/IntroSummit.visible = true
	$HUD/IntroSummit.modulate = Color.WHITE
	$HUD/IntroText.visible = true
	$HUD/IntroText.text = "THE TOP OF THE WORLD"
	var body := player.get_node_or_null("Body") as PlayerVisual
	if body != null and body.sprite != null:
		final_character.texture = body.sprite.texture
	final_character.visible = true
	final_character.position = Vector2(480.0, 330.0)
	final_character.rotation = 0.0
	final_wings.visible = false
	_update_hud()

func _update_final_cinematic(delta: float) -> void:
	final_t = minf(final_t + delta, FINAL_CINEMATIC_SECONDS)
	if final_t < 2.0:
		$HUD/IntroText.text = "AT THE SUMMIT, THE GUARDIAN CATCHES UP."
		final_character.position = Vector2(480.0, 330.0)
	elif final_t < 3.0:
		$HUD/IntroText.text = "JUMP."
		final_character.position = Vector2(480.0 + (final_t - 2.0) * 54.0, 330.0 + (final_t - 2.0) * 130.0)
		final_character.rotation = 0.18
	else:
		$HUD/IntroText.text = "THE WOOD-AND-CLOTH WINGS OPEN ABOVE THE CLOUDS."
		final_wings.visible = true
		var glide := (final_t - 3.0) / 5.0
		final_character.position = Vector2(534.0 + glide * 270.0, 430.0 - glide * 210.0 + sin(glide * TAU) * 18.0)
		final_character.rotation = -0.16
		final_wings.position = final_character.position
	if final_t >= FINAL_CINEMATIC_SECONDS:
		_finish_final_cinematic()

func _finish_final_cinematic() -> void:
	if app_state != AppState.FINAL_CINEMATIC:
		return
	final_t = FINAL_CINEMATIC_SECONDS
	final_character.visible = false
	final_wings.visible = false
	$HUD/IntroSummit.visible = false
	$HUD/IntroText.visible = false
	app_state = AppState.GAME_COMPLETE
	_update_hud()
	call_deferred("_focus_complete_action")

func _focus_complete_action() -> void:
	if app_state == AppState.GAME_COMPLETE:
		($HUD/CompleteNewRun as Button).grab_focus()

func _complete_new_run() -> void:
	if app_state == AppState.GAME_COMPLETE:
		start_game()

func _start_nightmare_run() -> void:
	if not bool(save_manager.replay_snapshot().nightmare_unlocked):
		return
	mode = MODE_NIGHTMARE
	start_game()

func _complete_menu() -> void:
	if app_state == AppState.GAME_COMPLETE:
		_show_menu()

func _on_stage_completed(stage_number: int) -> void:
	if not tutorial_active and stage_number == ghost_stage:
		save_manager.record_stage_ghost(mode, stage_number, ghost_stage_elapsed, ghost_trace)
	completed_stages[stage_number] = true
	var player_body := player.get_node_or_null("Body")
	if player_body != null and player_body.has_method("play_celebration"):
		player_body.play_celebration()
	var reward := economy.complete_stage(stage_number)
	economy.mark_stage_completed(stage_number)
	last_stage_gold_reward = int(reward.gold)
	reward_toast_remaining = 0.0
	double_reward_remaining = 0.0
	$HUD/RewardToast.text = "+%d GOLD  +%d XP" % [reward.gold, reward.xp]
	if stage_number < Balance.STAGE_COUNT:
		_show_tutorial_for_stage(stage_number + 1)
		_reset_stage_ghost(stage_number + 1)

func try_time_wings() -> bool:
	var stage_number := stages.stage_for_y(player.global_position.y)
	if app_state != AppState.PLAYING:
		return false
	if stage_number < Balance.TIME_WINGS_STAGE:
		_show_time_wings_notice("Unlocks at Stage 5", 1.2)
		return false
	if time_wings_used_stage.has(stage_number) or time_wings_remaining > 0.0:
		_show_time_wings_notice("Used this stage", 1.2)
		return false
	if fire_wings_remaining > 0.0:
		return false
	time_wings_used_stage[stage_number] = true
	time_wings_remaining = Balance.TIME_WINGS_SECONDS
	time_wings_started_remaining = time_wings_remaining
	player.time_wings_active = true
	player.add_to_group("time_wings_active")
	skills_used += 1
	audio.play_sfx("time_wings")
	audio.wings_was_active = true
	_update_hud()
	return true

func _show_time_wings_notice(text: String, seconds: float) -> void:
	time_wings_notice = text
	time_wings_notice_remaining = seconds
	_update_hud()

func try_fire_wings() -> bool:
	var stage_number := stages.stage_for_y(player.global_position.y)
	var unlocked := stage_number >= Balance.FIRE_WINGS_STAGE or debug_sandbox == "rocks"
	if app_state != AppState.PLAYING or not unlocked or fire_wings_used_stage.has(stage_number) or fire_wings_remaining > 0.0 or time_wings_remaining > 0.0:
		return false
	fire_wings_used_stage[stage_number] = true
	fire_wings_remaining = Balance.FIRE_WINGS_SECONDS
	fire_wings_started_remaining = fire_wings_remaining
	player.fire_wings_active = true
	skills_used += 1
	audio.play_sfx("time_wings")
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
	if command == "fire_wings":
		return try_fire_wings()
	return false

func _die(cause: DeathCause = DeathCause.CAUGHT) -> void:
	if app_state == AppState.PLAYER_DEAD:
		return
	if not tutorial_active:
		if hit_invulnerability_remaining > 0.0:
			_respawn_at_continue_checkpoint()
			return
		_lose_life(cause, true)
		return
	_enter_player_dead(cause)

func _lose_life(cause: DeathCause, respawn_from_checkpoint: bool) -> bool:
	if tutorial_active or app_state != AppState.PLAYING or hit_invulnerability_remaining > 0.0 or current_lives <= 0:
		return false
	current_lives -= 1
	golds.reset_combo()
	_end_danger()
	damage_events += 1
	challenge_eligible = false
	hit_invulnerability_remaining = float(economy.config.get("hit_invulnerability_seconds", 1.5))
	shake_remaining = 0.20
	if current_lives <= 0:
		_enter_player_dead(cause)
	elif respawn_from_checkpoint:
		_respawn_at_continue_checkpoint()
	else:
		_update_hud()
		_publish_readonly_web_state()
	return true

func _enter_player_dead(cause: DeathCause) -> void:
	economy.flush_climb_save()
	golds.reset_combo()
	resume_available = false
	state = State.PLAYER_DEAD
	app_state = AppState.PLAYER_DEAD
	death_cause = cause
	challenge_eligible = false
	_remember_continue_checkpoint()
	var dead_stage := stages.stage_for_y(player.global_position.y)
	death_count_by_stage[dead_stage] = int(death_count_by_stage.get(dead_stage, 0)) + 1
	dead_restart_delay = 0.25
	confirm_pending = false
	player.time_wings_active = false
	player.remove_from_group("time_wings_active")
	player.fire_wings_active = false
	fire_wings_remaining = 0.0
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	rocks.set_physics_process(false)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(false)
	if not tutorial_active:
		death_phase = "continue"
		if not _can_offer_ad_revive() or not platform_services.is_rewarded_supported():
			_show_run_result()
	_update_hud()
	call_deferred("_focus_default_death_action")
	_publish_readonly_web_state()

func _show_run_result() -> void:
	if app_state != AppState.PLAYER_DEAD or tutorial_active or result_recorded:
		return
	death_phase = "result"
	result_recorded = true
	result_elapsed = 0.0
	leaderboard_visible = false
	ended_runs_since_interstitial += 1
	var character := str(economy.shop.selected_character)
	var player_name := str(save_manager.profile.get("player_name", "")).strip_edges()
	if player_name.is_empty():
		player_name = str(economy.config.get("characters", {}).get(character, {}).get("name", character))
	var recorded := save_manager.record_run_score(player_name, int(score), character)
	result_new_best = bool(recorded.new_best)
	result_best = int(recorded.best)
	var generation := run_generation
	leaderboard_service.submit_score(player_name, int(score), func(response: Dictionary):
		if generation != run_generation or not result_recorded:
			return
		leaderboard_entries = response.get("entries", []).duplicate(true)
		leaderboard_source = str(response.get("source", "local"))
		_refresh_leaderboard_rows()
		_update_hud()
	)
	layout_hud_for_viewport(get_viewport_rect().size)
	_update_hud()

func _show_leaderboard() -> void:
	if app_state != AppState.PLAYER_DEAD or death_phase != "result":
		return
	leaderboard_visible = true
	_update_hud()
	call_deferred("_focus_default_death_action")

func _refresh_leaderboard_rows() -> void:
	for index in leaderboard_rows.size():
		var row := leaderboard_rows[index]
		if index >= leaderboard_entries.size():
			continue
		var entry: Dictionary = leaderboard_entries[index]
		(row.get_node("Columns/Rank") as Label).text = str(entry.get("rank", index + 1))
		(row.get_node("Columns/Name") as Label).text = str(entry.get("name", ""))
		(row.get_node("Columns/Score") as Label).text = _format_run_number(int(entry.get("score", 0)))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("47633a") if bool(entry.get("is_player", false)) else Color(0.08, 0.12, 0.09, 0.92)
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		row.add_theme_stylebox_override("panel", style)

func _shop_from_death() -> void:
	if app_state == AppState.PLAYER_DEAD and death_phase == "result" and leaderboard_visible:
		death_phase = ""
		leaderboard_visible = false
		_show_shop()

func _respawn_at_continue_checkpoint() -> void:
	golds.reset_combo()
	var safe_position: Vector2 = continue_checkpoint.get("position", player.global_position)
	safe_position = _validated_continue_position(safe_position)
	continue_checkpoint = {"position": safe_position, "stage": stages.stage_for_y(safe_position.y)}
	player.reset_run(safe_position)
	climb_previous_y = player.global_position.y
	score_previous_y = player.global_position.y
	var safe_stage := stages.stage_for_y(safe_position.y)
	spider.reset_run(safe_position + Vector2(0, _spider_start_gap(safe_stage)))
	rocks.sync_after_player_teleport()
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_update_hud()
	_publish_readonly_web_state()

func _validated_continue_position(candidate: Vector2) -> Vector2:
	var stage_number := stages.stage_for_y(candidate.y)
	var preferred_route := stages.route_for_x(candidate.x)
	if stages.can_enter_route_at(stage_number, preferred_route, stages.progress_in_stage(candidate.y)):
		return candidate
	for step in range(1, 25):
		var sample_y := candidate.y + float(step) * 24.0
		if stages.stage_for_y(sample_y) != stage_number:
			break
		for route in [preferred_route, 1, 0, 2]:
			if stages.can_enter_route_at(stage_number, route, stages.progress_in_stage(sample_y)):
				return Vector2(stages.branch_x_at(route, sample_y), sample_y)
	return Vector2(0.0, stages.stage_bottom_y(stage_number))

func _update_hit_invulnerability(delta: float) -> void:
	if app_state == AppState.PLAYING and hit_invulnerability_remaining > 0.0:
		hit_invulnerability_remaining = maxf(hit_invulnerability_remaining - delta, 0.0)
		player.modulate.a = 0.30 if int(hit_invulnerability_remaining * 12.0) % 2 == 0 else 1.0
	else:
		player.modulate.a = 1.0

func _request_confirm() -> void:
	if tutorial_active and app_state == AppState.PLAYER_DEAD:
		_finish_onboarding()
	elif app_state == AppState.MENU:
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.visible and not focused.disabled:
			focused.pressed.emit()
		else:
			_start_selected_run()
	elif app_state == AppState.INTRO:
		_finish_intro()
	elif app_state == AppState.PLAYER_DEAD:
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.visible and not focused.disabled:
			focused.pressed.emit()
		else:
			_focus_default_death_action()
	elif app_state == AppState.GAME_COMPLETE:
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null and focused.visible:
			focused.pressed.emit()
		else:
			_complete_new_run()

func _spider_can_catch() -> bool:
	if tutorial_active and tutorial_step < 3:
		return false
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
	economy.flush_climb_save()
	menu_help_open = false
	app_state = AppState.MENU
	death_phase = ""
	leaderboard_visible = false
	if meta_ui != null:
		meta_ui.visible = false
	player.set_physics_process(false)
	spider.set_physics_process(false)
	beans.set_physics_process(false)
	golds.visible = false
	layout_hud_for_viewport(get_viewport_rect().size)
	_update_hud()
	call_deferred("_focus_menu_action")

func _focus_menu_action() -> void:
	if app_state == AppState.MENU:
		var action := $HUD/Resume if resume_available else $HUD/NewRun
		(action as Button).grab_focus()

func _resume_from_menu() -> void:
	if app_state != AppState.MENU or not resume_available or platform_pause_active:
		return
	resume_available = false
	golds.visible = true
	_resume_game()

func _show_credits() -> void:
	app_state = AppState.CREDITS
	_update_hud()
	($HUD/InfoBack as Button).grab_focus()

func _replay_tutorial() -> void:
	if resume_available:
		menu_help_open = true
		_show_credits()
		return
	mode = MODE_NORMAL
	tutorial_force = true
	restart()
	_start_onboarding()

func _toggle_sound_setting() -> void:
	meta_settings.sound = not bool(meta_settings.sound)
	audio.set_sound_enabled(bool(meta_settings.sound))
	_save_meta_settings()

func _save_meta_settings() -> void:
	save_manager.write_settings(meta_settings)
	_refresh_sound_icon()
	_update_hud()

func _apply_loaded_profile(loaded_profile: Dictionary) -> void:
	var systems: Dictionary = loaded_profile.get("meta_systems", {}) if loaded_profile.get("meta_systems", {}) is Dictionary else {}
	var settings: Dictionary = systems.get("settings", {}) if systems.get("settings", {}) is Dictionary else {}
	meta_settings = {
		"sound": bool(settings.get("sound", true)) and bool(settings.get("music", true)),
		"ghost": true,
	}
	if audio != null:
		audio.set_sound_enabled(bool(meta_settings.sound))
	_refresh_sound_icon()

func _refresh_sound_icon() -> void:
	if not has_node("HUD/Mute"):
		return
	($HUD/Mute as SpeakerButton).sound_enabled = bool(meta_settings.sound)

func _show_shop() -> void:
	app_state = AppState.SHOP
	meta_ui.open_shop()
	_update_hud()

func _show_map() -> void:
	app_state = AppState.MAP
	meta_ui.open_map()
	_update_hud()

func _show_character_select() -> void:
	app_state = AppState.CHARACTER_SELECT
	meta_ui.open_character_select()
	_update_hud()

func _close_meta_ui() -> void:
	_show_menu()

func _start_selected_run() -> void:
	mode = MODE_NORMAL
	start_game()

func _continue_with_ad() -> void:
	if app_state != AppState.PLAYER_DEAD or death_phase != "continue" or not _can_offer_ad_revive():
		return
	platform_services.show_rewarded("continue_in_stage", _continue_after_reward)

func _continue_after_reward() -> void:
	if app_state != AppState.PLAYER_DEAD or death_phase != "continue":
		return
	var stage_number := stages.stage_for_y(player.global_position.y)
	ad_revives_by_stage[stage_number] = int(ad_revives_by_stage.get(stage_number, 0)) + 1
	continue_used_this_run = true
	current_lives = mini(max_lives, maxi(int(economy.config.get("ad_revive_lives", 1)), 1))
	hit_invulnerability_remaining = float(economy.config.get("hit_invulnerability_seconds", 1.5))
	_respawn_at_continue_checkpoint()
	_resume_after_death()

func _can_offer_ad_revive() -> bool:
	var stage_number := stages.stage_for_y(player.global_position.y)
	var maximum := maxi(int(economy.config.get("ad_revive_max_per_stage", 0)), 0)
	return maximum == 0 or int(ad_revives_by_stage.get(stage_number, 0)) < maximum

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
	death_phase = ""
	leaderboard_visible = false
	death_cause = DeathCause.NONE
	dead_restart_delay = 0.0
	confirm_pending = false
	player.set_physics_process(true)
	spider.set_physics_process(true)
	beans.set_physics_process(true)
	rocks.set_physics_process(true)
	for bean in get_tree().get_nodes_in_group("beans"):
		bean.set_physics_process(true)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	_update_hud()

func _restart_run_from_death() -> void:
	if app_state == AppState.PLAYER_DEAD and death_phase == "result" and leaderboard_visible:
		var now := Time.get_ticks_msec()
		var minimum_delay := maxi(economy.value("interstitial_min_delay_seconds"), 0) * 1000
		if ended_runs_since_interstitial >= 2 and now - last_interstitial_msec >= minimum_delay:
			if platform_services.show_interstitial("play_again"):
				ended_runs_since_interstitial = 0
				last_interstitial_msec = now
		restart()
		_begin_intro()

func _restart_from_death() -> void:
	if app_state != AppState.PLAYER_DEAD:
		return
	if str(economy.config.get("restart_mode", "stage")) == "game":
		restart()
	else:
		restart_stage()

func _menu_from_death() -> void:
	if app_state in [AppState.PLAYER_DEAD, AppState.PAUSED]:
		resume_available = app_state == AppState.PAUSED
		_show_menu()

func _focus_default_death_action() -> void:
	if app_state != AppState.PLAYER_DEAD:
		return
	var actions := _visible_death_actions()
	if not actions.is_empty():
		actions[0].grab_focus()

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
	var next_y := stages.stage_bottom_y(stage_number + 1)
	player.reset_run(Vector2(0, next_y))
	climb_previous_y = player.global_position.y
	spider.reset_run(Vector2(0, next_y + _spider_start_gap(stage_number + 1)))
	_begin_danger(true)
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

func _start_onboarding() -> void:
	if mode == MODE_NIGHTMARE:
		return
	app_state = AppState.PLAYING
	tutorial_active = true
	tutorial_step = 1
	tutorial_step_elapsed = 0.0
	tutorial_catch_triggered = false
	tutorial_bean = null
	_enter_tutorial_arena()
	ghost_sprite.visible = false
	_show_onboarding_step()

func _enter_tutorial_arena() -> void:
	player.speed_scale = 1.0
	danger_remaining = 0.0
	danger_vignette_alpha = 0.0
	for child in get_tree().get_nodes_in_group("run_transient"):
		child.free()
	beans.reset_run()
	beans.sandbox_mode = true
	stages.reset_run()
	var stage_number := 3
	var practice_progress := 0.18
	for sample_index in range(18, 72):
		var candidate := float(sample_index) / 100.0
		if stages.has_route_support_at(stage_number, 0, candidate) and stages.has_route_support_at(stage_number, 1, candidate) and stages.has_route_support_at(stage_number, 2, candidate) and stages.transfer_window_open(stage_number, candidate):
			practice_progress = candidate
			break
	var practice_y := -(stages.stage_start_height(stage_number) + stages.stage_length(stage_number) * practice_progress)
	player.reset_run(Vector2(stages.branch_x_at(1, practice_y), practice_y))
	climb_previous_y = player.global_position.y
	spider.reset_run(player.global_position + Vector2(0.0, 900.0))
	player.set_physics_process(true)
	spider.set_physics_process(false)
	beans.set_physics_process(true)
	rocks.set_physics_process(false)
	storm.set_physics_process(false)
	var spider_body := spider.get_node_or_null("Body") as CanvasItem
	if spider_body != null:
		spider_body.visible = false
	golds.visible = false
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	tutorial_transition_baseline = player.branch_transition_count

func _update_onboarding(delta: float) -> void:
	tutorial_step_elapsed += delta
	if tutorial_step == 2 and tutorial_bean == null and tutorial_step_elapsed >= 0.35:
		_spawn_tutorial_bean()
		_show_onboarding_step()
	if tutorial_step == 1 and player.branch_transition_count > tutorial_transition_baseline:
		tutorial_step = 2
		tutorial_step_elapsed = 0.0
		tutorial_transition_baseline = player.branch_transition_count
		_spawn_tutorial_bean()
		_show_onboarding_step()
	elif tutorial_step == 2 and player.branch_transition_count > tutorial_transition_baseline:
		if tutorial_bean != null and is_instance_valid(tutorial_bean):
			tutorial_bean.consume()
		tutorial_bean = null
		tutorial_step = 3
		tutorial_step_elapsed = 0.0
		_show_onboarding_step()
	elif tutorial_step == 3 and tutorial_step_elapsed >= 0.8 and not tutorial_catch_triggered:
		tutorial_catch_triggered = true
		var spider_body := spider.get_node_or_null("Body") as CanvasItem
		if spider_body != null:
			spider_body.visible = true
		spider.global_position = player.global_position + Vector2(0.0, Balance.CATCH_DISTANCE * 0.5)
		_die(DeathCause.CAUGHT)
		$HUD/TutorialPanel.text = "3 / 3  CAUGHT\nThe death screen offers retry, restart, and menu. This practice catch does not affect your run."
		$HUD/TutorialSkip.text = "START CLIMB"

func _spawn_tutorial_bean() -> void:
	if not tutorial_active or tutorial_step != 2:
		return
	var route := player.transition_to if player.transition_state_name() == "TRANSITION" else player.active_branch
	tutorial_bean = beans.spawn_bean(route, player.global_position.y, "tutorial-dodge-%d" % Time.get_ticks_msec())
	tutorial_bean.request_release()

func _show_onboarding_step() -> void:
	var messages := {
		1: "1 / 3  CHANGE BRANCH\nPress LEFT or RIGHT once. One press commits one branch change.",
		2: "2 / 3  DODGE THE BEAN\nA bean is falling on your route. Change branch once to escape.",
		3: "3 / 3  SPIDER CATCH\nThe spider is closing in. Watch the controlled catch.",
	}
	$HUD/TutorialPanel.text = messages.get(tutorial_step, "")
	$HUD/TutorialSkip.text = "SKIP"
	_update_hud()

func _finish_onboarding() -> void:
	if not tutorial_active:
		return
	tutorial_active = false
	tutorial_force = false
	tutorial_step = 0
	tutorial_bean = null
	save_manager.mark_tutorial_completed()
	restart()

func _reset_stage_ghost(stage_number: int) -> void:
	ghost_stage = stage_number
	ghost_stage_elapsed = 0.0
	ghost_sample_elapsed = GHOST_SAMPLE_SECONDS
	ghost_trace.clear()
	ghost_playback.clear()
	ghost_best_time = 0.0
	var systems := save_manager.meta_systems_snapshot()
	var mode_ghosts: Dictionary = systems.ghosts.get(mode, {})
	var stored: Dictionary = mode_ghosts.get(str(stage_number), {})
	ghost_best_time = float(stored.get("time", 0.0))
	ghost_playback = stored.get("samples", []).duplicate(true)
	if ghost_sprite != null:
		ghost_sprite.visible = false

func _update_ghost(delta: float) -> void:
	ghost_stage_elapsed += delta
	ghost_sample_elapsed += delta
	if ghost_sample_elapsed >= GHOST_SAMPLE_SECONDS:
		ghost_sample_elapsed = fmod(ghost_sample_elapsed, GHOST_SAMPLE_SECONDS)
		ghost_trace.append({"t": ghost_stage_elapsed, "x": player.global_position.x, "y": player.global_position.y, "branch": player.active_branch})
	var visible := bool(meta_settings.ghost) and not ghost_playback.is_empty()
	ghost_sprite.visible = visible
	if not visible:
		return
	var sample: Dictionary = ghost_playback.back()
	for candidate in ghost_playback:
		if float(candidate.t) >= ghost_stage_elapsed:
			sample = candidate
			break
	ghost_sprite.global_position = Vector2(float(sample.x), float(sample.y))
	var body := player.get_node_or_null("Body") as PlayerVisual
	if body != null and body.sprite != null:
		ghost_sprite.texture = body.sprite.texture
		ghost_outline.texture = body.sprite.texture

func _show_tutorial_for_stage(stage_number: int) -> void:
	if is_nightmare_mode():
		tutorial_text = ""
		tutorial_remaining = 0.0
		return
	if stage_number == Balance.TIME_WINGS_STAGE and not time_wings_stage_intro_shown:
		time_wings_stage_intro_shown = true
		_show_time_wings_notice("TIME WINGS · PRESS F", 2.5)
		return
	var messages := {1: "MOVE LEFT / RIGHT", 2: "AVOID", 3: "CHANGE BRANCH", 6: "ROCKS BLOCK THE VINE", 8: "WATCH THE ROLL", 10: "PRESS H", 15: "NO MORE HELP"}
	tutorial_text = messages.get(stage_number, "")
	tutorial_remaining = Balance.TUTORIAL_SECONDS if tutorial_text != "" else 0.0

func show_bean_tutorial() -> void:
	if is_nightmare_mode():
		return
	if tutorial_text != "DODGE THE BEANS":
		tutorial_text = "DODGE THE BEANS"
		tutorial_remaining = Balance.TUTORIAL_SECONDS

func on_bean_hit() -> void:
	if tutorial_active and tutorial_step == 2:
		tutorial_step_elapsed = 0.0
		tutorial_transition_baseline = player.branch_transition_count
		tutorial_bean = null
		$HUD/TutorialPanel.text = "2 / 3  TRY AGAIN\nThe bean hit this branch. Wait for the warning, then change branch once."
		return
	_on_danger_obstacle_hit()

func on_rock_hit() -> void:
	_on_danger_obstacle_hit()

func _on_danger_obstacle_hit() -> void:
	if tutorial_active or app_state != AppState.PLAYING or hit_invulnerability_remaining > 0.0 or current_lives <= 0:
		return
	if danger_remaining > 0.0:
		_lose_life(DeathCause.OBSTACLE, false)
	else:
		_begin_danger()
		hit_invulnerability_remaining = 0.5
		shake_remaining = 0.20

func _begin_danger(immediate := false) -> void:
	danger_remaining = 0.0 if tutorial_active else Balance.DANGER_SECONDS
	if tutorial_active:
		return
	danger_pulse_elapsed = 0.0
	spider.begin_danger(immediate)

func _end_danger() -> void:
	if danger_remaining <= 0.0:
		return
	danger_remaining = 0.0
	spider.retreat_from_danger(_spider_start_gap(stages.stage_for_y(player.global_position.y)))

func _update_danger(delta: float) -> void:
	if app_state != AppState.PLAYING or tutorial_active:
		return
	if danger_remaining > 0.0:
		if danger_remaining <= delta:
			_end_danger()
		else:
			danger_remaining -= delta
		danger_pulse_elapsed += delta
		danger_vignette_alpha = 0.45 + 0.25 * cos(danger_pulse_elapsed * TAU / 0.5)
	else:
		danger_vignette_alpha = move_toward(danger_vignette_alpha, 0.0, delta / 0.3)

func on_environment_hit(kind: String, respawn_from_checkpoint := false) -> void:
	var cause := DeathCause.FALL if kind == "branch_break" else DeathCause.OBSTACLE
	_lose_life(cause, respawn_from_checkpoint)

func is_nightmare_mode() -> bool:
	return mode == MODE_NIGHTMARE

func _spider_start_gap(stage_number: int) -> float:
	var gap := SpiderController.stage_start_gap(stages.template_for_stage(stage_number))
	if is_nightmare_mode():
		gap *= float(StageDatabase.nightmare_modifiers().get("spider_start_gap_scale", 1.0))
	return gap

func _apply_impact_fx(_delta: float) -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		if shake_remaining > 0.0 and app_state == AppState.PLAYING:
			var progress := 1.0 - shake_remaining / 0.20
			camera.offset = Vector2.from_angle(progress * TAU * 7.0) * (6.0 * shake_remaining / 0.20)
		else:
			camera.offset = Vector2.ZERO
	var close_label := player.get_node_or_null("CloseCall") as Label
	if close_label != null:
		close_label.visible = close_text_remaining > 0.0 and app_state == AppState.PLAYING

func _setup_hud() -> void:
	_apply_theme()
	danger_vignette = ColorRect.new()
	danger_vignette.name = "DangerVignette"
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_vignette.z_index = 20
	var danger_shader := Shader.new()
	danger_shader.code = """shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 edge_distance = min(UV, vec2(1.0) - UV);
    float edge = 1.0 - smoothstep(0.0, 0.14, min(edge_distance.x, edge_distance.y));
    COLOR = vec4(0.85, 0.015, 0.025, edge * COLOR.a);
}
"""
	var danger_material := ShaderMaterial.new()
	danger_material.shader = danger_shader
	danger_vignette.material = danger_material
	$HUD.add_child(danger_vignette)
	danger_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	danger_vignette.visible = false
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
	_add_action_button("Resume", "RESUME", _resume_from_menu)
	_add_action_button("NewRun", "NEW RUN", _start_selected_run)
	_add_action_button("Nightmare", "NIGHTMARE", _start_nightmare_run)
	_add_action_button("Shop", "SHOP", _show_shop)
	_add_action_button("Map", "MAP", _show_map)
	_add_action_button("HowToPlay", "HOW TO PLAY", _replay_tutorial)
	_add_action_button("Credits", "CREDITS", _show_credits)
	_build_daily_card()
	_add_label("InfoTitle", Vector2.ZERO, "", 34)
	var info_body := _add_label("InfoBody", Vector2.ZERO, "", 17)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add_action_button("InfoBack", "BACK", _show_menu)
	var tutorial_panel := _add_label("TutorialPanel", Vector2.ZERO, "", 24)
	tutorial_panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tutorial_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tutorial_box := StyleBoxFlat.new()
	tutorial_box.bg_color = Color(0.025, 0.055, 0.075, 0.92)
	tutorial_box.border_color = Color("7ad8d0")
	tutorial_box.set_border_width_all(3)
	tutorial_box.set_corner_radius_all(14)
	tutorial_box.content_margin_left = 18.0
	tutorial_box.content_margin_right = 18.0
	tutorial_panel.add_theme_stylebox_override("normal", tutorial_box)
	_add_action_button("TutorialSkip", "SKIP", _finish_onboarding)
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
	_add_label("StageCounter", Vector2(16, 62), "STAGE 1 / 30", 14)
	var lives := Control.new()
	lives.name = "Lives"
	lives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(lives)
	for index in max_lives:
		var heart := HeartIcon.new()
		heart.name = "Heart%d" % (index + 1)
		heart.position = Vector2(index * 29.0, 0.0)
		heart.size = Vector2(26.0, 26.0)
		lives.add_child(heart)
	_add_label("Tutorial", Vector2(360, 130), "", 22)
	_add_label("TimeWings", Vector2(690, 22), "", 16)
	var wings_notice := _add_label("TimeWingsNotice", Vector2.ZERO, "", 18)
	wings_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wings_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wings_notice.z_index = 20
	wings_notice.add_theme_color_override("font_color", Color("fff8ff"))
	wings_notice.add_theme_color_override("font_outline_color", Color("32154f"))
	wings_notice.add_theme_constant_override("outline_size", 3)
	var wings_notice_style := StyleBoxFlat.new()
	wings_notice_style.bg_color = Color("7a3fa3e8")
	wings_notice_style.border_color = Color("f3d9ff")
	wings_notice_style.set_border_width_all(2)
	wings_notice_style.set_corner_radius_all(10)
	wings_notice_style.content_margin_left = 10.0
	wings_notice_style.content_margin_right = 10.0
	wings_notice.add_theme_stylebox_override("normal", wings_notice_style)
	_add_label("FireWings", Vector2(690, 44), "", 16)
	_add_label("GoldStatus", Vector2(690, 62), "GOLD 0", 18)
	_add_label("Score", Vector2(708, 8), "0", 30)
	var run_coins_label := _add_label("RunCoins", Vector2(708, 48), "0", 20)
	var run_coin_icon := TextureRect.new()
	run_coin_icon.name = "Icon"
	run_coin_icon.texture = preload("res://assets/art/items/gold_coin.png")
	run_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	run_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	run_coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	run_coin_icon.size = Vector2(22.0, 22.0)
	run_coins_label.add_child(run_coin_icon)
	var combo_label := _add_label("GoldCombo", Vector2(690, 119), "", 16)
	combo_label.modulate.a = 0.0
	var flight_layer := Node2D.new()
	flight_layer.name = "GoldFlights"
	$HUD.add_child(flight_layer)
	_add_label("XPStatus", Vector2(690, 87), "LV 1 · XP 0/100", 14)
	var xp_bar := ProgressBar.new()
	xp_bar.name = "XPBar"
	xp_bar.show_percentage = false
	xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(xp_bar)
	_add_label("RewardToast", Vector2(300, 152), "", 20)
	_add_label("LevelUpCard", Vector2(300, 202), "", 28)
	var death_backdrop := ColorRect.new()
	death_backdrop.name = "DeathBackdrop"
	death_backdrop.color = Color(0.025, 0.05, 0.03, 0.96)
	death_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	$HUD.add_child(death_backdrop)
	$HUD.move_child(death_backdrop, $HUD/Dead.get_index())
	_add_label("MenuBest", Vector2.ZERO, "", 16)
	_add_label("RunBest", Vector2.ZERO, "", 20)
	_add_label("RunCoinsResult", Vector2.ZERO, "", 22)
	_add_label("LeaderboardTitle", Vector2.ZERO, "LEADERBOARD", 26)
	_add_label("LeaderboardSource", Vector2.ZERO, "", 13)
	for index in 10:
		var row := PanelContainer.new()
		row.name = "LeaderboardRow%d" % index
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var columns := HBoxContainer.new()
		columns.name = "Columns"
		columns.add_theme_constant_override("separation", 8)
		columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(columns)
		for field in ["Rank", "Name", "Score"]:
			var label := Label.new()
			label.name = field
			label.theme = ui_theme
			label.add_theme_font_size_override("font_size", 16)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if field == "Name":
				label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			elif field == "Score":
				label.custom_minimum_size.x = 85.0
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			else:
				label.custom_minimum_size.x = 26.0
			columns.add_child(label)
		$HUD.add_child(row)
		leaderboard_rows.append(row)
	_add_action_button("ContinueAd", "CONTINUE · AD", _continue_with_ad)
	_add_action_button("NoThanks", "NO THANKS", _show_run_result)
	_add_action_button("DeathShop", "SHOP", _shop_from_death)
	_add_action_button("RetryStage", "RESTART", _restart_from_death)
	_add_action_button("RestartRun", "PLAY AGAIN", _restart_run_from_death)
	_add_action_button("DeathMenu", "MENU", _menu_from_death)
	_add_action_button("PauseMenu", "MENU", _menu_from_death)
	_add_action_button("SkipStageAd", "SKIP STAGE (AD)", _skip_stage_with_ad)
	_add_action_button("DoubleStageReward", "DOUBLE +0 (AD)", _double_stage_reward_with_ad)
	_add_action_button("GetMoreGold", "GET 100 GOLD (AD)", _get_more_gold_with_ad)
	_add_action_button("RemoveAds", "REMOVE ADS", platform_services.purchase_remove_ads)
	var wings_orb := TextureRect.new()
	wings_orb.name = "TimeWingsOrb"
	wings_orb.texture = TIME_WINGS_ICON
	wings_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wings_orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wings_orb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wings_orb)
	var wings_bar := ProgressBar.new()
	wings_bar.name = "TimeWingsBar"
	wings_bar.max_value = Balance.TIME_WINGS_SECONDS
	wings_bar.show_percentage = false
	wings_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(wings_bar)
	var result_panel := Panel.new()
	result_panel.name = "ResultPanel"
	result_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result_panel.z_index = -1
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color(0.025, 0.055, 0.075, 0.94)
	result_style.border_color = Color("7ad8d0")
	result_style.set_border_width_all(3)
	result_style.set_corner_radius_all(18)
	result_panel.add_theme_stylebox_override("panel", result_style)
	$HUD.add_child(result_panel)
	_add_label("Stats", Vector2(300, 190), "", 18)
	_add_label("Replay", Vector2(300, 375), "", 18)
	for index in SaveManager.CHALLENGE_NAMES.size():
		var badge := _add_label("Challenge%d" % index, Vector2.ZERO, "", 16)
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		result_badges.append(badge)
	_add_action_button("CompleteNewRun", "PLAY AGAIN", _complete_new_run)
	_add_action_button("CompleteNightmare", "NIGHTMARE", _start_nightmare_run)
	_add_action_button("CompleteMenu", "MENU", _complete_menu)
	final_character = Sprite2D.new()
	final_character.name = "FinalCharacter"
	final_character.scale = Vector2.ONE * 0.49
	final_character.visible = false
	$HUD.add_child(final_character)
	final_wings = Polygon2D.new()
	final_wings.name = "FinalWoodClothWings"
	final_wings.polygon = PackedVector2Array([Vector2(-98, 0), Vector2(-28, -30), Vector2(0, -8), Vector2(28, -30), Vector2(98, 0), Vector2(34, 22), Vector2(0, 8), Vector2(-34, 22)])
	final_wings.color = Color("d9b878")
	final_wings.visible = false
	$HUD.add_child(final_wings)
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
	_add_touch_button("TouchLeft", Rect2(36, 392, 136, 132), "LEFT", "move_left")
	_add_touch_button("TouchRight", Rect2(180, 392, 136, 132), "RIGHT", "move_right")
	_add_touch_button("TouchWings", Rect2(640, 392, 145, 132), "TIME", "time_wings")
	_add_touch_button("TouchFire", Rect2(795, 392, 145, 132), "FIRE", "fire_wings")
	meta_ui = MetaShopUI.new()
	meta_ui.name = "MetaShop"
	meta_ui.visible = false
	$HUD.add_child(meta_ui)
	meta_ui.setup(economy, player.get_node("Body") as PlayerVisual, platform_services)
	meta_ui.closed.connect(_close_meta_ui)
	meta_ui.run_started.connect(_start_selected_run)
	ghost_sprite = Sprite2D.new()
	ghost_sprite.name = "StageGhost"
	ghost_sprite.scale = Vector2.ONE * 0.49
	ghost_sprite.modulate = Color(0.72, 0.94, 1.0, 0.40)
	ghost_sprite.z_index = 4
	ghost_sprite.visible = false
	add_child(ghost_sprite)
	ghost_outline = Sprite2D.new()
	ghost_outline.name = "Outline"
	ghost_outline.show_behind_parent = true
	ghost_outline.scale = Vector2.ONE * 1.10
	ghost_outline.modulate = Color(0.88, 0.98, 1.0, 0.72)
	ghost_sprite.add_child(ghost_outline)
	# Keep the replay above the world but below the live character when their
	# sampled positions match exactly.
	player.z_index = 5
	economy.changed.connect(func(_snapshot): _refresh_daily_card())
	_refresh_daily_card()
	_refresh_sound_icon()

func _build_daily_card() -> void:
	daily_card = PanelContainer.new()
	daily_card.name = "DailyCard"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("173a31")
	style.border_color = Color("e0ba4c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	daily_card.add_theme_stylebox_override("panel", style)
	var body := VBoxContainer.new()
	daily_card.add_child(body)
	var title := Label.new()
	title.text = "DAILY BONUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	body.add_child(title)
	daily_reward_label = Label.new()
	daily_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(daily_reward_label)
	daily_claim_button = Button.new()
	daily_claim_button.custom_minimum_size.y = 36
	daily_claim_button.pressed.connect(_claim_daily_bonus)
	body.add_child(daily_claim_button)
	$HUD.add_child(daily_card)

func _refresh_daily_card() -> void:
	if daily_card == null:
		return
	var daily := economy.daily_snapshot()
	var day_index := int(daily.day_index)
	daily_reward_label.text = "DAY 7 · RARE OUTFIT" if day_index == 7 else "DAY %d · %d GOLD" % [day_index, int(economy.config.daily_login_gold[day_index - 1])]
	daily_claim_button.text = "CLAIMED TODAY" if daily.claimed_today else "CLAIM"
	daily_claim_button.disabled = bool(daily.claimed_today)

func _claim_daily_bonus() -> void:
	var reward := economy.claim_daily_bonus()
	if reward.is_empty():
		return
	_refresh_daily_card()

func layout_hud_for_viewport(viewport_size: Vector2) -> void:
	var width := maxf(viewport_size.x, 320.0)
	var height := maxf(viewport_size.y, 320.0)
	var portrait := width < height
	var compact := height < 450.0
	var menu_action_y := height - 56.0
	var logo_y := 8.0
	var logo_width := minf(170.0 if compact else 280.0, width * 0.34)
	var logo_height := logo_width / 1.5
	var logo := $HUD/MenuLogo as TextureRect
	logo.position = Vector2((width - logo_width) * 0.5, logo_y)
	logo.size = Vector2(logo_width, logo_height)
	var prompt := $HUD/Menu as Label
	prompt.position = Vector2(0.0, logo.position.y + logo.size.y + 24.0)
	prompt.size = Vector2(width, 26.0 if compact else 30.0)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUD/Mute.position = Vector2(width - (68.0 if portrait else 128.0), 124.0)
	$HUD/Mute.size = Vector2(56.0, 56.0)
	$HUD/Lives.position = Vector2(14.0, 12.0)
	$HUD/Lives.size = Vector2(max_lives * 29.0, 26.0)
	var skill := $HUD/TimeWings as Label
	var skill_orb := $HUD/TimeWingsOrb as TextureRect
	var skill_y := maxf(height - (226.0 if DisplayServer.is_touchscreen_available() else 84.0), 126.0)
	skill_orb.position = Vector2(maxf(width - 310.0, 10.0), skill_y)
	skill_orb.size = Vector2(54.0, 54.0)
	skill.position = Vector2(maxf(width - 248.0, 70.0), skill_y + 2.0)
	skill.size = Vector2(minf(230.0, width - skill.position.x - 10.0), 28.0)
	skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var skill_bar := $HUD/TimeWingsBar as ProgressBar
	skill_bar.position = Vector2(skill.position.x, skill_y + 34.0)
	skill_bar.size = Vector2(skill.size.x, 10.0)
	var skill_notice := $HUD/TimeWingsNotice as Label
	var skill_notice_width := minf(300.0, width - 20.0)
	skill_notice.position = Vector2(width - skill_notice_width - 10.0, maxf(skill_y - 46.0, 10.0))
	skill_notice.size = Vector2(skill_notice_width, 38.0)
	var fire_skill := $HUD/FireWings as Label
	fire_skill.position = Vector2(maxf(width - 270.0, 70.0), 188.0)
	fire_skill.size = Vector2(minf(250.0, width - fire_skill.position.x - 10.0), 28.0)
	fire_skill.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# Keep the meta readout in the gap between the centered banners and the
	# right-side sound/gauge column. Explicit gaps matter because the HUD
	# contract treats touching Control edges as overlap.
	var meta_width := 140.0
	var meta_x := width - 290.0
	$HUD/GoldStatus.position = Vector2(meta_x, 62.0)
	$HUD/GoldStatus.size = Vector2(meta_width, 20.0)
	$HUD/GoldCombo.position = Vector2(meta_x, 119.0)
	var run_counter_width := minf(240.0, width - 120.0)
	for counter: Label in [$HUD/Score, $HUD/RunCoins, $HUD/GoldCombo]:
		counter.position.x = width - run_counter_width - 12.0
		counter.size.x = run_counter_width
		counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	$HUD/Score.position.y = 8.0
	$HUD/Score.size.y = 40.0
	$HUD/RunCoins.position.y = 54.0
	$HUD/RunCoins.size.y = 28.0
	$HUD/GoldCombo.position.y = 92.0
	$HUD/GoldCombo.size.y = 26.0
	$HUD/GoldCombo.pivot_offset = $HUD/GoldCombo.size * Vector2(1.0, 0.5)
	_layout_run_coin_icon()
	$HUD/XPStatus.position = Vector2(meta_x, 85.0)
	$HUD/XPStatus.size = Vector2(meta_width, 18.0)
	$HUD/XPBar.position = Vector2(meta_x, 106.0)
	$HUD/XPBar.size = Vector2(meta_width, 9.0)
	_layout_death_panel(Vector2(width, height))
	$HUD/DoubleStageReward.position = Vector2((width - 230.0) * 0.5, 188.0)
	$HUD/DoubleStageReward.size = Vector2(230.0, 52.0)
	var commerce_buttons: Array[Button] = []
	if platform_services.is_rewarded_supported():
		commerce_buttons.append($HUD/GetMoreGold)
	if platform_services.is_payments_supported() and not platform_services.remove_ads_owned:
		commerce_buttons.append($HUD/RemoveAds)
	var commerce_width := minf(240.0, (width - 42.0) / maxf(float(commerce_buttons.size()), 1.0))
	var commerce_total := commerce_width * commerce_buttons.size() + 10.0 * maxi(commerce_buttons.size() - 1, 0)
	var commerce_x := (width - commerce_total) * 0.5
	for index in commerce_buttons.size():
		commerce_buttons[index].position = Vector2(commerce_x + index * (commerce_width + 10.0), menu_action_y)
		commerce_buttons[index].size = Vector2(commerce_width, 48.0)
	var menu_width := minf(220.0, width * 0.34)
	var menu_gap := 8.0
	var menu_button_height := 44.0 if compact else 48.0
	var primary_y := prompt.position.y + prompt.size.y + 8.0
	$HUD/Resume.position = Vector2((width - menu_width) * 0.5, primary_y)
	$HUD/Resume.size = Vector2(menu_width, menu_button_height)
	if resume_available:
		primary_y += menu_button_height + menu_gap
	var primary_buttons: Array[Button] = [$HUD/NewRun, $HUD/Shop, $HUD/Map]
	if bool(save_manager.replay_snapshot().nightmare_unlocked):
		primary_buttons.append($HUD/Nightmare)
	menu_width = minf(menu_width, (width - 32.0 - menu_gap * (primary_buttons.size() - 1)) / primary_buttons.size())
	var menu_row_width := menu_width * primary_buttons.size() + menu_gap * (primary_buttons.size() - 1)
	var menu_x := (width - menu_row_width) * 0.5
	for index in primary_buttons.size():
		var menu_button: Button = primary_buttons[index]
		menu_button.position = Vector2(menu_x + index * (menu_width + menu_gap), primary_y)
		menu_button.size = Vector2(menu_width, 44.0 if compact else 48.0)
	var secondary_width := minf(220.0, (width - 32.0 - menu_gap) / 2.0)
	var secondary_total := secondary_width * 2.0 + menu_gap
	var secondary_x := (width - secondary_total) * 0.5
	for index in 2:
		var secondary_button: Button = [$HUD/HowToPlay, $HUD/Credits][index]
		secondary_button.position = Vector2(secondary_x + index * (secondary_width + menu_gap), $HUD/NewRun.position.y + $HUD/NewRun.size.y + 8.0)
		secondary_button.size = Vector2(secondary_width, 44.0 if compact else 48.0)
	if daily_card != null:
		daily_card.position = Vector2(12.0 if compact else 16.0, 10.0 if compact else 54.0)
		daily_card.size = Vector2(minf(190.0 if compact else 220.0, width * 0.27), 108.0 if compact else 112.0)
	_layout_centered_label($HUD/InfoTitle, width, 36.0, 52.0, 24.0)
	_layout_centered_label($HUD/InfoBody, width, 92.0, maxf(height - 190.0, 130.0), 64.0)
	$HUD/InfoBack.position = Vector2((width - 220.0) * 0.5, height - 76.0)
	$HUD/InfoBack.size = Vector2(220.0, 52.0)
	var tutorial_width := minf(640.0, width - 48.0)
	$HUD/TutorialPanel.position = Vector2((width - tutorial_width) * 0.5, 12.0)
	$HUD/TutorialPanel.size = Vector2(tutorial_width, 88.0)
	$HUD/TutorialSkip.position = Vector2((width - 190.0) * 0.5, 120.0)
	$HUD/TutorialSkip.size = Vector2(190.0, 40.0)
	_layout_centered_label($HUD/RewardToast, width, 154.0, 30.0, 190.0)
	# Stage completion can show this together with the 188..240 double-reward
	# button. Keep the level reward in its own readable row below that action.
	_layout_centered_label($HUD/LevelUpCard, width, 248.0, 42.0, 190.0)
	_layout_centered_label($HUD/StageBanner, width, 124.0 if portrait else 86.0, 30.0, 82.0 if portrait else 300.0)
	$HUD/StageCounter.position = Vector2(8.0 if portrait else 14.0, 172.0 if portrait else 58.0)
	$HUD/StageCounter.size = Vector2(112.0, 22.0)
	_layout_centered_label($HUD/Tutorial, width, 158.0 if portrait else 122.0, 36.0, 82.0 if portrait else 300.0)
	var map_height := minf(360.0, height - (370.0 if portrait else 112.0))
	$HUD/MiniMap.position = Vector2(16.0 if portrait else 22.0, 205.0 if portrait else 86.0)
	$HUD/MiniMap.size = Vector2(42.0 if portrait else 48.0, maxf(map_height, 80.0))
	$HUD/Gauge.position = Vector2(width - 44.0 if portrait else width - 54.0, 205.0 if portrait else 86.0)
	$HUD/Gauge.size = Vector2(28.0, maxf(map_height, 80.0))
	_layout_centered_label($HUD/Pause, width, height * 0.38, 42.0, 40.0)
	var pause_width := minf(230.0, width - 32.0)
	$HUD/PauseMenu.size = Vector2(pause_width, 52.0)
	$HUD/PauseMenu.position = Vector2((width - pause_width) * 0.5, $HUD/Pause.position.y + $HUD/Pause.size.y + 16.0)
	var result_margin := 18.0 if compact else 32.0
	var result_top := 12.0 if compact else 20.0
	var result_bottom := height - (70.0 if compact else 88.0)
	$HUD/ResultPanel.position = Vector2(result_margin, result_top)
	$HUD/ResultPanel.size = Vector2(width - result_margin * 2.0, result_bottom - result_top)
	_layout_centered_label($HUD/Complete, width, 24.0 if compact else 34.0, 32.0 if compact else 40.0, result_margin + 12.0)
	_layout_intro_text(Vector2(width, height))
	var content_x := result_margin + 18.0
	var content_top := 68.0 if compact else 88.0
	var content_gap := 24.0 if compact else 28.0
	var column_width := (width - content_x * 2.0 - content_gap) * 0.5
	$HUD/Stats.position = Vector2(content_x, content_top)
	$HUD/Stats.size = Vector2(column_width, result_bottom - content_top - 18.0)
	$HUD/Replay.position = Vector2(content_x + column_width + content_gap, content_top)
	$HUD/Replay.size = Vector2(column_width, 24.0)
	var badge_step := 30.0 if compact else 44.0
	for index in result_badges.size():
		result_badges[index].position = Vector2(content_x + column_width + content_gap, content_top + 28.0 + index * badge_step)
		result_badges[index].size = Vector2(column_width, 24.0 if compact else 32.0)
	var complete_width := minf(190.0, (width - 48.0) / 3.0)
	var complete_start := (width - complete_width * 3.0 - 12.0) * 0.5
	var complete_y := height - (60.0 if compact else 68.0)
	$HUD/CompleteNewRun.position = Vector2(complete_start, complete_y)
	$HUD/CompleteNewRun.size = Vector2(complete_width, 48.0 if compact else 52.0)
	$HUD/CompleteNightmare.position = Vector2(complete_start + complete_width + 6.0, complete_y)
	$HUD/CompleteNightmare.size = Vector2(complete_width, 48.0 if compact else 52.0)
	$HUD/CompleteMenu.position = Vector2(complete_start + (complete_width + 6.0) * 2.0, complete_y)
	$HUD/CompleteMenu.size = Vector2(complete_width, 48.0 if compact else 52.0)
	var touch_y := height - 148.0
	$HUD/TouchLeft.position = Vector2(18.0, touch_y)
	$HUD/TouchLeft.size = Vector2(104.0, 128.0)
	$HUD/TouchRight.position = Vector2(132.0, touch_y)
	$HUD/TouchRight.size = Vector2(104.0, 128.0)
	$HUD/TouchWings.position = Vector2(width - 292.0, touch_y)
	$HUD/TouchWings.size = Vector2(maxf(132.0, Balance.TOUCH_BUTTON_MIN_PX), maxf(128.0, Balance.TOUCH_BUTTON_MIN_PX))
	$HUD/TouchFire.position = Vector2(width - 150.0, touch_y)
	$HUD/TouchFire.size = Vector2(132.0, 128.0)
	$HUD/MetaShop.set_offsets_preset(Control.PRESET_FULL_RECT)

func _layout_death_panel(viewport_size: Vector2) -> void:
	var width := viewport_size.x
	var height := viewport_size.y
	$HUD/DeathBackdrop.position = Vector2.ZERO
	$HUD/DeathBackdrop.size = viewport_size
	var is_result := death_phase == "result"
	_layout_centered_label($HUD/Dead, width, 22.0 if is_result else height * 0.27, 42.0 if is_result else 80.0, 14.0)
	$HUD/Dead.add_theme_font_size_override("font_size", 26 if width < 400.0 else 32)
	$HUD/Dead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_layout_centered_label($HUD/RunBest, width, 68.0, 26.0, 12.0)
	_layout_centered_label($HUD/RunCoinsResult, width, 100.0, 28.0, 12.0)
	_layout_centered_label($HUD/LeaderboardTitle, width, 136.0, 32.0, 12.0)
	_layout_centered_label($HUD/LeaderboardSource, width, 168.0, 20.0, 12.0)
	var row_width := minf(560.0, width - 28.0)
	var row_height := minf(25.0, (height - 270.0) / 10.0)
	for index in leaderboard_rows.size():
		leaderboard_rows[index].position = Vector2((width - row_width) * 0.5, 192.0 + index * row_height)
		leaderboard_rows[index].size = Vector2(row_width, row_height - 1.0)
	var continue_width := minf(230.0, (width - 38.0) * 0.5)
	for index in 2:
		var button: Button = [$HUD/ContinueAd, $HUD/NoThanks][index]
		button.position = Vector2((width - continue_width * 2.0 - 10.0) * 0.5 + index * (continue_width + 10.0), height * 0.52)
		button.size = Vector2(continue_width, 52.0)
		button.add_theme_font_size_override("font_size", 16 if width < 400.0 else 20)
	var action_width := minf(220.0, (width - 44.0) / 3.0)
	for index in 3:
		var button: Button = [$HUD/RestartRun, $HUD/DeathShop, $HUD/DeathMenu][index]
		button.position = Vector2((width - action_width * 3.0 - 16.0) * 0.5 + index * (action_width + 8.0), height - 66.0)
		button.size = Vector2(action_width, 48.0)
		button.add_theme_font_size_override("font_size", 14 if width < 400.0 else 20)
	_layout_centered_label($HUD/MenuBest, width, $HUD/Menu.position.y - 24.0, 20.0, 12.0)

func _layout_centered_label(label: Label, width: float, y: float, height: float, side_margin: float) -> void:
	label.position = Vector2(side_margin, y)
	label.size = Vector2(maxf(width - side_margin * 2.0, 1.0), height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _layout_intro_text(viewport_size: Vector2) -> void:
	var guardian_beat := intro_active and intro_beat == 2
	var panel_y := 12.0 if guardian_beat else viewport_size.y * 0.34
	var panel_height := 96.0 if guardian_beat else 110.0
	_layout_centered_label($HUD/IntroText, viewport_size.x, panel_y, panel_height, 72.0)
	if guardian_beat:
		_layout_intro_guardian(viewport_size)

func _layout_intro_guardian(viewport_size: Vector2) -> void:
	var body := spider.get_node("Body") as Node2D
	var guardian := body.get("sprite") as Sprite2D
	if guardian == null or guardian.texture == null:
		return
	# Frame the real player sprite directly below the wrapped text panel.
	# Only the intro camera moves; _finish_intro restores the normal run view.
	var panel := $HUD/IntroText as Label
	var camera := player.get_node("Camera2D") as Camera2D
	var player_sprite := (player.get_node("Body") as PlayerVisual).sprite
	camera.force_update_scroll()
	var player_bounds := player_sprite.get_global_transform_with_canvas() * player_sprite.get_rect()
	var player_top := panel.get_global_rect().end.y + 16.0
	var canvas := get_viewport().get_canvas_transform()
	camera.global_position += canvas.affine_inverse().basis_xform(Vector2(0.0, player_bounds.position.y - player_top))
	camera.force_update_scroll()
	player_bounds = player_sprite.get_global_transform_with_canvas() * player_sprite.get_rect()
	var top := player_bounds.end.y + 24.0
	var available := Vector2(maxf(viewport_size.x - 32.0, 1.0), maxf(viewport_size.y - top - 16.0, 1.0))
	canvas = get_viewport().get_canvas_transform()
	var local_bounds: Rect2 = guardian.transform * guardian.get_rect().grow(16.0)
	var bounds: Rect2 = Transform2D(canvas.x, canvas.y, Vector2.ZERO) * local_bounds
	var fit := minf(INTRO_GUARDIAN_SCALE.x, minf(available.x / bounds.size.x, available.y / bounds.size.y))
	body.scale = Vector2.ONE * fit
	body.position = Vector2.ZERO
	var center := Vector2(viewport_size.x * 0.5, top + available.y * 0.5)
	spider.global_position = canvas.affine_inverse() * center - local_bounds.get_center() * fit

func fly_gold_to_counter(screen_transform: Transform2D, arrived: Callable) -> void:
	var collected_value := economy.value("gold_per_collectible") * mini(golds.combo, 5)
	var collected_generation := run_generation
	var layer := $HUD/GoldFlights as Node2D
	var coin := Sprite2D.new()
	coin.texture = GoldCollectible.COIN_TEXTURE
	var local_transform := layer.get_global_transform_with_canvas().affine_inverse() * screen_transform
	var start_scale := local_transform.get_scale()
	coin.scale = start_scale
	layer.add_child(coin)
	var start := local_transform.origin
	coin.position = start
	var flight := create_tween()
	flight.tween_method(func(progress: float):
		var target: Vector2 = layer.get_global_transform_with_canvas().affine_inverse() * ($HUD/RunCoins/Icon.get_global_transform_with_canvas() * ($HUD/RunCoins/Icon.size * 0.5))
		var eased := progress * progress
		coin.position = start.lerp(target, eased) + Vector2(0.0, -80.0 * sin(PI * progress))
		coin.scale = start_scale * lerpf(1.0, 0.6, progress)
	, 0.0, 1.0, 0.45)
	flight.tween_callback(func():
		coin.queue_free()
		if collected_generation == run_generation:
			run_coins += collected_value
		arrived.call()
	)

func bump_gold_counter() -> void:
	var label := $HUD/RunCoins as Label
	label.text = _format_run_number(run_coins)
	_layout_run_coin_icon()
	label.pivot_offset = label.size * Vector2(1.0, 0.5)
	if gold_counter_tween != null:
		gold_counter_tween.kill()
	label.scale = Vector2.ONE
	gold_counter_tween = create_tween()
	gold_counter_tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.06)
	gold_counter_tween.tween_property(label, "scale", Vector2.ONE, 0.12)

func _layout_run_coin_icon() -> void:
	var label := $HUD/RunCoins as Label
	$HUD/RunCoins/Icon.position = Vector2(label.size.x - label.get_minimum_size().x - 28.0, 3.0)

func show_gold_combo(multiplier: int) -> void:
	var label := $HUD/GoldCombo as Label
	if gold_combo_tween != null:
		gold_combo_tween.kill()
	gold_combo_tween = create_tween()
	if multiplier < 2:
		gold_combo_tween.tween_property(label, "modulate:a", 0.0, 0.3)
		return
	label.text = "X%d" % multiplier
	label.modulate.a = 1.0
	label.pivot_offset = label.size * Vector2(1.0, 0.5)
	label.scale = Vector2.ONE
	gold_combo_tween.tween_property(label, "scale", Vector2.ONE * 1.3, 0.06)
	gold_combo_tween.tween_property(label, "scale", Vector2.ONE, 0.12)

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
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("47705eff")
	focus.border_color = Palette.ACCENT_PROGRESS_LIGHT
	focus.set_border_width_all(4)
	theme.set_stylebox("focus", "Button", focus)
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
	var button := SpeakerButton.new()
	button.name = "Mute"
	button.theme = ui_theme
	button.custom_minimum_size = Vector2(56, 56)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.gui_input.connect(func(event: InputEvent):
		if event is InputEventScreenTouch:
			button.accept_event()
			if event.pressed:
				_toggle_sound_setting())
	button.pressed.connect(_toggle_sound_setting)
	$HUD.add_child(button)

func _add_touch_button(name: String, rect: Rect2, text: String, action: String) -> void:
	var button := Button.new()
	button.name = name
	button.theme = ui_theme
	button.position = rect.position
	button.size = Vector2(maxf(rect.size.x, Balance.TOUCH_BUTTON_MIN_PX), maxf(rect.size.y, Balance.TOUCH_BUTTON_MIN_PX))
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = DisplayServer.is_touchscreen_available()
	$HUD.add_child(button)
	button.button_down.connect(_on_touch_action_down.bind(action))
	button.button_up.connect(_on_touch_action_up.bind(action))
	button.pressed.connect(_request_confirm)

func _on_touch_action_down(action: String) -> void:
	if action in ["time_wings", "fire_wings"]:
		dispatch_command(action, "mobile")
	else:
		Input.action_press(action)
		player.request_branch_direction(-1 if action == "move_left" else 1)

func _on_touch_action_up(action: String) -> void:
	if action not in ["time_wings", "fire_wings"]:
		Input.action_release(action)

func _clear_direction_inputs() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	touch_actions.clear()

func _update_lives_hud() -> void:
	var lives := $HUD/Lives as Control
	for index in lives.get_child_count():
		var heart := lives.get_child(index) as HeartIcon
		var is_filled := index < current_lives
		heart.set_filled(is_filled)
		if displayed_lives >= 0 and current_lives < displayed_lives and index >= current_lives and index < displayed_lives:
			heart.animate_loss()
	displayed_lives = current_lives

func _update_hud() -> void:
	var playing := app_state == AppState.PLAYING
	var normal_playing := playing and not tutorial_active
	danger_vignette.visible = normal_playing and danger_vignette_alpha > 0.0
	danger_vignette.modulate.a = danger_vignette_alpha
	var result_visible := app_state == AppState.GAME_COMPLETE
	var meta_visible := normal_playing or result_visible
	$HUD/Menu.visible = app_state == AppState.MENU
	$HUD/Pause.visible = app_state == AppState.PAUSED
	$HUD/Dead.visible = app_state == AppState.PLAYER_DEAD
	$HUD/Dead.text = ("NEW HIGH SCORE!" if result_new_best else "SCORE %s" % _format_run_number(int(score))) if death_phase == "result" else _death_text()
	$HUD/Dead.modulate = Color("ffd45c") if death_phase == "result" and result_new_best else Color.WHITE
	$HUD/ResultPanel.visible = result_visible
	$HUD/Complete.visible = result_visible
	$HUD/Stats.visible = result_visible
	$HUD/Replay.visible = result_visible
	for badge in result_badges:
		badge.visible = result_visible
	$HUD/CompleteNewRun.visible = result_visible
	$HUD/CompleteNightmare.visible = result_visible and bool(save_manager.replay_snapshot().nightmare_unlocked)
	$HUD/CompleteMenu.visible = result_visible
	player.visible = not result_visible
	spider.visible = not result_visible
	$HUD/MenuLogo.visible = app_state == AppState.MENU
	$HUD/Resume.visible = app_state == AppState.MENU and resume_available
	$HUD/NewRun.visible = app_state == AppState.MENU
	$HUD/Nightmare.visible = app_state == AppState.MENU and bool(save_manager.replay_snapshot().nightmare_unlocked)
	$HUD/Shop.visible = app_state == AppState.MENU
	$HUD/Map.visible = app_state == AppState.MENU
	$HUD/HowToPlay.visible = app_state == AppState.MENU
	$HUD/Credits.visible = app_state == AppState.MENU
	daily_card.visible = app_state == AppState.MENU
	var credits_visible := app_state == AppState.CREDITS
	$HUD/InfoTitle.visible = credits_visible
	$HUD/InfoTitle.text = "CREDITS"
	$HUD/InfoBody.visible = credits_visible
	$HUD/InfoBody.text = "BEANSTALK ESCAPE\nMade with Godot\n\nArt: Kenney (CC0), Codex image_gen project assets, manager-provided logo (origin review pending)\nMusic: MintoDog and TAD (CC0)\nAudio: Kenney (CC0), Sonniss GDC 2026 (commercial use; raw redistribution prohibited)\nFont: Lilita One (SIL OFL 1.1)\nFull attributions: CREDITS.md"
	if menu_help_open:
		$HUD/InfoTitle.text = "HOW TO PLAY"
		$HUD/InfoBody.text = "A / D or LEFT / RIGHT: switch branches\nTouch the left / right side to move\n\nClimb as high as you can. The vine gets faster.\nAvoid falling beans, rocks and broken branches.\nCollect gold along the way.\n\nF / TIME: Time Wings (unlocks during the climb)\nH / FIRE: Fire Wings (unlocks during the climb)\n\nESC: pause / resume"
	$HUD/InfoBack.visible = credits_visible
	$HUD/TutorialPanel.visible = tutorial_active
	$HUD/TutorialSkip.visible = tutorial_active
	$HUD/Mute.visible = playing
	$HUD/IntroText.visible = app_state in [AppState.INTRO, AppState.FINAL_CINEMATIC]
	$HUD/Gauge.visible = normal_playing
	$HUD/MiniMap.visible = false
	$HUD/StageBanner.visible = false
	$HUD/StageCounter.visible = false
	$HUD/Score.visible = normal_playing
	$HUD/RunCoins.visible = normal_playing
	$HUD/GoldCombo.visible = normal_playing
	$HUD/Score.text = _format_run_number(int(score))
	$HUD/RunCoins.text = _format_run_number(run_coins)
	_layout_run_coin_icon()
	$HUD/Tutorial.visible = normal_playing
	$HUD/TimeWings.visible = normal_playing
	$HUD/TimeWingsOrb.visible = normal_playing
	$HUD/TimeWingsBar.visible = normal_playing and time_wings_remaining > 0.0
	$HUD/TimeWingsNotice.visible = playing and time_wings_notice_remaining > 0.0
	$HUD/FireWings.visible = normal_playing
	$HUD/Lives.visible = normal_playing
	var balance_visible := result_visible or app_state in [AppState.MENU, AppState.SHOP]
	$HUD/GoldStatus.visible = balance_visible
	$HUD/XPStatus.visible = balance_visible
	$HUD/XPBar.visible = balance_visible
	$HUD/RewardToast.visible = false
	$HUD/LevelUpCard.visible = meta_visible and level_up_remaining > 0.0
	var death_visible := app_state == AppState.PLAYER_DEAD and not tutorial_active
	var continue_visible := death_visible and death_phase == "continue"
	var run_result_visible := death_visible and death_phase == "result"
	var board_visible := run_result_visible and leaderboard_visible
	$HUD/DeathBackdrop.visible = death_visible
	$HUD/ContinueAd.visible = continue_visible
	$HUD/NoThanks.visible = continue_visible
	$HUD/RunBest.visible = run_result_visible
	$HUD/RunBest.text = "BEST %s" % _format_run_number(result_best)
	$HUD/RunCoinsResult.visible = run_result_visible
	$HUD/RunCoinsResult.text = "+%s COINS" % _format_run_number(run_coins)
	$HUD/LeaderboardTitle.visible = board_visible
	$HUD/LeaderboardSource.visible = board_visible
	$HUD/LeaderboardSource.text = "THIS DEVICE" if leaderboard_source == "local" else ("CONNECTING…" if leaderboard_source.is_empty() else "ONLINE")
	for index in leaderboard_rows.size():
		leaderboard_rows[index].visible = board_visible and index < leaderboard_entries.size()
	$HUD/MenuBest.visible = app_state == AppState.MENU
	$HUD/MenuBest.text = "BEST %s" % _format_run_number(int(save_manager.profile.get("best_score", 0)))
	$HUD/RetryStage.visible = false
	$HUD/RestartRun.visible = board_visible
	$HUD/DeathShop.visible = board_visible
	$HUD/DeathMenu.visible = board_visible
	$HUD/PauseMenu.visible = app_state == AppState.PAUSED
	$HUD/SkipStageAd.visible = false
	$HUD/DoubleStageReward.visible = false
	$HUD/DoubleStageReward.text = "DOUBLE +%d (AD)" % last_stage_gold_reward
	$HUD/GetMoreGold.visible = app_state == AppState.MENU and platform_services.is_rewarded_supported()
	$HUD/GetMoreGold.text = "GET %d GOLD (AD)" % economy.value("get_more_gold_reward")
	$HUD/RemoveAds.visible = app_state == AppState.MENU and platform_services.is_payments_supported() and not platform_services.remove_ads_owned
	$HUD/TouchLeft.visible = normal_playing and DisplayServer.is_touchscreen_available()
	$HUD/TouchRight.visible = normal_playing and DisplayServer.is_touchscreen_available()
	$HUD/TouchWings.visible = normal_playing and DisplayServer.is_touchscreen_available()
	$HUD/TouchFire.visible = normal_playing and DisplayServer.is_touchscreen_available()
	_refresh_sound_icon()
	$HUD/StageBanner.text = stages.stage_banner if stages.stage_banner_remaining > 0.0 and app_state == AppState.PLAYING else ""
	$HUD/StageCounter.text = "STAGE %d / 30" % stages.stage_for_y(player.global_position.y)
	var route_hint_visible := tutorial_text != "CHANGE BRANCH" or stages.branch_targets_visible(player.global_position.y, get_viewport_rect().size.y)
	$HUD/Tutorial.text = tutorial_text if tutorial_remaining > 0.0 and app_state == AppState.PLAYING and route_hint_visible else ""
	$HUD/TimeWings.text = _time_wings_status()
	$HUD/TimeWingsNotice.text = time_wings_notice
	$HUD/TimeWingsBar.max_value = Balance.TIME_WINGS_SECONDS
	$HUD/TimeWingsBar.value = time_wings_remaining
	$HUD/FireWings.text = _fire_wings_status()
	_update_lives_hud()
	var meta := economy.snapshot()
	$HUD/GoldStatus.text = "GOLD %d" % meta.gold
	$HUD/XPStatus.text = "LV %d · XP %d/%d" % [meta.level, meta.xp, meta.xp_threshold]
	$HUD/XPBar.max_value = meta.xp_threshold
	$HUD/XPBar.value = meta.xp
	_update_time_wings_orb()
	if result_visible:
		$HUD/Stats.text = _stats_text()
		$HUD/Complete.text = "%s COMPLETE" % mode
		$HUD/Replay.text = "CHALLENGES"
		var challenge_state := _challenge_snapshot()
		for index in result_badges.size():
			var challenge_name: String = SaveManager.CHALLENGE_NAMES[index]
			var badge_state: Dictionary = challenge_state.get(challenge_name, {})
			var earned := bool(badge_state.get("earned", false))
			result_badges[index].text = "EARNED  ·  %s" % challenge_name if earned else "NOT EARNED  ·  %s" % challenge_name
			result_badges[index].add_theme_color_override("font_color", Color("7ee787") if earned else Color("9aa7b2"))
	else:
		$HUD/Stats.text = ""
		$HUD/Replay.text = ""
	if Engine.get_physics_frames() % 6 == 0:
		$HUD/MiniMap.queue_redraw()
	if ghost_sprite != null and not playing:
		ghost_sprite.visible = false

func _format_run_number(value: int) -> String:
	var digits := str(value)
	var result := ""
	for index in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result

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
		return "F · LOCKED"
	if time_wings_remaining > 0.0:
		return "F · ACTIVE %.1fs" % time_wings_remaining
	if time_wings_used_stage.has(stage_number):
		return "F · RECHARGING"
	return "F · READY"

func _fire_wings_status() -> String:
	var stage_number := stages.stage_for_y(player.global_position.y)
	if stage_number < Balance.FIRE_WINGS_STAGE and debug_sandbox != "rocks":
		return "H · FIRE WINGS LOCKED"
	if fire_wings_remaining > 0.0:
		return "H · FIRE WINGS ACTIVE %.1fs" % fire_wings_remaining
	if fire_wings_used_stage.has(stage_number):
		return "H · FIRE WINGS USED"
	return "H · FIRE WINGS READY"

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
	var deaths := 0
	for count in death_count_by_stage.values(): deaths += int(count)
	var record: Dictionary = save_manager.replay_snapshot().records.get(mode, {})
	var personal_best := float(record.get("best_time", 0.0))
	var best_text := "--:--" if personal_best <= 0.0 else "%02d:%02d" % [int(personal_best) / 60, int(personal_best) % 60]
	return "TIME %02d:%02d\nDEATHS / RETRIES %d / %d\nBEAN / ROCK HITS %d / %d\nCLOSE CALLS %d\nSKILLS USED %d\nBEST SPIDER DISTANCE %.1fm\nPERSONAL BEST %s" % [mm, ss, deaths, stage_restart_count, beans.hit_count, rocks.hit_count, close_calls, skills_used, best_m, best_text]

func _replay_badges_text() -> String:
	var lines: PackedStringArray = []
	for challenge in SaveManager.CHALLENGE_NAMES:
		var state: Dictionary = _challenge_snapshot().get(challenge, {})
		lines.append("[x] %s" % challenge if bool(state.get("earned", false)) else "[ ] %s" % challenge)
	return "\n".join(lines)

func _publish_readonly_web_state() -> void:
	if not OS.has_feature("web") or not _debug_state_enabled():
		return
	var now := Time.get_ticks_msec()
	if now - last_web_state_publish_msec < WEB_STATE_INTERVAL_MSEC:
		return
	last_web_state_publish_msec = now
	JavaScriptBridge.eval("window.beanstalkState = %s;" % JSON.stringify(_readonly_state_snapshot()), true)

func _debug_state_enabled() -> bool:
	if OS.has_feature("web"):
		return "debug" in str(JavaScriptBridge.eval("window.location.hash", true)).to_lower()
	return OS.is_debug_build()

func _challenge_snapshot() -> Dictionary:
	var saved: Dictionary = save_manager.replay_snapshot().challenges
	var common := mode == MODE_NORMAL and challenge_eligible
	return {
		"NO BEAN HIT": {"eligible": common and beans.hit_count == 0, "earned": bool(saved.get("NO BEAN HIT", false))},
		"NO ROCK HIT": {"eligible": common and rocks.hit_count == 0, "earned": bool(saved.get("NO ROCK HIT", false))},
		"NO DAMAGE": {"eligible": common and damage_events == 0, "earned": bool(saved.get("NO DAMAGE", false))},
		"UNDER 12 MINUTES": {"eligible": common and total_time < 720.0, "earned": bool(saved.get("UNDER 12 MINUTES", false))},
		"NO SKILLS": {"eligible": common and skills_used == 0, "earned": bool(saved.get("NO SKILLS", false))},
		"ZERO SPIDER RED ZONE": {"eligible": common and not spider_red_zone_seen, "earned": bool(saved.get("ZERO SPIDER RED ZONE", false))},
	}

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
	var pet_state := {"id": "", "visible": false, "x": player.global_position.x, "y": player.global_position.y}
	if pet_follower != null:
		pet_state = pet_follower.snapshot()
	var state_beans := []
	for bean in get_tree().get_nodes_in_group("beans"):
		if bean.active:
			state_beans.append({
				"route": bean.blocked_route,
				"phase": "falling" if bean.falling else "warning",
				"y": bean.global_position.y,
				"warning_visible_seconds": bean.warning_visible_seconds,
			})
	var state_gold := []
	for placement: Dictionary in golds.placements_by_stage.get(stage_number, []):
		var position: Vector2 = placement.position
		var route := int(placement.route)
		state_gold.append({
			"id": String(placement.id),
			"x": position.x,
			"visual_x": position.x + ScaleLock.vine_visual_offset(route, position.y) if stage_number >= 3 else position.x,
			"y": position.y,
			"route": route,
			"collected": golds.collected_ids.has(String(placement.id)),
		})
	return {
		"app_state": AppState.keys()[app_state],
		"run_time": total_time,
		"score": int(score),
		"run_coins": run_coins,
		"run_xp": economy.run_xp,
		"economy_level": economy.level,
		"best_score": int(save_manager.profile.get("best_score", 0)),
		"death_phase": death_phase,
		"result_new_best": result_new_best,
		"leaderboard_visible": leaderboard_visible,
		"leaderboard_entries": leaderboard_entries.duplicate(true),
		"leaderboard_source": leaderboard_source,
		"hud_stage_counter_visible": $HUD/StageCounter.visible,
		"hud_score_text": $HUD/Score.text,
		"speed_scale": player.speed_scale,
		"climb_speed": player.climb_speed(),
		"difficulty_tier": Balance.difficulty_tier_for_time(total_time),
		"difficulty_name": Balance.tier_name(Balance.difficulty_tier_for_time(total_time)),
		"chunk_template": stages.template_for_stage(stage_number),
		"chunk_tier": stages.tier_for_stage(stage_number),
		"resume_available": resume_available,
		"mode": mode,
		"nightmare_unlocked": bool(save_manager.replay_snapshot().nightmare_unlocked),
		"challenges": _challenge_snapshot(),
		"intro": {"active": intro_active, "beat": intro_beat, "t": intro_t, "visual_mode": INTRO_VISUAL_MODES[intro_beat] if intro_active else "none"},
		"tutorial": {"active": tutorial_active, "step": tutorial_step, "completed": bool(save_manager.meta_systems_snapshot().tutorial_completed)},
		"ghost": {"enabled": bool(meta_settings.ghost), "visible": ghost_sprite != null and ghost_sprite.visible, "stage_best_time": ghost_best_time},
		"final": {"active": app_state == AppState.FINAL_CINEMATIC, "t": final_t, "duration": FINAL_CINEMATIC_SECONDS},
		"death_cause": DeathCause.keys()[death_cause],
		"danger_remaining": danger_remaining,
		"lives": {"current": current_lives, "max": max_lives, "invulnerable_remaining": hit_invulnerability_remaining},
		"revive_panel": app_state == AppState.PLAYER_DEAD and current_lives <= 0,
		"fake_ad": platform_services.fake_ad_snapshot(),
		"stage": stages.stage_for_y(player.global_position.y),
		"player": {"x": player.global_position.x, "y": player.global_position.y, "vy": player.velocity.y},
		"player_visual": player_visual,
		"pet": pet_state,
		"spider": {"x": spider.global_position.x, "target_x": spider.target_x, "y": spider.global_position.y, "distance": gauge.distance_px, "ratio": spider.speed_ratio, "boost": spider.boost_remaining > 0.0, "boost_remaining": spider.boost_remaining, "catchup_active": spider.catchup_active, "catchup_blend": spider.catchup_blend, "on_screen": spider_visibility.on_screen, "visible_px": spider_visibility.visible_px},
		"gauge_level": gauge.level,
		"time_wings": {"unlocked": stages.stage_for_y(player.global_position.y) >= Balance.TIME_WINGS_STAGE, "active": time_wings_remaining > 0.0, "remaining": time_wings_remaining, "started_remaining": time_wings_started_remaining, "used": time_wings_used_stage.has(stages.stage_for_y(player.global_position.y)), "notice": time_wings_notice, "slow_scale": Balance.TIME_WINGS_SLOW_SCALE},
		"fire_wings": {"unlocked": stages.stage_for_y(player.global_position.y) >= Balance.FIRE_WINGS_STAGE or debug_sandbox == "rocks", "active": fire_wings_remaining > 0.0, "remaining": fire_wings_remaining, "started_remaining": fire_wings_started_remaining, "used": fire_wings_used_stage.has(stages.stage_for_y(player.global_position.y))},
		"rocks": rocks.snapshot(),
		"audio_events": audio.audio_event_snapshot(),
		"gold_fx": golds.feedback_state(),
		"gold": state_gold,
		"tempo": {"stage_seconds": Balance.STAGE_DURATION_SECONDS, "events_in_stage": stages.pattern_for_stage(stage_number).encounters.size()},
		"fx": {"shake": shake_remaining, "close_text": close_text_remaining},
		"beans": state_beans,
		"storm": storm.snapshot(),
		"next_dead_end": {"route": dead_end_route, "distance_px": null if is_inf(dead_end_distance) else dead_end_distance},
		"open_routes_at_player": stages.open_routes_at(player.global_position.y),
		"active_branch": player.active_branch,
		"support_state": player.support_state_name(),
		"transition_state": player.transition_state_name(),
		"branch_target": player.transition_to,
		"branch_transition_count": player.branch_transition_count,
		"on_support": player.on_support,
		"stats": {"time": total_time, "bean_hits": beans.hit_count, "rock_hits": rocks.hit_count, "close_calls": close_calls, "skills_used": skills_used, "best_distance": best_spider_distance},
		"restart": {"count": stage_restart_count, "start_distance": stage_restart_start_distance},
		"shop": economy.shop_snapshot(),
		"daily": economy.daily_snapshot(),
		"map": {
			"completed": economy.progression_snapshot().completed_stages,
			"skipped": economy.progression_snapshot().skipped_stages,
			"treasures_claimed": economy.progression_snapshot().treasures_claimed,
		},
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
		if parts.size() != 2:
			continue
		if parts[0] == "unlock" and parts[1].to_lower() == "nightmare":
			save_manager.unlock_nightmare()
			continue
		if parts[0] == "sandbox":
			var requested_sandbox := parts[1].to_lower()
			debug_sandbox = requested_sandbox if requested_sandbox in ["rocks", "storm"] else ""
			if not debug_sandbox.is_empty():
				debug_start_stage = 3
			continue
		if parts[0] == "tutorial" and parts[1] == "1":
			tutorial_force = true
			continue
		if parts[0] == "pet":
			var requested_pet := parts[1]
			for item in economy.cosmetic_catalog("PET"):
				if str(item.get("id", "")) == requested_pet:
					economy.shop.equipped["PET"] = requested_pet
					break
			continue
		if not parts[1].is_valid_int():
			continue
		if parts[0] == "gold": economy.gold = maxi(int(parts[1]), 0)
		if parts[0] == "level": economy.level = maxi(int(parts[1]), 1)
		if parts[0] == "stage": debug_start_stage = clampi(int(parts[1]), 1, Balance.STAGE_COUNT)

func _sync_pet(_snapshot := {}) -> void:
	if pet_follower == null:
		return
	var equipped_id := str(economy.shop_snapshot().equipped.get("PET", ""))
	var equipped_pet := {}
	for item in economy.cosmetic_catalog("PET"):
		if str(item.get("id", "")) == equipped_id:
			equipped_pet = item
			break
	pet_follower.set_pet(equipped_pet)

func _start_debug_stage(stage_number: int) -> void:
	if stage_number <= 1 or stage_number > Balance.STAGE_COUNT:
		return
	var start_y := stages.stage_bottom_y(stage_number)
	player.reset_run(Vector2(0.0, start_y))
	climb_previous_y = player.global_position.y
	spider.reset_run(Vector2(0.0, start_y + _spider_start_gap(stage_number)))
	_begin_danger(true)
	rocks.sync_after_player_teleport()
	golds.refresh_active_window(true)
	stages.update_progress(start_y)
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)

func _ensure_actions() -> void:
	_add_key_action("time_wings", [KEY_F])
	_add_key_action("fire_wings", [KEY_H])
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
