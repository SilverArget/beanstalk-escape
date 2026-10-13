class_name FairyEffect
extends Node2D

var effect_name := ""
var elapsed := 0.0

func configure(item: Dictionary) -> void:
	effect_name = str(item.get("effect_name", ""))
	visible = not effect_name.is_empty()
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	match effect_name:
		"SOFT GLOW":
			var pulse := 0.78 + sin(elapsed * 3.0) * 0.12
			draw_circle(Vector2.ZERO, 25.0 * pulse, Color(0.55, 1.0, 0.52, 0.08))
			draw_circle(Vector2.ZERO, 17.0 * pulse, Color(0.72, 1.0, 0.58, 0.12))
		"LIGHT TRAIL":
			for index in 5:
				var trail_pos := Vector2(-12.0 - index * 8.0, sin(elapsed * 5.0 - index) * 4.0)
				draw_circle(trail_pos, 4.5 - index * 0.55, Color(1.0, 0.45, 0.72, 0.23 - index * 0.035))
		"SPARKLE DUST":
			for index in 6:
				var phase := fmod(elapsed * 0.65 + index * 0.19, 1.0)
				var mote := Vector2(-14.0 + index * 5.5, 8.0 + phase * 30.0)
				_draw_diamond(mote, 2.8 - phase, Color(0.55, 0.9, 1.0, 0.7 * (1.0 - phase)))
		"HALO RING":
			for index in 8:
				var angle := elapsed * 1.7 + TAU * index / 8.0
				draw_circle(Vector2(cos(angle) * 28.0, sin(angle) * 13.0), 2.2, Color(1.0, 0.76, 0.2, 0.58))
		"PRISM AURA":
			for index in 3:
				var hue := fmod(elapsed * 0.10 + index / 3.0, 1.0)
				var radius := 22.0 + index * 4.0 + sin(elapsed * 2.0 + index) * 1.5
				draw_arc(Vector2.ZERO, radius, -PI * 0.82 + index * 0.25, PI * 0.18 + index * 0.25, 20, Color.from_hsv(hue, 0.42, 1.0, 0.20), 2.0, true)
		"STAR BURST":
			var burst := fmod(elapsed, 1.8) / 1.8
			if burst < 0.42:
				var strength := 1.0 - burst / 0.42
				for index in 6:
					var angle := TAU * index / 6.0
					var start := Vector2.from_angle(angle) * (10.0 + burst * 18.0)
					var finish := Vector2.from_angle(angle) * (24.0 + burst * 30.0)
					draw_line(start, finish, Color(1.0, 0.78, 0.22, strength * 0.72), 2.0, true)
					_draw_diamond(finish, 3.0, Color(0.83, 0.56, 1.0, strength * 0.8))

func _draw_diamond(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0.0, -radius), point + Vector2(radius, 0.0),
		point + Vector2(0.0, radius), point + Vector2(-radius, 0.0),
	]), color)
