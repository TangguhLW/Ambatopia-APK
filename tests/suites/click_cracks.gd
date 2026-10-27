extends RefCounted

func run(t):
	var app=load("res://scenes/app.tscn").instantiate()
	t.root.add_child(app)
	app.session.store.directory="user://click-cracks-fixture"
	app.start_local("ClickQA");app.enter_world("CLICKCRACKS")
	await t.process_frame
	var play=app.screen
	play.toggle_inventory();await t.create_timer(0.3).timeout
	var bag=play.inventory
	bag.mode="clothes";bag.rebuild();await t.process_frame
	var card=bag.grid.get_child(0)
	var card_origin: Vector2=card.global_position
	card.pressed.emit();await t.process_frame;await t.process_frame
	t.check(is_instance_valid(card),"The first click preserves its target card")
	if not is_instance_valid(card):
		app.queue_free();await t.process_frame;return
	t.check(card.global_position.is_equal_approx(card_origin),"First item click does not move the wardrobe card before the second click")
	card.pressed.emit();await t.process_frame;await t.process_frame
	t.check(is_instance_valid(card) and not card.is_queued_for_deletion(),"Equipping preserves the live clicked card")
	var item: int=bag.selected
	t.check(bag.is_worn(item),"Two card clicks wear the item")
	if is_instance_valid(card) and not card.is_queued_for_deletion():
		card.pressed.emit();card.pressed.emit();await t.process_frame
		t.check(not bag.is_worn(item),"Next two card clicks remove the same item")
	else:t.check(false,"Clicked wardrobe card remains usable for removal")
	var crack_script=load("res://src/game/block_cracks.gd")
	if crack_script!=null and crack_script.can_instantiate():
		t.check(crack_script.region(1,8)==Rect2(0,0,32,32),"Early block damage uses the first source crack frame")
		t.check(crack_script.region(7,8)==Rect2(96,0,32,32),"Heavy block damage uses the dense source crack frame")
	else:t.check(false,"Damage stages use the local crack sheet")
	var tile:=Vector2i(51,23)
	play.player.developer=false;play.world.set_tile(tile,1)
	play.actions.cooldown=0
	var result: Dictionary=play.actions.apply(play.world,play.player,"punch",tile,0)
	t.check(result.accepted and play.world.damage.get(tile,0)>0 and play.world.damage_required.get(tile,0)>1,"A real punch leaves staged crack damage on an unbroken block")
	play.world.set_tile(tile,0)
	t.check(not play.world.damage.has(tile) and not play.world.damage_required.has(tile),"Replacing a block clears its old crack state")
	app.queue_free();await t.process_frame
