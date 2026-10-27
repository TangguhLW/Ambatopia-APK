extends Control

const UI = preload("res://src/ui/theme.gd")
const MaterialAudio=preload("res://src/game/material_audio.gd")
var tile_regions := {}
var frame_probe=preload("res://src/diagnostics/frame_probe.gd").new()
var dirt_top := Rect2()
var app
var input = preload("res://src/game/input_router.gd").new()
var simulation = preload("res://src/game/simulation.gd").new()
var actions = preload("res://src/game/interactions.gd").new()
var rayman=preload("res://src/game/rayman_controller.gd").new()
var world
var player
var hud
var avatar
var terrain_layer
var tiles: Texture2D
var action_particles: Texture2D
var block_cracks: Texture2D
var camera := Vector2.ZERO
var zoom := 1.0
var accumulator := 0.0
var selected_item := 0
var inventory: Control
var inventory_fraction := 1.0
var inventory_drag_start := -1.0
var inventory_tween: Tween
var modal: Control
var chat: LineEdit
var effects: Array[Dictionary] = []
var sounds := {}
var voices: Array[AudioStreamPlayer] = []
var backdrop
var guild_overlay: Control
var voice_index := 0
var autosave := 0.0
var bubble := ""
var bubble_time := 0.0
var chat_height := 0.0
var chat_panel: PanelContainer
var chat_history: RichTextLabel
var local_messages: Array[String] = []
var shared := false
var remote_players: Dictionary = {}
var shared_tile_updates := 0
var sfx_counts: Dictionary = {}
var world_touches: Dictionary = {}
var pinch_distance := 0.0
var pinched := false
var touch_tap_pending := false
var touch_origin := Vector2.ZERO
var profile_hitbox := Rect2()
var block_sprites: Dictionary = {}
var item_runtime = preload("res://src/game/item_runtime.gd").new()
var terrain_renderer=preload("res://src/game/terrain_renderer.gd").new()
var item_status: Label
var item_panel_tile := Vector2i.ZERO
var machine_soundscape=preload("res://src/game/machine_soundscape.gd").new()
var seed_visuals=preload("res://src/game/seed_visuals.gd").new()

func show_profile() -> void:
	if is_instance_valid(modal) or is_instance_valid(inventory):
		return
	input.set_text_focus(true)
	modal = load("res://src/ui/motion_panel.gd").new()
	modal.reduced_motion=not app.settings.get("animations",true)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var column := UI.panel(modal,minf(480,size.x-32))
	column.add_child(UI.label(player.display_name + " · Indonesia",28))
	column.add_child(UI.label("Choose skin",22))
	var skins := HFlowContainer.new()
	column.add_child(skins)
	for index in player.SKINS.size():
		var button := UI.button("●",func(): player.skin_index = index; sync_outfit(),28)
		button.set_meta("caption_color",Color(player.SKINS[index]))
		button.add_theme_color_override("font_color",Color(player.SKINS[index]))
		skins.add_child(button)
	column.add_child(UI.label("Creative wardrobe · double-tap clothes to wear or remove",18))
	column.add_child(UI.label("Harvested/collected item types: %d" % player.collected.size(),18))
	for modifier in player.modifiers:
		column.add_child(UI.label("%s · %ds" % [modifier,ceili(player.modifiers[modifier].remaining)],16))
	for modifier in player.abilities().worn_mods:column.add_child(UI.label(str(modifier)+" · equipped",16))
	column.add_child(UI.button("Close",func(): close_modal()))

