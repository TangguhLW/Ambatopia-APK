extends Control

var route := "menu"
var screen: Control
var profile := {"id": "local", "display_name": "Player"}
var last_error := ""
var session = preload("res://src/game/local_session.gd").new()
var settings := {"schema_version": 1, "master": 0.7, "effects": 0.7, "music":0.7, "chat":true, "animations":true,"graphics":"normal","fps":60}
var settings_store = preload("res://src/storage/local_store.gd").new()
var audio_feedback
var network
var accounts
var shared_selection := false

func _ready() -> void:
	if OS.get_cmdline_args().has("--server"):
		add_child(load("res://server/runtime.gd").new())
		return
	get_tree().auto_accept_quit = false
	var asset_failures: Array[String]=preload("res://src/diagnostics/resource_check.gd").verify()
	if not asset_failures.is_empty():
		var diagnostic:=Label.new()
		diagnostic.text="The game resources are incomplete.\nPlease use a complete build.\n\n"+"\n".join(asset_failures)
		diagnostic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(diagnostic)
		push_error(diagnostic.text)
		return
	theme = preload("res://src/ui/theme.gd").build()
	settings_store.directory = "user://preferences"
	var saved: Dictionary = settings_store.load_slot("settings")
	if saved.ok:
		for key in ["master", "effects", "music"]:
			settings[key] = clampf(float(saved.data.get(key, 0.7)), 0, 1)
		for key in ["chat","animations"]:
			settings[key] = bool(saved.data.get(key,true))
		settings.graphics = "low" if saved.data.get("graphics") == "low" else "normal"
		settings.fps = int(saved.data.get("fps",60)) if int(saved.data.get("fps",60)) in [30,60,120] else 60
	Engine.max_fps = settings.fps
	audio_feedback = load("res://src/ui/audio_feedback.gd").new()
	audio_feedback.app = self
	add_child(audio_feedback)
	accounts = load("res://src/network/accounts.gd").new()
	add_child(accounts)
	network = load("res://src/network/supabase_client.gd" if accounts.cloud_enabled else "res://src/network/client.gd").new()
	if accounts.cloud_enabled:
		network.accounts=accounts
		network.app=self
	add_child(network)
	network.received.connect(receive_network)
	navigate("menu")
	if OS.get_name()=="Windows" and OS.get_cmdline_args().has("--live-preview"):
		var live=load("res://src/diagnostics/live_preview.gd").new()
		live.app=self
		add_child(live)
	if not OS.get_cmdline_args().has("--script") and not OS.get_cmdline_args().has("--qa-run") and not FileAccess.file_exists("user://qa-request.json") and DisplayServer.get_name() != "headless":
		show_title_intro()
	if OS.get_cmdline_args().has("--qa-run") or OS.get_cmdline_user_args().has("--qa-run") or FileAccess.file_exists("user://qa-request.json"):
		if FileAccess.file_exists("user://qa-request.json"):
			var request_text := FileAccess.get_file_as_string("user://qa-request.json")
			var request = JSON.parse_string(request_text) if request_text.begins_with("{") else {}
			if request is Dictionary:
				set_meta("qa_network",request.get("network",false))
			DirAccess.remove_absolute("user://qa-request.json")
		var runner = load("res://src/diagnostics/qa_runner.gd").new()
		runner.app = self
		add_child(runner)

