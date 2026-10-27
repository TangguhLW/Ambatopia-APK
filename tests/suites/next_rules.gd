extends RefCounted
func run(t) -> void:
	var Core = load("res://src/network/room_server.gd")
	var c = Core.new()
	c.join(1,"Owner","RULES",{"id":"owner","role":"player"})
	c.join(2,"Guest","RULES",{"id":"guest","role":"player"})
	c.join(3,"Thaney","RULES",{"id":"dev","role":"developer"})
	c.rooms.RULES.owner = 1
	c.rooms.RULES.owner_uid = "owner"
	t.check(not c.accept(2,{"type":"chat","text":"/pull Owner"}),"Non-owner cannot pull")
	t.check(c.accept(1,{"type":"chat","text":"/pull Guest"}),"Owner can pull")
	c.players[1].last_chat = -1000
	t.check(c.accept(1,{"type":"chat","text":"/sb Hello all worlds"}),"Broadcast accepted")
	c.players[1].last_chat = -1000
	t.check(not c.accept(1,{"type":"chat","text":"/sb Again"}),"Broadcast cooldown enforced")
	c.players[1].last_chat = -1000
	t.check(c.accept(1,{"type":"chat","text":"/ban Guest"}),"Owner can world-ban")
	c.leave(2)
	t.check(not c.join(2,"Guest","RULES",{"id":"guest","role":"player"}).ok,"World ban survives reconnect")
	t.check(c.accept(3,{"type":"developer","command":"amba","enabled":true}),"Developer may transform")
	t.check(not c.accept(1,{"type":"developer","command":"amba","enabled":true}),"Player may not transform")
	var w = c.rooms.RULES.world
	c.players[3].state.position = w.spawn_position()
	c.accept(3,{"type":"input","seq":0,"axis":0,"action":"punch","x":50,"y":23,"item":0})
	c.step(1.0/60)
	t.check(w.tile_at(Vector2i(50,23)) == 0,"Developer can break white door")
	var restored = load("res://src/game/world_state.gd").new()
	t.check(restored.restore(w.serialize()) and restored.tile_at(Vector2i(50,23)) == 0,"Developer door deletion persists")

	var Locks = load("res://src/game/lock_rules.gd")
	var fresh = load("res://src/game/world_state.gd").new()
	fresh.create_default("AREAS")
	for spec in [[100202,10],[100204,48],[100206,200],[104994,200]]:
		fresh.locks.clear()
		Locks.placed(fresh,Vector2i(40,15),spec[0],"owner")
		t.check(fresh.locks[0].tiles.size() == spec[1],"Area capacity: "+str(spec[1]))
		t.check(Locks.owner_at(fresh,Vector2i(40,15)) == "owner","Lock tile belongs to its owner")
		t.check(Locks.owner_at(fresh,Vector2i(90,15)) == "","Area lock leaves distant tiles free")
		t.check(not Locks.can_place(fresh,Vector2i(40,15),100202,"guest"),"Another player cannot overlap an area lock")
	fresh.locks.clear()
	fresh.set_tile(Vector2i(40,15),5)
	t.check(not Locks.can_place(fresh,Vector2i(42,15),101796,"owner"),"Existing legacy World Lock blocks another full-world lock")
	var sim = load("res://src/game/simulator_catalog.gd")
	t.check(sim.items().size() == 16508,"Full simulator source inventory retained")
	t.check(sim.weather_list.size() == 80,"All simulator weather choices retained")
	for blocked in [200006,200007,200008,200009]:
		t.check(not sim.supported(blocked),"Protected item cannot be taken: "+str(blocked))
	t.check(sim.supported(200002),"Simulator Dirt is placeable")
	c.players[3].actions.cooldown = 0
	c.players[3].state.position = Vector2(50*32+16,24*32)
	c.accept(3,{"type":"input","seq":1,"axis":0,"action":"punch","x":50,"y":24,"item":0})
	c.step(1.0/60)
	t.check(w.tile_at(Vector2i(50,24)) == 0,"Developer can break spawn bedrock")
	c.players[3].input.action = "none"
	c.join(4,"Moderator","RULES",{"id":"mod","role":"player","settings":{"moderator":true}})
	t.check(not c.accept(4,{"type":"developer","command":"god","enabled":true}),"Moderator cannot use developer powers")
	t.check(c.accept(4,{"type":"chat","text":"/pull Owner"}),"Moderator can moderate without developer powers")
	c.rooms.RULES.owner_uid = "owner"
	c.rooms.RULES.owner = 1
	t.check(c.accept(3,{"type":"weather","key":"night"}),"Developer can change weather")
	t.check(not c.accept(4,{"type":"weather","key":"sunny"}),"Moderator cannot change someone else's locked world")

	var a = load("res://src/game/interactions.gd").new()
	var farmer = load("res://src/game/player_state.gd").new()
	fresh.create_default("LAYERTEST")
	farmer.position = fresh.spawn_position()
	fresh.background[24*100+49]=0
	var result: Dictionary = a.apply(fresh,farmer,"place",Vector2i(49,24),200014)
	t.check(result.accepted and fresh.tile_at(Vector2i(49,24)) == 1 and fresh.background[24*100+49] == 200014,"Background can be placed behind foreground without replacing dirt")
