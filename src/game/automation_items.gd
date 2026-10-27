extends RefCounted

const Sim=preload("res://src/game/simulator_catalog.gd")
const Locks=preload("res://src/game/lock_rules.gd")
const CRYSTALS=[2242,2244,2246,2248,2250]
const STORAGE={5638:5000,6946:1500,6948:1500}
const AUTO=[6950,6952,6954]
const POWERS={"dbl":"Double Jump","hig":"High Jump","asb":"Heat Resist","pun":"Strong Punch","lng":"Long Punch","spd":"Speedy","lngb":"Long Build","siw":"Speedy in Water","sp2":"Punch Damage","pwr":"Powerups"}
var chi_index: Dictionary={}
var tick_clocks: Dictionary={}

func handles(id: int) -> bool:
	return id in CRYSTALS or id==2072 or STORAGE.has(id) or id in AUTO

func initialize(r,w,tile: Vector2i,id: int) -> void:
	if not handles(id):return
	var d=r.state(w,tile)
	if id in CRYSTALS and not d.has("crystals"):
		d.crystals={str(id):1}
	if STORAGE.has(id) and not d.has("target"):
		d.merge({"target":0,"count":0,"enabled":true,"building":false,"elapsed":0.0})
	if id in AUTO and not d.has("target"):
		d.merge({"target":0,"fuel":0,"enabled":false,"trees":true,"seeds":true,"count":0,"elapsed":0.0})
	if id==2072 and not w.world_effects.has("xenonite"):
		w.world_effects.xenonite={"force":{},"block":{}}

func done(r,tile: Vector2i,text: String,events: Array=[]) -> Dictionary:
	events.append(r.message(text,tile))
	events.append({"type":"item_state","tile":tile})
	return r.result(true,"",events)

func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==int(value)

func crystal_recipe(r,d: Dictionary) -> Array:
	var best: Array=[]
	var rarity=-1
	for row in r.rest.data.A_crystal:
		var enough=true
		for i in 5:
			if int(d.get("crystals",{}).get(str(CRYSTALS[i]),0))<int(row[i]):enough=false
		var candidate=int(Sim.items().get(str(int(row[5])),[0,0,0,0,0,0,0,0,0,0,0,0,0])[12])
		if enough and candidate>rarity:
			best=row;rarity=candidate
	return best

func crystal_requirement(r,d: Dictionary) -> Array:
	if d.has("chi_required"):return d.chi_required
	var recipe=crystal_recipe(r,d)
	if recipe.is_empty():return []
	var rarity=int(Sim.items()[str(int(recipe[5]))][12])
	var req=[0,0,0,0]
	for i in clampi(int(rarity/10),3,16):req[randi_range(0,3)]+=1
	d.chi_required=req
	return req

func add_crystal(r,w,tile: Vector2i,item: int) -> Dictionary:
	if item not in CRYSTALS or r.source(w.tile_at(tile)) not in CRYSTALS:
		return r.result(false,"Choose an existing Crystal cluster.")
	initialize(r,w,tile,r.source(w.tile_at(tile)))
	var d=r.state(w,tile)
	var count=0
	for amount in d.crystals.values():count+=int(amount)
	if count>=5:return r.result(false,"This cluster is full: at most five crystals.")
	d.crystals[str(item)]=int(d.crystals.get(str(item),0))+1
	crystal_requirement(r,d)
	return done(r,tile,"Crystal mixed. Wrench the cluster to inspect elemental Chi.")

func element(r,id: int) -> int:
	if id==822:return 3
	if chi_index.is_empty():
		for category in r.rest.data.A_chi:
			for item in r.rest.data.A_chi[category]:chi_index[int(item)]=int(category)
	return int(chi_index.get(id,4))

func chi_at(r,w,tile: Vector2i) -> Array:
	var result=[0,0,0,0]
	for y in range(-1,2):
		for x in range(-1,2):
			var at=tile+Vector2i(x,y)
			if not w.contains(at):continue
			if at!=tile and w.tile_at(at)!=0:
				var kind=element(r,r.source(w.tile_at(at)))
				if kind<4:result[kind]+=1
			var back=int(w.background[at.y*w.size.x+at.x])
			if back!=0:
				var kind=element(r,r.source(back))
				if kind<4:result[kind]+=1
			var d: Dictionary=w.extras.get(r.key(w,at),{})
			if d.get("water",false):result[3]+=1
			if d.get("fire",false):result[1]+=1
	return result

func compatible(r,item: int,machine: int) -> bool:
	if not Sim.items().has(str(item)) or item in [0,1,6,7,8,9,5638,6016,6946,6948,6950,6952,6954,5640]:return false
	var row: Array=Sim.items()[str(item)]
	if machine==6946 and not r.is_seed(item):return false
	if machine==6948 and r.is_seed(item):return false
	var action=int(row[7])
	var untradeable=bool(int(row[10])&32768)
	return item==1796 or not untradeable and int(row[12])!=999 and (action==8 or action not in [20,8,3])

