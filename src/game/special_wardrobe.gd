extends RefCounted

const Program=preload("res://src/game/wardrobe_program.gd")
var active_states: Array=[]
var pose_overrides: Dictionary={}
const Wardrobe=preload("res://src/game/web_wardrobe.gd")
const SLOTS=["hat","shirt","pants","feet","face","hand","back","hair","neck","artifact"]
const ANCHORS={"RenderBehind":Vector2(16,8),"RenderAura":Vector2(16,8),"RenderTransform":Vector2(16,8),"RenderHandItem":Vector2(9,18),"RenderBackHandItem":Vector2(23,18)}
var contexts: Dictionary={}
var compiled: Dictionary={}
var hidden_parts: Dictionary={}
var hidden_slots: Dictionary={}
var elapsed:=0.0
var motion:="Idle"
var motion_age:=0.0
var previous_grounded:=true
var action:=0
var action_age:=0.0
var sprite_cache: Dictionary={}

static func value(e,ctx: Dictionary,depth: int=0) -> float:
	if depth>96 or e==null:return 0
	if e is bool:return float(e)
	if e is int or e is float:return float(e) if is_finite(float(e)) else 0
	if e is String:
		var stored=ctx.get(e,0)
		return float(stored) if stored is float or stored is int or stored is bool else 0
	if not e is Array or e.is_empty():return 0
	var op:=str(e[0])
	var a:=value(e[1],ctx,depth+1) if e.size()>1 else 0.0
	if op=="if":return value(e[2] if a!=0 else e[3],ctx,depth+1)
	if op=="and":return value(e[2],ctx,depth+1) if a!=0 else 0
	if op=="or":return a if a!=0 else value(e[2],ctx,depth+1)
	if op=="pick":return value(e[clampi(int(a)+2,2,e.size()-1)],ctx,depth+1)
	var b:=value(e[2],ctx,depth+1) if e.size()>2 else 0.0
	match op:
		"+":return a+b
		"-":return a-b
		"*":return a*b
		"/":return a/b if absf(b)>0.000001 else 0
		"//":return float(int(a/b)) if absf(b)>0.000001 else 0
		"%":return fmod(a,b) if absf(b)>0.000001 else 0
		"neg":return -a
		"lt":return float(a<b)
		"gt":return float(a>b)
		"le":return float(a<=b)
		"ge":return float(a>=b)
		"eq":return float(a==b)
		"ne":return float(a!=b)
		"not":return float(a==0)
		"abs":return absf(a)
		"floor":return floorf(a)
		"trunc":return float(int(a))
		"fr":return a
		"sin":return sin(a)
		"cos":return cos(a)
		"atan2":return atan2(a,b)
		"hypot":return Vector2(a,b).length()
		"sinp":return sin(TAU*a/maxf(1,b))
		"rnd":return randf_range(a,b)
		"rndi":return a+floorf(randf()*(b-a))
		"min","max":
			var result:=a
			for i in range(2,e.size()):result=minf(result,value(e[i],ctx,depth+1)) if op=="min" else maxf(result,value(e[i],ctx,depth+1))
			return result
	return 0

static func bindings(rows: Array,ctx: Dictionary) -> void:
	for row in rows:
		if row is Array and row.size()==2:ctx[str(row[0])]=value(row[1],ctx)

static func supports(record: Dictionary) -> bool:
	return record.get("ro",{}).get("k") in ["g","xr"] and record.has("bk") and not record.get("L",[]).is_empty()

