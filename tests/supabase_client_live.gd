extends SceneTree
var app
var checks: Array[String]=[]
var failures: Array[String]=[]
var appearance_probe: Array=[]
func _initialize():call_deferred("run")
func check(value: bool,label: String):
	checks.append(label)
	if not value:failures.append(label)
func write_json(path: String,value):
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(value,"\t"));file.close()
func run():
	var config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	app=load("res://scenes/app.tscn").instantiate()
	app.set_meta("visual_freeze",true)
	root.add_child(app)
	DisplayServer.window_set_title("Ambatopia — Supabase live QA")
	app.settings.master=0
	app.accounts.cloud_enabled=true
	app.accounts.access_token=config.token
	app.accounts.profile=config.profile
	app.network.queue_free()
	app.network=load("res://src/network/supabase_client.gd").new()
	app.network.accounts=app.accounts;app.network.app=app
	app.add_child(app.network)
	app.network.received.connect(app.receive_network)
	app.profile={"id":config.profile.id,"display_name":config.profile.amba_id}
	app.shared_selection=true
	var result: Dictionary=app.enter_world(config.world)
	check(result.ok,"Godot starts a Supabase world join")
	var deadline:=Time.get_ticks_msec()+25000
	while app.route!="play" and Time.get_ticks_msec()<deadline:await create_timer(0.05).timeout
	check(app.route=="play","Godot joins the remote world without the localhost server")
	if app.route=="play":
		var game=app.screen
		var initial: Vector2=game.player.position
		game.input.press("left")
		await create_timer(0.16).timeout
		game.input.release("left")
		check(game.player.position.x<initial.x-5,"Local movement responds while using Supabase transport")
		game.input.press("jump")
		await create_timer(0.06).timeout
		game.input.release("jump")
		check(game.player.velocity.y<0,"Jump is simulated locally without a network round trip")
		game.input.press("punch")
		await create_timer(0.05).timeout
		game.input.release("punch")
		check(game.player.punch_time>0,"Punch starts immediately in the real Godot world view")
		check(game.sfx_counts.get("punch",0)>0,"Punch plays its mapped local sound")
		var peer_topic: String="realtime:motion:"+config.world+":"+config.other_uid
		deadline=Time.get_ticks_msec()+15000
		while not app.network.topics.get(peer_topic,{}).get("ready",false) and Time.get_ticks_msec()<deadline:
			await create_timer(0.05).timeout
		check(app.network.topics.get(peer_topic,{}).get("ready",false),"Peer movement subscription is ready before sending the test sample")
		write_json(config.ready_path,{"ready":true})
		deadline=Time.get_ticks_msec()+20000
		while Time.get_ticks_msec()<deadline:
			var has_chat: bool=game.local_messages.any(func(text):return "Godot bridge verification" in text)
			var motion_ready:=false
			for remote in game.remote_players.values():
				if absf(remote.target.x-1580)<1:motion_ready=true
			if has_chat and game.world.tile_at(Vector2i(48,23))==1 and motion_ready:break
			await create_timer(0.05).timeout
		check(not game.remote_players.is_empty(),"Godot renders another authenticated player")
		check(game.local_messages.any(func(text):return "Godot bridge verification" in text),"Godot receives live world chat")
		check(game.world.tile_at(Vector2i(48,23))==1,"Godot receives a persistent block edit from the other client")
		var remote_motion:=false
		for remote in game.remote_players.values():
			if absf(remote.target.x-1580)<1:remote_motion=true
		check(remote_motion,"Godot accepts and interpolates the authenticated peer's motion sample")
		var outfit={"shirt":5264,"neck":6064,"feet":1740,"hand":5480}
		game.player.catalog_equipment=outfit.duplicate();game.player.skin_index=2
		game.player.item_options={"pet_5480":false};game.sync_outfit()
		deadline=Time.get_ticks_msec()+12000
		while Time.get_ticks_msec()<deadline:
			var ready:=false
			for remote in game.remote_players.values():
				ready=remote.state.catalog_equipment==outfit and remote.state.item_options.get("pet_5480",true)==false
			if ready:break
			await create_timer(0.05).timeout
		check(game.shared,"Live transport uses the shared native WorldView")
		for remote in game.remote_players.values():
			appearance_probe.append({"expected":outfit,"actual":remote.state.catalog_equipment.duplicate(),"skin":remote.state.skin_index,"expected_buffs":game.player.abilities(),"actual_buffs":remote.state.abilities()})
			check(remote.state.catalog_equipment==outfit and remote.state.skin_index==2,"Live SQL outfit and skin match the offline catalog equipment")
			check(remote.state.item_options.get("pet_5480",true)==false,"Live private motion channel applies the pet switch")
			check(remote.avatar.get_script()==game.avatar.get_script(),"Live and offline avatars use the exact same Godot renderer")
			check(remote.state.abilities()==game.player.abilities(),"Live peer and offline-equivalent outfit resolve identical buffs")
			check(remote.avatar.body_lift(remote.state)<0,"Live Spirit Guide and StarBoard retain their native hover pose")
			check(remote.avatar.item_tracks.pet_for(remote.state).is_empty(),"Disabled live Rayman pet is not drawn")
		await create_timer(0.35).timeout
		for remote in game.remote_players.values():
			check(not remote.avatar.ancestral_particles.particles.is_empty(),"Live Neon Nerves executes its source rainbow emitter")
		game.toggle_inventory();await create_timer(0.4).timeout
		check(is_instance_valid(game.inventory) and game.inventory.worn==game.player.catalog_equipment,"Live backpack uses the same equipped-item state as offline")
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(config.report_path+".png")
		game.toggle_inventory()
		await app.accounts.database_call("game_leave",{"p_player_id":app.network.id})
	write_json(config.report_path,{"checks":checks,"failures":failures,"appearance_probe":appearance_probe,"platform":"Windows Godot client, real Supabase transport","renderer":DisplayServer.get_name()})
	app.network.close()
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
