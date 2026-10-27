extends RefCounted

const World = preload("res://src/game/world_state.gd")
const Player = preload("res://src/game/player_state.gd")
const Simulation = preload("res://src/game/simulation.gd")
const Locks = preload("res://src/game/lock_rules.gd")
var broadcasts: Dictionary = {}
const Actions = preload("res://src/game/interactions.gd")
var rooms: Dictionary = {}
var players: Dictionary = {}
var events: Array[Dictionary] = []
var simulation := Simulation.new()
var max_players := 64
var item_runtime = preload("res://src/game/item_runtime.gd").new()

func join(id: int, name: String, world_name: String, identity: Dictionary = {}) -> Dictionary:
	var normalized := world_name.strip_edges().to_upper()
	if identity.has("id"):
		for active in players.values():
			if active.uid == identity.id:
				return {"ok":false,"error":"This account is already in a world."}
	if players.size() >= max_players or name.strip_edges().is_empty() or name.length() > 18 or normalized.is_empty() or normalized.length() > 18:
		return {"ok":false,"error":"Invalid profile/world or server full"}
	for letter in normalized:
		if letter not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			return {"ok":false,"error":"World name must use letters and digits"}
	for letter in name:
		if letter.unicode_at(0)<32 or letter.unicode_at(0)==127:
			return {"ok":false,"error":"Invalid player name"}
	if players.has(id):
		leave(id)
	if not rooms.has(normalized):
		if rooms.size()>=64:
			return {"ok":false,"error":"Session world limit reached"}
		var world := World.new()
		world.create_default(normalized)
		rooms[normalized] = {"world":world,"owner":0,"owner_uid":""}
	if identity.get("role") != "developer" and float(rooms[normalized].world.bans.get(identity.get("id","session:"+str(id)),0)) > Time.get_unix_time_from_system():
		return {"ok":false,"error":"You are banned from this world for 24 hours."}
	var player := Player.new()
	player.developer = identity.get("role") == "developer"
	player.skin_index = clampi(int(identity.get("settings",{}).get("skin",0)),0,5)
	player.collected=identity.get("settings",{}).get("collected",{}).duplicate()
	player.position = rooms[normalized].world.spawn_position()
	player.grounded = true
	player.actor_key=identity.get("id","session:"+str(id))
	player.world_rules=rooms[normalized].world.world_effects.get("xenonite",{})
	player.display_name = "@Thaney" if identity.get("role") == "developer" else name.strip_edges()
	players[id] = {"state":player,"room":normalized,"actions":Actions.new(),"input":{"axis":0.0},"seq":-1,"last_input":Time.get_ticks_msec(),"last_chat":-1000,"uid":identity.get("id",""),"developer":identity.get("role") == "developer","moderator":identity.get("settings",{}).get("moderator",false),"god":false,"invisible":false,"amba":false,"muted":false,"joined":Time.get_ticks_msec()}
	if not identity.is_empty():
		for slot in identity.get("outfit",{}):
			var item = identity.outfit[slot]
			if numeric(item):
				player.equip_catalog(int(item))
	return {"ok":true,"type":"welcome","id":id,"world":rooms[normalized].world.serialize(),"players":snapshot(normalized)}

func leave(id: int) -> void:
	if not players.has(id):
		return
	var room: Dictionary = rooms[players[id].room]
	if players[id].uid == "":
		for lock in room.world.locks.duplicate():
			if lock.owner == owner_key(id):
				var tile := Vector2i(lock.x,lock.y)
				room.world.set_tile(tile,0)
				Locks.removed(room.world,tile)
				events.append({"room":players[id].room,"type":"tile","x":tile.x,"y":tile.y,"item":0})
	if room.owner == id and room.get("owner_uid","") == "":
		# Session locks cannot strand a room after its anonymous owner disconnects.
		room.owner = 0
		for y in room.world.size.y:
			for x in room.world.size.x:
				if room.world.tile_at(Vector2i(x,y)) == 5:
					room.world.set_tile(Vector2i(x,y),0)
					events.append({"room":players[id].room,"type":"tile","x":x,"y":y,"item":0})
	players.erase(id)

