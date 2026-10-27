extends SceneTree

func _initialize():call_deferred("run")

func run():
	root.size=Vector2i(1120,925)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	var canvas=Control.new()
	canvas.theme=load("res://src/ui/theme.gd").build()
	root.add_child(canvas)
	var bg=ColorRect.new()
	bg.color=Color("184657")
	bg.size=root.size
	canvas.add_child(bg)
	var actors: Array=[]
	var samples=[{"name":"Bare source body","ids":[]}, {"name":"All basic slots","ids":[46,34,36,48,40,362,98]}, {"name":"Top hat / tuxedo","ids":[66,38,50,42]}, {"name":"Animated wings","ids":[156,44,84,76,40]}, {"name":"Native special XML","ids":[15576,15416,15188]}]
	for i in samples.size():
		for facing in [-1,1]:
			var player=load("res://src/game/player_state.gd").new()
			player.grounded=true
			player.facing=facing
			for id in samples[i].ids:player.equip_catalog(id)
			var avatar=load("res://src/game/avatar_view.gd").new()
			avatar.scale=Vector2.ONE*4
			avatar.position=Vector2(140+(i%2)*550+facing*55,220+int(i/2)*285)
			canvas.add_child(avatar)
			avatar.present(player,0);actors.append(avatar)
		var label=load("res://src/ui/theme.gd").label(samples[i].name,24)
		label.position=Vector2(32+(i%2)*550,235+int(i/2)*285)
		label.size=Vector2(500,40)
		canvas.add_child(label)
	for i in 10:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/render-regression/avatar-020-wardrobe.png")
	for avatar in actors:
		avatar.set_process(false)
		avatar.player.punch_time=0.22
		avatar.player.punch_direction=Vector2(avatar.player.facing,0)
		avatar.advance_limbs(0)
		avatar.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/render-regression/avatar-020-punch.png")
	print("HYBRID_CAPTURE_DONE")
	quit()

