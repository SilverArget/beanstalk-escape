class_name BeanstalkAudio
extends Node

const STREAMS := {
	"music_game": preload("res://assets/audio/music_game.ogg"), "music_menu": preload("res://assets/audio/music_menu.ogg"),
	"wind_loop": preload("res://assets/audio/wind_loop.ogg"), "branch_swoosh": preload("res://assets/audio/branch_swoosh.ogg"),
	"bean_warning_creak": preload("res://assets/audio/bean_warning_creak.ogg"), "bean_fall_whoosh": preload("res://assets/audio/bean_fall_whoosh.ogg"),
	"bean_impact": preload("res://assets/audio/bean_impact.ogg"), "bean_impact_wood": preload("res://assets/audio/bean_impact_wood.ogg"),
	"spider_step_1": preload("res://assets/audio/spider_step_1.ogg"), "spider_step_2": preload("res://assets/audio/spider_step_2.ogg"),
	"spider_scream": preload("res://assets/audio/spider_scream.ogg"), "heartbeat_thump": preload("res://assets/audio/heartbeat_thump.ogg"),
	"time_wings": preload("res://assets/audio/time_wings.ogg"), "stage_complete": preload("res://assets/audio/stage_complete.ogg"),
	"game_complete": preload("res://assets/audio/game_complete.ogg"), "death_bass_down": preload("res://assets/audio/death_bass_down.ogg"),
	"ui_click": preload("res://assets/audio/ui_click.ogg"), "climb_rustle_1": preload("res://assets/audio/climb_rustle_1.ogg"),
	"climb_rustle_2": preload("res://assets/audio/climb_rustle_2.ogg"), "climb_rustle_3": preload("res://assets/audio/climb_rustle_3.ogg"),
}
const VOLUME_DB := {"music": -14.0, "ambience": -24.0, "sfx": -7.0, "heartbeat": -12.0}
const EVENT_RING_CAPACITY := 24

var music := AudioStreamPlayer.new()
var wind := AudioStreamPlayer.new()
var sfx := AudioStreamPlayer.new()
var heartbeat := AudioStreamPlayer.new()
var game_music_prewarm := AudioStreamPlayer.new()
var muted := false
var last_app_state := -1
var last_stage := 1
var last_transition_count := 0
var last_hit_count := 0
var tracked_beans := {}
var beat_cooldown := 0.0
var climb_cooldown := 0.0
var spider_cooldown := 0.0
var wings_was_active := false
var danger_was_active := false
var played_roles := {}
var audio_events: Array = []

func _ready() -> void:
	for player in [music, wind, sfx, heartbeat]:
		add_child(player)
	music.volume_db = VOLUME_DB.music
	wind.volume_db = VOLUME_DB.ambience
	sfx.volume_db = VOLUME_DB.sfx
	heartbeat.volume_db = VOLUME_DB.heartbeat
	STREAMS["music_game"].set_loop(true)
	STREAMS["music_menu"].set_loop(true)
	STREAMS["wind_loop"].set_loop(true)
	wind.stream = STREAMS.wind_loop
	wind.play()
	played_roles["wind_loop"] = true
	# Web decodes this larger OGG on first playback. Trigger that work while the
	# menu is loading so the first ENTER does not stall the gameplay transition.
	game_music_prewarm.stream = STREAMS.music_game
	game_music_prewarm.volume_db = -80.0
	add_child(game_music_prewarm)
	game_music_prewarm.play()
	call_deferred("_finish_game_music_prewarm")

func _finish_game_music_prewarm() -> void:
	game_music_prewarm.stop()
	game_music_prewarm.queue_free()

func _process(delta: float) -> void:
	var game := get_parent() as GameManager
	if game == null:
		return
	if game.app_state != last_app_state:
		_on_state_changed(game, last_app_state)
		last_app_state = game.app_state
	if game.player.branch_transition_count != last_transition_count:
		last_transition_count = game.player.branch_transition_count
		play_sfx("branch_swoosh")
	if game.beans.hit_count != last_hit_count:
		last_hit_count = game.beans.hit_count
		play_sfx("bean_impact")
		play_sfx("bean_impact_wood")
	if game.stages.current_stage != last_stage:
		last_stage = game.stages.current_stage
		play_sfx("stage_complete")
	_track_beans(game)
	_update_danger(game, delta)
	_update_movement_sounds(game, delta)
	if game.player.time_wings_active and not wings_was_active:
		play_sfx("time_wings")
	wings_was_active = game.player.time_wings_active

