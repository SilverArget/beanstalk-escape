class_name SpiderDistanceGauge
extends Control

var distance_px := 0.0
var normalized_danger := 0.0
var level := "GREEN"

func update_from_positions(player_y: float, spider_y: float) -> void:
	distance_px = maxf(spider_y - player_y, 0.0)
	normalized_danger = clampf(1.0 - distance_px / Balance.GAUGE_MAX_DISTANCE, 0.0, 1.0)
	level = level_for(normalized_danger)
	queue_redraw()

func level_for(value: float) -> String:
	for name: String in Balance.GAUGE_THRESHOLDS:
		if value <= Balance.GAUGE_THRESHOLDS[name]:
			return name
	return "DANGER"

func _draw() -> void:
	var colors := {"GREEN": Color("55d66b"), "YELLOW": Color("e8d650"), "ORANGE": Color("ed9b3a"), "RED": Color("d84949"), "DANGER": Color("8d1830")}
	draw_rect(Rect2(0, 0, 28, 220), Color("21322b"), true)
	var height := normalized_danger * 212.0
	draw_rect(Rect2(4, 216.0 - height, 20, height), colors[level], true)