func navigate(destination: String) -> void:
	if destination not in ["menu", "options", "about", "download", "terms", "login", "worlds", "play","multiplayer"]:
		last_error = "Unknown page"
		return
	theme=preload("res://src/ui/theme.gd").build()
	preload("res://src/ui/theme.gd").source_bounds.clear()
	preload("res://src/game/simulator_catalog.gd").sprites.clear()
	preload("res://src/game/simulator_catalog.gd").local_sprites.clear()
	if is_instance_valid(screen):
		if screen.has_method("cancel_input"):
			screen.cancel_input()
		remove_child(screen)
		screen.queue_free()
	route = destination
	var script_path: String = {"menu": "main_menu", "options": "dialog", "about": "dialog", "download":"dialog", "terms":"dialog", "login": "login", "worlds": "world_select", "play": "../game/world_view","multiplayer":"multiplayer"}[destination]
	screen = load("res://src/ui/" + script_path + ".gd").new()
	screen.app = self
	if destination in ["options", "about", "download", "terms"]:
		screen.kind = destination
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	audio_feedback.set_page(destination)
	if settings.animations and destination != "play" and not get_meta("visual_freeze",false):
		screen.modulate.a = 0
		var motion := create_tween()
		motion.tween_property(screen,"modulate:a",1.0,0.22)
		var start_x := screen.position.x
		screen.position.x = start_x - 24
		motion.parallel().tween_property(screen,"position:x",start_x,0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func show_title_intro() -> void:
	var cover := ColorRect.new()
	cover.color = Color("143943")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var title := TextureRect.new()
	title.texture = load("res://assets/ambatopia/title.png")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.offset_left = 30
	title.offset_right = -30
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.modulate.a = 0
	cover.add_child(title)
	var fade := create_tween()
	fade.tween_property(title,"modulate:a",1.0,0.45)
	fade.tween_interval(0.3)
	fade.tween_property(cover,"modulate:a",0.0,0.4)
	fade.tween_callback(cover.queue_free)

func start_local(display_name: String) -> void:
	shared_selection = false
	profile = {"id": "local", "display_name": display_name.strip_edges().left(18)}
	set_meta("profile_active",true)
	navigate("worlds")

func enter_world(world_name: String) -> Dictionary:
	if shared_selection:
		var error: int = network.connect_room("ws://127.0.0.1:4192",profile.display_name,world_name,accounts.access_token)
		return {"ok":error == OK,"error":"Could not connect to game server." if error != OK else ""}
	var result: Dictionary = session.enter(profile, world_name)
	if result.ok:
		navigate("play")
	return result

func save_settings() -> void:
	settings_store.save("settings", settings)

func prepare_close() -> Dictionary:
	if network != null and network.active:
		if session.player!=null:session.save_set()
		network.close()
		session.active = false
		return {"ok":true,"error":""}
	return session.save() if session.active else {"ok": true, "error": ""}

func receive_network(packet: Dictionary) -> void:
	if packet.get("type") == "welcome":
		session.world = load("res://src/game/world_state.gd").new()
		if not session.world.restore(packet.world):
			network.close()
			return
		session.player = load("res://src/game/player_state.gd").new()
		session.player.developer = accounts.profile.get("role") == "developer"
		session.player.display_name = network.join_packet.name
		session.player.position = session.world.spawn_position()
		session.player.grounded = true
		for row in packet.get("players",[]):
			if int(row.id) == network.id:
				session.player.display_name = row.name
				session.player.catalog_equipment = preload("res://src/network/appearance.gd").equipment(row.equipment)
				session.player.skin_index = int(row.get("skin",0))
		session.restore_set({"id":str(accounts.profile.get("id",network.join_packet.name)),"display_name":session.player.display_name})
		session.active = false
		navigate("play")
		network.send({"type":"outfit","equipment":session.player.catalog_equipment,"skin":session.player.skin_index,"item_options":preload("res://src/network/cosmetic_options.gd").sanitized(session.player.item_options)})

func go_back() -> void:
	if route == "play":
		screen.show_menu()
	elif route == "multiplayer":
		network.close()
		navigate("login")
	elif route != "menu":
		navigate("menu")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if has_meta("qa_stage"):print("QA_WINDOW_CLOSE_REQUEST stage=",get_meta("qa_stage"))
		var result := prepare_close()
		if result.ok:
			get_tree().quit()
		elif is_instance_valid(screen) and route == "play":
			screen.hud.status.text = result.error
