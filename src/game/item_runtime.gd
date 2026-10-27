extends RefCounted
var recovered=preload("res://src/game/recovered_machines.gd").new()
var automation=preload("res://src/game/automation_items.gd").new()
var special = preload("res://src/game/special_items.gd").new()
var source_drops=preload("res://src/game/source_drop_rules.gd").new()
const Sim = preload("res://src/game/simulator_catalog.gd")
static var extra: Dictionary = {}
static var rest: Dictionary = {}
const MOD_TINTS = {"Feelin' Blue":"599dff","Frozen":"a2eaff","Devil Horns":"ff7869","Golden Halo!":"ffe280","Poisoned":"a5dc76"}
func _init() -> void:
	Sim.items()
	if extra.is_empty():
		extra = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/extra.json"))
		rest = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/rest.json"))
func now() -> float:
	return Time.get_unix_time_from_system()
func key(world, tile: Vector2i) -> String:
	return str(tile.y*world.size.x+tile.x)
func source(item: int) -> int:
	if item >= 200000:
		return item-200000
	if item >= 100000:
		return item-100000
	return {1:2,2:8,3:10,4:6,5:242,6:108,7:4}.get(item,0)
func state(world, tile: Vector2i) -> Dictionary:
	var k := key(world,tile)
	if not world.extras.has(k):
		world.extras[k] = {}
	return world.extras[k]
func result(accepted: bool, text: String = "", events: Array = []) -> Dictionary:
	return {"accepted":accepted,"reason":text,"events":events}
func message(text: String, tile: Vector2i) -> Dictionary:
	return {"type":"item_message","text":text,"tile":tile}
func handler_for(id: int) -> String:
	return str(extra.consumable.get(str(id),{}).get("kind","creative_use"))
func is_seed(id: int) -> bool:
	return Sim.use_rules.seed.has(str(id)) and int(Sim.items().get(str(id),[0,0,0,0,0,0,0,0])[7]) == 19
func planted(world, tile: Vector2i, id: int) -> void:
	automation.initialize(self,world,tile,id)
	recovered.initialize(self,world,tile,id)
	special.initialize(self,world,tile,id)
	var data := state(world,tile)
	if is_seed(id):
		data.seed = id
		data.planted = now()
		data.duration = maxf(1,float(Sim.use_rules.seed[str(id)][0]))
		data.fruit=1 if int(Sim.use_rules.seed[str(id)][1])==999 else randi_range(1,4)
	elif Sim.use_rules.provider.has(str(id)):
		data.ready = now()+float(Sim.use_rules.provider[str(id)])
func growth(world, tile: Vector2i) -> float:
	var data: Dictionary = world.extras.get(key(world,tile),{})
	return clampf((now()-float(data.get("planted",now())))/maxf(1,float(data.get("duration",1))),0,1)
func seed_use(world, player, tile: Vector2i, id: int) -> Dictionary:
	var current := source(world.tile_at(tile))
	if is_seed(current):
		var data := state(world,tile)
		var ids := [id,current]
		ids.sort()
		var output := int(Sim.use_rules.splice.get("%d,%d" % ids,0))
		if output == 0 or data.get("spliced",false):
			return result(false,"These seeds cannot be spliced.")
		var seed := output+1
		world.set_tile(tile,200000+seed)
		planted(world,tile,seed)
		data.spliced = true
		var events: Array=special.solar_growth(self,world,tile,true)
		events.append_array([{ "type":"tile_placed","tile":tile},message("Spliced: "+Sim.items()[str(output)][0],tile)])
		return result(true,"",events)
	if world.tile_at(tile) != 0 or not world.solid(tile+Vector2i.DOWN):
		return result(false,"Plant seeds on a solid block with empty space above it.")
	world.set_tile(tile,200000+id)
	planted(world,tile,id)
	var events: Array=special.solar_growth(self,world,tile,false)
	events.append_array([{ "type":"tile_placed","tile":tile},{"type":"item_state","tile":tile}])
	return result(true,"",events)
func reward(world, tile: Vector2i, id: int, amount: int = 1) -> Dictionary:
	id = clampi(id,2,100000)
	if id in [6,7,8,9] or not Sim.items().has(str(id)):
		id = 2
	if world.drops.size()<256:
		world.next_drop += 1
		world.drops.append({"uid":world.next_drop,"id":id,"amount":clampi(amount,1,200),"x":tile.x*32+16,"y":tile.y*32+12})
	return {"type":"reward","tile":tile,"item":id,"amount":amount,"text":"Received %d × %s" % [amount,Sim.items()[str(id)][0]]}
