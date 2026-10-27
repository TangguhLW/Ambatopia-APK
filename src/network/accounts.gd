extends Node

var access_token := ""
var refresh_token := ""
var profile: Dictionary = {}
var refreshing := false
var refresh_elapsed := 0.0
var cloud_enabled:=false
var cloud_url:=""
var cloud_key:=""

func _ready():
	if not FileAccess.file_exists("res://data/network.json"):return
	var config=JSON.parse_string(FileAccess.get_file_as_string("res://data/network.json"))
	if not config is Dictionary:return
	cloud_url=str(config.get("url",""))
	cloud_key=str(config.get("publishable_key",""))
	cloud_enabled=config.get("enabled",false) and cloud_url=="https://hbptqogoihmguhdizqcf.supabase.co" and not cloud_key.is_empty()

func cloud_request(path: String,payload: Dictionary={},method: int=HTTPClient.METHOD_POST) -> Dictionary:
	var http:=HTTPRequest.new()
	http.timeout=15
	add_child(http)
	var headers:=PackedStringArray(["Content-Type: application/json","apikey: "+cloud_key])
	if not access_token.is_empty():headers.append("Authorization: Bearer "+access_token)
	var error:=http.request(cloud_url+path,headers,method,"" if method==HTTPClient.METHOD_GET else JSON.stringify(payload))
	if error!=OK:
		http.queue_free();return {"ok":false,"error":"Supabase connection could not start."}
	var response: Array=await http.request_completed
	http.queue_free()
	var text: String=response[3].get_string_from_utf8()
	var data=null
	if not text.is_empty():
		var parser:=JSON.new()
		if parser.parse(text)!=OK:return {"ok":false,"error":"Supabase returned an invalid response."}
		data=parser.data
	if response[0]!=HTTPRequest.RESULT_SUCCESS or int(response[1])<200 or int(response[1])>=300:
		return {"ok":false,"error":str(data.get("msg",data.get("message",data.get("error_description","Supabase request failed.")))) if data is Dictionary else "Supabase request failed."}
	return {"ok":true,"data":data}

func database_call(name: String,payload: Dictionary) -> Dictionary:
	if name not in ["game_join","game_leave","game_heartbeat","game_roster","game_world_list","game_command","game_events"]:
		return {"ok":false,"error":"Unknown game request"}
	return await cloud_request("/rest/v1/rpc/"+name,payload)

func request(path: String, payload: Dictionary = {}, method: int = HTTPClient.METHOD_POST) -> Dictionary:
	if cloud_enabled:
		if path=="/worlds":
			var worlds_result:=await database_call("game_world_list",{})
			return {"ok":worlds_result.ok,"worlds":worlds_result.get("data",[]),"error":worlds_result.get("error","")}
		if path=="/online":
			if access_token.is_empty():return {"ok":true,"online":0}
			var online_result:=await database_call("game_world_list",{})
			var total:=0
			for world_row in online_result.get("data",[]):total+=int(world_row.count)
			return {"ok":online_result.ok,"online":total}
		if path=="/auth/refresh":
			return await cloud_session("/auth/v1/token?grant_type=refresh_token",payload)
		return {"ok":false,"error":"This request is not available on Supabase yet."}
	var http := HTTPRequest.new()
	http.timeout = 15
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not access_token.is_empty():
		headers.append("Authorization: Bearer " + access_token)
	var error := http.request("http://127.0.0.1:4193"+path,headers,method,"" if method == HTTPClient.METHOD_GET else JSON.stringify(payload))
	if error != OK:
		http.queue_free()
		return {"ok":false,"error":"Account server is unavailable."}
	var result: Array = await http.request_completed
	http.queue_free()
	var parser:=JSON.new()
	if parser.parse(result[3].get_string_from_utf8())!=OK or not parser.data is Dictionary:
		return {"ok":false,"error":"Account server is unavailable. Start the local account service."}
	var data: Dictionary=parser.data
	if not data is Dictionary:
		return {"ok":false,"error":"Account server is unavailable. Start the local account service."}
	data.ok = result[1] >= 200 and result[1] < 300
	return data

func authenticate(name: String, secret: String, register: bool) -> Dictionary:
	if cloud_enabled:
		var name_pattern:=RegEx.new()
		name_pattern.compile("^[A-Za-z0-9_]{3,18}$")
		if name_pattern.search(name)==null or secret.length()<10 or secret.to_utf8_buffer().size()>72:
			return {"ok":false,"error":"Use a 3–18 character AmbaID and a password of 10–72 bytes."}
		var cloud_result: Dictionary
		if register:
			cloud_result=await cloud_session("/auth/v1/signup",{"email":name.to_lower()+"@players.ambatopia.invalid","password":secret,"data":{"amba_id":name}})
		else:
			cloud_result=await cloud_session("/auth/v1/token?grant_type=password",{"email":name.to_lower()+"@players.ambatopia.invalid","password":secret})
		if cloud_result.ok:
			access_token=cloud_result.access_token;refresh_token=cloud_result.refresh_token;profile=cloud_result.profile
		return cloud_result
	var result := await request("/auth/register" if register else "/auth/login",{"name":name,"password":secret})
	if result.ok:
		access_token = result.access_token
		refresh_token = result.refresh_token
		profile = result.profile
		refresh_elapsed = 0
	return result

func cloud_session(path: String,payload: Dictionary) -> Dictionary:
	var result:=await cloud_request(path,payload)
	if not result.ok:return result
	if not result.data is Dictionary or not result.data.has("access_token"):
		return {"ok":false,"error":"AmbaID registration is not enabled on this server."}
	var previous:=access_token
	access_token=result.data.access_token
	var identity:=await cloud_request("/rest/v1/game_profiles?select=*&id=eq."+str(result.data.user.id),{},HTTPClient.METHOD_GET)
	if not identity.ok or not identity.data is Array or identity.data.is_empty():
		access_token=previous
		return {"ok":false,"error":"Game profile is unavailable."}
	return {"ok":true,"access_token":result.data.access_token,"refresh_token":result.data.refresh_token,"profile":identity.data[0]}

func _process(delta: float) -> void:
	if access_token.is_empty() or refreshing:
		return
	refresh_elapsed += delta
	if refresh_elapsed > 1800:
		refreshing = true
		var result := await request("/auth/refresh",{"refresh_token":refresh_token})
		if result.ok:
			access_token = result.access_token
			refresh_token = result.refresh_token
			profile = result.profile
		refresh_elapsed = 0
		refreshing = false

func logout() -> void:
	access_token = ""
	refresh_token = ""
	profile.clear()