func draw_player_flag(point: Vector2, name_text: String, font: Font, font_size: int) -> void:
	var width := font.get_string_size(name_text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var pos := point + Vector2(-width/2-22,-12)
	draw_rect(Rect2(pos,Vector2(18,6)),Color("e54141"))
	draw_rect(Rect2(pos+Vector2(0,6),Vector2(18,6)),Color.WHITE)

func draw_speech(text: String, point: Vector2, font: Font) -> void:
	var width := minf(300,size.x-40)
	var lines: Array[String] = [""]
	for character in text.left(160):
		var candidate: String = lines[-1]+character
		if font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x>width-20:
			lines.append(character)
		else:
			lines[-1] = candidate
	var height := lines.size()*22+16
	var origin := point+Vector2(-width/2,-47*zoom-height-8)
	origin.x = clampf(origin.x,8,maxf(8,size.x-width-8))
	var style := UI.box(Color("ffffffbb"),8)
	style.shadow_size = 7
	style.shadow_color = Color(0.1,0.2,0.3,0.2)
	draw_style_box(style,Rect2(origin,Vector2(width,height)))
	for line in lines.size():
		draw_string(font,origin+Vector2(10,24+line*22),lines[line],HORIZONTAL_ALIGNMENT_CENTER,width-20,18,Color("1a3544"))

func set_zoom(value: float) -> void:
	var minimum := maxf(0.45,maxf(size.x/(world.size.x*32.0),size.y/(world.size.y*32.0))) if world != null else 0.45
	zoom = clampf(value,minimum,2.5)
	update_presentation()
	queue_redraw()

func _ready() -> void:
	add_child(machine_soundscape)
	machine_soundscape.contact_sound.connect(func(path):play_sound(path))
	world = app.session.world
	player = app.session.player
	shared = app.network != null and app.network.connected
	if shared:
		app.network.received.connect(receive_shared)
		app.network.disconnected.connect(func(): cancel_input(); input.set_text_focus(true); hud.show_message("Connection lost. Exit World to reconnect.",30))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop = load("res://src/ui/background.gd").new()
	backdrop.menu_mode = false
	add_child(backdrop)
	backdrop.show_behind_parent = true
	tiles = load("res://assets/reference/tiles.png")
	action_particles = load("res://assets/reference/action_particles.png")
	block_cracks = load("res://assets/reference/block_cracks.png")
	var atlas_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas.json"))
	var frames: Dictionary = atlas_data.tiles
	var top_frame: Array = atlas_data.terrain.dirt_top
	dirt_top = Rect2(top_frame[0], top_frame[1], top_frame[2], top_frame[3])
	for id in frames:
		var region: Array = frames[id]
		tile_regions[int(id)] = Rect2(region[0], region[1], region[2], region[3])
	terrain_layer=preload("res://src/game/terrain_layer.gd").new()
	terrain_layer.view=self
	terrain_layer.show_behind_parent=true
	add_child(terrain_layer)
	avatar = load("res://src/game/avatar_view.gd").new()
	add_child(avatar)
	avatar.source_punch_sound.connect(func(name):play_sound(name,"item_punch"))
	guild_overlay=preload("res://src/ui/guild_weather_overlay.gd").new()
	guild_overlay.view=self
	add_child(guild_overlay)
	hud = load("res://src/ui/hud.gd").new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	hud.title.text = world.name + " • " + player.display_name
	hud.status.text = "Local creative • Punch selected • Physics/frame timing provisional"
	hud.hold_started.connect(func(action): input.press(action))
	hud.hold_ended.connect(func(action): input.release(action))
	hud.mode_selected.connect(select_action)
	hud.inventory_requested.connect(toggle_inventory)
	hud.inventory_dragged.connect(drag_inventory)
	hud.menu_requested.connect(show_menu)
	hud.chat_requested.connect(toggle_chat)
	hud.chat_height_requested.connect(set_chat_height)
	chat_panel = PanelContainer.new()
	chat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	chat_panel.visible = false
	add_child(chat_panel)
	chat_history = RichTextLabel.new()
	chat_history.text="World chat"
	chat_history.add_theme_font_override("normal_font",load("res://assets/reference/font.ttf"))
	chat_history.add_theme_font_size_override("normal_font_size",16)
	chat_history.add_theme_color_override("default_color",Color("fff4bd"))
	chat_history.scroll_active=true
	chat_history.scroll_following=true
	chat_history.size_flags_vertical=Control.SIZE_EXPAND_FILL
	chat_history.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	chat_panel.clip_contents = true
	chat_panel.add_child(chat_history)
	move_child(chat_panel,hud.get_index())
	for id in ["jump", "punch", "place", "break", "lava","male_scream","teleport","gauntlet_death","gauntlet_spawn","realitytear"]:
		sounds[id] = load("res://assets/reference/%s_sound.wav" % id)
	for id in MaterialAudio.FILES:
		sounds[id]=load("res://assets/reference/material_%s.wav" % id)
	for i in 4:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	resized.connect(layout_overlays)
	update_presentation()

func cancel_input() -> void:
	input.cancel_all()
	world_touches.clear()
	pinch_distance = 0
	if is_instance_valid(hud):
		hud.clear_touches()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		cancel_input()

func select_action(action: String, item_id: int) -> void:
	player.wrench_selected=action=="wrench"
	input.cancel_all()
	input.selected_action = action
	selected_item = item_id
	hud.set_selection(action,item_id)
	hud.status.text = {"punch": "Punch", "place": "Place item %d" % item_id, "wrench": "Wrench / inspect"}[action] + " selected"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		var action: String = {KEY_A: "left", KEY_LEFT: "left", KEY_D: "right", KEY_RIGHT: "right", KEY_SPACE: "jump", KEY_UP: "jump", KEY_F: "punch"}.get(event.physical_keycode, "")
		if not action.is_empty():
			if event.pressed:
				input.press(action)
			else:
				input.release(action)
		if event.pressed and not input.text_focus:
			match event.physical_keycode:
				KEY_1: select_action("punch", 0)
				KEY_2: select_action("place", 1)
				KEY_3: select_action("wrench", 0)
				KEY_E: toggle_inventory()
				KEY_ENTER: toggle_chat()
				KEY_ESCAPE: show_menu()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		input.release("interact")

func _gui_input(event: InputEvent) -> void:
	if input.selected_action == "wrench" and ((event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)) and profile_hitbox.has_point(event.position):
		show_profile()
		accept_event()
		return
	if event is InputEventMagnifyGesture:
		set_zoom(zoom * event.factor)
		accept_event()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if world_touches.is_empty():
				pinched = false
				touch_origin = event.position
			world_touches[event.index] = event.position
		else:
			if world_touches.size() == 1 and not pinched and touch_origin.distance_to(event.position)<20:
				input.target = Vector2i(((event.position-size/2)/zoom+camera)/32)
				input.press("interact")
				touch_tap_pending = true
			world_touches.erase(event.index)
		if world_touches.size() == 2:
			pinched = true
			pinch_distance = world_touches.values()[0].distance_to(world_touches.values()[1])
			input.release("interact")
		else:
			pinch_distance = 0
		accept_event()
		return
	if event is InputEventScreenDrag and world_touches.has(event.index):
		world_touches[event.index] = event.position
		if world_touches.size() == 2:
			var distance: float = world_touches.values()[0].distance_to(world_touches.values()[1])
			if pinch_distance > 8:
				set_zoom(zoom * distance / pinch_distance)
			pinch_distance = distance
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		set_zoom(zoom * (1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.1))
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			input.target = Vector2i(((event.position - size / 2) / zoom + camera) / 32)
			input.press("interact")
		else:
			input.release("interact")
		accept_event()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		input.target = Vector2i(((event.position - size / 2) / zoom + camera) / 32)

func _process(delta: float) -> void:
	var probe_start:=frame_probe.start()
	if world == null:
		return
	world.tick_damage(delta)
	machine_soundscape.update(world,player,delta,float(app.settings.master)*float(app.settings.effects))
	hud.overlay_blocked = is_instance_valid(inventory) or is_instance_valid(modal) or is_instance_valid(chat)
	delta = minf(delta, 0.1)
	accumulator = minf(accumulator + delta, 5.0 / 60.0)
	while accumulator >= 1.0 / 60.0:
		var state: Dictionary = input.sample()
		if player.death_time>=0 and player.death_time<2:
			state.axis=0;state.jump_pressed=false;state.action="none";state.pressed=false
		if not shared:state=rayman.sample(player,state,1.0/60.0)
		if shared:
			app.network.submit(state,selected_item)
		if state.jump_pressed and (player.grounded or player.can_double_jump() and player.air_jumps < 1):
			play_sound("jump")
		for hazard_event in simulation.step(world, player, state, 1.0 / 60.0):receive_event(hazard_event)
		if not shared:
			for event in preload("res://src/game/source_machine_rules.gd").tick(item_runtime,world):receive_event(event)
			for event in item_runtime.automation.tick(item_runtime,world,1.0/60.0):receive_event(event)
			item_runtime.collect(world,player)
			item_runtime.special.tick(item_runtime,world,[player],1.0/60.0)
		actions.tick(1.0 / 60.0)
		if shared and state.action == "punch" and actions.cooldown <= 0:
			var punch_target: Vector2=Vector2(state.target)*32+Vector2(16,16)
			if state.get("direct_punch",false):punch_target=player.position+Vector2(player.facing*36,-16)
			if punch_target.distance_to(player.position-Vector2(0,16))<=player.abilities().range:
				var target_tile:=Vector2i((punch_target/32).floor())
				var target_id: int=world.tile_at(target_tile)
				if target_id==0 and world.contains(target_tile):target_id=world.background[target_tile.y*world.size.x+target_tile.x]
				play_sound(MaterialAudio.impact(target_id,target_id in [2,4]),"punch")
				player.begin_punch(punch_target)
			actions.cooldown = 0.22
		if not shared and state.action != "none":
			var target: Vector2i = state.target
			if state.action == "punch" and state.get("direct_punch",false):
				target = Vector2i((player.position + Vector2(player.facing * 36, -16)) / 32)
			var result: Dictionary = actions.apply(world, player, state.action, target, selected_item)
			if result.reason not in ["","Cooldown","Out of reach"]:
				hud.show_message(result.reason,3)
			for action_event in result.events:
				receive_event(action_event)
		accumulator -= 1.0 / 60.0
		if touch_tap_pending:
			input.release("interact")
			touch_tap_pending = false
	for effect in effects:
		effect.age += delta
	effects = effects.filter(func(effect): return effect.age < 0.35)
	bubble_time = maxf(0, bubble_time - delta)
	autosave += delta
	if autosave >= 15 and not shared:
		autosave = 0
		var result: Dictionary = app.session.save()
		if not result.ok:
			hud.show_message(result.error,8)
	update_presentation()
	for remote in remote_players.values():
		remote.state.position = remote.state.position.lerp(remote.target,minf(1,delta*18))
		remote.state.punch_time = maxf(0,remote.state.punch_time-delta)
		remote.state.talk_time = maxf(0,remote.state.talk_time-delta)
		remote.state.burn_time=maxf(0,remote.state.burn_time-delta)
		if remote.state.death_time>=0:remote.state.death_time+=delta
		remote.bubble_time = maxf(0,remote.bubble_time-delta)
		remote.avatar.position = to_screen(remote.state.position+Vector2(0,remote.avatar.body_lift(remote.state)))
		remote.avatar.scale = Vector2.ONE * zoom
		if remote.state.death_time>=0:remote.avatar.scale*=preload("res://src/game/death_sequence.gd").visual(remote.state).scale
		remote.avatar.present(remote.state,0)
	queue_redraw()
	frame_probe.end("simulation_and_presentation",probe_start)

func update_presentation() -> void:
	if player == null:
		return
	camera = player.position + Vector2(0, 4)
	camera.x = clampf(camera.x, size.x / zoom / 2, world.size.x * 32 - size.x / zoom / 2)
	camera.y = clampf(camera.y, size.y / zoom / 2, world.size.y * 32 - size.y / zoom / 2)
	if is_instance_valid(terrain_layer):terrain_layer.refresh()
	avatar.position = to_screen(player.position+Vector2(0,avatar.body_lift(player)))
	avatar.scale = Vector2.ONE * zoom
	if player.death_time>=0:avatar.scale*=preload("res://src/game/death_sequence.gd").visual(player).scale
	avatar.present(player, 0)
	backdrop.weather = world.weather
	backdrop.weather_parameters=world.extras.get(str(world.world_effects.get("active_weather","")),{})
	if world.weather=="guild":backdrop.weather_parameters=preload("res://src/game/guild_weather.gd").parameters(world,backdrop.weather_parameters)
	if is_instance_valid(guild_overlay):guild_overlay.queue_redraw()
	backdrop.camera_offset = camera.x
	backdrop.low_quality = app.settings.get("graphics","normal") == "low"

func to_screen(point: Vector2) -> Vector2:
	return (point - camera) * zoom + size / 2

func _draw() -> void:
	var probe_start:=frame_probe.start()
	if world == null or tiles == null:
		return
	var animation_ms:=int(Time.get_unix_time_from_system()*1000)
	for chunk in terrain_layer.chunks.values():
		if not chunk.visible:continue
		for tile in chunk.dynamic_tiles:draw_tree(tile,item_runtime.source(world.tile_at(tile)))
		for tile in chunk.animated_tiles:
			var id: int=world.tile_at(tile)
			var image: Texture2D=terrain_renderer.animation_texture(world,tile,id,animation_ms)
			var row: Array=terrain_renderer.Sim.items().get(str(terrain_renderer.source(id)),[])
			var tint: Color=terrain_renderer.rainbow(Time.get_ticks_msec()/1000.0,tile) if row.size()>13 and int(row[13])==25 else Color(world.extras.get(item_runtime.key(world,tile),{}).get("paint","ffffff"))
			if image!=null:draw_texture_rect(image,Rect2(to_screen(Vector2(tile)*32),Vector2.ONE*32*zoom),false,tint)
	for key in world.extras:
		var index:=int(key)
		var tile:=Vector2i(index%world.size.x,index/world.size.x)
		var rect:=Rect2(to_screen(Vector2(tile)*32),Vector2.ONE*32*zoom)
		if not rect.intersects(Rect2(Vector2.ZERO,size)):continue
		var data: Dictionary=world.extras[key]
		if data.get("enabled",false) and not terrain_renderer.MachineAnimation.handles(item_runtime.source(world.tile_at(tile))):draw_circle(rect.position+Vector2(26,7)*zoom,3*zoom,Color("81ff9a"))
		if data.get("water",false):draw_rect(rect,Color(0.2,0.6,1,0.3))
		if data.get("fire",false):draw_circle(rect.get_center(),(8+sin(Time.get_ticks_msec()*0.012)*2)*zoom,Color(1,0.5,0.1,0.7))
	for tile in world.damage:
		var rect:=Rect2(to_screen(Vector2(tile)*32),Vector2.ONE*32*zoom)
		if rect.intersects(Rect2(Vector2.ZERO,size)):
			var region: Rect2=preload("res://src/game/block_cracks.gd").region(float(world.damage[tile]),float(world.damage_required.get(tile,3)))
			draw_texture_rect_region(block_cracks,rect,region)
	for shot in world.world_effects.get("projectiles",[]):
		draw_circle(to_screen(Vector2(shot.x,shot.y)),5*zoom,Color("ff5a1f" if int(shot.id)==8020 else "9fe8ff"))
	for drop in world.drops:
		var point := to_screen(Vector2(drop.x,drop.y))
		if not Rect2(Vector2.ZERO,size).has_point(point):
			continue
		var icon: Texture2D = preload("res://src/game/simulator_catalog.gd").sprite(int(drop.id))
		if icon!=null:
			draw_texture_rect(icon,Rect2(point-Vector2(10,10),Vector2(20,20)*zoom),false)
	for effect in effects:
		if app.settings.get("graphics","normal") == "low":
			break
		var center := to_screen(Vector2(effect.tile) * 32 + Vector2(16, 16))
		var smoke_frame := clampi(int(effect.age/0.35*5),0,4)
		draw_texture_rect_region(action_particles,Rect2(center-Vector2(24,24),Vector2(48,48)),Rect2(smoke_frame*32,0,32,32),Color(1,1,1,1-effect.age/0.35))
	var name_position := to_screen(player.position).round() + Vector2(-80, -47 * zoom)
	var font := get_theme_default_font()
	draw_string(font, name_position + Vector2(1, 1), player.display_name, HORIZONTAL_ALIGNMENT_CENTER, 160, roundi(14 * zoom), Color("18303b"))
	draw_string(font, name_position, player.display_name, HORIZONTAL_ALIGNMENT_CENTER, 160, roundi(14 * zoom), Color.WHITE)
	draw_player_flag(name_position+Vector2(80,0),player.display_name,font,roundi(14*zoom))
	profile_hitbox = Rect2()
	if input.selected_action == "wrench":
		var name_width := font.get_string_size(player.display_name,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(14*zoom)).x
		profile_hitbox = Rect2(name_position+Vector2(80+name_width/2+4,-30),Vector2(44,44))
		draw_texture_rect(UI.item_icon(-1),profile_hitbox,false)
	if bubble_time > 0 and app.settings.get("chat",true):
		draw_speech(bubble,to_screen(player.position),font)
	for remote in remote_players.values():
		var point: Vector2 = to_screen(remote.state.position)
		draw_string(font,point+Vector2(-80,-47),remote.state.display_name,HORIZONTAL_ALIGNMENT_CENTER,160,14,Color.WHITE)
		draw_player_flag(point+Vector2(0,-47),remote.state.display_name,font,14)
		if remote.bubble_time > 0 and app.settings.get("chat",true):
			draw_speech(remote.bubble,point,font)

	frame_probe.end("world_draw",probe_start)

func receive_event(event: Dictionary) -> void:
	match event.type:
		"tile_damaged":
			world.register_damage(event.tile,float(event.get("hits",float(world.damage.get(event.tile,0))+1)),float(event.get("required",3)))
		"death_sound":play_sound(str(event.sound))
		"death_started":cancel_input()
		"punch_started":
			play_sound(MaterialAudio.impact(int(event.get("item_id",world.tile_at(event.tile))),bool(event.get("protected",false))),"punch")
		"tile_placed":
			if not shared and item_runtime.source(world.tile_at(event.tile))==5814:preload("res://src/game/lock_rules.gd").placed(world,event.tile,world.tile_at(event.tile),player.actor_key)
			play_sound("place")
			effects.append({"tile": event.tile, "age": 0.0})
			if world.tile_at(event.tile) == 5:
				send_announcement("This world has been locked by " + player.display_name + ".")
		"tile_removed":
			if not shared and item_runtime.source(int(event.get("item_id",0)))==5814:preload("res://src/game/lock_rules.gd").removed(world,event.tile)
			world.damage.erase(event.tile)
			world.damage_required.erase(event.tile)
			play_sound(str(MaterialAudio.pair(int(event.get("item_id",0)))[1]),"break")
			effects.append({"tile": event.tile, "age": 0.0})
		"inspect_requested": show_item_panel(event.tile)
		"item_message","reward":
			hud.show_message(event.get("text","Item used"),6)
			if is_instance_valid(item_status):
				item_status.text = describe_item(item_panel_tile)
		"item_used":
			play_sound("place")
			effects.append({"tile":event.tile,"age":0.0})
		"item_state":
			if event.has("tile"):world.mark_visual(event.tile)
			if is_instance_valid(item_status):
				item_status.text = describe_item(item_panel_tile)

func draw_tree(tile: Vector2i,id: int) -> void:
	var progress := item_runtime.growth(world,tile)
	var data: Dictionary=world.extras.get(item_runtime.key(world,tile),{})
	seed_visuals.draw(self,to_screen(Vector2(tile)*32),zoom,id,progress,int(data.get("fruit",0)))

func describe_item(tile: Vector2i) -> String:
	var id := item_runtime.source(world.tile_at(tile))
	var data: Dictionary = world.extras.get(item_runtime.key(world,tile),{})
	var text := "Item · " + str(preload("res://src/game/simulator_catalog.gd").items().get(str(id),["Tile"])[0])
	if id in [392,3402,9350]:text+="\nSimulator chest replay · rare pool 1/%d; final override 1/5000. Original live-server odds are unverified."%(350 if id==9350 else 800)
	if preload("res://src/game/source_machine_rules.gd").handles(id):text+="\n"+("On" if data.get("enabled",false) else "Off")
	if item_runtime.recovered.data.calendars.has(str(id)):text+="\nGifts collected: %d / 25"%int(data.get("claimed",0))
	if id==10656:text+="\nGolden Booty Chests: %d / 200"%int(data.get("chests",0))
	text+=item_runtime.special.describe(item_runtime,world,tile)
	text+=item_runtime.automation.describe(item_runtime,world,tile)
	if item_runtime.is_seed(id):
		text += "\nGrowth: %d%%" % roundi(item_runtime.growth(world,tile)*100)
	if data.has("ready") and not item_runtime.recovered.data.calendars.has(str(id)) and id!=10656:
		text += "\nReady in: %ds" % maxi(0,ceili(float(data.ready)-item_runtime.now()))
	if data.has("result"):
		text += "\nResult: "+str(data.result)
	if data.has("label"):
		text += "\n"+str(data.label)
	for stock in data.get("stock",{}):
		text += "\n%s × %d" % [preload("res://src/game/simulator_catalog.gd").items().get(stock,[stock])[0],int(data.stock[stock])]
	return text

func perform_item(tile: Vector2i,command: String,args: Dictionary = {}) -> void:
	world.mark_visual(tile)
	if shared:
		app.network.send({"type":"machine","x":tile.x,"y":tile.y,"command":command,"args":args})
	else:
		var result: Dictionary = item_runtime.interact(world,player,tile,command,args)
		if not result.accepted:
			hud.show_message(result.reason,6)
		for event in result.events:
			receive_event(event)
		if is_instance_valid(item_status):
			item_status.text = describe_item(tile)

func show_item_panel(tile: Vector2i) -> void:
	if is_instance_valid(modal) or is_instance_valid(inventory) or world.tile_at(tile)==0:
		return
	input.set_text_focus(true)
	item_panel_tile = tile
	modal = PanelContainer.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.anchor_left=0.06
	modal.anchor_right=0.94
	modal.anchor_top=0.06
	modal.anchor_bottom=0.94
	modal.add_theme_stylebox_override("panel",UI.box(Color("184d60f5"),12))
	add_child(modal)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	item_status=UI.label(describe_item(tile),18)
	item_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(item_status)
	var actions_row := HFlowContainer.new()
	body.add_child(actions_row)
	var source_id=item_runtime.source(world.tile_at(tile))
	if source_id==5814:
		preload("res://src/ui/guild_panel.gd").new().populate(body,self,tile)
		return
	if preload("res://src/ui/recovered_machine_panel.gd").new().populate(body,self,tile,source_id):return
	if preload("res://src/game/source_machine_rules.gd").handles(source_id):
		actions_row.add_child(UI.button("Switch On / Off",func():perform_item(tile,"activate"),20))
		var silent:=CheckButton.new()
		silent.text="Silence machine"
		silent.button_pressed=item_runtime.state(world,tile).get("silent",false)
		silent.toggled.connect(func(value):perform_item(tile,"configure",{"silent":value}))
		body.add_child(silent)
		var public_switch:=CheckButton.new()
		public_switch.text="Allow public switching"
		public_switch.button_pressed=item_runtime.state(world,tile).get("public",false)
		public_switch.toggled.connect(func(value):perform_item(tile,"configure",{"public":value}))
		body.add_child(public_switch)
		preload("res://src/ui/weather_machine_panel.gd").new().populate(body,self,tile,source_id)
		if source_id in [5958,10058]:
			var settings: Dictionary=item_runtime.state(world,tile)
			var interval:=SpinBox.new()
			interval.min_value=1;interval.max_value=60 if source_id==5958 else 240;interval.value=settings.get("interval",10 if source_id==5958 else 5)
			body.add_child(UI.label("Cycle interval (minutes)",18));body.add_child(interval)
			body.add_child(UI.button("Apply interval",func():perform_item(tile,"configure",{"interval":interval.value}),18))
			if source_id==5958:
				for index in 3:
					var phase:=CheckButton.new()
					phase.text=["Ice Age","Volcano","Floating Islands"][index]
					phase.button_pressed=settings.get("phases",[false,false,false])[index]
					phase.toggled.connect(func(enabled):
						var values: Array=item_runtime.state(world,tile).get("phases",[false,false,false]).duplicate()
						values[index]=enabled;perform_item(tile,"configure",{"phases":values}))
					body.add_child(phase)
			else:
				var random_order:=CheckButton.new()
				random_order.text="Random weather order";random_order.button_pressed=settings.get("random",false)
				random_order.toggled.connect(func(value):perform_item(tile,"configure",{"random":value}))
				body.add_child(random_order)
				for index in 4:
					var picker:=OptionButton.new();picker.custom_minimum_size.y=44;picker.fit_to_longest_item=false
					picker.add_item("Weather %d: Empty"%[index+1],0)
					for id in item_runtime.Sim.use_rules.weather:
						if int(id) in [5958,10058]:continue
						picker.add_item(str(item_runtime.Sim.items()[id][0]),int(id))
					var values: Array=settings.get("slots",[])
					picker.select(picker.get_item_index(int(values[index])) if index<values.size() else 0)
					picker.item_selected.connect(func(selected):
						var slots: Array=item_runtime.state(world,tile).get("slots",[0,0,0,0]).duplicate()
						slots.resize(4)
						for i in 4:
							if slots[i]==null:slots[i]=0
						slots[index]=picker.get_item_id(selected);perform_item(tile,"configure",{"slots":slots}))
					body.add_child(picker)
		body.add_child(UI.button("Close",func():close_modal()))
		return
	if item_runtime.Sim.use_rules.provider.has(str(source_id)):
		actions_row.add_child(UI.button("Harvest",func():perform_item(tile,"harvest"),20))
		actions_row.add_child(UI.button("Creative grow",func():perform_item(tile,"grow"),20))
		var table: Array=item_runtime.Sim.use_rules.provider_drop.get(str(source_id),[])
		var names: Array=[]
		for row in table:
			var name: String=str(item_runtime.Sim.items()[str(int(row[0]))][0])
			if name not in names:names.append(name)
		var info:=UI.label("Drops: 1–250 Gems" if source_id==1008 else "Drops: "+", ".join(names) if not names.is_empty() else "Source drop table unavailable for this provider.",16)
		info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		body.add_child(info)
		body.add_child(UI.button("Close",func():close_modal()))
		return
	if preload("res://src/ui/automation_panel.gd").new().populate(body,self,tile,source_id):return
	var entries: Array=[["Activate","activate"],["Harvest","harvest"],["Creative grow","grow"],["Dispense","dispense"]]
	if source_id==3354:
		entries=[["Sew three bolts","sew"]]
	elif source_id==3316:
		entries=[["Harvest silk","harvest"]]
	elif source_id==3078:
		entries=[]
	elif source_id==2208:
		entries=[["Exchange outfit","activate"],["Take all clothes","take_all"]]
	elif source_id in [4344,8020]:
		entries=[["Switch blaster","activate"]]
	elif source_id in item_runtime.special.FOSSIL_ROCKS:
		entries=[]
	for entry in entries:
		actions_row.add_child(UI.button(entry[0],func():perform_item(tile,entry[1]),18))
	if source_id==3078:
		for field in ["planting","splicing"]:
			var choice:=CheckButton.new()
			choice.text="Speeds growth when "+field
			choice.button_pressed=item_runtime.state(world,tile).get(field,true)
			choice.toggled.connect(func(enabled):perform_item(tile,"configure",{field:enabled}))
			body.add_child(choice)
	if source_id in [4344,8020]:
		var settings: Dictionary=item_runtime.state(world,tile)
		for field in ["period","speed"]:
			body.add_child(UI.label("Fire interval (2-20 seconds)" if field=="period" else "Projectile speed (10-250 px/s)",16))
			var value:=SpinBox.new()
			value.min_value=2 if field=="period" else 10
			value.max_value=20 if field=="period" else 250
			value.value=settings.get(field,10 if field=="period" else 100)
			value.custom_minimum_size.y=44
			body.add_child(value)
			body.add_child(UI.button("Update "+field,func():perform_item(tile,"configure",{field:int(value.value)}),18))
		var direction:=CheckButton.new()
		direction.text="Fire toward the left"
		direction.button_pressed=settings.get("left",false)
		direction.toggled.connect(func(enabled):perform_item(tile,"configure",{"left":enabled}))
		body.add_child(direction)
	if source_id not in [3078,4344,8020,2208] and source_id not in item_runtime.special.FOSSIL_ROCKS:
		var search := LineEdit.new()
		search.placeholder_text="Find ingredient / stock item"
		search.custom_minimum_size.y=44
		body.add_child(search)
		var picker := OptionButton.new()
		picker.fit_to_longest_item=false
		picker.clip_text=true
		picker.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		picker.custom_minimum_size.y=44
		body.add_child(picker)
		var choices: Array = []
		search.text_changed.connect(func(text):
			choices.assign(preload("res://src/game/simulator_catalog.gd").query(text).slice(0,24))
			picker.clear()
			for row in choices:
				picker.add_item(row.name))
		search.text="Dirt"
		search.text_changed.emit(search.text)
		var amount := SpinBox.new()
		amount.min_value=1
		amount.max_value=200
		amount.value=1
		amount.custom_minimum_size.y=44
		body.add_child(amount)
		if source_id!=3316:
			body.add_child(UI.button("Add free creative stock",func():
				if picker.selected>=0 and picker.selected<choices.size():
					perform_item(tile,"deposit",{"item":int(choices[picker.selected].id),"amount":int(amount.value)}),18))
		if source_id==3316:
			body.add_child(UI.button("Give selected care item",func():
				if picker.selected>=0 and picker.selected<choices.size():
					perform_item(tile,"care",{"item":int(choices[picker.selected].id)}),18))
		var recipes: Array = item_runtime.recipes_for(item_runtime.source(world.tile_at(tile)))
		if not recipes.is_empty():
			var recipe_picker := OptionButton.new()
			recipe_picker.fit_to_longest_item=false
			recipe_picker.clip_text=true
			recipe_picker.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			recipe_picker.custom_minimum_size.y=44
			for recipe in recipes:
				recipe_picker.add_item(recipe.name)
			body.add_child(recipe_picker)
			var ingredients := UI.label("",16)
			ingredients.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			body.add_child(ingredients)
			var show_ingredients := func(index):
				ingredients.text="Ingredients: "+", ".join(recipes[index].inputs.map(func(id):return preload("res://src/game/simulator_catalog.gd").items().get(str(int(id)),[str(id)])[0]))
			recipe_picker.item_selected.connect(show_ingredients)
			show_ingredients.call(0)
			body.add_child(UI.button("Craft selected recipe",func():perform_item(tile,"craft",{"recipe":recipe_picker.selected}),18))
		if source_id not in [3316,3354]:
			var label := LineEdit.new()
			label.placeholder_text="Sign / label text"
			label.max_length=160
			label.custom_minimum_size.y=44
			body.add_child(label)
			body.add_child(UI.button("Save label",func():perform_item(tile,"configure",{"label":label.text}),18))
	body.add_child(UI.button("Close",func():
		modal.queue_free()
		modal=null
		item_status=null
		input.set_text_focus(false),22))

func send_announcement(text: String) -> void:
	bubble = text
	bubble_time = clampf(2+text.length()*0.08,3,8)
	local_messages.append(text)
	chat_history.text = "\n".join(local_messages.slice(-8))

func play_sound(id: String, action: String="") -> void:
	if not sounds.has(id):
		var stream: AudioStream=preload("res://src/game/machine_audio.gd").stream(id) if id.begins_with("audio/") else preload("res://src/game/source_punch_audio.gd").stream(id)
		if stream==null:
			if not has_meta("missing_sfx_"+id):push_warning("Source punch audio unavailable: "+id);set_meta("missing_sfx_"+id,true)
			return
		sounds[id]=stream
	var count_key:=id if action.is_empty() else action
	sfx_counts[count_key] = int(sfx_counts.get(count_key,0))+1
	set_meta("last_sfx",id)
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = sounds[id]
	voice.volume_db = linear_to_db(maxf(0.0001, app.settings.master * app.settings.effects))
	voice.play()

func toggle_inventory() -> void:
	if is_instance_valid(inventory):
		if inventory_tween != null:
			inventory_tween.kill()
		inventory_drag_start = -1
		inventory.queue_free()
		inventory = null
		hud.overlay_blocked = false
		input.set_text_focus(false)
		return
	if is_instance_valid(modal) or is_instance_valid(chat):
		return
	input.set_text_focus(true)
	hud.overlay_blocked = true
	inventory = load("res://src/ui/inventory.gd").new()
	inventory_fraction = 1.0
	inventory.worn = player.catalog_equipment.duplicate()
	inventory.developer = player.developer
	add_child(inventory)
	inventory.minimum_size_changed.connect(layout_overlays)
	inventory.close_requested.connect(toggle_inventory)
	inventory.drawer_dragged.connect(drag_inventory)
	inventory.item_selected.connect(func(id): toggle_inventory(); select_action("place", id))
	inventory.equipment_changed.connect(func(slot, id): player.equipment[slot] = id)
	inventory.catalog_equip_requested.connect(equip_outfit_item)
	inventory.catalog_unequip_requested.connect(unequip_outfit_item)
	inventory.save_set_requested.connect(show_outfits)
	layout_overlays()
	if app.settings.get("animations",true):
		set_inventory_fraction(0.0)
		animate_inventory(1.0)

func inventory_height() -> float:
	var minimum := inventory.get_combined_minimum_size().y if is_instance_valid(inventory) else 0.0
	return minf(size.y-24,maxf(minimum,maxf(410,size.y*0.72)))

func set_inventory_fraction(value: float) -> void:
	inventory_fraction = clampf(value,0,1)
	layout_overlays()

func animate_inventory(target: float) -> void:
	if inventory_tween != null:
		inventory_tween.kill()
	inventory_tween = create_tween()
	inventory_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	inventory_tween.tween_method(set_inventory_fraction,inventory_fraction,target,preload("res://src/ui/motion.gd").DRAWER_DURATION if app.settings.get("animations",true) else 0.0)
	if target == 0:
		inventory_tween.tween_callback(func():
			if is_instance_valid(inventory):
				inventory.queue_free()
				inventory = null
			input.set_text_focus(false))

func drag_inventory(distance: float, finished: bool) -> void:
	if inventory_drag_start < 0:
		var was_open := is_instance_valid(inventory)
		if not was_open:
			toggle_inventory()
		if not is_instance_valid(inventory):
			return
		if inventory_tween != null:
			inventory_tween.kill()
		inventory_drag_start = inventory_fraction if was_open else 0.0
	set_inventory_fraction(inventory_drag_start+distance/inventory_height())
	if finished:
		var decisive:=maxf(48,inventory_height()*0.12)
		var target := (1.0-inventory_drag_start) if absf(distance)<8 else 1.0 if distance>decisive else 0.0 if distance< -decisive else (1.0 if inventory_fraction>=0.5 else 0.0)
		inventory_drag_start = -1
		animate_inventory(target)

func show_menu() -> void:
	hud.visible=true
	if is_instance_valid(modal):
		if modal.has_method("request_close"):
			if modal.transition_state=="closing":
				modal.open()
			else:
				close_modal()
		else:
			close_modal()
		return
	if is_instance_valid(inventory):
		toggle_inventory()
	if is_instance_valid(chat):
		toggle_chat()
	input.set_text_focus(true)
	modal = load("res://src/ui/motion_panel.gd").new()
	modal.reduced_motion=not app.settings.get("animations",true)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var column := UI.panel(modal, 480)
	column.add_child(UI.label("Menu", 36))
	column.add_child(UI.button("Exit World",exit_world))
	column.add_child(UI.button("Respawn",respawn_player))
	column.add_child(UI.button("Options",open_world_options))
	if player.catalog_equipment.values().any(func(id):return preload("res://src/game/source_item_tracks.gd").pets.get("items",{}).has(str(preload("res://src/game/source_item_tracks.gd").source(int(id))))):
		var pet_toggle:=CheckButton.new()
		pet_toggle.text="Show equipped pet"
		var pet_id: String=""
		for id in player.catalog_equipment.values():
			var key:=str(preload("res://src/game/source_item_tracks.gd").source(int(id)))
			if preload("res://src/game/source_item_tracks.gd").pets.items.has(key):pet_id=key;break
		pet_toggle.button_pressed=bool(player.item_options.get("pet_"+pet_id,true))
		pet_toggle.toggled.connect(func(on):player.item_options["pet_"+pet_id]=on;sync_outfit())
		column.add_child(pet_toggle)
	column.add_child(UI.button("Hide UI",func(): close_modal(func(): hud.visible=false; chat_panel.visible=false)))
	for entry in [["Store","No store economy in creative mode"],["Support","Support service is not implemented"],["Secure My Account","Account MFA is not implemented in this local game"]]:
		var unavailable:=UI.button(entry[0],func(): pass)
		unavailable.disabled=true
		unavailable.tooltip_text=entry[1]
		column.add_child(unavailable)
	column.add_child(UI.button("Back",show_menu))
	column.add_child(UI.label("Current World: "+world.name,20))
	column.add_child(UI.label("Creative tools",20))
	column.add_child(UI.button("Player profile",func(): close_modal(show_profile)))
	if shared and app.accounts.profile.get("role") == "developer":
		column.add_child(UI.button("Developer",func():
			modal.queue_free()
			modal = load("res://src/ui/developer.gd").new()
			modal.app = app
			modal.world_view = self
			modal.close_action = show_menu
			modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(modal)))
	var weather_picker := OptionButton.new()
	weather_picker.custom_minimum_size.y = 48
	weather_picker.fit_to_longest_item = false
	weather_picker.clip_text = true
	var sim = preload("res://src/game/simulator_catalog.gd")
	sim.items()
	for row in sim.weather_list:
		weather_picker.add_item(row.n)
		if row.k == world.weather:
			weather_picker.select(weather_picker.item_count-1)
	weather_picker.item_selected.connect(func(index):
		if shared:
			app.network.send({"type":"weather","key":sim.weather_list[index].k})
		else:
			world.weather = sim.weather_list[index].k)
	column.add_child(weather_picker)
	if not shared:
		column.add_child(UI.button("Save world", func(): var result: Dictionary = app.session.save(); hud.show_message("Saved locally" if result.ok else result.error)))

func close_modal(next: Callable=Callable()) -> void:
	var closing:=modal
	var done:=func():
		if is_instance_valid(closing):
			closing.queue_free()
		if modal==closing:
			modal=null
		input.set_text_focus(false)
		if next.is_valid():next.call()
	if is_instance_valid(closing) and closing.has_method("request_close"):
		closing.request_close(done)
	else:
		done.call()

func open_world_options() -> void:
	close_modal(func():
		input.set_text_focus(true)
		modal=load("res://src/ui/dialog.gd").new()
		modal.app=app
		modal.kind="options"
		modal.close_action=func(): close_modal(show_menu)
		modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(modal))

func respawn_player() -> void:
	cancel_input()
	if shared:
		app.network.send({"type":"respawn"})
	else:
		player.position=world.spawn_position()
		player.velocity=Vector2.ZERO
		player.punch_time=0
	close_modal()

func exit_world() -> void:
	if shared:
		app.network.close()
		app.navigate("worlds" if app.shared_selection else "multiplayer")
		return
	var result: Dictionary = app.session.leave()
	if result.ok:
		app.navigate("worlds")
	else:
		hud.show_message(result.error,8)

func toggle_chat() -> void:
	if not app.settings.get("chat",true) and not is_instance_valid(chat):
		hud.show_message("Chat is disabled in Options")
		return
	if is_instance_valid(chat):
		chat.queue_free()
		chat = null
		input.set_text_focus(false)
		set_chat_height(0)
		return
	if is_instance_valid(modal) or is_instance_valid(inventory):
		return
	input.set_text_focus(true)
	chat = LineEdit.new()
	chat.placeholder_text = "Local chat • type and press Enter"
	chat.max_length = 80
	add_child(chat)
	chat.text_submitted.connect(send_local_chat)
	set_chat_height(200)
	layout_overlays()
	chat.grab_focus()

func send_local_chat(text: String) -> void:
	var message := text.strip_edges()
	if not message.is_empty():
		if shared:
			app.network.send({"type":"chat","text":message})
			toggle_chat()
			return
		bubble = message
		player.begin_speech(message)
		bubble_time = clampf(2 + message.length() * 0.08,3,8)
		local_messages.append(player.display_name + ": " + message)
		while local_messages.size() > 8:
			local_messages.pop_front()
		chat_history.text = "\n".join(local_messages)
	toggle_chat()

func set_chat_height(height: float) -> void:
	if not app.settings.get("chat",true):
		height = 0
	chat_height = clampf(height,0,size.y * 0.7)
	if not is_instance_valid(chat_panel):
		return
	chat_panel.visible = chat_height > 24
	chat_panel.position = Vector2.ZERO
	chat_panel.size = Vector2(size.x * 0.94,maxf(chat_height,36))
	var chat_style:=UI.box(Color("226980ed"),5)
	chat_style.border_color=Color("98d9ed");chat_style.set_border_width_all(2)
	chat_style.content_margin_bottom=64 if is_instance_valid(chat) and chat.visible else 6
	chat_panel.add_theme_stylebox_override("panel",chat_style)
	hud.drawer.position.y = chat_height - 8
	if is_instance_valid(chat):
		chat.position = Vector2(20,maxf(36,chat_height - 62))
		chat.size = Vector2(size.x - 40,54)

func equip_outfit_item(id: int) -> void:
	var previous: Dictionary=player.catalog_equipment.duplicate()
	if not player.equip_catalog(id) or previous==player.catalog_equipment:return
	play_sound("audio/change_clothes.wav","wear")
	sync_outfit()

func unequip_outfit_item(slot: String) -> void:
	if not player.catalog_equipment.has(slot):return
	player.unequip_catalog(slot)
	play_sound("audio/change_clothes.wav","wear")
	sync_outfit()

func show_outfits() -> void:
	if is_instance_valid(modal):return
	if is_instance_valid(inventory):toggle_inventory()
	cancel_input()
	input.set_text_focus(true)
	modal=load("res://src/ui/motion_panel.gd").new()
	modal.name="OutfitPanel"
	modal.reduced_motion=not app.settings.get("animations",true)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	preload("res://src/ui/outfit_panel.gd").new().populate(UI.panel(modal,480),self)

func sync_outfit() -> void:
	var result: Dictionary=app.session.save_set()
	if not result.ok:hud.show_message(result.error,3)
	if is_instance_valid(inventory):
		inventory.worn = player.catalog_equipment.duplicate()
		inventory.refresh_equipment()
	if shared:
		app.network.send({"type":"outfit","equipment":player.catalog_equipment,"skin":player.skin_index,"item_options":preload("res://src/network/cosmetic_options.gd").sanitized(player.item_options)})

func receive_shared(packet: Dictionary) -> void:
	match packet.get("type"):
		"item_state":
			world.mark_visual(Vector2i(packet.x,packet.y))
			var key := item_runtime.key(world,Vector2i(packet.x,packet.y))
			if packet.data.is_empty():
				world.extras.erase(key)
			else:
				world.extras[key]=packet.data
			world.drops=packet.drops
			if is_instance_valid(item_status):
				item_status.text=describe_item(item_panel_tile)
		"projectiles":
			world.world_effects.projectiles=packet.shots
		"drops":
			world.drops=packet.drops
		"world_rules":
			world.world_effects.xenonite=packet.rules
			player.world_rules=packet.rules
		"world_state":
			world.restore(packet.world)
		"weather":
			world.weather = packet.key
		"world_exit":
			app.network.close()
			app.session.active = false
			app.navigate("worlds")
		"teleport":
			player.position = Vector2(packet.x,packet.y)
			player.velocity = Vector2.ZERO
		"broadcast":
			local_messages.append("[SB] %s (in %s): %s" % [packet.name,packet.world,packet.text])
			chat_history.text = "\n".join(local_messages.slice(-8))
		"notice":
			hud.show_message(packet.get("text",""),12)
		"snapshot":
			var seen: Array = []
			for row in packet.players:
				var id := int(row.id)
				if id == app.network.id:
					player.amba = row.get("amba",false)
					player.modifiers=row.get("modifiers",{})
					# Outfit is restored on join and changed locally; an older snapshot must not undo an equip.
					var target := Vector2(row.x,row.y)
					if player.position.distance_to(target)>60:
						player.position = target
					elif player.position.distance_to(target)>8:
						player.position = player.position.lerp(target,0.2)
					continue
				seen.append(id)
				if not remote_players.has(id):
					var other = load("res://src/game/player_state.gd").new()
					other.position = Vector2(row.x,row.y)
					var view = load("res://src/game/avatar_view.gd").new()
					add_child(view)
					move_child(view,guild_overlay.get_index())
					remote_players[id] = {"state":other,"avatar":view,"target":other.position,"bubble":"","bubble_time":0.0}
				var remote: Dictionary = remote_players[id]
				remote.target = Vector2(row.x,row.y)
				remote.state.velocity = Vector2(row.vx,row.vy)
				remote.state.facing = int(row.facing)
				remote.state.grounded = row.grounded
				remote.state.punch_time = float(row.punch)
				remote.state.burn_time=clampf(float(row.get("burn",0)),0,1.2)
				remote.state.death_time=float(row.get("death_time",-1))
				remote.state.catalog_equipment = preload("res://src/network/appearance.gd").equipment(row.equipment)
				remote.state.item_options=preload("res://src/network/cosmetic_options.gd").sanitized(row.get("item_options",{}))
				if int(row.get("death_epoch",0))!=remote.state.death_epoch:
					remote.state.death_epoch=int(row.death_epoch)
					remote.state.death_origin=Vector2(row.get("death_x",row.x),row.get("death_y",row.y))
					remote.state.death_profile=preload("res://src/game/death_sequence.gd").profile(remote.state)
				remote.state.punch_direction=Vector2(row.get("punch_dx",row.facing),row.get("punch_dy",0)).normalized()
				remote.state.punch_distance=float(row.get("punch_distance",36))
				remote.state.display_name = row.name
				remote.state.amba = row.get("amba",false)
				remote.state.skin_index = clampi(int(row.get("skin",0)),0,5)
				remote.state.modifiers=row.get("modifiers",{})
			for id in remote_players.keys():
				if id not in seen:
					remote_players[id].avatar.queue_free()
					remote_players.erase(id)
		"tile":
			shared_tile_updates += 1
			if packet.get("layer") == "background":
				world.set_background(Vector2i(packet.x,packet.y),int(packet.item))
			else:
				world.set_tile(Vector2i(packet.x,packet.y),int(packet.item))
		"effect":
			var event: Dictionary = packet.event.duplicate()
			event.tile = Vector2i(event.tile[0],event.tile[1])
			if event.type == "punch_started":
				if int(packet.id) != app.network.id:
					play_sound(MaterialAudio.impact(int(event.get("item_id",world.tile_at(event.tile))),bool(event.get("protected",false))),"punch")
					if remote_players.has(int(packet.id)):remote_players[int(packet.id)].state.begin_punch(Vector2(event.tile)*32+Vector2(16,16))
			else:
				receive_event(event)
		"chat":
			local_messages.append(packet.name+": "+packet.text)
			chat_history.text = "\n".join(local_messages.slice(-8))
			var seconds := clampf(2+packet.text.length()*0.08,3,8)
			if int(packet.id) == app.network.id:
				bubble = packet.text
				player.begin_speech(packet.text)
				bubble_time = seconds
			elif remote_players.has(int(packet.id)):
				remote_players[int(packet.id)].state.begin_speech(packet.text)
				remote_players[int(packet.id)].bubble = packet.text
				remote_players[int(packet.id)].bubble_time = seconds

func layout_overlays() -> void:
	if is_instance_valid(inventory):
		var height := inventory_height()
		inventory.position = Vector2(12,size.y-(height+8)*inventory_fraction)
		inventory.size = Vector2(size.x-24,height)
	if is_instance_valid(chat):
		set_chat_height(chat_height)

