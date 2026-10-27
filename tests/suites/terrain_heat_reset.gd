extends RefCounted
func run(t) -> void:
	var world=load("res://src/game/world_state.gd").new();world.create_default("HEATQA")
	var terrain=load("res://src/game/terrain_renderer.gd").new()
	var tile:=Vector2i(10,10)
	world.set_tile(tile,1);world.set_tile(tile+Vector2i.UP,0)
	var grass=terrain.variant(world,tile,1,false)
	for id in [3,2,7,200010,200008,200004]:
		world.set_tile(tile+Vector2i.UP,id)
		t.check(terrain.variant(world,tile,1,false)==grass,"Dirt under unlike material retains the source grass edge: "+str(id))
	world.set_tile(tile+Vector2i.UP,200002)
	t.check(terrain.variant(world,tile,1,false)!=grass,"Identical dirt joins across placement encodings")
	var p=load("res://src/game/player_state.gd").new();p.position=Vector2(9*32+16,11*32)
	var actions=load("res://src/game/interactions.gd").new()
	world.set_tile(tile,1)
	actions.apply(world,p,"punch",tile,0)
	t.check(world.damage.has(tile),"First hit cracks the block")
	if not world.has_method("tick_damage"):t.check(false,"Cracks have a world-owned reset timer");return
	world.tick_damage(4.5)
	t.check(world.damage.has(tile),"Crack remains before its timeout")
	actions.cooldown=0;actions.apply(world,p,"punch",tile,0)
	world.tick_damage(1)
	t.check(world.damage.has(tile),"A fresh punch refreshes the crack timeout")
	world.tick_damage(4.1)
	t.check(not world.damage.has(tile) and not world.damage_required.has(tile),"Timeout clears both damage and crack stage")
	actions.cooldown=0;actions.apply(world,p,"punch",tile,0)
	t.check(world.damage.get(tile,0)==1,"Punching after timeout starts from the first damage stage")
	var sim=load("res://src/game/simulation.gd").new()
	for lava in [7,200004,100004]:
		world.set_tile(Vector2i(15,10),lava)
		p.position=Vector2(15*32+16,10*32+24);p.velocity=Vector2.ZERO;p.god_mode=false;p.death_time=-1;p.respawn_invulnerability=0
		var events=sim.step(world,p,{"axis":0},1.0/60)
		t.check(p.death_time==0,"Lava immediately enters the source death sequence: "+str(lava))
		t.check(p.position.distance_to(world.spawn_position())>32,"Death remains at the contact point before respawn")
		t.check(events.any(func(e):return e.type=="death_sound" and e.sound=="male_scream"),"Lava starts the original scream recording")
		for i in 125:sim.step(world,p,{"axis":0},1.0/60)
		t.check(p.position.distance_to(world.spawn_position())<2,"Death returns to the white door after the source delay")
		p.death_time=-1;p.god_mode=true;p.position=Vector2(15*32+16,10*32+24)
		sim.step(world,p,{"axis":0},1.0/60)
		t.check(p.death_time<0,"God mode remains immune to lava")
	var anc=load("res://src/game/ancestral_particles.gd").new()
	var records=JSON.parse_string(FileAccess.get_file_as_string("res://research/web-wardrobe/archive/l.json"))
	var count:=0
	for record in records.items:
		if not anc.supported(record):continue
		count+=1;p.catalog_equipment={"artifact":int(record.id)}
		anc.particles.clear();anc.clocks.clear()
		for i in 40:anc.update(p,1.0/60)
		t.check(not anc.particles.is_empty(),"Ancestral source program emits: "+record.name)
		for particle in anc.particles:
			var g=anc.geometry(particle)
			t.check(g.scale.is_finite() and g.color.a>=0 and g.color.a<=1,"Source ancestral geometry remains finite")
		t.check(anc.particles.size()<=anc.LIMIT,"Ancestral emitter is bounded")
	t.check(count==30,"All thirty captured ancestral variants are exercised")
