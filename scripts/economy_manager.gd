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
var shop: Dictionary = {}

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
	shop = save_manager.shop_snapshot()
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

func daily_snapshot() -> Dictionary:
	var saved := save_manager.daily_snapshot()
	var today := Time.get_date_string_from_system(false)
	var claimed_today := str(saved.last_claim_date) == today
	return {
		"day_index": int(saved.day_index) if claimed_today else _next_daily_day(saved, today),
		"claimed_today": claimed_today,
	}

func claim_daily_bonus() -> Dictionary:
	var daily := daily_snapshot()
	if daily.claimed_today:
		return {}
	var day_index := int(daily.day_index)
	var result := {"day_index": day_index, "gold": 0, "item": ""}
	if day_index == 7:
		var item_id := str(config.get("daily_login_day_7_item", "outfit_sky"))
		_unlock_item(item_id)
		result.item = item_id
	else:
		var rewards: Array = config.get("daily_login_gold", [])
		if day_index < 1 or day_index > rewards.size():
			return {}
		result.gold = maxi(int(rewards[day_index - 1]), 0)
		gold += result.gold
	save_manager.write_daily({"day_index": day_index, "last_claim_date": Time.get_date_string_from_system(false)})
	_persist_shop()
	return result

func progression_snapshot() -> Dictionary:
	return save_manager.progression_snapshot()

func mark_stage_completed(stage_number: int) -> void:
	save_manager.mark_stage_completed(stage_number)
	changed.emit(snapshot())

func map_treasure(stage_number: int) -> Dictionary:
	for raw_reward in config.get("map_treasures", []):
		if raw_reward is Dictionary and int(raw_reward.get("stage", 0)) == stage_number:
			return (raw_reward as Dictionary).duplicate(true)
	return {}

func claim_map_treasure(stage_number: int) -> Dictionary:
	var progression := progression_snapshot()
	if not progression.completed_stages.has(stage_number) or progression.treasures_claimed.has(stage_number):
		return {}
	var reward := map_treasure(stage_number)
	if reward.is_empty() or not save_manager.mark_treasure_claimed(stage_number):
		return {}
	if str(reward.get("type", "")) == "item":
		_unlock_item(str(reward.get("item", "")))
	else:
		var amount := maxi(int(reward.get("amount", 0)), 0)
		gold += amount
		reward["amount"] = amount
	_persist_shop()
	return reward

func reload_profile(profile: Dictionary) -> void:
	var meta: Dictionary = profile.get("meta", {})
	gold = maxi(int(meta.get("gold", gold)), 0)
	xp = maxi(int(meta.get("xp", xp)), 0)
	level = maxi(int(meta.get("level", level)), 1)
	shop = save_manager.shop_snapshot()
	changed.emit(snapshot())

func character_catalog() -> Dictionary:
	return config.get("characters", {}).duplicate(true)

func cosmetic_catalog(slot := "") -> Array:
	var result: Array = []
	for raw_item in config.get("cosmetics", []):
		var item: Dictionary = raw_item.duplicate(true)
		if not slot.is_empty() and str(item.get("slot", "")) != slot:
			continue
		var rarity := str(item.get("rarity", "COMMON"))
		item["price"] = int(item.get("price", config.get("cosmetic_prices", {}).get(rarity, 0)))
		item["level"] = int(item.get("level", config.get("cosmetic_levels", {}).get(rarity, 1)))
		result.append(item)
	return result

func character_available(character_id: String) -> bool:
	var normalized := character_id.to_upper()
	var required_frame := "res://assets/art/character_frames/%s/hang.png" % normalized.to_lower()
	return config.get("characters", {}).has(normalized) and ResourceLoader.exists(required_frame)

func locked_reason(item_id: String) -> String:
	var item := _catalog_item(item_id)
	if item.is_empty():
		return "UNKNOWN"
	if item.get("kind", "") == "character" and not character_available(item_id):
		return "COMING"
	if not str(item.get("source", "")).is_empty():
		return str(item.source)
	if level < int(item.get("level", 1)):
		return "LV %d" % int(item.level)
	if shop.get("owned", []).has(item_id):
		return ""
	var missing := int(item.get("price", 0)) - gold
	return "NEED %d GOLD" % missing if missing > 0 else ""

func buy(item_id: String) -> bool:
	var item := _catalog_item(item_id)
	if item.is_empty() or shop.get("owned", []).has(item_id):
		return false
	if not locked_reason(item_id).is_empty():
		return false
	gold -= int(item.get("price", 0))
	shop.owned.append(item_id)
	_persist_shop()
	return true

func select_character(character_id: String) -> bool:
	var normalized := character_id.to_upper()
	if not shop.get("owned", []).has(normalized) or not character_available(normalized):
		return false
	shop.selected_character = normalized
	_persist_shop()
	return true

func equip(item_id: String) -> bool:
	var item := _catalog_item(item_id)
	if item.get("kind", "") != "cosmetic" or not shop.get("owned", []).has(item_id):
		return false
	var slot := str(item.get("slot", ""))
	shop.equipped[slot] = "" if str(shop.equipped.get(slot, "")) == item_id else item_id
	_persist_shop()
	return true

func shop_snapshot() -> Dictionary:
	var locked := {}
	for character_id in character_catalog():
		var reason := locked_reason(character_id)
		if not reason.is_empty(): locked[character_id] = reason
	for item in cosmetic_catalog():
		var reason := locked_reason(str(item.id))
		if not reason.is_empty(): locked[item.id] = reason
	return {"gold": gold, "level": level, "owned": shop.get("owned", []).duplicate(), "equipped": shop.get("equipped", {}).duplicate(true), "selected_character": shop.get("selected_character", "M1"), "locked_reasons": locked}

func _catalog_item(item_id: String) -> Dictionary:
	var normalized := item_id.to_upper()
	var characters: Dictionary = config.get("characters", {})
	if characters.has(normalized):
		var result: Dictionary = characters[normalized].duplicate(true)
		result["id"] = normalized
		result["kind"] = "character"
		return result
	for item in cosmetic_catalog():
		if str(item.get("id", "")) == item_id:
			var result: Dictionary = item.duplicate(true)
			result["kind"] = "cosmetic"
			return result
	return {}

func _persist_shop() -> void:
	if save_manager != null:
		save_manager.write_meta_and_shop(snapshot(), shop)
	changed.emit(snapshot())

func _unlock_item(item_id: String) -> void:
	if not item_id.is_empty() and not shop.get("owned", []).has(item_id):
		shop.owned.append(item_id)

func _next_daily_day(saved: Dictionary, today: String) -> int:
	var last_date := str(saved.get("last_claim_date", ""))
	if last_date.is_empty():
		return 1
	var last_unix := Time.get_unix_time_from_datetime_string(last_date + "T00:00:00")
	var today_unix := Time.get_unix_time_from_datetime_string(today + "T00:00:00")
	if int(today_unix - last_unix) != 86400:
		return 1
	return int(saved.get("day_index", 0)) % 7 + 1

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
	if config.daily_login_gold is not Array or config.daily_login_gold.size() != 6:
		return false
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
