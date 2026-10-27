extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://src/game/item_catalog.gd"):
		t.check(false,"Canonical catalog runtime exists")
		return
	var catalog = load("res://src/game/item_catalog.gd")
	catalog.index.clear()
	t.check(catalog.summary(34).name == "Shades" and catalog.index.is_empty(),"Saved outfit lookup avoids loading full search catalog")
	t.check(catalog.entries().size() == 16434,"All version27 records searchable offline")
	t.check(catalog.query("362","clothing","back").size() == 1,"ID and slot filter select Angel Wings")
	t.check(catalog.query("green shirt","clothing","shirt").size() >= 1,"Name search works")
	t.check(catalog.query("Dirt","block").size() >= 1,"Ordinary block category includes verified Dirt action type")
	t.check(catalog.record(362).effects[0].kind == "double_jump","Effect provenance retained")
	var p = load("res://src/game/player_state.gd").new()
	for item in catalog.query("","clothing","",true):
		p.reset_appearance()
		t.check(p.equip_catalog(int(item.id)) and catalog.sprite(int(item.id)) != null and p.catalog_equipment.get(item.slot) == int(item.id),"Wearable sprite and slot: " + item.name)
	p.reset_appearance()
	var view = load("res://src/game/avatar_view.gd").new()
	for item in catalog.query("","clothing","shirt",true).slice(0,50):
		view.clothing_texture("shirt",int(item.id))
	t.check(view.worn_cache.size() == 1 and catalog.texture_cache.size()<=8,"Repeated outfit switches retain current slot only")
	view.free()
	t.check(p.equip_catalog(34),"Equip face slot with original ID")
	t.check(not p.equip_catalog(2),"Reject block as clothing")
	t.check(p.equip_catalog(36) and p.equip_catalog(38),"Same-slot replacement works")
	t.check(p.catalog_equipment.shirt == 38,"Only latest shirt remains")
	p.reset_appearance()
	t.check(p.catalog_equipment.is_empty() and p.equipment.shirt == -1,"Reset removes legacy and canonical equipment")
	var world = load("res://src/game/world_state.gd").new()
	world.create_default("WINGS")
	p.position = world.spawn_position()
	p.grounded = true
	var sim = load("res://src/game/simulation.gd").new()
	p.equip_catalog(362)
	sim.step(world,p,{"jump_pressed":true},1.0/60)
	p.velocity.y = 100
	sim.step(world,p,{"jump_pressed":true},1.0/60)
	t.check(p.velocity.y < 0 and p.air_jumps == 1,"Angel Wings permits one midair jump")
	p.velocity.y = 100
	sim.step(world,p,{"jump_pressed":true},1.0/60)
	t.check(p.velocity.y > 0,"Third jump denied")
	p.unequip_catalog("back")
	p.velocity.y = 100
	sim.step(world,p,{"jump_pressed":true},1.0/60)
	t.check(p.velocity.y > 0,"Unequip removes double jump")
	var session = load("res://src/game/local_session.gd").new()
	session.store.directory = "user://catalog-save-fixtures"
	session.enter({"display_name":"Wardrobe"},"CATALOG")
	session.player.equip_catalog(34)
	t.check(session.save().ok,"Catalog outfit saves")
	session.enter({"display_name":"Wardrobe"},"CATALOG")
	t.check(session.player.catalog_equipment.get("face") == 34,"Original ID survives save/reload")
	var invalid_world: Dictionary = session.world.serialize()
	session.store.save("invalidcatalog",{"schema_version":2,"world":invalid_world,"equipment":{},"catalog_equipment":{"face":2}})
	t.check(not session.enter({},"INVALIDCATALOG").ok,"Saved cross-slot block ID rejected")
	var inventory = load("res://src/ui/inventory.gd").new()
	t.root.add_child(inventory)
	inventory.mode = "clothes"
	inventory.rebuild()
	t.check(inventory.grid.get_child_count() <= 144,"Only visible rows build controls")
	inventory.queue_free()
	await t.process_frame
