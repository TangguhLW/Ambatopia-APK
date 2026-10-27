extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
const Icons=preload("res://src/game/inventory_icons.gd")
var manifest: Dictionary={}
var textures: Dictionary={}
func texture(key: String) -> Texture2D:
	if manifest.is_empty():manifest=JSON.parse_string(FileAccess.get_file_as_string("res://data/native-weather-029.json")).entries
	if not manifest.has(key):return null
	if not textures.has(key):textures[key]=load("res://"+str(manifest[key].output))
	return textures[key]
func layer(c,key: String,bottom: float,height: float,view: Vector2) -> void:
	var image:=texture(key)
	if image==null:return
	var row: Dictionary=manifest[key]
	var factor:=height/float(row.height)
	var width:=float(row.width)*factor
	for i in range(-1,ceili(view.x/width)+1):
		c.draw_texture_rect_region(image,Rect2(i*width,bottom-height,width+1,height),Rect2(0,0,float(row.width),float(row.height)))
func render(c,key: String,time: float,params: Dictionary,low: bool) -> bool:
	var view: Vector2=c.size
	match key:
		"guild":
			var color:=Color(254.0/255,254.0/255,100.0/255)
			if params.get("invert",false):color=Color(1-color.r,1-color.g,1-color.b)
			c.draw_rect(Rect2(Vector2.ZERO,view),color)
		"frozen":
			c.draw_texture_rect(texture("mtn_sky"),Rect2(Vector2.ZERO,view),false)
			layer(c,"mtn_3",view.y,view.y*0.9,view)
			layer(c,"mtn_2",view.y,view.y*0.77,view)
			layer(c,"mtn_1",view.y,view.y*0.45,view)
		"celebrity":
			c.draw_rect(Rect2(Vector2.ZERO,view),Color("58d8ec"))
			layer(c,"hills3_growtopia",view.y,view.y*0.85,view)
			layer(c,"hills2_growtopia",view.y,view.y*0.8,view)
			layer(c,"hills1_growtopia",view.y,view.y*0.3,view)
		"custom_background":
			var image: Texture2D=Sim.sprite(int(params.get("bg",14)))
			c.draw_rect(Rect2(Vector2.ZERO,view),Color.BLACK)
			if image==null:return true
			for y in ceili(view.y/64):
				for x in ceili(view.x/64):c.draw_texture_rect(image,Rect2(x*64,y*64,64,64),false)
		"custom_heatwave":
			var color:=Color(float(params.get("r",255))/255,float(params.get("g",128))/255,float(params.get("b",0))/255)
			c.draw_rect(Rect2(Vector2.ZERO,view),color.darkened(0.75))
			var image:=texture("haze")
			for index in (4 if low else 8):
				var width:=view.x*2
				var x: float=-view.x*0.5+sin(time*0.05+index)*view.x*0.25
				var y:=view.y*float(index)/8
				c.draw_texture_rect(image,Rect2(x,y,width,view.y*0.22),false,Color(color,0.5))
		"custom_stuff":
			c.draw_rect(Rect2(Vector2.ZERO,view),Color("101d35"))
			var image: Texture2D=Icons.texture(int(params.get("item",2)))
			if image==null:return true
			var gravity: float=float(params.get("gravity",50))
			for index in (24 if low else 60):
				var point:=Vector2(fposmod(index*137.13,view.x+32)-16,fposmod(index*71.19+time*gravity,view.y+48)-24)
				var scale_y: float=-1 if params.get("invert",false) else 1
				c.draw_set_transform(point,time*(1 if index%2==0 else -1) if params.get("spin",false) else 0,Vector2(1,scale_y))
				c.draw_texture_rect(image,Rect2(-12,-12,24,24),false)
			c.draw_set_transform(Vector2.ZERO)
		_:return false
	return true
