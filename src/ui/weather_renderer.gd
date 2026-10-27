extends RefCounted
var data: Dictionary = {}
var assets: Dictionary = {}
var textures: Dictionary = {}
var complex_scene = preload("res://src/ui/weather_scene.gd").new()
var active_weather := ""
var recovered=preload("res://src/ui/recovered_weather.gd").new()
func viewport_extent(canvas: Control) -> Vector2:
	return canvas.size
func expression(value: Variant, view: Vector2, scale: float = 0) -> float:
	if value is Dictionary:
		return float(value.get("W",0))*view.x+float(value.get("H",0))*view.y+float(value.get("s",0))*scale+float(value.get("px",0))
	return float(value) if value is float or value is int else 0.0
func texture(key: String) -> Texture2D:
	if not assets.has(key):
		return null
	if not textures.has(key):
		if textures.size()>96:
			textures.erase(textures.keys()[0])
		textures[key] = load("res://assets/simulator/wxg/"+assets[key])
	return textures[key]
func render(canvas: Control, key: String, time: float, camera: float, low: bool,params: Dictionary={}) -> bool:
	if recovered.render(canvas,key,time,params,low):return true
	if data.is_empty():
		data = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/weather-layers.json"))
		assets = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/weather-assets.json"))
	if not data.wx.has(key):
		return false
	var row: Dictionary = data.wx[key]
	var view := viewport_extent(canvas)
	if active_weather!=key:
		textures.clear()
		active_weather=key
	if row.has("ro2"):
		complex_scene.prepare(key,row.ro2,view,texture)
		complex_scene.draw(canvas,time,camera,low)
		return true
	for sky in row.sky:
		if sky.has("c"):
			canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color(float(sky.c[0])/255,float(sky.c[1])/255,float(sky.c[2])/255))
		elif sky.has("t"):
			var image := texture(sky.t)
			if image != null and sky.s is Array:
				canvas.draw_texture_rect(image,Rect2(Vector2(expression(sky.x,view),expression(sky.y,view)),image.get_size()*Vector2(expression(sky.s[0],view),expression(sky.s[1],view))),false)
	if row.has("stars"):
		var stars: Dictionary = row.stars if row.stars is Dictionary else {}
		for i in (30 if low else mini(200,int(stars.get("n",200)))):
			var point := Vector2(fposmod(i*73.13+time*float(stars.get("vx",0)),view.x),fposmod(i*91.79,view.y))
			canvas.draw_circle(point,1.0+fposmod(i*0.73,1.5),Color(1,1,1,0.5+0.3*sin(time+i)))
	for layer in row.L:
		if layer.has("ref"):
			if layer.ref == "clouds" and row.has("clouds"):
				var image := texture(row.clouds.t)
				if image != null:
					for i in (3 if low else 9):
						var point := Vector2(fposmod(i*137+time*(3+i)-camera*0.03,view.x+180)-180,view.y*fposmod(i*0.271,0.8))
						canvas.draw_texture_rect(image,Rect2(point,Vector2(120,68)),false,Color(1,1,1,0.5))
			continue
		if not layer.has("t"):
			continue
		var image := texture(layer.t)
		if image == null:
			continue
		var source := Rect2(Vector2.ZERO,image.get_size())
		if layer.has("src"):
			source = Rect2(layer.src[0],layer.src[1],layer.src[2],layer.src[3])
		var scale := expression(layer.get("s",1),view)
		var portrait_fit:=false
		if layer.has("tile") and layer.get("a",0) and source.size.y > 0:
			var minimum_height:=view.y*0.9/source.size.y
			portrait_fit=scale<minimum_height and view.y>view.x
			if portrait_fit:scale=minimum_height
		var dimensions := source.size*scale
		var point := Vector2(expression(layer.get("x",0),view,scale),expression(layer.get("y",0),view,scale))
		point.x += expression(layer.get("scroll",0),view,scale)*time-camera*expression(layer.get("p",0),view,scale)*0.1
		if layer.get("a",0):
			point.y -= dimensions.y
		var tint := Color(1,1,1,expression(layer.get("al",1),view,scale))
		if layer.has("tile"):
			var stride := maxf(8,expression(layer.tile,view,scale) if layer.tile is Dictionary else dimensions.x)
			stride = minf(stride,maxf(8,dimensions.x))
			if portrait_fit:stride=dimensions.x
			point.x = fposmod(point.x,stride)-stride*ceilf(dimensions.x/stride)
			var count := 0
			while point.x < view.x and count < 128:
				canvas.draw_texture_rect_region(image,Rect2(point,dimensions+Vector2(1,0)),source,tint)
				point.x += stride
				count += 1
		else:
			canvas.draw_texture_rect_region(image,Rect2(point,dimensions),source,tint)
	if not low and (row.has("snow") or row.has("rain")):
		for i in 70:
			var point := Vector2(fposmod(i*73.7-time*14,view.x),fposmod(i*41.9+time*(120 if row.has("rain") else 30),view.y))
			if row.has("rain"):
				canvas.draw_line(point,point+Vector2(-3,12),Color(0.7,0.9,1,0.5),1)
			else:
				canvas.draw_circle(point,2,Color(1,1,1,0.7))
	return true
