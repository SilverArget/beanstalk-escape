extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ProjectSettings.get_setting("autoload/Bridge", "").contains("playgama_bridge/bridge.gd"), "Bridge is an autoload")
	_check(ProjectSettings.get_setting("autoload/PlatformServices", "").contains("platform_services.gd"), "platform adapter is an autoload")
	var export_text := FileAccess.get_file_as_string("res://export_presets.cfg")
	_check(export_text.contains('html/custom_html_shell="res://addons/playgama_bridge/template/index.html"'), "web export uses Bridge shell")
	var plugin := ConfigFile.new()
	_check(plugin.load("res://addons/playgama_bridge/plugin.cfg") == OK and plugin.get_value("plugin", "version") == "2.3.0", "official Bridge v2.3.0 installed")
	var bridge_config: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://addons/playgama_bridge/template/playgama-bridge-config.json"))
	var placements: Array = bridge_config.advertisement.rewarded.placements
	_check(placements.size() == 5 and bridge_config.payments[0].id == "remove_ads", "five rewarded placements and remove_ads configured")

	var isolated_save := SaveManager.new()
	_check(isolated_save.save_path == "user://qa/profile_v1.json", "test process uses isolated save path")
	var economy := EconomyManager.new()
	_check(economy.initialize(isolated_save), "M2 economy config loads")
	var before_gold := economy.gold
	var platform_services := root.get_node_or_null("PlatformServices")
	_check(platform_services != null, "platform adapter starts before the game")
	platform_services.show_rewarded("get_more_gold", func(): economy.grant_gold(economy.value("get_more_gold_reward")))
	_check(economy.gold == before_gold + 100, "debug rewarded callback grants configured gold")

	var game := load("res://scenes/main.tscn").instantiate() as GameManager
	root.add_child(game)
	await process_frame
	game.start_game()
	var death_position := game.player.global_position
	game._die(GameManager.DeathCause.CAUGHT)
	await process_frame
	var buttons := [game.get_node("HUD/ContinueAd"), game.get_node("HUD/RetryStage"), game.get_node("HUD/RestartRun"), game.get_node("HUD/DeathMenu")]
	_check(buttons.all(func(button): return button.visible and button.size.y >= 48.0), "death screen has four touch-sized actions")
	game._continue_with_ad()
	_check(game.app_state == GameManager.AppState.PLAYING and game.player.global_position == death_position and game.continue_used_this_run, "rewarded continue resumes at the same point once")
	_check(game.spider.global_position.y - game.player.global_position.y >= SpiderController.retry_gap_for_stage(game.stages.current_stage), "continue restores safe spider gap")

	game.queue_free()
	await process_frame
	print("META_M2_TEST passed=%d failed=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
