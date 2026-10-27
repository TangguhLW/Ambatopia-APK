extends RefCounted

func run(t) -> void:
	var core = load("res://src/network/room_server.gd").new()
	core.join(1,"Normal","SECURITY",{"id":"player-a","role":"player"})
	t.check(not core.accept(1,{"type":"developer","command":"god","enabled":true}),"Regular account cannot enable god mode")
	t.check(not core.accept(1,{"type":"developer","command":"invisible","enabled":true}),"Regular account cannot become invisible")
	core.join(2,"Thaney","SECURITY",{"id":"developer","role":"developer"})
	t.check(core.players[2].state.display_name == "@Thaney","Verified developer gets @Thaney title")
	t.check(core.accept(2,{"type":"developer","command":"god","enabled":true}) and core.players[2].state.god_mode,"Verified developer god mode enforced on server")
	core.accept(2,{"type":"developer","command":"invisible","enabled":true})
	t.check(not core.snapshot("SECURITY").any(func(p): return p.id==2),"Invisible developer absent from other snapshots")
	t.check(not core.join(3,"Spoof","SECURITY",{"id":"player-a","role":"player"}).ok,"Duplicate authenticated session rejected")
	core.rooms.SECURITY.world.set_tile(Vector2i(49,23),5)
	core.rooms.SECURITY.owner=1
	core.rooms.SECURITY.owner_uid="player-a"
	core.leave(1)
	t.check(core.rooms.SECURITY.world.tile_at(Vector2i(49,23)) == 5,"Authenticated ownership survives disconnect")
	var player = load("res://src/game/player_state.gd").new()
	player.position = core.rooms.SECURITY.world.spawn_position()
	var action = load("res://src/game/interactions.gd").new()
	action.apply(core.rooms.SECURITY.world,player,"punch",Vector2i(49,23),0)
	t.check(player.facing == -1,"Punch faces a selected tile on the left")