func accept(id: int, packet: Dictionary) -> bool:
	if not players.has(id) or not packet.get("type") is String:
		return false
	var entry: Dictionary = players[id]
	var state = entry.state
	match packet.type:
		"respawn":
			var now:=Time.get_ticks_msec()
			if now-int(entry.get("last_respawn",-1000))<1000:
				return false
			entry.last_respawn=now
			state.position=rooms[entry.room].world.spawn_position()
			state.velocity=Vector2.ZERO
			state.punch_time=0
			entry.input={"axis":0.0}
		"machine":
			if not numeric(packet.get("x")) or not numeric(packet.get("y")) or not packet.get("command") is String or not packet.get("args",{}) is Dictionary or packet.get("args",{}).size()>6:
				return false
			if not is_finite(float(packet.x)) or not is_finite(float(packet.y)) or float(packet.x)!=int(packet.x) or float(packet.y)!=int(packet.y) or float(packet.x)<0 or float(packet.x)>=100 or float(packet.y)<0 or float(packet.y)>=60:
				return false
			var tile := Vector2i(int(packet.x),int(packet.y))
			var room: Dictionary = rooms[entry.room]
			var public_switch: bool=packet.command in ["activate","toggle"] and preload("res://src/game/source_machine_rules.gd").handles(item_runtime.source(room.world.tile_at(tile))) and room.world.extras.get(item_runtime.key(room.world,tile),{}).get("public",false)
			if (not can_modify(id,tile) and not public_switch) or entry.actions.cooldown>0:
				return false
			entry.actions.cooldown = 0.25
			var result: Dictionary = item_runtime.interact(room.world,state,tile,packet.command,packet.get("args",{}))
			if not result.accepted:
				events.append({"room":entry.room,"type":"notice","target":id,"text":result.reason})
				return false
			publish_item_events(entry.room,id,result.events)
		"developer":
			if not entry.developer:
				return false
			if packet.get("command") in ["god","invisible","amba"] and packet.get("enabled") is bool:
				entry[packet.command] = packet.enabled
				state.god_mode = entry.god
				state.amba = entry.amba
			else:
				return false
		"weather":
			var room: Dictionary = rooms[entry.room]
			var sim = preload("res://src/game/simulator_catalog.gd")
			sim.items()
			if not packet.get("key") is String or not sim.weather_list.any(func(row): return row.k == packet.key):
				return false
			if not entry.developer and room.get("owner_uid","") != "" and room.owner_uid != entry.uid or not entry.developer and room.owner != 0 and room.owner != id and room.get("owner_uid","") == "":
				return false
			room.world.weather = packet.key
			events.append({"room":entry.room,"type":"weather","key":packet.key})
		"input":
			var seq = packet.get("seq")
			var axis = packet.get("axis")
			if not numeric(seq) or float(seq) != int(seq) or seq <= entry.seq or seq > entry.seq+1000 or not numeric(axis) or not is_finite(float(axis)) or absf(axis) > 1:
				return false
			var action = packet.get("action","none")
			if action not in ["none","punch","place","wrench"] or not packet.get("jump",false) is bool or not packet.get("direct",false) is bool:
				return false
			for key in ["x","y","item"]:
				if not numeric(packet.get(key,0)) or float(packet.get(key,0)) != int(packet.get(key,0)):
					return false
			entry.seq = int(seq)
			entry.last_input = Time.get_ticks_msec()
			entry.input = {"axis":float(axis),"jump_pressed":entry.input.get("jump_pressed",false) or packet.get("jump",false),"action":action,"target":Vector2i(packet.get("x",0),packet.get("y",0)),"item":int(packet.get("item",0)),"direct":packet.get("direct",false)}
		"chat":
			if entry.muted:
				return false
			if not packet.get("text") is String or packet.text.length()>80 or packet.text.strip_edges().is_empty() or Time.get_ticks_msec()-entry.last_chat < 700:
				return false
			entry.last_chat = Time.get_ticks_msec()
			if packet.text.begins_with("/"):
				return command(id,packet.text.strip_edges())
			events.append({"room":entry.room,"type":"chat","id":id,"name":state.display_name,"text":packet.text.strip_edges()})
		"outfit":
			if not preload("res://src/network/cosmetic_options.gd").valid(packet.get("item_options",{})):return false
			var skin = packet.get("skin",0)
			if not numeric(skin) or skin != int(skin) or skin < 0 or skin > 5:
				return false
			var outfit = packet.get("equipment")
			if not outfit is Dictionary or outfit.size()>10:
				return false
			var candidate := Player.new()
			for slot in outfit:
				if not numeric(outfit[slot]) or float(outfit[slot]) != int(outfit[slot]):
					return false
				var item: Dictionary = preload("res://src/game/item_catalog.gd").summary(int(outfit[slot]))
				if item.is_empty() or item.slot != slot or not candidate.equip_catalog(int(outfit[slot])):
					return false
			state.catalog_equipment = candidate.catalog_equipment
			state.skin_index = int(skin)
			state.item_options=packet.get("item_options",{}).duplicate(true)
		_:
			return false
	return true