func update(player,dt: float,foot_a: float,foot_b: float,arm_a: float,arm_b: float) -> void:
	elapsed+=dt*1000
	var next:="Idle" if player.grounded else "Jump" if player.velocity.y<0 else "Fall"
	motion_age=0 if next!=motion else motion_age+dt*1000
	motion=next
	var next_action:=10 if player.death_time>=0 and player.death_time<2 else 8 if player.punch_time>0 else 3 if motion=="Jump" else 6 if motion=="Fall" else 1 if absf(player.velocity.x)>1 else 0
	action_age=0 if next_action!=action else action_age+dt*1000
	action=next_action
	sprite_cache.clear()
	compiled.clear();hidden_parts.clear();hidden_slots.clear();pose_overrides.clear()
	var active: Dictionary={}
	var definitions: Array=[]
	for id in player.catalog_equipment.values():
		var record:=Wardrobe.definition(int(id))
		for slot in record.get("hs",[]):hidden_slots[int(slot)]=true
		for part in record.get("hd",[]):hidden_parts[str(part)]=true
		for part in record.get("b",{}).get("hide",[]):hidden_parts[str(part)]=true
		if supports(record):definitions.append(record)
	for record in definitions:
		if hidden_slots.has(int(record.slot)):continue
		var id:=int(record.id)
		active[id]=true
		var ro: Dictionary=record.ro
		var events: Dictionary=ro.ev if ro.get("ev") is Dictionary else {}
		if not contexts.has(id):
			var initial: Dictionary=ro.get("c",{}).duplicate()
			initial.merge(ro.get("v",{}),true)
			contexts[id]={"vars":initial,"previous_st":-1,"previous_punch":-1.0,"program":Program.initial(ro)}
			bindings(events.get("init",[]),initial)
		var runtime: Dictionary=contexts[id]
		var ctx: Dictionary=runtime.vars
		var st:=8 if player.punch_time>0 else 3 if not player.grounded else 1 if absf(player.velocity.x)>1 else 0
		ctx.merge({"T":elapsed,"dt":dt*1000,"vx":player.velocity.x,"vy":player.velocity.y,"air":int(not player.grounded),"walk":int(player.grounded and absf(player.velocity.x)>1),"st":st,"face":player.facing,"sc":1,"jmp":int(previous_grounded and not player.grounded),"dj":0,"ld":int(not previous_grounded and player.grounded),"f1":foot_a,"f2":foot_b,"armB":rad_to_deg(arm_a),"armF":rad_to_deg(arm_b),"fx":0,"fy":0,"tx":16+player.punch_direction.x*48,"ty":16+player.punch_direction.y*48,"ptm":(player.PUNCH_DURATION-player.punch_time)*1000 if player.punch_time>0 else -1,"rsp":1000000000,"gr":int(player.grounded),"pw":int(player.catalog_equipment.has("pants")),"rds":1,"rdb":0,"rdc":1},true)
		for i in SLOTS.size():
			var worn:=int(player.catalog_equipment.get(SLOTS[i],0))
			ctx["ws"+str(i)]=worn-200000 if worn>=200000 else worn
		for option in record.get("cfg",{}).get("controls",[]):
			if option.get("t")!="colour":ctx["o_"+str(option.k)]=float(option.get("d",0)) if option.get("d",0) is float or option.get("d",0) is int else 0
		if st==8 and runtime.previous_st!=8:bindings(events.get("punch",[]),ctx)
		if ctx.ptm>=0 and (runtime.previous_punch<0 or ctx.ptm<runtime.previous_punch):bindings(events.get("swing",[]),ctx)
		bindings(ro.get("up",[]),ctx)
		if ro.k=="g":
			for part in ro.get("arm",{}):
				pose_overrides["armF" if part=="F" else "armB"]=value(ro.arm[part],ctx)
		ctx.action=action
		if ro.k=="xr":
			Program.update(ro,runtime.program,ctx,player,dt*1000,elapsed)
			active_states=runtime.program.states
			var hooks: Array=["Update"]
			if st==8:hooks.append("OnPunchUpdate")
			for hook in hooks:
				var rules:=expanded_rules(ro.get("st",{}).get(hook,[]),ctx,player)
				if hook=="OnPunchUpdate" and not rules.is_empty():pose_overrides.no_fist=true
				for rule in rules:
					if rule.has("arm"):
						var part: String="armB" if (int(rule.arm)==1)!=bool(rule.get("sw",false) and player.facing<0) else "armF"
						var raw=Program.resolve(rule.get("a",0),ctx)
						var angle:=float(raw[0]) if raw is Array else float(raw) if raw is float or raw is int else 0.0
						if rule.get("add",false):
							if st==8:continue
							angle=float(runtime.get("pose_"+part,ctx.get(part,0)))+angle*dt
						if rule.has("cv"):angle=Program.curve(rule.cv,minf(1,elapsed/maxf(1,float(rule.get("ms",1000)))))
						pose_overrides[part]=angle;ctx[part]=angle;runtime["pose_"+part]=angle
					if rule.has("foot"):
						var values: Array=rule.foot.map(func(v):return Program.resolve(v,ctx))
						pose_overrides.foot1=float(values[0]);pose_overrides.foot2=float(values[2])
		runtime.previous_st=st;runtime.previous_punch=ctx.ptm
		for part in record.get("hd",[]):hidden_parts[str(part)]=true
		for part in record.get("b",{}).get("hide",[]):hidden_parts[str(part)]=true
		for part in ro.get("hdx",{}):
			if value(ro.hdx[part],ctx)!=0:hidden_parts[part]=true
		for hook in ro.get("st",{}):
			var rows:=commands(record,hook,player)
			if not compiled.has(hook):compiled[hook]=[]
			compiled[hook].append_array(rows)
	for id in contexts.keys():
		if not active.has(id):contexts.erase(id)
	previous_grounded=player.grounded

