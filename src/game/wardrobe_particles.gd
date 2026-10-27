extends RefCounted
const W=preload("res://src/game/web_wardrobe.gd")
const Program=preload("res://src/game/wardrobe_program.gd")
static var index: Dictionary={}
static var textures: Dictionary={}
var particles: Array=[]
var clocks: Dictionary={}
var active_last: Dictionary={}
const LIMIT:=96

static func texture(key: String) -> Texture2D:
	if textures.has(key):return textures[key]
	if index.is_empty():index=JSON.parse_string(FileAccess.get_file_as_string("res://data/wardrobe-particles.json"))
	var entry: Dictionary=index.get(key,{})
	if entry.is_empty() or entry.get("missing",false):return null
	var file=FileAccess.open("res://assets/web-wardrobe/particles.bin",FileAccess.READ)
	file.seek(int(entry.offset));var image=Image.new()
	if image.load_png_from_buffer(file.get_buffer(int(entry.bytes)))!=OK:return null
	if image.get_size()!=Vector2i(int(entry.width),int(entry.height)):return null
	if textures.size()>=4:textures.erase(textures.keys()[0])
	textures[key]=ImageTexture.create_from_image(image)
	return textures[key]

static func vec(raw,default: Vector2=Vector2.ZERO) -> Vector2:
	return Vector2(raw[0],raw[1]) if raw is Array and raw.size()>1 else default

static func randomized(spec: Dictionary,key: String,base: Vector2) -> Vector2:
	var range_values: Array=spec.get("rn",{}).get(key,[])
	return base+Vector2(randf_range(range_values[0][0],range_values[1][0]),randf_range(range_values[0][1],range_values[1][1])) if range_values.size()==2 and range_values[0].size()>1 else base

func update(player,renderer,dt: float) -> void:
	for particle in particles:
		particle.age+=dt;particle.point+=particle.velocity*dt
	particles=particles.filter(func(p):return p.age<p.life)
	var active: Dictionary={}
	for id in player.catalog_equipment.values():
		var record:=W.definition(int(id))
		if not preload("res://src/game/native_item_renderer.gd").definition(int(id)).get("particles",{}).is_empty():continue
		if record.get("xs",[]).is_empty() or not renderer.contexts.has(int(record.get("id",-1))):continue
		var ctx: Dictionary=renderer.contexts[int(record.id)].vars
		renderer.active_states=renderer.contexts[int(record.id)].program.states
		var rules: Array=renderer.expanded_rules(record.get("ro",{}).get("st",{}).get("AddClothingParticles",[]),ctx,player)
		for rule in rules:
			if not (rule.get("ps") is float or rule.get("ps") is int):continue
			var emitter:=int(rule.ps)
			if emitter<0 or emitter>=record.xs.size():continue
			var spec: Dictionary=record.xs[emitter]
			if not spec.get("w",[]).is_empty() or str(spec.get("t","")).is_empty():continue
			var key:=str(record.id)+":"+str(emitter);active[key]=true
			var start: Dictionary=spec.get("x",{})
			if start.get("chk",0) and active_last.has(key):continue
			clocks[key]=float(clocks.get(key,0))+dt
			var interval:=maxf(1.0/60,float(start.get("iv",spec.get("iv",0))))
			if float(clocks[key])<interval:continue
			clocks[key]=0
			var capacity:=maxi(1,int(spec.get("n",1)))
			if particles.filter(func(p):return p.key==key).size()>=capacity or particles.size()>=LIMIT:continue
			spawn(spec,key,player)
	active_last=active
	for key in clocks.keys():
		if not active.has(key):clocks.erase(key)

func spawn(spec: Dictionary,key: String,player) -> void:
	var frames: Array=spec.get("cl",[])
	if frames.is_empty():return
	var image: Texture2D
	for particle in particles:
		if particle.sheet==str(spec.t):image=particle.image;break
	if image==null:image=texture(str(spec.t))
	if image==null:return
	var selected: Array=frames.pick_random()
	var life:=maxf(0.016,float(spec.get("L",1)))
	var point:=randomized(spec,"o",vec(spec.get("po",[])))+vec(spec.get("eo",[]))
	var velocity:=randomized(spec,"v",vec(spec.get("v",[])))
	particles.append({"key":key,"sheet":str(spec.t),"image":image,"frames":frames,"source":Rect2(selected[0],selected[1],selected[2],selected[3]),"point":point,"origin":player.position,"face":player.facing,"velocity":velocity,"age":0.0,"life":life,"spec":spec,"relative":bool(spec.get("rel",false)),"name":str(spec.get("sn",""))})

func draw(canvas: CanvasItem,player,front: bool) -> void:
	for p in particles:
		var spec: Dictionary=p.spec
		if (str(spec.get("ly","f"))=="f")!=front:continue
		var image: Texture2D=p.image
		if image==null:continue
		var phase:=float(p.age)/float(p.life)
		var source: Rect2=p.source
		if spec.get("pk")=="a":
			var frame: Array=p.frames[mini(p.frames.size()-1,int(float(p.age)/maxf(0.016,float(spec.get("ft",0.1)))))]
			source=Rect2(frame[0],frame[1],frame[2],frame[3])
		var scale:=vec(spec.get("s",[]),Vector2.ONE)
		var alpha:=float(spec.get("a",1))
		var curves: Dictionary=spec.get("cv",{})
		if curves.has("a"):alpha*=Program.curve(curves.a,phase)
		if curves.has("s"):
			scale*=Vector2(Program.curve(curves.s,phase,1),Program.curve(curves.s,phase,2))
		var point: Vector2=p.point
		point.x*=float(p.face)*player.facing
		if not p.relative:point+=(p.origin-player.position)*Vector2(player.facing,1)
		var angle:=deg_to_rad(float(spec.get("ang",0))+float(p.age)*float(spec.get("rr",0)))
		var extent:=source.size*scale
		var alignment:=vec(spec.get("al",[]),Vector2(0.5,0.5))
		canvas.draw_set_transform(point*Vector2(player.facing,1),angle*player.facing,Vector2(player.facing,1))
		canvas.draw_texture_rect_region(image,Rect2(-extent*alignment,extent),source,Color(1,1,1,clampf(alpha,0,1)))
		canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
