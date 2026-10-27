extends RefCounted
func run(t) -> void:
	var P=load("res://src/game/player_state.gd")
	var Sets=load("res://src/storage/outfit_store.gd")
	var S=load("res://src/game/local_session.gd")
	var Seeds=load("res://src/game/seed_visuals.gd")
	var Sim=load("res://src/game/simulator_catalog.gd")
	var directory: String="user://sets027-"+str(Time.get_ticks_usec())
	var session=S.new();session.store.directory=directory
	var profile={"id":"local","display_name":"SetQA"}
	t.check(session.enter(profile,"FIRST").ok,"First world creates a local profile")
	t.check(session.player.equip_catalog(34) and session.player.equip_catalog(362),"Saved outfit uses validated original wardrobe IDs")
	session.player.skin_index=3;session.player.item_options={"pet_5480":false}
	t.check(session.save_set().ok,"Save set writes an atomic outfit checkpoint")
	t.check(session.enter(profile,"SECOND").ok and session.player.catalog_equipment=={"face":34,"back":362},"Outfit follows the profile into a different new world")
	t.check(session.player.skin_index==3 and session.player.item_options.get("pet_5480")==false,"Skin and pet options restore with the set")
	session.player.unequip_catalog("back");session.save_set()
	var fresh=S.new();fresh.store.directory=directory;fresh.enter(profile,"FIRST")
	t.check(fresh.player.catalog_equipment=={"face":34},"A fresh session restores the most recent set, including unequip")
	t.check(fresh.world_names().all(func(name):return not name.begins_with("SET_")),"Outfit checkpoints do not appear as worlds")
	fresh.enter({"id":"local","display_name":"AnotherPlayer"},"THIRD")
	t.check(fresh.player.catalog_equipment.is_empty(),"Another local profile does not inherit somebody else's set")
	t.check(Sets.slot({"id":"account-a","display_name":"Same"})!=Sets.slot({"id":"account-b","display_name":"Same"}),"Online accounts have distinct set storage keys even with the same displayed name")
	var saved=Sets.new();saved.store.directory=directory+"/outfits"
	var bad={"id":"bad"};saved.store.save(Sets.slot(bad),{"schema_version":2,"equipment":{},"catalog_equipment":{"face":2},"skin":0})
	var before=P.new();before.equip_catalog(34)
	t.check(not saved.restore(bad,before).ok and before.catalog_equipment=={"face":34},"Corrupt/cross-slot set data is rejected before changing any player slot")
	t.check(not before.developer and not before.god_mode,"Restoring cosmetic set cannot grant developer capabilities")
	for key in Sim.items():
		var row: Array=Sim.items()[key]
		if row[7]!=19:continue
		var id:=int(key)
		var plan: Dictionary=Seeds.plan(id,1,3)
		t.check(not plan.is_empty() and plan.result==id-1 and Sim.items().has(str(plan.result)),"Every seed maps to its actual grown item")
		if plan.is_empty():continue
		t.check(plan.trunk.position.y==608 and plan.leaves.position.y==576,"Seed tree uses original trunk/leaves atlas rows")
		t.check(plan.fruit.size()==3 and plan.fruit[0].position.is_equal_approx(Vector2(5.2,-1.8)),"Ripe fruit uses source count and positions")
		t.check(Seeds.plan(id,0.5,3).fruit.is_empty(),"Growing trees do not show ripe items early")
	var color: Color=Seeds.color(0x11223344)
	t.check(color.is_equal_approx(Color(0x33/255.0,0x22/255.0,0x11/255.0,0x44/255.0)),"Tree tint decodes source ABGR bytes correctly")
	var bag=load("res://src/ui/inventory.gd").new();t.root.add_child(bag)
	bag.size=Vector2(1024,600);bag.mode="clothes";bag.rebuild();await t.process_frame
	var captions: Array=[]
	for child in bag.find_children("*","Button",true,false):captions.append(child.text)
	t.check("Outfits" in captions and not "Reset" in captions and not "Wear" in captions and not "‹" in captions and not "›" in captions,"Wardrobe footer contains one Outfits entry without redundant navigation/reset/wear controls")
	var clicks: Array=[];bag.save_set_requested.connect(func():clicks.append(true));bag.save_set.pressed.emit()
	t.check(clicks==[true],"Save set button dispatches exactly one functional save request")
	bag.mode="simulator";bag.search.text="Shades Seed";bag.rebuild();await t.process_frame
	t.check(not bag.entries.is_empty() and bag.grid.get_child(0).get_node_or_null("SeedResult")!=null,"Clothing seed card shows the item it grows")
	bag.inspect_item(200035)
	t.check("Grows: Shades" in bag.detail.text,"Seed inspector names its actual harvest result")
	bag.queue_free();await t.process_frame
