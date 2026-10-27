extends RefCounted
const Assets=preload("res://src/game/source_effect_assets.gd")
static var pets: Dictionary={}
static var punches: Dictionary={}
var elapsed:=0.0
var punch_age:=100.0
var previous_punch:=0.0
var pet_state:="i"
var pet_age:=0.0
var pet_motion=preload("res://src/game/source_pet_motion.gd").new()
var punch_particles: Array=[]
var punch_pending: Array=[]
var repeated: Array=[]
var sound_pending: Array=[]
var sound_events: Array=[]
const PUNCH_LIMIT:=256

static func load_data() -> void:
	if pets.is_empty():pets=JSON.parse_string(FileAccess.get_file_as_string("res://data/pet-tracks.json"))
	if punches.is_empty():punches=JSON.parse_string(FileAccess.get_file_as_string("res://data/punch-tracks.json"))

static func source(id: int) -> int:return id-200000 if id>=200000 else id

static func pet_for(player) -> Dictionary:
	var id:=pet_id_for(player)
	return pets.items.get(str(id),{})

static func pet_id_for(player) -> int:
	load_data()
	for id in player.catalog_equipment.values():
		var key:=str(source(int(id)))
		if pets.items.has(key) and bool(player.item_options.get("pet_"+key,true)):return int(key)
	return 0

static func punch_for(player) -> Dictionary:
	load_data()
	var slots=["hat","shirt","pants","feet","face","hand","back","hair","neck","artifact"]
	for slot in punches.slot_priority:
		var id:=str(source(int(player.catalog_equipment.get(slots[int(slot)],-1))))
		var key=punches.items.get(id)
		if key!=null and punches.punches.has(str(key)):return punches.punches[str(key)]
	return punches.punches.get("0",{})

func update(player,dt: float) -> void:
	elapsed+=dt;punch_age+=dt
	var pet_id:=pet_id_for(player)
	var active_pet: Dictionary=pets.items.get(str(pet_id),{})
	pet_motion.update(pet_id,active_pet,player,dt)
	for p in punch_particles:p.age+=dt
	punch_particles=punch_particles.filter(func(p):return p.age<float(p.track.life))
	if player.punch_time>previous_punch+0.001:
		punch_age=0;start_punch(player)
	for pending in punch_pending.duplicate():
		if punch_age<float(pending.t0):continue
		punch_pending.erase(pending);emit_punch(pending,player,maxf(0,punch_age-float(pending.t0)))
	for pending in repeated:
		if punch_age<float(pending.t0) or punch_age>=float(pending.pf.until):continue
		for i in int(pending.pf.n):emit_punch(pending,player,0,float(pending.pf.j))
	for sound in sound_pending.duplicate():
		if punch_age>=float(sound[0]):sound_events.append(str(sound[1]));sound_pending.erase(sound)
	previous_punch=player.punch_time
	pet_state=pet_motion.state;pet_age=pet_motion.age

func start_punch(player) -> void:
	punch_pending=[];repeated=[]
	var target: Vector2=Vector2(16,32)+player.punch_direction*Vector2(player.facing,1)*player.punch_distance
	var jitter:=Vector2(randf_range(-6,6),randf_range(-6,6))
	var profile:=punch_for(player)
	sound_pending=profile.get("snd",[]).duplicate(true)
	for raw in profile.get("P",[]):
		var p:=resolved_particle(raw,player.punch_distance>48).duplicate(true)
		var delta:=anchor_delta(raw,player)
		var aimed:=preload("res://src/game/source_punch_aim.gd").resolve(raw,target,profile.get("aim",{}).get("R",{}),delta)
		if not aimed.is_empty():p=aimed
		elif delta!=Vector2.ZERO:p.at=[float(p.at[0])+delta.x,float(p.at[1])+delta.y]
		if p.has("bolt"):
			p.at=[target.x+randf_range(-float(p.bolt.jx),float(p.bolt.jx)),32-float(p.bolt.tb)]
		elif p.has("sk"):
			var at: Vector2=target+(jitter if p.sk.get("pj",false) else Vector2.ZERO)
			if p.sk.has("yb"):at.y=target.y+float(p.sk.yb)
			p.at=[at.x+randf_range(-float(p.sk.j),float(p.sk.j)),at.y+randf_range(-float(p.sk.j),float(p.sk.j))]
			var angle:=randf()*TAU;var size:=randf_range(0.4,1);var rotation:=randf()*360
			p.life=minf(0.5,size);p.erase("cs")
			p.cv={"t":[],"x":[],"y":[],"sx":[],"sy":[],"a":[],"r":[]}
			for i in 9:
				var t:=float(i)/8;var age: float=t*p.life
				p.cv.t.append(t);p.cv.x.append(60*cos(angle)*age);p.cv.y.append(60*sin(angle)*age+30*age*age)
				p.cv.sx.append(size-age);p.cv.sy.append(size-age);p.cv.a.append(1-2*age);p.cv.r.append(rotation+720*age)
		elif p.has("cone"):
			var hand:=Vector2(p.cone.hand[0],p.cone.hand[1]);var distance:=hand.distance_to(target)
			for i in int(p.cone.n):
				var copy:=p.duplicate(true);var radius:=randf_range(distance/4,distance);var spread:=maxf(10,90-0.7*radius)
				var at:=hand+Vector2.from_angle((target-hand).angle()+deg_to_rad(randf_range(-spread,spread)))*radius
				copy.at=[at.x,at.y];punch_pending.append(copy)
			continue
		if p.has("pf"):repeated.append(p)
		else:punch_pending.append(p)

