extends RefCounted

static var definitions: Dictionary={}
static var textures: Dictionary={}
var particles: Array=[]
var clocks: Dictionary={}
var was_grounded=true
var last_jump_velocity=0.0
var motion_state:="Idle"
var action_state:="Equip"
var state_time:=0.0

static func definition(id: int) -> Dictionary:
	if definitions.is_empty():
		definitions=JSON.parse_string(FileAccess.get_file_as_string("res://data/native-renderers.json"))
	return definitions.get(str(id-200000 if id>=200000 else id),{})

static func vector(value, fallback: Vector2=Vector2.ZERO) -> Vector2:
	if not value is String:
		return fallback
	var parts=value.split(",")
	return Vector2(float(parts[0]),float(parts[1] if parts.size()>1 else parts[0]))

static func number(value, default_value: float) -> float:
	return float(value) if value is String or value is float or value is int else default_value

static func curve(keys: Array, phase: float) -> float:
	if keys.is_empty():
		return 1.0
	for i in range(1,keys.size()):
		if phase<=float(keys[i][0]):
			return lerpf(float(keys[i-1][1]),float(keys[i][1]),clampf((phase-float(keys[i-1][0]))/maxf(0.0001,float(keys[i][0])-float(keys[i-1][0])),0,1))
	return float(keys.back()[1])

static func animation_enabled(spec: Dictionary,motion: String="Idle",action: String="Equip") -> bool:
	var state: String=spec.get("playOnState",spec.get("onState",""))
	if state.begins_with("Motion."):return state=="Motion."+motion
	if state.begins_with("state."):return state=="state."+action
	return state.is_empty()

static func sprite_frame(d: Dictionary, name: String, elapsed: float,motion: String="Idle",action: String="Equip",state_elapsed: float=-1) -> Vector2:
	var frame=vector(",".join(d.sprites[name].frame.map(str)))
	for animation in d.animations:
		if animation.sprite==name and not animation.frames.is_empty() and animation_enabled(animation,motion,action):
			var local_time: float=state_elapsed if animation.has("playOnState") and state_elapsed>=0 else elapsed
			var phase:=local_time*1000/maxf(1,float(animation.ms))
			phase=fmod(phase,1) if animation.get("isLoop","false")=="true" else minf(phase,0.99999)
			var index=int(phase*animation.frames.size())
			frame=Vector2(animation.frames[index][0],animation.frames[index][1])
	return frame

func update(player, dt: float) -> void:
	var next_motion: String="Idle" if player.grounded else "Jump" if player.velocity.y<0 else "Fall"
	var next_action: String="Punch" if player.punch_time>0 else "Equip"
	state_time=0 if next_motion!=motion_state or next_action!=action_state else state_time+dt
	motion_state=next_motion;action_state=next_action
	for p in particles:
		p.age+=dt
	particles=particles.filter(func(p):return p.age<p.life)
	var action="PUNCH" if player.punch_time>0 else "JUMP" if not player.grounded and player.velocity.y<0 else "FALL" if not player.grounded else "WALK" if absf(player.velocity.x)>1 else "IDLE"
	var jumped=not player.grounded and player.velocity.y<0 and (was_grounded or player.velocity.y<last_jump_velocity-100)
	var worn: Array=[]
	for id in player.catalog_equipment.values():
		var d=definition(int(id))
		if d.is_empty():
			continue
		worn.append(int(id))
		for rule in d.emit:
			if rule.hook!="AddClothingParticles":
				continue
			var actions=str(rule.get("onAction",""))
			var event=jumped and ("JUMPSTART" in actions or "JUMPDOUBLE" in actions)
			if not event and action not in actions.split("|"):
				continue
			var k=str(id)+":"+rule.name
			var spec: Dictionary=d.particles[rule.name]
			var interval=number(spec.emitter.get("emissionInterval",spec.emitter.get("interval")),0.1)
			clocks[k]=float(clocks.get(k,0))+dt
			if not event and float(clocks[k])<interval:
				continue
			clocks[k]=fmod(float(clocks[k]),maxf(0.01,interval))
			var count=clampi(int(number(spec.emitter.get("particlesPerEmission"),1)),1,8)
			for i in count:
				if particles.size()>=96:
					break
				var settings: Dictionary=spec.particle
				var velocity=Vector2.ZERO
				var extra_offset=Vector2.ZERO
				var scale=Vector2.ONE
				if settings.get("velocity") is Dictionary:
					var v=settings.velocity
					velocity=vector(v.min).lerp(vector(v.max),randf())
				if settings.get("offset") is Dictionary:
					var v=settings.offset
					extra_offset=vector(v.min).lerp(vector(v.max),randf())
				else:
					extra_offset=vector(settings.get("offset","0,0"))
				if settings.get("initialScale") is Dictionary:
					var v=settings.initialScale
					scale=vector(v.min).lerp(vector(v.max),randf())
				else:
					scale=vector(settings.get("initialScale","1,1"),Vector2.ONE)
				var position=vector(spec.emitter.get("offset","0,0"))+extra_offset+Vector2(0,-20)
				for increment in settings.get("increments",[]):
					if increment.source=="particleIndex":
						if increment.name=="initialScale":
							scale+=vector(increment.multiplier)*i
						elif increment.name=="worldPos":
							position+=vector(increment.multiplier)*i
				particles.append({"id":int(id),"sprite":settings.get("sprite",""),"age":0.0,"life":maxf(0.01,number(settings.get("lifeTime"),0.5)),"position":position,"origin":player.position,"facing":player.facing,"velocity":velocity,"scale":scale,"settings":settings})
	particles=particles.filter(func(p):return p.id in worn)
	was_grounded=player.grounded
	last_jump_velocity=player.velocity.y

