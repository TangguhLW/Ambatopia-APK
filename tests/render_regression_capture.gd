extends SceneTree
var app
var game
var folder="res://evidence/render-regression/before"
func _initialize():call_deferred("run")
func shot(name):
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")
func run():
	if not OS.get_cmdline_user_args().is_empty():folder=OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(844,390)
	root.content_scale_size=Vector2i(844,390)
	DisplayServer.window_set_size(Vector2i(844,390))
	app=load("res://scenes/app.tscn").instantiate()
	app.set_meta("visual_freeze",true)
	app.session.store.directory="user://render-regression"
	root.add_child(app)
	app.settings.master=0
	app.start_local("RenderQA")
	app.enter_world("RENDERQA")
	game=app.screen
	game.world.create_default("RENDERQA")
	game.set_process(false)
	game.zoom=3
	game.player.reset_appearance()
	for id in [46,34,36,48,40,156]:game.player.equip_catalog(id)
	for tick in 240:
		var phase=tick/30
		game.player.position=game.world.spawn_position()+Vector2(0,-absf(sin(tick*PI/30))*35 if phase<2 else 0)
		game.player.facing=1 if phase%2==0 else -1
		game.player.grounded=phase>=2
		game.player.velocity=Vector2(0,-200 if tick%30<15 else 200) if phase<2 else Vector2(game.player.facing*150,0) if phase<4 else Vector2.ZERO
		game.player.punch_time=maxf(0,0.18-float(tick%15)/30) if phase in [4,5] else 0
		if "punch_direction" in game.player:game.player.punch_direction=Vector2(1,-1).normalized() if phase==4 else Vector2(-1,0)
		if "talk_time" in game.player:game.player.talk_time=maxf(0,2-float(tick-150)/30) if tick>=150 else 0
		game.bubble="Direction / punch / chat fixture"
		game.bubble_time=1 if tick>150 and tick<215 else 0
		game.update_presentation()
		game.queue_redraw()
		await process_frame
		if tick in [10,40,130,165]:await shot("pose-"+str(tick))
	for dimensions in [Vector2i(844,390),Vector2i(390,844),Vector2i(568,320)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		DisplayServer.window_set_size(dimensions)
		game.zoom=1.5
		game.update_presentation()
		await shot("world-%dx%d"%[dimensions.x,dimensions.y])
		game.toggle_inventory()
		await shot("inventory-%dx%d"%[dimensions.x,dimensions.y])
		game.toggle_inventory()
	for route in ["login","about"]:
		app.navigate(route)
		for i in 10:await process_frame
		await shot(route+"-568x320")
	print("RENDER_REGRESSION_CAPTURE_DONE")
	quit()
