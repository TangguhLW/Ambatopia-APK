from pathlib import Path
p=Path('src/game/simulator_catalog.gd');p.write_text('''extends RefCounted
static var rows: Dictionary = {}
static var use_rules: Dictionary = {}
static var weather_list: Array = []
static var textures: Dictionary = {}
static func items() -> Dictionary:
	if rows.is_empty():
		rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/items.json"))
		use_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/use.json"))
		weather_list = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/weather.json"))
	return rows
static func category(row: Array) -> String:
	return {3:"lock",17:"block",18:"background",19:"seed",20:"clothing",8:"consumable"}.get(int(row[7]),"other")
static func query(text: String, filter: String = "") -> Array:
	var result: Array = []
	for key in items():
		var row: Array = rows[key]
		if filter != "" and filter != category(row):
			continue
		if text != "" and text != key and text.to_lower() not in str(row[0]).to_lower():
			continue
		result.append({"id":int(key),"name":row[0],"category":category(row),"simulator":true})
	return result
static func supported(world_id: int) -> bool:
	var id := str(world_id-200000)
	if not items().has(id) or int(id) in [6,7,8,9]:
		return false
	var row: Array = rows[id]
	return int(row[7]) in [17,18] or use_rules.weather.has(id) or use_rules.provider.has(id)
static func collision(world_id: int) -> bool:
	return int(items()[str(world_id-200000)][6]) == 1
static func sprite(id: int) -> Texture2D:
	var row: Array = items().get(str(id),[])
	if row.is_empty():
		return null
	var path := "res://assets/simulator/atlas/"+str(row[1])+".png"
	if not ResourceLoader.exists(path):
		return null
	if not textures.has(path):
		if textures.size() >= 8:
			textures.erase(textures.keys()[0])
		textures[path] = load(path)
	var atlas := AtlasTexture.new()
	atlas.atlas = textures[path]
	atlas.region = Rect2(int(row[2])*32,int(row[3])*32,32,32)
	return atlas
''')
p=Path('src/ui/inventory.gd');s=p.read_text().replace('["Catalog","catalog"]','["Catalog","catalog"],["Simulator","simulator"]')
s=s.replace('\telse:\n\t\tvar slot :=', '\telif mode == "simulator":\n\t\tentries = preload("res://src/game/simulator_catalog.gd").query(search.text,"" if category_filter.selected == 0 else category_filter.get_item_text(category_filter.selected))\n\telse:\n\t\tvar slot :=')
s=s.replace('button.icon = Catalog.sprite(entry.original)', 'button.icon = preload("res://src/game/simulator_catalog.gd").sprite(int(entry.id)) if entry.get("simulator",false) else Catalog.sprite(entry.original)')
s=s.replace('if entry.get("local",false):\n\t\t\t\titem_selected.emit(entry.id)', '''if entry.get("simulator",false):
				var id := int(entry.id)
				var sim = preload("res://src/game/simulator_catalog.gd")
				if preload("res://src/game/placeable_blocks.gd").supports(100000+id) and entry.category == "lock":
					item_selected.emit(100000+id)
				elif sim.supported(200000+id):
					item_selected.emit(200000+id)
				elif id in [6,7,8,9]:
					detail.text = "Main Door and Bedrock cannot be taken."
				elif not Catalog.summary(id).is_empty() and entry.name == Catalog.summary(id).name:
					activate_item(id,Time.get_ticks_msec())
				else:
					detail.text = entry.name + " · behavior not implemented yet"
			elif entry.get("local",false):
				item_selected.emit(entry.id)''')
p.write_text(s)
p=Path('src/game/world_state.gd');s=p.read_text().replace('var protected_spawn := true','var protected_spawn := true\nvar weather := "sunny"')
s=s.replace('"locks":locks,','"weather":weather,"locks":locks,')
s=s.replace('and not preload("res://src/game/placeable_blocks.gd").supports(int(id))','and not preload("res://src/game/placeable_blocks.gd").supports(int(id)) and not preload("res://src/game/simulator_catalog.gd").supported(int(id))')
s=s.replace('\tlocks = data.get', '\tweather = str(data.get("weather","sunny"))\n\tlocks = data.get')
s=s.replace('return tile_at(tile) not in [0, 4, 7]','var item := tile_at(tile)\n\tif preload("res://src/game/simulator_catalog.gd").supported(item):\n\t\treturn preload("res://src/game/simulator_catalog.gd").collision(item)\n\treturn item not in [0, 4, 7]')
p.write_text(s)
p=Path('src/game/interactions.gd');s=p.read_text().replace('and not preload("res://src/game/placeable_blocks.gd").supports(item_id)', 'and not preload("res://src/game/placeable_blocks.gd").supports(item_id) and not preload("res://src/game/simulator_catalog.gd").supported(item_id)')
s=s.replace('\t\tworld.set_tile(tile, item_id)', '''		world.set_tile(tile, item_id)
		var sim = preload("res://src/game/simulator_catalog.gd")
		if sim.supported(item_id) and sim.use_rules.weather.has(str(item_id-200000)):
			world.weather = sim.use_rules.weather[str(item_id-200000)].k
			result.events.append({"type":"weather_changed","tile":tile,"weather":world.weather})''')
