extends SceneTree
var app
var folder:="res://evidence/automation-rules"
func _initialize():
	call_deferred("run")
func shot(name: String):
	await process_frame
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run():
	root.size=Vector2i(844,390)
	root.content_scale_size=Vector2i(844,390)
	DisplayServer.window_set_size(Vector2i(844,390))
	app=load("res://scenes/app.tscn").instantiate()
	app.set_meta("visual_freeze",true)
	app.session.store.directory="user://item-capture-fixtures"
	root.add_child(app)
	app.settings.master=0
	app.start_local("ItemReview")
	app.enter_world("ITEMREVIEW")
	await process_frame
	var game=app.screen
	var runtime=load("res://src/game/item_runtime.gd").new()

	game.player.position=Vector2(48*32+16,24*32)
	for dimensions in [Vector2i(844,390),Vector2i(390,844)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		DisplayServer.window_set_size(dimensions)
		await process_frame
		for pair in [[2072,"xenonite"],[5638,"magplant"],[6950,"gaia"],[2242,"crystal"]]:
			var tile=Vector2i(49,23)
			game.world.set_tile(tile,200000+pair[0])
			game.world.extras.erase(runtime.key(game.world,tile))
			runtime.planted(game.world,tile,pair[0])
			game.show_item_panel(tile)
			await shot(pair[1]+"-"+("portrait" if dimensions.x<dimensions.y else "landscape"))
			game.show_menu()
	print("AUTOMATION_CAPTURE_DONE")
	quit()
