class_name SpiderDistanceGauge
extends Control

var distance_px := 0.0
var normalized_danger := 0.0
var level := "GREEN"

func update_from_positions(player_y: float, spider_y: float) -> void:
	distance_px = maxf(spider_y - player_y, 0.0)
	normalized_danger = clampf(1.0 - distance_px / Balance.GAUGE_MAX_DISTANCE, 0.0, 1.0)
	level = level_for_gap(distance_px)
	queue_redraw()

func level_for(value: float) -> String:
	for name: String in Balance.GAUGE_THRESHOLDS:
		if value <= Balance.GAUGE_THRESHOLDS[name]:
			return name
	return "DANGER"

static func level_for_gap(gap: float) -> String:
	if gap >= 240.0: return "GREEN"
	if gap >= 180.0: return "YELLOW"
	if gap >= 96.0: return "ORANGE"
	if gap >= 56.0: return "RED"
	return "DANGER"

func _draw() -> void:
	var colors := {"GREEN": Palette.GAUGE_GREEN, "YELLOW": Palette.GAUGE_YELLOW, "ORANGE": Palette.GAUGE_ORANGE, "RED": Palette.GAUGE_RED, "DANGER": Palette.DANGER_SPIDER}
	draw_rect(Rect2(0, 0, 28, 220), Palette.UI_PANEL, true)
	var height := normalized_danger * 212.0
	draw_rect(Rect2(4, 216.0 - height, 20, height), colors[level], true)
	draw_circle(Vector2(14, 232), 10.0, Palette.SPIDER_BODY)
	draw_circle(Vector2(10, 229), 2.5, Palette.DANGER_GLOW)
	draw_circle(Vector2(18, 229), 2.5, Palette.DANGER_GLOW)