func collect(world, player) -> bool:
	var changed := false
	for drop in world.drops.duplicate():
		if Vector2(float(drop.x),float(drop.y)).distance_to(player.position-Vector2(0,16))<38:
			var item := str(int(drop.id))
			if player.collected.size()>=1024 and not player.collected.has(item):
				continue
			player.collected[item] = mini(999999,int(player.collected.get(item,0))+int(drop.amount))
			world.drops.erase(drop)
			changed = true
	return changed
func interact(world, player, tile: Vector2i, command: String, args: Dictionary) -> Dictionary:
	if not world.contains(tile) or (Vector2(tile)*32+Vector2(16,16)).distance_to(player.position-Vector2(0,16))>96:
		return result(false,"Out of reach")
	var id := source(world.tile_at(tile))
	if id==5814:return preload("res://src/game/guild_weather.gd").configure(self,world,player,tile,command,args)
	if preload("res://src/game/source_machine_rules.gd").handles(id):return preload("res://src/game/source_machine_rules.gd").toggle(self,world,player,tile,command,args)
	var recovered_result: Dictionary=recovered.interact(self,world,player,tile,command,args)
	if not recovered_result.is_empty():return recovered_result
	var specific: Dictionary=automation.interact(self,world,player,tile,command,args)
	if not specific.is_empty():return specific
	if command in ["deposit","craft"]:
		for field in (["item","amount"] if command=="deposit" else ["recipe"]):
			var value = args.get(field)
			if not value is int and not value is float or not is_finite(float(value)) or float(value)!=int(value) or float(value)<0 or float(value)>100000:
				return result(false,"Invalid item action parameters.")
	if id == 0:
		return result(false,"Choose a placed item.")
	var recovered: Dictionary = special.interact(self,world,player,tile,command,args)
	if not recovered.is_empty():
		return recovered
	var data := state(world,tile)
	var events: Array = []
	if command == "grow":
		if is_seed(id):
			data.planted = now()-float(data.get("duration",1))
		elif Sim.use_rules.provider.has(str(id)):
			data.ready = now()-1
		else:
			return result(false,"Only trees/providers can be made ready.")
		events.append(message("Creative growth: ready to harvest.",tile))
	elif command == "harvest" and is_seed(id):
		if growth(world,tile)<1:
			return result(false,"Tree is still growing. Use fertilizer or Creative grow.")
		events.append(reward(world,tile,id-1,randi_range(1,4)))
		events.append(reward(world,tile,id,1))
		world.set_tile(tile,0)
		world.extras.erase(key(world,tile))
		events.append({"type":"tile_removed","tile":tile})
	elif command == "harvest" and Sim.use_rules.provider.has(str(id)):
		if not data.has("ready"):
			data.ready = now()+float(Sim.use_rules.provider[str(id)])
		if float(data.ready)>now():
			return result(false,"Provider ready in %d seconds." % ceili(data.ready-now()))
		var drops: Array=source_drops.provider(self,id)
		if drops.is_empty():return result(false,"The recovered simulator has no drop table for this provider; timer and stock were preserved.")
		for drop in drops:events.append_array(source_drops.grant(self,world,tile,int(drop[0]),int(drop[1])))
		data.ready = now()+float(Sim.use_rules.provider[str(id)])
		if id in [7766,7770,7774,7778,8050,9302]:
			world.set_tile(tile,0);world.extras.erase(key(world,tile));events.append({"type":"tile_removed","tile":tile})
		elif id==12680:
			data.harvests=int(data.get("harvests",0))+1
			if data.harvests>=8:
				events.append(reward(world,tile,12682));world.set_tile(tile,0);world.extras.erase(key(world,tile));events.append({"type":"tile_removed","tile":tile})
	elif command == "configure":
		for field in args:
			if field not in ["label","enabled","price","period","output","text"]:
				return result(false,"Unrecognized machine setting.")
			if field in ["label","text"] and (not args[field] is String or args[field].length()>160):
				return result(false,"Use at most 160 characters.")
			if field == "enabled" and not args[field] is bool:
				return result(false,"Invalid switch value.")
			if field in ["price","period","output"] and (not args[field] is int and not args[field] is float or not is_finite(float(args[field])) or float(args[field])<0 or float(args[field])>100000):
				return result(false,"Invalid machine number.")
		for field in args:
			data[field] = args[field]
		events.append(message("Settings saved.",tile))
	elif command == "deposit":
		var item := int(args.get("item",0))
		var amount := int(args.get("amount",1))
		if not Sim.items().has(str(item)) or item in [0,1,6,7,8,9] or amount<1 or amount>200:
			return result(false,"Choose a valid item and 1–200 units.")
		if not data.has("stock"):
			data.stock = {}
		if data.stock.size()>=20 and not data.stock.has(str(item)):
			return result(false,"Machine holds at most 20 item types.")
		data.stock[str(item)] = mini(200,int(data.stock.get(str(item),0))+amount)
		data.selected = item
		events.append(message("Stock added from creative inventory.",tile))
	elif command == "dispense":
		var stock: Dictionary = data.get("stock",{})
		var item := str(data.get("selected",0))
		if int(stock.get(item,0))<1:
			return result(false,"Machine is empty. Deposit items first.")
		stock[item] -= 1
		events.append(reward(world,tile,int(item),1))
	elif command == "craft":
		var recipes := recipes_for(id)
		var index := int(args.get("recipe",-1))
		if index<0 or index>=recipes.size():
			return result(false,"Choose a recipe.")
		var recipe: Dictionary = recipes[index]
		var stock: Dictionary = data.get("stock",{})
		for ingredient in recipe.inputs:
			if int(stock.get(str(int(ingredient)),0))<recipe.inputs.count(ingredient):
				return result(false,"Deposit every ingredient first.")
		for ingredient in recipe.inputs:
			stock[str(int(ingredient))] -= 1
		events.append(reward(world,tile,int(recipe.output),int(recipe.get("amount",1))))
		data.result = recipe.name
	elif command == "activate":
		var name: String = str(Sim.items().get(str(id),["Machine"])[0]).to_lower()
		if "roulette" in name:
			data.result = str(randi_range(0,36))
		elif "dice" in name:
			data.result = str(randi_range(1,6))
		elif "gacha" in name or "mystery" in name or "slot" in name:
			var pool: Array = data.get("stock",{}).keys().filter(func(k): return int(data.stock[k])>0)
			if pool.is_empty():
				return result(false,"This machine has no recovered drop table. Deposit creative stock before dispensing.")
			var won := int(pool[randi()%pool.size()])
			if data.get("stock",{}).has(str(won)):
				data.stock[str(won)] -= 1
			data.result = Sim.items()[str(won)][0]
			events.append(reward(world,tile,won,1))
		elif "phone booth" in name:
			var outfit: Dictionary = data.get("outfit",{}).duplicate()
			data.outfit = player.catalog_equipment.duplicate()
			player.catalog_equipment = outfit
			data.result = "Outfits swapped"
		else:
			data.enabled = not data.get("enabled",false)
			data.result = "On" if data.enabled else "Off"
		data.activations = int(data.get("activations",0))+1
		events.append(message("%s: %s" % [Sim.items().get(str(id),["Item"])[0],data.result],tile))
	else:
		return result(false,"Choose an available item action.")
	events.append({"type":"item_state","tile":tile})
	return result(true,"",events)
