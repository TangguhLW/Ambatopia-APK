extends RefCounted
static var index: Dictionary={}
static var cache: Dictionary={}
static func texture(sheet: String) -> Texture2D:
	if cache.has(sheet):return cache[sheet]
	if index.is_empty():index=JSON.parse_string(FileAccess.get_file_as_string("res://data/additional-effects-index.json"))
	var entry: Dictionary=index.get(sheet,{})
	if entry.is_empty() or entry.get("missing",false):return null
	var file=FileAccess.open("res://assets/web-wardrobe/additional-effects.bin",FileAccess.READ)
	file.seek(int(entry.offset));var image=Image.new()
	if image.load_png_from_buffer(file.get_buffer(int(entry.bytes)))!=OK:return null
	if cache.size()>=8:cache.erase(cache.keys()[0])
	cache[sheet]=ImageTexture.create_from_image(image)
	return cache[sheet]
