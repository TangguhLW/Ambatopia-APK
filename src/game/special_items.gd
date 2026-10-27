extends RefCounted

const FOSSIL_ROCKS = [3918,3920,3922,3924,3926,3928]

func silk_status(d: Dictionary, clock: float) -> Dictionary:
	var age=maxf(0,clock-float(d.born))
	var sick=maxf(maxf(0,age-float(d.fu)),maxf(0,age-float(d.wu)))
	if int(d.wf)&1:
		sick=maxf(sick,maxf(1,age-float(d.ill)))
	var dead=bool(int(d.wf)&8) or sick>86400 or age>=1728001
	var progress=0.0 if dead or sick>0 else minf(86400,maxf(0,age-maxf(86400,float(d.hv))))
	return {"age":age,"sick":sick,"dead":dead,"progress":progress}

func initialize(r, w, tile: Vector2i, id: int) -> void:
	if id==3078:
		var solar=r.state(w,tile)
		if not solar.has("charged_from"):
			solar.merge({"charged_from":r.now(),"planting":true,"splicing":true})
	if id in [4344,8020]:
		var d=r.state(w,tile)
		if not d.has("period"):
			d.merge({"period":10.0,"speed":100.0,"enabled":false,"left":false,"next":r.now()+10})
	if id==3316:
		var d=r.state(w,tile)
		if not d.has("born"):
			d.merge({"born":r.now(),"r":randi_range(0,255),"g":randi_range(0,255),"b":randi_range(0,255),"wf":0,"fu":21600,"wu":21600,"hv":0,"ill":0,"feeds":0})

func palette(r, d: Dictionary) -> Array:
	var best: Array=[]
	var distance=INF
	for row in r.rest.data.B_silk.pal:
		var delta=Vector3(d.r,d.g,d.b).distance_squared_to(Vector3(row[1],row[2],row[3]))
		if delta<distance:
			distance=delta
			best=row
	return best

func done(r, tile: Vector2i, text: String, events: Array=[]) -> Dictionary:
	events.append(r.message(text,tile))
	events.append({"type":"item_state","tile":tile})
	return r.result(true,"",events)

func use(r, w, p, tile: Vector2i, item: int) -> Dictionary:
	var id=r.source(w.tile_at(tile))
	if item==4132 or item==6140:
		var found=false
		for drop in w.drops.duplicate():
			if Vector2(float(drop.x),float(drop.y)).distance_to(Vector2(tile)*32+Vector2(16,16))>24:
				continue
			if item==4132 and int(drop.id)==3936:
				drop.id=4134
				found=true
			elif item==6140 and int(drop.id)!=112:
				var k=str(int(drop.id))
				if p.collected.size()>=1024 and not p.collected.has(k):
					continue
				p.collected[k]=mini(999999,int(p.collected.get(k,0))+int(drop.amount))
				w.drops.erase(drop)
				found=true
		return done(r,tile,"Fossil polished." if item==4132 else "Floating items collected.") if found else r.result(false,"Use on a floating Fossil." if item==4132 else "No floating items here.")
	if id!=3316:
		return {}
	initialize(r,w,tile,id)
	var d=r.state(w,tile)
	var s=silk_status(d,r.now())
	if item==3896:
		if not s.dead:
			return r.result(false,"This Silkworm is still alive.")
		d.wf=0
		if s.age>=1724401:
			d.born=r.now()-172800
			d.hv=172800
			s.age=172800
		d.fu=s.age+21600;d.wu=s.age+21600;d.ill=0
		return done(r,tile,"The Silkworm lives again!")
	if s.dead:
		return r.result(false,"This Silkworm has died. It needs a Soul.")
	if item==822:
		if float(d.wu)-s.age>259200:
			return r.result(false,"This Silkworm cannot drink any more.")
		d.wu=maxf(d.wu,s.age)+86400
	elif item==782:
		d.wf=int(d.wf)&~1;d.ill=0
	elif item==3410:
		if s.sick>0:
			return r.result(false,"A sick Silkworm cannot play.")
		d.play_until=r.now()+8
	elif item in [3630,3628]:
		var color=palette(r,d)
		var output=int(color[6 if item==3630 else 7])
		w.set_tile(tile,0);w.extras.erase(r.key(w,tile))
		return done(r,tile,"Silkworm ready to accompany you.",[r.reward(w,tile,output),{"type":"tile_removed","tile":tile}])
	elif item==126:
		d.wf=int(d.wf)^4
	elif r.rest.data.B_silk.food.has(str(item)):
		if float(d.fu)-s.age>259200:
			return r.result(false,"This Silkworm is too full.")
		d.fu=maxf(d.fu,s.age)+86400;d.feeds=int(d.feeds)+1
		if item in [614,540]:
			d.wf=int(d.wf)|1;d.ill=s.age
		if item in [1662,1488]:
			d.wf=int(d.wf)|2
		if item==1964:
			d.wf=(int(d.wf)&~16)|4
		if item==128:
			d.wf=(int(d.wf)&~4)|16
		var index=int(r.rest.data.B_silk.food[str(item)])
		for i in 3:
			var field=["r","g","b"][i]
			d[field]=clampi(floori(float(d[field])+0.2*(144-float(d[field]))+0.5) if index==2 else int(d[field])+int(r.rest.data.B_silk.step[index][i]),0,255)
	else:
		return r.result(false,"This is not Silkworm food or care equipment.")
	return done(r,tile,"%s Silkworm: food and water updated." % palette(r,d)[0])

