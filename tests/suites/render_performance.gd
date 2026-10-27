extends RefCounted
func run(t):
	var path="res://src/game/terrain_layer.gd"
	if not ResourceLoader.exists(path):
		t.check(false,"World retains static terrain draw lists across frames")
		return
	var app=load("res://scenes/app.tscn").instantiate()
	app.session.store.directory="user://retained-terrain-fixture"
	t.root.add_child(app)
	app.start_local("TerrainQA");app.enter_world("TERRAINQA")
	var view=app.screen
	var layer=view.terrain_layer
	var before: int=layer.rebuild_count
	for i in 60:layer.refresh()
	t.check(layer.rebuild_count==before,"Unchanged world does not rebuild static terrain every frame")
	var tile=Vector2i(49,23)
	view.world.set_tile(tile,1)
	layer.refresh()
	t.check(layer.rebuild_count>before,"Tile mutation invalidates the retained terrain")
	t.check(layer.rebuild_count-before<=4,"A block mutation only rebuilds its chunk and affected boundary neighbors")
	var chunk=layer.chunks.get(Vector2i(tile.x/16,tile.y/16))
	t.check(chunk!=null and chunk.commands.any(func(c):return c.tile==tile),"A placed block is present in the refreshed draw list")
	before=layer.rebuild_count
	view.camera.x+=1
	layer.refresh()
	t.check(layer.rebuild_count==before,"Sub-tile camera movement changes transforms without rebuilding terrain")
	view.world.set_tile(tile,0);layer.refresh()
	before=layer.rebuild_count
	var actions=load("res://src/game/interactions.gd").new()
	t.check(actions.apply(view.world,view.player,"place",tile,200014).accepted,"Background placement uses the normal player action")
	layer.refresh()
	t.check(layer.rebuild_count>before,"Background placement refreshes the retained draw list")
	before=layer.rebuild_count
	actions.cooldown=0;view.player.developer=true
	t.check(actions.apply(view.world,view.player,"punch",tile,0).accepted,"Background break uses the normal punch action")
	layer.refresh()
	t.check(layer.rebuild_count>before,"Breaking a background refreshes the retained draw list")
	app.queue_free()
	await t.process_frame
	var bg=load("res://src/ui/background.gd").new()
	bg.menu_mode=false
	bg.set_meta("force_weather_viewport",true)
	t.root.add_child(bg)
	t.check(bg.has_method("create_weather_surface"),"Heavy weather can use a separate logical-resolution render surface")
	t.check(bg.has_method("weather_resolution"),"Android weather has a bounded pixel cost independent of UI resolution")
	if bg.has_method("weather_resolution"):
		t.check(bg.weather_resolution(Vector2(1560,720),false,true)==Vector2i(1300,600),"Android weather budget preserves the display aspect ratio")
		t.check(bg.weather_resolution(Vector2(1280,720),false,false)==Vector2i(1280,720),"Desktop reference pixels retain their original resolution")
	bg.queue_free()
	await t.process_frame
