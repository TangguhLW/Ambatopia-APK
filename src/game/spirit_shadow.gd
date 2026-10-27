extends Node2D

const AGES=[0.06,0.12,0.18]
const CAPTURE_ORIGIN=Vector2(64,96)
var avatar
var history: Array=[]
var clock:=0.0
var capture: SubViewport
var silhouette

static func active(player) -> bool:
	if player==null or player.amba or player.death_time>=0:return false
	return player.catalog_equipment.values().any(func(id):return int(id) in [6064,206064])

func _ready() -> void:
	show_behind_parent=true
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func sample(player,dt: float) -> void:
	clock+=dt
	if not active(player):history.clear();return
	var point: Vector2=player.position+Vector2(0,player.visual_lift)
	if not history.is_empty() and point.distance_to(history[-1].point)>96:history.clear()
	history.append({"time":clock,"point":point})
	while history.size()>24 or not history.is_empty() and clock-float(history[0].time)>0.25:history.pop_front()

func traces(player) -> Array:
	var result: Array=[]
	if not active(player) or history.is_empty():return result
	var current: Vector2=player.position+Vector2(0,player.visual_lift)
	for i in AGES.size():
		var selected: Dictionary={}
		for row in history:
			if float(row.time)<=clock-float(AGES[i])+0.00001:selected=row
		if not selected.is_empty() and selected.point.distance_to(current)>1:
			result.append({"offset":selected.point-current,"alpha":0.24-float(i)*0.06})
	return result

func _process(dt: float) -> void:
	if not is_instance_valid(avatar):return
	sample(avatar.player,dt)
	var rows:=traces(avatar.player)
	if not rows.is_empty():
		if capture==null:
			capture=SubViewport.new();capture.size=Vector2i(128,128)
			capture.transparent_bg=true;capture.disable_3d=true
			capture.render_target_clear_mode=SubViewport.CLEAR_MODE_ALWAYS
			add_child(capture)
			silhouette=avatar.get_script().new();silhouette.shadow_capture=true
			capture.add_child(silhouette);silhouette.set_process(false)
			silhouette.position=CAPTURE_ORIGIN
		for key in ["player","elapsed","foot1","foot2","arm1","arm2","native_renderer","web_wardrobe","special_wardrobe","item_tracks","death_sequence"]:silhouette.set(key,avatar.get(key))
		silhouette.queue_redraw()
		capture.render_target_update_mode=SubViewport.UPDATE_ONCE
	elif capture!=null:capture.render_target_update_mode=SubViewport.UPDATE_DISABLED
	queue_redraw()

func _draw() -> void:
	if capture==null or not is_instance_valid(avatar):return
	for row in traces(avatar.player):
		draw_texture_rect(capture.get_texture(),Rect2(row.offset-CAPTURE_ORIGIN,Vector2(128,128)),false,Color(0,0,0,row.alpha))
