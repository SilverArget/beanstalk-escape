class_name SaveManager
extends RefCounted

signal profile_loaded(profile: Dictionary)

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://profile_v1.json"
const CHALLENGE_NAMES := [
	"NO BEAN HIT",
	"NO ROCK HIT",
	"NO DAMAGE",
	"UNDER 12 MINUTES",
	"NO SKILLS",
	"ZERO SPIDER RED ZONE",
]

var save_path: String
var profile: Dictionary = {}
var platform_service: Node
var bridge_loaded := false
var pending_bridge_write := false

func _init(path := DEFAULT_PATH) -> void:
	save_path = _qa_path() if path == DEFAULT_PATH and _is_qa_process() else path

func configure_platform(service: Node) -> void:
	platform_service = service
	if platform_service != null and OS.has_feature("web"):
		platform_service.storage_get(_on_bridge_profile_loaded)

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
	profile = _sanitize_profile(parsed as Dictionary)
	return profile.duplicate(true)

func replay_snapshot() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return profile.get("replay", _default_replay()).duplicate(true)

func unlock_nightmare() -> bool:
	if profile.is_empty():
		load_profile()
	var replay: Dictionary = _sanitize_replay(profile.get("replay", {}))
	replay["nightmare_unlocked"] = true
	profile["replay"] = replay
	return _write_profile()

