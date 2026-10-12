extends Control

var game: GameManager
const GRADIENT_BANDS := 16
var redraw_count := 0
var redraw_elapsed := 0.0

func _process(delta: float) -> void:
	redraw_elapsed += delta
	if redraw_elapsed >= 0.05:
		redraw_elapsed = fmod(redraw_elapsed, 0.05)
		queue_redraw()

func _draw() -> void:
	redraw_count += 1
	if game == null or game.app_state != GameManager.AppState.PLAYING:
		return
	var amount := clampf((game.gauge.normalized_danger - 0.45) / 0.55, 0.0, 1.0)
	amount = maxf(amount, clampf(game.danger_pulse_remaining / 0.22, 0.0, 1.0))
	if amount <= 0.0:
		return
	var edge := 24.0 + amount * 34.0
	var band := edge / float(GRADIENT_BANDS)
	for index in GRADIENT_BANDS:
		var distance := float(index) * band
		var color := Palette.DANGER_SPIDER
		color.a = overlay_alpha_at_distance(distance, edge, amount)
		draw_rect(Rect2(0, distance, size.x, band + 0.5), color, true)
		draw_rect(Rect2(0, size.y - distance - band, size.x, band + 0.5), color, true)
		draw_rect(Rect2(distance, 0, band + 0.5, size.y), color, true)
		draw_rect(Rect2(size.x - distance - band, 0, band + 0.5, size.y), color, true)

func overlay_alpha_at_distance(distance: float, edge: float, amount: float) -> float:
	var normalized := clampf(1.0 - distance / maxf(edge, 0.001), 0.0, 1.0)
	return amount * 0.34 * normalized * normalized
