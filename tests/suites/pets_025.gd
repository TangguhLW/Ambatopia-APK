extends RefCounted
func run(t) -> void:
	var P=load("res://src/game/player_state.gd")
	var M=load("res://src/game/source_pet_motion.gd")
	var T=load("res://src/game/source_item_tracks.gd")
	var Aim=load("res://src/game/source_punch_aim.gd")
	T.load_data()
	var fixtures=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/pet-source-fixtures.json"))
	for entry in fixtures.fixtures:
		var profile: Dictionary=T.punches.punches[entry.id]
		var actual: Dictionary=Aim.resolve(profile.P[int(entry.index)],Vector2(entry.target[0],entry.target[1]),profile.get("aim",{}).get("R",{}),Vector2(entry.delta[0],entry.delta[1]))
		t.check(not actual.is_empty(),"Dynamic pet anchor resolves the source-confirmed punch")
		if actual.is_empty():continue
		t.check(Vector2(actual.at[0],actual.at[1]).distance_to(Vector2(entry.result.at[0],entry.result.at[1]))<0.025,"Moving-pet punch origin matches the original JavaScript")
		for key in entry.result.cv:
			var valid: bool=actual.cv.get(key,[]).size()==entry.result.cv[key].size()
			for i in mini(actual.cv.get(key,[]).size(),entry.result.cv[key].size()):
				if absf(float(actual.cv[key][i])-float(entry.result.cv[key][i]))>0.025:valid=false
			t.check(valid,"Moving-pet punch curve matches source: "+key)
	for entry in fixtures.flying:
		var p=P.new();p.position=Vector2.ZERO;p.velocity=Vector2.ZERO
		var motion=M.new();motion.midpoint_random=true
		motion.position=Vector2(entry.start[0],entry.start[1]);motion.velocity=Vector2(entry.start[2],entry.start[3]);motion.fly(p,1.0/60)
		t.check(motion.position.distance_to(Vector2(entry.result.x,entry.result.y))<0.0001,"Flying pet position matches the isolated original source helper")
		t.check(motion.velocity.distance_to(Vector2(entry.result.vx,entry.result.vy))<0.0001,"Flying pet acceleration and idle damping match source")
	for facing in [-1,1]:
		var p=P.new();p.position=Vector2(400,200);p.grounded=true;p.facing=facing
		var motion=M.new();motion.update(870,T.pets.items["870"],p,1.0/60)
		t.check(motion.position==p.position-Vector2(16*facing,0),"Pet spawns at the source sixteen-pixel ground anchor, facing independently")
		p.position.x+=60*facing;p.velocity=Vector2(180*facing,0)
		for i in 18:motion.update(870,T.pets.items["870"],p,1.0/60)
		t.check(motion.position==Vector2(400-16*facing,200) and motion.state=="i","Ground pet retains the original twenty-sample delayed idle state")
		for i in 30:motion.update(870,T.pets.items["870"],p,1.0/60)
		t.check(motion.position.distance_to(p.position-Vector2(16*facing,0))<0.01 and motion.state=="w","Ground pet catches up at source speed and switches to walking")
		p.grounded=false;p.velocity.y=-200;p.position.y-=40
		for i in 22:motion.update(870,T.pets.items["870"],p,1.0/60)
		t.check(motion.state=="u" and motion.position.y<200,"Pet uses delayed jump frames and height instead of sticking to the player's feet")
		p.punch_time=0.2;motion.update(870,T.pets.items["870"],p,1.0/60)
		t.check(motion.state=="p","Source pet punch state interrupts locomotion")
		p.position+=Vector2(1000,0);motion.update(870,T.pets.items["870"],p,1.0/60)
		t.check(motion.position.distance_to(p.position)<80 and motion.history.size()==20,"World/spawn teleport resets cosmetic history rather than sweeping through the world")
		motion.update(0,{},p,1.0/60);t.check(motion.active_id==0 and motion.history.is_empty(),"Unequip/toggle removes pet and clears its motion history")
	for id in T.pets.items:
		var pet: Dictionary=T.pets.items[id]
		t.check(pet.k in M.PORTED,"Every captured pet has a specific source motion branch: "+id)
		var p=P.new();p.position=Vector2(100,100);p.grounded=true
		var motion=M.new();motion.midpoint_random=true
		for frame in 140:
			p.velocity=Vector2(90,0) if frame<70 else Vector2.ZERO
			p.position+=p.velocity/60;p.facing=1 if frame<90 else -1
			motion.update(int(id),pet,p,1.0/60)
			t.check(motion.position.is_finite() and motion.velocity.is_finite() and is_finite(motion.angle),"Source pet motion remains finite across locomotion and reversal: "+id)
			t.check(motion.history.size()==20,"Pet trail remains bounded: "+id)
	var player=P.new();player.position=Vector2(100,100);player.grounded=true;player.catalog_equipment={"hand":5480}
	var tracks=T.new();tracks.update(player,1.0/60);tracks.pet_motion.position+=Vector2(-24,12)
	t.check(tracks.anchor_delta({"an":"mid","af":0.75},player).is_equal_approx(tracks.anchor_delta({"an":"pet"},player)*0.25),"Source midpoint anchor blends toward pet by one minus af")
	player.item_options["pet_5480"]=false;tracks.update(player,1.0/60)
	t.check(tracks.pet_motion.active_id==0,"Rayman pet toggle clears its active effect anchor")
	var ball=M.new();player.catalog_equipment={};player.punch_direction=Vector2.RIGHT;player.punch_distance=64
	player.punch_time=0.32;ball.update(2878,T.pets.items["2878"],player,1.0/60)
	t.check(ball.position.distance_to(player.position)<0.001,"Pet ball starts its strike at the player, using elapsed punch time rather than the native countdown")
	for frame in 15:
		player.punch_time-=1.0/60;ball.update(2878,T.pets.items["2878"],player,1.0/60)
	t.check(ball.position.distance_to(player.position+Vector2(64,0))<0.01,"Pet ball reaches the source target after a quarter-second strike")
