extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
const Locks=preload("res://src/game/lock_rules.gd")
var data: Dictionary={}
var clock_override: float=-1
var final_roll: int=-1
func _init() -> void:
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/machine-recovered-029.json"))
func clock() -> float:return clock_override if clock_override>=0 else Time.get_unix_time_from_system()
func handles(id: int) -> bool:return data.calendars.has(str(id)) or data.providers.has(str(id)) or id==10656
func spent(id: int) -> bool:
	return id==10658 or data.calendars.values().any(func(row):return int(row.used_item)==id)
func infect(w,attacker,target) -> bool:
	if not attacker.modifiers.has("Infected!") or target.modifiers.has("Infected!") or target.god_mode:return false
	if preload("res://src/game/source_machine_rules.gd").flags(w).zombie and not w.world_effects.get("pandemic",false):return false
	target.modifiers["Infected!"]={"remaining":60.0,"item":764,"kind":"player_mod","tint":"","slot":"body"}
	return true
func initialize(r,w,tile: Vector2i,id: int) -> void:
	if not handles(id):return
	var d: Dictionary=r.state(w,tile)
	if data.providers.has(str(id)):d.ready=r.now()+float(data.providers[str(id)].seconds)
	if data.calendars.has(str(id)) and not d.has("claimed"):d.claimed=0
	if id==10656 and not d.has("chests"):d.chests=0
func calendar_available(id: int) -> int:
	var row: Dictionary=data.calendars[str(id)]
	var start:=Time.get_unix_time_from_datetime_string(row.unlock_start_utc)
	return clampi(floori((clock()-start)/86400)+1,0,25)
func calendar_pool(id: int,day: int) -> Array:
	for group in data.calendars[str(id)].groups:
		if group.days.any(func(value):return int(value)==day):return group.pool
	return []
func selection(pool: Array,args: Dictionary) -> Dictionary:
	var choice=args.get("choice",-1)
	if not (choice is int or choice is float) or not is_finite(float(choice)) or float(choice)!=int(choice) or int(choice)<0 or int(choice)>=pool.size():return {}
	return pool[int(choice)]
func interact(r,w,p,tile: Vector2i,command: String,args: Dictionary) -> Dictionary:
	var id: int=r.source(w.tile_at(tile))
	if spent(id):return r.result(false,"All rewards from this item have already been collected.")
	if not handles(id):return {}
	var d: Dictionary=r.state(w,tile)
	if data.providers.has(str(id)):
		var row: Dictionary=data.providers[str(id)]
		if not d.has("ready"):d.ready=r.now()+float(row.seconds)
		if command=="grow":d.ready=r.now()-1
		elif command=="harvest":
			if float(d.get("ready",INF))>r.now():return r.result(false,"Provider ready in %ds."%ceili(float(d.ready)-r.now()))
			if w.drops.size()>=256:return r.result(false,"Collect nearby drops before harvesting.")
			d.ready=r.now()+float(row.seconds)
			return r.result(true,"",[r.reward(w,tile,int(row.output),r.source_drops.roll(2)+1),{"type":"item_state","tile":tile}])
		else:return r.result(false,"This provider supports Harvest and Creative grow.")
		return r.result(true,"",[{"type":"item_state","tile":tile}])
	var owner:=Locks.owner_at(w,tile)
	if owner.is_empty():return r.result(false,"This item requires a World Lock.")
	if not p.developer and owner!=p.actor_key:return r.result(false,"Only the owner can collect this item's rewards.")
	if data.calendars.has(str(id)):
		var row: Dictionary=data.calendars[str(id)]
		if command=="grow":
			d.creative_unlocked=25
			return r.result(true,"",[r.message("Creative replay: all 25 historical gifts are available.",tile),{"type":"item_state","tile":tile}])
		if command!="harvest":return r.result(false,"Choose a documented reward for creative replay. Original server odds are not available.")
		var day:=int(d.get("claimed",0))+1
		if day>maxi(calendar_available(id),int(d.get("creative_unlocked",0))) or day>25:return r.result(false,"No unclaimed gift is available yet.")
		var reward:=selection(calendar_pool(id,day),args)
		if reward.is_empty():return r.result(false,"Select a documented gift from this day's pool. No unpublished odds are simulated.")
		if w.drops.size()>=256:return r.result(false,"Collect nearby drops before opening a gift.")
		d.claimed=day
		var events: Array=r.source_drops.grant(r,w,tile,int(reward.id),int(reward.amount))
		if day==25:
			w.set_tile(tile,200000+int(row.used_item));w.extras.erase(r.key(w,tile))
			events.append({"type":"tile_placed","tile":tile})
		events.append({"type":"item_state","tile":tile})
		return r.result(true,"",events)
	if id==10656:
		var well: Dictionary=data.well
		var count:=int(d.get("chests",0))
		if command=="contribute":
			if count>=200:return r.result(false,"The Well of Love is full. Harvest its final reward.")
			var reward:=selection(well.pool,args)
			if reward.is_empty():return r.result(false,"Choose a published chest reward for the five-chest creative replay.")
			if w.drops.size()>=256:return r.result(false,"Collect nearby drops before contributing.")
			d.chests=count+5
			return r.result(true,"",[r.reward(w,tile,int(reward.id),1),r.message("Well of Love: %d/200 chests · creative replay, not original best-of-five odds."%d.chests,tile),{"type":"item_state","tile":tile}])
		if command=="harvest":
			if count<200:return r.result(false,"The well needs %d more Golden Booty Chests."%(200-count))
			if w.drops.size()>=256:return r.result(false,"Collect nearby drops before harvesting.")
			var choice=args.get("choice",0)
			if not (choice is int or choice is float) or not is_finite(float(choice)) or float(choice)!=int(choice) or int(choice)<0 or int(choice)>=well.epic.size():return r.result(false,"Choose a valid epic reward preview.")
			var roll: int=final_roll if final_roll>=0 else r.source_drops.roll(10000)
			var output: int=int(well.essence) if roll<int(well.essence_chance_per_10000) else int(well.epic[int(choice)])
			w.set_tile(tile,200000+int(well.dry));w.extras.erase(r.key(w,tile))
			return r.result(true,"",[r.reward(w,tile,output),{"type":"tile_placed","tile":tile},{"type":"item_state","tile":tile}])
		return r.result(false,"Contribute five creative chests at a time, then harvest at 200.")
	return {}
