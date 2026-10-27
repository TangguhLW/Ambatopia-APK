extends SceneTree
var app
var folder := "res://evidence/ui-revision"
func _initialize():
	call_deferred("run")
func shot(name: String):
	await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run():
	if not OS.get_cmdline_user_args().is_empty():folder=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	app=load("res://scenes/app.tscn").instantiate()
	app.set_meta("visual_freeze",true)
	app.session.store.directory="user://ui-revision-capture"
	root.add_child(app)
	app.settings.master=0
	app.start_local("UIReview")
	app.enter_world("UIREVIEW")
	var game=app.screen
	game.world.create_default("UIREVIEW")
	game.player.position=game.world.spawn_position()
	game.player.reset_appearance()
	for id in [46,34,36,48,40,156]:
		game.player.equip_catalog(id)
	for dimensions in [Vector2i(844,390),Vector2i(390,844),Vector2i(320,568)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		DisplayServer.window_set_size(dimensions)
		await shot("world-%dx%d" % [dimensions.x,dimensions.y])
		game.toggle_inventory()
		await shot("bag-%dx%d" % [dimensions.x,dimensions.y])
		game.inventory.mode="clothes"
		game.inventory.rebuild()
		await shot("clothes-%dx%d" % [dimensions.x,dimensions.y])
		game.toggle_inventory()
	print("UI_REVISION_CAPTURE_DONE")
	quit()