var projectile_broadcast_clock=0.0
func step(dt: float) -> void:
	projectile_broadcast_clock+=dt
	var broadcast_projectiles=projectile_broadcast_clock>=0.05
	if broadcast_projectiles:
		projectile_broadcast_clock=0
	for name in rooms:
		rooms[name].world.tick_damage(dt)
		var participants: Array=[]
		for entry in players.values():
			if entry.room==name:
				participants.append(entry.state)
		var weather_events: Array=preload("res://src/game/source_machine_rules.gd").tick(item_runtime,rooms[name].world)
		if not weather_events.is_empty():publish_item_events(name,0,weather_events)
		var automation_events: Array=item_runtime.automation.tick(item_runtime,rooms[name].world,dt)
		if not automation_events.is_empty():publish_item_events(name,0,automation_events)
		if item_runtime.special.tick(item_runtime,rooms[name].world,participants,dt):
			rooms[name].projectiles_dirty=true
		if rooms[name].get("projectiles_dirty",false) and broadcast_projectiles:
			rooms[name].projectiles_dirty=false
			events.append({"room":name,"type":"projectiles","shots":rooms[name].world.world_effects.get("projectiles",[]) .duplicate(true)})
	for id in players:
		var entry: Dictionary = players[id]
		var room: Dictionary = rooms[entry.room]
		var state = entry.state
		if Time.get_ticks_msec()-entry.last_input > 250:
			entry.input = {"axis":0.0}
		simulation.step(room.world,state,entry.input,dt)
		if item_runtime.collect(room.world,state):
			events.append({"room":entry.room,"type":"drops","drops":room.world.drops})
		entry.input.jump_pressed = false
		entry.actions.tick(dt)
		var action: String = entry.input.get("action","none")
		if action == "none":
			continue
		var tile: Vector2i = entry.input.get("target",Vector2i.ZERO)
		if action == "punch" and entry.input.get("direct",false):
			tile = Vector2i((state.position+Vector2(state.facing*36,-16))/32)
		var locked_by_other: bool = room.get("owner_uid","") != "" and room.owner_uid != entry.uid or room.get("owner_uid","") == "" and room.owner != 0 and room.owner != id
		var area_owner := Locks.owner_at(room.world,tile)
		locked_by_other = locked_by_other or area_owner != "" and area_owner != owner_key(id)
		if action == "place" and not Locks.can_place(room.world,tile,entry.input.get("item",0),owner_key(id)):
			continue
		if locked_by_other and not entry.developer and action != "wrench":
			if action == "punch" and entry.actions.cooldown <= 0:
				state.begin_punch(Vector2(tile)*32+Vector2(16,16))
				var machine_state: Dictionary=room.world.extras.get(item_runtime.key(room.world,tile),{})
				if machine_state.get("public",false) and preload("res://src/game/source_machine_rules.gd").handles(item_runtime.source(room.world.tile_at(tile))):
					var toggled: Dictionary=item_runtime.interact(room.world,state,tile,"activate",{})
					if toggled.accepted:publish_item_events(entry.room,id,toggled.events)
				player_punch(entry,tile)
				entry.actions.cooldown = 0.22
				events.append({"room":entry.room,"type":"effect","id":id,"event":{"type":"punch_started","tile":[tile.x,tile.y]}})
			continue
		var result: Dictionary = entry.actions.apply(room.world,state,action,tile,entry.input.get("item",0),func(extra):return can_modify(id,extra))
		if not result.accepted and result.reason not in ["","Cooldown","Out of reach","Main door and bedrock are protected"] and entry.actions.cooldown>0:
			events.append({"room":entry.room,"type":"notice","target":id,"text":result.reason})
		if entry.developer and action == "punch" and result.reason == "Main door and bedrock are protected":
			room.world.set_tile(tile,0)
			room.world.protected_spawn = false
			result.events.append({"type":"tile_removed","tile":tile})
		for event in result.events:
			if event.type=="punch_started":player_punch(entry,event.tile)
			if event.type == "weather_changed":
				events.append({"room":entry.room,"type":"weather","key":room.world.weather})
			if event.type in ["tile_placed","tile_removed"]:
				var layer: String = event.get("layer","foreground")
				var item: int = room.world.background[tile.y*room.world.size.x+tile.x] if layer == "background" else room.world.tile_at(tile)
				if event.type == "tile_placed" and Locks.is_lock(item):
					Locks.placed(room.world,tile,item,owner_key(id))
				if event.type == "tile_placed" and Locks.is_lock(item) and Locks.capacity(item) == 0:
					room.owner = id
					room.owner_uid = entry.uid
					events.append({"room":entry.room,"type":"chat","id":id,"name":"World","text":"This world has been locked by " + state.display_name+"."})
				if event.type == "tile_removed":
					Locks.removed(room.world,tile)
				if event.type == "tile_removed" and not room.world.locks.any(func(lock): return lock.area == 0) and not room.world.foreground.has(5):
					room.owner = 0
					room.owner_uid = ""
				events.append({"room":entry.room,"type":"tile","x":tile.x,"y":tile.y,"item":item,"layer":layer})
			publish_item_events(entry.room,id,[event],false)

