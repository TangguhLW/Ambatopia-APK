extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
static var data: Dictionary={}
static func load_data() -> void:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/blast-templates.json"))
static func weather_key(id: int) -> String:
	for entry in Sim.use_rules.weather.values():
		if int(entry.w)==id and entry.k!=null:return str(entry.k)
	return {0:"sunny",1:"sunny",3:"arid",6:"harvest",7:"mars",10:"black",14:"undersea",28:"custom_heatwave",29:"custom_stuff",34:"custom_background",32:"jungle",38:"iceage",39:"volcano",40:"floating",41:"guild",43:"monochrome",45:"surgery",46:"bountiful"}.get(id,"unmapped_%d"%id)
static func available(id: int) -> bool:
	load_data()
	return data.templates.has(str(id)) or id in preload("res://src/game/documented_blasts.gd").IDS
static func encode(id: int) -> int:
	return 0 if id==0 else 4 if id==6 else 2 if id==8 else id+200000
static func apply(r,w,p,tile: Vector2i,id: int,variant: int=-1) -> Dictionary:
	load_data()
	if not available(id):return r.result(false,str(data.unavailable.get(str(id),"No verified blast generator for this item.")))
	if not p.developer and (not w.locks.is_empty() or Array(w.foreground).any(func(value):return value not in [0,1,2,3,4,7])):return r.result(false,"Blasts need a fresh unlocked world; existing builds are preserved.")
	if id in preload("res://src/game/documented_blasts.gd").IDS:return preload("res://src/game/documented_blasts.gd").apply(r,w,p,tile,id,variant)
	var variants: Array=data.templates[str(id)]
	var template: Dictionary=variants[randi_range(0,variants.size()-1) if variant<0 else variant%variants.size()]
	var replacement=w.serialize().duplicate(true)
	replacement.foreground=template.fg.map(func(value):return encode(int(value)))
	replacement.background=template.bg.map(func(value):return encode(int(value)))
	replacement.main_door=template.spawn.duplicate()
	replacement.extras={};replacement.drops=[];replacement.next_drop=0;replacement.locks=[];replacement.world_effects={"blast":id};replacement.weather=weather_key(int(template.weather))
	for drop in template.obj:
		if replacement.drops.size()>=256:break
		replacement.next_drop+=1
		replacement.drops.append({"uid":replacement.next_drop,"id":int(drop.id),"amount":clampi(int(drop.n),1,200),"x":float(drop.x),"y":float(drop.y)})
	for key in template.ex:
		var original: Dictionary=template.ex[key]
		var extra: Dictionary={}
		if original.has("label"):extra.label=original.label
		if original.has("fruit"):
			var seed: int=int(template.fg[int(key)])
			extra={"seed":seed,"fruit":int(original.fruit),"planted":r.now()-float(Sim.use_rules.seed.get(str(seed),[1])[0]),"duration":float(Sim.use_rules.seed.get(str(seed),[1])[0])}
		if not extra.is_empty():replacement.extras[key]=extra
	var candidate=load("res://src/game/world_state.gd").new()
	if not candidate.restore(replacement):return r.result(false,"Source blast contains unsupported world data; original world preserved.")
	w.restore(replacement)
	return r.result(true,"",[{"type":"world_changed","tile":tile},r.message("Source blast applied: "+str(Sim.items()[str(id)][0]),tile)])
