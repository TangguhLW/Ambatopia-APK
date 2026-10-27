extends RefCounted

func run(t) -> void:
	var bag = load("res://src/ui/inventory.gd").new()
	t.root.add_child(bag)
	t.check(bag.entries.size() > 3000 and not bag.entries.any(func(e): return e.category in ["seed","clothing","consumable"]),"Blocks includes the full building collection without clothing/seeds")
	bag.inspect_item(14232)
	t.check(load("res://src/game/item_catalog.gd").summary(bag.selected).get("equip",false),"Native renderer wearable uses runtime equip capability")
	bag.mode="simulator"
	bag.rebuild()
	t.check(bag.entries.size()==16508,"All items exposes every source record")
	bag.size=Vector2(390,600)
	await t.process_frame
	await t.process_frame
	bag.item_scroll.scroll_vertical=int(bag.item_content.custom_minimum_size.y)
	await t.process_frame
	bag.render_window()
	t.check(bag.window_end==bag.entries.size() and bag.grid.get_child_count()>0,"Last item is reachable by scrolling")
	t.check(bag.grid.get_child_count()<=144,"Large catalog keeps a bounded visible control pool")
	bag.mode="clothes"
	bag.rebuild()
	t.check(bag.entries.size()>=4071,"All 4071 source clothing entries include artifacts")
	bag.queue_free()
	var hud = load("res://src/ui/hud.gd").new()
	t.root.add_child(hud)
	for dimensions in [Vector2(390,844),Vector2(844,390),Vector2(320,568)]:
		hud.size=dimensions
		hud.layout()
		for control in [hud.left,hud.right,hud.jump,hud.punch,hud.inventory_drawer]:
			t.check(control.size.x>=48 and control.size.y>=44,"Mobile touch target: "+control.tooltip_text)
		t.check(not hud.left.get_rect().intersects(hud.right.get_rect()),"Movement targets do not overlap")
		t.check(not hud.jump.get_rect().intersects(hud.punch.get_rect()),"Action targets do not overlap")
	hud.overlay_blocked=true
	t.check(not hud.route_touch(44,hud.left.get_global_rect().get_center(),true),"HUD cannot steal item/menu touches behind an open overlay")
	hud.queue_free()
	var renderer = load("res://src/ui/weather_renderer.gd").new()
	t.check(renderer.has_method("viewport_extent"),"Weather uses a stable viewport extent")
	if renderer.has_method("viewport_extent"):
		var canvas=Control.new()
		canvas.size=Vector2(844,390)
		canvas.set_meta("weather_horizon",100)
		var before: Vector2=renderer.viewport_extent(canvas)
		canvas.set_meta("weather_horizon",180)
		t.check(renderer.viewport_extent(canvas)==before,"Jump/camera horizon cannot resize background")
		canvas.free()
	var avatar=load("res://src/game/avatar_view.gd").new()
	t.check(avatar.slot_origin("hat").y<avatar.slot_origin("face").y,"Headwear has a dedicated head anchor")
	t.check(avatar.slot_origin("pants")==Vector2(-16,-32),"Lower clothing preserves the source body cell origin")
	avatar.clothing_texture("feet",40)
	t.check(avatar.worn_cache.feet.has("second_foot"),"Brown Shoes draw the separate second foot frame")
	avatar.free()
	var app=load("res://scenes/app.tscn").instantiate()
	app.session.store.directory="user://ui-revision-fixtures"
	t.root.add_child(app)
	await t.process_frame
	app.start_local("DrawerFixture")
	app.enter_world("DRAWERFIXTURE")
	var game=app.screen
	game.drag_inventory(0,false)
	game.drag_inventory(game.inventory_height()*0.5,false)
	t.check(is_equal_approx(game.inventory_fraction,0.5),"Backpack follows finger halfway instead of instantly opening")
	game.drag_inventory(game.inventory_height()*0.6,true)
	await t.create_timer(0.3).timeout
	t.check(is_equal_approx(game.inventory_fraction,1),"Released opening swipe snaps to open")
	game.drag_inventory(0,false)
	game.drag_inventory(-game.inventory_height()*0.9,true)
	await t.create_timer(0.3).timeout
	t.check(not is_instance_valid(game.inventory) and not game.input.text_focus,"Downward swipe closes backpack and restores player controls")
	game.drag_inventory(0,false)
	game.drag_inventory(0,true)
	await t.create_timer(0.3).timeout
	t.check(is_instance_valid(game.inventory) and is_equal_approx(game.inventory_fraction,1),"Tapping backpack handle opens it without a swipe")
	app.queue_free()
	await t.process_frame
