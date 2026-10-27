extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://src/game/simulation.gd"):
		t.check(false, "Fixed-step simulation exists")
		return
	var world = load("res://src/game/world_state.gd").new()
	world.create_default("TEST")
	var restored = load("res://src/game/world_state.gd").new()
	t.check(restored.restore(world.serialize()), "World restores its own schema")
	t.check(restored.restore(JSON.parse_string(JSON.stringify(world.serialize()))), "World restores JSON numeric arrays")
	var p = load("res://src/game/player_state.gd").new()
	p.position = world.spawn_position()
	var sim = load("res://src/game/simulation.gd").new()
	for i in 120:
		sim.step(world, p, {"axis": 0.0}, 1.0 / 60.0)
	t.check(p.grounded, "Spawn settles on solid ground")
	t.check(p.position.distance_to(world.spawn_position()) < 2, "Safe spawn does not fall through bedrock")
	var start = p.position
	sim.step(world, p, {"axis": 0.0, "jump_pressed": true}, 1.0 / 60.0)
	t.check(p.velocity.y < 0, "Jump moves upward")
	for i in 120:
		sim.step(world, p, {"axis": 1.0}, 1.0 / 60.0)
	t.check(p.position.x > start.x + 100, "Movement advances player")
	t.check(p.position.y <= world.ground_y * 32 + 0.1, "Ground collision")
	var p2 = load("res://src/game/player_state.gd").new()
	p2.position = world.spawn_position()
	for i in 120:
		sim.step(world, p2, {"axis": 0.0}, 1.0 / 60.0)
	t.check(p2.position.distance_to(start) < 0.01, "Deterministic standing replay")
	world.set_tile(Vector2i(51, 23), 1)
	p.position = start
	for i in 90:
		sim.step(world, p, {"axis": 1.0}, 1.0 / 60.0)
	t.check(p.position.x <= 51 * 32 - 9, "Wall stops player without tunneling")
	t.check(sim.catchup_steps(0.5) == 5, "Stall catch-up is bounded")
