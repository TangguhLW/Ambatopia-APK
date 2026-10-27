extends RefCounted

static var index: Dictionary = {}
static var wearable_index: Dictionary = {}
static var by_id: Dictionary = {}
static var page_cache: Dictionary = {}
static var texture_cache: Dictionary = {}
static var enrichment: Dictionary = {}

static func source_notes(id: int) -> Dictionary:
	if index.is_empty():entries()
	if enrichment.is_empty() and FileAccess.file_exists("res://data/source-enrichment.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/source-enrichment.json"))
		if data is Dictionary and data.get("schema_version")==1 and data.get("native_generation")==index.get("generation"):
			for entry in data.entries:
				enrichment[int(entry.id)]=entry
	var original:=id-200000 if id>=200000 else id
	var note: Dictionary=enrichment.get(original,{})
	var item:=summary(id)
	return note if not note.is_empty() and not item.is_empty() and note.name==item.name else {}

static func entries() -> Array:
	if index.is_empty():
		index = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog-index.json"))
		for item in index.entries:
			if not preload("res://src/game/native_item_renderer.gd").definition(int(item.id)).is_empty() or item.slot!=null and preload("res://src/game/web_wardrobe.gd").can_render(item):
				item.equip=true
			by_id[int(item.id)] = item
	return index.entries

static func summary(id: int) -> Dictionary:
	if id>=200000:
		var sim = preload("res://src/game/simulator_catalog.gd")
		var row: Array = sim.items().get(str(id-200000),[])
		if row.is_empty():
			return {}
		var slot: String = sim.slot(id-200000)
		return {"id":id,"name":row[0],"slot":slot if slot!="" else null,"equip":slot!="","equipment":slot!="","category":sim.category(row),"preview":true,"simulator":true,"aliases":[],"effects":[]}
	if index.is_empty():
		if wearable_index.is_empty():
			wearable_index = JSON.parse_string(FileAccess.get_file_as_string("res://data/wearable-index.json"))
		for item in wearable_index.entries:
			if int(item.id) == id:
				if not preload("res://src/game/native_item_renderer.gd").definition(id).is_empty() or item.slot!=null and preload("res://src/game/web_wardrobe.gd").can_render(item):item.equip=true
				return item
	entries()
	return by_id.get(id,{})

static func query(text: String = "", category: String = "", slot: String = "", supported_only: bool = false) -> Array:
	var found: Array = []
	var needle := text.strip_edges().to_lower()
	for item in entries():
		if category != "" and item.category != category:
			continue
		if slot != "" and item.slot != slot:
			continue
		if supported_only and not item.equip:
			continue
		if needle != "" and needle != str(int(item.id)) and needle not in str(item.name).to_lower() and needle not in " ".join(item.aliases).to_lower():
			continue
		found.append(item)
	return found

static func record(id: int) -> Dictionary:
	var item := summary(id)
	if item.is_empty():
		return {}
	if id>=200000:
		return {"name":item.name,"original_id":id-200000,"equipment":{"slot":item.slot} if item.equip else null,"status":{"equipment":item.equip},"effects":[],"description":"Creative source wardrobe / item"}
	var page := int(item.page)
	if not page_cache.has(page):
		if page_cache.size() >= 4:
			page_cache.erase(page_cache.keys()[0])
		var directory: String = wearable_index.details if index.is_empty() else index.details
		page_cache[page] = JSON.parse_string(FileAccess.get_file_as_string("res://%s/%d.json" % [directory,page]))
	for row in page_cache[page]:
		if int(row.original_id) == id:
			return row
	return {}

static func sprite(id: int) -> Texture2D:
	if id>=200000:
		var image: Texture2D=preload("res://src/game/simulator_catalog.gd").sprite(id-200000)
		return image if image!=null else preload("res://src/game/web_wardrobe.gd").icon(id)
	var item := summary(id)
	if item.is_empty():
		return null
	if not item.preview:return preload("res://src/game/web_wardrobe.gd").icon(id)
	var path: String = "res://" + item.asset
	if not texture_cache.has(path):
		if texture_cache.size() >= 8:
			texture_cache.erase(texture_cache.keys()[0])
		texture_cache[path] = ResourceLoader.load(path,"Texture2D",ResourceLoader.CACHE_MODE_REUSE)
	var atlas := AtlasTexture.new()
	atlas.filter_clip=true
	atlas.atlas = texture_cache[path]
	var f: Array = item.frame
	atlas.region = Rect2(f[0],f[1],f[2],f[3])
	return atlas

static func icon(id: int) -> Texture2D:
	var image: Texture2D=preload("res://src/game/inventory_icons.gd").texture(id-200000 if id>=200000 else id,id<200000)
	return image if image!=null else preload("res://src/game/web_wardrobe.gd").icon(id) if not summary(id).get("preview",false) and id<200000 else null