func interact(r,w,p,tile: Vector2i,command: String,args: Dictionary) -> Dictionary:
	var id=r.source(w.tile_at(tile))
	if not handles(id):return {}
	initialize(r,w,tile,id)
	var d=r.state(w,tile)
	if id in CRYSTALS:
		if command=="add_crystal" and integer(args.get("item")):
			return add_crystal(r,w,tile,int(args.item))
		if command=="shatter":return punch(r,w,p,tile)
		return r.result(false,"Mix up to five crystals. Match surrounding Chi, then punch to shatter.")
	if id==2072:
		if command!="xenonite" or not args.get("power") is String or not args.get("mode") is String:
			return r.result(false,"Choose a power to force, block, or leave normal.")
		var power: String=args.power
		var mode: String=args.mode
		if not POWERS.has(power) or mode not in ["force","block","normal"] or power=="pwr" and mode=="force":
			return r.result(false,"Invalid Xenonite power setting.")
		var settings: Dictionary=w.world_effects.xenonite
		settings.force.erase(power);settings.block.erase(power)
		if mode!="normal":settings[mode][power]=true
		p.world_rules=settings
		return done(r,tile,"Xenonite: %s %s" % [POWERS[power],mode],[{"type":"world_rules","tile":tile}])
	d.owner_key=p.actor_key
	if command=="select_target":
		if not integer(args.get("item")):return r.result(false,"Choose a valid target item.")
		var item=int(args.item)
		if STORAGE.has(id):
			if int(d.count)>0:return r.result(false,"Empty the machine before changing its target.")
			if not compatible(r,item,id):return r.result(false,"This item is not compatible with this storage machine.")
		else:
			if int(d.count)>0:return r.result(false,"Retrieve stored items before changing the target.")
			if id!=6952 and not r.is_seed(item):item+=1
			if id==6952 and r.is_seed(item):item-=1
			if not Sim.items().has(str(item)) or int(Sim.items()[str(item)][12])==999 or item in [0,1,6,7,8,9,611,9380,9386,9384,15018,10716,5136,9600,9381,9387,9385,5137,610]:
				return r.result(false,"This target is not allowed in the automation machine.")
			if id!=6952 and not r.is_seed(item):return r.result(false,"This item has no plantable seed.")
			if id==6952 and (int(Sim.items()[str(item)][7])==20 or not compatible(r,item,5638)):
				return r.result(false,"This target cannot be broken automatically.")
		d.target=item
		return done(r,tile,"Target: "+str(Sim.items()[str(item)][0]))
	if command=="configure":
		for field in args:
			if field not in (["enabled"] if STORAGE.has(id) else ["trees","seeds"]) or not args[field] is bool:
				return r.result(false,"Invalid automation setting.")
			if id in AUTO and int(d.count)>0:return r.result(false,"Empty the machine before changing its mode.")
		for field in args:d[field]=args[field]
		return done(r,tile,"Settings updated.")
	if command in ["deposit","withdraw","refuel"]:
		if not integer(args.get("amount")) or float(args.amount)<1 or float(args.amount)>100000:
			return r.result(false,"Use a positive whole amount up to 100000.")
		var amount=int(args.amount)
		if command=="refuel":
			if id not in AUTO:return r.result(false,"This machine does not use fuel.")
			d.fuel=mini(8000,int(d.fuel)+amount)
			return done(r,tile,"Creative fuel added: %d/8000." % int(d.fuel))
		if int(d.target)==0:return r.result(false,"Choose the target item first.")
		if command=="deposit":
			if not STORAGE.has(id):return r.result(false,"This machine receives items through automation.")
			if args.has("item") and (not integer(args.item) or int(args.item)!=int(d.target)):
				return r.result(false,"Deposit must match the selected target.")
			d.count=mini(int(STORAGE[id]),int(d.count)+amount)
			return done(r,tile,"Creative stock added to selected target.")
		var output=int(d.target)
		if id==6954 and not d.seeds:output-=1
		if p.collected.size()>=1024 and not p.collected.has(str(output)):return r.result(false,"Your collected-item list is full.")
		var count=mini(mini(amount,int(d.count)),maxi(0,200-int(p.collected.get(str(output),0))))
		if count<=0:return r.result(false,"Machine empty, or your collected stack already contains 200 items.")
		p.collected[str(output)]=int(p.collected.get(str(output),0))+count
		d.count-=count
		return done(r,tile,"Retrieved %d %s." % [count,Sim.items()[str(output)][0]])
	if command=="remove_fuel" and id in AUTO:
		d.fuel=0
		return done(r,tile,"Fuel removed. This creative machine is now empty of gems.")
	if command=="get_remote":
		if id!=5638 or int(d.target)==0 or not compatible(r,int(d.target),5638):return r.result(false,"Select a buildable MAGPLANT target first.")
		var row: Array=Sim.items()[str(int(d.target))]
		if int(row[12])==999 or int(row[6])!=1 and int(row[7]) not in [18,19]:return r.result(false,"This stored item cannot be built with the remote.")
		p.machine_remote={"index":int(r.key(w,tile)),"target":int(d.target),"world":w.name}
		p.collected["5640"]=1
		return done(r,tile,"Received MAGPLANT Remote. Select it in inventory to build from storage.")
	if command=="activate":
		if int(d.target)==0:return r.result(false,"Choose the target item first.")
		if id==5638:
			d.building=not d.building
			var remote=interact(r,w,p,tile,"get_remote",{})
			if not remote.accepted:return remote
			return done(r,tile,"MAGPLANT building active." if d.building else "MAGPLANT building disabled.")
		if id in AUTO:
			d.enabled=not d.enabled
			return done(r,tile,"Automation running." if d.enabled else "Automation stopped.")
	return r.result(false,"Choose a machine-specific action.")