func snapshot(room_name: String) -> Array:
	var result: Array = []
	for id in players:
		var entry: Dictionary = players[id]
		if entry.room != room_name:
			continue
		if entry.invisible:
			continue
		var p = entry.state
		result.append({"id":id,"name":p.display_name,"x":snappedf(p.position.x,0.01),"y":snappedf(p.position.y,0.01),"vx":p.velocity.x,"vy":p.velocity.y,"facing":p.facing,"grounded":p.grounded,"punch":p.punch_time,"equipment":p.catalog_equipment,"skin":p.skin_index,"amba":p.amba,"modifiers":p.modifiers,"ack":entry.seq})
		result[-1].burn=p.burn_time
		result[-1].item_options=preload("res://src/network/cosmetic_options.gd").sanitized(p.item_options)
		result[-1].punch_dx=p.punch_direction.x;result[-1].punch_dy=p.punch_direction.y;result[-1].punch_distance=clampf(p.punch_distance,0,160)
		result[-1].death_time=p.death_time;result[-1].death_epoch=p.death_epoch
		result[-1].death_x=p.death_origin.x;result[-1].death_y=p.death_origin.y
	return result

func can_modify(id: int,tile: Vector2i) -> bool:
	var entry: Dictionary = players[id]
	var room: Dictionary = rooms[entry.room]
	if entry.developer:
		return true
	var owner: String = room.get("owner_uid","")
	if owner!="" and owner!=entry.uid or owner=="" and room.owner!=0 and room.owner!=id:
		return false
	var area := Locks.owner_at(room.world,tile)
	return area in ["",owner_key(id)]

