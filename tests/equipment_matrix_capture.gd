extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1120,640)
	root.content_scale_size=Vector2i(1120,640)
	DisplayServer.window_set_size(root.size)
	var canvas=Control.new()
	canvas.theme=load("res://src/ui/theme.gd").build()
	root.add_child(canvas)
	var background=ColorRect.new()
	background.color=Color("184657")
	background.size=Vector2(1120,640)
	canvas.add_child(background)
	var catalog=load("res://src/game/item_catalog.gd")
	var rows=[]
	var samples=[46,36,48,40,34,92,362,68,2570,2648,130,1780]
	var states=[]
	for i in samples.size():
		var id=samples[i]
		var entry=catalog.record(id)
		var summary=catalog.summary(id)
		var row={"id":id,"name":summary.name,"slot":summary.slot,"source":entry.asset.source,"frame":entry.asset.frame,"layer":summary.slot,"directions":[-1,1],"tested_states":["idle","jump","punch"],"status":"representative mapping; exact special branches unverified" if id==1780 else "representative visual and state test"}
		for direction in [-1,1]:
			var p=load("res://src/game/player_state.gd").new()
			var equipped: bool=p.equip_catalog(id)
			row.equipped=equipped
			if not equipped:row.status="not wearable through canonical catalogue; special mapping unverified"
			p.facing=direction
			p.grounded=true
			var avatar=load("res://src/game/avatar_view.gd").new()
			avatar.position=Vector2(80+(i%6)*185+direction*31,130+int(i/6)*240)
			avatar.scale=Vector2.ONE*2.5
			canvas.add_child(avatar)
			avatar.present(p,0)
			row.anchor=[avatar.slot_origin(summary.slot).x,avatar.slot_origin(summary.slot).y]
			states.append({"player":p,"avatar":avatar})
		rows.append(row)
		var label=load("res://src/ui/theme.gd").label("%d · %s\n%s"%[id,summary.name,summary.slot],14)
		label.position=Vector2(4+(i%6)*185,145+int(i/6)*240)
		label.size=Vector2(180,75)
		canvas.add_child(label)
	for action in ["idle","jump","punch"]:
		for s in states:
			s.player.grounded=action!="jump"
			s.player.velocity=Vector2(0,-200) if action=="jump" else Vector2.ZERO
			s.player.punch_time=0.12 if action=="punch" else 0
			s.player.punch_direction=Vector2(s.player.facing,-1).normalized()
		for tick in 12:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/render-regression/equipment-"+action+".png")
	var file=FileAccess.open("res://evidence/render-regression/equipment-matrix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	print("EQUIPMENT_MATRIX_DONE: ",rows.size()," items, both directions, three states; custom Legendbot remains explicitly unverified")
	quit()
