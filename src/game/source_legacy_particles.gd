extends RefCounted
const W=preload("res://src/game/web_wardrobe.gd")
const SLOTS=preload("res://src/game/simulator_catalog.gd").SLOTS
const VM=preload("res://src/game/source_particle_program.gd")
const Assets=preload("res://src/game/source_effect_assets.gd")
const LIMIT:=96
var particles: Array=[]
var clocks: Dictionary={}
var elapsed:=0.0
var jump_effect_until:=0.0
var was_grounded:=true
var previous_vy:=0.0
var previous_state:=0

static func value(e,ctx: Dictionary):
	if e is String:return ctx.get(e,0.0)
	if not e is Array:return e
	if e.is_empty():return 0.0
	var a=value(e[1],ctx) if e.size()>1 else 0.0
	if e[0]=="if":return value(e[2] if bool(a) else e[3],ctx)
	if e[0]=="not":return not bool(a)
	if e[0]=="abs":return absf(float(a))
	if e[0]=="sin":return sin(float(a))
	if e[0]=="cos":return cos(float(a))
	var b=value(e[2],ctx) if e.size()>2 else 0.0
	match str(e[0]):
		"+":return float(a)+float(b)
		"-":return float(a)-float(b)
		"*":return float(a)*float(b)
		"/":return float(a)/maxf(0.00001,float(b))
		"lt":return a<b
		"le":return a<=b
		"gt":return a>b
		"ge":return a>=b
		"eq":return a==b
		"ne":return a!=b
		"and":return bool(a) and bool(b)
		"or":return bool(a) or bool(b)
		"rnd":return randf_range(float(a),float(b))
		"rndi":return randi_range(int(a),int(b))
		"atan2":return atan2(float(a),float(b))
		"hypot":return Vector2(float(a),float(b)).length()
		"min":return minf(float(a),float(b))
		"max":return maxf(float(a),float(b))
		"sinp":return sin(float(a)/maxf(1,float(b))*TAU)
		"pick":return value(e[2+clampi(int(a),0,e.size()-3)],ctx)
	return 0.0

func update(player,dt: float,arm_angle: float=0) -> void:
	elapsed+=dt
	for p in particles:
		p.life-=dt;p.x+=float(p.vx)*dt;p.y+=float(p.vy)*dt
		p.owner=owner_context(player,p.origin);p.clock_ms=elapsed*1000
		VM.run(p.program.up,p,dt)
	particles=particles.filter(func(p):return p.life>0)
	var active: Dictionary={}
	var ctx={"bx":0,"by":0,"face":player.facing,"vx":player.velocity.x,"vy":player.velocity.y,"gr":player.grounded,"T":elapsed*1000,"armB":rad_to_deg(arm_angle),"wr":false,"st":0,"dnc":false}
	ctx.wr=player.wrench_selected
	var worn: Array=[]
	for slot in range(SLOTS.size()):
		var id:=int(player.catalog_equipment.get(SLOTS[slot],0));id=id-200000 if id>=200000 else id
		ctx["s"+str(slot)]=id;worn.append(id)
	if not player.grounded and player.velocity.y<0 and (was_grounded or previous_vy>=0):
		jump_effect_until=elapsed+(1.0 if 1938 in worn or 1550 in worn else 0.5)
	was_grounded=player.grounded;previous_vy=player.velocity.y
	ctx.j26=elapsed<jump_effect_until;ctx.wt=player.in_water
	ctx.jt=not player.grounded and player.velocity.y>0 and player.jump_held and not player.in_water
	ctx.c005=int(elapsed/0.05)!=int((elapsed-dt)/0.05)
	ctx.st=3 if not player.grounded else 0 if absf(player.velocity.x)<1 else 1
	ctx.pst=previous_state;previous_state=int(ctx.st)
	var emitters: Array=player.catalog_equipment.values()
	if player.burn_time>0 and 1442 not in emitters:emitters.append(1442)
	for id in emitters:
		var record:=W.definition(int(id));var ef: Dictionary=record.get("ef",{})
		var rows: Array=ef.get("rows",[])
		for i in rows.size():
			var row: Dictionary=rows[i]
			var type:=str(int(row.get("lp",-1)))
			if not VM.programs().has(type) or not bool(value(row.get("on",true),ctx)):continue
			var key:=str(id)+":"+str(i);active[key]=true
			clocks[key]=float(clocks.get(key,0))+dt
			var interval:=float({"c005":0.05,"c01":0.1,"c03":0.3,"c2":2.0}.get(str(row.get("tick","f")),0.0))
			if row.get("iv") is Array:interval=maxf(interval,float(value(row.iv[0],ctx)))
			if interval>0 and float(clocks[key])<interval:continue
			clocks[key]=fmod(float(clocks[key]),interval) if interval>0 else 0.0
			if int(row.get("ch",0))>0 and randi_range(0,int(row.ch)-1)!=0:continue
			if particles.size()>=LIMIT:continue
			var program: Dictionary=VM.programs()[type]
			var vars: Dictionary=ctx.duplicate()
			for name in row.get("vars",{}):vars[name]=value(row.vars[name],vars)
			for at in row.get("ats",[row.get("at",[0,0])]):
				if particles.size()>=LIMIT:break
				if int(row.get("cha",0))>0 and randi_range(0,int(row.cha)-1)!=0:continue
				var angle:=float(value(row.get("ang",0),vars))
				var speed:=float(value(row.get("spd",0),vars))
				var p={"x":float(value(at[0],vars)),"y":float(value(at[1],vars)),"vx":speed*cos(deg_to_rad(angle)),"vy":speed*sin(deg_to_rad(angle)),"s":1.0,"al":1.0,"rot":0.0,"life":1.0,"an":angle,"sp":speed,"w2":value(row.get("w2",0),vars),"a4":value(row.get("a4",0),vars),"program":program,"origin":player.position,"item":int(record.id)}
				p.origin+=Vector2(0,player.visual_lift)
				p.id=int(type)
				p.owner=owner_context(player,p.origin);p.clock_ms=elapsed*1000
				if row.has("lc"):p.lc=row.lc
				if program.has("factory"):
					var factory: Dictionary=program.factory
					for child_index in int(factory.count):
						if particles.size()>=LIMIT:break
						var child:=p.duplicate()
						child.id=int(factory.target);child.sp=0
						child.x+=randf_range(-float(factory.jitter),float(factory.jitter));child.y+=randf_range(-float(factory.jitter),float(factory.jitter))
						child.an=VM.run(factory.angle,p,0).get("value",0)
						initialize_particle(child,VM.programs()[str(int(factory.target))],ef)
				else:initialize_particle(p,program,ef)
	for key in clocks.keys():
		if not active.has(key):clocks.erase(key)

