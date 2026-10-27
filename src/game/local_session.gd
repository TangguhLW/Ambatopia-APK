extends RefCounted

const World = preload("res://src/game/world_state.gd")
const Player = preload("res://src/game/player_state.gd")
const Store = preload("res://src/storage/local_store.gd")
var world
var player
var store := Store.new()
var active := false
var outfit_profile: Dictionary={}
var outfits=preload("res://src/storage/outfit_store.gd").new()

func save_set() -> Dictionary:
	if player==null:return {"ok":false,"error":"No player"}
	outfits.store.directory=store.directory+"/outfits"
	return outfits.save(outfit_profile,player)

func save_outfit_slot(index: int) -> Dictionary:
	if player==null or index<1 or index>3:return {"ok":false,"error":"Choose outfit 1, 2 or 3"}
	outfits.store.directory=store.directory+"/outfits"
	return outfits.save(outfit_profile,player,index)

func load_outfit_slot(index: int) -> Dictionary:
	if player==null or index<1 or index>3:return {"ok":false,"error":"Choose outfit 1, 2 or 3"}
	outfits.store.directory=store.directory+"/outfits"
	var candidate=Player.new()
	var result: Dictionary=outfits.restore(outfit_profile,candidate,index)
	if not result.ok:return result
	result=outfits.save(outfit_profile,candidate)
	if not result.ok:return result
	player.equipment=candidate.equipment
	player.catalog_equipment=candidate.catalog_equipment
	player.skin_index=candidate.skin_index
	player.item_options=candidate.item_options
	return result

func outfit_slot_info(index: int) -> Dictionary:
	if index<1 or index>3:return {"ok":false}
	outfits.store.directory=store.directory+"/outfits"
	var candidate=Player.new()
	var result: Dictionary=outfits.restore(outfit_profile,candidate,index)
	return {"ok":result.ok,"items":candidate.catalog_equipment.size()}

func restore_set(profile: Dictionary) -> Dictionary:
	outfit_profile=profile.duplicate()
	outfits.store.directory=store.directory+"/outfits"
	return outfits.restore(outfit_profile,player)

func world_names() -> Array[String]:
	var names: Array[String] = ["START", "SANDBOX"]
	var directory := DirAccess.open(store.directory)
	if directory:
		for file in directory.get_files():
			if file.ends_with(".json") and file.get_basename() not in ["settings"]:
				var name := file.get_basename().to_upper()
				if name not in names:
					names.append(name)
	for name in names.duplicate():
		var saved:=store.load_slot(name.to_lower())
		if not saved.ok or not saved.data.get("world") is Dictionary:continue
		var candidate:=World.new()
		if candidate.restore(saved.data.world) and preload("res://src/game/source_machine_rules.gd").flags(candidate).signal:names.erase(name)
	return names

func enter(profile: Dictionary, world_name: String) -> Dictionary:
	var normalized := world_name.strip_edges().to_upper()
	if normalized.is_empty() or normalized.length() > 18:
		return {"ok": false, "error": "Use 1–18 letters or digits."}
	for c in normalized:
		if not c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			return {"ok": false, "error": "World names use letters and digits only."}
	world = World.new()
	player = Player.new()
	var saved := store.load_slot(normalized.to_lower())
	if saved.ok:
		if not saved.data.has("world") or not saved.data.world is Dictionary or not world.restore(saved.data.world):
			return {"ok": false, "error": "World data unsupported; saved file preserved."}
		var equipment = saved.data.get("equipment", {})
		player.skin_index = clampi(int(saved.data.get("skin",0)),0,5)
		if saved.data.get("collected",{}) is Dictionary:
			player.collected=saved.data.get("collected",{}).duplicate()
		if equipment is Dictionary:
			for slot in player.equipment:
				var value = equipment.get(slot, -1)
				if not value is int and not value is float:
					return {"ok": false, "error": "Invalid saved equipment; file preserved."}
				if float(value) != int(value) or int(value) < -1 or int(value) > 2:
					return {"ok": false, "error": "Unsupported saved equipment frame; file preserved."}
				player.equipment[slot] = int(value)
		var catalog = saved.data.get("catalog_equipment",{})
		if not catalog is Dictionary:
			return {"ok":false,"error":"Invalid catalog outfit; file preserved."}
		for slot in catalog:
			var id = catalog[slot]
			if (not id is int and not id is float) or float(id) != int(id):
				return {"ok":false,"error":"Invalid catalog ID; file preserved."}
			var entry: Dictionary = preload("res://src/game/item_catalog.gd").summary(int(id))
			if entry.is_empty() or entry.slot != slot or not player.equip_catalog(int(id)):
				return {"ok":false,"error":"Unsupported catalog outfit; file preserved."}
	elif saved.error != "Save not found":
		return {"ok": false, "error": saved.error}
	else:
		world.create_default(normalized)
	restore_set(profile)
	player.display_name = str(profile.get("display_name", "Player")).left(18)
	player.position = world.spawn_position()
	player.grounded = world.solid(Vector2i((player.position + Vector2(0, 0.1)) / 32))
	active = true
	return {"ok": true, "error": ""}

func save() -> Dictionary:
	if not active:
		return {"ok": false, "error": "No active world"}
	var outfit_result:=save_set()
	if not outfit_result.ok:return outfit_result
	var error := store.save(world.name.to_lower(), {"schema_version": 2, "world": world.serialize(), "equipment": player.equipment,"catalog_equipment":player.catalog_equipment,"skin":player.skin_index,"collected":player.collected})
	return {"ok": error == OK, "error": "" if error == OK else "Could not save local world (%d)" % error}

func leave() -> Dictionary:
	var result := save()
	if result.ok:
		active = false
	return result
