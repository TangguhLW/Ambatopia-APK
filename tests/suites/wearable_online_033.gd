extends RefCounted

func run(t) -> void:
	var P=load("res://src/game/player_state.gd")
	var W=load("res://src/game/wardrobe_effects.gd")
	var neon=W.abilities({"shirt":5264})
	t.check(W.abilities({"shirt":5264,"neck":4988}).speed==neon.speed,"Neon and Speed Medallion do not stack with one another")
	t.check(W.abilities({"shirt":5264,"feet":1740}).speed>neon.speed,"Neon stacks with another Speedy clothing item")
	t.check(W.abilities({"shirt":5264,"feet":1740,"neck":4988}).speed==W.abilities({"shirt":5264,"feet":1740}).speed,"Medallion does not add an extra Neon stack")
	t.check(W.abilities({"shirt":205264,"feet":201740}).speed==W.abilities({"shirt":5264,"feet":1740}).speed,"Encoded catalog IDs retain the same buff grouping")
	t.check(W.abilities({"shirt":5264,"invalid_duplicate":5264}).speed==neon.speed,"Repeated IDs cannot manufacture speed stacks")
	var capped=W.abilities({"shirt":5264,"feet":1740,"hat":6782})
	t.check(capped.speed_stacks==3 and W.abilities({"shirt":5264,"feet":1740,"hat":6782,"pants":6294}).speed==capped.speed,"Neon is capped at two additional Speedy clothing contributions")
	var stacked=P.new();stacked.catalog_equipment={"shirt":5264,"feet":1740,"hat":6782}
	stacked.in_water=true
	t.check(stacked.speed_multiplier()==1,"Stacked land speed does not leak into swimming")
	stacked.in_water=false;stacked.world_rules={"block":{"spd":true}}
	t.check(stacked.speed_multiplier()==1,"Xenonite suppresses the whole worn speed stack")
	var shadow_path="res://src/game/spirit_shadow.gd"
	t.check(ResourceLoader.exists(shadow_path),"Spirit Guide has a silhouette trail rather than only a ground ellipse")
	if ResourceLoader.exists(shadow_path):
		var shadow=load(shadow_path).new();var p=P.new();p.equip_catalog(6064)
		for i in 30:
			p.position.x+=3;shadow.sample(p,1.0/60)
		t.check(shadow.traces(p).size()==3,"Moving Spirit Guide produces three bounded silhouette echoes")
		p.position.x+=400;shadow.sample(p,1.0/60)
		t.check(shadow.traces(p).is_empty(),"Teleport clears old Spirit silhouettes")
		p.catalog_equipment.clear();shadow.sample(p,1.0/60)
		t.check(shadow.history.is_empty(),"Unequipping Spirit Guide clears its trail")
		shadow.free()
	var core=load("res://src/network/room_server.gd").new()
	core.join(1,"Owner","COSMETIC")
	t.check(core.accept(1,{"type":"outfit","equipment":{},"skin":2,"item_options":{"pet_10034":false}}),"Valid cosmetic outfit packet is accepted")
	t.check(core.snapshot("COSMETIC")[0].get("item_options",{}).get("pet_10034",true)==false,"Pet visibility is included in local multiplayer snapshots")
	t.check(not core.accept(1,{"type":"outfit","equipment":{},"item_options":{"god":true}}),"Cosmetic packets cannot carry privilege fields")
	var client=load("res://src/network/supabase_client.gd").new()
	client.accounts=FakeAccounts.new();client.peers={"peer":{"id":2,"name":"Peer","equipment":{},"skin":0}}
	client.accept_motion("peer",{"seq":1,"x":100,"y":100,"vx":1,"vy":0,"grounded":true,"facing":1,"punch":0,"item_options":{"pet_10034":false},"equipment":{"neck":6064},"name":"Spoof","god":true})
	t.check(client.peers.peer.get("item_options",{}).get("pet_10034",true)==false,"Authenticated cosmetic broadcast synchronizes pet toggles")
	t.check(client.peers.peer.name=="Peer" and client.peers.peer.equipment.is_empty() and not client.peers.peer.has("god"),"Broadcast cannot replace SQL-authoritative identity, outfit, or role")
	client.free()

class FakeAccounts:
	extends RefCounted
	var profile={"id":"self"}
