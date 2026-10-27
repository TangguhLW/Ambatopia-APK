extends Node

const Core = preload("res://src/network/room_server.gd")
var core := Core.new()
var tcp := TCPServer.new()
var peers: Dictionary = {}
var last_id := 0
var accumulator := 0.0
var snapshots := 0.0
var saves := 0.0
var internal_token := ""
var qa_mode := false
var joining: Dictionary = {}
var saving: Dictionary = {}
var presence_elapsed := 0.0
var checking_status := false

func refresh_status() -> void:
	if checking_status:
		return
	checking_status = true
	var ids: Array = []
	for player in core.players.values():
		if player.uid != "":
			ids.append(player.uid)
	var response := await account_request("/internal/status",{"ids":ids})
	for row in response.get("players",[]):
		for id in core.players:
			var entry: Dictionary = core.players[id]
			if entry.uid != row.id:
				continue
			if row.banned_until != null and Time.get_unix_time_from_datetime_string(str(row.banned_until).left(19))>Time.get_unix_time_from_system():
				peers[id].socket.close(1008,"Account restricted")
			entry.moderator = row.settings.get("moderator",false)
			entry.muted = Time.get_unix_time_from_datetime_string(str(row.settings.get("muted_until","1970-01-01T00:00:00")).left(19)) > Time.get_unix_time_from_system()
			var warning: String = row.settings.get("warning","")
			if warning != "" and entry.get("last_warning","") != warning:
				entry.last_warning = warning
				peers[id].socket.send_text(JSON.stringify({"type":"notice","text":warning}))
	checking_status = false

func account_request(path: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15
	add_child(http)
	var error := http.request("http://127.0.0.1:4193"+path,PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+internal_token]),HTTPClient.METHOD_POST,JSON.stringify(body))
	if error != OK:
		http.queue_free()
		return {}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[1] < 200 or response[1] >= 300:
		return {}
	var result = JSON.parse_string(response[3].get_string_from_utf8())
	return result if result is Dictionary else {}

func join_authenticated(id: int, packet: Dictionary) -> void:
	if joining.has(id):
		return
	joining[id] = true
	var result := {"ok":false,"error":"Please log in with an AmbaID."}
	var identity: Dictionary = {}
	if packet.get("token") is String:
		var verified := await account_request("/auth/verify",{"token":packet.token})
		identity = verified.get("profile",{})
	if not peers.has(id):
		joining.erase(id)
		return
	if not identity.is_empty() or qa_mode:
		var world_name: String = packet.world.strip_edges().to_upper()
		var stored := await account_request("/internal/world",{"name":world_name}) if not qa_mode else {}
		if not peers.has(id):
			joining.erase(id)
			return
		if not qa_mode and not stored.has("world"):
			peers[id].socket.send_text(JSON.stringify({"ok":false,"error":"World storage is unavailable. Please retry."}))
			joining.erase(id)
			return
		if not core.rooms.has(world_name) and stored.get("world") is Dictionary:
			var world = load("res://src/game/world_state.gd").new()
			if world.restore(stored.world.state):
				core.rooms[world_name] = {"world":world,"owner":0,"owner_uid":stored.world.get("owner_id","") if stored.world.get("owner_id") != null else ""}
		result = core.join(id,identity.get("amba_id",packet.name),world_name,identity)
	peers[id].socket.send_text(JSON.stringify(result))
	joining.erase(id)

func save_room(name: String) -> void:
	if qa_mode or not core.rooms.has(name) or saving.has(name):
		return
	saving[name] = true
	var room: Dictionary = core.rooms[name]
	var result := await account_request("/internal/world",{"name":name,"state":room.world.serialize(),"owner_id":room.get("owner_uid","")})
	if not result.get("ok",false):
		push_warning("World save unavailable: " + name)
	saving.erase(name)

func _ready() -> void:
	qa_mode = OS.get_cmdline_args().has("--qa-server")
	internal_token = OS.get_environment("GAME_INTERNAL_TOKEN")
	if not qa_mode and internal_token.length()<32:
		push_error("Private account service configuration required")
		get_tree().quit(1)
		return
	if not qa_mode and FileAccess.file_exists("user://broadcast-cooldowns.json"):
		var stored = JSON.parse_string(FileAccess.get_file_as_string("user://broadcast-cooldowns.json"))
		if stored is Dictionary:
			core.broadcasts = stored
	Engine.max_fps = 60
	var listen_port:=4192
	if qa_mode and OS.get_environment("GAME_QA_PORT").is_valid_int():listen_port=clampi(int(OS.get_environment("GAME_QA_PORT")),1024,65535)
	var error := tcp.listen(listen_port,"127.0.0.1")
	if error != OK:
		push_error("Local multiplayer listen failed: " + str(error))
		get_tree().quit(1)
	else:
		print("LOCAL_GAME_SERVER_READY 127.0.0.1:%d capacity=64" % listen_port)