p.write_text(s)
p=Path('src/network/room_server.gd');s=p.read_text().replace('\t\t"input":','''		"weather":
			var room: Dictionary = rooms[entry.room]
			var sim = preload("res://src/game/simulator_catalog.gd")
			sim.items()
			if not packet.get("key") is String or not sim.weather_list.any(func(row): return row.k == packet.key):
				return false
			if not entry.developer and room.get("owner_uid","") != "" and room.owner_uid != entry.uid or not entry.developer and room.owner != 0 and room.owner != id and room.get("owner_uid","") == "":
				return false
			room.world.weather = packet.key
			events.append({"room":entry.room,"type":"weather","key":packet.key})
		"input":''')
s=s.replace('\t\tfor event in result.events:', '\t\tfor event in result.events:\n\t\t\tif event.type == "weather_changed":\n\t\t\t\tevents.append({"room":entry.room,"type":"weather","key":room.world.weather})')
p.write_text(s)
p=Path('src/game/world_view.gd');s=p.read_text().replace('\tbackdrop.camera_offset =', '\tbackdrop.weather = world.weather\n\tbackdrop.camera_offset =')
s=s.replace('\t\t\t\tif preload("res://src/game/placeable_blocks.gd").supports(item_id):','''				if preload("res://src/game/simulator_catalog.gd").supported(item_id):
					var sprite: Texture2D = preload("res://src/game/simulator_catalog.gd").sprite(item_id-200000)
					if sprite != null:
						draw_texture_rect(sprite,rect,false)
					continue
				if preload("res://src/game/placeable_blocks.gd").supports(item_id):''')
s=s.replace('\tcolumn.add_child(UI.button("Options",', '''	var weather_picker := OptionButton.new()
	weather_picker.custom_minimum_size.y = 48
	weather_picker.fit_to_longest_item = false
	weather_picker.clip_text = true
	var sim = preload("res://src/game/simulator_catalog.gd")
	sim.items()
	for row in sim.weather_list:
		weather_picker.add_item(row.n)
		if row.k == world.weather:
			weather_picker.select(weather_picker.item_count-1)
	weather_picker.item_selected.connect(func(index):
		if shared:
			app.network.send({"type":"weather","key":sim.weather_list[index].k})
		else:
			world.weather = sim.weather_list[index].k)
	column.add_child(weather_picker)
	column.add_child(UI.button("Options",''')
s=s.replace('match packet.get("type"):', 'match packet.get("type"):\n\t\t"weather":\n\t\t\tworld.weather = packet.key')
p.write_text(s)
p=Path('src/ui/background.gd');s=p.read_text().replace('var elapsed :=','var weather := "sunny"\nvar weather_key := ""\nvar weather_texture: Texture2D\nvar elapsed :=')
s=s.replace('\tdraw_rect(Rect2(Vector2.ZERO,view),', '''	if weather != "sunny" and not menu_mode:
		if weather_key != weather:
			weather_key = weather
			var path := "res://assets/simulator/weather/"+weather+".jpg"
			weather_texture = load(path) if ResourceLoader.exists(path) else null
		if weather_texture != null:
			draw_texture_rect(weather_texture,Rect2(Vector2.ZERO,view),false)
			return
	draw_rect(Rect2(Vector2.ZERO,view),''')
p.write_text(s)
p=Path('scripts/build.ps1');s=p.read_text().replace("+ '/*.json'", "+ '/*.json,data/simulator/*.json'");p.write_text(s)
p=Path('server/runtime.gd');s=p.read_text().replace('\t\t\tentry.muted =','\t\t\tentry.moderator = row.settings.get("moderator",false)\n\t\t\tentry.muted =');p.write_text(s)
p=Path('src/network/room_server.gd');s=p.read_text().replace('if not entry.developer and not (room.owner == id','if not entry.developer and not entry.moderator and not (room.owner == id');p.write_text(s)
p=Path('server/accounts.mjs');s=p.read_text().replace("if(!result || result.banned_until", "if(!result || !user.app_metadata?.game_provisioned && !(result.role==='developer' && result.amba_id==='Thaney') || result.banned_until")
p.write_text(s)
