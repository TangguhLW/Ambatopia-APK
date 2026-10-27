extends RefCounted
const W=preload("res://src/game/web_wardrobe.gd")
const Assets=preload("res://src/game/source_effect_assets.gd")
const Expr=preload("res://src/game/special_wardrobe.gd")
const LIMIT:=48
var particles: Array=[]
var clocks: Dictionary={}
var elapsed:=0.0

static func memory(defaults: Dictionary,overrides: Dictionary) -> PackedByteArray:
	var bytes:=PackedByteArray();bytes.resize(784);bytes.fill(0)
	for map in [defaults,overrides]:
		for key in map:
			var offset:=str(key).hex_to_int()
			if offset>=0 and offset+4<=bytes.size():bytes.encode_u32(offset,int(map[key]))
	return bytes

static func f(bytes: PackedByteArray,offset: int) -> float:return bytes.decode_float(offset)
static func flag(bytes: PackedByteArray,offset: int) -> bool:return bytes[offset]!=0

static func supported(record: Dictionary) -> bool:
	for row in record.get("ef",{}).get("rows",[]):
		if row.get("anc",0):return true
	return false

func update(player,dt: float) -> void:
	elapsed+=dt
	for p in particles:
		p.age+=dt
		var phase:=clampf(float(p.age)/float(p.life),0,1)
		var velocity:=Vector2(f(p.mem,132),f(p.mem,136))
		if flag(p.mem,160):velocity=velocity.lerp(Vector2(f(p.mem,140),f(p.mem,144)),phase)
		p.point+=velocity*dt
	particles=particles.filter(func(p):return p.age<p.life)
	var active: Dictionary={}
	for id in player.catalog_equipment.values():
		var record:=W.definition(int(id))
		if not supported(record) and int(record.get("id",0))!=5264:continue
		var ef: Dictionary=record.ef
		for row in ef.rows:
			var neon:=int(record.id)==5264 and int(row.get("ty",0))==39
			if not row.get("anc",0) and not neon:continue
			if neon and player.velocity==Vector2.ZERO:continue
			var key:=str(record.id)+":"+str(row.ty);active[key]=true
			var definition: Dictionary=ef.types.get(str(int(row.ty))+":0",{})
			var variants: Array=definition.get("vars",[])
			if neon:variants=[definition]
			if variants.is_empty():continue
			var phase: float=(sin(TAU*elapsed*1000/maxf(1,float(definition.get("vms",500))))+1)/2
			var index:=0
			for i in definition.get("vr",[]).size():
				var limits: Array=definition.vr[i]
				if phase>=float(limits[0]) and phase<=float(limits[1]):index=i;break
			var variant: Dictionary=variants[mini(index,variants.size()-1)]
			var emitter:=memory({},variant.get("e",{}))
			var interval:=maxf(1.0/60,f(emitter,152))
			clocks[key]=float(clocks.get(key,0))+dt
			if float(clocks[key])<interval or particles.size()>=LIMIT:continue
			clocks[key]=fmod(float(clocks[key]),interval)
			spawn(player,record,row,variant,phase)
	for key in clocks.keys():
		if not active.has(key):clocks.erase(key)

func spawn(player,record: Dictionary,row: Dictionary,variant: Dictionary,phase: float) -> void:
	# This family contains source lot/R/fr programs, not child/curve emitters.
	for key in ["p2","pol","flot","clot","ch","rel","tl","md","mlot","tab","ctab","cmul"]:
		if not variant.get(key,[]).is_empty():return
	var mem:=memory(record.ef.D,variant.w)
	var randoms: Array=[]
	for i in variant.get("R",[]).size():
		var spec: Array=variant.R[i]
		var value:=randf()
		if spec[0]=="sot":
			value=(sin(TAU*elapsed*1000/maxf(1,float(spec[1])))+1)/2
			var limits: Array=variant.get("rg",{}).get(str(i),[])
			if limits.size()==2:value=clampf((value-float(limits[0]))/maxf(0.00001,float(limits[1])-float(limits[0])),0,1)
		randoms.append(value)
	for lot in variant.get("lot",[]):
		mem.encode_float(str(lot[0]).hex_to_int(),lerpf(float(lot[2]),float(lot[3]),float(randoms[int(lot[1])])))
	var ctx={"bx":0,"by":0,"face":player.facing}
	var at: Array=row.get("at",[0,0])
	var point:=Vector2(Expr.value(at[0],ctx),Expr.value(at[1],ctx))+Vector2(f(mem,444),f(mem,448))
	var image=Assets.texture(str(variant.get("t","particles")))
	var frames: Array=variant.get("fr",[])
	if image==null or frames.is_empty():return
	var cell: Array=frames[0]
	var size:=float(variant.get("fs",32))
	var region:=Rect2(float(cell[0])*size,float(cell[1])*size,size,size)
	if not Rect2(Vector2.ZERO,image.get_size()).encloses(region):return
	particles.append({"item":int(record.id),"mem":mem,"point":point,"origin":player.position+Vector2(0,player.visual_lift),"age":0.0,"life":maxf(0.016,f(mem,440)),"image":image,"region":region})

func geometry(p: Dictionary) -> Dictionary:
	var phase:=clampf(float(p.age)/float(p.life),0,1)
	var scale:=Vector2(f(p.mem,240),f(p.mem,244))
	if flag(p.mem,264):scale=scale.lerp(Vector2(f(p.mem,248),f(p.mem,252)),phase)
	var alpha:=f(p.mem,280)
	if flag(p.mem,292):alpha=lerpf(alpha,f(p.mem,284),phase)
	if flag(p.mem,408):alpha=maxf(f(p.mem,412),(sin(float(p.age)*TAU/maxf(0.001,float(p.mem.decode_s32(432))/1000)+4.712389)+1)/2)
	var color:=Color(f(p.mem,344),f(p.mem,348),f(p.mem,352),clampf(alpha,0,1))
	if flag(p.mem,416):
		var wave:=sin(TAU*elapsed*1000/maxf(1,float(p.mem.decode_s32(432))))
		color.r=maxf(f(p.mem,420),color.r-(color.r-f(p.mem,420))*(1-wave))
		color.g=maxf(f(p.mem,424),color.g-(color.g-f(p.mem,424))*(1-wave))
		color.b=maxf(f(p.mem,428),color.b-(color.b-f(p.mem,428))*(1-wave))
	if flag(p.mem,436):
		var hue:=fposmod(0.5*sin(TAU*fmod(floorf(elapsed*1000),10000)/10000)+0.5,1.0)
		var rainbow:=Color.from_hsv(hue,1,1)
		color=Color(rainbow.r,rainbow.g,rainbow.b,color.a)
	return {"scale":scale,"color":color,"additive":p.mem.decode_s32(392)==1,"behind":flag(p.mem,529)}

func draw(canvas: CanvasItem,player,additive: bool,front: bool=true) -> void:
	for p in particles:
		var g:=geometry(p)
		if g.additive!=additive or g.behind==front:continue
		var point: Vector2=p.point+p.origin-player.position
		point.y-=player.visual_lift
		var extent: Vector2=p.region.size*g.scale
		canvas.draw_set_transform(point)
		canvas.draw_texture_rect_region(p.image,Rect2(-extent/2,extent),p.region,g.color)
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
