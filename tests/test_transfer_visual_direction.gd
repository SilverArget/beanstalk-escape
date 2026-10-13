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
	_check(visual.scale.x < 0.0, "left transfer mirrors the whole visual root")
	_check(left_rotation < 0.0 and is_equal_approx(absf(left_rotation), 0.18), "left transfer leans left")
	_check(particles != null and particles.direction.x < 0.0 and particles.lifetime <= 0.35, "takeoff trail is short and points behind the local pose")

	player.transition_from = 1
	player.transition_to = 2
	player._update_transition_visual(0.5)
	visual._update_mode(player, 0.016)
	_check(visual.scale.x > 0.0, "right transfer keeps the source orientation")
	_check(visual.rotation > 0.0 and is_equal_approx(visual.rotation, -left_rotation), "transfer lean is direction-symmetric")

	var emblem := visual.cosmetic_sprites.get("EMBLEM") as Sprite2D
	_check(emblem != null and emblem.get_parent() == visual, "cosmetics share the mirrored and leaning visual root")

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

	game.free()
	if failures == 0:
		print("PASS: transfer visuals mirror, lean, trail and pet by direction")
	quit(failures)

func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % label)
