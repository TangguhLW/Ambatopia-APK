extends RefCounted
const Player=preload("res://src/game/player_state.gd")
var store=preload("res://src/storage/local_store.gd").new()

static func slot(profile: Dictionary) -> String:
	var identity:=str(profile.get("id","local"))
	if identity in ["","local"]:identity="local:"+str(profile.get("display_name","Player")).strip_edges().to_lower()
	return "set_"+identity.sha256_text().substr(0,16)

func save(profile: Dictionary,player,index: int=0) -> Dictionary:
	if index<0 or index>3:return {"ok":false,"error":"Choose outfit 1, 2 or 3"}
	var payload={"schema_version":2,"equipment":player.equipment.duplicate(),"catalog_equipment":player.catalog_equipment.duplicate(),"skin":player.skin_index,"item_options":player.item_options.duplicate(true)}
	var error: Error=store.save(slot(profile)+( "_"+str(index) if index>0 else ""),payload)
	return {"ok":error==OK,"error":"" if error==OK else "Could not save set (%d)"%error}

func restore(profile: Dictionary,player,index: int=0) -> Dictionary:
	if index<0 or index>3:return {"ok":false,"error":"Choose outfit 1, 2 or 3"}
	var result: Dictionary=store.load_slot(slot(profile)+( "_"+str(index) if index>0 else ""))
	if not result.ok:return result
	var data: Dictionary=result.data
	var candidate=Player.new()
	if not data.get("equipment") is Dictionary or not data.get("catalog_equipment") is Dictionary or not data.get("item_options",{}) is Dictionary:return invalid()
	for key in data.equipment:
		var value=data.equipment[key]
		if not candidate.equipment.has(key) or not integral(value) or int(value)<-1 or int(value)>2:return invalid()
		candidate.equipment[key]=int(value)
	for key in data.catalog_equipment:
		var id=data.catalog_equipment[key]
		if not integral(id):return invalid()
		var entry: Dictionary=preload("res://src/game/item_catalog.gd").summary(int(id))
		if entry.get("slot")!=key or not candidate.equip_catalog(int(id)):return invalid()
	if not integral(data.get("skin")) or int(data.skin)<0 or int(data.skin)>=Player.SKINS.size():return invalid()
	for key in data.get("item_options",{}):
		if not key is String or not key.begins_with("pet_") or not data.item_options[key] is bool:return invalid()
	player.equipment=candidate.equipment;player.catalog_equipment=candidate.catalog_equipment
	player.skin_index=int(data.skin);player.item_options=data.get("item_options",{}).duplicate(true)
	return {"ok":true,"error":""}

static func integral(value) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==int(value)

static func invalid() -> Dictionary:
	return {"ok":false,"error":"Saved set invalid; original preserved"}
