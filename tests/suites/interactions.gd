extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://src/game/interactions.gd"):
		t.check(false, "Separate interactions exist")
		return
	var world = load("res://src/game/world_state.gd").new()
	world.create_default("TEST")
	var p = load("res://src/game/player_state.gd").new()
	p.position = world.spawn_position()
	var actions = load("res://src/game/interactions.gd").new()
	var tile = Vector2i(51, 23)
	var result = actions.apply(world, p, "punch", tile, 1)
	t.check(result.accepted and world.tile_at(tile) == 0, "Punch with dirt selected never places dirt")
	actions.cooldown = 0
	result = actions.apply(world, p, "place", tile, 1)
	t.check(result.accepted and world.tile_at(tile) == 1, "Explicit place changes tile")
	t.check(not actions.apply(world, p, "place", tile, 1).accepted, "Duplicate action rejected")
	actions.cooldown = 0
	t.check(actions.apply(world, p, "wrench", tile, 0).events[0].type == "inspect_requested", "Wrench inspects")
	t.check(world.tile_at(tile) == 1, "Wrench does not break")
	actions.cooldown = 0
	t.check(not actions.apply(world, p, "place", Vector2i(80, 2), 1).accepted, "Range validation")
	t.check(not actions.apply(world, p, "place", Vector2i(49, 23), 9999).accepted, "Unknown item rejected")
	actions.cooldown = 0
	t.check(not actions.apply(world, p, "punch", world.main_door + Vector2i.DOWN, 0).accepted, "Bedrock is unbreakable")
	for i in 3:
		actions.cooldown = 0
		actions.apply(world, p, "punch", tile, 0)
	t.check(world.tile_at(tile) == 0, "Supported block breaks after damage threshold")
