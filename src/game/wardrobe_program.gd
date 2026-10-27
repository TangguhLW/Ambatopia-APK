extends RefCounted

static func compare(a: float,op: int,b: float) -> bool:
	match op:
		0:return a<b
		1:return a<=b
		2:return a==b
		3:return a!=b
		4:return a>=b
		5:return a>b
	return false

static func resolve(raw,vars: Dictionary):
	if raw is Array and raw.size()==2 and raw[0] is String:
		if raw[0]=="v":return vars.get(str(raw[1]),0)
		if raw[0] in ["c","l"]:return raw[1]
	return raw

static func condition(row: Array,ctx: Dictionary,p) -> bool:
	if row.size()<2:return false
	var a: float=float(ctx.get("action",0))
	match str(row[0]):
		"c":return bool(row[1])
		"a":return compare(a,int(row[2]),float(row[1]))
		"g":return p.grounded==bool(row[1])
		"l":return (p.facing<0)==bool(row[1])
		"dn":return bool(row[1])==bool(ctx.get("dance",false))
		"f":
			var value: float=float({"speed.x":p.velocity.x,"speed.y":p.velocity.y,"speed.length":p.velocity.length()}.get(row[1],0))
			return compare(absf(value) if row.size()>4 and row[4] else value,int(row[2]),float(row[3]))
		"v":
			if not ctx.has(str(row[1])):return false
			var left=ctx[str(row[1])];var right=resolve(row[3],ctx)
			if left is Array and right is Array:
				var equal: bool=left.size()==right.size()
				if equal:
					for i in left.size():
						if left[i]!=right[i]:equal=false;break
				return equal==(int(row[2])==2)
			if left is bool:return (left==bool(right))==(int(row[2])!=3)
			if (left is float or left is int) and (right is float or right is int):return compare(float(left),int(row[2]),float(right))
			return false
		"af":return bool(ctx.get("animation_"+str(int(row[1])),false))!=bool(row[2])
		"w":
			var slots=["hat","shirt","pants","feet","face","hand","back","hair","neck","artifact"]
			var id: int=int(p.catalog_equipment.get(slots[int(row[1])],0));id=id-200000 if id>=200000 else id
			return compare(id,int(row[3]),float(row[2]))
		"s":return conditions([row[1],row[2]],ctx,p)
		"tag":return bool(ctx.get("tag_"+str(row[1]),false))!=bool(row[2])
	return false

static func conditions(raw: Array,ctx: Dictionary,p) -> bool:
	if raw.size()<2:return false
	var all_required:=bool(raw[0])
	for row in raw[1]:
		var result:=condition(row,ctx,p)
		if all_required and not result:return false
		if not all_required and result:return true
	return all_required

static func initial(ro: Dictionary) -> Dictionary:
	var sprites: Array=[]
	for s in ro.get("sd",[]):sprites.append({"frame":int(s.get("d",0)),"alpha":1.0,"position":Vector2.ZERO,"scale":Vector2.ONE,"rotation":0.0,"visible":true})
	return {"sprites":sprites,"animations":{},"machines":{},"machine_ages":{},"states":[],"vars":ro.get("vars",{}).duplicate(true)}

static func property(sprite: Dictionary,key: String,values: Array) -> void:
	if values.is_empty():return
	match key:
		"alpha":sprite.alpha=float(values[0])
		"rotation":sprite.rotation=float(values[0])
		"pos":sprite.position=Vector2(values[0],values[-1])
		"pos.x":sprite.position.x=float(values[0])
		"pos.y":sprite.position.y=float(values[0])
		"scale":sprite.scale=Vector2(values[0],values[-1])
		"scale.x":sprite.scale.x=float(values[0])
		"scale.y":sprite.scale.y=float(values[0])

static func curve(keys: Array,phase: float,column: int=1) -> float:
	if keys.is_empty():return 0
	if phase<=float(keys[0][0]):return float(keys[0][mini(column,keys[0].size()-1)])
	for i in range(1,keys.size()):
		if phase<=float(keys[i][0]):
			var a: Array=keys[i-1];var b: Array=keys[i]
			return lerpf(float(a[mini(column,a.size()-1)]),float(b[mini(column,b.size()-1)]),(phase-float(a[0]))/maxf(0.00001,float(b[0])-float(a[0])))
	return float(keys[-1][mini(column,keys[-1].size()-1)])

