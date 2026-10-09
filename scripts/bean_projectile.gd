class_name BeanProjectile
extends Node2D

var blocked_route := 1
var warning_remaining := Balance.BEAN_WARNING_SECONDS
var active := true
var falling := false
var warning_started_msec := 0
var fall_started_msec := 0
var landing_y := 0.0
const WARNING_SCREEN_TOP_PX := 150.0
const WARNING_SCREEN_BOTTOM_PX := 285.0

func setup(route: int, at_y: float) -> void:
	blocked_route = route
	landing_y = at_y
	position = Vector2(Balance.ROUTE_X[route], at_y)
	warning_started_msec = Time.get_ticks_msec()

func _physics_process(delta: float) -> void:
	if not active: return
	var slow := Balance.TIME_WINGS_SLOW_SCALE if get_tree().get_first_node_in_group("time_wings_active") != null else 1.0
	if not falling:
		warning_remaining = maxf(warning_remaining - delta * slow, 0.0)
		$Warning.visible = true
		$Warning.global_position = warning_screen_position()
		$Warning.rotation = sin(Time.get_ticks_msec() * 0.025) * 0.12
		if warning_remaining <= 0.0:
			falling = true
			fall_started_msec = Time.get_ticks_msec()
			$Warning.visible = false
			$Body.visible = true
	else:
		$Warning.position = Vector2.ZERO
		position.y += Balance.BEAN_FALL_SPEED * delta * slow

func warning_screen_position() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null:
		player = get_parent().get_parent().get_node_or_null("Player") as PlayerController
	if player == null:
		return Vector2(global_position.x, landing_y)
	var top := player.global_position.y - WARNING_SCREEN_BOTTOM_PX
	var bottom := player.global_position.y - WARNING_SCREEN_TOP_PX
	return Vector2(global_position.x, clampf(landing_y, top, bottom))

func consume() -> void:
	if not active: return
	active = false
	set_physics_process(false)
	$Warning.visible = false
	$Body.show_burst()
	get_tree().create_timer(0.16).timeout.connect(queue_free)
