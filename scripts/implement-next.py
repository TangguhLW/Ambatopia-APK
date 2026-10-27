from pathlib import Path
p=Path('src/game/lock_rules.gd');p.write_text('''extends RefCounted
const Blocks = preload("res://src/game/placeable_blocks.gd")
static func is_lock(item: int) -> bool:
	return item == 5 or Blocks.supports(item) and Blocks.items()[item].get("lock",false)
static func capacity(item: int) -> int:
	return int(Blocks.items()[item].get("area",0)) if Blocks.supports(item) else 0
static func owner_at(world, tile: Vector2i) -> String:
	for record in world.locks:
		if record.area == 0 or record.tiles.has(tile.y*world.size.x+tile.x):
			return record.owner
	return ""
static func coverage(world, origin: Vector2i, count: int) -> Array:
	var result: Array = []
	var queue: Array[Vector2i] = [origin]
	var seen := {}
	while not queue.is_empty() and result.size() < count:
		var tile: Vector2i = queue.pop_front()
		if seen.has(tile) or not world.contains(tile):
			continue
		seen[tile] = true
		if owner_at(world,tile) != "":
			continue
		result.append(tile.y*world.size.x+tile.x)
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			queue.append(tile+direction)
	return result
static func can_place(world, tile: Vector2i, item: int, owner: String) -> bool:
	if not is_lock(item):
		return true
	for record in world.locks:
		if record.area == 0 or capacity(item) == 0 and record.owner != owner:
			return false
	return owner_at(world,tile) in ["",owner]
static func placed(world, tile: Vector2i, item: int, owner: String) -> void:
	if not is_lock(item):
		return
	var count := capacity(item)
	var covered := coverage(world,tile,count) if count > 0 else []
	world.locks.append({"x":tile.x,"y":tile.y,"item":item,"owner":owner,"area":count,"tiles":covered})
static func removed(world, tile: Vector2i) -> void:
	world.locks = world.locks.filter(func(record): return record.x != tile.x or record.y != tile.y)
''')
p=Path('src/game/world_state.gd');s=p.read_text().replace('var damage := {}','var damage := {}\nvar locks: Array = []\nvar bans: Dictionary = {}\nvar protected_spawn := true')
s=s.replace('"schema_version": schema_version,','"locks":locks,"bans":bans,"protected_spawn":protected_spawn,"schema_version": schema_version,')
s=s.replace('\tset_tile(main_door, 4)\n\tset_tile(main_door + Vector2i.DOWN, 2)\n\treturn true','\tlocks = data.get("locks",[]).duplicate(true)\n\tbans = data.get("bans",{}).duplicate(true)\n\tprotected_spawn = data.get("protected_spawn",true)\n\tif protected_spawn:\n\t\tset_tile(main_door, 4)\n\t\tset_tile(main_door + Vector2i.DOWN, 2)\n\treturn true')
p.write_text(s)
p=Path('src/game/player_state.gd');s=p.read_text();s+='\nvar amba := false\n';p.write_text(s)
p=Path('src/network/room_server.gd');s=p.read_text().replace('const Actions =','const Locks = preload("res://src/game/lock_rules.gd")\nvar broadcasts: Dictionary = {}\nconst Actions =')
s=s.replace('\tvar player := Player.new()', '\tif identity.get("role") != "developer" and float(rooms[normalized].world.bans.get(identity.get("id",name),0)) > Time.get_unix_time_from_system():\n\t\treturn {"ok":false,"error":"You are banned from this world for 24 hours."}\n\tvar player := Player.new()',1)
s=s.replace('"god":false,"invisible":false','"moderator":identity.get("settings",{}).get("moderator",false),"god":false,"invisible":false,"amba":false')
s=s.replace('["god","invisible"]','["god","invisible","amba"]')
s=s.replace('state.god_mode = entry.god','state.god_mode = entry.god\n\t\t\t\tstate.amba = entry.amba')
s=s.replace('entry.last_chat = Time.get_ticks_msec()\n\t\t\tevents.append','entry.last_chat = Time.get_ticks_msec()\n\t\t\tif packet.text.begins_with("/"):\n\t\t\t\treturn command(id,packet.text.strip_edges())\n\t\t\tevents.append')
s=s.replace('\t\tif locked_by_other and', '\t\tvar area_owner := Locks.owner_at(room.world,tile)\n\t\tlocked_by_other = locked_by_other or area_owner != "" and area_owner != owner_key(id)\n\t\tif action == "place" and not Locks.can_place(room.world,tile,entry.input.get("item",0),owner_key(id)):\n\t\t\tcontinue\n\t\tif locked_by_other and')
s=s.replace(' and tile != room.world.main_door and tile != room.world.main_door+Vector2i.DOWN:',':')
s=s.replace('\t\t\troom.world.set_tile(tile,0)\n\t\t\tresult.events', '\t\t\troom.world.set_tile(tile,0)\n\t\t\troom.world.protected_spawn = false\n\t\t\tresult.events')
s=s.replace('if event.type == "tile_placed" and item == 5:', 'if event.type == "tile_placed" and Locks.is_lock(item):\n\t\t\t\t\tLocks.placed(room.world,tile,item,owner_key(id))\n\t\t\t\tif event.type == "tile_placed" and Locks.is_lock(item) and Locks.capacity(item) == 0:')
s=s.replace('if event.type == "tile_removed" and room.world.foreground.find(5) == -1:', 'if event.type == "tile_removed":\n\t\t\t\t\tLocks.removed(room.world,tile)\n\t\t\t\tif event.type == "tile_removed" and not room.world.locks.any(func(lock): return lock.area == 0) and not room.world.foreground.has(5):')
s=s.replace('"skin":p.skin_index,','"skin":p.skin_index,"amba":p.amba,')
s+='''
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
	if not entry.developer and not (room.owner == id or room.get("owner_uid","") != "" and room.owner_uid == entry.uid):
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
'''
s=s.replace('world.bans.get(identity.get("id",name),0)', 'world.bans.get(identity.get("id","session:"+str(id)),0)')
p.write_text(s)
p=Path('server/runtime.gd');s=p.read_text().replace('if core.players[id].room == room and peers.has(id):','if (room == "*" or core.players[id].room == room) and peers.has(id) and (not packet.has("target") or int(packet.target) == id):')
s=s.replace('\t\tbroadcast(event.room,event)','\t\tbroadcast(event.room,event)\n\t\tif event.type == "world_exit" and peers.has(int(event.target)):\n\t\t\tpeers[int(event.target)].socket.close(1000,"World owner action")')
p.write_text(s)
p=Path('src/game/world_view.gd');s=p.read_text().replace('match packet.get("type"):', '''match packet.get("type"):
		"world_exit":
			app.network.close()
			app.session.active = false
			app.navigate("worlds")
		"teleport":
			player.position = Vector2(packet.x,packet.y)
			player.velocity = Vector2.ZERO
		"broadcast":
			local_messages.append("[SB] %s (in %s): %s" % [packet.name,packet.world,packet.text])
			chat_history.text = "\\n".join(local_messages.slice(-8))''')
s=s.replace('var target := Vector2(row.x,row.y)','player.amba = row.get("amba",false)\n\t\t\t\t\tvar target := Vector2(row.x,row.y)')
s=s.replace('remote.state.skin_index =', 'remote.state.amba = row.get("amba",false)\n\t\t\t\tremote.state.skin_index =')
p.write_text(s)
p=Path('src/ui/developer.gd');s=p.read_text().replace('["Invisible","invisible"]','["Invisible","invisible"],["Transform Amba","amba"]');s=s.replace('["Warning","warn"]','["Warning","warn"],["Promote to Mod","promote"],["Remove Mod","demote"]');p.write_text(s)
p=Path('tests/suites/ambatopia_ui.gd');s=p.read_text().replace('== 836','== 863').replace('836 source-backed blocks','836 static blocks plus 27 locks');p.write_text(s)
p=Path('src/ui/inventory.gd');s=p.read_text().replace('"original":int(block.id),"local":true','"original":int(block.id),"category":"lock" if block.get("lock",false) else "block","local":true');p.write_text(s)
