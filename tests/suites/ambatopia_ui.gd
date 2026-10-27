extends RefCounted

func run(t) -> void:
	var world = load("res://src/game/world_state.gd").new()
	world.create_default("NEWLAND")
	t.check(world.foreground.has(3),"New world contains underground rock")
	t.check(world.foreground.has(7),"New world contains deep lava")
	var second = load("res://src/game/world_state.gd").new()
	second.create_default("NEWLAND")
	t.check(world.foreground == second.foreground,"World terrain is deterministic by name")
	t.check(second.restore(world.serialize()),"Rock/lava world survives save round trip")
	var registry = preload("res://src/game/placeable_blocks.gd")
	t.check(registry.items().size()==867,"Static block registry includes 836 static blocks plus 31 locks")
	var player = load("res://src/game/player_state.gd").new()
	player.position = world.spawn_position()
	var actions = load("res://src/game/interactions.gd").new()
	t.check(actions.apply(world,player,"place",Vector2i(49,23),100100).accepted,"Catalog Wood Block places using its stable original ID")
	t.check(second.restore(world.serialize()) and second.tile_at(Vector2i(49,23))==100100,"Catalog blocks survive save round trip")
	actions.cooldown = 0
	t.check(not actions.apply(world,player,"place",Vector2i(51,23),199999).accepted,"Unknown catalog block ID is rejected")
	var app = load("res://scenes/app.tscn").instantiate()
	app.session.store.directory = "user://ambatopia-ui-fixtures"
	t.root.add_child(app)
	await t.process_frame
	t.check(app.screen.logo.texture.resource_path.ends_with("ambatopia/title.png"),"Requested title is active")
	t.check(app.screen.controls.quit.text == "Download","Download replaces Quit")
	app.start_local("WardrobeTest")
	app.enter_world("UIREVISION")
	app.screen.toggle_inventory()
	var bag = app.screen.inventory
	bag.activate_item(98,1000)
	t.check(app.session.player.catalog_equipment.get("hand",-1) != 98,"Single tap inspects without equipping")
	bag.activate_item(98,1200)
	t.check(app.session.player.catalog_equipment.get("hand",-1) == 98,"Double tap equips supported item")
	bag.activate_item(98,2000)
	bag.activate_item(98,2200)
	t.check(app.session.player.catalog_equipment.get("hand",-1) != 98,"Second double tap removes item")
	app.screen.toggle_inventory()
	app.screen.set_chat_height(90)
	t.check(app.screen.chat_panel.clip_contents,"Broadcast clips text to panel")
	app.queue_free()
	await t.process_frame
