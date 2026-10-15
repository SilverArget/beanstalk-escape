class_name SaveManager
extends RefCounted

signal profile_loaded(profile: Dictionary)

const SAVE_VERSION := 4
const DEFAULT_PATH := "user://profile_v1.json"
const LEGACY_PET_IDS := {
	"pet_squirrel": "fairy_leaf",
	"pet_ladybug": "fairy_flower",
	"pet_frog": "fairy_drop",
	"pet_bird": "fairy_firefly",
	"pet_snail": "fairy_cloud",
	"pet_rabbit": "fairy_star",
}
const RETIRED_HAIR_REFUNDS := {
	"hair_dark": 150,
	"hair_blonde": 400,
	"hair_silver": 900,
}
# Frozen prices from economy.json at retirement; each owned ID refunds once.
const RETIRED_EMBLEM_REFUNDS := {
	"emblem_leaf": 150,
	"emblem_star": 150,
	"emblem_sun": 400,
	"emblem_bolt": 400,
	"emblem_spider": 900,
	"emblem_crown": 900,
}
# Frozen prices from economy.json at retirement; each owned ID refunds once.
const RETIRED_TRAIL_REFUNDS := {
	"trail_leaf": 200,
	"trail_cloud": 500,
	"trail_star": 1000,
}
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
var bridge_write_in_flight := false
var bridge_write_dirty := false
var hair_refund_migrated := false
var emblem_refund_migrated := false
var trail_refund_migrated := false

func _init(path := DEFAULT_PATH) -> void:
	save_path = _qa_path() if path == DEFAULT_PATH and _is_qa_process() else path

func configure_platform(service: Node) -> void:
	platform_service = service
	if platform_service != null:
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
	hair_refund_migrated = false
	emblem_refund_migrated = false
	trail_refund_migrated = false
	profile = _sanitize_profile(parsed as Dictionary)
	if hair_refund_migrated or emblem_refund_migrated or trail_refund_migrated:
		_write_local_profile()
	return profile.duplicate(true)

func replay_snapshot() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return profile.get("replay", _default_replay()).duplicate(true)

func meta_systems_snapshot() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return _sanitize_meta_systems(profile.get("meta_systems", {}))

func write_settings(settings: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	var systems := _sanitize_meta_systems(profile.get("meta_systems", {}))
	systems["settings"] = _sanitize_settings(settings)
	profile["meta_systems"] = systems
	return _write_profile()

func mark_tutorial_completed() -> bool:
	if profile.is_empty():
		load_profile()
	var systems := _sanitize_meta_systems(profile.get("meta_systems", {}))
	systems["tutorial_completed"] = true
	profile["meta_systems"] = systems
	return _write_profile()

func record_stage_ghost(mode: String, stage_number: int, stage_time: float, samples: Array) -> bool:
	if profile.is_empty():
		load_profile()
	if stage_time <= 0.0 or samples.is_empty():
		return false
	var systems := _sanitize_meta_systems(profile.get("meta_systems", {}))
	var ghosts: Dictionary = systems.ghosts.duplicate(true)
	var normalized_mode := "NIGHTMARE" if mode.to_upper() == "NIGHTMARE" else "NORMAL"
	var mode_ghosts: Dictionary = ghosts.get(normalized_mode, {}).duplicate(true)
	var key := str(clampi(stage_number, 1, 30))
	var previous: Dictionary = mode_ghosts.get(key, {})
	if float(previous.get("time", 0.0)) > 0.0 and float(previous.time) <= stage_time:
		return false
	mode_ghosts[key] = {"time": stage_time, "samples": _sanitize_ghost_samples(samples)}
	ghosts[normalized_mode] = mode_ghosts
	systems["ghosts"] = ghosts
	profile["meta_systems"] = systems
	return _write_profile()

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
	profile["meta"] = _meta_for_write(meta)
	return _write_profile()

func write_meta_and_shop(meta: Dictionary, shop: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	profile["version"] = SAVE_VERSION
	profile["meta"] = _meta_for_write(meta)
	profile["shop"] = _sanitize_shop(shop)
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

func mark_stage_completed(stage_number: int) -> bool:
	if profile.is_empty():
		load_profile()
	var progression := _sanitize_progression(profile.get("progression", {}))
	if not progression.completed_stages.has(stage_number):
		progression.completed_stages.append(stage_number)
		progression.completed_stages.sort()
	profile["progression"] = progression
	return _write_profile()

func mark_treasure_claimed(stage_number: int) -> bool:
	if profile.is_empty():
		load_profile()
	var progression := _sanitize_progression(profile.get("progression", {}))
	if progression.treasures_claimed.has(stage_number):
		return false
	progression.treasures_claimed.append(stage_number)
	progression.treasures_claimed.sort()
	profile["progression"] = progression
	return _write_profile()

func progression_snapshot() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return _sanitize_progression(profile.get("progression", {}))

func write_daily(daily: Dictionary) -> bool:
	if profile.is_empty():
		load_profile()
	profile["daily"] = _sanitize_daily(daily)
	return _write_profile()

func daily_snapshot() -> Dictionary:
	if profile.is_empty():
		load_profile()
	return _sanitize_daily(profile.get("daily", {}))

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
	var meta: Dictionary = profile.get("meta", {}).duplicate(true)
	meta["save_seq"] = maxi(int(meta.get("save_seq", 0)), 0) + 1
	profile["meta"] = meta
	var local_write_ok := _write_local_profile()
	if platform_service != null:
		if bridge_loaded:
			_queue_bridge_write()
		else:
			pending_bridge_write = true
	return local_write_ok

func _queue_bridge_write() -> void:
	if bridge_write_in_flight:
		bridge_write_dirty = true
		return
	bridge_write_in_flight = true
	platform_service.storage_set(profile.duplicate(true), _on_bridge_write_completed)

func _on_bridge_write_completed(_success: bool) -> void:
	bridge_write_in_flight = false
	if bridge_write_dirty:
		bridge_write_dirty = false
		_queue_bridge_write()

func _meta_for_write(value: Dictionary) -> Dictionary:
	var current_meta: Dictionary = profile.get("meta", {})
	return {
		"gold": maxi(int(value.get("gold", 0)), 0),
		"xp": maxi(int(value.get("xp", 0)), 0),
		"level": maxi(int(value.get("level", 1)), 1),
		"hair_refund_done": bool(current_meta.get("hair_refund_done", true)),
		"emblem_refund_done": bool(current_meta.get("emblem_refund_done", true)),
		"trail_refund_done": bool(current_meta.get("trail_refund_done", true)),
		"save_seq": maxi(int(current_meta.get("save_seq", 0)), 0),
	}

func _write_local_profile() -> bool:
	var directory := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(directory):
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(profile, "\t"))
	file.flush()
	file.close()
	return true

func _default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"meta": {"gold": 0, "xp": 0, "level": 1, "hair_refund_done": true, "emblem_refund_done": true, "trail_refund_done": true, "save_seq": 0},
		"progression": {"completed_stages": [], "skipped_stages": [], "treasures_claimed": []},
		"daily": {"day_index": 0, "last_claim_date": ""},
		"purchases": {"remove_ads": false},
		"shop": _default_shop(),
		"replay": _default_replay(),
		"meta_systems": _default_meta_systems(),
	}

