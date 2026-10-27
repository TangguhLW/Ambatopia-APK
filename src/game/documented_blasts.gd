extends RefCounted
const World=preload("res://src/game/world_state.gd")
const Sim=preload("res://src/game/simulator_catalog.gd")
const IDS=[1060,1402]
static func apply(r,w,p,tile: Vector2i,id: int,variant: int) -> Dictionary:
	var candidate=World.new()
	candidate.create_default(w.name)
	var random:=RandomNumberGenerator.new()
	random.seed=(w.name.hash()+id*7919+maxi(0,variant)) if variant>=0 else randi()
	if id==1402:
		candidate.foreground.fill(0);candidate.background.fill(0)
		for x in 100:candidate.foreground[59*100+x]=2
		candidate.main_door=Vector2i(0 if random.randi_range(0,1)==0 else 99,58)
		candidate.set_tile(candidate.main_door,4)
	elif id==1060:
		candidate.set_tile(candidate.main_door,0)
		candidate.set_tile(candidate.main_door+Vector2i.DOWN,1)
		candidate.main_door=Vector2i(random.randi_range(0,99),23)
		candidate.set_tile(candidate.main_door,4);candidate.set_tile(candidate.main_door+Vector2i.DOWN,2)
		var seeds: Array=Sim.use_rules.seed.keys().filter(func(key):return int(key) not in [1,7,9] and int(Sim.items()[key][7])==19 and int(Sim.items()[key][11])!=999)
		if seeds.is_empty():return r.result(false,"No valid source seeds for Harvest Moon; world preserved.")
		for x in 100:
			if x==candidate.main_door.x:continue
			var seed:=int(seeds[random.randi_range(0,seeds.size()-1)])
			var at:=Vector2i(x,23)
			candidate.set_tile(at,200000+seed)
			var duration: float=maxf(1,float(Sim.use_rules.seed[str(seed)][0]))
			candidate.extras[str(2300+x)]={"seed":seed,"fruit":1 if int(Sim.use_rules.seed[str(seed)][1])==999 else random.randi_range(1,4),"duration":duration,"planted":r.now()-duration}
		candidate.weather="harvest"
	candidate.world_effects={"blast":id,"blast_origin":"documented reconstruction","unverified":"Original server terrain/RNG unavailable. Layout and seed distribution are adaptations."}
	var result: Dictionary=candidate.serialize()
	var validated=World.new()
	if not validated.restore(result):return r.result(false,"Generated world validation failed; current world preserved.")
	w.restore(result)
	return r.result(true,"",[{"type":"world_changed","tile":tile},r.message("%s · documented layout reconstruction; original server generator unavailable."%Sim.items()[str(id)][0],tile)])