func _process(dt: float) -> void:
	while tcp.is_connection_available():
		var stream := tcp.take_connection()
		if peers.size()>=64:
			stream.disconnect_from_host()
			continue
		last_id += 1
		var peer := WebSocketPeer.new()
		peer.inbound_buffer_size = 8192
		peer.outbound_buffer_size = 2097152
		peer.max_queued_packets = 64
		if peer.accept_stream(stream) == OK:
			peers[last_id] = {"socket":peer,"started":Time.get_ticks_msec(),"rate_start":Time.get_ticks_msec(),"rate":0}
			peers[last_id].ip = stream.get_connected_host()
	for id in peers.keys():
		var entry: Dictionary = peers[id]
		var peer: WebSocketPeer = entry.socket
		peer.poll()
		if peer.get_ready_state() == WebSocketPeer.STATE_CLOSED or not core.players.has(id) and not joining.has(id) and Time.get_ticks_msec()-entry.started>30000:
			if core.players.has(id):
				save_room(core.players[id].room)
				if not qa_mode:
					account_request("/internal/profile",{"id":core.players[id].uid,"outfit":core.players[id].state.catalog_equipment,"skin":core.players[id].state.skin_index,"collected":core.players[id].state.collected,"seconds":int((Time.get_ticks_msec()-core.players[id].joined)/1000)})
			core.leave(id)
			peers.erase(id)
			continue
		if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
			continue
		while peer.get_available_packet_count()>0:
			var bytes := peer.get_packet()
			if Time.get_ticks_msec()-entry.rate_start>1000:
				entry.rate = 0
				entry.rate_start = Time.get_ticks_msec()
			entry.rate += 1
			if bytes.size()>4096 or entry.rate>100 or not peer.was_string_packet():
				peer.close(1008,"Packet limit")
				break
			var packet = JSON.parse_string(bytes.get_string_from_utf8())
			if not packet is Dictionary:
				continue
			if packet.get("type") == "join" and not core.players.has(id):
				if not packet.get("name") is String or not packet.get("world") is String:
					continue
				join_authenticated(id,packet)
			else:
				core.accept(id,packet)
	accumulator = minf(accumulator+dt,5.0/60)
	while accumulator>=1.0/60:
		core.step(1.0/60)
		accumulator -= 1.0/60
	for event in core.events:
		if event.type == "broadcast" and not qa_mode:
			var file := FileAccess.open("user://broadcast-cooldowns.json",FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(core.broadcasts))
		broadcast(event.room,event)
		if event.type == "world_exit" and peers.has(int(event.target)):
			peers[int(event.target)].socket.close(1000,"World owner action")
	core.events.clear()
	saves += dt
	presence_elapsed += dt
	if presence_elapsed > 5 and not qa_mode:
		presence_elapsed = 0
		var world_rows: Array = []
		var player_rows: Array = []
		for name in core.rooms:
			world_rows.append({"name":name,"count":core.snapshot(name).size()})
		for id in core.players:
			player_rows.append({"id":core.players[id].uid,"ip":peers[id].ip,"seconds":int((Time.get_ticks_msec()-core.players[id].joined)/1000)})
		account_request("/internal/presence",{"worlds":world_rows,"players":player_rows})
		refresh_status()
	if saves > 15 and not qa_mode:
		saves = 0
		for room in core.rooms:
			save_room(room)
	snapshots += dt
	if snapshots>=0.05:
		snapshots = 0
		for room in core.rooms:
			broadcast(room,{"type":"snapshot","players":core.snapshot(room)})

func broadcast(room: String, packet: Dictionary) -> void:
	var encoded := JSON.stringify(packet)
	for id in core.players:
		if (room == "*" or core.players[id].room == room) and peers.has(id) and (not packet.has("target") or int(packet.target) == id):
			var peer: WebSocketPeer = peers[id].socket
			if peer.get_current_outbound_buffered_amount()<131072:
				peer.send_text(encoded)
			else:
				peer.close(1008,"Slow connection")