func initialize_particle(p: Dictionary,program: Dictionary,ef: Dictionary) -> void:
	VM.run(program.init,p,0)
	if p.life<=0:return
	program=VM.programs().get(str(int(p.id)),program);p.program=program
	var sheet=str(VM.run(program.sh_program,p,0).get("value","")) if program.has("sh_program") else str(program.get("sh",""))
	var path: String=str(ef.get("lts",{}).get(sheet,"")) if sheet!="" else str(ef.get("lt","particles"))
	p.image=Assets.texture(path)
	if p.image!=null:particles.append(p)

static func owner_context(player,origin: Vector2) -> Dictionary:
	return {"x":player.position.x-origin.x,"y":player.position.y-origin.y,"vx":player.velocity.x,"vy":player.velocity.y,"bx":0,"by":0,"face":player.facing}

func draw(canvas: CanvasItem,player,additive: bool=false) -> void:
	for p in particles:
		var add: bool=bool(VM.run(p.program.add_program,p,0).get("value",false)) if p.program.has("add_program") else bool(p.program.get("add",0))
		if add!=additive:continue
		var result:=VM.run(p.program.cell,p,0)
		var cell=result.get("value",[])
		if not cell is Array or cell.size()<2:continue
		var frame_size:=float(p.program.get("fs",32))
		var source:=Rect2(float(cell[0])*frame_size,float(cell[1])*frame_size,frame_size,frame_size)
		if not Rect2(Vector2.ZERO,p.image.get_size()).encloses(source):continue
		var scale:=Vector2(float(p.sx),float(p.get("sy",1))) if p.has("sx") else Vector2.ONE*float(p.s)
		var extent:=scale.abs()*frame_size
		var point: Vector2=Vector2(p.x,p.y)+p.origin-player.position
		point.y-=player.visual_lift
		var flip_x: bool=scale.x<0
		if p.get("fl",false):flip_x=not flip_x
		canvas.draw_set_transform(point,deg_to_rad(float(p.rot)),Vector2(-1 if flip_x else 1,-1 if scale.y<0 else 1))
		var rgb: Array=p.get("rgb",[1,1,1])
		var align: Array=p.program.get("an",[0.5,0.5])
		canvas.draw_texture_rect_region(p.image,Rect2(-extent*Vector2(align[0],align[1]),extent),source,Color(float(rgb[0]),float(rgb[1]),float(rgb[2]),clampf(float(p.al),0,1)))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
