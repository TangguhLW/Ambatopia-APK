extends RefCounted

static var manifest: Dictionary={}
static var records: Dictionary={}
static var textures: Dictionary={}
static var icons: Texture2D
const CACHE_LIMIT := 64
var state := "stand"
var state_age := 0.0
var landing_age := -1.0
var previously_grounded := true

static func index() -> Dictionary:
	if manifest.is_empty():
		manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/web-wardrobe-index.json"))
	return manifest

static func definition(id: int) -> Dictionary:
	if id>=200000:id-=200000
	if records.has(id):return records[id]
	var location: Array=index().items.get(str(id),[])
	if location.is_empty():return {}
	var file=FileAccess.open("res://assets/web-wardrobe/records.bin",FileAccess.READ)
	if file==null:
		push_error("Wardrobe metadata pack is missing")
		return {}
	file.seek(int(location[0]))
	var record=JSON.parse_string(file.get_buffer(int(location[1])).get_string_from_utf8())
	if not record is Dictionary:
		push_error("Invalid wardrobe record: "+str(id))
		return {}
	if records.size()>=CACHE_LIMIT:records.erase(records.keys()[0])
	records[id]=record
	return record

static func can_render(item: Dictionary) -> bool:
	var key:=str(int(item.get("id",-1)))
	return index().get("names",{}).get(key)==item.get("name") and index().get("renderers",{}).get(key) in ["basic","g","xr"]

static func icon(id: int) -> Texture2D:
	if id>=200000:id-=200000
	var cell:=int(index().get("icons",{}).get(str(id),-1))
	if cell<0:return null
	if icons==null:icons=load("res://assets/web-wardrobe/icons.png")
	var atlas=AtlasTexture.new()
	atlas.atlas=icons
	atlas.region=Rect2(Vector2(cell%64,int(cell/64))*32,Vector2(32,32))
	atlas.filter_clip=true
	return atlas

static func texture(key: String) -> Texture2D:
	if textures.has(key):
		var cached: Texture2D=textures[key]
		textures.erase(key)
		textures[key]=cached
		return cached
	var location: Dictionary=index().sheets.get(key,{})
	if location.is_empty():return null
	var file=FileAccess.open("res://assets/web-wardrobe/atlas.bin",FileAccess.READ)
	if file==null:
		push_error("Wardrobe texture pack is missing")
		return null
	file.seek(int(location.offset))
	var image=Image.new()
	if image.load_png_from_buffer(file.get_buffer(int(location.bytes)))!=OK:
		push_error("Invalid wardrobe PNG: "+key)
		return null
	if image.get_width()!=int(location.width) or image.get_height()!=int(location.height):
		push_error("Wardrobe PNG dimensions changed: "+key)
		return null
	var result=ImageTexture.create_from_image(image)
	if textures.size()>=CACHE_LIMIT:textures.erase(textures.keys()[0])
	textures[key]=result
	return result

func update(player,delta: float) -> void:
	if player.grounded and not previously_grounded:landing_age=0
	elif landing_age>=0:landing_age+=delta*1000
	previously_grounded=player.grounded
	var next: String="up" if not player.grounded and player.velocity.y<0 else "fall" if not player.grounded else "walk" if absf(player.velocity.x)>1 else "stand"
	if next!=state:
		state=next
		state_age=0
	state_age+=delta*1000

static func sequence_frame(sequence: Array,ms: float,loop: bool) -> int:
	var frames: Array=sequence[3] if sequence.size()>3 and sequence[3] is Array else []
	if not frames.is_empty():
		var total:=0.0
		for frame in frames:total+=float(frame[1])
		if total<=0:return int(frames[0][0])
		var phase:=fmod(ms,total) if loop else minf(ms,total-0.001)
		for frame in frames:
			if phase<float(frame[1]):return int(frame[0])
			phase-=float(frame[1])
		return int(frames[-1][0])
	var count:=maxi(1,int(sequence[1]))
	var step:=maxf(1,float(sequence[2]))
	return int(sequence[0])+(int(ms/step)%count if loop else mini(count-1,int(ms/step)))

