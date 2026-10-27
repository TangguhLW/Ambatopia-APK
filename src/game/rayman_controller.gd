extends RefCounted
const Assets=preload("res://src/game/source_effect_assets.gd")
var held:=false
var age:=0.0
var target:=Vector2i.ZERO
var locked:=false

static func equipped(player) -> bool:
	var id:=int(player.catalog_equipment.get("hand",-1))
	return id in [5480,205480] and int(player.catalog_equipment.get("face",-1)) not in [4288,204288]

func sample(player,state: Dictionary,dt: float) -> Dictionary:
	if not equipped(player):
		held=false;age=0;locked=false;player.rayman_charge=0;player.rayman_level=0
		return state
	var pressing: bool=state.action=="punch"
	if locked:
		if not pressing:locked=false
		state.action="none";state.pressed=false
		return state
	if pressing:
		target=state.target
		if state.get("direct_punch",false):target=Vector2i(((player.position+Vector2(player.facing*36,-16))/32).floor())
		age+=dt;held=true;player.rayman_charge=age
		player.rayman_level=3 if age>1.5 else 2 if age>1 else 1 if age>0.5 else 0
		state.action="none";state.pressed=false
		if age>=11:
			locked=true;held=false;player.rayman_charge=0;player.rayman_fire=0.32;age=0
			state.action="punch";state.pressed=true;state.target=target;state.direct_punch=false
	elif held:
		held=false;state.action="punch";state.target=target;state.direct_punch=false;state.pressed=true
		player.rayman_charge=0;player.rayman_fire=0.32;age=0
	return state

static func draw(canvas: CanvasItem,player) -> void:
	if not equipped(player):return
	if player.rayman_charge>0:
		var image=Assets.texture("particles")
		if image==null:return
		var cells=[7,8,11,12];var cell:=int(cells[clampi(player.rayman_level,0,3)])
		canvas.draw_set_transform(Vector2(-16*player.facing,-16),deg_to_rad(player.rayman_charge*720)*player.facing,Vector2(player.facing,1))
		canvas.draw_texture_rect_region(image,Rect2(-16,-16,32,32),Rect2(cell*32,15*32,32,32))
	elif player.rayman_fire>0:
		var image=Assets.texture("fisticuffs")
		if image==null:return
		var direction: Vector2=player.punch_direction
		var progress: float=1-player.rayman_fire/0.32
		canvas.draw_set_transform(Vector2(0,-16)+direction*progress*72,direction.angle(),Vector2.ONE)
		canvas.draw_texture_rect_region(image,Rect2(-32,-16,64,32),Rect2(64 if player.rayman_level>=2 else 0,0,64,32))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
