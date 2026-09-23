class_name GameManager
extends Node2D

enum State { PLAYING, PLAYER_DEAD, PROTOTYPE_COMPLETE }
var state := State.PLAYING
@onready var player: PlayerController = $Player
@onready var spider: SpiderController = $Spider
@onready var gauge: SpiderDistanceGauge = $HUD/Gauge
@onready var stages: StageManager = $StageManager
@onready var beans: BeanSpawner = $BeanSpawner

func _ready() -> void:
	process_physics_priority = 10
	stages.prototype_completed.connect(_on_prototype_completed)

func _physics_process(_delta: float) -> void:
	if state != State.PLAYING:
		return
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	stages.update_progress(player.global_position.y)
	if gauge.distance_px <= Balance.CATCH_DISTANCE:
		state = State.PLAYER_DEAD
		$HUD/Dead.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYER_DEAD and event.is_action_pressed("ui_accept"):
		restart()

func restart() -> void:
	for child in get_tree().get_nodes_in_group("run_transient"): child.free()
	beans.reset_run()
	player.reset_run(Vector2(0, 0))
	spider.reset_run(Vector2(0, Balance.START_DISTANCE))
	stages.reset_run()
	state = State.PLAYING
	$HUD/Dead.visible = false
	$HUD/Complete.visible = false
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)

func _on_prototype_completed() -> void:
	state = State.PROTOTYPE_COMPLETE
	$HUD/Complete.visible = true
