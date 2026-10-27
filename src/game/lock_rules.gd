extends RefCounted
const Blocks = preload("res://src/game/placeable_blocks.gd")
static func is_lock(item: int) -> bool:
	return item == 5 or Blocks.supports(item) and Blocks.items()[item].get("lock",false)
static func capacity(item: int) -> int:
	return int(Blocks.items()[item].get("area",0)) if Blocks.supports(item) else 0
static func owner_at(world, tile: Vector2i) -> String:
	for record in world.locks:
		if record.area == 0 or record.tiles.has(tile.y*world.size.x+tile.x):
			return record.owner
	return ""
static func coverage(world, origin: Vector2i, count: int) -> Array:
	var result: Array = []
	var queue: Array[Vector2i] = [origin]
	var seen := {}
	while not queue.is_empty() and result.size() < count:
		var tile: Vector2i = queue.pop_front()
		if seen.has(tile) or not world.contains(tile):
			continue
		seen[tile] = true
		if owner_at(world,tile) != "":
			continue
		result.append(tile.y*world.size.x+tile.x)
		for direction in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			queue.append(tile+direction)
	return result
static func can_place(world, tile: Vector2i, item: int, owner: String) -> bool:
	if not is_lock(item):
		return true
	if capacity(item) == 0 and Array(world.foreground).any(func(existing): return is_lock(existing) and capacity(existing) == 0):
		return false
	for record in world.locks:
		if record.area == 0 or capacity(item) == 0 and record.owner != owner:
			return false
	return owner_at(world,tile) in ["",owner]
static func placed(world, tile: Vector2i, item: int, owner: String) -> void:
	if not is_lock(item):
		return
	var count := capacity(item)
	var covered := coverage(world,tile,count) if count > 0 else []
	world.locks.append({"x":tile.x,"y":tile.y,"item":item,"owner":owner,"area":count,"tiles":covered})
static func removed(world, tile: Vector2i) -> void:
	world.locks = world.locks.filter(func(record): return record.x != tile.x or record.y != tile.y)
