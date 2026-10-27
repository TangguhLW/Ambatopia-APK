extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
const SWITCH_ACTIONS=[12,31,122,45]
const JAMMERS={226:"signal",1276:"punch",1278:"zombie",4884:"balloon",3616:"balloon"}
static var cached: Dictionary={}
static var weather_recipes: Dictionary={}
static func renderable(weather: String) -> bool:
	if weather_recipes.is_empty():weather_recipes=JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/weather-layers.json")).wx
	return weather_recipes.has(weather) or weather in ["frozen","celebrity","custom_heatwave","custom_stuff","custom_background","guild"]

static func source(id: int) -> int:
	return preload("res://src/game/terrain_renderer.gd").source(id)

static func handles(id: int) -> bool:
	var row: Array=Sim.items().get(str(id),[])
	return Sim.use_rules.weather.has(str(id)) or row.size()>7 and int(row[7]) in SWITCH_ACTIONS

static func flags(w) -> Dictionary:
	var key: int=w.get_instance_id()
	if cached.has(key) and cached[key].ref.get_ref()==w and cached[key].revision==w.visual_revision:return cached[key].data
	var data={"signal":false,"punch":false,"zombie":false,"balloon":false,"antigravity":false,"active":[],"pending":[]}
	for index in w.foreground.size():
		var id:=source(int(w.foreground[index]))
		if not handles(id):continue
		var state: Dictionary=w.extras.get(str(index),{})
		var enabled: bool=bool(state.get("enabled",false))
		if state.has("switch_at"):data.pending.append(index)
		if id==4992:data.antigravity=enabled
		if enabled and JAMMERS.has(id):data[JAMMERS[id]]=true
		if enabled:data.active.append({"index":index,"item":id,"silent":bool(state.get("silent",false))})
	if cached.size()>=8:cached.erase(cached.keys()[0])
	cached[key]={"ref":weakref(w),"revision":w.visual_revision,"data":data}
	return data

