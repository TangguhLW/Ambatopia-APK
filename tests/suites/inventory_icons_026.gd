extends RefCounted
func run(t) -> void:
	var I=load("res://src/game/inventory_icons.gd")
	var Sim=load("res://src/game/simulator_catalog.gd")
	var UI=load("res://src/ui/theme.gd")
	I.load_index()
	for pair in [[2,Vector2i(384,672)],[4,Vector2i(256,224)],[8,Vector2i(128,864)]]:
		var original: Texture2D=Sim.sprite(pair[0])
		var icon: Texture2D=I.texture(pair[0])
		t.check(original!=null and icon!=null and icon.get_size()==Vector2(32,32),"Dirt/lava/bedrock have a complete independent inventory icon")
		t.check(icon.get_image().get_pixel(16,16).is_equal_approx(original.atlas.get_image().get_pixel(pair[1].x+16,pair[1].y+16)),"Icon centre samples the simulator's isolated atlas cell")
		t.check(original.region.position!=Vector2(pair[1]),"Fixing backpack icons does not replace the world adjacency base cell")
	for id in [3,5,17]:
		var icon=I.texture(id)
		t.check(icon!=null and icon.get_image().get_region(Rect2i(0,0,32,8)).is_invisible(),"Seed icon keeps the source transparent eight-pixel margin")
	t.check(UI.item_icon(1)==I.texture(2) and UI.item_icon(200002)==I.texture(2),"Legacy and catalog dirt use the same backpack icon")
	t.check(UI.item_icon(7)==I.texture(4),"Legacy lava uses the same isolated icon as catalog lava")
	var bag=load("res://src/ui/inventory.gd").new();t.root.add_child(bag);bag.size=Vector2(1024,600)
	for extent in [Vector2(390,640),Vector2(844,350),Vector2(1280,600)]:
		bag.size=extent;bag.mode="blocks";bag.search.text="Dirt";bag.rebuild();await t.process_frame;bag.update_columns()
		for card in bag.grid.get_children():
			var icon=card.get_node_or_null("ItemIcon")
			t.check(icon!=null and icon.texture!=null,"Every visible dirt card has a mapped inventory icon")
			if icon==null:continue
			t.check(icon.size.x==icon.size.y and int(icon.size.x)%32==0 and icon.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"Backpack uses square integer-scale pixel art at each window size")
			t.check(icon.position.x>=0 and icon.position.x+icon.size.x<=card.size.x+1,"Icon stays within its card")
	bag.queue_free();await t.process_frame
	t.check(I.pages.size()<=I.PAGE_LIMIT and I.icons.size()<=I.ICON_LIMIT,"Inventory texture caches stay bounded")
