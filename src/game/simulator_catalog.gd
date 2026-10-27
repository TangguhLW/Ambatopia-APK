extends RefCounted
static var rows: Dictionary = {}
static var use_rules: Dictionary = {}
static var weather_list: Array = []
static var sprites: Dictionary = {}
static var textures: Dictionary = {}
static var seed_icons: Dictionary = {}
static var local_sprites: Dictionary={}
const SLOTS = ["hat","shirt","pants","feet","face","hand","back","hair","neck","artifact"]
static func slot(id: int) -> String:
	items()
	var value := int(use_rules.cloth.get(str(id),-1))
	return SLOTS[value] if value>=0 and value<SLOTS.size() else ""
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
		var item_category: String = "clothing" if use_rules.cloth.has(key) else category(row)
		if filter != "" and filter != item_category:
			continue
		if text != "" and text != key and text.to_lower() not in str(row[0]).to_lower():
			continue
		result.append({"id":int(key),"name":row[0],"category":item_category,"simulator":true})
	return result
static func supported(world_id: int) -> bool:
	var id := str(world_id-200000)
	if not items().has(id) or int(id) in [0,1,6,7,8,9,18,32]:
		return false
	var row: Array = rows[id]
	return int(row[7]) != 3 and not use_rules.cloth.has(id)
static func collision(world_id: int) -> bool:
	if int(items()[str(world_id-200000)][7]) == 19:
		return false
	return int(items()[str(world_id-200000)][6]) == 1
static func sprite(id: int) -> Texture2D:
	if sprites.has(id):
		return sprites[id]
	var row: Array = items().get(str(id),[])
	if row.is_empty():
		return null
	if local_sprites.is_empty() and FileAccess.file_exists("res://data/local-sprite-overrides.json"):
		var native_map=JSON.parse_string(FileAccess.get_file_as_string("res://data/local-sprite-overrides.json"))
		if native_map is Dictionary:local_sprites=native_map.get("items",{})
	if local_sprites.has(str(id)):
		var entry: Array=local_sprites[str(id)]
		var local_path: String="res://"+str(entry[0])
		if not ResourceLoader.exists(local_path):
			push_error("Mapped local sprite is missing: "+local_path)
			return null
		if not textures.has(local_path):
			if textures.size()>=8:textures.erase(textures.keys()[0])
			textures[local_path]=load(local_path)
		var native_image:=AtlasTexture.new()
		native_image.filter_clip=true
		native_image.atlas=textures[local_path]
		var frame: Array=entry[1]
		native_image.region=Rect2(frame[0],frame[1],frame[2],frame[3])
		if sprites.size()>=128:sprites.erase(sprites.keys()[0])
		sprites[id]=native_image
		return native_image
	if int(row[7])==19:
		if seed_icons.is_empty():
			seed_icons=JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/seed-icons.json"))
		if seed_icons.has(str(id)):
			var image:=AtlasTexture.new()
			image.filter_clip=true
			image.atlas=load("res://assets/ambatopia/seed-icons.png")
			image.region=Rect2(seed_icons[str(id)][0],seed_icons[str(id)][1],16,16)
			if sprites.size()>=128:
				sprites.erase(sprites.keys()[0])
			sprites[id]=image
			return image
	var path := "res://assets/simulator/atlas/"+str(row[1])+".png"
	if not ResourceLoader.exists(path):
		return null
	if not textures.has(path):
		if textures.size() >= 8:
			textures.erase(textures.keys()[0])
		textures[path] = load(path)
	var atlas := AtlasTexture.new()
	atlas.filter_clip=true
	atlas.atlas = textures[path]
	atlas.region = Rect2(int(row[2])*32,int(row[3])*32,32,32)
	if sprites.size() >= 128:
		sprites.erase(sprites.keys()[0])
	sprites[id] = atlas
	return atlas