func emit_punch(track: Dictionary,player,age: float,jitter:=0.0) -> void:
	if punch_particles.size()>=PUNCH_LIMIT or age>=float(track.life):return
	punch_particles.append({"track":track,"age":age,"origin":player.position,"face":player.facing,"jitter":Vector2(randf_range(-jitter,jitter),randf_range(-jitter,jitter))})

static func curve(cv: Dictionary,key: String,t: float,default: float) -> float:
	var times: Array=cv.get("t",[]);var values: Array=cv.get(key,[])
	if values.is_empty():return default
	if values.size()==1 or times.is_empty():return float(values[0])
	for i in range(1,mini(times.size(),values.size())):
		if t<=float(times[i]):return lerpf(float(values[i-1]),float(values[i]),clampf((t-float(times[i-1]))/maxf(0.000001,float(times[i])-float(times[i-1])),0,1))
	return float(values[-1])

func draw_pet(canvas: CanvasItem,player) -> void:
	var pet:=pet_for(player)
	if pet.is_empty() or pet_motion.active_id==0:return
	var sequence: Array=pet.get("S",{}).get(pet_state,pet.get("S",{}).get("i",[]))
	if sequence.is_empty():return
	var duration:=0.0
	for pair in sequence:duration+=float(pair[1])
	var clock:=fmod(pet_age*1000,maxf(1,duration));var selected:=int(sequence[-1][0])
	for pair in sequence:
		clock-=float(pair[1])
		if clock<0:selected=int(pair[0]);break
	if pet.has("pm") and pet_motion.mode>=1:
		var mode: int=pet_motion.mode if pet.k=="o" else 4+(int(pet_motion.clock)&1) if pet_motion.mode==2 else 3
		selected=int(pet.pm.get(str(mode),selected))
	if selected>=pet.F.size():return
	for index in pet.F[selected]:
		if int(index)>=pet.B.size():continue
		var b: Array=pet.B[int(index)]
		if b.size()<18:continue
		var image=Assets.texture(str(pets.sheets[int(b[0])]))
		if image==null:continue
		var region:=Rect2(b[1],b[2],b[3],b[4])
		if not Rect2(Vector2.ZERO,image.get_size()).encloses(region):continue
		var pivot:=Vector2(b[10],b[11])
		var extent:=Vector2(b[7],b[8])
		var flip:=Vector2(-1 if b[12] else 1,-1 if b[13] else 1)
		var offset:=Vector2(b[5],b[6])-pivot+Vector2(extent.x if b[12] else 0,extent.y if b[13] else 0)
		var origin: Vector2=(pet_motion.position-player.position).floor()+Vector2(0,pet_motion.bob)
		if canvas.has_method("body_lift"):origin.y-=canvas.body_lift(player)
		var rotation:=deg_to_rad(pet_motion.angle)
		var centre:=Vector2(0,-16 if int(pet.t) in [2,6,13,18,30] else 0)
		var transformed: Vector2=(centre+(pivot-centre).rotated(rotation))*pet_motion.scale_in
		canvas.draw_set_transform(origin+transformed*Vector2(pet_motion.face,1),(rotation+deg_to_rad(float(b[9])))*pet_motion.face,Vector2(pet_motion.face,1)*flip*pet_motion.scale_in)
		canvas.draw_texture_rect_region(image,Rect2(offset*flip,extent),region,Color(float(b[14])/255,float(b[15])/255,float(b[16])/255,float(b[17])/255))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))

