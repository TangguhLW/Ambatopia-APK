extends "res://src/network/client.gd"

var accounts
var app
var topics: Dictionary={}
var peers: Dictionary={}
var clock:=0.0
var heartbeat_clock:=0.0
var roster_clock:=0.0
var motion_clock:=0.0
var action_clock:=0.0
var roster_busy:=false
var command_busy:=false
var token_seen:=""
var sample_sequence:=0
var peer_sequences: Dictionary={}
var generation:=0
var pending_commands: Array[Dictionary]=[]
var event_cursor:=0
var event_clock:=0.0
var events_busy:=false
var last_motion: Dictionary={}

static func motion_changed(previous: Dictionary,current: Dictionary) -> bool:
	for key in current:
		if previous.get(key)!=current[key]:return true
	return false

func connect_room(_url: String,name: String,world_name: String,_token: String="") -> Error:
	close()
	if accounts.access_token.is_empty():return ERR_UNAUTHORIZED
	if not world_name.is_valid_identifier() or world_name.length()>18:return ERR_INVALID_PARAMETER
	join_packet={"type":"join","name":name,"world":world_name.to_upper()}
	active=true
	begin_join(generation)
	return OK

func begin_join(ticket: int):
	var result: Dictionary=await accounts.database_call("game_join",{"p_world":join_packet.world})
	if ticket!=generation:return
	if not result.get("ok",false):
		received.emit({"ok":false,"error":result.get("error","Could not join world")})
		close()
		return
	id=int(result.data.id)
	event_cursor=int(result.data.get("cursor",0))
	result.data.players=[{"id":id,"name":join_packet.name,"equipment":accounts.profile.get("outfit",{}),"skin":accounts.profile.get("settings",{}).get("skin",0)}]
	socket=WebSocketPeer.new()
	socket.inbound_buffer_size=2097152
	socket.outbound_buffer_size=65536
	var url: String=accounts.cloud_url.replace("https://","wss://")+"/realtime/v1/websocket?apikey="+accounts.cloud_key.uri_encode()+"&vsn=1.0.0"
	if socket.connect_to_url(url)!=OK:
		close();disconnected.emit();return
	set_meta("welcome",result.data)

func close() -> void:
	generation+=1
	if active and accounts!=null and not accounts.access_token.is_empty():
		accounts.database_call("game_leave",{"p_player_id":id})
	super.close()
	topics.clear();peers.clear();peer_sequences.clear();pending_commands.clear()
	roster_busy=false;command_busy=false
	events_busy=false;event_cursor=0;event_clock=0
	heartbeat_clock=0;roster_clock=0;motion_clock=0;action_clock=0
	last_motion.clear()
	remove_meta("welcome")

func frame(topic: String,event: String,payload: Dictionary) -> void:
	if socket!=null and socket.get_ready_state()==WebSocketPeer.STATE_OPEN:
		seq+=1
		socket.send_text(JSON.stringify({"topic":topic,"event":event,"payload":payload,"ref":str(seq)}))

func subscribe(topic: String,uid: String="") -> void:
	if topics.has(topic):return
	topics[topic]={"uid":uid,"ready":false}
	frame(topic,"phx_join",{"config":{"private":true,"broadcast":{"ack":false,"self":false},"presence":{"enabled":false}},"access_token":accounts.access_token})

func ready_channels() -> void:
	subscribe("realtime:game:"+join_packet.world)
	subscribe("realtime:motion:"+join_packet.world+":"+accounts.profile.id,accounts.profile.id)

