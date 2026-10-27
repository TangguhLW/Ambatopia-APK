extends RefCounted
func run(t) -> void:
	var VM=load("res://src/game/source_particle_program.gd")
	var E=load("res://src/game/source_legacy_particles.gd")
	var P=load("res://src/game/player_state.gd")
	var W=load("res://src/game/web_wardrobe.gd")
	for entry in [[2048,112,2],[2064,113,3]]:
		var p=P.new();p.grounded=true;p.catalog_equipment={"feet":entry[0]};p.velocity=Vector2(90,0)
		var emitter=E.new();emitter.update(p,0.1)
		t.check(emitter.particles.size()==1,"Each comet emits one original trail particle per source tick")
		if emitter.particles.is_empty():continue
		var particle: Dictionary=emitter.particles[0]
		var cell: Array=VM.run(particle.program.cell,particle,0).value
		t.check(int(particle.id)==entry[1] and int(cell[0])==entry[2] and int(cell[1])==6,"Comet and Meteor select separate original atlas cells")
		t.check(is_equal_approx(particle.vx,-30) and absf(particle.vy)<0.001 and particle.life==1 and particle.s==2,"Ride trail retains its source initial velocity, lifetime and size")
		var rotation: float=particle.rot;emitter.update(p,0.01)
		t.check(absf(wrapf(float(particle.rot)-rotation+7.2,-180,180))<0.01,"Ride spark rotates at the original minus-720 degrees per second")
		t.check(particle.s>=0.01 and particle.s<=2*particle.life,"Ride spark flickers inside its original shrinking size range")
		p.wrench_selected=true
		var count: int=emitter.particles.size();emitter.update(p,0.2)
		t.check(emitter.particles.size()<=count,"Selecting wrench suppresses Comet/Meteor trail emission as in source")
	for entry in [[36,10,35],[232,5,233]]:
		var factory: Dictionary=VM.programs()[str(entry[0])].factory
		t.check(int(factory.count)==entry[1] and int(factory.target)==entry[2],"Neptune factory preserves the original child count and program")
	var p=P.new();p.catalog_equipment={"feet":11012};p.grounded=false;p.velocity=Vector2(0,50)
	var emitter=E.new();emitter.update(p,1.0/60)
	t.check(emitter.particles.is_empty(),"Neptune landing burst does not appear before contact with ground")
	p.grounded=true;p.velocity=Vector2.ZERO;emitter.update(p,1.0/60)
	t.check(emitter.particles.size()==10,"Neptune landing makes exactly ten source droplets")
	for particle in emitter.particles:
		t.check(particle.id==35 and absf(particle.x)<=8 and particle.y>=-16 and particle.y<=0,"Neptune landing droplets retain source program and eight-pixel jitter")
		t.check(is_equal_approx(Vector2(particle.vx,particle.vy).length(),60),"Neptune landing uses the original child speed")
	var before: int=emitter.particles.size();emitter.update(p,1.0/60)
	t.check(emitter.particles.size()==before,"Standing still cannot repeat the landing burst")
	emitter=E.new();p.grounded=false;p.velocity=Vector2(0,80);emitter.update(p,0.016)
	p.grounded=true;p.velocity=Vector2.ZERO;emitter.update(p,0.016)
	t.check(emitter.particles.size()==10,"Sub-sixty-Hz frame intervals cannot suppress a one-frame landing trigger")
	emitter=E.new();p.grounded=true;p.velocity=Vector2(90,0)
	for frame in 7:emitter.update(p,1.0/60)
	t.check(emitter.particles.size()==5,"Walking Neptune makes five droplets at the original tenth-second tick")
	for particle in emitter.particles:
		VM.run(particle.program.cell,particle,0)
		t.check(particle.id==233 and particle.rgb==[137.0/255,208.0/255,1.0],"Neptune trail retains its source RGB rather than a generic particle tint")
	for frame in 180:emitter.update(p,1.0/60)
	t.check(emitter.particles.size()<=emitter.LIMIT,"Repeated Neptune factories remain within the render budget")
	p.catalog_equipment={}
	for frame in 180:emitter.update(p,1.0/60)
	t.check(emitter.particles.is_empty(),"Removing a ride stops emission and lets existing particles expire")
	var animation=W.new();p=P.new();p.grounded=true
	var chaos: Dictionary=W.definition(8488)
	t.check(chaos.st.stand[3].size()==8,"Chaos has eight captured glitch frames")
	for frame in 8:t.check(W.frame_index(chaos,frame*200)==frame,"Chaos source holds each glitch cell for two hundred milliseconds")
	p.velocity=Vector2(90,0);animation.update(p,0.01)
	var timing: Dictionary=animation.animation_timing(chaos,0.85)
	t.check(timing.pose=="stand" and timing.age==850 and W.frame_index(chaos,timing.age,timing.pose)==4,"Walking does not reset Chaos's continuous source animation")
	p.grounded=false;p.velocity.y=-100;animation.update(p,0.01)
	timing=animation.animation_timing(chaos,1.25)
	t.check(timing.age==1250 and W.frame_index(chaos,timing.age,timing.pose)==6,"Jumping does not reset Chaos's continuous source animation")
	t.check(not VM.programs().has("302"),"An absent simulator program is not replaced with a generic Chaos emitter")
	p.grounded=true;p.velocity=Vector2.ZERO;animation.update(p,0.01)
	for id in [2048,2064]:
		var ride: Dictionary=W.definition(id)
		timing=animation.animation_timing(ride,3)
		t.check(timing.pose=="land" and W.frame_index(ride,0,"land")==55,"Ride landing plays its captured landing sequence")
	animation.update(p,0.3)
	t.check(animation.animation_timing(W.definition(2048),3.3).pose=="stand","Ride exits landing sequence at the source duration")