func enabled(on: Array) -> bool:
	if on.is_empty():return true
	for condition in on:
		if condition in active_states:return true
		if condition=="Motion."+motion:return true
		if action==1 and condition in ["PlayerAction.Move","Action.Move","Motion.Walk"]:return true
		var action_name: String={0:"Idle",1:"Walk",3:"Jump",6:"Fall",8:"Punch"}.get(action,"Idle")
		if condition=="PlayerAction."+action_name or condition=="Action."+action_name:return true
		if condition in ["state.Equip","State.Equip"]:return true
	return false

func sprite_state(ro: Dictionary,sprite: int) -> Dictionary:
	var result={"frame":int(ro.sd[sprite].get("d",0)),"alpha":1.0,"position":Vector2.ZERO,"scale":Vector2.ONE,"rotation":0.0,"visible":true}
	for animation in ro.get("an",[]):
		if int(animation.get("s",-1))!=sprite or not enabled(animation.get("on",[])):continue
		if animation.has("oa") and not animation.oa.any(func(value):return int(value)==action):continue
		var age: float=elapsed if animation.get("on",[]).is_empty() else motion_age
		var duration:=maxf(1,float(animation.get("ms",100)))
		var phase:=fmod(age/duration,1) if animation.get("lp",0) else minf(age/duration,0.999999)
		if animation.k=="f" and not animation.get("fr",[]).is_empty():
			var step:=16*(floorf(duration/animation.fr.size()/16)+1)
			var frame: int=int(age/step)%animation.fr.size() if animation.get("lp",0) else mini(animation.fr.size()-1,int(age/step))
			result.frame=int(animation.fr[frame])
		elif animation.k=="c":
			var amount:=preload("res://src/game/native_item_renderer.gd").curve(animation.get("keys",[]),phase)
			match str(animation.get("p","")):
				"alpha":result.alpha=amount
				"pos.y":result.position.y=amount
				"rotation":result.rotation=amount
				"scale","pos":
					var keys: Array=animation.get("keys",[])
					var ykeys: Array=[]
					for key in keys:ykeys.append([key[0],key[2] if key.size()>2 else key[1]])
					var y:=preload("res://src/game/native_item_renderer.gd").curve(ykeys,phase)
					if animation.p=="scale":result.scale=Vector2(amount,y)
					else:result.position=Vector2(amount,y)
		elif animation.k=="vs":result.visible=bool(animation.get("vis",1))
	return result

static func crop(record: Dictionary,frame: int) -> Dictionary:
	var layer: Array=record.L[0]
	var count:=maxi(1,int(layer[8]))
	if frame<0 or frame>=count:return {}
	var columns:=maxi(1,int(layer[7]))
	var size:=Vector2(layer[4],layer[5])
	return {"source":Rect2(Vector2((frame%columns)*size.x,float(layer[6])+floorf(float(frame)/columns)*size.y),size),"offset":Vector2(layer[2],layer[3])}

