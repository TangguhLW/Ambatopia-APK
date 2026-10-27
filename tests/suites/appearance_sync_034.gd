extends RefCounted

func run(t) -> void:
	var W=load("res://src/game/wardrobe_effects.gd")
	var D=load("res://src/game/death_sequence.gd").new()
	t.check(D.has_method("additive_blend"),"Death particle blend decoding supports numeric and string source modes")
	if D.has_method("additive_blend"):
		for mode in [0,0.0,1,1.0,"lighter","source-over"]:
			t.check(D.additive_blend(mode)==(str(mode) in ["1","1.0","lighter"]),"Source death blend mode is decoded without mixed-type comparison: "+str(mode))
	t.check(W.abilities({"shirt":5264,"feet":1740})==W.abilities({"feet":1740,"shirt":5264}),"Buff state and displayed labels do not depend on SQL JSON key order")
	var path="res://src/network/appearance.gd"
	t.check(ResourceLoader.exists(path),"Network appearance normalizes JSON IDs before native rendering")
	if not ResourceLoader.exists(path):return
	var A=load(path)
	var packet=JSON.parse_string('{"feet":1740,"neck":6064,"shirt":5264,"hand":5480}')
	var outfit=A.equipment(packet)
	t.check(outfit=={"shirt":5264,"neck":6064,"feet":1740,"hand":5480},"Live JSON outfit equals native integer catalog state")
	t.check(outfit.values().all(func(id):return id is int),"Every replicated equipment ID has native integer type")
	t.check(A.equipment({"god":true}).is_empty(),"Appearance parser excludes privilege keys")
	t.check(A.equipment({"shirt":5264.5}).is_empty() and A.equipment({"shirt":"5264"}).is_empty(),"Appearance parser rejects fractional and string IDs")
	var bag=load("res://src/ui/inventory.gd").new()
	t.root.add_child(bag);bag.worn={"hat":46};bag.refresh_dock()
	bag.catalog_unequip_requested.connect(func(slot):bag.worn.erase(slot);bag.refresh_dock())
	var button=bag.worn_dock.get_child(0)
	button.pressed.emit()
	t.check(is_instance_valid(button) and button.get_parent()==null and button.is_queued_for_deletion(),"Unequip detaches and defers deletion of the button currently emitting its signal")
	bag.queue_free();await t.process_frame
