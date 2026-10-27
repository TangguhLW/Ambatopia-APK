extends RefCounted
var cached_key := ""
var cached_size := Vector2.ZERO
var models: Array = []
var fill := Color("59d1e5")
func value(expression: Variant, context: Dictionary, depth: int = 0) -> float:
	if depth>24:
		return 0
	if expression is bool:
		return 1 if expression else 0
	if expression is int or expression is float:
		return float(expression) if is_finite(float(expression)) else 0
	if expression is String:
		return float(context.get(expression,0))
	if not expression is Array or expression.is_empty():
		return 0
	var op: String = str(expression[0])
	var a := value(expression[1],context,depth+1) if expression.size()>1 else 0.0
	var b := value(expression[2],context,depth+1) if expression.size()>2 else 0.0
	match op:
		"+": return a+b
		"-": return a-b
		"*": return a*b
		"/": return a/b if absf(b)>0.00001 else 0.0
		"neg": return -a
		"==": return 1 if a==b else 0
		"!=": return 1 if a!=b else 0
		">=": return 1 if a>=b else 0
		"?": return b if a!=0 else value(expression[3],context,depth+1) if expression.size()>3 else 0
		"call":
			var name:=str(expression[1])
			var x:=value(expression[2],context,depth+1) if expression.size()>2 else 0.0
			var y:=value(expression[3],context,depth+1) if expression.size()>3 else 1.0
			match name:
				"rnd","rndi","rand":
					var random:=fposmod(sin(float(context.get("i",1))*78.233+expression.hash()*0.001)*43758.5453,1)
					return floorf(lerpf(x,y,random)) if name=="rndi" else lerpf(x,y,random)
				"Math.sin": return sin(x)
				"Math.cos": return cos(x)
				"Math.trunc": return float(int(x))
				"Math.max": return maxf(x,y)
	return 0
func prepare(key: String, recipe: Dictionary, view: Vector2, resolver: Callable) -> void:
	if cached_key==key and cached_size==view:
		return
	cached_key=key
	cached_size=view
	models.clear()
	var color: Array = recipe.get("fill",[80,190,220])
	fill=Color(float(color[0])/255,float(color[1])/255,float(color[2])/255)
	for group in ["back","mid","front"]:
		var rows: Array = recipe.get(group,[]).duplicate()
		rows.append_array(recipe.get("own",{}).get(group,[]) if recipe.get("own",{}).get(group,[]) is Array else [])
		for row in rows:
			if not row is Dictionary or not row.has("t") or not row.has("f"):
				continue
			var image: Texture2D=resolver.call(str(row.t))
			if image==null:
				continue
			for index in mini(40,int(row.get("n",1))):
				if models.size()>=160:
					break
				var context:={"W":view.x,"H":view.y,"pw":image.get_width(),"ph":image.get_height(),"i":index,"j":index,"s":1.0,"ux":view.x/1024.0,"uy":view.y/768.0,"worldWpx":3200,"mapW":100,"bg30":view.y,"E.x":view.x,"E.y":view.y}
				for binding in row.get("let",[]):
					if binding is Array and binding.size()>1:
						context[str(binding[0])]=value(binding[1],context)
				var frame: Dictionary=row.f
				var steps: Array=frame.get("S",[{}])
				var scale_values: Array=steps[0].get("scale",[1,1]) if not steps.is_empty() else [1,1]
				var scale:=Vector2(value(scale_values[0],context),value(scale_values[1],context))
				if scale.x==0 or scale.y==0:
					scale=Vector2.ONE*maxf(0.1,view.x/1024)
				var frame_counts: Array=frame.get("frames",[1,1])
				var columns:=maxi(1,int(value(frame_counts[0],context)))
				var rows_count:=maxi(1,int(value(frame_counts[1],context)))
				var source:=Vector2(image.get_width()/float(columns),image.get_height()/float(rows_count))
				var origin:=Vector2(value(frame.get("x",0),context),value(frame.get("y",0),context))
				var velocity: Array=frame.get("vel",[0,0])
				models.append({"image":image,"source":source,"columns":columns,"frames":columns*rows_count,"position":origin,"scale":scale,"velocity":Vector2(value(velocity[0],context),value(velocity[1],context))*60,"frame":frame,"context":context,"row":row,"z":value(frame.get("z",0),context),"phase":index*1.618,"parallax":value(frame.get("pf",1),context)*0.01 if frame.get("parX",0) else 0.0,"wrap_x":bool(frame.get("wrapX",0)),"wrap_y":bool(frame.get("wrapY",0)),"align":int(value(frame.get("align",0),context)),"bob":frame.has("bob_phase") or frame.has("bobabs"),"sin_amp":value(frame.sin[0],context) if frame.get("sin") is Array and frame.sin.size()>1 else 0.0,"sin_period":maxf(0.1,value(frame.sin[1],context)/1000) if frame.get("sin") is Array and frame.sin.size()>1 else 1.0,"steps_visible":steps.map(func(step):return value(step.get("visible",1),context)!=0)})
		models.sort_custom(func(a,b):return a.z>b.z)
func draw(canvas: Control,time: float,camera: float,low: bool) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),fill)
	var view:=cached_size
	var limit:=40 if low else 160
	for index in mini(limit,models.size()):
		var model: Dictionary=models[index]
		var source: Vector2=model.source
		var scale: Vector2=model.scale
		var point: Vector2=model.position+model.velocity*time
		if model.parallax!=0:
			point.x-=camera*model.parallax
		if model.wrap_x:
			point.x=fposmod(point.x+source.x*scale.x,view.x+source.x*scale.x)-source.x*scale.x
		if model.wrap_y:
			point.y=fposmod(point.y+source.y*scale.y,view.y+source.y*scale.y)-source.y*scale.y
		if model.sin_amp!=0:
			point.x+=model.sin_amp*sin(time*TAU/model.sin_period)
		if model.bob:
			point.y+=sin(time*2+model.phase)*5
		if point.y>=view.y*0.8:
			point.y-=source.y*scale.y
		elif int(model.align) in [2,4,5]:
			point-=source*scale*0.5
		var frame_index:=int(time*8+model.phase)%int(model.frames)
		var region:=Rect2(Vector2(frame_index%int(model.columns),frame_index/int(model.columns))*source,source)
		var visible_steps: Array=model.steps_visible
		if not visible_steps.is_empty() and not visible_steps[int(time*2)%visible_steps.size()]:
			continue
		var dimensions:=source*scale
		if dimensions.x<0.1 or dimensions.y<0.1 or dimensions.x>view.x*8 or dimensions.y>view.y*8:
			continue
		canvas.draw_texture_rect_region(model.image,Rect2(point,dimensions),region)
