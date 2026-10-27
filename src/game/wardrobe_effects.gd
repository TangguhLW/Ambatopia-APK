extends RefCounted
static var descriptions: Dictionary = {}
static var movement: Dictionary={}
static var confirmed_speedy: Array=[]
static func abilities(outfit: Dictionary) -> Dictionary:
	if descriptions.is_empty():
		descriptions = JSON.parse_string(FileAccess.get_file_as_string("res://data/simulator/clothing-descriptions.json"))
	if movement.is_empty():
		movement=JSON.parse_string(FileAccess.get_file_as_string("res://data/source-movement-rules.json"))
		movement.slippery=movement.slippery.map(func(id):return int(id))
		for key in movement.worn:
			if movement.worn[key] is Array:movement.worn[key]=movement.worn[key].map(func(id):return int(id))
	if confirmed_speedy.is_empty():confirmed_speedy=JSON.parse_string(FileAccess.get_file_as_string("res://data/clothing-mods-032.json")).speedy.map(func(id):return int(id))
	var result := {"double_jump":false,"speed":1.0,"jump":1.0,"dig":1.0,"range":96.0,"build_range":96.0,"strong_punch":false,"speed_in_water":false,"fireproof":false,"trail":false,"pet":false,"glow":false,"worn_mods":[]}
	for key in ["climb","anti_slip","floaties","slippery_clothes"]:result[key]=false
	result.snowshoes=false
	var speedy_ids: Array=[]
	for encoded in outfit.values():
		var id := int(encoded)-200000 if int(encoded)>=200000 else int(encoded)
		if id in confirmed_speedy:
			if id not in speedy_ids:speedy_ids.append(id)
			result.speed=maxf(float(result.speed),1.25)
			result.worn_mods.append("Neon Nerves · Speedy" if id==5264 else "Speedy · "+str(descriptions.get(str(id),{}).get("name",id)))
		for key in ["climb","anti_slip","floaties","slippery_clothes"]:
			if id in movement.worn.get(key,[]):result[key]=true
		if id==int(movement.worn.snowshoes):result.snowshoes=true
		var row: Dictionary = descriptions.get(str(id),{})
		var description: String = str(row.get("description","")).to_lower()
		var name: String = str(row.get("name","")).to_lower()
		if id in [156,362,1460] or "double-jump" in description or "double jump" in description:
			result.double_jump = true
		if "speedy" in description or "move faster" in description or "run faster" in description:
			result.speed = 1.25
			if id not in speedy_ids:speedy_ids.append(id)
		if "high jump" in description or "jump higher" in description:
			result.jump = 1.15
		if id==98 or "break blocks faster" in description or "smash through bricks slightly faster" in description:
			result.dig = 1.5
		if "punch range" in description or "longer reach" in description:
			result.range = 128.0
		if "build further" in description or "long build" in description:
			result.build_range=128.0
		if "fireproof" in description or "immune to lava" in description:
			result.fireproof = true
		result.trail = result.trail or "trail" in description
		result.glow = result.glow or "glow" in description or "aura" in description or "flam" in name
		result.pet = result.pet or "leash" in name or "pet " in name
	var ids: Array=outfit.values().map(func(id):return int(id)-200000 if int(id)>=200000 else int(id))
	if movement.worn.slippery_pair.all(func(id):return id in ids):result.slippery_clothes=true
	# Neon shares the Medallion's contribution; the native increment remains an adaptation.
	var stacks:=0
	if 5264 in speedy_ids:
		stacks=1+mini(2,speedy_ids.filter(func(id):return id not in [5264,4988]).size())
	elif not speedy_ids.is_empty():
		stacks=1
	result.speed_stacks=stacks
	result.speed=1.0+0.25*stacks
	result.worn_mods.sort()
	return result
