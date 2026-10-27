extends RefCounted

static var records: Dictionary = {}
static func items() -> Dictionary:
	if records.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/placeable-blocks.json"))
		for item in data.items:
			records[int(item.world_id)] = item
	return records

static func supports(world_id: int) -> bool:
	return items().has(world_id)

static func original(world_id: int) -> int:
	return int(items()[world_id].id) if supports(world_id) else -1
