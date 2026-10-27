extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==int(value)

static func background(id: int) -> bool:
	var row: Array=Sim.items().get(str(id),[])
	return row.size()>7 and int(row[7]) in [18,22,23,28]

static func foreground(id: int) -> bool:
	var row: Array=Sim.items().get(str(id),[])
	return id>1 and row.size()>7 and not background(id) and int(row[7]) not in [3,8,19,20,37] and not Sim.use_rules.cloth.has(str(id))

static func record(w) -> Dictionary:
	for entry in w.locks:
		if not entry is Dictionary or not ["x","y","area","item"].all(func(key):return integer(entry.get(key))):continue
		if not entry.get("owner") is String or entry.owner.is_empty():continue
		var tile:=Vector2i(int(entry.x),int(entry.y))
		if int(entry.area)==0 and int(entry.item) in [105814,205814] and w.contains(tile) and w.tile_at(tile) in [105814,205814]:return entry
	return {}

static func mascot(w) -> Dictionary:
	var lock:=record(w)
	if lock.is_empty():return {}
	var data: Dictionary=w.extras.get(str(int(lock.y)*w.size.x+int(lock.x)),{})
	var fg=data.get("mascot_fg",-1);var bg=data.get("mascot_bg",-1)
	if not integer(fg) or not integer(bg) or not foreground(int(fg)) or int(bg)!=0 and not background(int(bg)):return {}
	return {"mascot_fg":int(fg),"mascot_bg":int(bg)}

static func parameters(w,settings: Dictionary) -> Dictionary:
	var image:=mascot(w)
	if image.is_empty():return {}
	var result:=image.duplicate()
	var gravity=settings.get("gravity",50)
	result.gravity=int(gravity) if integer(gravity) and gravity>=-500 and gravity<=500 else 50
	result.spin=settings.get("spin",false) if settings.get("spin",false) is bool else false
	result.invert=settings.get("invert",false) if settings.get("invert",false) is bool else false
	return result

static func configure(r,w,p,tile: Vector2i,command: String,args: Dictionary) -> Dictionary:
	if command!="configure":return r.result(false,"Wrench the Guild Lock to choose the creative guild mascot.")
	var lock:=record(w)
	if lock.is_empty() or int(lock.x)!=tile.x or int(lock.y)!=tile.y:return r.result(false,"This Guild Lock is not the world's active lock.")
	if not p.developer and str(lock.owner)!=p.actor_key:return r.result(false,"Only the Guild Lock owner can change its mascot.")
	if args.size()!=2 or not args.has("mascot_fg") or not args.has("mascot_bg") or not integer(args.mascot_fg) or not integer(args.mascot_bg):return r.result(false,"Choose one foreground and one background item.")
	if not foreground(int(args.mascot_fg)) or int(args.mascot_bg)!=0 and not background(int(args.mascot_bg)):return r.result(false,"Choose a foreground block and a background block; background may be empty in creative mode.")
	r.state(w,tile).merge({"mascot_fg":int(args.mascot_fg),"mascot_bg":int(args.mascot_bg)},true)
	w.mark_visual(tile)
	return r.result(true,"",[{"type":"item_state","tile":tile},r.message("Creative guild mascot saved. Guild weather now follows this mascot.",tile)])

static func particles(view: Vector2,time: float,params: Dictionary,low: bool) -> Array:
	var result: Array=[]
	var gravity:=float(params.get("gravity",50))
	var fit:=view.y/830.0
	for index in (20 if low else 36):
		var depth:=0.12+pow(fposmod(index*0.61803398875+0.37,1.0),2)*3.05
		var side:=32*depth*fit
		var speed:=gravity*(3.5+depth*3.0)*fit
		var point:=Vector2(fposmod(index*137.13*fit,view.x+side)-side+sin(time*2.4+index)*22*fit,fposmod(index*71.19*fit+time*speed,view.y+side)-side)
		result.append({"rect":Rect2(point,Vector2.ONE*side),"angle":fposmod(time*(0.7+depth*0.2)*(1 if index%2==0 else -1),TAU) if params.get("spin",false) else 0.0})
	return result
