extends RefCounted
const World = preload("res://src/game/world_state.gd")
const Player = preload("res://src/game/player_state.gd")
const Actions = preload("res://src/game/interactions.gd")
func run(t) -> void:
	if not ResourceLoader.exists("res://src/game/item_runtime.gd"):
		t.check(false,"Item runtime must exist before source items can be used")
		return
	var runtime = load("res://src/game/item_runtime.gd").new()
	var world = World.new()
	world.create_default("ITEMTEST")
	var player = Player.new()
	player.position = Vector2(48*32+16,24*32)
	player.grounded = true
	var tile := Vector2i(49,23)
	var actions := Actions.new()
	var planted = actions.apply(world,player,"place",tile,200003)
	t.check(planted.accepted and world.tile_at(tile)==200003,"Dirt seed plants on supporting ground")
	t.check(world.extras.has("2349"),"Plant records a persistent growth start")
	var data: Dictionary = world.extras["2349"]
	data.planted = runtime.now()-100
	var harvested = runtime.interact(world,player,tile,"harvest",{})
	t.check(harvested.accepted and world.tile_at(tile)==0 and not world.drops.is_empty(),"Mature tree harvest produces collectable source drops")
	var restored = World.new()
	t.check(restored.restore(world.serialize()) and restored.drops.size()==world.drops.size(),"Drops and item extras survive save/rejoin")
	world.set_tile(tile,200866)
	world.extras["2349"]={"ready":runtime.now()-1}
	var provider = runtime.interact(world,player,tile,"harvest",{})
	t.check(provider.accepted and world.tile_at(tile)==200866 and world.extras["2349"].ready>runtime.now(),"Provider harvest keeps machine and resets source cooldown")
	world.set_tile(tile,200003)
	world.extras["2349"]={"planted":runtime.now(),"duration":1000,"seed":3}
	var spray = runtime.use_item(world,player,tile,228)
	t.check(spray.accepted and world.extras["2349"].planted<runtime.now()-100,"Growth spray advances real tree state")
	var mod = runtime.use_item(world,player,tile,274)
	t.check(mod.accepted and player.modifiers.has("Frozen"),"Freeze Wand creates expiring player modifier")
	player.tick_modifiers(11)
	t.check(not player.modifiers.has("Frozen"),"Timed modifier expires")
	world.set_tile(tile,1)
	var paint = runtime.use_item(world,player,tile,3478)
	t.check(paint.accepted and world.extras["2349"].has("paint"),"Paint modifies target tile appearance data")
	var pack = runtime.use_item(world,player,tile,1360)
	t.check(pack.accepted and pack.events.any(func(e):return e.type=="reward"),"Gift produces actual reward items")
	world.set_tile(tile,200460)
	var toggle = runtime.interact(world,player,tile,"activate",{})
	t.check(toggle.accepted and world.extras["2349"].get("enabled",false),"Toggle machine changes persistent state")
	var denied = runtime.interact(world,player,tile,"configure",{"label":"bad","unknown":"field"})
	t.check(not denied.accepted,"Unrecognized machine fields fail closed")
	world.set_tile(tile,202978)
	var vend = runtime.interact(world,player,tile,"deposit",{"item":2,"amount":5})
	t.check(vend.accepted and world.extras["2349"].stock.get("2",0)==5,"Creative vending stock stores selected item and amount")
	var buy = runtime.interact(world,player,tile,"dispense",{})
	t.check(buy.accepted and world.extras["2349"].stock.get("2",0)==4,"Vending dispenses a real collectable item")
	world.set_tile(tile,200756)
	var game = runtime.interact(world,player,tile,"activate",{})
	t.check(game.accepted and not str(world.extras["2349"].get("result","")).is_empty(),"Free machine activation produces a persistent result")
	world.set_tile(tile,204080)
	world.extras.erase("2349")
	runtime.interact(world,player,tile,"deposit",{"item":4082,"amount":3})
	var craft=runtime.interact(world,player,tile,"craft",{"recipe":0})
	t.check(craft.accepted and world.drops.any(func(drop):return int(drop.id)==3952),"DNA processor consumes recovered recipe ingredients and creates its exact output")
	t.check(not runtime.interact(world,player,tile,"deposit",{"item":{},"amount":1}).accepted,"Malformed machine input cannot crash item runtime")
	var core=load("res://src/network/room_server.gd").new()
	core.join(1,"Owner","MACHINES",{"id":"owner","role":"player"})
	core.join(2,"Guest","MACHINES",{"id":"guest","role":"player"})
	var shared=core.rooms.MACHINES
	shared.world.set_tile(tile,202978)
	shared.owner_uid="owner"
	shared.owner=1
	t.check(not core.accept(2,{"type":"machine","x":49,"y":23,"command":"deposit","args":{"item":2,"amount":5}}),"Other account cannot change locked-world machine stock")
	t.check(core.accept(1,{"type":"machine","x":49,"y":23,"command":"deposit","args":{"item":2,"amount":5}}),"Owner can change own machine stock")
	t.check(core.events.any(func(event):return event.type=="item_state"),"Machine mutations create replicated item-state events")
	t.check(not core.accept(1,{"type":"machine","x":INF,"y":23,"command":"activate","args":{}}),"Non-finite machine coordinates fail closed")
	var bad_save=world.serialize()
	bad_save.drops=[{"id":"invalid"}]
	t.check(not World.new().restore(bad_save),"Malformed persisted item drops fail closed")
	for machine in [4080,4498,2452,4582]:
		world.set_tile(tile,200000+machine)
		var recipes: Array=runtime.recipes_for(machine)
		t.check(not recipes.is_empty(),"Recovered machine recipes available: "+str(machine))
		for index in recipes.size():
			world.extras.erase("2349")
			world.drops.clear()
			var ingredients: Array=recipes[index].inputs
			for ingredient in ingredients:
				runtime.interact(world,player,tile,"deposit",{"item":int(ingredient),"amount":ingredients.count(ingredient)})
			var made=runtime.interact(world,player,tile,"craft",{"recipe":index})
			t.check(made.accepted and world.drops.any(func(drop):return int(drop.id)==int(recipes[index].output)),"Recovered recipe creates exact output: %d/%d" % [machine,index])
	for provider_id in sim_provider_ids(runtime):
		world.set_tile(tile,200000+int(provider_id))
		world.extras.erase("2349")
		world.drops.clear()
		runtime.planted(world,tile,int(provider_id))
		runtime.interact(world,player,tile,"grow",{})
		var produced=runtime.interact(world,player,tile,"harvest",{})
		var verified: bool=int(provider_id)==1008 or runtime.Sim.use_rules.provider_drop.has(provider_id) or runtime.recovered.data.providers.has(provider_id)
		t.check(produced.accepted and not world.drops.is_empty() if verified else not produced.accepted and world.drops.is_empty(),"Provider follows recovered drop coverage without fabricated rewards: "+provider_id)
	for id in [200156,200362,1460]:
		t.check(player.equip_catalog(id),"Source wardrobe can equip wings %d" % id)
	t.check(player.can_double_jump(),"Source wardrobe grants double jump")
	player.unequip_catalog("back")
	t.check(not player.can_double_jump(),"Removing effect item removes ability")
	var sim = load("res://src/game/simulator_catalog.gd")
	for id in sim.use_rules.cloth:
		t.check(player.equip_catalog(200000+int(id)),"Every source wardrobe entry can be worn: "+id)
	for id in sim.use_rules.seed:
		if int(id) not in [1,7,9]:
			t.check(sim.supported(200000+int(id)),"Seed has usable runtime: "+id)
			world.set_tile(tile,0)
			world.extras.clear()
			world.drops.clear()
			var seed_result = runtime.seed_use(world,player,tile,int(id))
			t.check(seed_result.accepted,"Every seed can actually be planted: "+id)
			var ready = runtime.interact(world,player,tile,"grow",{})
			t.check(ready.accepted,"Every planted source seed can grow: "+id)
			var yield_result = runtime.interact(world,player,tile,"harvest",{})
			t.check(yield_result.accepted and not world.drops.is_empty(),"Every mature source tree yields items: "+id)
	for id in runtime.extra.consumable:
		t.check(runtime.handler_for(int(id))!="","Consumable has explicit handler: "+id)
		world.create_default("USETEST")
		var kind: String=runtime.handler_for(int(id))
		if kind in ["grow_spray","world_spray"]:
			world.set_tile(tile,200003)
			runtime.planted(world,tile,3)
		elif kind=="love_potion":
			world.set_tile(tile,3)
		elif kind in ["spatula","extract_o_snap","fossil_brush"]:
			world.set_tile(tile,1)
			if kind!="spatula":
				runtime.reward(world,tile,3936 if kind=="fossil_brush" else 2)
		elif kind=="lock_mover":
			world.set_tile(Vector2i(51,23),5)
			world.locks=[{"x":51,"y":23,"item":5,"area":0,"owner":"test","tiles":[]}]
		var used = runtime.use_item(world,player,tile,int(id))
		var unavailable_blast: bool=kind=="world_blast" and not preload("res://src/game/source_blasts.gd").available(int(id))
		t.check(not used.accepted and used.events.is_empty() if unavailable_blast else used.accepted and not used.events.is_empty(),"Consumable follows recovered behavior or reports unavailable source: "+id)
	if not ResourceLoader.exists("res://src/ui/weather_scene.gd"):
		t.check(false,"Complex weather requires a live scene interpreter")
		return
	var scene = load("res://src/ui/weather_scene.gd").new()
	t.check(scene.value(["+",["*","W",0.5],3],{"W":100})==53,"Weather expression interpreter evaluates recovered arithmetic")
	t.check(scene.value(["/",3,0],{})==0,"Weather expression interpreter handles zero safely")
	t.check(scene.value(["?",["==",1,1],8,9],{})==8,"Weather condition expression")
func sim_provider_ids(_runtime) -> Array:
	return load("res://src/game/simulator_catalog.gd").use_rules.provider.keys()
