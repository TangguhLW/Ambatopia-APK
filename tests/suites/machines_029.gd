extends RefCounted
const W=preload("res://src/game/world_state.gd")
const P=preload("res://src/game/player_state.gd")
const R=preload("res://src/game/item_runtime.gd")
func run(t) -> void:
	var r=R.new();var w=W.new();w.create_default("EXPANDED")
	var p=P.new();p.actor_key="owner";p.position=Vector2(48*32+16,24*32)
	var tile:=Vector2i(49,23)
	for id in [16104,16238]:
		w.set_tile(tile,200000+id);w.extras.clear();w.drops.clear()
		r.planted(w,tile,id);r.interact(w,p,tile,"grow",{})
		var result: Dictionary=r.interact(w,p,tile,"harvest",{})
		t.check(result.accepted and w.drops.size()==1,"Recovered recent provider produces documented item: "+str(id))
		if not w.drops.is_empty():t.check(int(w.drops[0].id)==(1772 if id==16104 else 6316) and int(w.drops[0].amount) in [1,2],"Provider preserves documented quantity and identity")
		t.check(not r.interact(w,p,tile,"harvest",{}).accepted,"Recent provider cannot bypass 22-hour cooldown")
	if not ResourceLoader.exists("res://src/game/recovered_machines.gd"):
		t.check(false,"Item-specific calendar and Well of Love implementation must exist")
		return
	var recovered=r.recovered
	for id in recovered.data.calendars:
		w.create_default("CALENDAR");w.locks=[{"x":52,"y":23,"item":5,"area":0,"owner":"owner","tiles":[]}]
		w.set_tile(tile,200000+int(id));r.planted(w,tile,int(id))
		var table: Dictionary=recovered.data.calendars[id]
		recovered.clock_override=Time.get_unix_time_from_datetime_string(table.unlock_start_utc)+86400
		t.check(recovered.calendar_available(int(id))==2,"Calendar accrues gifts at daily UTC-5 boundary: "+id)
		for day in range(1,26):
			var pool: Array=recovered.calendar_pool(int(id),day)
			t.check(not pool.is_empty(),"Recovered calendar has day-specific candidates: %s/%d"%[id,day])
			if pool.is_empty():continue
			if day==3:t.check(not r.interact(w,p,tile,"harvest",{"choice":0}).accepted,"Unreleased calendar gifts cannot be claimed")
			if day==3:r.interact(w,p,tile,"grow",{})
			w.drops.clear()
			var claimed: Dictionary=r.interact(w,p,tile,"harvest",{"choice":0})
			t.check(claimed.accepted and w.drops.size()==1 and int(w.drops[0].id)==int(pool[0].id),"Calendar replays only a documented reward: %s/%d"%[id,day])
		t.check(r.source(w.tile_at(tile))==int(table.used_item),"Claim 25 transforms to correct used calendar: "+id)
		t.check(not r.interact(w,p,tile,"harvest",{"choice":0}).accepted,"Used calendar cannot issue a 26th reward")
	recovered.clock_override=-1
	w.create_default("WELL");w.locks=[{"x":52,"y":23,"item":5,"area":0,"owner":"owner","tiles":[]}]
	w.set_tile(tile,210656);r.planted(w,tile,10656)
	for i in 40:
		w.drops.clear()
		var filled: Dictionary=r.interact(w,p,tile,"contribute",{"choice":0})
		t.check(filled.accepted,"Well accepts a five-chest creative replay contribution: "+str(i))
	t.check(r.state(w,tile).get("chests",0)==200,"Well tracks exactly 200 contributed chests")
	t.check(not r.interact(w,p,tile,"contribute",{"choice":0}).accepted,"Full well rejects overfilling")
	w.drops.clear();recovered.final_roll=0
	t.check(r.interact(w,p,tile,"harvest",{"choice":0}).accepted and w.drops.any(func(d):return int(d.id)==10660),"Full well creates Pure Love Essence on documented common branch")
	t.check(r.source(w.tile_at(tile))==10658,"Harvest turns Well of Love into Dry Well of Love")
	var rules=preload("res://src/game/source_machine_rules.gd")
	for id in [3694,3832,5000,7644,10286]:
		w.create_default("WEATHER");w.set_tile(tile,200000+id)
		t.check(r.interact(w,p,tile,"activate",{}).accepted,"Dedicated weather renderer can activate: "+str(id))
	var blasts=preload("res://src/game/source_blasts.gd")
	for id in [1060,1402]:
		w.create_default("NEWBLAST");p.developer=true
		t.check(blasts.apply(r,w,p,tile,id).accepted,"Documented additional blast can generate its specific world: "+str(id))
		if id==1402:t.check(w.foreground.count(0)>5700 and w.main_door.x in [0,99],"Thermonuclear blast clears world and moves door to edge")
		else:t.check(w.extras.values().filter(func(d):return d.has("seed")).size()==99 and w.weather=="harvest","Harvest Moon creates 99 mature trees and harvest weather")

	w.create_default("JAMMERS");p.developer=false;p.position=Vector2(48*32+16,24*32)
	w.set_tile(tile,204884);w.extras.clear()
	r.interact(w,p,tile,"activate",{})
	t.check(not rules.flags(w).balloon and r.state(w,tile).has("switch_at"),"Balloon Jammer waits five seconds before enabling")
	r.state(w,tile).switch_at=0;rules.tick(r,w)
	t.check(rules.flags(w).balloon,"Balloon Jammer activates when countdown expires")
	t.check(not r.use_item(w,p,tile,4844).accepted,"Active Balloon Jammer rejects War Balloon throws")
	var victim=P.new();p.modifiers["Infected!"]={"remaining":60,"kind":"player_mod","tint":""}
	w.set_tile(tile,201278);w.extras.clear();r.interact(w,p,tile,"activate",{})
	t.check(not r.recovered.infect(w,p,victim),"Zombie Jammer blocks player-to-player infection")
	t.check(r.use_item(w,victim,tile,764).accepted and victim.modifiers.has("Infected!"),"Direct g-Virus injection bypasses Zombie Jammer as documented")
	victim.modifiers.clear();r.interact(w,p,tile,"activate",{})
	t.check(r.recovered.infect(w,p,victim) and victim.modifiers.has("Infected!"),"Disabling Zombie Jammer restores infection from infected player")

	var core=preload("res://src/network/room_server.gd").new()
	core.join(1,"Owner","PUBLIC");core.join(2,"Guest","PUBLIC")
	var room: Dictionary=core.rooms.PUBLIC
	room.owner=1
	room.world.locks=[{"x":52,"y":23,"item":5,"area":0,"owner":"session:1","tiles":[]}]
	room.world.set_tile(tile,204992);room.world.extras["2349"]={"public":true}
	core.players[2].state.position=Vector2(48*32+16,24*32)
	core.accept(2,{"type":"input","seq":1,"axis":0,"action":"punch","x":49,"y":23});core.step(1.0/60)
	t.check(rules.flags(room.world).antigravity and room.world.tile_at(tile)==204992 and not room.world.damage.has(tile),"Public switch lets guest toggle without damaging protected block")
	core.players[2].actions.cooldown=0
	t.check(not core.accept(2,{"type":"machine","x":49,"y":23,"command":"configure","args":{"silent":true}}),"Public on/off permission does not grant configuration rights")
	for invalid in [{"r":0,"g":0,"b":0},{"r":-1,"g":255,"b":0},{"r":100.5,"g":255,"b":0}]:
		w.create_default("COLORS");w.set_tile(tile,203694)
		t.check(not r.interact(w,p,tile,"configure",invalid).accepted,"Heatwave rejects invalid or too-dark RGB values")
	w.create_default("COLORS");w.set_tile(tile,203694)
	t.check(r.interact(w,p,tile,"configure",{"r":128,"g":60,"b":255}).accepted,"Heatwave accepts exact source RGB range")
	w.set_tile(tile,205000);w.extras.clear()
	t.check(not r.interact(w,p,tile,"configure",{"bg":2}).accepted and r.interact(w,p,tile,"configure",{"bg":14}).accepted,"Background weather accepts background blocks only")
	w.set_tile(tile,203832);w.extras.clear()
	t.check(r.interact(w,p,tile,"configure",{"item":1772,"gravity":-200,"spin":true,"invert":false}).accepted,"Stuff stores selected source item, reverse gravity and spin")

	w.create_default("IMPORTED");w.set_tile(tile,216104);w.extras.clear()
	var first: Dictionary=r.interact(w,p,tile,"harvest",{})
	t.check(not first.accepted and r.state(w,tile).has("ready"),"Imported recent provider initializes a missing cooldown safely")
