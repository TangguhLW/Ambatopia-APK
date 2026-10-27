extends Control
const Guild=preload("res://src/game/guild_weather.gd")
const Icons=preload("res://src/game/inventory_icons.gd")
var view
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	if view==null or view.world==null or view.world.weather!="guild":return
	var params:=Guild.parameters(view.world,view.backdrop.weather_parameters)
	if params.is_empty():return
	var fg:=Icons.texture(int(params.mascot_fg))
	var bg:=Icons.texture(int(params.mascot_bg)) if int(params.mascot_bg)!=0 else null
	if fg==null:return
	var time:=Time.get_unix_time_from_system()
	for particle in Guild.particles(size,time,params,view.backdrop.low_quality):
		var rect: Rect2=particle.rect
		draw_set_transform(rect.get_center(),float(particle.angle))
		var local:=Rect2(-rect.size/2,rect.size)
		if bg!=null:draw_texture_rect(bg,local,false)
		draw_texture_rect(fg,local,false)
	draw_set_transform(Vector2.ZERO)
