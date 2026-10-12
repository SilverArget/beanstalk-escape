class_name SaveManager
extends RefCounted

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://profile_v1.json"

var save_path: String
var profile: Dictionary = {}

func _init(path := DEFAULT_PATH) -> void:
	save_path = path

func load_profile() -> Dictionary:
	profile = _default_profile()
	if not FileAccess.file_exists(save_path):
		return profile.duplicate(true)
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return profile.duplicate(true)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return profile.duplicate(true)
	profile = (parsed as Dictionary).duplicate(true)
	profile["version"] = SAVE_VERSION
	var meta_value: Variant = profile.get("meta", {})
	var meta: Dictionary = meta_value if meta_value is Dictionary else {}
	meta["gold"] = maxi(int(meta.get("gold", 0)), 0)
	meta["xp"] = maxi(int(meta.get("xp", 0)), 0)
	meta["level"] = maxi(int(meta.get("level", 1)), 1)
	profile["meta"] = meta
	return profile.duplicate(true)

func write_meta(meta: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	profile["version"] = SAVE_VERSION
	profile["meta"] = {
		"gold": maxi(int(meta.get("gold", 0)), 0),
		"xp": maxi(int(meta.get("xp", 0)), 0),
		"level": maxi(int(meta.get("level", 1)), 1),
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	return true

func _default_profile() -> Dictionary:
	return {"version": SAVE_VERSION, "meta": {"gold": 0, "xp": 0, "level": 1}}
