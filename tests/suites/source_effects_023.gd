extends RefCounted
func run(t) -> void:
	var VM=load("res://src/game/source_particle_program.gd")
	var P=load("res://src/game/player_state.gd")
	var Tracks=load("res://src/game/source_item_tracks.gd")
	var Emitter=load("res://src/game/source_legacy_particles.gd")
	var Aim=load("res://src/game/source_punch_aim.gd")
	Tracks.load_data()
	var cases=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/punch-aim-source-fixtures.json"))
	for fixture in cases.fixtures:
		var profile: Dictionary=Tracks.punches.punches[fixture.id]
		var actual: Dictionary=Aim.resolve(profile.P[int(fixture.index)],Vector2(fixture.target[0],fixture.target[1]),profile.get("aim",{}).get("R",{}))
		if actual.is_empty():t.check(false,"Source-confirmed punch retarget must resolve: "+fixture.id+"/"+str(fixture.index));continue
		t.check(Vector2(actual.at[0],actual.at[1]).distance_to(Vector2(fixture.result.at[0],fixture.result.at[1]))<0.02,"Punch anchor agrees with independently executed source: "+fixture.id+"/"+str(fixture.index)+" "+str(fixture.target))
		t.check(absf(float(actual.life)-float(fixture.result.life))<0.001,"Punch lifetime agrees with independently executed source")
		for key in fixture.result.cv:
			var expected: Array=fixture.result.cv[key];var got: Array=actual.cv.get(key,[])
			var matches: bool=got.size()==expected.size()
			for i in mini(got.size(),expected.size()):
				if absf(float(got[i])-float(expected[i]))>0.025:matches=false;break
			t.check(matches,"Punch curve agrees with source: "+fixture.id+"/"+str(fixture.index)+" "+key+" "+str(fixture.target))
	var missing=[70,91,95,117,126,130,152,233,236,238,253,256,257,294,365,382]
	for fixture in cases.rejected:
		var profile: Dictionary=Tracks.punches.punches[fixture.id]
		t.check(Aim.resolve(profile.P[int(fixture.index)],Vector2(fixture.target[0],fixture.target[1]),profile.get("aim",{}).get("R",{})).is_empty(),"Native retarget declines the same case as source: "+fixture.id+"/"+str(fixture.index))
	for id in missing:t.check(VM.programs().has(str(id)),"Previously unsupported source program is executable: "+str(id))
	var state={"id":130,"an":90,"sp":10,"x":0,"y":0,"owner":{}}
	VM.run(VM.programs()["130"].init,state,0)
	t.check(absf(state.vx)<0.001 and is_equal_approx(state.vy,-40),"Ride O Gold uses source polar velocity and upward impulse")
	VM.run(VM.programs()["130"].up,state,0.1)
	t.check(is_equal_approx(state.vy,-20) and is_equal_approx(state.s,0.275),"Ride O Gold uses its own gravity and shrinking curve")
	state={"id":126,"an":0,"sp":0,"x":0,"y":0,"owner":{"x":40,"y":70,"bx":2,"by":3,"face":-1,"vx":0,"vy":0}}
	VM.run(VM.programs()["126"].init,state,0)
	VM.run(VM.programs()["126"].up,state,0.1)
	t.check(state.x==38 and state.y==58 and is_equal_approx(state.al,0.225),"MightyBOOSH follows the source owner anchor and fade")
	state={"id":233,"an":0,"sp":0,"x":0,"y":0,"lc":[255,128,0]}
	VM.run(VM.programs()["233"].init,state,0);VM.run(VM.programs()["233"].cell,state,0)
	t.check(state.rgb==[1.0,128.0/255,0.0],"Colored source projectile normalizes its own supplied RGB channels")
	state={"id":236,"an":0,"sp":2,"x":0,"y":0}
	VM.run(VM.programs()["236"].init,state,0);VM.run(VM.programs()["236"].up,state,0.1)
	t.check(state.x==-40 and state.sx==2 and is_equal_approx(state.al,0.4),"Speed Medallion stretches and fades using its source movement scale")
	var items=[1672,1824,1876,4260,2420,2574,3074,4988,4880,4946,6756,6782,8370,9422,9716]
	for id in items:
		var player=P.new();player.catalog_equipment={"hand":id};player.grounded=false;player.velocity=Vector2(90,-100)
		if id==8370:player.grounded=true;player.velocity=Vector2(90,0)
		var emitter=Emitter.new();var peak:=0
		for frame in 120:
			player.position+=player.velocity/60
			emitter.update(player,1.0/60);peak=maxi(peak,emitter.particles.size())
			for particle in emitter.particles:
				var cell=VM.run(particle.program.cell,particle,0).get("value",[])
				var size:=float(particle.program.get("fs",32))
				t.check(cell.size()==2 and Rect2(Vector2.ZERO,particle.image.get_size()).encloses(Rect2(cell[0]*size,cell[1]*size,size,size)),"Worn source effect resolves an atlas cell: "+str(id))
				if particle.id==293:t.check(particle.program==VM.programs()["293"],"Undead Slippers switch to the source projectile program after initialization")
			t.check(emitter.particles.size()<=emitter.LIMIT,"Special emitter respects the render budget")
		t.check(peak>0,"Previously missing worn effect emits through real conditions: "+str(id))
	var player=P.new();player.catalog_equipment={"hand":1782};player.begin_punch(Vector2(50,-16))
	var tracks=Tracks.new();tracks.update(player,0.02)
	t.check(not tracks.repeated.is_empty(),"Focused Eye uses its source repeated particle emitter")
	for frame in 8:tracks.update(player,1.0/60)
	t.check(tracks.punch_particles.size()>8 and tracks.punch_particles.size()<=tracks.PUNCH_LIMIT,"Repeated punch emits multiple particles with a bounded budget")
	var count: int=tracks.punch_particles.size()
	tracks.update(player,10)
	t.check(tracks.punch_particles.is_empty() and count>0,"Repeated punch particles expire independently of the active hand animation")
	player.catalog_equipment={"hand":6026};tracks=Tracks.new();player.punch_time=0;tracks.update(player,0.01);player.begin_punch(Vector2(50,-16));tracks.update(player,0.01)
	t.check(tracks.punch_particles.size()>=10,"Source cone punch produces the recorded ten-particle fan")
	player.catalog_equipment={"hand":4778};tracks=Tracks.new();player.punch_time=0;tracks.update(player,0.01);player.begin_punch(Vector2(50,-16));tracks.update(player,0.01)
	t.check(tracks.punch_particles.any(func(p):return p.track.get("fol",false)),"Follower punch is retained as a separate source particle instance")
	var tint=Tracks.punch_tint({"tint":[255,0,0],"tint2":[0,0,255],"cv":{"a":[0.5]}},0.5,0)
	t.check(tint.is_equal_approx(Color(0.5,0,0.5,0.5)),"Source punch tint interpolates its two recorded colors and opacity")
	var audio=load("res://src/game/material_audio.gd")
	var source_audio=load("res://src/game/source_punch_audio.gd")
	var audio_index=JSON.parse_string(FileAccess.get_file_as_string("res://data/punch-audio-index.json"))
	for name in audio_index:
		if audio_index[name].get("missing",false):continue
		var stream=source_audio.stream(name)
		t.check(stream!=null and stream.get_length()>0,"Captured item punch sound decodes from the portable pack: "+str(name))
	var sim=load("res://src/game/simulator_catalog.gd")
	for key in sim.items():
		var id:=int(key)
		t.check(audio.pair(id+200000)==audio.pair(id+100000),"Every catalog block encoding keeps the same material sound")
	t.check(audio.pair(200002)[0]!=audio.pair(200010)[0] and audio.pair(200010)[0]!=audio.pair(200056)[0] and audio.pair(200056)[0]!=audio.pair(200060)[0],"Dirt, rock, glass and metal have distinct original impact recordings")