func _process(dt: float) -> void:
	if not active or socket==null:return
	socket.poll()
	if socket.get_ready_state()==WebSocketPeer.STATE_CLOSED:
		close();disconnected.emit();return
	if socket.get_ready_state()!=WebSocketPeer.STATE_OPEN:return
	if topics.is_empty():
		socket.set_no_delay(true)
		ready_channels()
	while socket.get_available_packet_count()>0:
		var bytes:=socket.get_packet()
		if bytes.size()>2097152:continue
		var packet=JSON.parse_string(bytes.get_string_from_utf8())
		if packet is Dictionary:accept_frame(packet)
	clock+=dt;heartbeat_clock+=dt;roster_clock+=dt;motion_clock+=dt;action_clock+=dt
	if clock>=20:
		clock=0;frame("phoenix","heartbeat",{})
	if token_seen!=accounts.access_token:
		token_seen=accounts.access_token
		for topic in topics:frame(topic,"access_token",{"access_token":token_seen})
	if not connected:return
	event_clock+=dt
	if event_clock>=0.8:
		event_clock=0
		fetch_events(generation)
	if roster_clock>=3 and not roster_busy:
		roster_clock=0;refresh_roster(generation)
	if heartbeat_clock>=8:
		heartbeat_clock=0;heartbeat()
	if motion_clock>=0.1 and app.session.player!=null:
		var p=app.session.player
		var sample={"x":p.position.x,"y":p.position.y,"vx":p.velocity.x,"vy":p.velocity.y,"facing":p.facing,"grounded":p.grounded,"punch":p.punch_time,"punch_dx":p.punch_direction.x,"punch_dy":p.punch_direction.y}
		sample.burn=p.burn_time
		sample.item_options=preload("res://src/network/cosmetic_options.gd").sanitized(p.item_options)
		sample.death_time=p.death_time;sample.death_epoch=p.death_epoch
		sample.punch_distance=clampf(p.punch_distance,0,160)
		sample.death_x=p.death_origin.x;sample.death_y=p.death_origin.y
		if motion_changed(last_motion,sample) or motion_clock>=5:
			motion_clock=0
			last_motion=sample.duplicate()
			sample_sequence+=1
			sample.seq=sample_sequence
			frame("realtime:motion:"+join_packet.world+":"+accounts.profile.id,"broadcast",{"type":"broadcast","event":"motion","payload":sample})
	if not command_busy and not pending_commands.is_empty():
		run_command(pending_commands.pop_front(),generation)
	if latest.get("action","none") in ["punch","place"] and action_clock>=0.22 and not command_busy:
		action_clock=0
		var command={"type":latest.action,"x":latest.x,"y":latest.y,"item":latest.item}
		if latest.get("direct",false):
			var p=app.session.player
			var target:=Vector2i((p.position+Vector2(p.facing*36,-16))/32)
			command.x=target.x;command.y=target.y
		run_command(command,generation)

func accept_frame(packet: Dictionary) -> void:
	var topic: String=packet.get("topic","")
	if not topics.has(topic):return
	var payload=packet.get("payload",{})
	if not payload is Dictionary:return
	if packet.get("event")=="phx_reply":
		if payload.get("status")=="error":
			received.emit({"ok":false,"error":"Private multiplayer channel was denied."})
			close();disconnected.emit();return
		if payload.get("status")=="ok":
			topics[topic].ready=true
			if topic=="realtime:game:"+join_packet.world and not connected:
				connected=true
				received.emit(get_meta("welcome"))
				refresh_roster(generation)
	elif packet.get("event") in ["phx_error","phx_close"]:
		close();disconnected.emit()
	elif packet.get("event")=="broadcast":
		var data=payload.get("payload",{})
		if not data is Dictionary:return
		if topic=="realtime:game:"+join_packet.world and payload.get("event")=="packet":
			fetch_events(generation)
		elif payload.get("event")=="motion":
			accept_motion(str(topics[topic].uid),data)

