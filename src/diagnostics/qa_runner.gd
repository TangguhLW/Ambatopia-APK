extends Node

var app
var report := {"platform": "", "checks": [], "failures": [], "timings_ms": {}}
var start := 0
var finished:=false

func checkpoint(stage: String) -> void:
	app.set_meta("qa_stage",stage)
	var file:=FileAccess.open("user://qa-progress.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"stage":stage,"checks":report.checks.size(),"failures":report.failures,"elapsed_ms":Time.get_ticks_msec()-start}))
	file.close()
	print("QA_STAGE ",stage)

func _exit_tree() -> void:
	if not finished:
		var file:=FileAccess.open("user://qa-interrupted.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"stage":app.get_meta("qa_stage","startup") if is_instance_valid(app) else "app removed","checks":report.checks,"failures":report.failures,"elapsed_ms":Time.get_ticks_msec()-start}))
		file.close()

func record(condition: bool, label: String) -> void:
	report.checks.append(label)
	if not condition:
		report.failures.append(label)

func snapshot(name: String) -> void:
	checkpoint("snapshot:"+name)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://qa-" + name + ".png")

func click_item_card(card: Control) -> void:
	var pointer: Vector2=get_viewport().get_screen_transform()*card.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new()
	motion.position=pointer;motion.global_position=pointer
	Input.parse_input_event(motion)
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=pointer;event.global_position=pointer
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		Input.parse_input_event(event)
	await get_tree().create_timer(0.07).timeout

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	start = Time.get_ticks_msec()
	if OS.get_name()=="Windows":DisplayServer.window_set_title("Ambatopia — automated GUI QA")
	checkpoint("start")
	report.platform = OS.get_name()
	report.build=JSON.parse_string(FileAccess.get_file_as_string("res://data/build-info.json")).get("version","")
	report.engine = Engine.get_version_info().string
	report.renderer = "Godot native simulation and UI; packed reference wardrobe"
	report.screen = [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	app.session.store.directory = "user://qa-device-fixtures"
	await get_tree().create_timer(0.3).timeout
	report.timings_ms.menu_from_ready = Time.get_ticks_msec() - start
	await snapshot("menu")
	record(app.audio_feedback.music.playing and app.audio_feedback.music.stream.resource_path.ends_with("main-theme.mp3"),"Supplied opening theme plays in the native menu")
	for button in app.screen.controls.values():
		record(button.caption.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and button.caption.get_rect().get_center().is_equal_approx(button.size/2),"Native menu button caption is centered: "+button.text)
	app.navigate("options")
	await get_tree().process_frame
	record(app.route == "options", "Options opens")
	app.navigate("about")
	await get_tree().process_frame
	record(app.screen.find_child("AboutText", true, false) != null, "About displays")
	app.navigate("login")
	await get_tree().process_frame
	record(app.screen.field != null, "Local profile form opens")
	app.start_local("DeviceQA")
	await get_tree().process_frame
	await snapshot("worlds")
	var world_start := Time.get_ticks_msec()
	var entered: Dictionary = app.enter_world("DEVICEQA")
	await get_tree().process_frame
	report.timings_ms.local_world_entry = Time.get_ticks_msec() - world_start
	record(entered.ok, "Enter local world")
	if not entered.ok:
		finish()
		return
	var play = app.screen
	if OS.get_cmdline_args().has("--qa-wearable-033-only"):
		await wearable_online_033_checks(play)
		finish()
		return
	if OS.get_cmdline_args().has("--qa-wearable-032-only"):
		await wearable_revision_032_checks(play)
		finish()
		return
	if OS.get_cmdline_args().has("--qa-guild-031-only"):
		await guild_revision_031_checks(play)
		finish()
		return
	if OS.get_cmdline_args().has("--qa-outfits-030-only"):
		await outfit_revision_030_checks(play)
		finish()
		return
	if OS.get_cmdline_args().has("--qa-machines-029-only"):
		await machine_revision_029_checks(play)
		finish()
		return
	play.world.create_default("DEVICEQA")
	play.player.position = play.world.spawn_position()
	play.player.velocity = Vector2.ZERO
	play.player.grounded = true
	report.synthetic_world_reset = true
	for frame in 10:
		await get_tree().process_frame
	var crack_tile:=Vector2i(51,23)
	play.world.set_tile(crack_tile,1)
	play.actions.cooldown=0
	var crack_result: Dictionary=play.actions.apply(play.world,play.player,"punch",crack_tile,0)
	for event in crack_result.events:play.receive_event(event)
	record(play.world.damage.get(crack_tile,0)>0 and play.block_cracks.get_size()==Vector2(128,32),"Punched blocks display the verified four-stage source crack sheet")
	await snapshot("block-cracks")
	play.world.set_tile(crack_tile,0)
	play.actions.cooldown=0
	record(not play.world.damage.has(crack_tile),"Removed blocks clear their crack overlay")
	play.world.set_tile(crack_tile,200056)
	for hit in 2:
		play.actions.cooldown=0
		var impact: Dictionary=play.actions.apply(play.world,play.player,"punch",crack_tile,0)
		for event in impact.events:play.receive_event(event)
		if hit==0:record(play.get_meta("last_sfx","")=="glass_hit","Glass impact selects the original glass hit recording")
	record(play.get_meta("last_sfx","")=="punch_glass" and play.world.tile_at(crack_tile)==0,"Glass breaking selects the original shatter recording through real punch events")
	var metal_sound_id:=0
	for source in preload("res://src/game/simulator_catalog.gd").items():
		if int(preload("res://src/game/simulator_catalog.gd").items()[source][11])==3:metal_sound_id=200000+int(source);break
	play.receive_event({"type":"punch_started","tile":crack_tile,"item_id":metal_sound_id})
	record(play.get_meta("last_sfx","")=="metal_hit","Metal impact selects the original metallic hit recording")
	for id in play.MaterialAudio.FILES:record(play.sounds[id].get_length()>0,"Material audio is present in the Windows export: "+id)
	play.actions.cooldown=0
	record(play.avatar.eyelid_region(0)==Rect2(0,128,32,32),"Exported avatar composites the source upper eyelid strip")
	var old_position: Vector2 = play.player.position
	play.hud.route_touch(0, play.hud.right.get_global_rect().get_center(), true)
	play.hud.route_touch(1, play.hud.jump.get_global_rect().get_center(), true)
	for frame in 18:
		await get_tree().physics_frame
	report.touch_displacement = [play.player.position.x-old_position.x,play.player.position.y-old_position.y]
	record(play.player.position.x > old_position.x + 8, "Touch movement advances player")
	record(play.player.position.y < old_position.y - 10, "Simultaneous touch jump works")
	play.hud.route_touch(0, Vector2.ZERO, false)
	play.hud.route_touch(1, Vector2.ZERO, false)
	play.cancel_input()
	await get_tree().create_timer(0.9).timeout
	record(play.input.sample().axis == 0, "Released touch stops movement")
	var before: PackedInt32Array = play.world.foreground.duplicate()
	play.select_action("place", 1)
	play.hud.route_touch(2, play.hud.punch.get_global_rect().get_center(), true)
	await get_tree().create_timer(0.1).timeout
	record(play.player.punch_time > 0, "Touch fist animates")
	record(before == play.world.foreground, "Touch fist with block selected does not place")
	play.hud.route_touch(2, Vector2.ZERO, false)
	play.toggle_chat()
	var chat_position: Vector2 = play.chat.position
	play.player.punch_time = play.player.PUNCH_DURATION
	await get_tree().process_frame
	record(play.chat.position == chat_position, "Chat layout stays fixed during punch")
	var fist_geometry=play.avatar.punch_geometry(0.1,Vector2.RIGHT)
	record(fist_geometry.source==Rect2(180,0,20,48) and play.avatar.arm_geometry(true).source.size==Vector2(6,10),"Exported avatar uses recovered fist column and cropped arm geometry")
	await snapshot("punch")
	play.chat.text_submitted.emit("Hello from Android QA")
	record(play.bubble_time > 0, "Local speech bubble starts")
	play.toggle_inventory()
	play.player.equipment.shirt = 1
	var catalog = preload("res://src/game/item_catalog.gd")
	record(catalog.entries().size() == 16434,"Export contains full version27 metadata index")
	play.inventory.mode = "clothes"
	play.inventory.supported_filter.button_pressed = true
	play.inventory.rebuild()
	record(play.inventory.entries.size() >= 1000 and play.inventory.grid.get_child_count() <= 144,"Wardrobe virtualizes the full equipment list")
	play.inventory.inspect_item(34)
	play.inventory.activate_item(98,1000)
	play.inventory.activate_item(98,1200)
	record(play.player.catalog_equipment.get("hand",-1)==98,"Double tap wears a supported item")
	play.inventory.activate_item(98,2000)
	play.inventory.activate_item(98,2200)
	record(play.player.catalog_equipment.get("hand",-1)!=98,"Double tap removes a worn item")
	play.inventory.inspect_item(34)
	var clicks_before: int = app.audio_feedback.click_count
	play.inventory.save_set.pressed.emit()
	record(is_instance_valid(play.modal) and play.modal.name=="OutfitPanel","Wardrobe footer opens the new outfit manager")
	play.close_modal(func():play.toggle_inventory())
	await get_tree().create_timer(0.6).timeout
	play.inventory.mode="clothes";play.inventory.rebuild();play.inventory.inspect_item(34)
	play.inventory.catalog_equip_requested.emit(play.inventory.selected)
	record(app.audio_feedback.click_count > clicks_before and app.audio_feedback.voice.stream.get_length()>0,"Button click sound is connected and has audio data")
	record(play.player.catalog_equipment.get("face") == 34,"Wardrobe Wear equips original item ID")
	play.player.equip_catalog(362)
	record(play.player.can_double_jump(),"Angel Wings activates local double jump")
	report.catalog_texture_cache_count = catalog.texture_cache.size()
	await get_tree().create_timer(0.3).timeout
	record(play.inventory.get_rect().end.y<=play.size.y+1,"Selected wardrobe inspector fits above the device bottom edge")
	var clicked_card: Control=play.inventory.grid.get_child(0)
	var clicked_id: int=clicked_card.get_meta("item_id")
	var worn_before: bool=play.inventory.is_worn(clicked_id)
	await click_item_card(clicked_card);await click_item_card(clicked_card)
	record(is_instance_valid(clicked_card) and play.inventory.is_worn(clicked_id)!=worn_before,"Actual mouse double click toggles wardrobe without replacing the clicked card")
	if is_instance_valid(clicked_card):
		await click_item_card(clicked_card);await click_item_card(clicked_card)
		record(play.inventory.is_worn(clicked_id)==worn_before,"Second actual mouse double click toggles the same wardrobe item back")
	await snapshot("inventory")
	record(play.inventory.entries.size()>=4071,"Device includes all source wardrobe entries including artifacts")
	play.inventory.inspect_item(14232)
	record(preload("res://src/game/item_catalog.gd").summary(play.inventory.selected).get("equip",false),"Special native wardrobe can be worn from the inspector")
	play.inventory.item_scroll.scroll_vertical=int(play.inventory.item_content.custom_minimum_size.y)
	await get_tree().process_frame
	play.inventory.render_window()
	record(play.inventory.window_end==play.inventory.entries.size() and play.inventory.grid.get_child_count()>0,"Device can scroll to the final wardrobe item")
	play.toggle_inventory()
	play.drag_inventory(0,false)
	play.drag_inventory(play.inventory_height()*0.5,false)
	record(is_equal_approx(play.inventory_fraction,0.5),"Backpack tracks partial swipe on device")
	play.drag_inventory(play.inventory_height()*0.6,true)
	await get_tree().create_timer(0.3).timeout
	record(is_equal_approx(play.inventory_fraction,1),"Backpack snaps open smoothly")
	play.drag_inventory(0,false)
	play.drag_inventory(-play.inventory_height()*0.9,true)
	await get_tree().create_timer(0.3).timeout
	record(not is_instance_valid(play.inventory) and not play.input.text_focus,"Backpack swipe closes and releases player controls")
	var handle_point: Vector2=play.hud.inventory_drawer.get_global_rect().get_center()
	var to_screen: Transform2D=get_viewport().get_screen_transform()
	report.drawer_touch_probe={"scale_x":to_screen.x.x,"scale_y":to_screen.y.y}
	var finger=InputEventScreenTouch.new();finger.index=15;finger.position=to_screen*handle_point;finger.pressed=true
	Input.parse_input_event(finger)
	await get_tree().process_frame
	report.drawer_touch_probe.binding_after_press=play.hud.inventory_touch
	var end_point: Vector2=handle_point-Vector2(0,play.inventory_height()*0.55)
	for step in range(1,9):
		var drag=InputEventScreenDrag.new();drag.index=15;drag.position=to_screen*handle_point.lerp(end_point,step/8.0);drag.relative=to_screen.basis_xform(Vector2(0,-play.inventory_height()*0.55/8))
		Input.parse_input_event(drag)
		await get_tree().process_frame
	finger=InputEventScreenTouch.new();finger.index=15;finger.position=to_screen*end_point;finger.pressed=false
	Input.parse_input_event(finger)
	await get_tree().create_timer(0.3).timeout
	report.drawer_touch_probe.final_fraction=play.inventory_fraction
	record(is_instance_valid(play.inventory) and play.inventory_fraction>0.99,"Backpack opens through actual Godot touch-event dispatch")
	if is_instance_valid(play.inventory):
		record(play.inventory.has_meta("category_rail") and play.inventory.grid.get_child(0).find_child("ItemName",true,false)!=null,"Exported wardrobe contains category rail and named cards")
		play.toggle_inventory();await get_tree().create_timer(0.3).timeout
	var saved_outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var saved_legacy: Dictionary=play.player.equipment.duplicate()
	for id in [46,34,36,48,40,156]:
		play.player.equip_catalog(id)
	await get_tree().process_frame
	await get_tree().process_frame
	var fixture_player=preload("res://src/game/player_state.gd").new()
	fixture_player.grounded=false;fixture_player.velocity.y=80;fixture_player.catalog_equipment={"hand":14238}
	var fixture_renderer=preload("res://src/game/special_wardrobe.gd").new()
	var fixture_particles=preload("res://src/game/wardrobe_particles.gd").new()
	for step in 30:
		fixture_renderer.update(fixture_player,1.0/60,0,0,0,0);fixture_particles.update(fixture_player,fixture_renderer,1.0/60)
	record(fixture_particles.particles.any(func(p):return p.name=="fall_heartSparkle"),"Exported Lace Parasol emits its own falling heart sprites")
	var wardrobe=preload("res://src/game/web_wardrobe.gd")
	record(wardrobe.textures.has(wardrobe.definition(46).bk) and wardrobe.textures.has(wardrobe.definition(34).bk) and wardrobe.commands(wardrobe.definition(40),0).size()==2,"Device renders reference headwear, facewear and both separate shoe layers")
	record(wardrobe.textures.size()<=wardrobe.CACHE_LIMIT,"Reference wardrobe texture cache stays bounded")
	record(play.avatar.special_wardrobe.hidden_parts.has("footA") and play.avatar.special_wardrobe.hidden_parts.has("footB"),"Exported ordinary footwear hides the bare source feet")
	await snapshot("wardrobe-slots")
	for special_id in [14192,14232,14234,14262,14294,15188,15416,15576]:
		record(play.player.equip_catalog(special_id),"Device equips recovered special costume "+str(special_id))
	play.player.catalog_equipment={"shirt":15576,"back":15416,"hat":15188}
	await get_tree().create_timer(0.3).timeout
	await snapshot("special-costume")
	play.player.catalog_equipment=saved_outfit
	play.player.equipment=saved_legacy
	var touch_one := InputEventScreenTouch.new()
	touch_one.index = 7
	touch_one.position = Vector2(300,150)
	touch_one.pressed = true
	play._gui_input(touch_one)
	var touch_two := InputEventScreenTouch.new()
	touch_two.index = 8
	touch_two.position = Vector2(400,150)
	touch_two.pressed = true
	play._gui_input(touch_two)
	var spread := InputEventScreenDrag.new()
	spread.index = 8
	spread.position = Vector2(450,150)
	play._gui_input(spread)
	record(play.zoom>1.2,"Two-finger pinch changes world zoom")
	touch_one.pressed = false
	touch_two.pressed = false
	play._gui_input(touch_one)
	play._gui_input(touch_two)
	record(not play.touch_tap_pending,"Pinch release does not place or punch a block")
	play.set_zoom(1)
	await item_checks(play)
	await snapshot("world")
	var frame_times: Array[float] = []
	play.frame_probe.enabled=true
	play.avatar.frame_probe.enabled=true
	play.backdrop.frame_probe.enabled=true
	for i in 120:
		var frame_start := Time.get_ticks_usec()
		await get_tree().process_frame
		frame_times.append((Time.get_ticks_usec() - frame_start) / 1000.0)
	frame_times.sort()
	report.timings_ms.frame_p50 = frame_times[60]
	report.timings_ms.frame_p95 = frame_times[114]
	report.profile={"world":play.frame_probe.totals.duplicate(true),"avatar":play.avatar.frame_probe.totals.duplicate(true),"weather":play.backdrop.frame_probe.totals.duplicate(true),"particles":play.avatar.native_renderer.particles.size(),"source_particles":play.avatar.source_particles.particles.size(),"weather_key":play.world.weather,"outfit":play.player.catalog_equipment.duplicate(),"drops":play.world.drops.size(),"resolution":[play.size.x,play.size.y]}
	play.frame_probe.enabled=false
	play.avatar.frame_probe.enabled=false
	play.backdrop.frame_probe.enabled=false
	report.static_memory_bytes = OS.get_static_memory_usage()
	await measure_effect_scenarios(play)
	checkpoint("source-effects")
	await source_effect_checks(play)
	await terrain_heat_checks(play)
	await source_revision_023_checks(play)
	await ride_revision_024_checks(play)
	await pet_revision_025_checks(play)
	await inventory_revision_026_checks(play)
	await wardrobe_revision_027_checks(play)
	await machine_revision_028_checks(play)
	await machine_revision_029_checks(play)
	await outfit_revision_030_checks(play)
	await guild_revision_031_checks(play)
	checkpoint("wearables-032-033")
	await wearable_revision_032_checks(play)
	await wearable_online_033_checks(play)
	record(app.session.save().ok, "World saves locally")
	play.exit_world()
	record(app.route == "worlds", "Exit returns to world chooser")
	app.enter_world("DEVICEQA")
	record(app.session.player.equipment.shirt == 1, "Outfit persists after re-entry")
	record(app.session.player.catalog_equipment.get("face") == 34,"Catalog outfit survives exported save/re-entry")
	app.go_back()
	record(app.screen.modal != null, "Android Back opens world menu")
	app.go_back()
	record(app.screen.modal == null, "Android Back closes world menu")
	if app.get_meta("qa_network",false) or OS.get_cmdline_args().has("--qa-network"):
		await shared_checks()
	if FileAccess.file_exists("user://qa-auth.json"):
		await authenticated_checks()
	finish()

func source_effect_checks(play) -> void:
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var position: Vector2=play.player.position
	play.player.catalog_equipment={"hair":1444,"hand":5480,"artifact":5078}
	await get_tree().create_timer(0.7).timeout
	var frames: Array=[]
	for i in 120:
		var stamp:=Time.get_ticks_usec()
		await get_tree().process_frame
		frames.append((Time.get_ticks_usec()-stamp)/1000.0)
	frames.sort()
	report.source_effect_frame_p95_ms=frames[114]
	record(float(frames[114])<=20,"Source hair particles and animated Globox meet the Windows frame budget")
	record(play.avatar.legacy_particles.particles.any(func(p):return p.item==1444),"Frosty Hair runs its extracted snowflake particle program in the export")
	record(not play.avatar.ancestral_particles.particles.is_empty(),"Ancestral emits its typed source sprites and native parameter curves")
	await snapshot("ancestral-wisdom")
	record(not play.avatar.item_tracks.pet_for(play.player).is_empty(),"Exported Rayman resolves Globox animation and source texture")
	play.player.item_options.pet_5480=false
	record(play.avatar.item_tracks.pet_for(play.player).is_empty(),"Globox visibility switches off without removing the fist")
	play.player.item_options.pet_5480=true
	play.show_menu()
	record(play.modal.find_children("*","CheckButton",true,false).any(func(button):return button.text=="Show equipped pet"),"Equipped-pet toggle is available in the world menu")
	play.show_menu()
	play.player.position=Vector2(9*32+16,10*32+32)
	play.player.velocity=Vector2.ZERO
	play.world.set_tile(Vector2i(9,11),2)
	for x in [10,11,12]:play.world.set_tile(Vector2i(x,10),1)
	play.input.press("punch")
	await get_tree().create_timer(1.2).timeout
	record(play.player.rayman_level>=2 and play.player.rayman_charge>0,"Holding the actual punch control charges Rayman")
	await snapshot("rayman-charge")
	play.input.release("punch")
	await get_tree().process_frame
	await get_tree().process_frame
	await snapshot("rayman-fire")
	record(play.player.rayman_fire>0,"Releasing the actual punch control launches the source fist")
	play.cancel_input()
	play.player.position=position
	var tile:=Vector2i((position/32).floor())+Vector2i(2,-1)
	play.world.set_tile(tile,202590)
	await get_tree().create_timer(0.4).timeout
	var rebuilds: int=play.terrain_layer.rebuild_count
	var color=play.terrain_renderer.rainbow(Time.get_ticks_msec()/1000.0,tile)
	await snapshot("shifty-start")
	await get_tree().create_timer(0.8).timeout
	await snapshot("shifty-changed")
	record(not color.is_equal_approx(play.terrain_renderer.rainbow(Time.get_ticks_msec()/1000.0,tile)),"Shifty hue changes while the block stays placed")
	record(play.terrain_layer.rebuild_count==rebuilds,"Shifty animation retains static terrain chunks")
	play.world.set_tile(tile,0)
	play.player.catalog_equipment=outfit
	play.player.rayman_level=0;play.player.rayman_charge=0;play.player.rayman_fire=0
	play.actions.cooldown=0

func wearable_online_033_checks(play) -> void:
	var saved: Dictionary=play.player.catalog_equipment.duplicate()
	var saved_legacy: Dictionary=play.player.equipment.duplicate()
	var saved_options: Dictionary=play.player.item_options.duplicate()
	var saved_skin: int=play.player.skin_index
	var saved_position: Vector2=play.player.position
	var old_network=app.network
	var client=preload("res://src/network/client.gd").new()
	client.id=1;app.network=client
	play.player.reset_appearance()
	for id in [5264,6064,1740]:play.player.equip_catalog(id)
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	play.player.item_options={"pet_5480":false}
	var peer={"id":2,"name":"OnlineVisualQA","x":play.player.position.x+90,"y":play.player.position.y,"vx":180,"vy":0,"facing":1,"grounded":true,"punch":0,"skin":play.player.skin_index,"equipment":outfit.duplicate(),"item_options":{"pet_5480":false}}
	play.receive_shared({"type":"snapshot","players":[{"id":1,"equipment":{},"x":play.player.position.x,"y":play.player.position.y},peer]})
	record(play.player.catalog_equipment==outfit,"Stale self snapshot cannot undo a newly equipped outfit")
	var remote=play.remote_players[2]
	record(remote.avatar.get_script()==play.avatar.get_script(),"Online and offline players share the exact native avatar renderer")
	record(remote.state.catalog_equipment==outfit and remote.state.item_options==play.player.item_options,"Remote renderer receives the same outfit and cosmetic switches")
	record(remote.state.abilities()==play.player.abilities(),"Online equipment resolves the same item effects and buffs")
	var elapsed:=0.0
	play.input.press("right")
	var timings: Array=[]
	for i in 180:
		var started:=Time.get_ticks_usec()
		await get_tree().process_frame
		timings.append((Time.get_ticks_usec()-started)/1000.0)
		if i==30:
			record(play.avatar.spirit_shadow.capture!=null,"Spirit Guide captures the actual equipped sprite on the GPU")
			record(not play.avatar.spirit_shadow.traces(play.player).is_empty(),"Spirit Guide silhouette echoes follow movement")
			await snapshot("wearable-033-spirit-online")
		elapsed+=float(timings[-1])
	play.input.release("right")
	timings.sort()
	report.wearable_033_performance={"frames":timings.size(),"fps":timings.size()*1000/maxf(1,elapsed),"p95_ms":timings[int(timings.size()*0.95)],"local_and_remote":true}
	record(play.avatar.spirit_shadow.history.size()<=24,"Shadow history stays bounded while effects are active")
	record(play.avatar.spirit_shadow.silhouette.shadow_capture and play.avatar.spirit_shadow.silhouette.spirit_shadow==null,"Silhouette capture cannot recursively create shadows or particle layers")
	play.toggle_inventory();await get_tree().create_timer(0.4).timeout
	record(is_instance_valid(play.inventory),"The same native inventory opens with online player presentation")
	await snapshot("wearable-033-online-inventory")
	play.toggle_inventory()
	play.receive_shared({"type":"snapshot","players":[]})
	app.network=old_network;client.free()
	play.player.catalog_equipment=saved;play.player.equipment=saved_legacy
	play.player.item_options=saved_options;play.player.skin_index=saved_skin
	play.player.position=saved_position;play.player.velocity=Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	record(play.avatar.spirit_shadow.history.is_empty(),"Removing Spirit Guide expires all silhouettes")

func wearable_revision_032_checks(play) -> void:
	if is_instance_valid(play.modal):play.close_modal();await get_tree().create_timer(0.3).timeout
	if is_instance_valid(play.inventory):play.toggle_inventory()
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var legacy: Dictionary=play.player.equipment.duplicate()
	var at: Vector2=play.player.position
	var rows: Array=[]
	for id in [5264,6064,1740,4988]:
		checkpoint("wearable-032-start:"+str(id))
		play.player.reset_appearance();play.player.equip_catalog(id)
		play.player.position=at;play.player.velocity=Vector2.ZERO
		await get_tree().create_timer(0.25).timeout
		var before: Vector2=play.player.position
		play.input.press("right")
		await get_tree().create_timer(0.45).timeout
		play.input.release("right")
		play.update_presentation()
		await snapshot("wearable-032-"+str(id))
		var lift: float=play.avatar.body_lift(play.player)
		var fx: int=play.avatar.ancestral_particles.particles.filter(func(row):return int(row.item)==id).size()
		var lp: int=play.avatar.legacy_particles.particles.filter(func(row):return int(row.item)==id).size()
		rows.append({"item":id,"travel":play.player.position.x-before.x,"speed_multiplier":play.player.speed_multiplier(),"lift":lift,"typed_particles":fx,"legacy_particles":lp})
		if id in [5264,1740,4988]:record(play.player.speed_multiplier()>1 and play.player.position.x-before.x>45,"Equipped wearable applies movement speed: "+str(id))
		if id==5264:record(fx>0,"Exported Neon Nerves emits its original rainbow trail")
		if id==4988:record(lp>0,"Exported Speed Medallion emits lightning rather than a generic trail")
		if id in [6064,1740]:record(lift<0 and absf(play.avatar.position.y-play.to_screen(play.player.position+Vector2(0,lift)).y)<1,"Hover pose lifts the whole equipped avatar without moving its collision body: "+str(id))
		play.player.catalog_equipment.clear()
		record(play.player.speed_multiplier()==1 and play.avatar.body_lift(play.player)==0,"Unequip clears speed and hover: "+str(id))
	play.player.reset_appearance()
	for id in [5264,6064,1740]:play.player.equip_catalog(id)
	play.player.position=at
	play.input.press("right")
	var frames: Array=[]
	for i in 180:
		var frame_start:=Time.get_ticks_usec();await get_tree().process_frame
		frames.append((Time.get_ticks_usec()-frame_start)/1000.0)
	play.input.release("right")
	frames.sort();var total:=0.0
	for frame in frames:total+=float(frame)
	report.wearable_032_performance={"frames":frames.size(),"fps":frames.size()*1000/maxf(1,total),"p95_ms":frames[int(frames.size()*0.95)]}
	record(report.wearable_032_performance.p95_ms<20,"Combined rainbow, hover and StarBoard effects meet Windows frame budget")
	play.player.reset_appearance();play.player.equip_catalog(5480)
	await get_tree().create_timer(0.3).timeout
	record(not play.avatar.item_tracks.pet_for(play.player).is_empty(),"Front pet layer retains original Rayman pet animation")
	play.avatar.set_process(false)
	play.avatar.item_tracks.pet_motion.position=play.player.position
	play.avatar.item_tracks.pet_motion.scale_in=1
	play.avatar.queue_redraw()
	await snapshot("wearable-032-front-pet")
	play.avatar.set_process(true)
	report.wearable_032=rows
	play.player.catalog_equipment=outfit;play.player.equipment=legacy;play.player.position=at;play.player.velocity=Vector2.ZERO
	play.update_presentation()

func guild_revision_031_checks(play) -> void:
	if is_instance_valid(play.modal):play.close_modal();await get_tree().create_timer(0.3).timeout
	if is_instance_valid(play.inventory):play.toggle_inventory()
	var saved: Dictionary=play.world.serialize().duplicate(true)
	var position: Vector2=play.player.position
	var Guild=preload("res://src/game/guild_weather.gd")
	play.world.create_default("GUILD031")
	play.player.position=Vector2(48*32+16,24*32);play.player.velocity=Vector2.ZERO
	var lock_tile:=Vector2i(47,23);var machine:=Vector2i(49,23)
	play.world.set_tile(lock_tile,0);play.actions.cooldown=0
	var result: Dictionary=play.actions.apply(play.world,play.player,"place",lock_tile,105814)
	for event in result.events:play.receive_event(event)
	record(result.accepted and not Guild.record(play.world).is_empty(),"Actual offline Guild Lock placement registers world ownership")
	play.show_item_panel(lock_tile);await get_tree().process_frame
	var fg=play.modal.find_child("GuildForegroundPicker",true,false)
	var bg=play.modal.find_child("GuildBackgroundPicker",true,false)
	record(fg!=null and bg!=null,"Guild Lock exposes foreground/background mascot selectors")
	if fg!=null:fg.select(fg.get_item_index(22))
	if bg!=null:bg.select(bg.get_item_index(14))
	await RenderingServer.frame_post_draw
	var save=play.modal.find_child("SaveGuildMascot",true,false)
	if save!=null:await click_item_card(save)
	report.guild_save_probe={"mascot":Guild.mascot(play.world),"foreground":fg.get_selected_id(),"background":bg.get_selected_id(),"extras":play.world.extras.duplicate(true)}
	record(Guild.mascot(play.world).get("mascot_fg")==22 and Guild.mascot(play.world).get("mascot_bg")==14,"Guild mascot save button applies its selected actual item layers")
	await snapshot("guild-031-mascot")
	play.close_modal();await get_tree().create_timer(0.3).timeout
	play.world.set_tile(machine,0);play.actions.cooldown=0
	result=play.actions.apply(play.world,play.player,"place",machine,206280)
	for event in result.events:play.receive_event(event)
	record(result.accepted,"Guild weather places through normal gameplay in a Guild-Locked world")
	play.show_item_panel(machine);await get_tree().process_frame
	var gravity=play.modal.find_child("GuildGravity",true,false)
	var spin=play.modal.find_child("GuildSpin",true,false)
	var invert=play.modal.find_child("GuildInvert",true,false)
	record(gravity!=null and spin!=null and invert!=null,"Guild weather wrench panel matches reference control names")
	var switches=play.modal.find_children("*","Button",true,false).filter(func(button):return button.text=="Switch On / Off")
	if not switches.is_empty():await click_item_card(switches[0])
	record(play.world.weather=="guild","Actual weather switch activates guild mascot rain")
	await snapshot("guild-031-controls")
	play.close_modal();await get_tree().create_timer(0.3).timeout
	play.update_presentation();await get_tree().process_frame
	record(play.guild_overlay.mouse_filter==Control.MOUSE_FILTER_IGNORE and play.guild_overlay.get_index()>play.avatar.get_index() and play.guild_overlay.get_index()<play.hud.get_index(),"Guild mascot rain overlays world/player sprites while leaving HUD input unobstructed")
	record(play.backdrop.weather_parameters.get("mascot_fg")==22,"Rendered weather follows the Guild Lock mascot")
	await snapshot("guild-031-rain")
	var frames: Array=[]
	for i in 240:
		var start_frame:=Time.get_ticks_usec();await get_tree().process_frame
		frames.append((Time.get_ticks_usec()-start_frame)/1000.0)
	frames.sort()
	var total:=0.0
	for duration in frames:total+=float(duration)
	report.guild_031={"samples":frames.size(),"fps":frames.size()*1000/maxf(total,1),"frame_p95_ms":frames[int(frames.size()*0.95)],"particle_count":Guild.particles(play.size,1.0,play.backdrop.weather_parameters,false).size()}
	record(report.guild_031.frame_p95_ms<=20,"Guild mascot rain meets measured Windows frame budget")
	play.show_item_panel(machine);await get_tree().process_frame
	gravity=play.modal.find_child("GuildGravity",true,false);spin=play.modal.find_child("GuildSpin",true,false);invert=play.modal.find_child("GuildInvert",true,false)
	gravity.value=-50;spin.button_pressed=true;invert.button_pressed=true
	await click_item_card(play.modal.find_child("ApplyGuildWeather",true,false))
	record(play.item_runtime.state(play.world,machine).get("gravity")==-50 and play.item_runtime.state(play.world,machine).get("spin",false),"Guild settings button saves reverse gravity, spin and inverse sky")
	play.close_modal();await get_tree().create_timer(0.3).timeout
	await snapshot("guild-031-inverted")
	var copy=preload("res://src/game/world_state.gd").new()
	record(copy.restore(play.world.serialize()) and Guild.mascot(copy).get("mascot_fg")==22,"Exported world save retains Guild Lock mascot metadata")
	play.perform_item(machine,"activate")
	record(play.world.weather=="sunny","Switching Guild weather off restores the original sky")
	play.world.restore(saved);play.player.position=position;play.player.velocity=Vector2.ZERO
	play.terrain_layer.invalidate();play.update_presentation()

func outfit_revision_030_checks(play) -> void:
	if is_instance_valid(play.modal):play.close_modal();await get_tree().create_timer(0.3).timeout
	if is_instance_valid(play.inventory):play.toggle_inventory()
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var legacy: Dictionary=play.player.equipment.duplicate()
	var skin: int=play.player.skin_index
	var options: Dictionary=play.player.item_options.duplicate(true)
	play.player.reset_appearance()
	var count: int=int(play.sfx_counts.get("wear",0))
	play.equip_outfit_item(34)
	record(int(play.sfx_counts.get("wear",0))==count+1 and play.get_meta("last_sfx")=="audio/change_clothes.wav","Equipping clothing plays the packed original change-clothes recording once")
	play.equip_outfit_item(34);play.equip_outfit_item(2);play.unequip_outfit_item("back")
	record(int(play.sfx_counts.get("wear",0))==count+1,"Invalid, repeated and empty-slot equipment actions do not trigger wear audio")
	play.unequip_outfit_item("face")
	record(int(play.sfx_counts.get("wear",0))==count+2,"Unequip plays the original recording once")
	play.toggle_inventory();await get_tree().create_timer(0.3).timeout
	play.inventory.mode="clothes";play.inventory.rebuild()
	play.inventory.activate_item(34,2000);play.inventory.activate_item(34,2200)
	record(play.player.catalog_equipment.get("face")==34 and int(play.sfx_counts.get("wear",0))==count+3,"Backpack double-click equips with wear audio")
	await get_tree().process_frame
	report.outfit_button_probe={"rect":str(play.inventory.save_set.get_global_rect()),"inventory":str(play.inventory.get_global_rect()),"viewport":str(get_viewport().get_visible_rect()),"modal":str(play.modal)}
	await snapshot("outfits-030-before-open")
	await click_item_card(play.inventory.save_set)
	await get_tree().create_timer(0.3).timeout
	record(is_instance_valid(play.modal) and play.modal.name=="OutfitPanel","Wardrobe Outfits button opens the native three-slot panel")
	if not is_instance_valid(play.modal):return
	for index in range(1,4):
		var save=play.modal.find_child("SaveOutfit"+str(index),true,false)
		var load_button=play.modal.find_child("LoadOutfit"+str(index),true,false)
		record(save!=null and load_button!=null,"Save and Load actions exist for numbered outfit "+str(index))
		if index==2:play.equip_outfit_item(362)
		if index==3:play.player.reset_appearance()
		if save!=null:await click_item_card(save)
		record(load_button!=null and not load_button.disabled and app.session.outfit_slot_info(index).ok,"Saving updates the available Load action for slot "+str(index))
	await snapshot("outfits-030-slots")
	await click_item_card(play.modal.find_child("LoadOutfit1",true,false))
	record(play.player.catalog_equipment=={"face":34},"Native Load outfit 1 replaces the full currently worn set")
	await click_item_card(play.modal.find_child("LoadOutfit2",true,false))
	record(play.player.catalog_equipment=={"face":34,"back":362},"Native Load outfit 2 restores its own independent set")
	await click_item_card(play.modal.find_child("LoadOutfit3",true,false))
	record(play.player.catalog_equipment.is_empty(),"Native Load outfit 3 can remove all worn items")
	var old_window: Vector2i=get_window().size
	get_window().size=Vector2i(520,780);await get_tree().create_timer(0.3).timeout
	var bounds: Rect2=play.modal.get_global_rect()
	record(play.modal.find_children("*","Button",true,false).all(func(button):return bounds.encloses(button.get_global_rect())),"Three-slot panel buttons fit the narrow Windows window")
	await snapshot("outfits-030-narrow")
	get_window().size=old_window;await get_tree().create_timer(0.3).timeout
	play.close_modal();await get_tree().create_timer(0.3).timeout
	var saved_world: Dictionary=play.world.serialize().duplicate(true)
	var terrain=play.terrain_renderer
	play.world.create_default("ANIMATION030")
	for index in 4:
		var id: int=[13146,13364,4380,932][index]
		var at:=Vector2i(47+index,23)
		play.world.set_tile(at,200000+id);play.world.extras[str(at.y*100+at.x)]={"enabled":true}
		var first=terrain.animation_texture(play.world,at,id+200000,0)
		var second=terrain.animation_texture(play.world,at,id+200000,300)
		record(first!=null and second!=null and first.region!=second.region,"Exported source machine changes its actual atlas frame: "+str(id))
	play.update_presentation();play.queue_redraw();await get_tree().process_frame
	record(play.terrain_layer.chunks.values().any(func(chunk):return Vector2i(47,23) in chunk.animated_tiles),"Source machine animation uses the visible dynamic terrain pass")
	await snapshot("machines-030-frames")
	play.world.restore(saved_world);play.terrain_layer.invalidate()
	play.player.catalog_equipment=outfit;play.player.equipment=legacy
	play.player.skin_index=skin;play.player.item_options=options;play.sync_outfit()

func wardrobe_revision_027_checks(play) -> void:
	play.toggle_inventory();await get_tree().create_timer(0.3).timeout
	var bag=play.inventory
	bag.mode="clothes";bag.search.text="Shades";bag.rebuild()
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	play.player.equip_catalog(34);play.sync_outfit()
	var stored: Dictionary=app.session.outfits.store.load_slot(app.session.outfits.slot(app.session.outfit_profile))
	record(stored.ok and stored.data.catalog_equipment.get("face")==34,"Exported Save set writes the actual current wardrobe")
	play.player.unequip_catalog("face")
	record(app.session.restore_set(app.session.outfit_profile).ok and play.player.catalog_equipment.get("face")==34,"Exported set restoration applies validated saved outfit")
	record(bag.save_set.text=="Outfits" and bag.save_set.visible and bag.save_set.get_global_rect().end.x<=bag.get_global_rect().end.x+1,"Single Outfits action fits inside the wardrobe footer")
	await snapshot("wardrobe-027-footer")
	bag.mode="simulator";bag.search.text="Shades Seed";bag.rebuild()
	await get_tree().process_frame
	record(bag.grid.get_child_count()>0 and bag.grid.get_child(0).get_node_or_null("SeedResult")!=null,"Exported clothing seed shows the grown clothing item")
	bag.inspect_item(200035)
	record("Grows: Shades" in bag.detail.text,"Exported seed inspector names the harvest")
	await snapshot("wardrobe-027-seed")
	play.toggle_inventory();await get_tree().create_timer(0.25).timeout
	play.set_process(false)
	var changed: Array=[]
	for index in 3:
		var tile:=Vector2i(46+index*2,23)
		changed.append({"tile":tile,"old":play.world.tile_at(tile)})
		var id: int=[35,3,1095][index]
		play.world.set_tile(tile,200000+id);play.item_runtime.planted(play.world,tile,id)
		var data: Dictionary=play.item_runtime.state(play.world,tile)
		data.planted=play.item_runtime.now()-data.duration;data.fruit=3
	play.update_presentation();play.queue_redraw()
	record(changed.all(func(entry):return play.terrain_layer.chunks.values().any(func(chunk):return entry.tile in chunk.dynamic_tiles)),"Exported mature seed trees enter the visible dynamic render pass")
	await get_tree().create_timer(0.15).timeout
	await snapshot("wardrobe-027-trees")
	for entry in changed:
		play.world.set_tile(entry.tile,entry.old);play.world.extras.erase(play.item_runtime.key(play.world,entry.tile))
	play.player.catalog_equipment=outfit;play.sync_outfit();play.set_process(true)

func inventory_revision_026_checks(play) -> void:
	var Icons=preload("res://src/game/inventory_icons.gd")
	play.toggle_inventory();await get_tree().create_timer(0.3).timeout
	var bag=play.inventory
	for word in ["Dirt","Lava","Bedrock","World Lock","Rayman"]:
		bag.mode="simulator";bag.category_filter.select(0);bag.search.text=word;bag.rebuild()
		await get_tree().process_frame
		var cards: Array=bag.grid.get_children()
		record(not cards.is_empty(),"Exported backpack finds original icons: "+word)
		for card in cards:
			var icon=card.get_node_or_null("ItemIcon")
			record(icon!=null and icon.texture!=null and icon.texture.get_size()==Vector2(32,32),"Exported item has a complete source-sized icon: "+str(card.get_meta("item_id")))
		await snapshot("inventory-026-"+word.to_lower().replace(" ","-"))
	record(Icons.pages.size()<=Icons.PAGE_LIMIT and Icons.icons.size()<=Icons.ICON_LIMIT,"Exported inventory page/icon caches remain within budget")
	play.toggle_inventory();await get_tree().create_timer(0.25).timeout

func pet_revision_025_checks(play) -> void:
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var origin: Vector2=play.player.position
	var facing: int=play.player.facing
	play.set_process(false)
	report.pets_025=[]
	for id in [870,882,1376,1968,4760,5480,1540,1952,10686,2878]:
		var slot: String=preload("res://src/game/simulator_catalog.gd").slot(id)
		play.player.catalog_equipment={slot:id};play.player.item_options.erase("pet_"+str(id))
		play.player.position=origin;play.player.facing=1;play.player.punch_time=0;play.player.velocity=Vector2.ZERO;play.player.grounded=true
		record(await wait_for(func():return play.avatar.item_tracks.pet_motion.active_id==id,1000),"Exported pet uses the selected item's independent motion: "+str(id))
		var motion=play.avatar.item_tracks.pet_motion
		var times: Array=[]
		for frame in 90:
			play.player.velocity=Vector2(90,0);play.player.position.x+=1.5
			var started:=Time.get_ticks_usec()
			await get_tree().process_frame
			times.append((Time.get_ticks_usec()-started)/1000.0)
		times.sort()
		record(motion.position.is_finite() and motion.history.size()==20,"Exported follow motion stays bounded while walking: "+str(id))
		report.pets_025.append({"item":id,"kind":motion.definition.k,"frame_p95_ms":times[85],"relative_position":[motion.position.x-play.player.position.x,motion.position.y-play.player.position.y]})
		play.player.facing=-1;play.player.velocity=Vector2.ZERO
		if id in [1540,1952,10686]:
			for frame in 720:motion.update(id,motion.definition,play.player,1.0/60)
			if id in [1540,1952]:record(motion.mode>0,"Exported source bird reaches its item-specific perch state: "+str(id))
		play.player.punch_time=0.2;play.player.punch_direction=Vector2(-1,0);play.player.punch_distance=64
		await get_tree().create_timer(0.06).timeout
		await snapshot("pet-"+str(id))
	play.player.catalog_equipment=outfit;play.player.position=origin;play.player.velocity=Vector2.ZERO;play.player.facing=facing;play.player.punch_time=0
	play.set_process(true)

func ride_revision_024_checks(play) -> void:
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var origin: Vector2=play.player.position
	play.set_process(false)
	report.rides_024=[]
	for id in [2048,2064,8488,11012]:
		var slot: String=preload("res://src/game/simulator_catalog.gd").slot(id)
		play.player.catalog_equipment={slot:id};play.player.wrench_selected=false
		play.player.grounded=true;play.player.velocity=Vector2(90,0)
		play.avatar.legacy_particles.particles.clear();play.avatar.legacy_particles.clocks.clear()
		if id==11012:
			play.player.grounded=false;play.player.velocity=Vector2(0,80)
			record(await wait_for(func():return play.avatar.legacy_particles.previous_state==3,1000),"Neptune QA observes the airborne state before landing")
			play.player.grounded=true;play.player.velocity=Vector2.ZERO
			record(await wait_for(func():return play.avatar.legacy_particles.particles.filter(func(p):return int(p.id)==35).size()==10,1000),"Exported Neptune landing makes the original ten-particle burst")
			await snapshot("neptune-landing")
			play.player.velocity=Vector2(90,0)
		var peak:=0;var times: Array=[]
		for frame in 180:
			var started:=Time.get_ticks_usec()
			await get_tree().process_frame
			times.append((Time.get_ticks_usec()-started)/1000.0)
			peak=maxi(peak,play.avatar.legacy_particles.particles.size())
		times.sort()
		report.rides_024.append({"item":id,"peak":peak,"frame_p95_ms":times[171]})
		if id==8488:
			record(peak==0,"Exported Chaos preserves the source's missing-302 guard without generic particles")
			var timing: Dictionary=play.avatar.web_wardrobe.animation_timing(preload("res://src/game/web_wardrobe.gd").definition(id),play.avatar.elapsed)
			record(timing.pose=="stand","Exported Chaos uses its continuously running original glitch sequence")
		else:record(peak>0 and peak<=play.avatar.legacy_particles.LIMIT,"Exported original ride particles emit within budget: "+str(id))
		await snapshot("ride-"+str(id))
	play.player.catalog_equipment=outfit;play.player.position=origin;play.player.velocity=Vector2.ZERO
	play.set_process(true)

func source_revision_023_checks(play) -> void:
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var origin: Vector2=play.player.position
	play.set_process(false)
	report.special_023=[]
	for id in [1672,1824,1876,4260,2420,2574,3074,4988,4880,4946,6756,6782,8370,9422,9716]:
		var slot: String=preload("res://src/game/simulator_catalog.gd").slot(id)
		play.player.catalog_equipment={slot:id};play.player.position=origin
		play.player.grounded=id==8370;play.player.velocity=Vector2(90,0 if id==8370 else -100)
		play.avatar.legacy_particles.particles.clear();play.avatar.legacy_particles.was_grounded=true
		var peak:=0
		for frame in 45:
			await get_tree().process_frame
			peak=maxi(peak,play.avatar.legacy_particles.particles.size())
		report.special_023.append({"item":id,"peak":peak})
		record(peak>0,"Exported source-specific wardrobe emits: "+str(id))
		await snapshot("source-special-"+str(id))
	for id in [1782,4778,6026,4750,1204]:
		play.player.catalog_equipment={"hand":id};play.player.punch_time=0
		for particle in play.avatar.item_tracks.punch_for(play.player).get("P",[]):
			preload("res://src/game/source_effect_assets.gd").texture(str(particle.get("c",[""])[0]))
		await get_tree().process_frame
		play.avatar.item_tracks.previous_punch=0
		play.player.begin_punch(play.player.position+Vector2(52,-16))
		var punch_seen:=false
		for frame in 8:
			await get_tree().process_frame
			punch_seen=punch_seen or not play.avatar.item_tracks.punch_particles.is_empty()
		record(punch_seen,"Exported source punch creates specialized particles: "+str(id))
		await snapshot("source-punch-"+str(id))
	for pair in [[200002,"wood_damage"],[200010,"rock_hit"],[200056,"glass_hit"],[200060,"metal_hit"]]:
		play.receive_event({"type":"punch_started","tile":Vector2i.ZERO,"item_id":pair[0]})
		record(play.get_meta("last_sfx","")==pair[1] and play.sounds[pair[1]].get_length()>0,"Exported material punch routes to a distinct original recording: "+str(pair[0]))
	play.player.catalog_equipment=outfit;play.player.position=origin;play.player.velocity=Vector2.ZERO;play.player.punch_time=0
	play.set_process(true)

func terrain_heat_checks(play) -> void:
	var old_position: Vector2=play.player.position
	var old_velocity: Vector2=play.player.velocity
	var old_equipment: Dictionary=play.player.catalog_equipment.duplicate()
	play.player.catalog_equipment={}
	play.avatar.legacy_particles.particles.clear()
	play.avatar.ancestral_particles.particles.clear()
	var tile:=Vector2i(15,10)
	play.world.set_tile(tile,7)
	play.player.position=Vector2(tile)*32+Vector2(16,24)
	play.player.velocity=Vector2.ZERO;play.player.god_mode=false
	await get_tree().process_frame
	await get_tree().process_frame
	record(play.player.death_time>=0 and play.player.position.distance_to(play.world.spawn_position())>32,"Lava starts the captured death sequence at the contact position")
	await get_tree().create_timer(0.16).timeout
	record(not play.avatar.death_sequence.particles.is_empty(),"The original angel sprites float from the corpse")
	record(play.sfx_counts.get("male_scream",0)>0,"Death plays the original male_scream recording")
	await snapshot("lava-death")
	await get_tree().create_timer(1.1).timeout
	await snapshot("death-floating")
	await get_tree().create_timer(1.4).timeout
	record(play.player.position.distance_to(play.world.spawn_position())<2 and play.sfx_counts.get("teleport",0)>0,"Respawn returns to the white door with the source teleport sound")
	play.player.death_time=-1
	play.player.position=old_position;play.player.velocity=old_velocity
	play.player.burn_time=0;play.player.lava_exposure=0;play.player.lava_cooldown=0
	play.world.set_tile(tile,0)
	var crack:=Vector2i((old_position/32).floor())+Vector2i(1,-1)
	play.world.set_tile(crack,1)
	play.world.register_damage(crack,1,3)
	await snapshot("crack-before-reset")
	play.world.tick_damage(5.1)
	record(not play.world.damage.has(crack) and not play.world.damage_required.has(crack),"Idle crack overlay and block damage both reset after five seconds")
	await snapshot("crack-after-reset")
	play.world.set_tile(crack,0)
	play.player.catalog_equipment=old_equipment

func item_checks(play) -> void:
	var runtime=load("res://src/game/item_runtime.gd").new()
	var origin: Vector2=play.player.position
	var tile:=Vector2i(49,23)
	play.player.position=Vector2(48*32+16,24*32)
	play.world.set_tile(tile,0)
	play.world.extras.erase(runtime.key(play.world,tile))
	play.actions.cooldown=0
	play.select_action("place",200003)
	play.input.target=tile
	play.input.press("interact")
	await get_tree().create_timer(0.15).timeout
	play.input.release("interact")
	record(play.world.tile_at(tile)==200003,"Exported item action plants a real seed")
	play.show_item_panel(tile)
	await get_tree().process_frame
	record(is_instance_valid(play.item_status),"Source item panel opens from world")
	play.perform_item(tile,"grow")
	play.perform_item(tile,"harvest")
	record(play.world.tile_at(tile)==0,"Creative growth and harvest remove mature tree")
	await get_tree().process_frame
	record(not play.player.collected.is_empty() or not play.world.drops.is_empty(),"Harvest yields collectible source items")
	play.show_menu()
	play.world.set_tile(tile,200866)
	runtime.planted(play.world,tile,866)
	play.perform_item(tile,"grow")
	play.perform_item(tile,"harvest")
	record(play.world.tile_at(tile)==200866 and play.world.extras[runtime.key(play.world,tile)].ready>runtime.now(),"Provider production resets its source cooldown")
	play.world.set_tile(tile,202978)
	play.world.extras.erase(runtime.key(play.world,tile))
	play.perform_item(tile,"deposit",{"item":2,"amount":3})
	play.perform_item(tile,"dispense")
	record(play.world.extras[runtime.key(play.world,tile)].stock["2"]==2,"Exported machine stores and dispenses item stock")
	record(play.player.equip_catalog(200156) and play.player.can_double_jump(),"Source wardrobe equips with functional ability")
	var freeze: Dictionary=runtime.use_item(play.world,play.player,tile,274)
	record(freeze.accepted and play.player.speed_multiplier()==0,"Consumable modifies player movement")
	play.player.tick_modifiers(11)
	record(not play.player.modifiers.has("Frozen"),"Consumable modifier expires on device")
	play.world.weather="pop-city"
	await get_tree().create_timer(0.2).timeout
	record(play.backdrop.renderer.complex_scene.models.size()>0,"Complex weather builds live texture layers on device")
	play.show_item_panel(tile)
	await snapshot("items")
	play.show_menu()
	await special_item_checks(play,runtime,tile)
	await automation_checks(play,runtime,tile)
	play.world.weather="sunny"
	play.player.position=origin
	play.select_action("punch",0)

func measure_effect_scenarios(play) -> void:
	var outfit: Dictionary=play.player.catalog_equipment.duplicate()
	var legacy: Dictionary=play.player.equipment.duplicate()
	var weather: String=play.world.weather
	var saved_position: Vector2=play.player.position
	var saved_velocity: Vector2=play.player.velocity
	var saved_grounded: bool=play.player.grounded
	var before: int=play.terrain_layer.rebuild_count
	var chunks_before: int=play.terrain_layer.chunks.size()
	report.effect_scenarios=[]
	for sample in [{"name":"legendbot","equipment":{"shirt":1780},"weather":"sunny"},{"name":"native_costume_particles","equipment":{"back":14232,"hat":14192,"shirt":15576},"weather":"sunny"},{"name":"costume_and_iceage","equipment":{"back":14232,"hat":14192,"shirt":15576},"weather":"iceage"},{"name":"costume_and_rlm","equipment":{"back":14232,"hat":14192,"shirt":15576},"weather":"rlm"},{"name":"advanced_wardrobe_rlm","equipment":{"hand":14238,"neck":14628,"artifact":16360,"back":14232},"weather":"rlm"}]:
		play.player.catalog_equipment=sample.equipment.duplicate()
		play.world.weather=sample.weather
		await get_tree().create_timer(0.6).timeout
		play.frame_probe.totals.clear();play.avatar.frame_probe.totals.clear();play.backdrop.frame_probe.totals.clear()
		play.frame_probe.enabled=true;play.avatar.frame_probe.enabled=true;play.backdrop.frame_probe.enabled=true
		var frames: Array=[]
		var frame_count:=600
		var source_peak:=0
		for i in frame_count:
			if sample.name=="advanced_wardrobe_rlm":
				if i%45==0:play.input.press("jump")
				if i%45==2:play.input.release("jump")
			source_peak=maxi(source_peak,play.avatar.source_particles.particles.size())
			var start_frame:=Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append((Time.get_ticks_usec()-start_frame)/1000.0)
		frames.sort()
		var total_ms:=0.0
		for duration in frames:total_ms+=float(duration)
		report.effect_scenarios.append({"name":sample.name,"frame_p50_ms":frames[int(frame_count/2)],"frame_p95_ms":frames[int(frame_count*.95)],"frame_mean_ms":total_ms/frame_count,"fps":frame_count*1000/maxf(1,total_ms),"frames_over_20ms":frames.filter(func(v):return v>20).size(),"samples":frames.size(),"particles":play.avatar.native_renderer.particles.size(),"source_particles":play.avatar.source_particles.particles.size(),"source_particles_peak":source_peak,"weather_models":play.backdrop.renderer.complex_scene.models.size(),"weather_pixels":[play.backdrop.weather_surface.size.x,play.backdrop.weather_surface.size.y] if play.backdrop.weather_surface!=null else [play.size.x,play.size.y],"cpu_world":play.frame_probe.totals.duplicate(true),"cpu_avatar":play.avatar.frame_probe.totals.duplicate(true),"cpu_weather":play.backdrop.frame_probe.totals.duplicate(true)})
		await snapshot("effects-"+sample.name)
		play.frame_probe.enabled=false;play.avatar.frame_probe.enabled=false;play.backdrop.frame_probe.enabled=false
	var new_chunks: int=play.terrain_layer.chunks.size()-chunks_before
	report.effect_terrain_cache={"rebuilds":play.terrain_layer.rebuild_count-before,"new_chunks":new_chunks}
	record(play.terrain_layer.rebuild_count-before==new_chunks,"Costume effects retain existing terrain draw lists while jumping reveals new chunks")
	record(play.avatar.special_wardrobe.contexts.size()>0,"Exported player uses native special costume render hooks")
	record(report.effect_scenarios.all(func(row):return row.frame_p50_ms<=17.5 and row.frame_p95_ms<=20),"Costume and weather scenarios meet the measured 60 FPS frame budget")
	for id in [1780,15898]:record(play.player.equip_catalog(id),"Special costume is wearable from the real catalog: "+str(id))
	play.player.catalog_equipment=outfit
	play.player.equipment=legacy
	play.world.weather=weather
	play.input.release("jump")
	play.player.position=saved_position;play.player.velocity=saved_velocity;play.player.grounded=saved_grounded

func authenticated_checks() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("user://qa-auth.json"))
	DirAccess.remove_absolute("user://qa-auth.json")
	var login: Dictionary = await app.accounts.authenticate(fixture.name,fixture.password,false)
	record(login.ok,"Exported app logs in to real Supabase fixture through account service")
	if not login.ok:
		return
	app.profile = {"id":login.profile.id,"display_name":login.profile.amba_id}
	app.shared_selection = true
	app.enter_world(fixture.world)
	var connected: bool = await wait_for(func(): return app.network.connected,20000)
	record(connected,"Authenticated exported app enters persistent shared world")
	if connected:
		record(app.screen.player.display_name == fixture.name,"Server verified AmbaID is displayed")
		record(app.accounts.profile.role == "player","Synthetic account has no developer rights")
		app.screen.player.equip_catalog(98)
		app.screen.sync_outfit()
		await get_tree().create_timer(0.6).timeout
		var play=app.screen
		play.select_action("place",200003)
		play.input.target=Vector2i(49,23)
		play.input.press("interact")
		record(await wait_for(func():return play.world.tile_at(Vector2i(49,23))==200003 and play.world.extras.has("2349")),"Authenticated device receives persistent seed metadata")
		play.input.release("interact")
		await get_tree().create_timer(0.3).timeout
		play.perform_item(Vector2i(49,23),"grow")
		await get_tree().create_timer(0.3).timeout
		play.perform_item(Vector2i(49,23),"harvest")
		record(await wait_for(func():return play.world.tile_at(Vector2i(49,23))==0),"Authenticated device harvests a shared tree")
		play.select_action("place",200866)
		play.input.target=Vector2i(51,23)
		play.input.press("interact")
		record(await wait_for(func():return play.world.tile_at(Vector2i(51,23))==200866 and play.world.extras.has("2351")),"Authenticated provider state replicated to device")
		play.input.release("interact")
		play.select_action("punch",0)
		play.player.equip_catalog(200156)
		play.sync_outfit()
		await get_tree().create_timer(0.3).timeout
		await snapshot("authenticated")

func wait_for(predicate: Callable, timeout_ms: int = 12000) -> bool:
	var deadline := Time.get_ticks_msec()+timeout_ms
	while not predicate.call() and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	return predicate.call()

func shared_checks() -> void:
	var own_name := "AndroidQA" if OS.get_name() == "Android" else "WindowsQA"
	var other_name := "WindowsQA" if OS.get_name() == "Android" else "AndroidQA"
	app.network.connect_room("ws://127.0.0.1:4192",own_name,"CROSSQA")
	var connected: bool = await wait_for(func(): return app.network.connected)
	record(connected,"Shared server connection opens")
	if not connected:
		return
	var play = app.screen
	var visible_peer: bool = await wait_for(func(): return play.remote_players.values().any(func(row): return row.state.display_name == other_name),25000)
	record(visible_peer,"Other physical platform appears in shared world")
	if not visible_peer:
		return
	var origin: Vector2 = play.player.position
	var direction_button = play.hud.left if OS.get_name() == "Android" else play.hud.right
	play.hud.route_touch(0,direction_button.get_global_rect().get_center(),true)
	play.hud.route_touch(1,play.hud.jump.get_global_rect().get_center(),true)
	await get_tree().create_timer(0.25).timeout
	play.hud.route_touch(0,Vector2.ZERO,false)
	play.hud.route_touch(1,Vector2.ZERO,false)
	record(absf(play.player.position.x-origin.x)>8,"Predicted shared movement and jump respond")
	app.network.send({"type":"chat","text":"Hello from "+own_name})
	record(await wait_for(func(): return play.bubble == "Hello from "+own_name),"Own chat returns from server")
	record(await wait_for(func(): return play.remote_players.values().any(func(row): return row.bubble == "Hello from "+other_name)),"Other platform chat bubble follows remote player")
	play.toggle_inventory()
	play.inventory.mode = "clothes"
	play.inventory.rebuild()
	play.inventory.inspect_item(34)
	play.inventory.catalog_equip_requested.emit(play.inventory.selected)
	play.toggle_inventory()
	record(await wait_for(func(): return play.remote_players.values().any(func(row): return row.state.catalog_equipment.get("face",-1) == 34)),"Other platform outfit is replicated")
	await get_tree().create_timer(1).timeout
	if OS.get_name() == "Windows":
		play.select_action("place",1)
		play.input.target = Vector2i(50,22)
		play.input.press("interact")
		await get_tree().create_timer(0.35).timeout
		play.input.release("interact")
		play.select_action("punch",0)
		play.input.target = Vector2i(50,22)
		play.input.press("interact")
		await get_tree().create_timer(1).timeout
		play.input.release("interact")
		record(play.sfx_counts.get("punch",0)>0 and play.sfx_counts.get("place",0)>0 and play.sfx_counts.get("break",0)>0,"Shared punch/place/break sound events play")
	else:
		record(await wait_for(func(): return play.shared_tile_updates>=2),"Physical Android receives place and break mutations")
	await snapshot("network")
	report.network_remote_players = play.remote_players.size()
	report.network_sfx = play.sfx_counts
	await get_tree().create_timer(2).timeout

func finish() -> void:
	finished=true
	checkpoint("complete")
	report.elapsed_ms = Time.get_ticks_msec() - start
	var file := FileAccess.open("user://qa-report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("QA_RESULT ", JSON.stringify(report))
	app.screen.hud.status.text = "Device QA: %d checks • %d failures" % [report.checks.size(), report.failures.size()] if app.route == "play" else "QA finished"
	if OS.get_cmdline_args().has("--qa-exit") or OS.get_cmdline_user_args().has("--qa-exit"):
		get_tree().quit(0 if report.failures.is_empty() else 1)

func special_item_checks(play,runtime,tile: Vector2i) -> void:
	play.world.extras.erase(runtime.key(play.world,tile))
	play.world.set_tile(tile,203354)
	play.perform_item(tile,"deposit",{"item":3336,"amount":3})
	play.perform_item(tile,"sew")
	record(play.world.drops.any(func(drop):return int(drop.id)==7030),"Sewing device consumes three bolts and creates recovered clothing")
	play.show_item_panel(tile)
	await get_tree().process_frame
	record(is_instance_valid(play.item_status) and "Silk Bolts" in play.item_status.text,"Specific sewing instructions fit exported item panel")
	play.show_menu()
	play.world.extras.erase(runtime.key(play.world,tile))
	play.world.set_tile(tile,203316)
	runtime.planted(play.world,tile,3316)
	var worm=runtime.state(play.world,tile)
	worm.r=144;worm.g=144;worm.b=144
	var fed=runtime.use_item(play.world,play.player,tile,386)
	record(fed.accepted and worm.r==169 and worm.g==118,"Silkworm uses recovered RGB food effect on device")
	play.world.set_tile(tile,203918)
	play.world.extras.erase(runtime.key(play.world,tile))
	play.player.catalog_equipment={"hand":3932}
	play.actions.cooldown=0
	play.actions.apply(play.world,play.player,"punch",tile,0)
	var fossil=runtime.state(play.world,tile)
	fossil.hits=1
	play.actions.cooldown=0
	play.actions.apply(play.world,play.player,"punch",tile,0)
	record(fossil.get("unearthed",false),"Exported punch action uncovers fossil with Rock Hammer")
	play.player.catalog_equipment={"hand":3934}
	play.actions.cooldown=0
	play.actions.apply(play.world,play.player,"punch",tile,0)
	record(play.world.tile_at(tile)==0 and play.world.drops.any(func(drop):return int(drop.id)==3936),"Exported Rock Chisel extracts actual Fossil")
	play.world.set_tile(tile,204344)
	play.world.extras.erase(runtime.key(play.world,tile))
	runtime.planted(play.world,tile,4344)
	play.perform_item(tile,"configure",{"period":2,"speed":250,"enabled":true})
	runtime.state(play.world,tile).next=0
	runtime.special.tick(runtime,play.world,[],0)
	record(play.world.world_effects.get("projectiles",[]).size()==1,"Configured blaster emits a real projectile in exported build")
	play.show_item_panel(tile)
	await get_tree().process_frame
	record(is_instance_valid(play.item_status) and "Projectiles" in play.item_status.text,"Device blaster panel displays its own settings and limits")
	await snapshot("special-machine")
	play.show_menu()
	play.player.catalog_equipment.clear()
	record(play.player.equip_catalog(14192) and play.player.equip_catalog(14232),"Native renderer wardrobe equips through normal catalog validation")
	play.player.grounded=true
	play.player.velocity=Vector2.ZERO
	await get_tree().create_timer(0.6).timeout
	record(not play.avatar.native_renderer.definition(14192).is_empty(),"Native Fireworks Mohawk animation data loaded in export")
	record(not play.avatar.native_renderer.particles.is_empty(),"Mobile Suit Wings emit their recovered sprite particles on device")
	await snapshot("special-wardrobe")
	play.player.catalog_equipment={"face":34,"back":200156}
	play.world.world_effects.projectiles=[]
	play.world.set_tile(tile,0)
	play.world.extras.erase(runtime.key(play.world,tile))

func automation_checks(play,r,tile: Vector2i) -> void:
	play.player.position=Vector2(48*32+16,24*32)
	play.world.world_effects.clear()
	play.world.extras.erase(r.key(play.world,tile))
	play.world.set_tile(tile,202242);r.planted(play.world,tile,2242)
	play.show_item_panel(tile)
	await get_tree().process_frame
	record(is_instance_valid(play.item_status) and "Nearby Chi" in play.item_status.text,"Crystal panel displays actual nearby and required elemental Chi")
	play.perform_item(tile,"add_crystal",{"item":2242})
	for i in 3:play.perform_item(tile,"add_crystal",{"item":2248})
	var cluster=r.state(play.world,tile)
	record(cluster.crystals.get("2242",0)==2 and cluster.crystals.get("2248",0)==3,"Exported Crystal controls mix exact colors")
	var required: Array=r.automation.crystal_requirement(r,cluster)
	var cells: Array=[]
	for y in range(-1,2):
		for x in range(-1,2):
			var at=tile+Vector2i(x,y)
			if at!=tile:play.world.set_tile(at,0)
			play.world.background[at.y*100+at.x]=0
			play.world.extras.erase(r.key(play.world,at)) if at!=tile else false
			cells.append(at)
	var assigned=0
	for kind in 4:
		var item=0
		for candidate in r.rest.data.A_chi[str(kind)]:
			if r.Sim.supported(200000+int(candidate)) and int(candidate)!=0:
				item=int(candidate);break
		for i in int(required[kind]):
			var at: Vector2i=cells[assigned%cells.size()]
			if assigned<9:play.world.background[at.y*100+at.x]=200000+item
			else:
				var available: Array=cells.filter(func(pos):return pos!=tile)
				play.world.set_tile(available[assigned-9],200000+item)
			assigned+=1
	record(r.automation.chi_at(r,play.world,tile)==required,"Device Crystal alignment uses actual surrounding source-element tiles")
	play.perform_item(tile,"shatter")
	record(play.world.tile_at(tile)==0 and play.world.drops.any(func(drop):return int(drop.id)==2254),"Aligned device Crystal shatters into exact Crystal Cape result")
	play.show_menu()
	play.world.create_default("DEVICEQA")
	play.player.position=Vector2(48*32+16,24*32)
	play.world.set_tile(tile,202072);r.planted(play.world,tile,2072)
	play.perform_item(tile,"xenonite",{"power":"dbl","mode":"force"})
	await get_tree().process_frame
	record(play.player.can_double_jump(),"Xenonite forces Double Jump in exported gameplay")
	play.perform_item(tile,"xenonite",{"power":"dbl","mode":"block"})
	record(not play.player.can_double_jump(),"Xenonite block overrides device wardrobe")
	play.show_item_panel(tile)
	await snapshot("automation-xenonite")
	play.show_menu()
	play.world.world_effects.erase("xenonite")
	play.player.world_rules={}
	play.world.extras.clear();play.world.set_tile(tile,205638);r.planted(play.world,tile,5638)
	play.perform_item(tile,"select_target",{"item":2})
	play.perform_item(tile,"deposit",{"amount":8})
	play.perform_item(tile,"activate")
	var machine=r.state(play.world,tile)
	play.actions.cooldown=0
	play.select_action("place",205640)
	play.input.target=Vector2i(47,23);play.input.press("interact")
	await get_tree().create_timer(0.15).timeout
	play.input.release("interact")
	record(r.source(play.world.tile_at(Vector2i(47,23)))==2 and machine.count==7,"Device MAGPLANT remote places a block and decrements source stock once")
	r.reward(play.world,Vector2i(80,10),2,5)
	await get_tree().create_timer(0.6).timeout
	record(machine.count==12,"Device MAGPLANT automatically collects a matching floating stack")
	play.show_item_panel(tile)
	await snapshot("automation-magplant")
	play.show_menu()
	play.world.extras.clear();play.world.drops.clear();play.world.set_tile(tile,206946);r.planted(play.world,tile,6946)
	play.perform_item(tile,"select_target",{"item":3})
	r.reward(play.world,Vector2i(80,10),3,7)
	await get_tree().create_timer(0.6).timeout
	record(r.state(play.world,tile).count==7,"Gaia Beacon collects only matching seeds on physical device")
	play.world.extras.clear();play.world.set_tile(tile,206950);r.planted(play.world,tile,6950)
	play.perform_item(tile,"select_target",{"item":2})
	play.perform_item(tile,"refuel",{"amount":20})
	play.perform_item(tile,"activate")
	var tree=Vector2i(80,23);play.world.set_tile(tree,200003);r.planted(play.world,tree,3)
	r.state(play.world,tree).planted=r.now()-100
	await get_tree().create_timer(1.65).timeout
	record(play.world.tile_at(tree)==0 and r.state(play.world,tile).fuel==19,"Heart of Gaia harvests matching tree and spends fuel through live exported tick")
	play.show_item_panel(tile)
	await snapshot("automation-gaia")
	play.show_menu()
	play.world.create_default("DEVICEQA")
	play.player.position=play.world.spawn_position()
	play.select_action("punch",0)

func machine_revision_028_checks(play) -> void:
	var saved: Dictionary=play.world.serialize().duplicate(true)
	var position: Vector2=play.player.position
	var tile:=Vector2i(49,23)
	play.player.position=Vector2(48*32+16,24*32);play.player.velocity=Vector2.ZERO
	play.world.create_default("MACHINESQA")
	play.world.set_tile(tile,204992)
	play.perform_item(tile,"activate")
	await get_tree().create_timer(0.25).timeout
	record(play.player.modifiers.has("Antigravity"),"Exported generator changes physics and exposes Antigravity modifier")
	record(not play.machine_soundscape.voices.is_empty(),"Active generator plays packed original machine audio")
	play.show_item_panel(tile)
	await get_tree().process_frame
	record(is_instance_valid(play.item_status) and play.item_status.text.contains("On"),"Machine panel shows live switch state")
	await snapshot("machine-antigravity")
	play.close_modal()
	play.perform_item(tile,"configure",{"silent":true})
	await get_tree().create_timer(0.25).timeout
	record(play.machine_soundscape.voices.is_empty(),"Silent option stops the machine voice")
	play.perform_item(tile,"activate")
	await get_tree().create_timer(0.1).timeout
	record(not play.player.modifiers.has("Antigravity"),"Generator off removes Antigravity modifier")
	play.world.set_tile(tile,205958);play.world.extras.clear()
	play.perform_item(tile,"configure",{"phases":[true,true,true]})
	play.perform_item(tile,"activate")
	await get_tree().create_timer(0.2).timeout
	record(play.world.weather=="iceage","Epoch Machine starts the enabled source phase")
	play.show_item_panel(tile)
	await get_tree().process_frame
	await snapshot("machine-epoch")
	play.close_modal()
	play.world.extras["2349"].next_cycle=0
	await get_tree().create_timer(0.15).timeout
	record(play.world.weather=="volcano","Epoch Machine advances to the next enabled source weather")
	play.world.create_default("MACHINESQA");play.world.set_tile(tile,201008)
	play.item_runtime.planted(play.world,tile,1008)
	play.show_item_panel(tile)
	await get_tree().process_frame
	await snapshot("provider-atm")
	play.close_modal()
	play.world.restore(saved)
	play.player.position=position;play.player.velocity=Vector2.ZERO
	play.terrain_layer.invalidate()
	play.update_presentation()

func machine_revision_029_checks(play) -> void:
	var saved: Dictionary=play.world.serialize().duplicate(true)
	var position: Vector2=play.player.position
	var tile:=Vector2i(49,23)
	play.player.position=Vector2(48*32+16,24*32);play.player.velocity=Vector2.ZERO
	for item in [16104,16238]:
		play.world.create_default("RECOVEREDQA");play.world.set_tile(tile,200000+item)
		play.item_runtime.planted(play.world,tile,item)
		play.perform_item(tile,"grow");play.perform_item(tile,"harvest")
		record(play.world.drops.any(func(drop):return int(drop.id)==(1772 if item==16104 else 6316)),"Exported recent provider drops its documented item: "+str(item))
	play.world.create_default("RECOVEREDQA")
	play.world.locks=[{"x":52,"y":23,"item":5,"area":0,"owner":play.player.actor_key,"tiles":[]}]
	play.world.set_tile(tile,215822);play.item_runtime.planted(play.world,tile,15822)
	play.show_item_panel(tile)
	await get_tree().process_frame
	var claim=play.modal.find_child("CalendarClaim",true,false)
	record(claim!=null,"Calendar exposes actual published reward selection")
	if claim!=null:claim.pressed.emit()
	record(int(play.item_runtime.state(play.world,tile).get("claimed",0))==1,"Calendar UI button collects a real gift and advances persisted claim count")
	await snapshot("calendar-rewards")
	play.close_modal();await get_tree().create_timer(0.3).timeout
	play.world.set_tile(tile,210656);play.world.extras.clear();play.item_runtime.planted(play.world,tile,10656)
	play.show_item_panel(tile);await get_tree().process_frame
	var contribute=play.modal.find_child("WellContribution",true,false)
	if contribute!=null:contribute.pressed.emit()
	record(int(play.item_runtime.state(play.world,tile).get("chests",0))==5,"Well contribution button adds exactly five creative chests")
	await snapshot("well-of-love")
	play.close_modal();await get_tree().create_timer(0.3).timeout
	for row in [{"id":3694,"params":{"r":80,"g":170,"b":255}},{"id":3832,"params":{"item":1772,"gravity":-80,"spin":true,"invert":false}},{"id":5000,"params":{"bg":14}},{"id":7644,"params":{}},{"id":10286,"params":{}}]:
		play.world.create_default("RECOVEREDQA");play.world.set_tile(tile,200000+int(row.id))
		if not row.params.is_empty():play.perform_item(tile,"configure",row.params)
		play.perform_item(tile,"activate")
		await get_tree().create_timer(0.2).timeout
		record(play.backdrop.weather==play.world.weather and not play.world.weather.begins_with("unmapped_"),"Exported weather uses dedicated renderer: "+str(row.id))
		await snapshot("recovered-weather-"+str(row.id))
	play.world.create_default("RECOVEREDQA");play.world.set_tile(tile,204884)
	play.perform_item(tile,"activate")
	report.balloon_countdown={"before":play.world.extras.duplicate(true),"before_flags":preload("res://src/game/source_machine_rules.gd").flags(play.world).duplicate(true),"clock_before":play.item_runtime.now(),"position":[play.player.position.x,play.player.position.y],"shared":play.shared}
	record(not preload("res://src/game/source_machine_rules.gd").flags(play.world).balloon,"Balloon Jammer starts its source five-second countdown")
	var countdown_timeout:=Time.get_ticks_msec()+7000
	while not preload("res://src/game/source_machine_rules.gd").flags(play.world).balloon and Time.get_ticks_msec()<countdown_timeout:
		await get_tree().process_frame
	report.balloon_countdown.after=play.world.extras.duplicate(true)
	report.balloon_countdown.clock_after=play.item_runtime.now()
	report.balloon_countdown.after_flags=preload("res://src/game/source_machine_rules.gd").flags(play.world).duplicate(true)
	record(preload("res://src/game/source_machine_rules.gd").flags(play.world).balloon,"Balloon Jammer countdown completes through the live Windows update loop")
	var developer: bool=play.player.developer;play.player.developer=true
	for id in [1060,1402]:
		play.world.create_default("RECOVEREDQA")
		var result: Dictionary=play.item_runtime.use_item(play.world,play.player,tile,id)
		for event in result.events:play.receive_event(event)
		record(result.accepted,"Exported documented blast creates its themed world: "+str(id))
		await get_tree().create_timer(0.2).timeout
		await snapshot("recovered-blast-"+str(id))
	play.player.developer=developer
	play.world.restore(saved);play.player.position=position;play.player.velocity=Vector2.ZERO
	play.terrain_layer.invalidate();play.update_presentation()
