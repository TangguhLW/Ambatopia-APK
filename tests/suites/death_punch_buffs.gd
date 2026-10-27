extends RefCounted
func run(t) -> void:
	var P=load("res://src/game/player_state.gd")
	var sim=load("res://src/game/simulation.gd").new()
	var world=load("res://src/game/world_state.gd").new();world.create_default("DIEQA")
	var p=P.new();p.position=Vector2(15*32+16,10*32+24)
	world.set_tile(Vector2i(15,10),7)
	sim.step(world,p,{},1.0/60)
	var start: Vector2=p.position
	for i in 60:sim.step(world,p,{"axis":1,"jump_pressed":true},1.0/60)
	t.check(p.position==start and p.punch_time==0,"Dead controls cannot move, jump or punch")
	var death=load("res://src/game/death_sequence.gd").new()
	death.update(p,0.5)
	t.check(not death.particles.is_empty(),"Source angel sprites appear at the death location")
	t.check(is_equal_approx(float(p.death_profile.B.d),2.496) and int(p.death_profile.skin[0])==200 and int(p.death_profile.skin[1])==240 and int(p.death_profile.skin[2])==220,"Death body curve and mint tint come from the captured source")
	t.check(death.visual(p).face==5,"Death selects the original face expression")
	var sound:=false
	for i in 65:
		for event in sim.step(world,p,{},1.0/60):
			if event.type=="death_sound" and event.sound=="teleport":sound=true
	t.check(sound and p.position.distance_to(world.spawn_position())<2,"Teleport recording accompanies white-door respawn")
	var acts=load("res://src/game/interactions.gd").new()
	p.death_time=0
	t.check(not acts.apply(world,p,"punch",Vector2i(51,23),0).accepted,"Gameplay mutations are blocked while dead")
	for id in death.source().items:
		var equipped=P.new();equipped.catalog_equipment={"hand":int(id)}
		equipped.begin_death()
		var effect=load("res://src/game/death_sequence.gd").new()
		for frame in 180:
			equipped.death_time=float(frame)/60
			effect.update(equipped,1.0/60)
			t.check(is_finite(float(death.visual(equipped).scale)),"Captured item death variants retain finite body curves")
		for particle in effect.particles:
			t.check(particle.image!=null and float(particle.track.L)>0,"Item death emitters resolve a valid source texture and lifetime")
	var tracks=load("res://src/game/source_item_tracks.gd")
	tracks.load_data()
	var far_count:=0
	for profile in tracks.punches.punches.values():
		for raw in profile.get("P",[]):
			if not raw.has("at80"):continue
			var far=tracks.resolved_particle(raw,true);far_count+=1
			t.check(far.at==raw.at80,"Long-target punch uses source alternate anchor")
			for key in ["x","y","sx","sy","r","a"]:t.check(is_finite(tracks.curve(far.cv,key,0.5,1)),"Merged long-target curves remain finite")
	t.check(far_count>100,"Alternate source punch variants are exercised across the archive")
	p=P.new();p.grounded=true;p.position=Vector2(10*32+16,11*32);p.velocity.x=150
	world.set_tile(Vector2i(10,11),200440)
	sim.step(world,p,{"axis":0},1.0/60)
	t.check(p.velocity.x>0,"Ice retains momentum without the anti-slip item")
	p.catalog_equipment={"feet":5418};p.grounded=true;p.velocity.x=150
	sim.step(world,p,{"axis":0},1.0/60)
	t.check(p.velocity.x==0,"Source Ice Skates of Winter disables ice sliding")
	p.catalog_equipment={"hand":1668};p.position=Vector2(20*32+16,10*32+24);p.velocity.y=400
	world.extras[str(10*world.size.x+20)]={"water":true}
	sim.step(world,p,{"axis":0,"jump_held":false},1.0/60)
	t.check(p.velocity.y<=40,"Source floatie limits sinking to forty pixels per second")
	sim.step(world,p,{"axis":0,"jump_held":true},1.0/60)
	t.check(p.velocity.y==-320,"Floatie jump input pulls upward using the source value")
	p.catalog_equipment={};t.check(not p.abilities().floaties,"Removing a floatie removes its gameplay effect")
	p=P.new();p.position=Vector2(25*32+22,11*32);p.catalog_equipment={"feet":3588}
	world.set_tile(Vector2i(26,10),1)
	sim.step(world,p,{"axis":1},1.0/60)
	t.check(p.grounded and p.velocity.y==0,"Source climbing equipment latches onto a pushed wall")
	p.catalog_equipment={};p.grounded=false
	sim.step(world,p,{"axis":1},1.0/60)
	t.check(not p.grounded and p.velocity.y>0,"Removing climbing equipment releases the wall")
	var jumps: Array=[]
	for equipped in [false,true]:
		p=P.new();p.position=Vector2(30*32+16,11*32);p.grounded=true
		if equipped:p.catalog_equipment={"feet":5420}
		world.set_tile(Vector2i(30,11),205396)
		sim.step(world,p,{"axis":0,"jump_pressed":true},1.0/60)
		jumps.append(p.velocity.y)
	t.check(absf(jumps[1])>absf(jumps[0])*1.3,"Source snowshoes prevents the weak-jump penalty on snow")
