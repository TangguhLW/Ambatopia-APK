extends SceneTree
func _initialize():call_deferred("run")
func snapshot(view,tile: Vector2i,name: String):
	for i in 3:await process_frame
	await RenderingServer.frame_post_draw
	var rect:=Rect2i(Vector2i(view.to_screen(Vector2(tile)*32).round()),Vector2i(32,32))
	root.get_texture().get_image().get_region(rect).save_png("res://evidence/render-regression/terrain-cache-"+name+".png")
func run():
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var app=load("res://scenes/app.tscn").instantiate()
	root.add_child(app);app.settings.master=0
	app.session.store.directory="user://terrain-pixel-fixture"
	app.start_local("PixelQA");app.enter_world("CACHEPIXELS")
	var view=app.screen
	view.backdrop.set_process(false)
	var tile=Vector2i(49,23)
	view.world.set_tile(tile,0);view.world.set_background(tile,0)
	await snapshot(view,tile,"before")
	var actions=load("res://src/game/interactions.gd").new()
	var placed=actions.apply(view.world,view.player,"place",tile,200014)
	await snapshot(view,tile,"placed")
	actions.cooldown=0;view.player.developer=true
	var broken=actions.apply(view.world,view.player,"punch",tile,0)
	await create_timer(0.4).timeout
	await snapshot(view,tile,"broken")
	print("TERRAIN_PIXEL_CAPTURE: ",placed.accepted," / ",broken.accepted)
	quit(0 if placed.accepted and broken.accepted else 1)
