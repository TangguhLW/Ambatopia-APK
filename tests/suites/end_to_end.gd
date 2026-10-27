extends RefCounted

func run(t) -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	app.session.store.directory = "user://integration-worlds"
	t.root.add_child(app)
	await t.process_frame
	app.start_local("QA Player")
	t.check(app.route == "worlds", "Menu to local profile to chooser")
	var result: Dictionary = app.enter_world("QAWORLD")
	t.check(result.ok and app.route == "play", "Enter playable world")
	await t.process_frame
	var play = app.screen
	t.check(play.world != null and play.player != null, "World and player are bound")
	t.check(play.player.grounded, "Player can jump immediately after safe spawn")
	t.check(play.hud.has_method("route_touch"), "HUD supports independent simultaneous touch pointers")
	if play.hud.has_method("route_touch"):
		play.hud.route_touch(0, play.hud.left.get_global_rect().get_center(), true)
		play.hud.route_touch(1, play.hud.jump.get_global_rect().get_center(), true)
		var touch_state: Dictionary = play.input.sample()
		t.check(touch_state.axis == -1 and touch_state.jump_pressed, "Move and jump together on two fingers")
		play.hud.route_touch(0, Vector2.ZERO, false)
		play.hud.route_touch(1, Vector2.ZERO, false)
		t.check(play.input.sample().axis == 0, "Touch releases outside control bounds")
	play.select_action("place", 1)
	play.input.press("punch")
	t.check(play.input.sample().action == "punch", "Fist override remains punch when dirt selected")
	play.input.cancel_all()
	play.toggle_inventory()
	t.check(play.inventory != null and play.input.text_focus, "Inventory pauses gameplay input")
	play.player.equipment.shirt = 1
	play.toggle_inventory()
	t.check(not play.input.text_focus, "Closing inventory restores input")
	play.toggle_chat()
	t.check(play.chat != null, "Chat field opens")
	var chat_position: Vector2 = play.chat.position
	play.player.punch_time = 0.18
	t.check(play.chat.position == chat_position, "Punch cannot shift chat layout")
	play.toggle_chat()
	t.check(app.session.save().ok, "Save succeeds before status")
	play.exit_world()
	t.check(app.route == "worlds", "Exit World reaches chooser")
	var reopened: Dictionary = app.enter_world("QAWORLD")
	t.check(reopened.ok, "Saved world can reopen: " + str(reopened))
	t.check(app.session.player.equipment.shirt == 1, "Outfit survives re-entry")
	app.queue_free()
	await t.process_frame
