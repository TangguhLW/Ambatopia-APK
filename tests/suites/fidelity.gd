extends RefCounted

func run(t) -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	app.session.store.directory = "user://fidelity-fixtures"
	t.root.add_child(app)
	await t.process_frame
	t.check(app.screen.has_method("reference_geometry"), "Menu exposes measured screenshot geometry")
	if app.screen.has_method("reference_geometry"):
		var rects: Dictionary = app.screen.reference_geometry(Vector2(1015, 772))
		t.check(rects.play == Rect2(319, 382, 376, 84), "Play geometry matches attached client crop")
	app.navigate("worlds")
	t.check(app.screen.find_child("WorldChat", true, false) != null, "Chooser uses top chat panel")
	app.start_local("Visual")
	app.enter_world("FIDELITY")
	await t.process_frame
	t.check(app.screen.zoom == 1.0, "Reference gameplay uses unit tile zoom")
	t.check(app.screen.hud.bar.get_child_count() == 4, "Four hotbar slots")
	app.screen.hud.chat_height_requested.emit(180)
	t.check(app.screen.chat_height == 180, "Drag handle opens chat to requested height")
	var chat_origin: Vector2 = app.screen.hud.drawer.position
	app.screen.player.punch_time = 0.15
	await t.process_frame
	t.check(app.screen.hud.drawer.position == chat_origin, "Punch does not move dragged chat")
	app.screen.hud.chat_height_requested.emit(0)
	t.check(not app.screen.chat_panel.visible, "Drag up closes chat")
	app.screen.toggle_inventory()
	app.screen.inventory.search.text = "Dirt"
	app.screen.inventory.rebuild()
	t.check(app.screen.inventory.entries.size()>0 and app.screen.inventory.entries.all(func(item): return "dirt" in item.name.to_lower()), "Inventory search filters expanded blocks by name")
	app.queue_free()
	await t.process_frame