static func toggle(r,w,p,tile: Vector2i,command: String,args: Dictionary) -> Dictionary:
	var id: int=r.source(w.tile_at(tile))
	if not handles(id):return {}
	var owner: String=preload("res://src/game/lock_rules.gd").owner_at(w,tile)
	var d: Dictionary=r.state(w,tile)
	if not p.developer and owner not in ["",p.actor_key] and not (command in ["activate","toggle"] and d.get("public",false)):return r.result(false,"Only the owner can configure this machine.")
	if command=="configure":
		var special: Dictionary=configure_weather(r,w,tile,id,args)
		if not special.is_empty():return special
		if args.keys()==["silent"] and args.silent is bool:d.silent=args.silent
		elif args.keys()==["public"] and args.public is bool:d.public=args.public
		elif id in [5958,10058] and args.keys()==["interval"] and (args.interval is int or args.interval is float) and is_finite(float(args.interval)) and float(args.interval)>=1 and float(args.interval)<=(60 if id==5958 else 240):d.interval=float(args.interval)
		elif id==10058 and args.keys()==["random"] and args.random is bool:d.random=args.random
		elif id==5958 and args.keys()==["phases"] and args.phases is Array and args.phases.size()==3 and args.phases.all(func(v):return v is bool):d.phases=args.phases.duplicate()
		elif id==10058 and args.keys()==["slots"] and args.slots is Array and args.slots.size()<=4:
			for slot in args.slots:
				if not (slot is int or slot is float) or not is_finite(float(slot)) or float(slot)!=int(slot) or int(slot)!=0 and not Sim.use_rules.weather.has(str(int(slot))) or int(slot) in [5958,10058]:return r.result(false,"Choose up to four ordinary weather machines.")
				if int(slot)!=0 and not renderable(preload("res://src/game/source_blasts.gd").weather_key(int(Sim.use_rules.weather[str(int(slot))].w))):return r.result(false,"This slot requires a weather renderer not yet recovered.")
			d.slots=args.slots.duplicate()
		else:return r.result(false,"Choose a valid machine setting.")
	elif command in ["activate","toggle"]:
		if id==4884:
			if d.has("switch_at"):return r.result(false,"Balloon Jammer is already counting down.")
			d.pending_enabled=not d.get("enabled",false);d.switch_at=r.now()+5
			w.mark_visual(tile)
			return r.result(true,"",[{"type":"item_state","tile":tile},r.message("Balloon Jammer switching %s in 5 seconds."%("on" if d.pending_enabled else "off"),tile)])
		if Sim.use_rules.weather.has(str(id)):
			var weather: String=cycle_weather(id,d,0) if id in [5958,10058] else preload("res://src/game/source_blasts.gd").weather_key(int(Sim.use_rules.weather[str(id)].w))
			if not renderable(weather):return r.result(false,"This weather's special renderer has not been recovered; existing sky preserved.")
			var on: bool=w.weather!=weather
			if id in [5958,10058]:on=not d.get("enabled",false)
			if weather=="sunny":on=w.weather!="sunny" or not d.get("enabled",false)
			if on and weather=="guild" and preload("res://src/game/guild_weather.gd").mascot(w).is_empty():return r.result(false,"Guild weather requires a Guild Lock with a configured guild mascot. Wrench your Guild Lock first.")
			if on and not w.world_effects.has("base_weather"):w.world_effects.base_weather=w.weather
			for key in w.extras:
				var other_id:=source(int(w.foreground[int(key)]))
				if Sim.use_rules.weather.has(str(other_id)):w.extras[key].enabled=false
			d.enabled=on;d.stage=0;d.next_cycle=r.now()+60*float(d.get("interval",10 if id==5958 else 5))
			w.world_effects.active_weather=r.key(w,tile) if on else ""
			w.weather=weather if on else str(w.world_effects.get("base_weather","sunny"))
		else:d.enabled=not bool(d.get("enabled",false))
	else:return r.result(false,"This machine supports on/off and sound settings.")
	w.mark_visual(tile)
	var events: Array=[{"type":"item_state","tile":tile}]
	if Sim.use_rules.weather.has(str(id)):events.append({"type":"weather_changed","tile":tile,"weather":w.weather})
	events.append(r.message("%s: %s"%[Sim.items()[str(id)][0],"On" if d.get("enabled",false) else "Off"],tile))
	return r.result(true,"",events)