func record_completion(mode: String, active_time: float, earned: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	var normalized_mode := "NIGHTMARE" if mode.to_upper() == "NIGHTMARE" else "NORMAL"
	var replay: Dictionary = _sanitize_replay(profile.get("replay", {}))
	var records: Dictionary = replay.records.duplicate(true)
	var record: Dictionary = records[normalized_mode].duplicate(true)
	record["completions"] = int(record.completions) + 1
	var previous_best := float(record.best_time)
	if active_time > 0.0 and (previous_best <= 0.0 or active_time < previous_best):
		record["best_time"] = active_time
	records[normalized_mode] = record
	replay["records"] = records
	if normalized_mode == "NORMAL":
		replay["nightmare_unlocked"] = true
		var badges: Dictionary = replay.challenges.duplicate(true)
		for challenge in CHALLENGE_NAMES:
			if bool(earned.get(challenge, false)):
				badges[challenge] = true
		replay["challenges"] = badges
	profile["replay"] = replay
	return _write_profile()

func write_meta(meta: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	profile["version"] = SAVE_VERSION
	profile["meta"] = {
		"gold": maxi(int(meta.get("gold", 0)), 0),
		"xp": maxi(int(meta.get("xp", 0)), 0),
		"level": maxi(int(meta.get("level", 1)), 1),
	}
	return _write_profile()

func add_gold(amount: int) -> bool:
	if profile.is_empty():
		load_profile()
	var meta: Dictionary = profile.get("meta", {}).duplicate(true)
	meta["gold"] = maxi(int(meta.get("gold", 0)) + amount, 0)
	profile["meta"] = meta
	return _write_profile()

func mark_stage_skipped(stage_number: int) -> bool:
	if profile.is_empty():
		load_profile()
	var progression: Dictionary = profile.get("progression", {}).duplicate(true)
	var skipped: Array = progression.get("skipped_stages", []).duplicate()
	if not skipped.has(stage_number):
		skipped.append(stage_number)
	progression["skipped_stages"] = skipped
	profile["progression"] = progression
	return _write_profile()

func set_remove_ads(value: bool) -> bool:
	if profile.is_empty():
		load_profile()
	var purchases: Dictionary = profile.get("purchases", {}).duplicate(true)
	purchases["remove_ads"] = value
	profile["purchases"] = purchases
	return _write_profile()

func write_shop(shop: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	profile["shop"] = _sanitize_shop(shop)
	return _write_profile()

func shop_snapshot() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return profile.get("shop", _default_shop()).duplicate(true)

func _write_profile() -> bool:
	if OS.has_feature("web") and platform_service != null:
		if bridge_loaded:
			platform_service.storage_set(profile.duplicate(true))
		else:
			pending_bridge_write = true
		return true
	var directory := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	return true

func _default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"meta": {"gold": 0, "xp": 0, "level": 1},
		"progression": {"skipped_stages": []},
		"purchases": {"remove_ads": false},
		"shop": _default_shop(),
		"replay": _default_replay(),
	}

func _default_replay() -> Dictionary:
	var challenges := {}
	for challenge in CHALLENGE_NAMES:
		challenges[challenge] = false
	return {
		"nightmare_unlocked": false,
		"challenges": challenges,
		"records": {
			"NORMAL": {"best_time": 0.0, "completions": 0},
			"NIGHTMARE": {"best_time": 0.0, "completions": 0},
		},
	}

func _default_shop() -> Dictionary:
	return {
		"owned": ["M1", "F1"],
		"equipped": {"HAIR": "", "FACE": "", "TRAIL": "", "OUTFIT": ""},
		"selected_character": "M1",
	}

func _sanitize_shop(value: Variant) -> Dictionary:
	var result := _default_shop()
	if value is not Dictionary:
		return result
	var source := value as Dictionary
	var owned_value: Variant = source.get("owned", [])
	if owned_value is Array:
		for item in owned_value:
			var item_id := str(item).to_upper() if str(item).length() == 2 else str(item)
			if not result.owned.has(item_id):
				result.owned.append(item_id)
	var equipped_value: Variant = source.get("equipped", {})
	if equipped_value is Dictionary:
		# HAT was retired in M3. Old ownership remains harmless in `owned`, while
		# an equipped HAT is deliberately ignored during profile migration.
		for slot in ["HAIR", "FACE", "TRAIL", "OUTFIT"]:
			result.equipped[slot] = str(equipped_value.get(slot, ""))
	var selected := str(source.get("selected_character", "M1")).to_upper()
	result.selected_character = selected if result.owned.has(selected) else "M1"
	return result

func _on_bridge_profile_loaded(success: bool, value: Variant) -> void:
	bridge_loaded = true
	if success and value is Dictionary:
		profile = _sanitize_profile(value)
		profile_loaded.emit(profile.duplicate(true))
	if pending_bridge_write:
		pending_bridge_write = false
		platform_service.storage_set(profile.duplicate(true))

func _sanitize_profile(value: Dictionary) -> Dictionary:
	var result := _default_profile()
	var meta: Dictionary = value.get("meta", {}) if value.get("meta", {}) is Dictionary else {}
	result.meta.gold = maxi(int(meta.get("gold", 0)), 0)
	result.meta.xp = maxi(int(meta.get("xp", 0)), 0)
	result.meta.level = maxi(int(meta.get("level", 1)), 1)
	if value.get("progression", {}) is Dictionary:
		result.progression = value.progression.duplicate(true)
	if value.get("purchases", {}) is Dictionary:
		result.purchases = value.purchases.duplicate(true)
	result.shop = _sanitize_shop(value.get("shop", {}))
	result.replay = _sanitize_replay(value.get("replay", {}))
	return result

func _sanitize_replay(value: Variant) -> Dictionary:
	var result := _default_replay()
	if value is not Dictionary:
		return result
	var source := value as Dictionary
	result.nightmare_unlocked = bool(source.get("nightmare_unlocked", false))
	var source_challenges: Variant = source.get("challenges", {})
	if source_challenges is Dictionary:
		for challenge in CHALLENGE_NAMES:
			result.challenges[challenge] = bool(source_challenges.get(challenge, false))
	var source_records: Variant = source.get("records", {})
	if source_records is Dictionary:
		for mode in ["NORMAL", "NIGHTMARE"]:
			var source_record: Variant = source_records.get(mode, {})
			if source_record is Dictionary:
				result.records[mode] = {
					"best_time": maxf(float(source_record.get("best_time", 0.0)), 0.0),
					"completions": maxi(int(source_record.get("completions", 0)), 0),
				}
	return result

func _is_qa_process() -> bool:
	for argument in OS.get_cmdline_args():
		if "test_" in argument or "capture_" in argument or argument == "--qa-save":
			return true
	return OS.has_environment("BEANSTALK_QA_SAVE")

func _qa_path() -> String:
	return "user://qa/profile_v1.json"
