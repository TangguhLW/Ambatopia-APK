extends RefCounted
func run(t):
	t.check(load("res://src/diagnostics/qa_runner.gd").can_instantiate(),"The exported QA harness compiles before a device install")
	var bag=load("res://src/ui/inventory.gd").new()
	t.root.add_child(bag)
	bag.size=Vector2(1024,600);bag.mode="clothes";bag.worn={"face":34};bag.rebuild()
	await t.process_frame
	t.check(bag.grid.get_child(0).find_child("WornTick",true,false).visible,"Old native outfit IDs mark the equivalent source wardrobe card as worn")
	var removed: Array=[]
	bag.catalog_unequip_requested.connect(func(slot):removed.append(slot))
	bag.activate_item(200034,1000);bag.activate_item(200034,1100)
	t.check(removed==["face"],"Double tap removes an equipped item saved with an old native ID")
	t.check(bag.has_meta("category_rail"),"Wardrobe exposes a category rail rather than only a dropdown")
	t.check(bag.grid.get_child(0).find_child("ItemName",true,false)!=null,"Wardrobe cards show item names beside their preview")
	if bag.has_method("choose_slot"):
		bag.choose_slot("hat")
		t.check(bag.entries.all(func(e):return (load("res://src/game/simulator_catalog.gd").slot(int(e.id)) if e.get("simulator",false) else load("res://src/game/item_catalog.gd").summary(int(e.id)).slot)=="hat"),"Hat rail filters the actual full catalog")
		bag.choose_slot("")
	else:t.check(false,"Rail selection changes the full catalog filter")
	for extent in [Vector2(390,640),Vector2(844,350),Vector2(1280,600)]:
		bag.size=extent
		await t.process_frame
		bag.update_columns()
		t.check(bag.item_scroll.get_global_rect().end.x<=bag.get_global_rect().end.x+1,"Item viewport stays inside the drawer after resize")
	bag.queue_free()
	await t.process_frame
	var app=load("res://scenes/app.tscn").instantiate();t.root.add_child(app)
	app.session.store.directory="user://drawer019-fixtures"
	app.start_local("DrawerQA");app.enter_world("DRAWER019")
	await t.process_frame
	var play=app.screen
	play.toggle_inventory();await t.create_timer(0.3).timeout
	play.inventory.inspect_item(200034)
	await t.process_frame
	await t.process_frame
	t.check(play.inventory.get_rect().end.y<=play.size.y+1,"Selected item inspector remains above the screen bottom")
	play.drag_inventory(0,false);play.drag_inventory(-play.inventory_height()*0.4,true)
	await t.create_timer(0.3).timeout
	t.check(not is_instance_valid(play.inventory),"A downward swipe below half the open backpack closes it")
	app.queue_free();await t.process_frame
