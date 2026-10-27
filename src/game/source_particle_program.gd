extends RefCounted
static var data: Dictionary={}

static func truthy(value) -> bool:
	if value==null:return false
	if value is Dictionary or value is Array:return true
	if value is String:return not value.is_empty()
	if value is float:return value!=0 and not is_nan(value)
	return bool(value)

static func programs() -> Dictionary:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/source-particle-programs.json"))
	return data.programs

static func evaluate(e,particle: Dictionary,locals: Dictionary,dt: float):
	if not e is Array or e.is_empty():return 0.0
	match str(e[0]):
		"c":return e[1]
		"field":return particle.get(str(e[1]),0.0)
		"local":return locals.get(str(e[1]),0.0)
		"dt":return dt
		"assign":
			var value=evaluate(e[3],particle,locals,dt)
			if e[1]=="field":particle[str(e[2])]=value
			else:locals[str(e[2])]=value
			return value
		"seq":
			var value=0
			for i in range(1,e.size()):value=evaluate(e[i],particle,locals,dt)
			return value
		"array":return e.slice(1).map(func(x):return evaluate(x,particle,locals,dt))
		"object":
			var result: Dictionary={}
			for pair in e.slice(1):result[str(pair[0])]=evaluate(pair[1],particle,locals,dt)
			return result
		"get":
			var target=evaluate(e[1],particle,locals,dt)
			var key=evaluate(e[2],particle,locals,dt)
			if target is Dictionary:return target.get(str(key),0.0)
			if target is Array and int(key)>=0 and int(key)<target.size():return target[int(key)]
			return 0.0
		"invoke":return run(e[1],particle,dt,locals.duplicate()).get("value",0.0)
		"map":
			var result: Array=[]
			var items=evaluate(e[1],particle,locals,dt)
			if items is Array:
				for item in items:
					var scope=locals.duplicate();scope.__mapped_value=item
					result.append(evaluate(e[2],particle,scope,dt))
			return result
		"choose":return evaluate(e[2] if truthy(evaluate(e[1],particle,locals,dt)) else e[3],particle,locals,dt)
		"random_range":return randf_range(float(evaluate(e[1],particle,locals,dt)),float(evaluate(e[2],particle,locals,dt)))
		"unary":
			var a=evaluate(e[2],particle,locals,dt)
			match str(e[1]):
				"!":return not truthy(a)
				"-":return -float(a)
				"~":return ~int(a)
				"void":return 0.0
			return a
		"op":
			var a=evaluate(e[2],particle,locals,dt)
			if e[1]=="&&":return evaluate(e[3],particle,locals,dt) if truthy(a) else a
			if e[1]=="||":return a if truthy(a) else evaluate(e[3],particle,locals,dt)
			var b=evaluate(e[3],particle,locals,dt)
			match str(e[1]):
				"===","==":return a==b
				"!==","!=":return a!=b
				"+":return float(a)+float(b)
				"-":return float(a)-float(b)
				"*":return float(a)*float(b)
				"/":return float(a)/float(b) if absf(float(b))>0.000001 else 0.0
				"%":return fmod(float(a),float(b)) if absf(float(b))>0.000001 else 0.0
				"<":return a<b
				"<=":return a<=b
				">":return a>b
				">=":return a>=b
				"|":return int(a)|int(b)
				"&":return int(a)&int(b)
		"math":
			var args: Array=e.slice(2).map(func(x):return evaluate(x,particle,locals,dt))
			var a:=float(args[0]) if not args.is_empty() else 0.0
			match str(e[1]):
				"random":return randf()
				"floor":return floorf(a)
				"ceil":return ceilf(a)
				"trunc":return float(int(a))
				"round":return floorf(a+0.5)
				"sin":return sin(a)
				"cos":return cos(a)
				"abs":return absf(a)
				"sign":return signf(a)
				"sqrt":return sqrt(maxf(0,a))
				"pow":return pow(a,float(args[1]))
				"atan2":return atan2(a,float(args[1]))
				"min","max":
					for i in range(1,args.size()):a=minf(a,float(args[i])) if e[1]=="min" else maxf(a,float(args[i]))
					return a
	return 0.0

static func run(rows: Array,particle: Dictionary,dt: float,locals: Dictionary={}) -> Dictionary:
	for row in rows:
		match str(row[0]):
			"call":run(row[1],particle,dt,locals.duplicate())
			"set":particle[str(row[1])]=evaluate(row[2],particle,locals,dt)
			"local":locals[str(row[1])]=evaluate(row[2],particle,locals,dt)
			"return":return {"returned":true,"value":evaluate(row[1],particle,locals,dt)}
			"if":
				var result:=run(row[2] if truthy(evaluate(row[1],particle,locals,dt)) else row[3],particle,dt,locals)
				if result.get("returned",false):return result
	return {}
