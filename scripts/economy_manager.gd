class_name EconomyManager
extends RefCounted

signal changed(snapshot: Dictionary)
signal level_up(level: int, gold_reward: int)

const CONFIG_PATH := "res://config/economy.json"
const REQUIRED_KEYS := [
	"stage_gold_count_min", "stage_gold_count_max",
	"gold_per_collectible",
	"stage_completion_gold_base", "stage_completion_gold_per_stage",
	"xp_per_stage", "xp_per_gold", "level_threshold_base",
	"level_threshold_per_level", "level_up_gold", "get_more_gold_reward",
	"skip_stage_death_count", "interstitial_min_stage",
	"interstitial_completed_stage_interval", "interstitial_min_delay_seconds",
]

var config: Dictionary = {}
var save_manager: SaveManager
var gold := 0
var xp := 0
var level := 1

func initialize(manager: SaveManager) -> bool:
	save_manager = manager
	if not _load_local_config():
		return false
	_try_playgama_remote_config()
	var profile := save_manager.load_profile()
	var meta: Dictionary = profile.meta
	gold = int(meta.gold)
	xp = int(meta.xp)
	level = int(meta.level)
	return true

func apply_remote_config(overrides: Dictionary) -> void:
	for key in REQUIRED_KEYS:
		if overrides.has(key) and (overrides[key] is int or overrides[key] is float):
			config[key] = maxi(int(overrides[key]), 0)
	_validate_config()

func stage_gold_count(stage_number: int) -> int:
	var minimum := value("stage_gold_count_min")
	var maximum := value("stage_gold_count_max")
	return minimum + posmod(stage_number * 2, maximum - minimum + 1)

func collect_gold() -> Dictionary:
	var reward := value("gold_per_collectible")
	gold += reward
	var levels := _add_xp(value("xp_per_gold"))
	_persist_and_emit()
	return {"gold": reward, "xp": value("xp_per_gold"), "level_ups": levels}

func complete_stage(stage_number: int) -> Dictionary:
	var reward := value("stage_completion_gold_base") + value("stage_completion_gold_per_stage") * stage_number
	gold += reward
	var levels := _add_xp(value("xp_per_stage"))
	_persist_and_emit()
	return {"gold": reward, "xp": value("xp_per_stage"), "level_ups": levels}

func grant_gold(amount: int) -> int:
	var reward := maxi(amount, 0)
	gold += reward
	_persist_and_emit()
	return reward

func reload_profile(profile: Dictionary) -> void:
	var meta: Dictionary = profile.get("meta", {})
	gold = maxi(int(meta.get("gold", gold)), 0)
	xp = maxi(int(meta.get("xp", xp)), 0)
	level = maxi(int(meta.get("level", level)), 1)
	changed.emit(snapshot())

func threshold_for(current_level := level) -> int:
	return value("level_threshold_base") + value("level_threshold_per_level") * (current_level - 1)

func snapshot() -> Dictionary:
	return {"gold": gold, "xp": xp, "level": level, "xp_threshold": threshold_for()}

func value(key: String) -> int:
	return int(config.get(key, 0))

func _add_xp(amount: int) -> int:
	xp += amount
	var levels := 0
	while xp >= threshold_for():
		xp -= threshold_for()
		level += 1
		levels += 1
		var reward := value("level_up_gold")
		gold += reward
		level_up.emit(level, reward)
	return levels

func _persist_and_emit() -> void:
	if save_manager != null:
		save_manager.write_meta(snapshot())
	changed.emit(snapshot())

func _load_local_config() -> bool:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return false
	config = (parsed as Dictionary).duplicate(true)
	return _validate_config()

func _validate_config() -> bool:
	for key in REQUIRED_KEYS:
		if not config.has(key) or not (config[key] is int or config[key] is float):
			return false
	config["stage_gold_count_min"] = maxi(int(config.stage_gold_count_min), 1)
	config["stage_gold_count_max"] = maxi(int(config.stage_gold_count_max), int(config.stage_gold_count_min))
	config["level_threshold_base"] = maxi(int(config.level_threshold_base), 1)
	return true

func _try_playgama_remote_config() -> void:
	if not OS.has_feature("web"):
		return
	var script := "(function(){const b=window.playgamaBridge||window.PlaygamaBridge;const r=b&&(b.remoteConfig||(b.platform&&b.platform.remoteConfig));const v=r&&(r.values||r);try{return v?JSON.stringify(v):'';}catch(e){return '';}})()"
	var json_text := str(JavaScriptBridge.eval(script, true))
	if json_text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed is Dictionary:
		apply_remote_config(parsed)
