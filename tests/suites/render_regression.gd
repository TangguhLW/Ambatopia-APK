extends RefCounted
func run(t):
	var P=load("res://src/game/player_state.gd")
	var avatar=load("res://src/game/avatar_view.gd").new()
	t.root.add_child(avatar)
	t.check(avatar.has_method("pose"),"Avatar exposes a single native pose independent of video direction")
	if not avatar.has_method("pose"):
		avatar.queue_free()
		return
	var p=P.new()
	var w=load("res://src/game/world_state.gd").new()
	w.create_default("POSEQA")
	var sim=load("res://src/game/simulation.gd").new()
	for direction in [-1,1]:
		p.position=w.spawn_position()
		p.facing=direction
		p.grounded=true
		for tick in 70:
			sim.step(w,p,{"axis":0,"jump_pressed":tick==0},1.0/60)
			avatar.present(p,0)
			t.check(p.facing==direction and avatar.pose().facing==direction,"Vertical motion never changes logical or rendered facing")
	p.begin_punch(p.position+Vector2(0,-80))
	t.check(p.punch_direction.y<-.9,"Punch uses the actual upper world target")
	for offset in [Vector2(50,0),Vector2(-50,0),Vector2(0,-50),Vector2(0,50),Vector2(35,-35),Vector2(-35,35)]:
		p.begin_punch(p.position-Vector2(0,16)+offset)
		t.check(p.punch_direction.is_equal_approx(offset.normalized()),"Punch arm follows the same world-space target in cardinal and diagonal directions")
	p.begin_speech("Test chat")
	avatar.present(p,0)
	t.check(avatar.pose().expression=="punch","Punch expression has priority over talking")
	p.punch_time=0
	t.check(avatar.pose().expression=="talk","Talking resumes after punch")
	p.tick_modifiers(10)
	t.check(avatar.pose().expression=="normal","Talking has a bounded duration independent of bubble lifetime")
	t.check(avatar.slot_origin("hat")==Vector2(-16,-48),"Native padded hat frames use the verified headwear offset")
	p.grounded=true
	p.velocity=Vector2.ZERO
	avatar.arm1=deg_to_rad(160)
	avatar.arm2=deg_to_rad(160)
	for tick in 20:avatar.advance_limbs(1.0/60)
	t.check(absf(avatar.arm1)<0.01 and absf(avatar.arm2)<0.01,"Raised arms settle quickly after landing instead of lingering for over a second")
	var background=load("res://src/ui/background.gd").new()
	t.root.add_child(background)
	background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	background.size=Vector2(568,320)
	t.check(background.renderer.viewport_extent(background)==background.size,"Weather fills the full viewport without an artificial horizontal seam")
	background.queue_free()
	var catalog=load("res://src/game/item_catalog.gd")
	var wings=catalog.sprite(156)
	avatar.elapsed=0
	var first=avatar.clothing_layers(156,wings)[0].texture.region
	avatar.elapsed=0.21
	t.check(avatar.clothing_layers(156,wings)[0].texture.region.position.x==first.position.x+32,"Native visual type 4 advances the wearable frame every 200 ms")
	var layers=avatar.clothing_layers(2648,catalog.sprite(2648))
	t.check(layers.size()==2 and layers[0].tint!=Color.WHITE,"Seed-tinted clothing composes both native frames using stored colors")
	t.check(avatar.seed_color(0x332211ff).is_equal_approx(Color(17/255.0,34/255.0,51/255.0,1)),"Seed tint uses little-endian A/R/G/B channel order")
	var holder=Control.new()
	holder.size=Vector2(568,320)
	t.root.add_child(holder)
	var panel=load("res://src/ui/page_panel.gd").new()
	holder.add_child(panel)
	panel.reflow(0)
	t.check(panel.size.x<=720 and Rect2(Vector2.ZERO,holder.size).encloses(panel.get_rect()),"Non-game panel fits a short landscape viewport")
	panel.reflow(100)
	t.check(panel.get_rect().end.y<holder.size.y-20,"Panel reserves space for the virtual keyboard")
	holder.queue_free()
	var native=load("res://src/game/native_item_renderer.gd")
	var mobile=native.definition(14232)
	t.check(int(mobile.sprites.item_Sprite.frame[0])==7 and int(mobile.sprites.item_Sprite.frame[1])==12,"Native XML frame attribute is preserved instead of silently sampling atlas origin")
	var found_barong=false
	for definition in native.definitions.values():
		if definition.source=="BarongDanceCostumeShirt.xml":
			found_barong=int(definition.sprites.item_Sprite.frame[0])==27 and int(definition.sprites.item_Sprite.frame[1])==29
	t.check(found_barong,"Special Barong costume uses the verified local cosmetics frame")
	var wings_definition=native.definition(15416)
	t.check(native.sprite_frame(wings_definition,"s_wing",9,"Fall","Equip",0)==Vector2(14,12),"Constellation fall selects its recovered fall frame, not the last unrelated animation")
	t.check(native.sprite_frame(wings_definition,"s_wing",9,"Jump","Equip",0)==Vector2(11,12),"Constellation jump begins at its first recovered frame on state entry")
	t.check(native.sprite_frame(wings_definition,"s_wing",9,"Jump","Equip",5)==Vector2(14,12),"Non-looping special animation holds its final frame")
	for id in [14192,14232,14234,14262,14294,15188,15416,15576]:
		t.check(p.equip_catalog(id),"Special native costume is wearable through normal inventory validation: "+str(id))
	var transport=load("res://src/network/supabase_client.gd")
	t.check(not transport.motion_changed({"x":1,"vx":0,"punch":0},{"x":1,"vx":0,"punch":0}),"An unchanged idle player does not spend a fresh movement broadcast")
	t.check(transport.motion_changed({"x":1,"vx":120},{"x":1,"vx":0}),"Stopping movement always sends the terminal velocity state")
	t.check(transport.motion_changed({"punch":0},{"punch":0.18}),"Stationary punches still produce a new network sample")
	var hud=load("res://src/ui/hud.gd").new()
	t.root.add_child(hud)
	for extent in [Vector2(1280,720),Vector2(1560,720),Vector2(568,320),Vector2(390,844)]:
		hud.size=extent
		hud.layout()
		await t.process_frame
		await t.process_frame
		t.check(hud.bar.get_rect().end.y<=hud.size.y,"Hotbar actual container height stays inside the viewport at "+str(extent))
	hud.queue_free()
	avatar.queue_free()
