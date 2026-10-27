extends RefCounted
func run(t) -> void:
	var D=load("res://src/game/source_drop_rules.gd").new()
	t.check(D.has_method("chest"),"Valentine chests use recovered source reward branches")
	if not D.has_method("chest"):return
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://research/machines-030/chest-fixtures.json"))
	for sample in fixture.samples:
		D.random_stream=sample.random_hex.map(func(value):return str(value).hex_decode().decode_double(0))
		var reward: Array=D.chest(int(sample.id))
		t.check(reward.size()==2 and int(reward[0])==int(sample.expected[0]) and int(reward[1])==int(sample.expected[1]) and D.random_stream.is_empty(),"Original chest RNG branches, override order and amounts: "+JSON.stringify(sample))
	var r=load("res://src/game/item_runtime.gd").new()
	var w=load("res://src/game/world_state.gd").new();w.create_default("CHESTS030")
	var p=load("res://src/game/player_state.gd").new();p.position=Vector2(48*32+16,24*32);p.developer=true
	var actions=load("res://src/game/interactions.gd").new()
	var tile:=Vector2i(49,23)
	for id in [392,3402,9350]:
		w.drops.clear();w.set_tile(tile,id+200000);actions.cooldown=0
		actions.runtime.source_drops.random_stream=[0.5,0.5,0.0]
		var result: Dictionary=actions.apply(w,p,"punch",tile,0)
		t.check(result.accepted and w.tile_at(tile)==0 and w.drops.size()==1 and int(w.drops[0].id)==13122,"Real break action awards source chest content once: "+str(id))