static func step(a: Dictionary,state: Dictionary,runtime: Dictionary,dt: float,time: float,depth: int=0) -> bool:
	if depth>24:return true
	var kind: String=str(a.k)
	state.age=float(state.get("age",0))+dt
	var duration:=maxf(1,float(a.get("ms",0)))
	var phase:=minf(1,float(state.age)/duration)
	if kind=="q":
		var children: Array=a.get("ch",[])
		var index:=int(state.get("index",0))
		for immediate in 2:
			if index>=children.size():return true
			if not state.has("child"):state.child={}
			if not step(children[index],state.child,runtime,dt,time,depth+1):return false
			index+=1;state.index=index;state.erase("child")
		return index>=children.size()
	if kind in ["vc","vi"]:
		var key: String=str(a.v)
		if kind=="vc":
			var n:=int(a.get("n",0))
			runtime.vars[key]=range(n).map(func(i):return curve(a.get("keys",[]),phase,i+1)) if n>0 else curve(a.get("keys",[]),phase)
		else:
			var current=runtime.vars.get(key,0)
			var goal=runtime.vars.get(str(a.get("gv","")),a.get("g",0))
			var offset=runtime.vars.get(str(a.get("go","")),0)
			if current is Array and goal is Array:
				var result: Array=[]
				for i in current.size():result.append(lerpf(float(current[i]),float(goal[mini(i,goal.size()-1)])+(float(offset[i]) if offset is Array and i<offset.size() else 0.0),phase))
				runtime.vars[key]=result
			elif current is float or current is int:runtime.vars[key]=lerpf(float(current),float(goal),phase)
	elif kind in ["f","c","p","vs"]:
		var id:=int(a.get("s",-1))
		if id<0 or id>=runtime.sprites.size():return true
		var sprite: Dictionary=runtime.sprites[id]
		match kind:
			"vs":sprite.visible=bool(a.get("vis",1));return true
			"f":
				var frames: Array=a.get("fr",[])
				if frames.is_empty():return true
				var ms: float=float(runtime.vars.get(str(a.get("msv","")),duration))
				var tick:=16*(floorf(ms/frames.size()/16)+1)
				sprite.frame=int(frames[mini(frames.size()-1,int(float(state.age)/tick))])
				duration=tick*frames.size()
			"c":
				var keys: Array=a.get("keys",[])
				property(sprite,str(a.p),[curve(keys,phase,1),curve(keys,phase,2)] if not keys.is_empty() and keys[0].size()>2 else [curve(keys,phase)])
			"p":
				for row in a.get("pr",[]):
					var wave:=sin(TAU*fmod(time,maxf(1,float(row[1])))/maxf(1,float(row[1]))) if row[1] else 0.0
					var values: Array=[]
					for value in row[3]:values.append(float(value)+wave*float(row[2]))
					property(sprite,str(row[0]),values)
				return false
	var done:=float(state.age)>=duration
	if done and a.get("lp",0):state.clear();return false
	return done

static func update(ro: Dictionary,runtime: Dictionary,ctx: Dictionary,p,dt: float,time: float) -> void:
	for name in runtime.vars:
		if ctx.has(name):runtime.vars[name]=ctx[name]
	var states: Array=[]
	for sm in ro.get("sm",[]):
		var key:=str(sm[0]);var index:=int(runtime.machines.get(key,int(sm[2])))
		runtime.machine_ages[key]=float(runtime.machine_ages.get(key,0))+dt
		for transition in sm[4].get(str(index),[]):
			var passes: bool=conditions(transition[1],ctx,p) if transition[1] is Array else float(runtime.machine_ages[key])>=float(sm[3][index])*1000
			if passes:
				index=int(transition[0]);runtime.machine_ages[key]=0;break
		runtime.machines[key]=index
		states.append(key+"."+str(sm[1][index]))
	var action_name: String={0:"Idle",1:"Walk",3:"Up",6:"Fall",8:"Punch"}.get(int(ctx.action),"Idle")
	for prefix in ["Motion","Action","PlayerAction"]:
		if not runtime.machines.has(prefix):states.append(prefix+"."+action_name)
	if int(ctx.action)==1:states.append("PlayerAction.Move")
	states.append("state.Equip")
	runtime.states=states
	for i in ro.get("an",[]).size():
		var animation: Dictionary=ro.an[i]
		var active: bool=bool(animation.get("ap",false)) or (not animation.has("on") and not animation.has("oa")) or animation.get("on",[]).any(func(on):return on in states) or animation.get("oa",[]).any(func(value):return int(value)==int(ctx.action))
		var key:=str(i)
		if not active:runtime.animations.erase(key);continue
		if not runtime.animations.has(key):runtime.animations[key]={}
		var anim_state: Dictionary=runtime.animations[key]
		if anim_state.get("done",false):continue
		anim_state.done=step(animation,anim_state,runtime,dt,time)
		ctx["animation_"+str(i)]=not anim_state.done
	ctx.merge(runtime.vars,true)

static func arithmetic(a: float,b: float,operation: int) -> float:
	match operation:
		0:return a+b
		1:return a-b
		2:return a*b
		3:return a/b if absf(b)>0.000001 else 0
	return b

static func operate(row: Array,ctx: Dictionary) -> void:
	if row.size()<3:return
	var name:=str(row[1]);var previous=ctx.get(name,0);var value=resolve(row[2],ctx)
	if previous is Array:
		var result: Array=[]
		for i in previous.size():
			var other: float=float(value[mini(i,value.size()-1)]) if value is Array and not value.is_empty() else float(value) if value is int or value is float else 0.0
			result.append(arithmetic(float(previous[i]),other,int(row[0])))
		if int(row[0])==5:
			var magnitude: float=sqrt(previous.reduce(func(total,v):return total+float(v)*float(v),0.0))
			var target: float=float(result[0])
			for i in result.size():result[i]=float(previous[i])/maxf(0.000001,magnitude)*target
		ctx[name]=result
	elif previous is bool:ctx[name]=bool(value)
	elif (previous is float or previous is int) and (value is float or value is int):ctx[name]=arithmetic(float(previous),float(value),int(row[0]))