func _default_meta_systems() -> Dictionary:
	return {
		"tutorial_completed": false,
		"settings": {"sound": true, "ghost": true},
		"ghosts": {"NORMAL": {}, "NIGHTMARE": {}},
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
		"equipped": {"OUTFIT": "", "PET": ""},
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
			item_id = str(LEGACY_PET_IDS.get(item_id, item_id))
			if not item_id.begins_with("face_") and not RETIRED_HAIR_REFUNDS.has(item_id) and not item_id.begins_with("emblem_") and not item_id.begins_with("trail_") and not result.owned.has(item_id):
				result.owned.append(item_id)
	var equipped_value: Variant = source.get("equipped", {})
	if equipped_value is Dictionary:
		# Retired HAT/FACE/HAIR/EMBLEM/TRAIL equipment is deliberately ignored during migration.
		for slot in ["OUTFIT", "PET"]:
			var equipped_id := str(equipped_value.get(slot, ""))
			result.equipped[slot] = str(LEGACY_PET_IDS.get(equipped_id, equipped_id)) if slot == "PET" else equipped_id
	var selected := str(source.get("selected_character", "M1")).to_upper()
	result.selected_character = selected if result.owned.has(selected) else "M1"
	return result

func _sanitize_progression(value: Variant) -> Dictionary:
	var result := {"completed_stages": [], "skipped_stages": [], "treasures_claimed": []}
	if value is not Dictionary:
		return result
	for key in result:
		var source: Variant = value.get(key, [])
		if source is Array:
			for raw_stage in source:
				var stage := int(raw_stage)
				if stage >= 1 and stage <= 30 and not result[key].has(stage):
					result[key].append(stage)
			result[key].sort()
	return result

func _sanitize_daily(value: Variant) -> Dictionary:
	if value is not Dictionary:
		return {"day_index": 0, "last_claim_date": ""}
	return {
		"day_index": clampi(int(value.get("day_index", 0)), 0, 7),
		"last_claim_date": str(value.get("last_claim_date", "")),
	}

func _on_bridge_profile_loaded(success: bool, value: Variant) -> void:
	bridge_loaded = true
	if profile.is_empty():
		load_profile()
	if success and value is Dictionary:
		hair_refund_migrated = false
		emblem_refund_migrated = false
		trail_refund_migrated = false
		var bridge_profile := _sanitize_profile(value)
		var local_seq := int(profile.get("meta", {}).get("save_seq", 0))
		var bridge_seq := int(bridge_profile.get("meta", {}).get("save_seq", 0))
		if bridge_seq >= local_seq:
			pending_bridge_write = false
			profile = bridge_profile
			if hair_refund_migrated or emblem_refund_migrated or trail_refund_migrated:
				_write_profile()
			else:
				_write_local_profile()
			profile_loaded.emit(profile.duplicate(true))
		else:
			pending_bridge_write = true
	if pending_bridge_write:
		pending_bridge_write = false
		_queue_bridge_write()

func _sanitize_profile(value: Dictionary) -> Dictionary:
	var result := _default_profile()
	var meta: Dictionary = value.get("meta", {}) if value.get("meta", {}) is Dictionary else {}
	var refund_done := bool(meta.get("hair_refund_done", false))
	var refund_gold := 0
	if not refund_done:
		var source_shop: Variant = value.get("shop", {})
		var source_owned: Variant = source_shop.get("owned", []) if source_shop is Dictionary else []
		if source_owned is Array:
			for item_id in RETIRED_HAIR_REFUNDS:
				if source_owned.has(item_id):
					refund_gold += int(RETIRED_HAIR_REFUNDS[item_id])
		hair_refund_migrated = true
	if not bool(meta.get("emblem_refund_done", false)):
		var source_shop: Variant = value.get("shop", {})
		var source_owned: Variant = source_shop.get("owned", []) if source_shop is Dictionary else []
		if source_owned is Array:
			for item_id in RETIRED_EMBLEM_REFUNDS:
				if source_owned.has(item_id):
					refund_gold += int(RETIRED_EMBLEM_REFUNDS[item_id])
		emblem_refund_migrated = true
	if not bool(meta.get("trail_refund_done", false)):
		var source_shop: Variant = value.get("shop", {})
		var source_owned: Variant = source_shop.get("owned", []) if source_shop is Dictionary else []
		if source_owned is Array:
			for item_id in RETIRED_TRAIL_REFUNDS:
				if source_owned.has(item_id):
					refund_gold += int(RETIRED_TRAIL_REFUNDS[item_id])
		trail_refund_migrated = true
	result.meta.gold = maxi(int(meta.get("gold", 0)), 0) + refund_gold
	result.meta.xp = maxi(int(meta.get("xp", 0)), 0)
	result.meta.level = maxi(int(meta.get("level", 1)), 1)
	result.meta.hair_refund_done = true
	result.meta.emblem_refund_done = true
	result.meta.trail_refund_done = true
	result.meta.save_seq = maxi(int(meta.get("save_seq", 0)), 0)
	if value.get("progression", {}) is Dictionary:
		result.progression = _sanitize_progression(value.progression)
	result.daily = _sanitize_daily(value.get("daily", {}))
	if value.get("purchases", {}) is Dictionary:
		result.purchases = value.purchases.duplicate(true)
	result.shop = _sanitize_shop(value.get("shop", {}))
	result.replay = _sanitize_replay(value.get("replay", {}))
	result.meta_systems = _sanitize_meta_systems(value.get("meta_systems", {}))
	return result

func _sanitize_settings(value: Variant) -> Dictionary:
	var source: Dictionary = value if value is Dictionary else {}
	return {
		"sound": bool(source.get("sound", true)) and bool(source.get("music", true)),
		"ghost": true,
	}

func _sanitize_meta_systems(value: Variant) -> Dictionary:
	var result := _default_meta_systems()
	if value is not Dictionary:
		return result
	var source := value as Dictionary
	result.tutorial_completed = bool(source.get("tutorial_completed", false))
	result.settings = _sanitize_settings(source.get("settings", {}))
	var source_ghosts: Variant = source.get("ghosts", {})
	if source_ghosts is Dictionary:
		for mode in ["NORMAL", "NIGHTMARE"]:
			var mode_source: Variant = source_ghosts.get(mode, {})
			if mode_source is not Dictionary:
				continue
			for stage_key in mode_source:
				var stage_number := int(stage_key)
				var ghost: Variant = mode_source[stage_key]
				if stage_number < 1 or stage_number > 30 or ghost is not Dictionary:
					continue
				var samples := _sanitize_ghost_samples(ghost.get("samples", []))
				var stage_time := maxf(float(ghost.get("time", 0.0)), 0.0)
				if stage_time > 0.0 and not samples.is_empty():
					result.ghosts[mode][str(stage_number)] = {"time": stage_time, "samples": samples}
	return result

func _sanitize_ghost_samples(value: Variant) -> Array:
	var result: Array = []
	if value is not Array:
		return result
	for raw_sample in value:
		if raw_sample is not Dictionary or result.size() >= 2400:
			continue
		result.append({
			"t": maxf(float(raw_sample.get("t", 0.0)), 0.0),
			"x": float(raw_sample.get("x", 0.0)),
			"y": float(raw_sample.get("y", 0.0)),
			"branch": int(raw_sample.get("branch", 0)),
		})
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