func accept_motion(uid: String,data: Dictionary) -> void:
	if not peers.has(uid) or uid==accounts.profile.id:return
	if not preload("res://src/network/cosmetic_options.gd").valid(data.get("item_options",{})):return
	for field in ["seq","x","y","vx","vy","facing","punch"]:
		if not (data.get(field) is int or data.get(field) is float) or not is_finite(float(data[field])):return
	if int(data.seq)<=int(peer_sequences.get(uid,-1)) or not data.get("grounded") is bool:return
	if data.has("burn"):
		if not (data.burn is int or data.burn is float) or not is_finite(float(data.burn)) or float(data.burn)<0 or float(data.burn)>1.2:return
	if data.has("punch_distance"):
		if not (data.punch_distance is int or data.punch_distance is float) or not is_finite(float(data.punch_distance)) or float(data.punch_distance)<0 or float(data.punch_distance)>160:return
	if data.has("death_time"):
		for key in ["death_time","death_epoch","death_x","death_y"]:
			if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])):return
		if float(data.death_time)<-1 or float(data.death_time)>10 or float(data.death_epoch)<0 or float(data.death_epoch)!=int(data.death_epoch) or float(data.death_epoch)>10000000:return
		if float(data.death_x)<0 or float(data.death_x)>3200 or float(data.death_y)<0 or float(data.death_y)>1920:return
	if int(data.facing) not in [-1,1] or data.punch<0 or data.punch>preload("res://src/game/player_state.gd").PUNCH_DURATION:return
	if data.x<0 or data.x>3200 or data.y<0 or data.y>1920 or absf(data.vx)>2000 or absf(data.vy)>2000:return
	if data.has("punch_dx") or data.has("punch_dy"):
		for key in ["punch_dx","punch_dy"]:
			if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or absf(data[key])>1.001:return
		var direction:=Vector2(data.punch_dx,data.punch_dy)
		if direction.length_squared()<0.9 or direction.length_squared()>1.1:return
		peers[uid].punch_dx=direction.x
		peers[uid].punch_dy=direction.y
	peer_sequences[uid]=int(data.seq)
	for field in ["x","y","vx","vy","facing","grounded","punch"]:peers[uid][field]=data[field]
	peers[uid].burn=float(data.get("burn",0))
	peers[uid].item_options=data.get("item_options",{}).duplicate(true)
	peers[uid].punch_distance=float(data.get("punch_distance",36))
	for key in ["death_time","death_epoch","death_x","death_y"]:
		if data.has(key):peers[uid][key]=data[key]
	# Account/name/outfit/role come from SQL, never another player's broadcast.
	emit_snapshot()

func emit_snapshot():
	var rows: Array=[]
	for uid in peers:
		if uid!=accounts.profile.id:rows.append(peers[uid])
	received.emit({"type":"snapshot","players":rows})

func refresh_roster(ticket: int):
	roster_busy=true
	var result: Dictionary=await accounts.database_call("game_roster",{"p_world":join_packet.world})
	if ticket!=generation:return
	roster_busy=false
	if not result.ok:return
	var seen: Array=[]
	for row in result.data:
		var uid: String=row.uid
		seen.append(uid)
		if peers.has(uid):
			for field in ["x","y","vx","vy","facing","grounded","punch","burn","punch_dx","punch_dy","punch_distance","death_time","death_epoch","death_x","death_y","item_options"]:
				if peers[uid].has(field):row[field]=peers[uid][field]
		peers[uid]=row
		if uid!=accounts.profile.id:subscribe("realtime:motion:"+join_packet.world+":"+uid,uid)
	for uid in peers.keys():
		if uid not in seen:
			peers.erase(uid);peer_sequences.erase(uid)
			var topic: String="realtime:motion:"+join_packet.world+":"+uid
			frame(topic,"phx_leave",{});topics.erase(topic)
	emit_snapshot()

func heartbeat() -> Dictionary:
	if app.session.player==null:return {"ok":false}
	var p=app.session.player
	return await accounts.database_call("game_heartbeat",{"p_x":p.position.x,"p_y":p.position.y,"p_player_id":id})

func send(packet: Dictionary) -> void:
	if not connected:return
	if not command_busy:run_command(packet,generation)
	elif pending_commands.size()<8:pending_commands.append(packet.duplicate(true))
	else:received.emit({"type":"notice","text":"Connection busy. Please retry the action."})

func run_command(packet: Dictionary,ticket: int):
	command_busy=true
	packet.session=id
	packet.cursor=event_cursor
	if packet.type in ["punch","place"]:await heartbeat()
	if ticket!=generation:return
	var result: Dictionary=await accounts.database_call("game_command",{"p_command":packet})
	if ticket!=generation:return
	command_busy=false
	if not result.ok:
		received.emit({"type":"notice","text":result.get("error","Action could not be saved")})
	elif result.data is Dictionary:
		if result.data.has("events"):ingest_events(result.data.events)
		elif result.data.get("type") in ["teleport","world_exit"]:received.emit(result.data)
		else:fetch_events(generation)

func fetch_events(ticket: int):
	if not connected or events_busy:return
	events_busy=true
	var result: Dictionary=await accounts.database_call("game_events",{"p_after":event_cursor})
	if ticket!=generation:return
	events_busy=false
	if result.ok and result.data is Dictionary:ingest_events(result.data.get("events",[]))

func ingest_events(rows: Array):
	for entry in rows:
		if not entry is Dictionary or int(entry.get("sequence",0))<=event_cursor:continue
		event_cursor=int(entry.sequence)
		if entry.get("packet") is Dictionary:received.emit(entry.packet)