func remote_target(r,w,p) -> Dictionary:
	var remote: Dictionary=p.machine_remote
	if remote.is_empty() or remote.get("world","")!=w.name:return r.result(false,"Get a remote from a MAGPLANT in this world first.")
	var index=int(remote.get("index",-1))
	if index<0 or index>=6000:return r.result(false,"Invalid remote binding.")
	var at=Vector2i(index%w.size.x,index/w.size.x)
	var d: Dictionary=w.extras.get(str(index),{})
	if r.source(w.tile_at(at))!=5638 or not d.get("enabled",false) or not d.get("building",false) or int(d.get("target",0))!=int(remote.target):return r.result(false,"There is no active matching MAGPLANT.")
	if int(d.get("count",0))<=0:return r.result(false,"The MAGPLANT is empty.")
	var owner=Locks.owner_at(w,at)
	if owner!="" and owner!=p.actor_key and not p.developer:return r.result(false,"You do not have access to this MAGPLANT.")
	return {"accepted":true,"item":200000+int(d.target),"tile":at,"data":d}

func punch(r,w,p,tile: Vector2i) -> Dictionary:
	var id=r.source(w.tile_at(tile))
	if not handles(id):return {}
	initialize(r,w,tile,id)
	var d=r.state(w,tile)
	if id in CRYSTALS:
		var recipe=crystal_recipe(r,d)
		if recipe.is_empty():return r.result(false,"These crystals cannot form anything yet. Mix different colors.")
		var req=crystal_requirement(r,d)
		if req!=chi_at(r,w,tile):return r.result(false,"Crystals are out of alignment. Wrench the cluster to inspect its Chi.")
		w.set_tile(tile,0);w.extras.erase(r.key(w,tile))
		return done(r,tile,"The crystals seek a higher form!",[r.reward(w,tile,int(recipe[5]),int(recipe[6])),{"type":"tile_removed","tile":tile}])
	if id==5638:
		var last=float(d.get("last_punch",0))
		d.last_punch=r.now()
		if int(d.count)>0 or r.now()-last>8:return interact(r,w,p,tile,"activate",{})
	elif STORAGE.has(id) and int(d.count)>0:
		return r.result(false,"Empty this machine before breaking it.")
	elif id in AUTO:
		if int(d.target)>0:d.enabled=not d.enabled
		if int(d.fuel)>0 or int(d.count)>0:return done(r,tile,"Automation toggled. Remove fuel and stored items before breaking.")
	return {}

func removed(_r,w,_tile: Vector2i,id: int) -> void:
	if id==2072:w.world_effects.erase("xenonite")

func allowed(w,d: Dictionary,tile: Vector2i) -> bool:
	var owner=Locks.owner_at(w,tile)
	return owner=="" or owner==d.get("owner_key","")

func suck(w,d: Dictionary,item: int,capacity: int) -> bool:
	var changed=false
	for drop in w.drops.duplicate():
		var at=Vector2i(floori(float(drop.x)/32),floori(float(drop.y)/32))
		if int(drop.id)!=item or int(d.count)>=capacity or not allowed(w,d,at):continue
		var take=mini(int(drop.amount),capacity-int(d.count))
		d.count+=take;drop.amount-=take;changed=true
		if int(drop.amount)<=0:w.drops.erase(drop)
	return changed

