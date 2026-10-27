extends RefCounted
static var index: Dictionary={}
static var cache: Dictionary={}
static func stream(name: String) -> AudioStreamWAV:
	if cache.has(name):return cache[name]
	if index.is_empty():index=JSON.parse_string(FileAccess.get_file_as_string("res://data/punch-audio-index.json"))
	var entry: Dictionary=index.get(name,{})
	if entry.is_empty() or entry.get("missing",false):return null
	var file=FileAccess.open("res://assets/web-wardrobe/punch-audio.bin",FileAccess.READ)
	file.seek(int(entry.offset))
	var audio:=AudioStreamWAV.load_from_buffer(file.get_buffer(int(entry.bytes)))
	if audio==null:return null
	if cache.size()>=8:cache.erase(cache.keys()[0])
	cache[name]=audio
	return audio
