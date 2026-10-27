extends Node2D
signal source_punch_sound(name: String)

var player
var shadow_capture:=false
var spirit_shadow
var frame_probe=preload("res://src/diagnostics/frame_probe.gd").new()
var native_renderer=preload("res://src/game/native_item_renderer.gd").new()
var web_wardrobe=preload("res://src/game/web_wardrobe.gd").new()
var source_particles=preload("res://src/game/wardrobe_particles.gd").new()
var legacy_particles=preload("res://src/game/source_legacy_particles.gd").new()
var ancestral_particles=preload("res://src/game/ancestral_particles.gd").new()
var death_sequence=preload("res://src/game/death_sequence.gd").new()
var item_tracks=preload("res://src/game/source_item_tracks.gd").new()
var special_wardrobe=preload("res://src/game/special_wardrobe.gd").new()
var textures := {}
var elapsed := 0.0
var frames := {}
var equipment_frames := {}
var amba_texture: Texture2D
var worn_cache: Dictionary = {}
var clothing_metadata: Dictionary={}
var foot1:=0.0
var foot2:=0.0
var limb_phase:=false
var arm1:=0.0
var arm2:=0.0
var previous_locomotion:="idle"
var walk_phase:=0.0
const SLOT_ORIGINS = {
	"hat":Vector2(-16,-48),"hair":Vector2(-16,-48),
	"face":Vector2(-16,-32),"neck":Vector2(-16,-32),
	"back":Vector2(-16,-32),"shirt":Vector2(-16,-32),
	"pants":Vector2(-16,-32),"feet":Vector2(-16,-32),
	"hand":Vector2(-16,-16),"artifact":Vector2(-16,-32)
}

func slot_origin(slot: String) -> Vector2:
	return SLOT_ORIGINS.get(slot,Vector2(-16,-32))

func _ready() -> void:
	if not shadow_capture:
		spirit_shadow=preload("res://src/game/spirit_shadow.gd").new();spirit_shadow.avatar=self;add_child(spirit_shadow)
		create_effect_layers()
	amba_texture = load("res://assets/ambatopia/amba-body.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frames = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas.json")).avatar
	equipment_frames = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment-samples.json")).slots
	for id in ["body", "head", "eyes", "eyes2", "face", "extraleg", "sleeve", "arm", "feet", "puncharm", "hair", "shirts", "pants"]:
		textures[id] = load("res://assets/reference/%s.png" % id)

func create_effect_layers() -> void:
	var back_glow=preload("res://src/game/ancestral_back_glow.gd").new();back_glow.avatar=self;add_child(back_glow)
	var punch_back=preload("res://src/game/punch_back_glow.gd").new();punch_back.avatar=self;add_child(punch_back)
	for additive in [false,true]:
		var death_layer=preload("res://src/game/death_layer.gd").new()
		death_layer.avatar=self;death_layer.additive=additive;add_child(death_layer)
	var glow=preload("res://src/game/wardrobe_glow.gd").new()
	glow.avatar=self
	add_child(glow)

func present(state, _alpha: float) -> void:
	player = state
	queue_redraw()

func _process(delta: float) -> void:
	var probe_start:=frame_probe.start()
	elapsed += delta
	if player!=null:
		player.visual_lift=body_lift(player)
		advance_limbs(delta)
		native_renderer.update(player,delta)
		web_wardrobe.update(player,delta)
		special_wardrobe.update(player,delta,foot1,foot2,arm1,arm2)
		var overrides: Dictionary=special_wardrobe.pose_overrides
		arm1=deg_to_rad(float(overrides.armB)) if overrides.has("armB") else arm1
		arm2=deg_to_rad(float(overrides.armF)) if overrides.has("armF") else arm2
		foot1=float(overrides.get("foot1",foot1));foot2=float(overrides.get("foot2",foot2))
		source_particles.update(player,special_wardrobe,delta)
		legacy_particles.update(player,delta,arm1)
		ancestral_particles.update(player,delta)
		item_tracks.update(player,delta)
		for sound in item_tracks.sound_events:source_punch_sound.emit(str(sound))
		item_tracks.sound_events.clear()
		if player.punch_time>0:
			var punch_profile:=item_tracks.punch_for(player)
			if not punch_profile.is_empty() and item_tracks.punch_age<float(punch_profile.d):
				arm2=deg_to_rad(death_sequence.keyframe(punch_profile.B,item_tracks.punch_age))
		death_sequence.update(player,delta)
		if player.death_time>=0 and player.death_time<2:
			var death_pose=death_sequence.visual(player)
			arm1=deg_to_rad(death_pose.armB);arm2=deg_to_rad(death_pose.armF)
			foot1=0;foot2=0
	queue_redraw()
	frame_probe.end("avatar_update",probe_start)

