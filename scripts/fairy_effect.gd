class_name FairyEffect
extends Node2D

var effect_name := ""
var elapsed := 0.0

func _init() -> void:
	var light_material := CanvasItemMaterial.new()
	light_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = light_material

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
			for layer in 7:
				var fade := 1.0 - float(layer) / 7.0
				var radius := lerpf(31.0, 12.0, fade) * pulse
				draw_circle(Vector2.ZERO, radius, Color(0.48, 1.0, 0.42, 0.025 + fade * 0.035))
		"LIGHT TRAIL":
			for index in 5:
				var trail_pos := Vector2(-12.0 - index * 8.0, sin(elapsed * 5.0 - index) * 4.0)
				var radius := 4.8 - index * 0.55
				draw_circle(trail_pos, radius * 1.8, Color(1.0, 0.24, 0.62, 0.09))
				draw_circle(trail_pos, radius, Color(1.0, 0.48, 0.78, 0.34 - index * 0.035))
				draw_circle(trail_pos, maxf(radius * 0.34, 0.9), Color(1.0, 0.94, 0.98, 0.82))
		"SPARKLE DUST":
			for index in 6:
				var phase := fmod(elapsed * 0.65 + index * 0.19, 1.0)
				var mote := Vector2(-14.0 + index * 5.5, 8.0 + phase * 30.0)
				var strength := 1.0 - phase
				draw_circle(mote, 4.2 - phase, Color(0.25, 0.8, 1.0, 0.12 * strength))
				_draw_diamond(mote, 3.1 - phase, Color(0.52, 0.92, 1.0, 0.78 * strength))
				draw_circle(mote, 0.9, Color(0.94, 1.0, 1.0, 0.92 * strength))
		"HALO RING":
			for index in 8:
				var angle := elapsed * 1.7 + TAU * index / 8.0
				var point := Vector2(cos(angle) * 28.0, sin(angle) * 13.0)
				draw_circle(point, 4.8, Color(1.0, 0.42, 0.04, 0.12))
				draw_circle(point, 2.5, Color(1.0, 0.72, 0.12, 0.72))
				draw_circle(point, 0.9, Color(1.0, 0.96, 0.68, 0.95))
		"PRISM AURA":
			for index in 5:
				var hue := fmod(elapsed * 0.14 + index / 5.0, 1.0)
				var radius := 22.0 + index * 2.3 + sin(elapsed * 2.0 + index) * 1.5
				var color := Color.from_hsv(hue, 0.82, 1.0, 0.40)
				draw_arc(Vector2.ZERO, radius, -PI * 0.84 + index * 0.16, PI * 0.20 + index * 0.16, 24, color, 2.8, true)
		"STAR BURST":
			var burst := fmod(elapsed, 1.8) / 1.8
			if burst < 0.42:
				var strength := 1.0 - burst / 0.42
				for index in 6:
					var angle := TAU * index / 6.0
					var start := Vector2.from_angle(angle) * (10.0 + burst * 18.0)
					var finish := Vector2.from_angle(angle) * (24.0 + burst * 30.0)
					draw_line(start, finish, Color(1.0, 0.52, 0.08, strength * 0.18), 5.0, true)
					draw_line(start, finish, Color(1.0, 0.86, 0.28, strength * 0.82), 2.0, true)
					_draw_diamond(finish, 4.5, Color(0.62, 0.28, 1.0, strength * 0.24))
					_draw_diamond(finish, 2.8, Color(0.92, 0.72, 1.0, strength * 0.88))
					draw_circle(finish, 0.8, Color(1.0, 0.98, 0.72, strength))

func _draw_diamond(point: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0.0, -radius), point + Vector2(radius, 0.0),
		point + Vector2(0.0, radius), point + Vector2(-radius, 0.0),
	]), color)
