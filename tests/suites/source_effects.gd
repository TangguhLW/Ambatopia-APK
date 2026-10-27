extends RefCounted
func run(t) -> void:
	var P=load("res://src/game/player_state.gd")
	var Ray=load("res://src/game/rayman_controller.gd")
	var p=P.new();p.catalog_equipment={"hand":5480};p.position=Vector2(9*32+16,10*32+32);p.grounded=true
	var ray=Ray.new()
	for i in 70:
		var state=ray.sample(p,{"action":"punch","target":Vector2i(10,10)},1.0/60)
		t.check(state.action=="none","Rayman hold charges rather than repeat breaking")
	t.check(p.rayman_level==2,"Rayman reaches level two after one second")
	var release=ray.sample(p,{"action":"none","target":Vector2i.ZERO},1.0/60)
	t.check(release.action=="punch" and release.target==Vector2i(10,10) and p.rayman_fire>0,"Rayman release preserves aim and triggers fire")
	var world=load("res://src/game/world_state.gd").new();world.create_default("SOURCEQA")
	for x in [10,11,12]:world.set_tile(Vector2i(x,10),1)
	var actions=load("res://src/game/interactions.gd").new()
	var result=actions.apply(world,p,"punch",Vector2i(10,10),0,func(tile):return tile!=Vector2i(12,10))
	t.check(result.accepted and world.damage.has(Vector2i(10,10)) and world.damage.has(Vector2i(11,10)),"Charged Rayman damages collinear tiles")
	t.check(not world.damage.has(Vector2i(12,10)),"Rayman checks permission on every extra tile")
	t.check(float(world.damage[Vector2i(10,10)])==2,"Charged Rayman doubles damage")
	for x in [10,11,12]:world.set_tile(Vector2i(x,10),1)
	actions.cooldown=0
	result=actions.apply(world,p,"punch",Vector2i(10,10),0,func(_tile):return true)
	t.check(world.damage.has(Vector2i(12,10)),"Unrestricted charged Rayman reaches the third tile")
	world.damage.clear();p.rayman_level=0;actions.cooldown=0
	actions.apply(world,p,"punch",Vector2i(10,10),0)
	t.check(world.damage.size()==1,"Uncharged Rayman hits one tile")
	var tracks=load("res://src/game/source_item_tracks.gd")
	t.check(not tracks.pet_for(p).is_empty(),"Rayman uses the captured Globox pet track")
	p.item_options.pet_5480=false
	t.check(tracks.pet_for(p).is_empty(),"Globox can be hidden without unequipping Rayman")
	t.check(not tracks.punch_for(p).is_empty(),"Rayman selects the captured punch profile")
	var renderer=load("res://src/game/terrain_renderer.gd").new()
	t.check(renderer.source(102590)==2590 and renderer.animated(202590),"Both placement encodings resolve Shifty rainbow material")
	t.check(not renderer.rainbow(0,Vector2i.ZERO).is_equal_approx(renderer.rainbow(1,Vector2i.ZERO)),"Rainbow material changes over time")
	world.set_tile(Vector2i(10,10),1);world.set_tile(Vector2i(10,9),2)
	var covered=renderer.variant(world,Vector2i(10,10),1,false)
	world.set_tile(Vector2i(10,9),1)
	t.check(renderer.variant(world,Vector2i(10,10),1,false)!=covered,"Different materials keep their own source edges")
	var VM=load("res://src/game/source_particle_program.gd")
	for key in VM.programs():
		var program: Dictionary=VM.programs()[key]
		if program.has("factory"):continue
		var particle={"x":0.0,"y":0.0,"vx":0.0,"vy":0.0,"s":1.0,"sx":1.0,"sy":1.0,"rot":0.0,"al":1.0,"life":2.0,"an":0.0,"sp":0.0}
		VM.run(program.init,particle,0)
		for i in 60:
			particle.life-=1.0/60
			VM.run(program.up,particle,1.0/60)
			var frame=VM.run(program.cell,particle,0).get("value",[])
			t.check(frame is Array and frame.size()==2,"Compiled particle "+key+" supplies a sprite cell")
			for field in ["x","y","vx","vy","s","sx","sy","rot","al","life"]:
				t.check(is_finite(float(particle[field])),"Particle program "+key+" remains finite: "+field)
	var emitter=load("res://src/game/source_legacy_particles.gd").new()
	p.catalog_equipment={"hair":1444}
	for i in 30:emitter.update(p,1.0/60)
	t.check(not emitter.particles.is_empty() and emitter.particles[0].item==1444,"Frosty Hair emits its source snowflake program")
	t.check(emitter.particles.size()<=emitter.LIMIT,"Source emitter keeps a bounded particle budget")
	var Assets=load("res://src/game/source_effect_assets.gd")
	for sheet in ["particles","fisticuffs","blogox"]:t.check(Assets.texture(sheet)!=null,"Local effect sheet decodes: "+sheet)
