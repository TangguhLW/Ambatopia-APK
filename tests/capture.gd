extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	app.session.store.directory = "user://visual-fixtures"
	root.add_child(app)
	await create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute("res://evidence/screenshots")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/screenshots/windows-menu.png")
	app.start_local("Reference")
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/screenshots/windows-worlds.png")
	app.enter_world("VISUAL")
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/screenshots/windows-world.png")
	app.screen.toggle_inventory()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/screenshots/windows-inventory.png")
	app.queue_free()
	await process_frame
	quit()