func interact(r,w,p,tile: Vector2i,command: String,args: Dictionary) -> Dictionary:
	var id=r.source(w.tile_at(tile))
	var d=r.state(w,tile)
	if id==3078:
		initialize(r,w,tile,id)
		if command!="configure":
			return r.result(false,"Solar Collector charges for 24 hours, then speeds one matching planting or splice by 25%.")
		for field in args:
			if field not in ["planting","splicing"] or not args[field] is bool:
				return r.result(false,"Invalid Solar Collector setting.")
		for field in args:
			d[field]=args[field]
		return done(r,tile,"Solar Collector updated.")
	if id in [4344,8020]:
		initialize(r,w,tile,id)
		if command=="configure":
			for field in args:
				if field not in ["period","speed","enabled","left"]:
					return r.result(false,"Unknown blaster setting.")
				if field in ["enabled","left"]:
					if not args[field] is bool:
						return r.result(false,"Invalid blaster switch.")
				elif not args[field] is int and not args[field] is float or not is_finite(float(args[field])):
					return r.result(false,"Invalid blaster number.")
			for field in args:
				d[field]=clampf(float(args[field]),2,20) if field=="period" else clampf(float(args[field]),10,250) if field=="speed" else args[field]
			d.next=r.now()+float(d.period)
			return done(r,tile,"Blaster settings updated.")
		if command=="activate":
			d.enabled=not d.enabled;d.next=r.now()+float(d.period)
			return done(r,tile,"Blaster enabled." if d.enabled else "Blaster disabled.")
		return r.result(false,"Configure rate, projectile speed and direction for this Blaster.")
	if id==3316:
		initialize(r,w,tile,id)
		if command=="care":
			var item=args.get("item",0)
			if not item is int and not item is float or not is_finite(float(item)) or float(item)!=int(item):
				return r.result(false,"Invalid care item.")
			return use(r,w,p,tile,int(item))
		if command=="harvest":
			var s=silk_status(d,r.now())
			if s.dead or s.sick>0 or s.progress<86400:
				return r.result(false,"Silkworm must be healthy and ready: first harvest after 48 hours, then every 24 hours.")
			var count=10 if int(d.wf)&2 else randi_range(1,10)
			d.hv=s.age;d.wf=int(d.wf)&~2
			return done(r,tile,"Silkworm harvested.",[r.reward(w,tile,int(palette(r,d)[4]),count)])
		if command not in ["configure"]:
			return r.result(false,"Use food, water, medicine, toys, saddle or leash to care for this Silkworm.")
	if id==3354 and command in ["sew","activate"]:
		var stock: Dictionary=d.get("stock",{})
		var bolts: Array=[]
		for row in r.rest.data.B_silk.pal:
			var k=str(int(row[5]))
			for i in mini(3-bolts.size(),maxi(0,int(stock.get(k,0)))):
				bolts.append(int(k))
		if bolts.size()!=3:
			return r.result(false,"Insert three Silk Bolts before sewing.")
		var output=3358
		if bolts[0]==bolts[1] and bolts[1]==bolts[2]:
			output=7030 if bolts[0] in [3336,3348] else 7028 if bolts[0] in [3340,3352,3350] else 7026
		for bolt in bolts:
			stock[str(bolt)]-=1
		return done(r,tile,"Oops! Patchwork Mess." if output==3358 else "Nice stitching!",[r.reward(w,tile,output)])
	if id==2208 and command=="take_all":
		var events: Array=[]
		for item in d.get("outfit",{}).values():
			var original=int(item)-200000 if int(item)>=200000 else int(item)
			events.append(r.reward(w,tile,original))
		d.outfit={}
		return done(r,tile,"Phone Booth emptied.",events)
	if id==2208 and command=="activate":
		if Vector2i(floori(p.position.x/32),floori((p.position.y-1)/32))!=tile:
			return r.result(false,"Stand inside the Phone Booth to exchange your outfit.")
		var outfit: Dictionary=d.get("outfit",{}).duplicate()
		d.outfit=p.catalog_equipment.duplicate()
		p.catalog_equipment=outfit
		return done(r,tile,"Outfits swapped.")
	return {}

