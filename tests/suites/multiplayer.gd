extends RefCounted

func run(t) -> void:
	var core = load("res://src/network/room_server.gd").new()
	for id in range(1,13):
		t.check(core.join(id,"Player"+str(id),"SHARED").ok,"Shared room accepts player "+str(id))
	t.check(core.snapshot("SHARED").size() == 12,"Room supports more than two players")
	var packet := {"type":"input","seq":1,"axis":1.0,"action":"none"}
	t.check(core.accept(1,packet),"Server accepts valid sequenced movement")
	t.check(not core.accept(1,packet),"Replay rejected")
	t.check(not core.accept(1,{"type":"input","seq":2,"axis":100}),"Impossible movement rejected")
	var original: Vector2 = core.players[1].state.position
	for frame in 12:
		core.step(1.0/60)
	t.check(core.players[1].state.position.x > original.x,"Authoritative simulation moves player")
	t.check(core.accept(1,{"type":"outfit","equipment":{"back":362}}),"Server validates wearable slot")
	t.check(not core.accept(2,{"type":"outfit","equipment":{"back":2}}),"Invalid outfit cannot grant abilities")
	core.players[1].state.position = core.rooms.SHARED.world.spawn_position()
	t.check(core.accept(1,{"type":"input","seq":2,"axis":0.0,"action":"place","item":5,"x":51,"y":23}),"Owner placement request accepted")
	core.step(1.0/60)
	t.check(core.rooms.SHARED.owner == 1,"Server grants lock ownership")
	core.accept(2,{"type":"input","seq":1,"axis":0.0,"action":"place","item":1,"x":49,"y":23})
	core.step(1.0/60)
	t.check(core.rooms.SHARED.world.tile_at(Vector2i(49,23)) == 0,"Other player cannot modify locked world")
	core.accept(1,{"type":"input","seq":3,"axis":0.0,"action":"place","item":5,"x":49,"y":23})
	core.players[1].actions.cooldown = 0
	core.step(1.0/60)
	t.check(core.rooms.SHARED.world.foreground.count(5) == 1,"Multiplayer cannot place duplicate lock")
	t.check(core.accept(2,{"type":"chat","text":"Shared hello"}),"Room chat accepted")
	t.check(not core.accept(2,{"type":"chat","text":"Flood"}),"Chat flood throttled")
	core.join(20,"Other","OTHER")
	t.check(core.snapshot("OTHER").size() == 1,"Snapshots isolate world membership")
	core.leave(1)
	t.check(core.rooms.SHARED.owner == 0 and core.rooms.SHARED.world.foreground.count(5) == 0,"Anonymous session lock released when owner leaves")