func _on_state_changed(game: GameManager, previous: int) -> void:
	if game.app_state == GameManager.AppState.MENU:
		play_music("music_menu")
	elif game.app_state == GameManager.AppState.PLAYING:
		if previous == GameManager.AppState.MENU:
			play_sfx("spider_scream")
		play_music("music_game")
	elif game.app_state == GameManager.AppState.PLAYER_DEAD:
		play_sfx("death_bass_down")
	elif game.app_state == GameManager.AppState.GAME_COMPLETE:
		play_sfx("game_complete")
		play_music("music_menu")
	_set_paused(game.app_state == GameManager.AppState.PAUSED)

func _track_beans(game: GameManager) -> void:
	for bean in game.get_tree().get_nodes_in_group("beans"):
		var id := bean.get_instance_id()
		var phase := 1 if bean.falling else 0
		if not tracked_beans.has(id):
			tracked_beans[id] = phase
			play_sfx("bean_warning_creak")
		elif tracked_beans[id] == 0 and phase == 1:
			tracked_beans[id] = phase
			play_sfx("bean_fall_whoosh")

func _update_danger(game: GameManager, delta: float) -> void:
	var danger := game.gauge.normalized_danger
	music.pitch_scale = lerpf(1.0, 1.15, clampf((danger - 0.45) / 0.55, 0.0, 1.0))
	wind.volume_db = VOLUME_DB.ambience + clampf(-game.player.global_position.y / 9000.0, 0.0, 5.0)
	beat_cooldown -= delta
	if danger > 0.56 and beat_cooldown <= 0.0:
		heartbeat.stream = STREAMS.heartbeat_thump
		heartbeat.play()
		beat_cooldown = lerpf(1.0, 0.42, danger)
	if danger > 0.78 and not danger_was_active:
		play_sfx("spider_scream")
	danger_was_active = danger > 0.72

func _update_movement_sounds(game: GameManager, delta: float) -> void:
	climb_cooldown -= delta
	spider_cooldown -= delta
	if game.app_state != GameManager.AppState.PLAYING:
		return
	if absf(game.player.velocity.y) > 1.0 and climb_cooldown <= 0.0:
		play_sfx("climb_rustle_%d" % (1 + int(Time.get_ticks_msec() / 431) % 3))
		climb_cooldown = 0.42
	if spider_cooldown <= 0.0:
		play_sfx("spider_step_%d" % (1 + int(Time.get_ticks_msec() / 733) % 2))
		spider_cooldown = lerpf(1.1, 0.45, game.gauge.normalized_danger)

func play_music(name: String) -> void:
	played_roles[name] = true
	_record_event(name)
	if music.stream == STREAMS[name] and music.playing:
		return
	music.stream = STREAMS[name]
	music.play()

func play_sfx(name: String) -> void:
	played_roles[name] = true
	_record_event(name)
	var one_shot := AudioStreamPlayer.new()
	one_shot.stream = STREAMS[name]
	one_shot.volume_db = VOLUME_DB.sfx
	add_child(one_shot)
	one_shot.finished.connect(one_shot.queue_free)
	one_shot.play()

func _record_event(event_name: String) -> void:
	var game := get_parent() as GameManager
	var event_time := game.total_time if game != null else 0.0
	audio_events.append({"event": event_name, "t": snappedf(event_time, 0.001)})
	while audio_events.size() > EVENT_RING_CAPACITY:
		audio_events.pop_front()

func audio_event_snapshot() -> Array:
	return audio_events.duplicate(true)

func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func _set_paused(value: bool) -> void:
	for player in [music, wind, sfx, heartbeat]:
		player.stream_paused = value
