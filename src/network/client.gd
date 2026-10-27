extends Node

signal received(packet: Dictionary)
signal disconnected
var socket: WebSocketPeer
var active := false
var connected := false
var id := 0
var join_packet: Dictionary = {}
var seq := 0
var elapsed := 0.0
var latest: Dictionary = {"axis":0.0,"action":"none"}
var jump_pending := false
var joined_sent := false
var server_url := ""
var retries := 0
var retry_at := 0

func connect_room(url: String, name: String, world: String, token: String = "") -> Error:
	close()
	if not url.begins_with("ws://127.0.0.1:"):
		return ERR_UNAUTHORIZED
	socket = WebSocketPeer.new()
	socket.inbound_buffer_size = 2097152
	socket.outbound_buffer_size = 16384
	socket.max_queued_packets = 128
	var error := socket.connect_to_url(url)
	if error != OK:
		return error
	join_packet = {"type":"join","name":name,"world":world}
	if not token.is_empty():
		join_packet.token = token
	server_url = url
	retries = 0
	retry_at = 0
	active = true
	return OK

func close() -> void:
	if socket != null:
		socket.close()
	socket = null
	active = false
	connected = false
	id = 0
	seq = 0
	joined_sent = false
	jump_pending = false
	latest = {"axis":0.0,"action":"none"}

func send(packet: Dictionary) -> void:
	if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(packet))

func submit(state: Dictionary, item: int) -> void:
	jump_pending = jump_pending or state.get("jump_pressed",false)
	var target: Vector2i = state.get("target",Vector2i.ZERO)
	latest = {"type":"input","axis":state.get("axis",0.0),"action":state.get("action","none"),"direct":state.get("direct_punch",false),"x":target.x,"y":target.y,"item":item}

func _process(dt: float) -> void:
	if not active or socket == null:
		return
	socket.poll()
	if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		if not connected and retries < 4:
			if retry_at == 0:
				retry_at = Time.get_ticks_msec()+200*(retries+1)
			if Time.get_ticks_msec() >= retry_at:
				retries += 1
				retry_at = 0
				joined_sent = false
				socket.connect_to_url(server_url)
			return
		close()
		disconnected.emit()
		return
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not joined_sent:
		socket.set_no_delay(true)
		send(join_packet)
		joined_sent = true
	while socket.get_available_packet_count()>0:
		var data := socket.get_packet()
		if data.size()>2097152:
			continue
		var packet = JSON.parse_string(data.get_string_from_utf8())
		if not packet is Dictionary:
			continue
		if packet.get("type") == "welcome":
			connected = true
			id = int(packet.id)
		received.emit(packet)
	elapsed += dt
	if connected and elapsed>=0.05:
		elapsed = 0
		seq += 1
		latest.type = "input"
		latest.seq = seq
		latest.jump = jump_pending
		send(latest)
		jump_pending = false