func frame(id: String, source: Rect2, destination: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(textures[id], destination, source, tint)

func source_frame(id: String) -> Rect2:
	var coordinates: Array = frames[id]
	return Rect2(coordinates[0], coordinates[1], coordinates[2], coordinates[3])

func pose() -> Dictionary:
	if player==null:return {}
	return {"facing":player.facing,"locomotion":"air" if not player.grounded else "walk" if absf(player.velocity.x)>1 else "idle","expression":"punch" if player.punch_time>0 else "talk" if player.talk_time>0 else "normal"}

func body_lift(state) -> float:
	return preload("res://src/game/wearable_pose.gd").lift(state,elapsed)

func advance_limbs(dt: float) -> void:
	var state: String=pose().locomotion
	var a:=0.0
	var b:=0.0
	var speed:=20.0
	if state=="air":
		a=1 if player.velocity.y<0 else -2
		b=a
		speed=30
	elif state=="walk":
		walk_phase=fmod(walk_phase+absf(player.velocity.x)*dt/20.0,4.0)
		var triangle:=walk_phase if walk_phase<2 else 4-walk_phase
		a=-2+triangle
		b=-triangle
	if state=="walk" and not preload("res://src/game/wearable_pose.gd").no_walk(player):
		foot1=a;foot2=b
	else:
		walk_phase=0
		foot1=move_toward(foot1,a,speed*dt)
		foot2=move_toward(foot2,b,speed*dt)
	var target1: float=deg_to_rad(200 if player.velocity.y<0 else 0) if state=="air" else deg_to_rad((foot1+1)*20) if state=="walk" else 0.0
	var target2: float=target1 if state=="air" else deg_to_rad((foot2+1)*20) if state=="walk" else 0.0
	var fast_settle:=absf(angle_difference(0,arm1))>deg_to_rad(20) or absf(angle_difference(0,arm2))>deg_to_rad(20)
	var arm_speed:=900.0 if state=="walk" or state=="air" and player.velocity.y<0 or state=="idle" and fast_settle else 200.0 if state=="air" else 100.0
	arm1=rotate_toward(arm1,target1,deg_to_rad(arm_speed)*dt)
	arm2=rotate_toward(arm2,target2,deg_to_rad(arm_speed)*dt)
	if player.punch_time>0:
		var age: float=player.PUNCH_DURATION-player.punch_time
		arm1=0 if age<0.23 else deg_to_rad(minf(0,900*(age-0.23)-78))
		arm2=deg_to_rad(maxf(20,75-900*age)) if age<0.23 else 0
	previous_locomotion=state

func skin_tint() -> Color:
	var tint:=Color(player.SKINS[player.skin_index])
	if player.death_time>=0 and player.death_time<2:
		var death_skin: Array=death_sequence.visual(player).skin
		if death_skin.size()==3:return Color(float(death_skin[0])/255,float(death_skin[1])/255,float(death_skin[2])/255)
	if player.burn_time>0:tint=tint.lerp(Color("ff7848"),0.35+sin(elapsed*22)*0.1)
	for mod in player.modifiers.values():
		if mod.get("tint","")!="" and mod.get("slot","body")=="body":tint=Color(mod.tint)
	return tint

static func arm_geometry(back: bool) -> Dictionary:
	return {"source":Rect2(0,0,6,10),"destination":Rect2(-3,-1,6,10),"shoulder":Vector2(8 if back else -7,-13)}

static func punch_geometry(age: float,direction: Vector2) -> Dictionary:
	return {"source":Rect2(180,0,20,48),"destination":Rect2(-10,0,20,48),"shoulder":Vector2(8.4,-14),"angle":direction.angle()-PI/2+deg_to_rad(-3),"scale":Vector2(1.75,1)*minf(1.05,0.07+4.6*age)}

func source_punch_geometry(age: float,direction: Vector2) -> Dictionary:
	var profile:=item_tracks.punch_for(player)
	if profile.is_empty():return punch_geometry(age,direction)
	if age>=float(profile.d) or profile.get("stretch")==null:return {}
	var geometry:=punch_geometry(age,direction)
	geometry.scale=Vector2(death_sequence.keyframe(profile.stretch.w,age),death_sequence.keyframe(profile.stretch.l,age))
	geometry.angle=direction.angle()+deg_to_rad(death_sequence.keyframe(profile.A,age)-360)
	return geometry

func arm(back: bool,angle: float,tint: Color) -> void:
	var geometry:=arm_geometry(back)
	draw_set_transform(geometry.shoulder*Vector2(player.facing,1),angle*player.facing,Vector2(player.facing,1))
	frame("arm",geometry.source,geometry.destination,tint)
	draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))

