extends SceneTree
func _initialize():call_deferred("run")
func run():
	var app=load("res://scenes/app.tscn").instantiate();root.add_child(app)
	app.session.store.directory="user://ride-capture-fixture"
	app.start_local("RideQA");app.enter_world("RIDECAPTURE")
	var view=app.screen
	await create_timer(0.1).timeout
	view.set_process(false)
	view.player.catalog_equipment={"feet":11012};view.player.grounded=false;view.player.velocity=Vector2(0,80)
	view.avatar.legacy_particles.particles.clear();view.avatar.legacy_particles.clocks.clear()
	await create_timer(0.08).timeout
	print("RIDE_AIR ",view.avatar.legacy_particles.previous_state," ",view.avatar.elapsed," ",view.avatar.player==view.player," ",view.avatar.is_processing())
	view.player.grounded=true;view.player.velocity=Vector2.ZERO
	await create_timer(0.05).timeout
	print("RIDE_LAND ",view.avatar.legacy_particles.particles.map(func(p):return int(p.id)))
	await RenderingServer.frame_post_draw
	print("RIDE_AFTER ",view.avatar.legacy_particles.particles.map(func(p):return int(p.id)))
	quit()