func commands(record: Dictionary,hook: String,player) -> Array:
	var result: Array=[]
	if not supports(record) or not contexts.has(int(record.id)):return result
	var ro: Dictionary=record.ro
	var ctx: Dictionary=contexts[int(record.id)].vars
	active_states=contexts[int(record.id)].program.states
	var base: Vector2=ANCHORS.get(hook,Vector2(16,32))+Vector2(-16,-32)
	var sv=ro.get("sv",{}).get(hook,0)
	if sv is int or sv is float:base.y+=float(sv)
	var rules: Array=ro.st.get(hook,[])
	if ro.k=="xr":rules=expanded_rules(rules,ctx,player)
	for rule in rules:
		if ro.k=="g" and value(rule.get("if",1),ctx)==0:continue
		if ro.k=="xr" and not enabled(rule.get("on",[])):continue
		if ro.k=="xr" and rule.has("oa") and not rule.oa.any(func(value):return int(value)==action):continue
		if rule.has("ci"):continue
		if rule.has("ln") and ro.k=="xr":
			var line: Array=rule.ln
			var a=ctx.get(str(line[0]),[]);var b=ctx.get(str(line[1]),[])
			if a is Array and b is Array and a.size()>1 and b.size()>1:
				var rgba: Array=line[4]
				var origin: Vector2=base+rule.get("_offset",Vector2.ZERO)
				result.append({"line":[origin+Vector2(a[0],a[1]),origin+Vector2(b[0],b[1])],"tint":Color(float(rgba[0])/255,float(rgba[1])/255,float(rgba[2])/255,float(rgba[3])/255),"width":maxf(0.1,float(line[5])),"add":false})
			continue
		if rule.has("ln"):
			var line: Array=rule.ln
			var rgb: Array=rule.get("rgb",[0,0,0])
			result.append({"line":[base+Vector2(value(line[0],ctx),value(line[1],ctx)),base+Vector2(value(line[2],ctx),value(line[3],ctx))],"tint":Color(value(rgb[0],ctx)/255,value(rgb[1],ctx)/255,value(rgb[2],ctx)/255,clampf(value(rule.get("a",1),ctx),0,1)),"width":maxf(0.1,value(rule.get("lw",1),ctx)),"add":false})
			continue
		var frame:=int(value(rule.get("c",0),ctx))
		var full: Vector2
		var point:=base
		var alignment: Array=rule.get("al",[0.5,0.5])
		var scale:=Vector2.ONE
		var alpha:=1.0
		var rotation:=0.0
		var flip:=false
		var flip_y:=false
		if ro.k=="g":
			if frame<0 or frame>=ro.cd.size():continue
			full=Vector2(ro.cd[frame][0],ro.cd[frame][1])
			point+=Vector2(value(rule.get("x",0),ctx),value(rule.get("y",0),ctx))
			scale=Vector2(value(rule.get("sx",1),ctx),value(rule.get("sy",1),ctx))
			alpha=clampf(value(rule.get("a",1),ctx),0,1)
			rotation=value(rule.get("r",0),ctx)
			flip=value(rule.get("fl",0),ctx)!=0;flip_y=value(rule.get("fy",0),ctx)!=0
		else:
			if not rule.has("spr"):continue
			var sprite:=int(rule.spr)
			if sprite<0 or sprite>=ro.sd.size():continue
			var cache_key:=str(int(record.id))+":"+str(sprite)
			if not sprite_cache.has(cache_key):
				var sprites: Array=contexts[int(record.id)].program.sprites
				sprite_cache[cache_key]=sprites[sprite] if sprite<sprites.size() else sprite_state(ro,sprite)
			var animated: Dictionary=sprite_cache[cache_key]
			if not animated.visible:continue
			frame=animated.frame;alpha=animated.alpha;rotation=animated.rotation
			full=Vector2(ro.sd[sprite].w,ro.sd[sprite].h)
			var offset: Array=rule.get("o",[0,0])
			var group_scale: Vector2=rule.get("_scale",Vector2.ONE)
			var group_angle:=deg_to_rad(float(rule.get("_rotation",0)))
			point+=rule.get("_offset",Vector2.ZERO)+(Vector2(offset[0],offset[1])*group_scale).rotated(group_angle if rule.get("ro",1) else 0)+animated.position
			scale=animated.scale*group_scale
			rotation+=float(rule.get("fr",rule.get("_rotation",0)))
			alpha*=float(rule.get("_alpha",1))
			if rule.has("sc"):scale*=Vector2(rule.sc[0],rule.sc[1])
			if player.facing<0:
				var left: Array=rule.get("alL",alignment)
				alignment=[1-float(left[0]),left[1]]
			var flips: Array=rule.get("fl",[0,0])
			flip=bool(flips[0]);flip_y=bool(flips[1])
		if rule.get("stt",0) or rule.get("rtt",0):
			var target:=Vector2(16+player.punch_direction.x*48*player.facing,16+player.punch_direction.y*48)+Vector2(-16,-32)
			var delta:=target-point
			rotation=rad_to_deg(delta.angle())-(180 if rule.get("stt",0) else 0)
			if rule.get("stt",0):scale.x*=maxf(0,delta.length()-4)/32
		var picture:=crop(record,frame)
		if picture.is_empty():continue
		var extent: Vector2=picture.source.size*scale
		var offset: Vector2=picture.offset*scale
		if flip:offset.x=full.x*scale.x-offset.x-extent.x
		if flip_y:offset.y=full.y*scale.y-offset.y-extent.y
		var destination:=Rect2(point-full*scale*Vector2(alignment[0],alignment[1])+offset,extent)
		if destination.size.x<0:
			destination.position.x+=destination.size.x;destination.size.x=absf(destination.size.x);flip=not flip
		if destination.size.y<0:
			destination.position.y+=destination.size.y;destination.size.y=absf(destination.size.y);flip_y=not flip_y
		var tint:=Color.WHITE
		if rule.get("tn") is String and rule.tn=="S":tint=Color(player.SKINS[player.skin_index])
		if rule.get("tn") is Array and rule.tn.size()>=3:
			tint=Color(float(rule.tn[0])/255,float(rule.tn[1])/255,float(rule.tn[2])/255)
			if rule.tn.size()>3:alpha*=float(rule.tn[3])/255
		if rule.get("rgb") is Array:
			var rgb: Array=rule.rgb
			tint=Color(value(rgb[0],ctx)/255,value(rgb[1],ctx)/255,value(rgb[2],ctx)/255)
		var pivot:=point
		if rule.has("pv"):pivot+=Vector2(value(rule.pv[0],ctx),value(rule.pv[1],ctx))
		result.append({"key":record.bk,"frame":frame,"source":picture.source,"destination":destination,"rotation":rotation,"pivot":pivot,"flip":flip,"flip_y":flip_y,"tint":Color(tint,alpha),"add":bool(rule.get("add",0))})
	return result

