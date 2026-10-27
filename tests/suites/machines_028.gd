extends RefCounted
const World=preload("res://src/game/world_state.gd")
const Player=preload("res://src/game/player_state.gd")
const Rules=preload("res://src/game/source_machine_rules.gd")
const Blasts=preload("res://src/game/source_blasts.gd")
func run(t) -> void:
	var r=preload("res://src/game/item_runtime.gd").new()
	var w=World.new();w.create_default("MACHINEQA")
	var p=Player.new();p.actor_key="owner";p.position=Vector2(48*32+16,24*32)
	var tile:=Vector2i(49,23)
	for id in [4992,226,1276,1278,4884]:
		w.set_tile(tile,200000+id);w.extras.clear()
		t.check(r.interact(w,p,tile,"activate",{}).accepted,"Switch accepts owner punch/activate: "+str(id))
		if id==4884:
			r.state(w,tile).switch_at=0;Rules.tick(r,w)
		var flag: String="antigravity" if id==4992 else str(Rules.JAMMERS[id])
		t.check(Rules.flags(w)[flag],"Machine enables actual world service: "+flag)
		t.check(r.interact(w,p,tile,"configure",{"silent":true}).accepted,"Machine supports silent mode")
		t.check(Rules.flags(w).active[0].silent,"Silent flag invalidates world-service cache")
		r.interact(w,p,tile,"activate",{})
		if id==4884:
			r.state(w,tile).switch_at=0;Rules.tick(r,w)
		t.check(not Rules.flags(w)[flag],"Second activation disables service: "+flag)
	w.set_tile(tile,204992);w.extras.clear();r.interact(w,p,tile,"activate",{})
	var sim=preload("res://src/game/simulation.gd").new()
	p.position=Vector2(30*32+16,10*32);p.velocity=Vector2.ZERO
	sim.step(w,p,{},1.0/60)
	t.check(is_equal_approx(p.velocity.y,1100.0*0.375/60),"Antigravity uses recovered 0.375 multiplier")
	t.check(p.modifiers.has("Antigravity"),"Active generator exposes Antigravity modifier")
	r.interact(w,p,tile,"activate",{}) # Out of reach must fail.
	t.check(Rules.flags(w).antigravity,"Remote machine interaction fails without modifying state")
	p.position=Vector2(48*32+16,24*32);r.interact(w,p,tile,"activate",{})
	p.position=Vector2(30*32+16,10*32);p.velocity=Vector2.ZERO;sim.step(w,p,{},1.0/60)
	t.check(not p.modifiers.has("Antigravity") and is_equal_approx(p.velocity.y,1100.0/60),"Switch-off restores ordinary gravity and removes world mod")
	p.position=Vector2(48*32+16,24*32)
	w.set_tile(tile,200934);w.extras.clear();w.weather="sunny"
	r.interact(w,p,tile,"activate",{})
	t.check(w.weather=="night","Weather machine changes actual weather")
	r.interact(w,p,tile,"activate",{})
	t.check(w.weather=="sunny","Weather switch restores base sky")
	var renderer=preload("res://src/game/terrain_renderer.gd").new()
	w.set_tile(tile,204992);w.extras.clear()
	var off=renderer.texture(w,tile,204992).region
	r.interact(w,p,tile,"activate",{})
	var on=renderer.texture(w,tile,204992).region
	t.check(on.position==off.position+Vector2(64,0),"Active switch uses original atlas +2 frame")
	t.check(fmod(on.position.x,32)==0 and fmod(on.position.y,32)==0,"Machine frame remains aligned to pixel atlas")
	w.drops.clear();r.source_drops.random_stream=[0.999]
	var drops: Array=r.source_drops.provider(r,1008)
	r.source_drops.grant(r,w,tile,int(drops[0][0]),int(drops[0][1]))
	t.check(w.drops.size()==2 and int(w.drops[0].amount)+int(w.drops[1].amount)==250,"ATM preserves maximum 250 gems across legal drop stacks")
	for id in [120,542,3604,7628,2478]:
		w.drops.clear();r.source_drops.random_stream=[0.5,0.5,0.5,0.5,0.5]
		var events: Array=r.source_drops.broken(r,w,tile,id)
		t.check(not events.is_empty() and not w.drops.is_empty(),"Break reward comes from recovered treasure pool: "+str(id))
	Blasts.load_data()
	for id in Blasts.data.templates:
		for variant in 4:
			w.create_default("BLASTQA");p.developer=true
			var result: Dictionary=Blasts.apply(r,w,p,tile,int(id),variant)
			t.check(result.accepted,"Recovered blast creates valid portable world: %s/%d"%[id,variant])
			if result.accepted:
				t.check(w.main_door==Vector2i(Blasts.data.templates[id][variant].spawn[0],Blasts.data.templates[id][variant].spawn[1]),"Blast preserves source spawn")
				t.check(w.drops.size()==Blasts.data.templates[id][variant].obj.size(),"Blast preserves original loose item drops")
	for id in Blasts.data.unavailable:
		if Blasts.available(int(id)):continue
		var before:=w.serialize()
		t.check(not Blasts.apply(r,w,p,tile,int(id)).accepted and w.serialize()==before,"Missing generator preserves existing world: "+id)
	w.create_default("WEATHERQA");p.developer=false;p.position=Vector2(48*32+16,24*32)
	w.set_tile(tile,205958)
	r.interact(w,p,tile,"configure",{"phases":[true,true,true]})
	r.interact(w,p,tile,"activate",{})
	t.check(w.weather=="iceage","Epoch uses first enabled historical phase")
	w.extras["2349"].next_cycle=0;Rules.tick(r,w)
	t.check(w.weather=="volcano","Epoch advances by source cycle order")
	w.extras["2349"].next_cycle=0;Rules.tick(r,w)
	t.check(w.weather=="floating","Epoch has original Floating Islands third phase")
	Rules.removed(w,5958,tile)
	t.check(w.weather=="sunny","Breaking a cycling weather machine restores base sky")
	w.set_tile(tile,210058);w.extras.clear()
	t.check(r.interact(w,p,tile,"configure",{"slots":[934,946,0]}).accepted,"Infinity accepts independent weather machine slots")
	r.interact(w,p,tile,"activate",{})
	t.check(w.weather=="night","Infinity starts first non-empty slot")
	w.extras["2349"].next_cycle=0;Rules.tick(r,w)
	t.check(w.weather=="arid","Infinity cycles to second configured weather")
	for id in r.Sim.use_rules.weather:
		w.create_default("WEATHERQA");w.set_tile(tile,200000+int(id));p.position=Vector2(48*32+16,24*32)
		var result: Dictionary=r.interact(w,p,tile,"activate",{})
		var supported: bool=int(id)!=6280 and (int(id) in [5958,10058] or Rules.renderable(Blasts.weather_key(int(r.Sim.use_rules.weather[id].w))))
		t.check(result.accepted if supported else not result.accepted and w.weather=="sunny","Weather switches use verified renderer or explicitly preserve sky: "+id)
	var core=preload("res://src/network/room_server.gd").new()
	core.join(1,"A","JAMMER");core.join(2,"B","JAMMER")
	var room: Dictionary=core.rooms.JAMMER
	room.world.set_tile(Vector2i(10,10),201276)
	room.world.extras["1010"]={"enabled":true};room.world.mark_visual(Vector2i(10,10))
	core.players[1].state.position=Vector2(48*32+16,24*32)
	core.players[2].state.position=Vector2(49*32+16,24*32)
	core.accept(1,{"type":"input","seq":1,"axis":0,"action":"punch","x":49,"y":23})
	core.step(1.0/60)
	t.check(core.players[2].state.knockback==Vector2.ZERO,"Punch Jammer prevents server-side player knockback")
	room.world.extras["1010"].enabled=false;room.world.mark_visual(Vector2i(10,10))
	core.players[1].actions.cooldown=0
	core.accept(1,{"type":"input","seq":2,"axis":0,"action":"punch","x":49,"y":23})
	core.step(1.0/60)
	t.check(core.players[2].state.knockback.length()>0,"Disabling Punch Jammer restores player punch response")
	var audio=preload("res://src/game/machine_audio.gd")
	audio.load_data()
	for path in audio.data.entries:
		t.check(audio.stream(path)!=null,"Portable machine recording decodes: "+path)