static func integer(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==int(value)

static func configure_weather(r,w,tile: Vector2i,id: int,args: Dictionary) -> Dictionary:
	var recognized:=false
	if id==6280 and args.size()==3 and args.has("gravity") and args.has("spin") and args.has("invert"):
		if not integer(args.gravity) or args.gravity<-500 or args.gravity>500 or not args.spin is bool or not args.invert is bool:return r.result(false,"Choose a gravity from -500 to 500 and valid Spin / Invert switches.")
		recognized=true
	if id==3694 and args.size()==3 and args.has("r") and args.has("g") and args.has("b"):
		for value in args.values():
			if not integer(value) or value<0 or value>255:return r.result(false,"RGB values must be integers from 0 to 255.")
		if maxf(float(args.r),maxf(float(args.g),float(args.b)))<40:return r.result(false,"At least one heatwave color must be 40 or brighter.")
		recognized=true
	elif id==5000 and args.keys()==["bg"]:
		if not integer(args.bg) or not Sim.items().has(str(int(args.bg))) or int(Sim.items()[str(int(args.bg))][7]) not in [18,22,23,28]:return r.result(false,"Select a background block.")
		recognized=true
	elif id==3832 and args.size()==4 and args.has("item") and args.has("gravity") and args.has("spin") and args.has("invert"):
		if not integer(args.item) or not Sim.items().has(str(int(args.item))) or int(args.item)<2:return r.result(false,"Select a valid falling item.")
		if not integer(args.gravity) or args.gravity<-500 or args.gravity>500 or not args.spin is bool or not args.invert is bool:return r.result(false,"Gravity must be from -500 to 500; spin and invert are switches.")
		recognized=true
	if not recognized:return {}
	r.state(w,tile).merge(args,true)
	w.mark_visual(tile)
	return r.result(true,"",[{"type":"item_state","tile":tile},r.message("Weather settings saved.",tile)])

static func removed(w,id: int,tile:=Vector2i(-1,-1)) -> void:
	if Sim.use_rules.weather.has(str(id)) and (str(w.world_effects.get("active_weather",""))==str(tile.y*w.size.x+tile.x) or w.weather==preload("res://src/game/source_blasts.gd").weather_key(int(Sim.use_rules.weather[str(id)].w))):w.world_effects.active_weather="";w.weather=str(w.world_effects.get("base_weather","sunny"))
	cached.erase(w.get_instance_id())

static func cycle_weather(id: int,d: Dictionary,stage: int) -> String:
	var choices: Array=[]
	if id==5958:
		var phases: Array=d.get("phases",[false,false,false])
		for index in 3:
			if phases[index]:choices.append(["iceage","volcano","floating"][index])
	else:
		for slot in d.get("slots",[]):
			if int(slot)==0:continue
			choices.append(preload("res://src/game/source_blasts.gd").weather_key(int(Sim.use_rules.weather[str(int(slot))].w)))
	return "sunny" if choices.is_empty() else str(choices[randi_range(0,choices.size()-1) if id==10058 and d.get("random",false) else stage%choices.size()])

static func tick(r,w) -> Array:
	var events: Array=[]
	if w.weather=="guild" and preload("res://src/game/guild_weather.gd").mascot(w).is_empty():
		var active: String=str(w.world_effects.get("active_weather",""))
		if w.extras.has(active):
			w.extras[active].enabled=false
			if active.is_valid_int() and int(active)>=0 and int(active)<w.foreground.size():
				var tile:=Vector2i(int(active)%w.size.x,floori(float(active)/w.size.x))
				w.mark_visual(tile);events.append({"type":"item_state","tile":tile})
		w.weather=str(w.world_effects.get("base_weather","sunny"));w.world_effects.active_weather=""
		events.append({"type":"weather_changed","tile":Vector2i.ZERO,"weather":w.weather})
	for index in flags(w).pending:
		var pending: Dictionary=w.extras.get(str(index),{})
		if r.now()<float(pending.get("switch_at",INF)):continue
		pending.enabled=bool(pending.get("pending_enabled",false));pending.erase("switch_at");pending.erase("pending_enabled")
		var at:=Vector2i(index%w.size.x,floori(float(index)/w.size.x))
		w.mark_visual(at)
		events.append({"type":"item_state","tile":at})
		events.append(r.message("Balloon Jammer is now %s."%("on" if pending.enabled else "off"),at))
	var key: String=str(w.world_effects.get("active_weather",""))
	if not key.is_valid_int() or int(key)<0 or int(key)>=w.foreground.size() or not w.extras.has(key):return events
	var id:=source(int(w.foreground[int(key)]))
	if id not in [5958,10058]:return events
	var d: Dictionary=w.extras[key]
	if not d.get("enabled",false) or r.now()<float(d.get("next_cycle",INF)):return events
	d.stage=int(d.get("stage",0))+1
	d.next_cycle=r.now()+60*float(d.get("interval",10 if id==5958 else 5))
	var weather:=cycle_weather(id,d,int(d.stage))
	if not renderable(weather):return events
	if weather=="guild" and preload("res://src/game/guild_weather.gd").mascot(w).is_empty():return events
	w.weather=weather
	var tile:=Vector2i(int(key)%w.size.x,floori(float(key)/w.size.x))
	w.mark_visual(tile)
	events.append_array([{"type":"weather_changed","tile":tile,"weather":weather},{"type":"item_state","tile":tile}])
	return events
