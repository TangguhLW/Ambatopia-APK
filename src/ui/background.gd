extends Control

var renderer
var frame_probe=preload("res://src/diagnostics/frame_probe.gd").new()
var weather := "sunny"
var weather_parameters: Dictionary={}
var weather_key := ""
var weather_texture: Texture2D
var elapsed := 0.0
var menu_mode := true
var generic_mode := false
var camera_offset := 0.0
var generic_texture: Texture2D
var cloud_texture: Texture2D
var sun_texture: Texture2D
var hills: Array[Texture2D] = []
var low_quality := false
var weather_surface: SubViewport
var weather_canvas: Control
var weather_picture: TextureRect

func _ready() -> void:
	renderer = load("res://src/ui/weather_renderer.gd").new()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	generic_texture = load("res://assets/reference/menu.png")
	cloud_texture = load("res://assets/reference/cloud.png")
	sun_texture = load("res://assets/reference/sun.png")
	for id in ["hills3","hills2","hills1"]:
		hills.append(load("res://assets/reference/" + id + ".png"))
	if not menu_mode and not get_meta("weather_surface_child",false) and (OS.get_name()=="Android" or get_meta("force_weather_viewport",false)):
		create_weather_surface()

func create_weather_surface() -> void:
	weather_surface=SubViewport.new()
	weather_surface.disable_3d=true
	weather_surface.world_2d=World2D.new()
	weather_surface.gui_disable_input=true
	weather_surface.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	weather_surface.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(weather_surface)
	weather_canvas=load("res://src/ui/background.gd").new()
	weather_canvas.menu_mode=false
	weather_canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	weather_canvas.set_meta("weather_surface_child",true)
	weather_canvas.frame_probe=frame_probe
	weather_surface.add_child(weather_canvas)
	weather_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	weather_canvas.set_process(false)
	renderer=weather_canvas.renderer
	weather_picture=TextureRect.new()
	weather_picture.texture=weather_surface.get_texture()
	weather_picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	weather_picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	weather_picture.stretch_mode=TextureRect.STRETCH_SCALE
	weather_picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(weather_picture)
	weather_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(resize_weather_surface)
	resize_weather_surface()

func resize_weather_surface() -> void:
	if weather_surface==null:return
	weather_surface.size=weather_resolution(size,low_quality,OS.get_name()=="Android")
	weather_surface.size_2d_override=Vector2i(maxi(1,roundi(size.x)),maxi(1,roundi(size.y)))
	weather_surface.size_2d_override_stretch=true
	weather_canvas.size=size
	weather_canvas.queue_redraw()

static func weather_resolution(view: Vector2,low: bool,mobile: bool) -> Vector2i:
	var factor:=minf(1,(480.0 if low else 600.0)/maxf(1,view.y)) if mobile else 1.0
	return Vector2i(maxi(1,roundi(view.x*factor)),maxi(1,roundi(view.y*factor)))

func sync_weather_surface() -> void:
	if weather_surface.size!=weather_resolution(size,low_quality,OS.get_name()=="Android"):resize_weather_surface()
	weather_canvas.weather=weather
	weather_canvas.weather_parameters=weather_parameters
	weather_canvas.elapsed=elapsed
	weather_canvas.camera_offset=camera_offset
	weather_canvas.low_quality=low_quality
	weather_canvas.queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if weather_canvas!=null:
		sync_weather_surface()
		return
	queue_redraw()

func _draw() -> void:
	if weather_canvas!=null:
		return
	if not is_instance_valid(cloud_texture):
		return
	var view := size
	if generic_mode:
		draw_texture_rect_region(generic_texture,Rect2(Vector2.ZERO,view),Rect2(0,0,1024,768))
		return
	if not menu_mode:
		var probe_start:=frame_probe.start()
		var painted: bool=renderer.render(self,weather,elapsed,camera_offset,low_quality,weather_parameters)
		frame_probe.end("weather_draw",probe_start)
		if painted:return
	if weather != "sunny" and not menu_mode:
		if weather_key != weather:
			weather_key = weather
			var path := "res://assets/simulator/weather/"+weather+".jpg"
			weather_texture = load(path) if ResourceLoader.exists(path) else null
		if weather_texture != null:
			draw_texture_rect(weather_texture,Rect2(Vector2.ZERO,view),false)
			for i in (12 if low_quality else 40):
				var point:=Vector2(fposmod(i*137.23+elapsed*8,view.x),fposmod(i*71.19+elapsed*(22 if weather=="frozen" else -8),view.y))
				draw_circle(point,1.5+0.5*sin(elapsed+i),Color(0.8,0.94,1,0.45))
			return
	draw_rect(Rect2(Vector2.ZERO,view),Color("59d1e5"))
	for layer in 3:
		var width := view.x * 1.2
		var top := view.y * (layer * 0.25)
		var scroll := fposmod(camera_offset * (0.04 + layer * 0.02),width)
		for repeat in 2:
			draw_texture_rect(hills[layer],Rect2(repeat * width - scroll,top,width,view.y - top),false)
	draw_texture_rect_region(sun_texture,Rect2(view.x * 0.70,view.y * 0.10,view.y * 0.24,view.y * 0.24),Rect2(0,0,164,164))
	for i in (3 if low_quality else 9):
		var factor := 0.55 + (i % 3) * 0.27
		var x := fposmod(i * view.x / 7.0 + elapsed * (3 + i),view.x + 220) - 110
		var y: float = view.y * [0.04,0.19,0.39,0.11,0.52,0.28,0.62,0.05,0.45][i]
		draw_texture_rect_region(cloud_texture,Rect2(x,y,155 * factor,87 * factor),Rect2(0,0,197,111),Color(1,1,1,0.65))
