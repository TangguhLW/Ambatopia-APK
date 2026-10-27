extends RefCounted

func run(t):
	var p=load("res://src/game/player_state.gd").new()
	var avatar=load("res://src/game/avatar_view.gd").new();avatar.player=p
	p.grounded=false;p.velocity=Vector2(0,-100)
	t.check(avatar.face_frame()==1,"Rising uses the source jump eye cell")
	p.velocity.y=100
	t.check(avatar.face_frame()==2,"Falling uses the source falling eye cell")
	p.grounded=true;p.velocity=Vector2(150,0)
	var peak: float=-100
	for i in 90:
		avatar.advance_limbs(1.0/60);peak=maxf(peak,maxf(avatar.foot1,avatar.foot2))
	t.check(peak<=0,"Walking feet remain in the source minus-two-to-zero range")
	avatar.walk_phase=0
	for i in 30:avatar.advance_limbs(1.0/60)
	t.check(is_equal_approx(avatar.foot1,-1.75) and is_equal_approx(avatar.foot2,-0.25),"Walking cadence follows source horizontal distance divided by twenty")
	t.check(Color(p.SKINS[0]).is_equal_approx(Color("c39582")),"Default skin matches the simulator palette entry three")
	if avatar.has_method("eyelid_region"):
		t.check(avatar.eyelid_region(0)==Rect2(0,128,32,32),"The untampered local upper-lid row is part of the face composition")
	else:t.check(false,"Source upper-lid overlay exists")
	avatar.free()
	var path="res://src/game/material_audio.gd"
	if not ResourceLoader.exists(path):t.check(false,"Material hit and break sound resolver exists");return
	var sound=load(path)
	t.check(sound.pair(200056)==["glass_hit","punch_glass"],"Glass uses original glass hit and shatter recordings")
	for id in [1,200002,100002,200016,100016]:
		t.check(sound.pair(id)==["wood_damage","wood_break"],"Dirt/grass use the simulator's wood_damage impact and wood_break destruction: "+str(id))
	t.check(sound.pair(3)==["rock_hit","rock_destroy"],"Rock uses the original stone recordings")
	t.check(sound.pair(200060)==["metal_hit","metal_destroy"],"Metal uses its own hit and destruction recordings")
	t.check(sound.material(3)==2,"Legacy rock resolves native material two")
	var sim=load("res://src/game/simulator_catalog.gd")
	var metal_id: int=0
	for id in sim.items():
		if int(sim.items()[id][11])==3:metal_id=200000+int(id);break
	t.check(metal_id>0 and sound.pair(metal_id)[0]=="metal_hit","Material three uses the original metallic impact")