func draw_hook(canvas: CanvasItem,hook: String,facing: int,additive: bool=false) -> void:
	for command in compiled.get(hook,[]):
		if command.add!=additive:continue
		if command.has("line"):
			canvas.draw_line(command.line[0],command.line[1],command.tint,command.width,false)
			continue
		var texture:=Wardrobe.texture(command.key)
		if texture==null:continue
		var destination: Rect2=command.destination
		var angle:=deg_to_rad(float(command.rotation))
		var center: Vector2=command.pivot+(destination.get_center()-command.pivot).rotated(angle)
		canvas.draw_set_transform(center*Vector2(facing,1),angle*facing,Vector2(facing*(-1 if command.flip else 1),-1 if command.flip_y else 1))
		canvas.draw_texture_rect_region(texture,Rect2(-destination.size/2,destination.size),command.source,command.tint)
		canvas.draw_set_transform(Vector2.ZERO,0,Vector2(facing,1))

func expanded_rules(rules: Array,ctx: Dictionary,p,offset: Vector2=Vector2.ZERO,scale: Vector2=Vector2.ONE,rotation: float=0,alpha: float=1,depth: int=0) -> Array:
	var result: Array=[]
	if depth>32:return result
	for raw in rules:
		var rule: Dictionary=raw
		if rule.has("stop"):
			if Program.conditions(rule.stop,ctx,p):break
			continue
		if not enabled(rule.get("on",[])) or (rule.has("oa") and not rule.oa.any(func(value):return int(value)==action)):continue
		if rule.has("op"):
			Program.operate(rule.op,ctx);continue
		if rule.has("grp"):
			result.append_array(expanded_rules(rule.grp,ctx,p,offset,scale,rotation,alpha,depth+1));continue
		if rule.has("tr"):
			var tr=Program.resolve(rule.tr,ctx)
			if tr is Array and tr.size()>1:offset+=(Vector2(tr[0],tr[1])*scale).rotated(deg_to_rad(rotation))
			continue
		if rule.has("rot"):
			var rot=Program.resolve(rule.rot,ctx)
			var angle:=float(rot[0]) if rot is Array else float(rot) if rot is float or rot is int else 0.0
			rotation=angle if rule.get("fv",0) else rotation+angle
			continue
		if rule.has("scl"):
			var scl=Program.resolve(rule.scl,ctx)
			if scl is Array and scl.size()>1:scale*=Vector2(scl[0],scl[1])
			continue
		if rule.has("alp"):
			var amount=Program.resolve(rule.alp,ctx)
			if amount is float or amount is int:alpha=clampf(float(amount),0,1)
			continue
		var leaf:=rule.duplicate()
		leaf._offset=offset;leaf._scale=scale;leaf._rotation=rotation;leaf._alpha=alpha
		result.append(leaf)
	return result
