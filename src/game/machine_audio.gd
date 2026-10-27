extends RefCounted
static var data: Dictionary={}
static var cache: Dictionary={}
static func load_data() -> void:
	if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://data/machine-audio-index.json"))
static func stream(path: String) -> AudioStream:
	load_data()
	if cache.has(path):return cache[path]
	var entry: Dictionary=data.entries.get(path,{})
	if entry.is_empty() or entry.get("missing",false):return null
	var file=FileAccess.open("res://assets/web-wardrobe/machine-audio.bin",FileAccess.READ)
	if file==null:return null
	file.seek(int(entry.offset))
	var bytes:=file.get_buffer(int(entry.bytes))
	var sound: AudioStream
	match entry.format:
		"ogg":sound=AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":sound=AudioStreamWAV.load_from_buffer(bytes)
		"mp3":
			sound=AudioStreamMP3.new();sound.data=bytes
	if sound!=null:
		if cache.size()>=12:cache.erase(cache.keys()[0])
		cache[path]=sound
	return sound
