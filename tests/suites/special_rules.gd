extends RefCounted
const World = preload("res://src/game/world_state.gd")
const Player = preload("res://src/game/player_state.gd")
func run(t) -> void:
	if not ResourceLoader.exists("res://src/game/special_items.gd"):
		t.check(false,"Recovered special-item runtime must exist")
		return
	var r=load("res://src/game/item_runtime.gd").new()
	var w=World.new()
	w.create_default("SPECIAL")
	var p=Player.new()
	var tile=Vector2i(49,23)
	p.position=Vector2(48*32+16,24*32)
	w.set_tile(tile,203354)
	r.interact(w,p,tile,"deposit",{"item":3336,"amount":3})
	var sewn=r.interact(w,p,tile,"sew",{})
	t.check(sewn.accepted and w.drops.back().id==7030,"Three red silk bolts sew exact recovered output")
	t.check(r.state(w,tile).stock["3336"]==0,"Sewing consumes all three bolts")
	t.check(not r.interact(w,p,tile,"sew",{}).accepted,"Empty sewing machine cannot mint rewards")
	w.extras.clear()
	r.interact(w,p,tile,"deposit",{"item":3336,"amount":1})
	r.interact(w,p,tile,"deposit",{"item":3340,"amount":2})
	t.check(r.interact(w,p,tile,"sew",{}).accepted and w.drops.back().id==3358,"Mixed silk produces Patchwork Mess rather than random prize")
	w.extras.clear()
	w.set_tile(tile,203316)
	r.planted(w,tile,3316)
	var d=r.state(w,tile)
	d.r=144;d.g=144;d.b=144
	t.check(r.use_item(w,p,tile,386).accepted and d.r==169 and d.g==118,"Silkworm food follows recovered RGB delta")
	r.use_item(w,p,tile,540)
	t.check(r.special.silk_status(d,r.now()).sick>0,"Specified spoiled food makes Silkworm sick")
	r.use_item(w,p,tile,782)
	t.check(r.special.silk_status(d,r.now()).sick==0,"Antidote clears disease")
	d.born=r.now()-172801;d.fu=300000;d.wu=300000;d.hv=86400
	var silk=r.interact(w,p,tile,"harvest",{})
	t.check(silk.accepted and int(w.drops.back().id) in [3328,3318,3320,3322,3330,3326,3324,3332,3334],"Healthy mature worm yields nearest palette thread")
	t.check(not r.interact(w,p,tile,"harvest",{}).accepted,"Silkworm cannot harvest twice before 24 hours")
	d.wf=8
	t.check(not r.use_item(w,p,tile,386).accepted,"Dead silkworm refuses food")
	t.check(r.use_item(w,p,tile,3896).accepted and not r.special.silk_status(d,r.now()).dead,"Soul revives dead silkworm")
	w.extras.clear();w.set_tile(tile,202208)
	p.catalog_equipment={"hat":48}
	t.check(not r.interact(w,p,tile,"activate",{}).accepted,"Phone Booth refuses remote outfit swap")
	p.position=Vector2(tile.x*32+16,tile.y*32+32)
	t.check(r.interact(w,p,tile,"activate",{}).accepted and p.catalog_equipment.is_empty(),"Standing inside booth stores outfit")
	p.position.x-=32
	t.check(not r.special.punch(r,w,p,tile).accepted,"Filled booth cannot be destroyed from outside")
	p.position.x+=32
	t.check(r.interact(w,p,tile,"activate",{}).accepted and p.catalog_equipment.hat==48,"Second booth swap restores exact outfit")
	w.extras.clear();w.set_tile(tile,203918)
	p.catalog_equipment={"hand":3932}
	r.special.punch(r,w,p,tile)
	d=r.state(w,tile);d.hits=1
	r.special.punch(r,w,p,tile)
	t.check(d.unearthed and w.tile_at(tile)==203918,"Rock Hammer exposes fossil without breaking tile")
	p.catalog_equipment={"hand":3934}
	var fossil=r.special.punch(r,w,p,tile)
	t.check(fossil.accepted and w.tile_at(tile)==0 and w.drops.back().id==3936,"Chisel recovers unearthed fossil")
	w.set_tile(tile,1)
	w.drops.clear();r.reward(w,tile,3936)
	t.check(r.use_item(w,p,tile,4132).accepted and w.drops[0].id==4134 and w.tile_at(tile)==1,"Brush polishes floating fossil without destroying ground")
	w.drops.clear()
	t.check(not r.use_item(w,p,tile,4132).accepted and w.tile_at(tile)==1,"Brush rejects wrong target")
	w.extras.clear();w.set_tile(tile,203918)
	p.catalog_equipment={"hand":3932}
	r.special.punch(r,w,p,tile);r.state(w,tile).hits=0
	r.special.punch(r,w,p,tile)
	t.check(r.source(w.tile_at(tile))==10,"Extra hammer strike smashes fossil into its original rock")

	var native=load("res://src/game/native_item_renderer.gd").new()
	var mohawk=native.definition(14192)
	t.check(not mohawk.is_empty() and mohawk.animations[0].frames.size()==6 and mohawk.animations[0].ms==600,"Fireworks Mohawk uses native six-frame 600ms animation")
	t.check(native.sprite_frame(mohawk,"item_Sprite",0.31)==Vector2(3,12),"Native animation clock selects correct atlas frame")
	p.catalog_equipment={"back":14232};p.grounded=true
	for i in 60:
		native.update(p,1.0/60)
	t.check(not native.particles.is_empty() and native.particles.size()<=96,"Mobile Suit Wings emit bounded native thruster particles")
	p.grounded=false;p.velocity.y=-390
	native.update(p,1.0/60)
	t.check(native.particles.any(func(particle):return particle.sprite=="jump_heart_sprite"),"Native wing jump event emits its heart sprite instead of generic orbit")
	p.catalog_equipment.clear();native.update(p,0.01)
	t.check(native.particles.is_empty(),"Unequipping removes old renderer particles")

	w.extras.clear();w.set_tile(tile,204344)
	r.planted(w,tile,4344)
	t.check(r.interact(w,p,tile,"configure",{"period":0,"speed":999,"enabled":true}).accepted,"Blaster accepts validated settings")
	d=r.state(w,tile)
	t.check(d.period==2 and d.speed==250,"Blaster clamps recovered 2-20s and 10-250px/s limits")
	t.check(not r.interact(w,p,tile,"configure",{"speed":{}}).accepted,"Malformed projectile speed rejected")
	d.next=0
	p.position=Vector2(51*32+16,24*32)
	r.special.tick(r,w,[p],0.01)
	t.check(w.world_effects.projectiles.size()==1,"Enabled blaster emits actual projectile")
	r.special.tick(r,w,[p],0.3)
	t.check(p.position==w.spawn_position() and w.world_effects.projectiles.is_empty(),"Blaster projectile collides with player and respawns them")
	for i in 20:
		var at=Vector2i(30+i,20)
		w.set_tile(at,204344);r.planted(w,at,4344)
		var b=r.state(w,at);b.enabled=true;b.next=0
	r.special.tick(r,w,[],0)
	t.check(w.world_effects.projectiles.size()==10,"Blaster cap is shared world-wide, never ten per machine")

	w.create_default("SOLAR")
	var collector=Vector2i(51,23)
	w.set_tile(collector,203078);r.planted(w,collector,3078)
	var solar=r.state(w,collector)
	solar.charged_from=r.now()-86401
	w.set_tile(tile,0)
	var planted=r.seed_use(w,p,tile,3)
	var tree=r.state(w,tile)
	t.check(planted.accepted and r.now()-float(tree.planted)>=float(tree.duration)*0.25,"Charged Solar Collector advances planting by exact 25 percent")
	t.check(r.now()-float(solar.charged_from)<1,"Solar boost consumes full 24-hour charge")
	w.set_tile(tile,0);w.extras.erase(r.key(w,tile))
	r.seed_use(w,p,tile,3)
	t.check(r.now()-float(r.state(w,tile).planted)<1,"Empty Solar Collector cannot speed a second planting")
	t.check(r.recipes_for(4582)[0].inputs.size()==50 if not r.recipes_for(4582).is_empty() else false,"Food grinder consumes recovered input quantities")

	w.set_tile(tile,202208);w.extras.erase(r.key(w,tile))
	r.state(w,tile).outfit={"hair":14192,"back":14232}
	p.position=Vector2(48*32+16,24*32)
	t.check(r.interact(w,p,tile,"take_all",{}).accepted and r.state(w,tile).outfit.is_empty(),"Phone Booth Take All empties stored clothes without requiring player to stand inside")
	t.check(w.drops.any(func(drop):return int(drop.id)==14192),"Take All returns each stored clothing item rather than destroying it")

	var restored=World.new()
	t.check(restored.restore(w.serialize()),"Special machine extras survive world serialization")
	t.check(restored.extras[r.key(w,collector)].charged_from==solar.charged_from,"Solar charge persists across save/rejoin")
	w.set_tile(tile,203316);w.extras.erase(r.key(w,tile));r.planted(w,tile,3316)
	r.use_item(w,p,tile,386)
	restored.restore(w.serialize())
	t.check(restored.extras[r.key(w,tile)].feeds==1 and restored.extras[r.key(w,tile)].born==r.state(w,tile).born,"Silkworm birth, food and color persist rather than restarting on join")
