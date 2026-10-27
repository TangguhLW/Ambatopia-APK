extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var app=load("res://scenes/app.tscn").instantiate();root.add_child(app)
	app.session.store.directory="user://panel019-capture"
	app.start_local("Wardrobe Preview");app.enter_world("PANEL019")
	await process_frame
	app.screen.toggle_inventory()
	await create_timer(0.35).timeout
	app.screen.inventory.mode="clothes";app.screen.inventory.rebuild()
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/render-regression/wardrobe-019-panel.png")
	quit()
