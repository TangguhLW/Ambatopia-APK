extends SceneTree
var app
var folder:="res://evidence/item-gameplay"
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
	for x in [48,49,51]:
		game.world.set_tile(Vector2i(x,23),200003)
		runtime.planted(game.world,Vector2i(x,23),3)
		game.world.extras[str(2300+x)].planted-=100
	game.player.equip_catalog(200156)
	game.player.modifiers["Golden Halo!"]={"remaining":100,"item":128,"kind":"player_mod","tint":"","slot":"body"}
	await shot("trees-wardrobe-landscape")
	game.world.set_tile(Vector2i(49,23),204498)
	game.show_item_panel(Vector2i(49,23))
	await shot("machine-landscape")
	game.show_menu()
	root.size=Vector2i(390,844)
	root.content_scale_size=Vector2i(390,844)
	DisplayServer.window_set_size(Vector2i(390,844))
	await process_frame
	game.show_item_panel(Vector2i(49,23))
	await shot("machine-portrait")
	game.show_menu()
	game.toggle_inventory()
	game.inventory.mode="clothes"
	game.inventory.rebuild()
	await shot("clothes-portrait")
	game.toggle_inventory()
	root.size=Vector2i(640,360)
	root.content_scale_size=Vector2i(640,360)
	DisplayServer.window_set_size(Vector2i(640,360))
	var sim=load("res://src/game/simulator_catalog.gd")
	for row in sim.weather_list:
		game.world.weather=row.k
		await shot("weather-"+row.k)
	print("ITEM_RENDER_CAPTURE_DONE weather=",sim.weather_list.size())
	quit()