func anchor_delta(particle: Dictionary,player) -> Vector2:
	var anchor:=str(particle.get("an",""))
	if anchor not in ["pet","mid"] or pet_motion.active_id==0:return Vector2.ZERO
	var nominal: Array=punches.get("_",{}).get("nominal_anchor",{}).get("pet",[0,32])
	return pet_motion.anchor_delta(player,Vector2(nominal[0],nominal[1]))*(1-float(particle.get("af",0)) if anchor=="mid" else 1)

static func resolved_particle(particle: Dictionary,far: bool) -> Dictionary:
	var result:=particle.duplicate()
	if not far or not particle.has("at80"):return result
	result.at=particle.at80
	var base: Dictionary=particle.get("cv",{})
	var extra: Dictionary=particle.get("cv80",{})
	var merged: Dictionary=base.duplicate(true)
	if extra.has("t"):
		for key in base:
			if key=="t" or extra.has(key):continue
			merged[key]=extra.t.map(func(t):return curve(base,key,float(t),0))
	for key in extra:merged[key]=extra[key]
	result.cv=merged
	for key in ["t0","life","cs"]:
		if particle.has(key+"80"):result[key]=particle[key+"80"]
	return result

func draw_punch(canvas: CanvasItem,player,additive:=false,front:=true) -> void:
	var profile:=punch_for(player)
	if profile.is_empty():return
	for instance in punch_particles:
		var raw: Dictionary=instance.track
		if (raw.get("b")=="lighter")!=additive or (str(raw.get("g","f"))=="f")!=front:continue
		var particle: Dictionary=raw
		var age: float=instance.age;var life:=float(particle.get("life",0))
		if age<0 or age>=life:continue
		var image=Assets.texture(str(particle.get("sheet","")))
		var c: Array=particle.get("c",[])
		if image==null or c.size()<4:continue
		var region:=Rect2(c[0],c[1],c[2],c[3])
		var cv: Dictionary=particle.get("cv",{});var phase:=age/maxf(life,0.001)
		for key in particle.get("cs",[]):
			if float(key[0])>phase:break
			if key[1] is Array and key[1].size()==4:region=Rect2(key[1][0],key[1][1],key[1][2],key[1][3])
		if not Rect2(Vector2.ZERO,image.get_size()).encloses(region):continue
		var at: Array=particle.get("at",[0,0])
		var offset:=Vector2(float(at[0])-16,float(at[1])-32)+Vector2(curve(cv,"x",phase,0),curve(cv,"y",phase,0))
		offset+=instance.jitter
		var origin: Vector2=player.position if particle.get("fol",false) else instance.origin
		var point: Vector2=origin-player.position+offset*Vector2(instance.face,1)
		var extent:=region.size*Vector2(absf(curve(cv,"sx",phase,1)),absf(curve(cv,"sy",phase,1)))
		var flip:=Vector2(-1 if curve(cv,"sx",phase,1)<0 else 1,-1 if curve(cv,"sy",phase,1)<0 else 1)
		if particle.get("fx",false):flip.x*=-1
		if particle.get("flr",false) and randf()<0.5:flip.x*=-1
		var align: Array=particle.get("al",[0.5,0.5])
		var tint:=punch_tint(particle,phase,elapsed)
		if particle.has("bolt"):
			var alpha:=tint.a;var width:=region.size.x*(0.1 if alpha<=0.1 else randf_range(0.1,2*alpha))
			var top:=canvas.get_global_transform_with_canvas().affine_inverse()*Vector2.ZERO
			canvas.draw_set_transform(point,0,Vector2(-1 if randf()<0.5 else 1,1))
			canvas.draw_texture_rect_region(image,Rect2(-width/2,top.y-point.y,width,maxf(0,point.y-top.y)),region,tint)
			continue
		canvas.draw_set_transform(point,deg_to_rad(curve(cv,"r",phase,0))*instance.face,Vector2(instance.face,1)*flip)
		canvas.draw_texture_rect_region(image,Rect2(-extent*Vector2(align[0],align[1]),extent),region,tint)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))

static func punch_tint(p: Dictionary,phase: float,time: float) -> Color:
	var tint:=Color.WHITE
	if p.has("tint"):
		var end: Array=p.get("tint2",p.tint)
		tint=Color(lerpf(p.tint[0],end[0],phase)/255,lerpf(p.tint[1],end[1],phase)/255,lerpf(p.tint[2],end[2],phase)/255)
	if p.has("rb"):
		var hue:=fposmod(4*floorf(fposmod(0.005*float(p.rb)*fposmod(time*20,360),360)/4)/360,1)
		tint=Color.from_hsv(hue,1,1)
	tint.a=clampf(curve(p.get("cv",{}),"a",phase,1),0,1)
	return tint
