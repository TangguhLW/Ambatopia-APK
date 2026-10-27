extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
const MachineAnimation=preload("res://src/game/machine_animation.gd")
const LEGACY={1:2,2:8,3:10,4:6,5:242,6:108,7:4}
const EIGHT=[Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
const FOUR=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
var tables: Dictionary={}
var sprites: Dictionary={}
var cells: Dictionary={}
var revision := -1
var world_identity := 0
static var weather_ids: Dictionary={}

static func weather_id(key: String) -> int:
	if weather_ids.is_empty():
		Sim.items()
		for entry in Sim.use_rules.weather.values():
			var name: String=preload("res://src/game/source_blasts.gd").weather_key(int(entry.w))
			if not weather_ids.has(name):weather_ids[name]=int(entry.w)
	return int(weather_ids.get(key,4))

static func source(id: int) -> int:
	return id-200000 if id>=200000 else id-100000 if id>=100000 else int(LEGACY.get(id,-1))

static func animated(id: int) -> bool:
	var original:=id-200000 if id>=200000 else id-100000 if id>=100000 else int(LEGACY.get(id,-1))
	var row: Array=Sim.items().get(str(original),[])
	return MachineAnimation.handles(original) or row.size()>13 and int(row[13])==25

func animation_texture(world,tile: Vector2i,id: int,ms: int) -> Texture2D:
	var original:=source(id)
	if not MachineAnimation.handles(original):return texture(world,tile,id)
	var base: Texture2D=Sim.sprite(original)
	if base==null:return null
	var row: Array=Sim.items()[str(original)]
	var cell_index:=variant(world,tile,id,false)
	var start: Vector2=base.region.position/32+Vector2(cell_index&7,cell_index>>3)
	var weather:=weather_id(world.weather)
	var enabled: bool=world.extras.get(str(tile.y*world.size.x+tile.x),{}).get("enabled",false)
	var point:=MachineAnimation.cell(original,row,Vector2i(start),int(base.atlas.get_width()/32),enabled,ms,weather)
	var key: String="anim:%s:%s:%s"%[original,point.x,point.y]
	if not sprites.has(key):
		var atlas:=AtlasTexture.new()
		atlas.atlas=base.atlas;atlas.filter_clip=true
		atlas.region=Rect2(Vector2(point)*32,Vector2(32,32))
		if sprites.size()>=256:sprites.erase(sprites.keys()[0])
		sprites[key]=atlas
	return sprites[key]

static func rainbow(time: float,tile: Vector2i) -> Color:
	# The source marks rainbow material; the four-second cycle is an unmeasured adaptation.
	return Color.from_hsv(fposmod(time/4.0+float(tile.x+tile.y)*0.035,1.0),0.78,1.0)

func variant(world,tile: Vector2i,id: int,behind: bool) -> int:
	if tables.is_empty():
		tables=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain-adjacency.json"))
	var original:=source(id)
	var row: Array=Sim.items().get(str(original),[])
	if row.is_empty() or int(row[4]) not in [2,5]:
		return 0
	var directions: Array=EIGHT if int(row[4])==2 else FOUR
	var mask:=0
	for i in directions.size():
		var neighbor: Vector2i=tile+directions[i]
		var matches: bool=not world.contains(neighbor)
		if not matches:
			var other: int=world.background[neighbor.y*world.size.x+neighbor.x] if behind else world.tile_at(neighbor)
			var other_source:=source(other)
			matches=other_source==original or other_source in {2:[5032],5032:[2],8:[3760],3760:[8,7372],7372:[3760]}.get(original,[])
		if matches:
			mask|=1<<i
	return int(tables.eight[mask] if int(row[4])==2 else tables.four[mask])

func texture(world,tile: Vector2i,id: int,behind:=false) -> Texture2D:
	if revision!=world.visual_revision or world_identity!=world.get_instance_id():
		cells.clear()
		revision=world.visual_revision
		world_identity=world.get_instance_id()
	var key:=str(tile.x)+":"+str(tile.y)+":"+str(id)+":"+str(behind)
	if cells.has(key):
		return cells[key]
	var original:=source(id)
	var base: Texture2D=Sim.sprite(original)
	if base==null:
		return null
	var cell:=variant(world,tile,id,behind)
	var frame:=0
	var row: Array=Sim.items().get(str(original),[])
	if not behind and row.size()>7 and world.extras.get(str(tile.y*world.size.x+tile.x),{}).get("enabled",false):
		var action:=int(row[7])
		if action in [122,12,27]:frame=2
		elif action in [31,32,39]:frame=int(base.atlas.get_width()/32) if int(row[4]) in [3,7,10] else 1
		elif action==45 and original not in [3772,4712] or Sim.use_rules.weather.has(str(original)):frame=1
	var sprite_key:=str(original)+":"+str(cell)+":"+str(frame)
	if not sprites.has(sprite_key):
		var atlas:=AtlasTexture.new()
		atlas.filter_clip=true
		atlas.atlas=base.atlas
		var point: Vector2=base.region.position+Vector2(cell&7,cell>>3)*32
		var columns:=int(base.atlas.get_width()/32)
		var linear:=int(point.y/32)*columns+int(point.x/32)+frame
		atlas.region=Rect2(Vector2(linear%columns,floori(float(linear)/columns))*32,Vector2(32,32))
		if sprites.size()>=256:
			sprites.erase(sprites.keys()[0])
		sprites[sprite_key]=atlas
	cells[key]=sprites[sprite_key]
	return cells[key]
