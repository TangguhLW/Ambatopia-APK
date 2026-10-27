extends SceneTree
var app
var folder := "res://evidence/ambatopia-next"
func _initialize():
	call_deferred("run")
func shot(name):
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run():
	app=load("res://scenes/app.tscn").instantiate()
	app.set_meta("visual_freeze",true)
	app.session.store.directory="user://next-capture-fixtures"
	root.add_child(app)
	for dimensions in [Vector2i(1280,720),Vector2i(390,844),Vector2i(844,390)]:
		root.content_scale_size=dimensions
		root.size=dimensions
		DisplayServer.window_set_size(dimensions)
		await process_frame
		for page in ["menu","login","options","about","download"]:
			app.navigate(page)
			await shot("%s-%dx%d" % [page,dimensions.x,dimensions.y])
		app.start_local("UIReview")
		app.enter_world("UIREVIEW")
		await process_frame
		app.screen.show_menu()
		await shot("world-menu-%dx%d" % [dimensions.x,dimensions.y])
		app.screen.show_menu()
		app.screen.toggle_inventory()
		app.screen.inventory.mode="clothes"
		app.screen.inventory.supported_filter.button_pressed=true
		app.screen.inventory.rebuild()
		await shot("backpack-%dx%d" % [dimensions.x,dimensions.y])
		app.screen.inventory.mode="simulator"
		app.screen.inventory.rebuild()
		await shot("simulator-%dx%d" % [dimensions.x,dimensions.y])
		app.screen.toggle_inventory()
		app.screen.world.weather = "night"
		await shot("night-%dx%d" % [dimensions.x,dimensions.y])
		app.screen.player.amba = true
		await shot("amba-%dx%d" % [dimensions.x,dimensions.y])
	app.queue_free()
	await process_frame
	quit()
