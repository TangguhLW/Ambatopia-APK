extends RefCounted

const TILE := 32
var schema_version := 1
var name := "START"
var size := Vector2i(100, 60)
var ground_y := 24
var foreground := PackedInt32Array()
var background := PackedInt32Array()
var main_door := Vector2i(50, 23)
var damage := {}
var damage_required := {}
var damage_ttl: Dictionary={}
const CRACK_RESET_SECONDS:=5.0

func register_damage(tile: Vector2i,hits: float,required: float) -> void:
	damage[tile]=hits;damage_required[tile]=required
	damage_ttl[tile]=CRACK_RESET_SECONDS

func tick_damage(dt: float) -> void:
	for tile in damage_ttl.keys():
		damage_ttl[tile]=maxf(0,float(damage_ttl[tile])-maxf(0,dt))
		if damage_ttl[tile]<=0 or not damage.has(tile):
			damage.erase(tile);damage_required.erase(tile);damage_ttl.erase(tile)
var locks: Array = []
var bans: Dictionary = {}
var protected_spawn := true
var weather := "sunny"
var extras: Dictionary = {}
var drops: Array = []
var next_drop := 0
var world_effects: Dictionary = {}
var visual_revision := 0
var visual_epoch := 0
var visual_chunks: Dictionary={}

func create_default(world_name: String) -> void:
	visual_epoch+=1
	visual_chunks.clear()
	main_door=Vector2i(50,23)
	locks.clear()
	bans.clear()
	damage.clear()
	damage_required.clear()
	damage_ttl.clear()
	protected_spawn = true
	weather = "sunny"
	extras.clear()
	drops.clear()
	world_effects.clear()
	next_drop = 0
	name = world_name
	foreground.resize(size.x * size.y)
	background.resize(size.x * size.y)
	foreground.fill(0)
	background.fill(0)
	visual_revision+=1
	var terrain := RandomNumberGenerator.new()
	terrain.seed = world_name.hash()
	for y in range(ground_y, size.y):
		for x in size.x:
			var item := 1
			if y >= size.y - 6:
				item = 2
			elif y >= size.y - 11 and terrain.randf() < 0.28:
				item = 7
			elif y > ground_y + 2 and terrain.randf() < 0.09:
				item = 3
			foreground[y*size.x+x]=item
			background[y*size.x+x]=200014
	set_tile(main_door, 4)
	set_tile(main_door + Vector2i.DOWN, 2)

func contains(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x < size.x and tile.y < size.y

func tile_at(tile: Vector2i) -> int:
	return foreground[tile.y * size.x + tile.x] if contains(tile) else 2

func set_tile(tile: Vector2i, item_id: int) -> void:
	if contains(tile):
		foreground[tile.y * size.x + tile.x] = item_id
		damage.erase(tile)
		damage_required.erase(tile)
		damage_ttl.erase(tile)
		mark_visual(tile)

func mark_visual(tile: Vector2i) -> void:
	visual_revision+=1
	for y in range(maxi(0,tile.y-1),mini(size.y,tile.y+2)):
		for x in range(maxi(0,tile.x-1),mini(size.x,tile.x+2)):
			visual_chunks[Vector2i(x/16,y/16)]=visual_revision

func set_background(tile: Vector2i,item_id: int) -> void:
	if not contains(tile):return
	background[tile.y*size.x+tile.x]=item_id
	damage.erase(tile)
	damage_required.erase(tile)
	damage_ttl.erase(tile)
	mark_visual(tile)

func solid(tile: Vector2i) -> bool:
	var item := tile_at(tile)
	if item>=100000 and item<200000:return preload("res://src/game/simulator_catalog.gd").collision(item+100000)
	if preload("res://src/game/simulator_catalog.gd").supported(item):
		return preload("res://src/game/simulator_catalog.gd").collision(item)
	return item not in [0, 4, 7]

func spawn_position() -> Vector2:
	for offset in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]:
		var tile: Vector2i = main_door + offset
		if contains(tile) and not solid(tile) and not solid(tile + Vector2i.UP):
			return Vector2(tile.x * TILE + 16, (tile.y + 1) * TILE)
	return Vector2(main_door.x * TILE + 16, main_door.y * TILE)

func serialize() -> Dictionary:
	return {"extras":extras,"drops":drops,"next_drop":next_drop,"world_effects":world_effects,"weather":weather,"locks":locks,"bans":bans,"protected_spawn":protected_spawn,"schema_version": schema_version, "name": name, "size": [size.x, size.y], "foreground": Array(foreground), "background": Array(background), "main_door": [main_door.x, main_door.y]}

func restore(data: Dictionary) -> bool:
	var dimensions = data.get("size", [])
	if data.get("schema_version") != 1 or not dimensions is Array or dimensions.size() != 2:
		return false
	if not numeric(dimensions[0]) or not numeric(dimensions[1]) or float(dimensions[0]) != 100 or float(dimensions[1]) != 60:
		return false
	var tiles = data.get("foreground", [])
	var backs = data.get("background", [])
	if not tiles is Array or tiles.size() != 6000 or not backs is Array or backs.size() != 6000:
		return false
	for layer in [tiles, backs]:
		for id in layer:
			if not numeric(id):
				return false
			if float(id) != int(id) or (int(id) not in range(8) and not preload("res://src/game/placeable_blocks.gd").supports(int(id)) and not preload("res://src/game/simulator_catalog.gd").supported(int(id))):
				return false
	var door = data.get("main_door", [])
	if not door is Array or door.size() != 2:
		return false
	if not numeric(door[0]) or not numeric(door[1]) or float(door[0])!=int(door[0]) or float(door[1])!=int(door[1]) or int(door[0])<0 or int(door[0])>=100 or int(door[1])<0 or int(door[1])>=59:
		return false
	name = str(data.get("name", "START"))
	main_door = Vector2i(int(door[0]),int(door[1]))
	foreground = PackedInt32Array(tiles)
	damage.clear();damage_required.clear();damage_ttl.clear()
	background = PackedInt32Array(backs)
	visual_revision += 1
	visual_epoch+=1
	visual_chunks.clear()
	weather = str(data.get("weather","sunny"))
	if not data.get("extras",{}) is Dictionary or not data.get("drops",[]) is Array or data.get("drops",[]).size()>256:
		return false
	if not data.get("world_effects",{}) is Dictionary or data.get("extras",{}).size()>6000:
		return false
	for key in data.get("extras",{}):
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=6000 or not data.extras[key] is Dictionary:
			return false
	for drop in data.get("drops",[]):
		if not drop is Dictionary:
			return false
		for field in ["uid","id","amount","x","y"]:
			if not numeric(drop.get(field)) or not is_finite(float(drop[field])):
				return false
		if int(drop.amount)<1 or int(drop.amount)>200 or not preload("res://src/game/simulator_catalog.gd").items().has(str(int(drop.id))):
			return false
	extras = data.get("extras",{}).duplicate(true)
	drops = data.get("drops",[]).duplicate(true)
	world_effects = data.get("world_effects",{}).duplicate(true)
	next_drop = maxi(0,int(data.get("next_drop",0)))
	locks = data.get("locks",[]).duplicate(true)
	bans = data.get("bans",{}).duplicate(true)
	protected_spawn = data.get("protected_spawn",true)
	if protected_spawn:
		set_tile(main_door, 4)
		set_tile(main_door + Vector2i.DOWN, 2)
	return true

func numeric(value: Variant) -> bool:
	return value is int or value is float
