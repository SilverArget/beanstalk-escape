extends SceneTree

class FakeGame extends Node:
	var app_state: int = GameManager.AppState.PLAYING

var failures := 0

func _init() -> void:
	var game := FakeGame.new()
	root.add_child(game)
	var player := PlayerController.new()
	game.add_child(player)
	var visual := PlayerVisual.new()
	player.add_child(visual)
	visual._build_visual()
	visual._load_skin("M1")
	player.body = visual

	player.support_state = PlayerController.SupportState.TRANSFERRING
	player.transition_from = 1
	player.transition_to = 0
	player._update_transition_visual(0.5)
	visual._update_mode(player, 0.016)
	var left_rotation := visual.rotation
	var particles := visual.get("takeoff_particles") as CPUParticles2D
	var trails: Array[Line2D] = []
	for child in visual.get_children():
		if child is Line2D and child.name.begins_with("TransferMotionTrail"):
			trails.append(child as Line2D)
	_check(visual.scale.x < 0.0, "left transfer mirrors the whole visual root")
	_check(left_rotation < 0.0 and is_equal_approx(absf(left_rotation), 0.18), "left transfer leans left")
	_check(particles != null and particles.texture != null, "takeoff leaves use a visible texture")
	if particles != null and particles.texture != null:
		var leaf_height := particles.texture.get_height()
		_check(particles.amount >= 5 and particles.amount <= 8, "takeoff emits five to eight leaves")
		_check(leaf_height * particles.scale_amount_min >= 10.0 and leaf_height * particles.scale_amount_max <= 16.0, "takeoff leaves render at ten to sixteen pixels")
		_check(particles.color.a >= 0.85 and particles.lifetime >= Balance.BRANCH_TRANSITION_SECONDS, "takeoff leaves stay opaque through the transfer")
		_check(particles.direction.x * signf(visual.scale.x) > 0.0, "left transfer throws its leaves right")
	_check(trails.size() == 3, "three motion trails are drawn")
	if trails.size() == 3:
		var left_trail := trails[0]
		_check(left_trail.visible and left_trail.width >= 3.0 and left_trail.width <= 5.0 and left_trail.z_index < 0, "motion trails are visible behind the character")
		_check(left_trail.to_global(left_trail.points[-1]).x > left_trail.to_global(left_trail.points[0]).x, "left transfer throws its trail right")

	player.transition_from = 1
	player.transition_to = 2
	player._update_transition_visual(0.5)
	visual._update_mode(player, 0.016)
	_check(visual.scale.x > 0.0, "right transfer keeps the source orientation")
	_check(visual.rotation > 0.0 and is_equal_approx(visual.rotation, -left_rotation), "transfer lean is direction-symmetric")
	if particles != null:
		_check(particles.direction.x * signf(visual.scale.x) < 0.0, "right transfer throws its leaves left")
	if trails.size() == 3:
		_check(trails[0].to_global(trails[0].points[-1]).x < trails[0].to_global(trails[0].points[0]).x, "right transfer throws its trail left")


	var follower := PetFollower.new()
	game.add_child(follower)
	follower._ready()
	follower.target = player
	follower.global_position = player.global_position
	follower._process(1.0)
	_check(not follower.sprite.flip_h and follower.global_position.x < player.global_position.x, "pet faces right and follows behind a right transfer")
	player.transition_to = 0
	follower._process(1.0)
	_check(follower.sprite.flip_h and follower.global_position.x > player.global_position.x, "pet faces left and follows behind a left transfer")

	player.support_state = PlayerController.SupportState.SUPPORTED
	visual._update_mode(player, 0.016)
	_check(visual.scale.x > 0.0, "leaving transfer clears mirroring")
	if trails.size() == 3:
		_check(trails[0].visible and trails[0].modulate.a < 1.0, "motion trail starts fading after transfer")
		visual._update_mode(player, 0.35)
		_check(not trails[0].visible, "motion trail disappears within 0.35 seconds")

	game.free()
	if failures == 0:
		print("PASS: transfer leaves and motion trails are visible and direction-aware")
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % label)
