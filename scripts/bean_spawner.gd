class_name BeanSpawner
extends Node2D

var spawned_keys: Dictionary = {}
var hit_count := 0
var warning_count := 0
@onready var player: PlayerController = get_parent().get_node("Player")
@onready var spider: SpiderController = get_parent().get_node("Spider")
@onready var stages: StageManager = get_parent().get_node("StageManager")
@onready var game: GameManager = get_parent() as GameManager
const BEAN_SCENE := preload("res://scenes/bean_projectile.tscn")

func _physics_process(_delta: float) -> void:
	for stage_pattern: Dictionary in stages.patterns:
		for slot_index in stage_pattern.bean_slots.size():
			var slot: Dictionary = stage_pattern.bean_slots[slot_index]
			var warning_y: float = -(float(stage_pattern.stage - 1) * Balance.STAGE_HEIGHT + float(slot.warning_height))
			for volley_index in int(slot.get("count", 1)):
				var target_y: float = -((stage_pattern.stage - 1 + slot.progress) * Balance.STAGE_HEIGHT) - float(volley_index) * 70.0
				var key := "%d:%d:%d" % [stage_pattern.stage, slot_index, volley_index]
				if not spawned_keys.has(key) and player.global_position.y <= warning_y:
					if game != null:
						game.show_bean_tutorial()
					spawn_bean(slot.blocked_route, target_y, key)
				if spawned_keys.has(key) and player.global_position.y <= target_y:
					var spawned := get_node_or_null(NodePath(str(spawned_keys[key]))) as BeanProjectile
					if spawned != null:
						spawned.request_release()
	for bean in get_tree().get_nodes_in_group("beans"):
		var relative_y: float = bean.global_position.y - player.global_position.y
		var previous_y: float = bean.get_meta("previous_relative_y", relative_y)
		var crossed_player := previous_y < 0.0 and relative_y >= 0.0
		var horizontal_hit := absf(bean.global_position.x - player.global_position.x) <= Balance.BEAN_HIT_RADIUS
		if bean.active and bean.falling and horizontal_hit and (absf(relative_y) <= Balance.BEAN_HIT_RADIUS or crossed_player):
			_hit(bean)
		elif bean.global_position.y > player.global_position.y + 500.0:
			bean.queue_free()
		else:
			bean.set_meta("previous_relative_y", relative_y)

func spawn_bean(route: int, target_y: float, key := "forced") -> BeanProjectile:
	var bean := BEAN_SCENE.instantiate() as BeanProjectile
	bean.add_to_group("beans")
	bean.add_to_group("run_transient")
	add_child(bean)
	# The top of the collider begins at A+120 and stays world-fixed through warning.
	var stage_number := stages.stage_for_y(target_y)
	var target_x := float(ScaleLock.TRUNK_SAFE_WORLD_X[route]) if stage_number <= 2 else float(Balance.ROUTE_X[route])
	bean.setup(route, target_y - 120.0, target_x)
	bean.set_meta("encounter_key", key)
	spawned_keys[key] = bean.get_path()
	warning_count += 1
	return bean

func force_contact(bean: BeanProjectile) -> void:
	if bean.active: _hit(bean)

func _hit(bean: BeanProjectile) -> void:
	if not bean.active:
		return
	player.apply_bean_hit()
	spider.apply_bean_boost()
	if game != null:
		game.on_bean_hit()
	hit_count += 1
	bean.consume()

func reset_run() -> void:
	for bean in get_tree().get_nodes_in_group("beans"): bean.free()
	spawned_keys.clear()
	hit_count = 0
	warning_count = 0
