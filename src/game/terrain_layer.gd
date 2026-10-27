extends Node2D
const Sim=preload("res://src/game/simulator_catalog.gd")
const Catalog=preload("res://src/game/item_catalog.gd")
const Blocks=preload("res://src/game/placeable_blocks.gd")
const EDGE:=16
var view
var chunks: Dictionary={}
var rebuild_count:=0
var generation:=0

class Chunk extends Node2D:
	var commands: Array=[]
	var dynamic_tiles: Array=[]
	var animated_tiles: Array=[]
	var revision:=-1
	var epoch:=-1
	var generation:=-1
	func _draw() -> void:
		for command in commands:
			if command.region.size==Vector2.ZERO:draw_texture_rect(command.image,command.rect,false,command.tint)
			else:draw_texture_rect_region(command.image,command.rect,command.region,command.tint)

func invalidate() -> void:generation+=1

func refresh() -> void:
	if view==null or view.world==null:return
	position=view.size/2-view.camera*view.zoom
	scale=Vector2.ONE*view.zoom
	var first:=Vector2i(((view.camera-view.size/view.zoom/2)/32/EDGE).floor())
	var last:=Vector2i(((view.camera+view.size/view.zoom/2)/32/EDGE).floor())
	var extent:=Vector2i(ceili(float(view.world.size.x)/EDGE),ceili(float(view.world.size.y)/EDGE))
	var visible: Dictionary={}
	for y in range(maxi(0,first.y),mini(extent.y,last.y+1)):
		for x in range(maxi(0,first.x),mini(extent.x,last.x+1)):
			var key:=Vector2i(x,y)
			visible[key]=true
			if not chunks.has(key):
				var chunk=Chunk.new()
				chunk.position=Vector2(key)*EDGE*32
				add_child(chunk)
				chunks[key]=chunk
			var chunk: Chunk=chunks[key]
			chunk.visible=true
			if chunk.epoch!=view.world.visual_epoch or chunk.revision!=int(view.world.visual_chunks.get(key,0)) or chunk.generation!=generation:rebuild(key,chunk)
	for key in chunks:
		if not visible.has(key):chunks[key].visible=false

func rebuild(key: Vector2i,chunk: Chunk) -> void:
	chunk.commands.clear();chunk.dynamic_tiles.clear();chunk.animated_tiles.clear()
	var origin:=key*EDGE
	for y in range(origin.y,mini(view.world.size.y,origin.y+EDGE)):
		for x in range(origin.x,mini(view.world.size.x,origin.x+EDGE)):
			var tile:=Vector2i(x,y)
			var rect:=Rect2(Vector2(tile-origin)*32,Vector2(32,32))
			var back:=int(view.world.background[y*view.world.size.x+x])
			if Sim.supported(back):
				var image: Texture2D=view.terrain_renderer.texture(view.world,tile,back,true)
				if image!=null:chunk.commands.append({"image":image,"rect":rect,"region":Rect2(),"tint":Color(.75,.75,.75),"tile":tile})
			var id: int=view.world.tile_at(tile)
			if id==0:continue
			if view.terrain_renderer.animated(id):
				chunk.animated_tiles.append(tile)
				continue
			var image: Texture2D
			var tint:=Color.WHITE
			var region:=Rect2()
			if Sim.supported(id):
				if view.item_runtime.is_seed(id-200000):
					chunk.dynamic_tiles.append(tile)
					continue
				image=view.terrain_renderer.texture(view.world,tile,id)
				tint=Color(view.world.extras.get(view.item_runtime.key(view.world,tile),{}).get("paint","ffffff"))
			elif Blocks.supports(id):
				image=view.terrain_renderer.texture(view.world,tile,id)
			elif view.tile_regions.has(id):
				image=view.terrain_renderer.texture(view.world,tile,id)
				if image==null:image=view.tiles;region=view.tile_regions[id]
			if image!=null:chunk.commands.append({"image":image,"rect":rect,"region":region,"tint":tint,"tile":tile})
	chunk.revision=int(view.world.visual_chunks.get(key,0))
	chunk.epoch=view.world.visual_epoch
	chunk.generation=generation
	rebuild_count+=1
	chunk.queue_redraw()