func draw_sleeves(phase: String) -> void:
	for id in player.catalog_equipment.values():
		var record:=web_wardrobe.definition(int(id))
		if not web_wardrobe.supports(record) or special_wardrobe.hidden_slots.has(int(record.slot)):continue
		web_wardrobe.draw_slot(self,player,int(id),elapsed,foot1,foot2,arm1,arm2,phase)

func draw_back_arm(tint: Color) -> void:
	if special_wardrobe.hidden_parts.has("armB"):return
	var age: float=player.PUNCH_DURATION-player.punch_time
	var punch_shape:=source_punch_geometry(age,player.punch_direction*Vector2(player.facing,1)) if player.punch_time>0 else {}
	if not punch_shape.is_empty() and not special_wardrobe.pose_overrides.get("no_fist",false):
		var geometry: Dictionary=punch_shape
		draw_set_transform(geometry.shoulder*Vector2(player.facing,1),geometry.angle*player.facing,geometry.scale*Vector2(player.facing,1))
		frame("puncharm",geometry.source,geometry.destination,tint)
		if not special_wardrobe.hidden_parts.has("slA"):
			var shirt:=web_wardrobe.definition(int(player.catalog_equipment.get("shirt",-1)))
			for sleeve in shirt.get("sl",[]):
				var rgb: Array=sleeve[2]
				frame("puncharm",Rect2(20*(int(sleeve[0])+4*int(sleeve[1])),0,20,48),geometry.destination,Color(float(rgb[0])/255,float(rgb[1])/255,float(rgb[2])/255))
		draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
	else:
		arm(true,arm1,tint)
		draw_sleeves("back_arm")

func face_frame() -> int:
	if player.death_time>=0 and player.death_time<2:return int(death_sequence.visual(player).face)
	if player.punch_time>0:
		var profile:=item_tracks.punch_for(player)
		if not profile.is_empty() and item_tracks.punch_age<float(profile.d):return int(death_sequence.keyframe(profile.face,item_tracks.punch_age,true))
	if player.punch_time>0 and player.PUNCH_DURATION-player.punch_time<0.27:return 4
	if player.talk_time>0 and int(elapsed*8)%2==0:return 2
	if not player.grounded:return 1 if player.velocity.y<0 else 2
	return 0

static func eyelid_region(expression: int) -> Rect2:
	return Rect2((expression%8)*32,128+floori(expression/8.0)*32,32,32)

func blinking() -> bool:
	var ms:=int(elapsed*1000)
	var phase:=ms%4000
	return face_frame()==0 and (phase>=3700 and phase<3830 or int(ms/4000)%3==2 and phase>=3900 and phase<3990)