func publish_item_events(room_name: String,id: int,rows: Array,tiles: bool = true) -> void:
	var world = rooms[room_name].world
	for row in rows:
		var tile: Vector2i = row.tile
		if row.type=="weather_changed":events.append({"room":room_name,"type":"weather","key":world.weather})
		if row.type=="world_rules":
			events.append({"room":room_name,"type":"world_rules","rules":world.world_effects.get("xenonite",{})})
		if row.type=="item_state" or row.type in ["tile_placed","tile_removed","reward"]:
			events.append({"room":room_name,"type":"item_state","x":tile.x,"y":tile.y,"data":world.extras.get(item_runtime.key(world,tile),{}),"drops":world.drops})
		if tiles and row.type in ["tile_placed","tile_removed"]:
			events.append({"room":room_name,"type":"tile","x":tile.x,"y":tile.y,"item":world.background[tile.y*world.size.x+tile.x] if row.get("layer","")=="background" else world.tile_at(tile),"layer":row.get("layer","foreground")})
		if row.type=="world_changed":
			events.append({"room":room_name,"type":"world_state","world":world.serialize()})
		var effect: Dictionary = row.duplicate(true)
		effect.tile = [tile.x,tile.y]
		events.append({"room":room_name,"type":"effect","id":id,"event":effect})

func numeric(value: Variant) -> bool:
	return value is int or value is float

func owner_key(id: int) -> String:
	return players[id].uid if players[id].uid != "" else "session:"+str(id)

func command(id: int, text: String) -> bool:
	var entry: Dictionary = players[id]
	var parts := text.split(" ",false,1)
	if parts.size() != 2:
		return false
	var argument := parts[1].strip_edges()
	if parts[0].to_lower() == "/sb":
		var key := owner_key(id)
		var now := Time.get_unix_time_from_system()
		if now < float(broadcasts.get(key,0)) or argument.is_empty():
			events.append({"room":entry.room,"type":"notice","target":id,"text":"Super Broadcast cooldown: 30 minutes."})
			return false
		broadcasts[key] = now+1800
		events.append({"room":"*","type":"broadcast","name":entry.state.display_name,"world":entry.room,"text":argument})
		return true
	if parts[0].to_lower() not in ["/kick","/pull","/ban"]:
		return false
	var room: Dictionary = rooms[entry.room]
	if not entry.developer and not entry.moderator and not (room.owner == id or room.get("owner_uid","") != "" and room.owner_uid == entry.uid):
		return false
	for other in players:
		var target: Dictionary = players[other]
		if other == id or target.room != entry.room or target.state.display_name.trim_prefix("@").to_lower() != argument.trim_prefix("@").to_lower() or target.developer:
			continue
		if parts[0].to_lower() == "/pull":
			target.state.position = entry.state.position
			target.state.velocity = Vector2.ZERO
			events.append({"room":entry.room,"type":"teleport","target":other,"x":target.state.position.x,"y":target.state.position.y})
		else:
			if parts[0].to_lower() == "/ban":
				room.world.bans[owner_key(other)] = Time.get_unix_time_from_system()+86400
			events.append({"room":entry.room,"type":"world_exit","target":other,"text":"The world owner removed you from this world."})
		return true
	return false

func player_punch(entry: Dictionary,tile: Vector2i) -> void:
	var world=rooms[entry.room].world
	if preload("res://src/game/source_machine_rules.gd").flags(world).punch:return
	for other in players.values():
		if other==entry or other.room!=entry.room or other.state.god_mode:continue
		if other.state.position.distance_to(Vector2(tile)*32+Vector2(16,32))<24 and entry.state.position.distance_to(other.state.position)<96:
			item_runtime.recovered.infect(world,entry.state,other.state)
			other.state.knockback=Vector2(entry.state.facing*(250 if entry.state.abilities().get("strong_punch",false) else 100),0)