func tick(r,w,dt: float) -> Array:
	var clock_key=w.get_instance_id()
	tick_clocks[clock_key]=float(tick_clocks.get(clock_key,0))+dt
	if float(tick_clocks[clock_key])+0.000001<0.1:return []
	dt=float(tick_clocks[clock_key]);tick_clocks[clock_key]=0.0
	var events: Array=[]
	for key in w.extras.keys():
		if not w.extras.has(key):continue
		var index=int(key)
		var at=Vector2i(index%w.size.x,index/w.size.x)
		var id=r.source(w.tile_at(at))
		if not STORAGE.has(id) and id not in AUTO:continue
		initialize(r,w,at,id)
		var d: Dictionary=w.extras[key]
		d.elapsed=float(d.get("elapsed",0))+dt
		var interval=0.5 if STORAGE.has(id) else 1.5
		if float(d.elapsed)+0.000001<interval:continue
		d.elapsed=fmod(float(d.elapsed),interval)
		if int(d.target)==0:continue
		var changed=false
		if STORAGE.has(id):
			if d.enabled:changed=suck(w,d,int(d.target),int(STORAGE[id]))
		else:
			if id==6954:changed=suck(w,d,int(d.target) if d.seeds else int(d.target)-1,100000)
			if d.enabled and int(d.fuel)>0:
				var harvest=id==6950 or id==6954 and d.trees
				var target=int(d.target) if harvest or id==6952 else int(d.target)-1
				for i in 6000:
					var tile=Vector2i(i%w.size.x,i/w.size.x)
					var foreground=r.source(w.tile_at(tile))
					var background=r.source(int(w.background[i]))
					if foreground!=target and (harvest or background!=target):continue
					if not allowed(w,d,tile):continue
					if harvest:
						if r.growth(w,tile)>=1:
							var seed=r.state(w,tile)
							w.set_tile(tile,0);w.extras.erase(r.key(w,tile))
							events.append(r.reward(w,tile,target-1,maxi(1,int(seed.get("fruit",1)))))
							var rarity=int(Sim.use_rules.seed[str(target)][1])
							if rarity!=999 and not Sim.use_rules.cloth.has(str(target-1)) and randf()<8.0/(3*(maxi(rarity,1)+6)):
								events.append(r.reward(w,tile,target,1))
							if rarity>=1 and rarity<999 and randi_range(0,2)<2:
								var gem_ratio=float(rarity)/(6 if rarity<31 else 4)
								var gems=randi_range(0,floori(gem_ratio))+(1 if randf()<0.5*fmod(gem_ratio,1) else 0)
								if gems>0:events.append(r.reward(w,tile,112,gems))
							events.append({"type":"tile_removed","tile":tile})
							d.fuel-=1;changed=true
					else:
						if foreground!=target and foreground!=0:break
						if int(d.get("hit_index",-1))!=i:
							d.hit_index=i;d.hit_points=maxi(1,int(Sim.items()[str(target)][8]))
						d.hit_points-=1;d.fuel-=1;changed=true
						if int(d.hit_points)<=0:
							if foreground==target:w.set_tile(tile,0);w.extras.erase(r.key(w,tile))
							else:w.set_background(tile,0)
							d.erase("hit_index")
							events.append({"type":"tile_removed","tile":tile,"layer":"foreground" if foreground==target else "background"})
							if randi_range(0,8)<2:events.append(r.reward(w,tile,target+1))
							elif randi_range(0,99)<8:events.append(r.reward(w,tile,target))
					break
		if changed:events.append({"type":"item_state","tile":at})
	return events

func describe(r,w,tile: Vector2i) -> String:
	var id=r.source(w.tile_at(tile))
	if not handles(id):return ""
	initialize(r,w,tile,id)
	var d=r.state(w,tile)
	if id in CRYSTALS:
		var colors: Array=[]
		for crystal in CRYSTALS:colors.append("%s: %d" % [Sim.items()[str(crystal)][0],int(d.crystals.get(str(crystal),0))])
		var req=crystal_requirement(r,d)
		return "\n"+", ".join(colors)+"\nNearby Chi (Earth/Fire/Air/Water): "+str(chi_at(r,w,tile))+"\nRequired: "+("Mix more crystals first" if req.is_empty() else str(req))+"\nMatch the elements around this cluster, then punch it."
	if id==2072:return "\nForce or block a power for everyone in this world. Normal follows their clothing."
	var target=str(Sim.items().get(str(int(d.target)),["Not selected"])[0])
	if STORAGE.has(id):return "\nTarget: %s\nStored: %d/%d · Collection: %s\nCollection interval: 0.5 seconds" % [target,int(d.count),int(STORAGE[id]),"On" if d.enabled else "Off"]
	return "\nTarget: %s\nFuel: %d/8000 · Running: %s\nAutomation interval: 1.5 seconds · Stored: %d" % [target,int(d.fuel),"On" if d.enabled else "Off",int(d.count)]