func draw_native_body() -> void:
	var tint:=skin_tint()
	var shirt=player.catalog_equipment.get("shirt",-1)
	var no_arms:=false
	if shirt>=0:
		var record: Dictionary=preload("res://src/game/item_catalog.gd").record(int(shirt)-200000 if shirt>=200000 else int(shirt))
		no_arms=int(record.get("raw_metadata",{}).get("visualEffect",0))==8
	if not no_arms:draw_back_arm(tint)
	if not special_wardrobe.hidden_parts.has("body"):frame("body",Rect2(0,32 if special_wardrobe.hidden_parts.has("legs") else 0,32,32),Rect2(-16,-32,32,32),tint)
	if not special_wardrobe.hidden_parts.has("legs"):
		if not special_wardrobe.hidden_parts.has("leg0"):frame("extraleg",Rect2(0,0,8,1),Rect2(-8,-4,8,maxf(0,foot2+2)),tint)
		if not special_wardrobe.hidden_parts.has("leg1"):frame("extraleg",Rect2(8,0,8,1),Rect2(0,-4,8,maxf(0,foot1+2)),tint)
	if not special_wardrobe.hidden_parts.has("head"):frame("head",Rect2(0,0,32,32),Rect2(-16,-32,32,32),tint)
	var eye_frame:=face_frame()
	if not special_wardrobe.hidden_parts.has("head"):
		var source:=Rect2(eye_frame*32,0,32,32)
		if not special_wardrobe.hidden_parts.has("eyes"):
			frame("eyes",source,Rect2(-16,-32,32,32))
			frame("eyes",eyelid_region(eye_frame),Rect2(-16,-32,32,32),Color(minf(1,tint.r+2.0/255),minf(1,tint.g+2.0/255),minf(1,tint.b+2.0/255)))
			var mouth_tint:=Color(maxf(0,tint.r-60.0/255),maxf(0,tint.g-60.0/255),maxf(0,tint.b-60.0/255)) if eye_frame==0 else Color.WHITE
			frame("face",source,Rect2(-16,-32,32,32),mouth_tint)
			frame("eyes2",source,Rect2(-16,-32,32,32),Color.BLACK)
			if blinking():frame("face",Rect2(160,96,32,32),Rect2(-16,-32,32,32),tint)
	if not player.catalog_equipment.has("feet"):
		if not special_wardrobe.hidden_parts.has("footA"):frame("feet",Rect2(0,32,32,32),Rect2(-16,-32+floorf(foot1),32,32),tint)
		if not special_wardrobe.hidden_parts.has("footB"):frame("feet",Rect2(0,0,32,32),Rect2(-16,-32+floorf(foot2),32,32),tint)
func draw_front_arm() -> void:
	if special_wardrobe.hidden_parts.has("armF"):return
	var shirt_id: int=player.catalog_equipment.get("shirt",-1)
	if shirt_id>=200000:shirt_id-=200000
	var metadata: Dictionary=preload("res://src/game/item_catalog.gd").record(shirt_id).get("raw_metadata",{}) if shirt_id>=0 else {}
	if int(metadata.get("visualEffect",0))!=8:
		var tint:=skin_tint()
		var age: float=player.PUNCH_DURATION-player.punch_time
		arm(false,arm2,tint)
		if not special_wardrobe.hidden_parts.has("slB"):draw_sleeves("front_arm")

func _draw() -> void:
	var probe_start:=frame_probe.start()
	if player == null or textures.is_empty():
		return
	draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
	if player.amba:
		var bounce := absf(sin(elapsed*12))*1.5 if absf(player.velocity.x)>1 and player.grounded else 0.0
		draw_texture_rect(amba_texture,Rect2(-16,-32-bounce,32,32),false)
		draw_set_transform(Vector2.ZERO)
		return
	if player.death_time>=0 and death_sequence.visual(player).hide:return
	var lift:=body_lift(player)
	if not shadow_capture and lift<0 and player.grounded and not preload("res://src/game/spirit_shadow.gd").active(player):
		draw_set_transform(Vector2(0,-lift),0,Vector2(1,0.2))
		draw_circle(Vector2.ZERO,10,Color(0,0,0,0.28))
		draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
	if not shadow_capture:
		source_particles.draw(self,player,false)
		ancestral_particles.draw(self,player,false,false)
		if not preload("res://src/game/rayman_controller.gd").equipped(player):item_tracks.draw_punch(self,player,false,false)
		special_wardrobe.draw_hook(self,"RenderBehind",player.facing)
		special_wardrobe.draw_hook(self,"RenderAura",player.facing)
	special_wardrobe.draw_hook(self,"RenderTransform",player.facing)
	draw_catalog_slot("back")
	if not shadow_capture:draw_effects()
	for hook in ["RenderBackHat","RenderBackHair","RenderChestBackItem","RenderBackArm","RenderBackHandItem"]:special_wardrobe.draw_hook(self,hook,player.facing)
	for id in player.catalog_equipment.values():
		if not special_wardrobe.supports(web_wardrobe.definition(int(id))):native_renderer.draw_slot(self,int(id),elapsed,"RenderBackHat")
	draw_native_body()
	for slot in ["pants","shirt","hair"]:
		if special_wardrobe.hidden_slots.has(preload("res://src/game/special_wardrobe.gd").SLOTS.find(slot)):continue
		var legacy: int = player.equipment.get(slot,-1)
		if legacy >= 0 and legacy < equipment_frames[slot].size():
			var entry: Dictionary = equipment_frames[slot][legacy]
			var coords: Array = entry.frame
			frame(entry.asset,Rect2(coords[0],coords[1],coords[2],coords[3]),Rect2(slot_origin(slot),Vector2(32,32)))
	for slot in ["feet","pants","shirt"]:
		draw_catalog_slot(slot)
	draw_front_arm()
	for hook in ["RenderFrontArm","RenderPreFrontArm","RenderFrontpack"]:special_wardrobe.draw_hook(self,hook,player.facing)
	for slot in ["neck","face","hair","hat","hand"]:
		draw_catalog_slot(slot)
	draw_catalog_slot("artifact")
	if shadow_capture:
		draw_set_transform(Vector2.ZERO)
		return
	item_tracks.draw_pet(self,player)
	draw_fallback_pet()
	special_wardrobe.draw_hook(self,"RenderInFront",player.facing)
	source_particles.draw(self,player,true)
	legacy_particles.draw(self,player)
	ancestral_particles.draw(self,player,false)
	if not preload("res://src/game/rayman_controller.gd").equipped(player):item_tracks.draw_punch(self,player)
	preload("res://src/game/rayman_controller.gd").draw(self,player)
	if player.modifiers.has("Golden Halo!"):
		draw_arc(Vector2(0,-37),10,0,TAU,20,Color("ffe17e"),2)
	if player.modifiers.has("Devil Horns"):
		for side in [-1,1]:
			draw_rect(Rect2(side*9-2,-37,4,8),Color("e34c41"))
	draw_set_transform(Vector2.ZERO)

	frame_probe.end("avatar_draw",probe_start)

