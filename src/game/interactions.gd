extends RefCounted

const Sim = preload("res://src/game/simulator_catalog.gd")
var cooldown := 0.0
var runtime = preload("res://src/game/item_runtime.gd").new()

func tick(dt: float) -> void:
	cooldown = maxf(0, cooldown - dt)

func apply(world, player, action: String, tile: Vector2i, item_id: int, permission: Callable=Callable()) -> Dictionary:
	var result:=apply_single(world,player,action,tile,item_id)
	if not result.accepted or action!="punch" or player.rayman_level<2 or not preload("res://src/game/rayman_controller.gd").equipped(player):return result
	var origin:=Vector2i(((player.position-Vector2(0,16))/32).floor())
	var direction:=Vector2i(player.facing,0) if tile.y==origin.y else Vector2i(0,signi(tile.y-origin.y)) if tile.x==origin.x else Vector2i.ZERO
	if direction==Vector2i.ZERO:return result
	for i in [1,2]:
		var extra: Vector2i=tile+direction*i
		if not world.contains(extra):break
		var owner:=preload("res://src/game/lock_rules.gd").owner_at(world,extra)
		if permission.is_valid():
			if not permission.call(extra):continue
		elif not player.developer and owner not in ["",player.actor_key]:continue
		cooldown=0
		var secondary:=apply_single(world,player,action,extra,item_id,true)
		for event in secondary.events:
			if event.type!="punch_started":result.events.append(event)
	cooldown=0.22
	return result

