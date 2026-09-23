class_name BeanProjectile
extends Node2D

var blocked_route := 1
var warning_remaining := Balance.BEAN_WARNING_SECONDS
var active := true
var falling := false
var warning_started_msec := 0
var fall_started_msec := 0

func setup(route: int, at_y: float) -> void:
	blocked_route = route
	position = Vector2(Balance.ROUTE_X[route], at_y)
	warning_started_msec = Time.get_ticks_msec()

func _physics_process(delta: float) -> void:
	if not active: return
	if not falling:
		warning_remaining = maxf(warning_remaining - delta, 0.0)
		$Warning.visible = true
		$Warning.rotation = sin(Time.get_ticks_msec() * 0.025) * 0.12
		if warning_remaining <= 0.0:
			falling = true
			fall_started_msec = Time.get_ticks_msec()
			$Warning.visible = false
			$Body.visible = true
	else:
		position.y += Balance.BEAN_FALL_SPEED * delta

func consume() -> void:
	if not active: return
	active = false
	visible = false
	set_physics_process(false)