func draw_effects() -> void:
	native_renderer.draw_particles(self,player)
	var abilities: Dictionary = player.abilities()
	var source_effects:=false
	for id in player.catalog_equipment.values():
		var record:=web_wardrobe.definition(int(id))
		if record.has("ef") or record.has("xs") or record.has("ro"):source_effects=true;break
	if abilities.glow and not source_effects:
		for i in 8:
			var angle := elapsed+i*TAU/8
			draw_circle(Vector2(cos(angle)*18,-18+sin(angle)*20),1.5,Color(1,0.85,0.3,0.65))
	if abilities.trail and not source_effects and absf(player.velocity.x)>1:
		for i in 5:
			draw_rect(Rect2(-12-i*5,-10+sin(elapsed*12+i)*5,3,3),Color(0.6,0.9,1,1-i*0.18))
	for mod in player.modifiers.values():
		if mod.get("kind")=="creative_effect":
			var image: Texture2D=preload("res://src/game/simulator_catalog.gd").sprite(int(mod.item))
			if image!=null:
				var point:=Vector2(cos(elapsed*2)*24,-20+sin(elapsed*2)*20)
				draw_texture_rect(image,Rect2(point,Vector2(10,10)),false,Color(1,1,1,0.75))

func draw_fallback_pet() -> void:
	if player.abilities().pet and preload("res://src/game/source_item_tracks.gd").pet_for(player).is_empty():
		for id in player.catalog_equipment.values():
			var item: Dictionary = preload("res://src/game/item_catalog.gd").summary(int(id))
			if "leash" in str(item.get("name","")).to_lower() or "pet " in str(item.get("name","")).to_lower():
				var record:=web_wardrobe.definition(int(id))
				if record.has("ro") or record.has("ef") or record.has("xs"):continue
				var image: Texture2D=preload("res://src/game/item_catalog.gd").sprite(int(id))
				if image!=null:
					draw_texture_rect(image,Rect2(-38,-23+absf(sin(elapsed*8))*3,24,24),false)