func apply_single(world, player, action: String, tile: Vector2i, item_id: int, chain:=false) -> Dictionary:
	var result := {"accepted": false, "reason": "", "events": []}
	if player.death_time>=0 and player.death_time<2.0:
		result.reason="Respawning"
		return result
	if action not in ["punch", "place", "wrench"]:
		result.reason = "Unsupported action"
		return result
	if cooldown > 0:
		result.reason = "Cooldown"
		return result
	player.world_rules=world.world_effects.get("xenonite",{})
	if not world.contains(tile) or not chain and (Vector2(tile) * 32 + Vector2(16, 16)).distance_to(player.position - Vector2(0, 16)) > float(player.abilities().get("build_range",player.abilities().range) if action=="place" else player.abilities().range):
		result.reason = "Out of reach"
		return result
	var foreground: int = world.tile_at(tile)
	player.world_rules=world.world_effects.get("xenonite",{})
	if action=="place" and runtime.source(item_id)==5640:
		var remote: Dictionary=runtime.automation.remote_target(runtime,world,player)
		if not remote.accepted:return remote
		var placed: Dictionary=apply(world,player,action,tile,int(remote.item))
		if placed.accepted:
			remote.data.count-=1
			placed.events.append({"type":"item_state","tile":remote.tile})
		return placed
	if action=="place" and item_id>=200000 and item_id-200000 in runtime.automation.CRYSTALS and runtime.source(foreground) in runtime.automation.CRYSTALS:
		cooldown=0.22
		return runtime.automation.add_crystal(runtime,world,tile,item_id-200000)
	if action=="place" and item_id>=200000:
		var source := item_id-200000
		if source==6280 and preload("res://src/game/guild_weather.gd").record(world).is_empty():
			return runtime.result(false,"Guild weather can only be placed in a Guild-Locked world.")
		if runtime.is_seed(source):
			cooldown = 0.22
			return runtime.seed_use(world,player,tile,source)
		if runtime.extra.consumable.has(str(source)) or int(Sim.items().get(str(source),[0,0,0,0,0,0,0,0])[7])==8:
			cooldown = 0.3
			return runtime.use_item(world,player,tile,source)
	if action=="punch":
		player.begin_punch(Vector2(tile)*32+Vector2(16,16))
		if preload("res://src/game/source_machine_rules.gd").handles(runtime.source(foreground)):
			var switched: Dictionary=preload("res://src/game/source_machine_rules.gd").toggle(runtime,world,player,tile,"activate",{})
			if not switched.accepted:
				cooldown=0.22
				return switched
			result.events.append_array(switched.events)
		var recovered: Dictionary=runtime.automation.punch(runtime,world,player,tile)
		if recovered.is_empty():recovered=runtime.special.punch(runtime,world,player,tile)
		if not recovered.is_empty():
			cooldown=0.22
			player.punch_time=player.PUNCH_DURATION
			recovered.events.push_front({"type":"punch_started","tile":tile,"item_id":foreground})
			return recovered
		var source := runtime.source(foreground)
		if runtime.recovered.data.calendars.has(str(source)) or source==10656:
			cooldown=0.22
			return {"accepted":true,"reason":"","events":[{"type":"punch_started","tile":tile,"item_id":foreground},{"type":"inspect_requested","tile":tile}]}
		if runtime.is_seed(source) and runtime.growth(world,tile)>=1 or Sim.use_rules.provider.has(str(source)) and float(world.extras.get(runtime.key(world,tile),{}).get("ready",INF))<=runtime.now():
			cooldown = 0.22
			player.punch_time = player.PUNCH_DURATION
			var harvest: Dictionary=runtime.interact(world,player,tile,"harvest",{})
			harvest.events.push_front({"type":"punch_started","tile":tile,"item_id":foreground})
			return harvest
	var behind: bool = (action == "place" and Sim.supported(item_id) and int(Sim.items()[str(item_id-200000)][7]) == 18) or action == "punch" and foreground == 0 and world.background[tile.y*world.size.x+tile.x] != 0
	var current: int = world.background[tile.y*world.size.x+tile.x] if behind else foreground
	var layer := "background" if behind else "foreground"
	if action == "place":
		if runtime.source(item_id)==5814 and not preload("res://src/game/lock_rules.gd").can_place(world,tile,item_id,player.actor_key):
			result.reason="A Guild Lock needs a world without another world-wide lock."
			return result
		if item_id == 5 and world.foreground.has(5):
			result.reason = "This world already has a World Lock."
			return result
		if (not (player.developer and item_id in [2,4]) and item_id not in [1, 3, 5, 6] and not preload("res://src/game/placeable_blocks.gd").supports(item_id) and not preload("res://src/game/simulator_catalog.gd").supported(item_id)) or current != 0:
			result.reason = "Cannot place here"
			return result
		var player_box := Rect2(player.position - Vector2(10, 30), Vector2(20, 30))
		if not behind and player_box.intersects(Rect2(Vector2(tile) * 32, Vector2(32, 32))):
			result.reason = "Player occupies this tile"
			return result
		if behind:
			world.set_background(tile,item_id)
		else:
			world.set_tile(tile, item_id)
			runtime.planted(world,tile,runtime.source(item_id))
		var sim = preload("res://src/game/simulator_catalog.gd")
		result.events.append({"type": "tile_placed", "tile": tile,"layer":layer})
		result.events.append({"type":"item_state","tile":tile})
	elif action == "wrench":
		result.events.append({"type": "inspect_requested", "tile": tile, "item_id": current})
	else:
		var target_x := tile.x*32+16
		if absf(target_x-player.position.x)>4:
			player.facing = 1 if target_x > player.position.x else -1
		player.punch_time = player.PUNCH_DURATION
		result.events.append({"type":"punch_started","tile":tile,"item_id":current,"protected":current in [2,4]})
		if current in [2, 4]:
			cooldown = 0.22
			result.reason = "Main door and bedrock are protected"
			return result
		if current != 0:
			if runtime.source(current)==5814 and not player.developer:
				result.reason="The Guild Lock is permanent. Only developer tools can remove it."
				cooldown=0.22
				return result
			var hits: float = float(world.damage.get(tile, 0)) + player.punch_power()
			var source_id:=runtime.source(current)
			var row: Array=Sim.items().get(str(source_id),[])
			var required:=maxf(1,float(row[8])/6.0) if row.size()>8 else 3.0
			if player.developer:
				required=1
			world.register_damage(tile,hits,required)
			result.events.append({"type":"tile_damaged","tile":tile,"hits":hits,"required":required})
			if hits >= required:
				if behind:
					world.set_background(tile,0)
				else:
					world.set_tile(tile, 0)
					runtime.automation.removed(runtime,world,tile,runtime.source(current))
					if runtime.source(current)==2072:result.events.append({"type":"world_rules","tile":tile})
				world.damage.erase(tile)
				world.damage_required.erase(tile)
				world.extras.erase(runtime.key(world,tile))
				preload("res://src/game/source_machine_rules.gd").removed(world,runtime.source(current),tile)
				result.events.append_array(runtime.source_drops.broken(runtime,world,tile,runtime.source(current)))
				if runtime.source(current) in [16104,16238,226,1276,1278,4884,4992] or Sim.use_rules.weather.has(str(runtime.source(current))):result.events.append(runtime.reward(world,tile,runtime.source(current)))
				result.events.append({"type":"tile_removed","tile":tile,"layer":layer,"item_id":current})
	cooldown = 0.22
	result.accepted = true
	return result

