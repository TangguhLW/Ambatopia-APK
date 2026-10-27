extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1200,800)
	root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	var canvas=Control.new()
	canvas.theme=load("res://src/ui/theme.gd").build()
	root.add_child(canvas)
	var bg=ColorRect.new();bg.color=Color("184657");bg.size=root.size;canvas.add_child(bg)
	var samples=[1780,15898,15416,14232,15576,15188]
	var actors: Array=[]
	var W=load("res://src/game/web_wardrobe.gd")
	for i in samples.size():
		var record=W.definition(samples[i])
		for facing in [-1,1]:
			var p=load("res://src/game/player_state.gd").new();p.grounded=true;p.facing=facing
			p.catalog_equipment={load("res://src/game/special_wardrobe.gd").SLOTS[int(record.slot)]:samples[i]}
			var avatar=load("res://src/game/avatar_view.gd").new();avatar.scale=Vector2.ONE*3
			avatar.position=Vector2(200+(i%3)*400+facing*65,230+int(i/3)*380)
			canvas.add_child(avatar);avatar.present(p,0);actors.append({"p":p,"avatar":avatar})
		var label=load("res://src/ui/theme.gd").label(str(samples[i])+" "+record.name,18)
		label.position=Vector2(8+(i%3)*400,260+int(i/3)*380);label.size=Vector2(384,55);canvas.add_child(label)
	for pose in ["idle","jump","fall","punch"]:
		for actor in actors:
			actor.p.grounded=pose in ["idle","punch"]
			actor.p.velocity.y=-180 if pose=="jump" else 180 if pose=="fall" else 0
			actor.p.punch_time=0.12 if pose=="punch" else 0
		for i in 6:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/render-regression/special-017-"+pose+".png")
	print("SPECIAL_017_CAPTURE_DONE")
	quit()
