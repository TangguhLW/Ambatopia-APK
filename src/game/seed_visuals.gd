extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
const Icons=preload("res://src/game/inventory_icons.gd")
const FRUIT_POINTS=[Vector2(10,3),Vector2(22,3),Vector2(4,14),Vector2(15,14),Vector2(28,14)]
var tiles: Texture2D

static func color(raw: int) -> Color:
	return Color(float((raw>>8)&255)/255,float((raw>>16)&255)/255,float((raw>>24)&255)/255,float(raw&255)/255)

static func plan(id: int,progress: float,fruit_count: int) -> Dictionary:
	var row: Array=Sim.items().get(str(id),[])
	if row.size()<16 or not row[15] is Array or row[15].size()<6:return {}
	var tree: Array=row[15]
	var size:=32*(clampf(progress,0,1)+0.2)
	var fruit: Array=[]
	if progress>=1:
		for i in clampi(fruit_count,0,5):fruit.append(Rect2(FRUIT_POINTS[i]-Vector2.ONE*4.8,Vector2.ONE*9.6))
	return {"rect":Rect2(16-size/2,32-size,size,size),"trunk":Rect2(int(tree[2])*32,19*32,32,32),"leaves":Rect2(int(tree[3])*32,18*32,32,32),"bark":color(int(tree[4])),"leaf":color(int(tree[5])),"fruit":fruit,"result":id-1}

func draw(canvas: CanvasItem,origin: Vector2,zoom: float,id: int,progress: float,count: int) -> void:
	var data:=plan(id,progress,count)
	if data.is_empty():return
	if tiles==null:tiles=load("res://assets/reference/tiles.png")
	var rect: Rect2=data.rect
	var destination:=Rect2(origin+rect.position*zoom,rect.size*zoom)
	for layer in [[data.trunk,data.bark],[data.leaves,data.leaf]]:
		if not Rect2(Vector2.ZERO,tiles.get_size()).encloses(layer[0]):
			push_error("Seed tree frame outside source atlas: "+str(id));return
		canvas.draw_texture_rect_region(tiles,destination,layer[0],layer[1])
	if data.fruit.is_empty():return
	var icon: Texture2D=Icons.texture(int(data.result))
	if icon==null:return
	for at in data.fruit:canvas.draw_texture_rect(icon,Rect2(origin+at.position*zoom,at.size*zoom),false)
