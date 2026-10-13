extends SceneTree

const NEW_STREAMS := [&"rock_rumble", &"vine_crack", &"vine_break"]
const OLD_FILES := [
	"branch_swoosh.ogg",
	"bean_warning_creak.ogg",
	"bean_impact_wood.ogg",
	"spider_step_1.ogg",
	"spider_step_2.ogg",
	"time_wings.ogg",
	"game_complete.ogg",
	"death_bass_down.ogg",
	"ui_click.ogg",
	"gold_pickup.ogg",
	"wind_loop.ogg",
]

var failures := 0

func check(ok: bool, id: String, detail: String) -> void:
	print(("PASS " if ok else "FAIL ") + id + " " + detail)
	if not ok:
		failures += 1

func _initialize() -> void:
	var all_loaded := true
	var old_paths: Array[String] = []
	for stream_name: StringName in BeanstalkAudio.STREAMS:
		var stream := BeanstalkAudio.STREAMS[stream_name] as AudioStream
		all_loaded = all_loaded and stream != null
		if stream != null:
			for old_file: String in OLD_FILES:
				if stream.resource_path.ends_with(old_file):
					old_paths.append(stream.resource_path)
	check(all_loaded, "AUDIO-LOAD", "streams=%d" % BeanstalkAudio.STREAMS.size())
	check(NEW_STREAMS.all(func(stream_name: StringName) -> bool: return BeanstalkAudio.STREAMS.has(stream_name)), "AUDIO-NEW-KEYS", "keys=%s" % [NEW_STREAMS])
	check(old_paths.is_empty(), "AUDIO-NO-OLD-PATHS", "old_paths=%s" % [old_paths])

	var audio := BeanstalkAudio.new()
	audio.sound_enabled = false
	audio.announce_storm_role("branch_crack")
	audio.announce_storm_role("branch_break")
	var event_names: Array[String] = []
	for event: Dictionary in audio.audio_event_snapshot():
		event_names.append(String(event.event))
	check(event_names.has("branch_crack") and event_names.has("vine_crack") and event_names.has("branch_break") and event_names.has("vine_break"), "AUDIO-STORM-ROLES", "events=%s" % [event_names])
	for player: AudioStreamPlayer in [audio.music, audio.wind, audio.sfx, audio.heartbeat, audio.game_music_prewarm]:
		player.free()
	audio.free()

	print("AUDIO_NATURAL_SET_RESULT failures=%d" % failures)
	quit(failures)
