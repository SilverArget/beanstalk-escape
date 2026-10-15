extends SceneTree

const OutfitEffectScript := preload("res://scripts/outfit_effect.gd")
const FairyEffectScript := preload("res://scripts/fairy_effect.gd")
var failures := 0

func _init() -> void:
	var outfit_effect := OutfitEffectScript.new()
	outfit_effect.configure({"effect_name": "SPARK ARCS"})
	var outfit_game_profile: Dictionary = outfit_effect.render_profile()
	_check(outfit_game_profile.particle_count == 7 and outfit_game_profile.max_draw_calls <= 40, "game outfit effects stay inside the seven-particle and 40-call budgets")
	_check(outfit_game_profile.polygon_draw_calls == 0 and outfit_game_profile.redraw_interval_frames == 2 and outfit_game_profile.redraw_phase == 1, "game outfit textures avoid polygon triangulation and redraw on odd frames")
	outfit_effect.set_preview_mode(true)
	var outfit_preview_profile: Dictionary = outfit_effect.render_profile()
	_check(outfit_preview_profile.particle_count == 10 and outfit_preview_profile.layers_per_particle == 4, "outfit preview preserves the legacy ten-particle four-layer density")
	_check(outfit_preview_profile.redraw_interval_frames == 1, "outfit preview redraws every frame")
	outfit_effect.free()

	var fairy_effect := FairyEffectScript.new()
	fairy_effect.configure({"effect_name": "STAR BURST"})
	var fairy_game_profile: Dictionary = fairy_effect.render_profile()
	_check(fairy_game_profile.polygon_draw_calls == 0 and fairy_game_profile.redraw_interval_frames == 2 and fairy_game_profile.redraw_phase == 0, "game fairy textures avoid polygon triangulation and redraw on even frames")
	fairy_effect.set_preview_mode(true)
	_check(fairy_effect.render_profile().redraw_interval_frames == 1, "fairy preview redraws every frame")
	fairy_effect.free()

	print("test_cosmetic_render_budget.gd: %d FAIL" % failures)
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % label)
