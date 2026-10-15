extends SceneTree

var passed := 0
var failed := 0

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String, detail: String) -> void:
	if condition:
		passed += 1
		print("PASS %s %s" % [label, detail])
	else:
		failed += 1
		print("FAIL %s %s" % [label, detail])

func _make_game() -> GameManager:
	var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as GameManager
	root.add_child(game)
	await process_frame
	return game

func _run() -> void:
	var skip_game := await _make_game()
	skip_game.economy.shop.selected_character = "F1"
	skip_game.get_node("HUD/NewRun").pressed.emit()
	_check(skip_game.app_state == GameManager.AppState.INTRO and not skip_game.meta_ui.visible and (skip_game.player.get_node("Body") as PlayerVisual).skin_id == "F1" and skip_game.mode == GameManager.MODE_NORMAL, "NEW-RUN-DIRECT", "selected=F1 character_select=false")
	var intro_started: bool = skip_game.app_state == GameManager.AppState.INTRO and skip_game.intro_active and skip_game._readonly_state_snapshot().intro.visual_mode == "climb"
	skip_game._finish_intro()
	var skip_snapshot := [skip_game.player.global_position, skip_game.spider.global_position, skip_game.beans.hit_count, skip_game.total_time]
	_check(intro_started and skip_game.app_state == GameManager.AppState.PLAYING and not skip_game.intro_active, "INTRO-SKIP", "state=%s gap=%.1f" % [GameManager.AppState.keys()[skip_game.app_state], skip_game.spider.distance_to_player()])
	skip_game.queue_free()
	await process_frame

	var complete_game := await _make_game()
	complete_game.start_game()
	complete_game._update_intro(float(GameManager.INTRO_BEAT_SECONDS[0]) + 0.01)
	var summit_visible: bool = complete_game.intro_beat == 1 and complete_game._readonly_state_snapshot().intro.visual_mode == "summit" and complete_game.get_node("HUD/IntroSummit").visible
	_check(summit_visible, "INTRO-SUMMIT", "mode=%s texture=%s" % [complete_game._readonly_state_snapshot().intro.visual_mode, str(complete_game.get_node("HUD/IntroSummit").texture != null)])
	complete_game._update_intro(float(GameManager.INTRO_BEAT_SECONDS[1]) + 0.01)
	complete_game._update_intro(0.10)
	var guardian_body := complete_game.spider.get_node("Body") as Node2D
	var guardian_visible: bool = complete_game.intro_beat == 2 and complete_game._readonly_state_snapshot().intro.visual_mode == "guardian" and guardian_body.visible and guardian_body.scale.x > 0.0 and guardian_body.scale.x <= GameManager.INTRO_GUARDIAN_SCALE.x
	_check(guardian_visible, "INTRO-GUARDIAN", "mode=%s scale=%.2f shake=%.2f" % [complete_game._readonly_state_snapshot().intro.visual_mode, guardian_body.scale.x, complete_game.player.get_node("Camera2D").offset.length()])
	var guardian_text := complete_game.get_node("HUD/IntroText") as Label
	var guardian_text_clear: bool = guardian_text.position.y <= 12.0 and guardian_text.position.y + guardian_text.size.y <= 120.0
	_check(guardian_text_clear, "INTRO-GUARDIAN-TEXT", "panel_y=%.1f panel_bottom=%.1f" % [guardian_text.position.y, guardian_text.position.y + guardian_text.size.y])
	root.content_scale_size = Vector2i.ZERO
	complete_game.save_manager.profile.replay.nightmare_unlocked = true
	for viewport_size in [Vector2i(960, 540), Vector2i(1586, 669), Vector2i(540, 960)]:
		root.size = viewport_size
		await process_frame
		complete_game.layout_hud_for_viewport(Vector2(viewport_size))
		complete_game._update_intro(0.01)
		var guardian := guardian_body.get("sprite") as Sprite2D
		var sprite_rect: Rect2 = guardian.get_global_transform_with_canvas() * guardian.get_rect()
		var text_rect := guardian_text.get_global_rect()
		_check(text_rect.end.y + 8.0 < sprite_rect.position.y and sprite_rect.end.y <= viewport_size.y and sprite_rect.position.x >= 0.0 and sprite_rect.end.x <= viewport_size.x, "GUARDIAN-SEPARATION", "%s text_bottom=%.1f sprite_top=%.1f" % [viewport_size, text_rect.end.y, sprite_rect.position.y])
		var logo := complete_game.get_node("HUD/MenuLogo") as TextureRect
		var prompt := complete_game.get_node("HUD/Menu") as Label
		_check(logo.get_global_rect().end.y + 16.0 <= prompt.get_global_rect().position.y and prompt.get_global_rect().end.y < complete_game.get_node("HUD/NewRun").position.y, "MENU-SEPARATION", "%s logo_bottom=%.1f prompt_top=%.1f" % [viewport_size, logo.get_global_rect().end.y, prompt.position.y])
	complete_game._update_intro(float(GameManager.INTRO_BEAT_SECONDS[2]) + 0.01)
	var complete_snapshot := [complete_game.player.global_position, complete_game.spider.global_position, complete_game.beans.hit_count, complete_game.total_time]
	_check(complete_game.app_state == GameManager.AppState.PLAYING and not complete_game.intro_active, "INTRO-COMPLETE", "state=%s duration=%.1f" % [GameManager.AppState.keys()[complete_game.app_state], 7.6])
	var presentation_reset: bool = not complete_game.get_node("HUD/IntroSummit").visible and guardian_body.scale == Vector2.ONE and complete_game.player.get_node("Camera2D").offset == Vector2.ZERO
	_check(skip_snapshot == complete_snapshot and complete_game.player.global_position == Vector2.ZERO and complete_game.spider.global_position == Vector2(0.0, Balance.START_DISTANCE) and presentation_reset, "INTRO-EQUIVALENCE", "skip_and_complete_start_equal=%s presentation_reset=%s" % [str(skip_snapshot == complete_snapshot), str(presentation_reset)])
	complete_game._finish_onboarding()
	complete_game.save_manager.profile.replay.nightmare_unlocked = true
	complete_game.economy.shop.selected_character = "F1"
	complete_game._show_menu()
	complete_game.get_node("HUD/Nightmare").pressed.emit()
	_check(complete_game.mode == GameManager.MODE_NIGHTMARE and complete_game.app_state == GameManager.AppState.INTRO and not complete_game.meta_ui.visible and (complete_game.player.get_node("Body") as PlayerVisual).skin_id == "F1", "NIGHTMARE-DIRECT", "selected=F1 character_select=false")
	complete_game.queue_free()
	await process_frame

	print("RESULT intro_smoke PASS=%d FAIL=%d" % [passed, failed])
	quit(0 if failed == 0 else 1)