func recipes_for(id: int) -> Array:
	var name: String = str(Sim.items().get(str(id),[""])[0]).to_lower()
	var rows: Array = []
	if "dna" in name:
		for recipe in rest.data.B_dna:
			rows.append({"name":Sim.items().get(str(int(recipe[3])),["DNA result"])[0],"inputs":recipe.slice(0,3),"output":int(recipe[3])})
	elif "oven" in name or "cooking" in name:
		for recipe in rest.data.A_cook.recipes:
			rows.append({"name":recipe[0],"inputs":recipe[1],"output":int(recipe[5][0][1])})
	elif "grind" in name or "food processor" in name:
		for item in rest.data.A_grind:
			var recipe: Array = rest.data.A_grind[item]
			var inputs: Array=[]
			for i in int(recipe[0]):
				inputs.append(int(item))
			rows.append({"name":Sim.items().get(str(int(recipe[1])),["Processed item"])[0],"inputs":inputs,"output":int(recipe[1])})
	elif "compactor" in name:
		for item in rest.data.A_r12:
			rows.append({"name":"Recycle "+Sim.items().get(item,["clothes"])[0],"inputs":[int(item)],"output":int(rest.data.A_r12[item][0])})
	return rows
func use_item(world, player, tile: Vector2i, id: int) -> Dictionary:
	if not world.contains(tile):
		return result(false,"Outside world")
	var recovered: Dictionary = special.use(self,world,player,tile,id)
	if not recovered.is_empty():
		return recovered
	var rule: Dictionary = extra.consumable.get(str(id),{})
	var kind := handler_for(id)
	if kind=="war_balloon" and preload("res://src/game/source_machine_rules.gd").flags(world).balloon:return result(false,"War Balloons cannot be thrown while the Balloon Jammer is active.")
	if kind=="player_mod" and world.world_effects.get("xenonite",{}).get("block",{}).get("pwr",false):
		return result(false,"Powerups are blocked by this world\'s Xenonite Crystal.")
	var name: String = Sim.items().get(str(id),["Item"])[0]
	var data := state(world,tile)
	var events: Array = []
	match kind:
		"grow_spray","world_spray":
			var found := false
			var targets: Array = world.extras.keys() if kind=="world_spray" else [key(world,tile)]
			for k in targets:
				var target: Dictionary = world.extras.get(k,{})
				if target.has("planted"):
					target.planted -= maxf(3600,float(target.duration)*0.25)
					found = true
				elif target.has("ready"):
					target.ready -= 3600
					found = true
			if not found:
				return result(false,"Use fertilizer on a growing tree or provider.")
		"player_mod","player_look":
			var mod: String = rule.get("mod",name)
			var tint: String = MOD_TINTS.get(mod,"")
			for word in {"red":"ef5656","green":"57d363","blue":"52a6ee","purple":"bd66dd","black":"42424c","white":"eeeeee","pink":"f68bd4","orange":"f5a14a"}:
				if word in name.to_lower() and kind=="player_look":
					tint = {"red":"ef5656","green":"57d363","blue":"52a6ee","purple":"bd66dd","black":"42424c","white":"eeeeee","pink":"f68bd4","orange":"f5a14a"}[word]
			player.modifiers[mod] = {"remaining":maxf(5,float(rule.get("secs",1800))),"item":id,"kind":kind,"tint":tint,"slot":"hair" if "hair" in name.to_lower() else "body"}
			events.append(message(name+" applied.",tile))
		"water","fire","eldritch_flame","glue","tree_decorations","varnish":
			if kind=="varnish":
				data.erase("paint")
			else:
				data[kind] = true
			if kind=="water":
				data.erase("fire")
		"paint":
			var colors := {3478:"ef5656",3480:"f3cb45",3482:"57d363",3484:"52a6ee",3486:"bd66dd",3488:"eeeeee",3490:"42424c"}
			data.paint = colors.get(id,"ffffff")
		"love_potion":
			if source(world.tile_at(tile))!=10:
				return result(false,"Love Potion #8 needs a Rock.")
			world.set_tile(tile,200392)
			events.append({"type":"tile_placed","tile":tile})
		"extract_o_snap","spatula","fossil_brush":
			var current := source(world.tile_at(tile))
			if current in [0,6,8] and not player.developer:
				return result(false,"This tile is protected.")
			events.append(reward(world,tile,current,1))
			world.set_tile(tile,0)
			world.extras.erase(key(world,tile))
			events.append({"type":"tile_removed","tile":tile})
		"world_blast":
			return preload("res://src/game/source_blasts.gd").apply(self,world,player,tile,id)
		"door_mover","lock_mover":
			if world.tile_at(tile)!=0 or not world.solid(tile+Vector2i.DOWN):
				return result(false,"Choose empty space above a solid tile.")
			if kind=="door_mover":
				world.set_tile(world.main_door,0)
				world.main_door = tile
				world.set_tile(tile,4)
				world.set_tile(tile+Vector2i.DOWN,2)
			else:
				var full: Array = world.locks.filter(func(lock):return lock.area==0)
				if full.is_empty():
					return result(false,"Place a world lock first.")
				var lock: Dictionary = full[0]
				world.set_tile(Vector2i(lock.x,lock.y),0)
				world.set_tile(tile,int(lock.item))
				lock.x=tile.x
				lock.y=tile.y
			events.append({"type":"world_changed","tile":tile})
		"pack_open","combine","sigil","fishing_bait","chemsynth_tool","war_balloon_bucket":
			var pool := [34,36,40,44,48,68,98,156,196,868,874]
			events.append(reward(world,tile,pool[randi()%pool.size()],randi_range(1,3)))
		_:
			# Unrecovered native handlers use the explicitly labelled creative prop effect.
			player.modifiers[name] = {"remaining":30.0,"item":id,"kind":"creative_effect","tint":""}
			events.append(message(("Creative effect: " if kind in ["no_handler","creative_use"] else "Used: ")+name,tile))
	events.append({"type":"item_used","tile":tile,"item":id,"kind":kind})
	events.append({"type":"item_state","tile":tile})
	return result(true,"",events)