func paint_sprite(canvas: CanvasItem,d: Dictionary,name: String,position: Vector2,scale: Vector2,elapsed: float,alpha: float=1.0,flip: bool=false,alignment: String="CENTER") -> void:
	if not d.sprites.has(name):
		return
	var sprite: Dictionary=d.sprites[name]
	if not textures.has(sprite.file):
		textures[sprite.file]=load("res://assets/native-effects/%s.png" % sprite.file)
	var size=Vector2(sprite.size[0],sprite.size[1])
	var point=sprite_frame(d,name,elapsed,motion_state,action_state,state_time)*size
	for animation in d.get("curves",[]):
		if animation.sprite!=name or not animation_enabled(animation,motion_state,action_state):continue
		var phase:=fmod(elapsed*1000/maxf(1,float(animation.ms)),1)
		for property in animation.curves:
			var value=curve(animation.curves[property],phase)
			if property=="alpha":alpha*=value
			elif property=="pos.y":position.y+=value
	var anchor:=Vector2(0.5,0.5)
	if alignment=="DOWN_CENTER":anchor.y=1
	elif alignment=="UPPER_CENTER":anchor.y=0
	elif alignment=="LEFT_CENTER":anchor.x=0
	elif alignment=="RIGHT_CENTER":anchor.x=1
	var dest=Rect2(position-size*scale*anchor,size*scale)
	if flip:
		dest.position.x+=dest.size.x
		dest.size.x=-dest.size.x
	canvas.draw_texture_rect_region(textures[sprite.file],dest,Rect2(point,size),Color(1,1,1,alpha))

func draw_slot(canvas: CanvasItem,id: int,elapsed: float,hook_filter: String="") -> bool:
	var d=definition(id)
	if d.is_empty():
		return false
	for rule in d.render:
		if not hook_filter.is_empty() and rule.hook!=hook_filter:continue
		if not animation_enabled(rule,motion_state,action_state):continue
		var position=vector(rule.get("offset","0,0"))
		var alignment: String=rule.get("alignmentRight",rule.get("alignment","CENTER"))
		paint_sprite(canvas,d,rule.name,position,Vector2.ONE,elapsed,1,rule.has("flip"),alignment)
	return true

func draw_pass(canvas: CanvasItem,player,hook: String,elapsed: float) -> void:
	for id in player.catalog_equipment.values():draw_slot(canvas,int(id),elapsed,hook)

func draw_particles(canvas: CanvasItem,player) -> void:
	for p in particles:
		var d=definition(p.id)
		var settings: Dictionary=p.settings
		var phase=clampf(p.age/p.life,0,1)
		var alpha=1.0
		if settings.get("initialAlpha") is Dictionary:
			alpha=curve(settings.initialAlpha.get("curve",[]),phase)
		else:
			alpha=number(settings.get("initialAlpha"),1)
			if settings.get("interpolateAlpha")=="true":
				alpha=lerpf(alpha,number(settings.get("finalAlpha"),0),phase)
		var scale: Vector2=p.scale
		if settings.get("interpolateScale")=="true":
			scale=scale.lerp(vector(settings.get("finalScale","1,1")),phase)
		var point: Vector2=p.position+p.velocity*p.age
		if settings.get("useGravity")=="true":
			point+=vector(settings.get("gravityVector","0,50"))*0.5*p.age*p.age
		if settings.get("relativeToEmitter")!="true":
			point+=(p.origin-player.position)*Vector2(player.facing,1)
		paint_sprite(canvas,d,p.sprite,point,scale,p.age,alpha)