func draw_catalog_slot(slot: String) -> void:
	if slot=="hand" and player.punch_time>0:
		var profile:=item_tracks.punch_for(player)
		if not profile.is_empty() and bool(profile.get("hide",false)) and item_tracks.punch_age<float(profile.d):return
	if slot=="hand" and preload("res://src/game/rayman_controller.gd").equipped(player) and (player.rayman_charge>0 or player.rayman_fire>0):return
	var id: int = player.catalog_equipment.get(slot,-1)
	if id < 0:
		worn_cache.erase(slot)
		return
	if special_wardrobe.hidden_slots.has(preload("res://src/game/special_wardrobe.gd").SLOTS.find(slot)):return
	var special_hook: String={"back":"RenderBackpack","hat":"RenderHat","hair":"RenderHair","shirt":"RenderShirt","face":"RenderFaceItem","pants":"RenderPants","hand":"RenderHandItem","feet":"RenderShoes","neck":"RenderChestItem"}.get(slot,"")
	if special_wardrobe.supports(web_wardrobe.definition(id)):
		special_wardrobe.draw_hook(self,special_hook,player.facing)
		return
	if web_wardrobe.draw_slot(self,player,id,elapsed,foot1,foot2,arm1,arm2):
		return
	if slot=="artifact" and ancestral_particles.supported(web_wardrobe.definition(id)):return
	var native_hook: String={"back":"RenderBackpack","hat":"RenderHat","hair":"RenderHair","shirt":"RenderShirt","face":"RenderFaceItem","pants":"RenderPants","hand":"RenderHandItem","feet":"RenderShoes","neck":"RenderChestItem"}.get(slot,"")
	if not native_hook.is_empty() and native_renderer.draw_slot(self,id,elapsed,native_hook):
		return
	var image: Texture2D = clothing_texture(slot,id)
	if image == null:
		return
	var offset := Vector2.ZERO
	if slot=="hand" and player.punch_time>0:
		offset=player.punch_direction*Vector2(player.facing,1)*sin((1-player.punch_time/player.PUNCH_DURATION)*PI)*22
	elif slot=="feet":offset.y=foot1
	var tint:=Color.WHITE
	for mod in player.modifiers.values():
		if mod.get("slot")==slot and mod.get("tint","")!="":
			tint=Color(mod.tint)
	for layer in clothing_layers(id,image):
		draw_texture_rect(layer.texture,Rect2(slot_origin(slot)+offset,Vector2(32,32)),false,tint*layer.tint)
	var second: Texture2D = worn_cache.get(slot,{}).get("second_foot")
	if slot=="feet" and second!=null:
		draw_texture_rect(second,Rect2(slot_origin(slot)+Vector2(0,foot2),Vector2(32,32)),false,tint)

func clothing_texture(slot: String, id: int) -> Texture2D:
	var catalog = preload("res://src/game/item_catalog.gd")
	if not worn_cache.has(slot) or worn_cache[slot].id != id:
		worn_cache[slot] = {"id":id,"texture":catalog.sprite(id)}
		if slot=="feet":
			var source := ""
			if id>=200000:
				var row: Array=preload("res://src/game/simulator_catalog.gd").items().get(str(id-200000),[])
				if not row.is_empty():
					source=str(row[1])
			else:
				source=str(catalog.record(id).get("asset",{}).get("source",""))
			var image: Texture2D=worn_cache[slot].texture
			if "player_feet" in source and image is AtlasTexture and image.region.end.y+32<=image.atlas.get_height():
				var second := AtlasTexture.new()
				second.atlas=image.atlas
				second.region=Rect2(image.region.position+Vector2(0,32),image.region.size)
				worn_cache[slot].second_foot=second
	return worn_cache[slot].texture

func shifted_frame(image: Texture2D, cells: Vector2i) -> Texture2D:
	if not image is AtlasTexture:return image
	var rect: Rect2=image.region
	rect.position+=Vector2(cells)*32
	if not Rect2(Vector2.ZERO,image.atlas.get_size()).encloses(rect):return image
	var shifted:=AtlasTexture.new()
	shifted.atlas=image.atlas
	shifted.region=rect
	shifted.filter_clip=true
	return shifted

func seed_color(value: int) -> Color:
	return Color(float((value>>8)&255)/255,float((value>>16)&255)/255,float((value>>24)&255)/255,float(value&255)/255)

func clothing_layers(id: int, image: Texture2D) -> Array:
	if not clothing_metadata.has(id):
		if clothing_metadata.size()>=64:clothing_metadata.erase(clothing_metadata.keys()[0])
		var catalog=preload("res://src/game/item_catalog.gd")
		var original:=id-200000 if id>=200000 else id
		var record: Dictionary=catalog.record(original)
		var metadata: Dictionary=record.get("raw_metadata",{}) if record.get("name")==catalog.summary(id).get("name") else {}
		clothing_metadata[id]={"visual":int(metadata.get("visualEffect",0)),"seed":catalog.record(original+1).get("raw_metadata",{})}
	var spec: Dictionary=clothing_metadata[id]
	if int(spec.visual) in [4,7]:return [{"texture":shifted_frame(image,Vector2i(int(elapsed/0.2)%2,0)),"tint":Color.WHITE}]
	if int(spec.visual) in [20,22,27,38,39] and spec.seed.has("baseColor"):
		return [{"texture":image,"tint":seed_color(int(spec.seed.baseColor))},{"texture":shifted_frame(image,Vector2i(1,0)),"tint":seed_color(int(spec.seed.overlayColor))}]
	return [{"texture":image,"tint":Color.WHITE}]