static func frame_index(record: Dictionary,ms: float,pose: String="stand",punch_ms: float=-1) -> int:
	var states: Dictionary=record.get("st",{})
	if not states.is_empty():
		if punch_ms>=0 and states.has("punch"):return sequence_frame(states.punch,punch_ms,false)
		return sequence_frame(states.get(pose,states.get("stand",[0,1,0,[[0,0]],0])),ms,pose!="land")
	var count:=maxi(1,int(record.get("n",1)))
	var durations=record.get("ms",100)
	if durations is Array:
		var total:=0.0
		for value in durations:total+=float(value)
		var phase:=fmod(ms,maxf(1,total))
		for i in durations.size():
			if phase<float(durations[i]):return i
			phase-=float(durations[i])
		return 0
	return int(ms/maxf(1,float(durations)))%count

static func commands(record: Dictionary,ms: float,pose: String="stand",punch_ms: float=-1) -> Array:
	var result: Array=[]
	var frame:=frame_index(record,ms,pose,punch_ms)
	var scale:=1.0/maxf(0.001,float(record.get("z",1)))
	for layer in record.get("L",[]):
		if layer.size()<9:continue
		var extent:=Vector2(layer[4],layer[5])
		var columns:=maxi(1,int(layer[7]))
		var selected:=mini(frame,maxi(0,int(layer[8])-1))
		result.append({"pass":int(layer[0]),"kind":str(layer[1]),"source":Rect2(Vector2((selected%columns)*extent.x,float(layer[6])+floorf(float(selected)/columns)*extent.y),extent),"destination":Rect2(Vector2(-16,-32)+Vector2(layer[2],layer[3]),extent*scale)})
	return result

static func supports(record: Dictionary) -> bool:
	return not record.is_empty() and not record.has("ro") and record.has("bk") and not record.get("L",[]).is_empty()

static func phase_commands(record: Dictionary,ms: float,pose: String="stand",punch_ms: float=-1,phase: String="body") -> Array:
	return commands(record,ms,pose,punch_ms).filter(func(command):
		return int(command.pass)==5 if phase=="back_arm" else int(command.pass)==19 if phase=="front_arm" else int(command.pass) not in [5,19])

func draw_slot(canvas: CanvasItem,player,id: int,elapsed: float,foot_a: float,foot_b: float,arm_a: float,arm_b: float,phase: String="body") -> bool:
	var record:=definition(id)
	if not supports(record):return false
	var image:=texture(record.bk)
	if image==null:return false
	var timing:=animation_timing(record,elapsed)
	for command in phase_commands(record,timing.age,timing.pose,(player.PUNCH_DURATION-player.punch_time)*1000 if player.punch_time>0 else -1,phase):
		var destination: Rect2=command.destination
		var tint:=Color.WHITE
		if command.kind=="1":destination.position.y+=foot_a
		elif command.kind=="2":destination.position.y+=foot_b
		elif command.kind in ["3","4","pc","s1","s2"]:tint=Color(player.SKINS[player.skin_index])
		elif command.kind.begins_with("hd:"):
			var rgb=command.kind.substr(3).split(",")
			if rgb.size()==3:tint=Color(float(rgb[0])/255,float(rgb[1])/255,float(rgb[2])/255)
		var angle:=0.0
		var pivot:=Vector2.ZERO
		if command.kind in ["rA","rB","rP"]:
			pivot=Vector2(8,-13) if command.kind=="rA" else Vector2(-7,-13)
			angle=arm_a if command.kind=="rA" else arm_b
		elif int(record.slot)==5 and player.punch_time>0:
			destination.position+=player.punch_direction*Vector2(player.facing,1)*sin((1-player.punch_time/player.PUNCH_DURATION)*PI)*22
		if angle!=0:
			canvas.draw_set_transform(pivot*Vector2(player.facing,1),angle*player.facing,Vector2(player.facing,1))
			destination.position-=pivot
		canvas.draw_texture_rect_region(image,destination,command.source,tint)
		if angle!=0:canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
	return true

func animation_timing(record: Dictionary,elapsed: float) -> Dictionary:
	var states: Dictionary=record.get("st",{})
	var pose: String=state if states.has(state) else "stand"
	var age: float=state_age if pose!="stand" else elapsed*1000
	if previously_grounded and landing_age>=0 and states.has("land"):
		var duration:=0.0
		for frame in states.land[3]:duration+=float(frame[1])
		if landing_age<duration:pose="land";age=landing_age
	return {"pose":pose,"age":age}
