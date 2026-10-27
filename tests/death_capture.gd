extends SceneTree
func _initialize():call_deferred("run")
func shot(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/render-regression/022-"+name+".png")
func run():
	root.size=Vector2i(1120,720);root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	var app=load("res://scenes/app.tscn").instantiate();root.add_child(app)
	app.session.store.directory="user://death-capture-fixture"
	app.start_local("DeathQA");app.enter_world("DIECAPTURE")
	var view=app.screen;view.zoom=3
	view.world.set_tile(Vector2i(51,23),7)
	view.player.position=Vector2(51*32+16,24*32-2)
	await create_timer(0.3).timeout;await shot("death-start")
	await create_timer(1.0).timeout;await shot("death-floating")
	await create_timer(1.4).timeout;await shot("death-respawn")
	quit()