func punch(r,w,p,tile: Vector2i) -> Dictionary:
	var id=r.source(w.tile_at(tile))
	var d=r.state(w,tile)
	if id==2208:
		if Vector2i(floori(p.position.x/32),floori((p.position.y-1)/32))==tile:
			return interact(r,w,p,tile,"activate",{})
		if not d.get("outfit",{}).is_empty():
			return r.result(false,"Empty the Phone Booth before breaking it!")
	if id not in FOSSIL_ROCKS:
		return {}
	var hand=int(p.catalog_equipment.get("hand",0))
	if hand>=200000:
		hand-=200000
	if hand==3932:
		d.hits=int(d.get("hits",randi_range(4,6)))-1
		if d.hits<0:
			w.set_tile(tile,200000+int(r.rest.data.A_fossil.rock[str(id)]))
			w.extras.erase(r.key(w,tile))
			return done(r,tile,"I smashed a Fossil!",[{"type":"tile_placed","tile":tile}])
		if d.hits==0:
			d.unearthed=true
		return done(r,tile,"I unearthed a Fossil! Use a Rock Chisel." if d.hits==0 else "Carefully uncovering the fossil...",[{"type":"tile_damaged","tile":tile}])
	if hand==3934 and d.get("unearthed",false):
		w.set_tile(tile,0);w.extras.erase(r.key(w,tile))
		return done(r,tile,"Fossil extracted.",[r.reward(w,tile,3936),{"type":"tile_removed","tile":tile}])
	return r.result(false,"Use a Rock Hammer, then a Rock Chisel once the fossil is unearthed.")

func describe(r,w,tile: Vector2i) -> String:
	var id=r.source(w.tile_at(tile))
	if id==3316:
		initialize(r,w,tile,id)
		var d=r.state(w,tile)
		var s=silk_status(d,r.now())
		return "\n%s Silkworm · %s\nFood: %dh · Water: %dh\nSilk progress: %d%%" % [palette(r,d)[0],"Dead" if s.dead else "Sick" if s.sick>0 else "Healthy",maxi(0,int((float(d.fu)-s.age)/3600)),maxi(0,int((float(d.wu)-s.age)/3600)),roundi(s.progress/864)]
	if id==3078:
		initialize(r,w,tile,id)
		var d=r.state(w,tile)
		return "\nCharge: %d%% (24 hours)\nA full charge speeds one planting or splice by 25%%." % clampi(int((r.now()-float(d.charged_from))/864),0,100)
	if id in [4344,8020]:
		return "\nProjectiles: 10 maximum per world. Configure interval, speed and direction."
	if id==3354:
		return "\nInsert exactly three Silk Bolts. Matching colors make clothing; mixed colors make Patchwork Mess."
	if id in FOSSIL_ROCKS:
		return "\nRock Hammer to uncover; Rock Chisel to extract. One hammer strike too many destroys the fossil."
	if id==2208:
		return "\nStand inside and punch to swap outfits. Empty it before breaking."
	return ""

func tick(r,w,players: Array,dt: float,clock: float=-1) -> bool:
	if clock<0:
		clock=r.now()
	var projectiles: Array=w.world_effects.get("projectiles",[])
	var changed=not projectiles.is_empty()
	for k in w.extras:
		var index=int(k)
		var tile=Vector2i(index%w.size.x,index/w.size.x)
		var id=r.source(w.tile_at(tile))
		if id not in [4344,8020]:
			continue
		var d: Dictionary=w.extras[k]
		if not d.get("enabled",false):
			continue
		if clock>=float(d.get("next",clock+10)):
			d.next=clock+clampf(float(d.get("period",10)),2,20)
			if projectiles.size()<10:
				projectiles.append({"source":index,"id":id,"x":tile.x*32+16.0,"y":tile.y*32+(6.0 if id==8020 else 16.0),"vx":(-1 if d.get("left",false) else 1)*clampf(float(d.get("speed",100)),10,250)})
				changed=true
	for shot in projectiles.duplicate():
		var source_tile=Vector2i(int(shot.source)%w.size.x,int(shot.source)/w.size.x)
		var dead=r.source(w.tile_at(source_tile)) not in [4344,8020]
		var travel=float(shot.vx)*dt
		var count=maxi(1,ceili(absf(travel)/4))
		for i in count:
			shot.x+=travel/count
			var tile=Vector2i(floori(float(shot.x)/32),floori(float(shot.y)/32))
			if not w.contains(tile) or tile!=source_tile and w.solid(tile):
				dead=true
				break
			for player in players:
				if not player.god_mode and Rect2(player.position-Vector2(10,30),Vector2(20,30)).has_point(Vector2(shot.x,shot.y)):
					player.position=w.spawn_position()
					player.velocity=Vector2.ZERO
					player.air_jumps=0
					dead=true
			if dead:
				break
		if dead:
			projectiles.erase(shot)
	w.world_effects.projectiles=projectiles
	return changed

func solar_growth(r,w,seed_tile: Vector2i,spliced: bool) -> Array:
	var field="splicing" if spliced else "planting"
	for k in w.extras:
		var index=int(k)
		var tile=Vector2i(index%w.size.x,index/w.size.x)
		if r.source(w.tile_at(tile))!=3078:
			continue
		initialize(r,w,tile,3078)
		var d: Dictionary=w.extras[k]
		if d.get(field,true) and r.now()-float(d.charged_from)>=86400:
			d.charged_from=r.now()
			var seed=r.state(w,seed_tile)
			seed.planted-=float(seed.duration)/4
			return [{"type":"item_state","tile":tile}]
	return []
