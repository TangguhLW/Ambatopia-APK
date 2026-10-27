extends RefCounted
const Tracks=preload("res://src/game/source_item_tracks.gd")
const Assets=preload("res://src/game/source_effect_assets.gd")
static var data: Dictionary={}
var age:=0.0
var previous_epoch:=-1
var particles: Array=[]
var pending: Array=[]
var origin:=Vector2.ZERO
static func additive_blend(mode) -> bool:
	if mode is String:return mode=="lighter"
	return (mode is int or mode is float) and mode==1
static func source() -> Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/death-tracks.json"))
	return data
static func profile(player) -> Dictionary:
	var d:=source();var result={"B":d.B,"skin":d.skin,"snd":d.snd.duplicate(),"hide":false,"P":[d.angel]}
	var selected: Array=[]
	for id in player.catalog_equipment.values():
		var key:=str(Tracks.source(int(id)))
		if d.items.has(key):selected.append({"id":int(key),"entry":d.items[key]})
	var chain:=-1
	for id in d.chain:
		if selected.any(func(item):return item.id==int(id)):chain=int(id);break
	if selected.any(func(item):return bool(item.entry.get("na",false))):result.P=[]
	for item in selected:
		var entry: Dictionary=item.entry
		if entry.has("B"):result.B=entry.B
		if entry.get("nt",false):result.skin=[]
		result.hide=result.hide or bool(entry.get("hide",false))
		result.snd.append_array(entry.get("snd",[]))
		for effect in entry.get("P",[]):
			if not effect.get("ch",false) or item.id==chain:result.P.append(effect)
	return result
static func keyframe(keys: Array,time: float,step:=false) -> float:
	if keys.is_empty():return 0
	for i in range(1,keys.size()):
		if time<float(keys[i][0]):
			if step:return float(keys[i-1][1])
			return lerpf(float(keys[i-1][1]),float(keys[i][1]),clampf((time-float(keys[i-1][0]))/maxf(0.00001,float(keys[i][0])-float(keys[i-1][0])),0,1))
	return float(keys[-1][1])
static func visual(player) -> Dictionary:
	var p: Dictionary=player.death_profile if not player.death_profile.is_empty() else profile(player)
	return {"scale":keyframe(p.B.sc,player.death_time),"armB":keyframe(p.B.A,player.death_time),"armF":keyframe(p.B.B,player.death_time),"face":int(keyframe(p.B.face,player.death_time,true)),"skin":p.skin,"hide":p.hide and player.death_time<source().d}
func update(player,dt: float) -> void:
	if player.death_epoch!=previous_epoch:
		previous_epoch=player.death_epoch
		if player.death_time>=0:
			age=0;origin=player.death_origin;pending=[]
			for emitter in player.death_profile.P:
				for time in emitter.t:pending.append({"time":float(time),"emitter":emitter})
	age+=dt
	for p in particles:p.age+=dt
	particles=particles.filter(func(p):return p.age<float(p.track.L))
	for item in pending.duplicate():
		if age<item.time:continue
		pending.erase(item)
		var emitter: Dictionary=item.emitter
		var variants: Array=[emitter] if emitter.has("c") else source().L.get(str(emitter.get("l","")),[])
		if variants.is_empty():continue
		var track: Dictionary=variants.pick_random()
		var image=Assets.texture(str(track.c[0]))
		if image==null:continue
		var offset:=Vector2(randf_range(float(emitter.x[0]),float(emitter.x[-1])),randf_range(float(emitter.y[0]),float(emitter.y[-1])))-Vector2(16,32)
		if particles.size()<160:particles.append({"age":0.0,"origin":origin,"offset":offset,"track":track,"image":image})
func draw(canvas: CanvasItem,player,additive: bool) -> void:
	for p in particles:
		var tr: Dictionary=p.track
		if additive_blend(tr.get("b",0))!=additive:continue
		var phase:=clampf(float(p.age)/maxf(0.001,float(tr.L)),0,1)
		var source_rect:=Rect2(tr.c[1],tr.c[2],tr.c[3],tr.c[4])
		for cell in tr.get("cl",[]):
			if phase<float(cell[0]):break
			source_rect.position=Vector2(cell[1],cell[2])
		if not Rect2(Vector2.ZERO,p.image.get_size()).encloses(source_rect):continue
		var motion: Dictionary=tr.get("P",{})
		var point: Vector2=p.origin-player.position+p.offset+Vector2(Tracks.curve(motion,"x",phase,0),Tracks.curve(motion,"y",phase,0))
		var extent:=Vector2(Tracks.curve(tr.cv,"x",phase,source_rect.size.x),Tracks.curve(tr.cv,"y",phase,source_rect.size.y))
		canvas.draw_set_transform(point,deg_to_rad(lerpf(float(tr.r[0]),float(tr.r[-1]),phase)+Tracks.curve(motion,"r",phase,0)))
		canvas.draw_texture_rect_region(p.image,Rect2(-extent/2,extent),source_rect,Color(1,1,1,Tracks.curve(tr.cv,"a",phase,1)))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
