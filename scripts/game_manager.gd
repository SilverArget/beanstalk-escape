class_name GameManager
extends Node2D

enum State { PLAYING, PLAYER_DEAD }
var state := State.PLAYING
@onready var player: PlayerController = $Player
@onready var spider: SpiderController = $Spider
@onready var gauge: SpiderDistanceGauge = $HUD/Gauge

func _physics_process(_delta: float) -> void:
	if state != State.PLAYING:
		return
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)
	if gauge.distance_px <= Balance.CATCH_DISTANCE:
		state = State.PLAYER_DEAD
		$HUD/Dead.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYER_DEAD and event.is_action_pressed("ui_accept"):
		restart()

func restart() -> void:
	player.reset_run(Vector2(0, 0))
	spider.reset_run(Vector2(0, Balance.START_DISTANCE))
	state = State.PLAYING
	$HUD/Dead.visible = false
	gauge.update_from_positions(player.global_position.y, spider.global_position.y)

