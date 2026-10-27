extends RefCounted

func run(t) -> void:
	var world = load("res://src/game/world_state.gd").new()
	world.create_default("ACTIONS")
	var player = load("res://src/game/player_state.gd").new()
	player.position = world.spawn_position()
	var actions = load("res://src/game/interactions.gd").new()
	var punch: Dictionary = actions.apply(world,player,"punch",world.main_door+Vector2i.DOWN,0)
	t.check(player.punch_time > 0 and not punch.events.is_empty(),"Protected blocks still show fist and sound event")
	actions.cooldown = 0
	t.check(actions.apply(world,player,"place",Vector2i(51,23),5).accepted,"First World Lock can be placed")
	actions.cooldown = 0
	t.check(not actions.apply(world,player,"place",Vector2i(49,23),5).accepted,"Second World Lock rejected across different tiles")
	player.equip_catalog(98)
	world.set_tile(Vector2i(51,23),1)
	for hit in 2:
		actions.cooldown = 0
		actions.apply(world,player,"punch",Vector2i(51,23),0)
	t.check(world.tile_at(Vector2i(51,23)) == 0,"Pickaxe local enhanced digging uses fewer hits")
	var router = load("res://src/game/input_router.gd").new()
	router.selected_action = "punch"
	router.press("interact")
	t.check(not router.sample().get("direct_punch",true),"Tile-click punch preserves selected target")
	var hud = load("res://src/ui/hud.gd").new()
	t.root.add_child(hud)
	await t.process_frame
	var image = hud.chat_button.get_child(0).texture
	t.check(image is AtlasTexture and image.region.size == Vector2(136,106),"Chat icon crops empty atlas padding")
	hud.size = Vector2(390,844)
	hud.layout()
	t.check(hud.chat_button.size.x>=52 and hud.chat_button.size.y>=44,"Portrait chat keeps a usable touch target")
	hud.queue_free()
	t.check(ResourceLoader.exists("res://src/ui/audio_feedback.gd"),"Persistent button audio feedback exists")
	await t.process_frame
