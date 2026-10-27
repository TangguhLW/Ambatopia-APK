extends RefCounted

func run(t) -> void:
	var entries = JSON.parse_string(FileAccess.get_file_as_string("res://assets/reference/manifest.json"))
	t.check(entries is Array and entries.size() >= 23, "Verified selected assets available")
	for id in ["title", "head", "body", "punch", "tiles", "hair", "shirts"]:
		t.check(ResourceLoader.exists("res://assets/reference/%s.png" % id), "Texture imports: " + id)
	t.check(ResourceLoader.exists("res://assets/reference/font.ttf"), "Reference font imports")
	for entry in entries:
		if not str(entry.source).ends_with(".rttex"):
			continue
		var id: String = entry.id
		var source := Image.new()
		source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/reference/%s.png" % id))
		var imported: Image = load("res://assets/reference/%s.png" % id).get_image()
		source.convert(Image.FORMAT_RGBA8)
		imported.convert(Image.FORMAT_RGBA8)
		t.check(source.get_data() == imported.get_data(), "Godot import cache matches decoded pixel bytes: " + id)
	var atlas = JSON.parse_string(FileAccess.get_file_as_string("res://data/atlas.json"))
	var avatar = load("res://src/game/avatar_view.gd").new()
	t.root.add_child(avatar)
	t.check(avatar.has_method("source_frame"), "Avatar consumes verified frame manifest")
	if avatar.has_method("source_frame"):
		t.check(avatar.source_frame("eyes") == Rect2(0, 0, 32, 32), "Eyes use visible upright frame")
		t.check(avatar.source_frame("puncharm").size.y == 48, "Fist retains full source arm height")
	avatar.queue_free()
	var top: Array = atlas.terrain.dirt_top
	var ground: Image = load("res://assets/reference/tiles.png").get_image()
	var opaque := true
	for y in range(int(top[1]), int(top[1] + top[3])):
		for x in range(int(top[0]), int(top[0] + top[2])):
			if ground.get_pixel(x, y).a < 1:
				opaque = false
	t.check(opaque, "Continuous grass surface has no transparent vertical seams")
	for id in atlas.avatar:
		var rect_data: Array = atlas.avatar[id]
		var region := Rect2i(int(rect_data[0]), int(rect_data[1]), int(rect_data[2]), int(rect_data[3]))
		var image: Image = load("res://assets/reference/%s.png" % id).get_image()
		t.check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Atlas frame is in bounds: " + id)
		var visible := false
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if image.get_pixel(x, y).a > 0.01:
					visible = true
		t.check(visible, "Atlas frame is not transparent: " + id)
