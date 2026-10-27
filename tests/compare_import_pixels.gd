extends SceneTree
func _initialize() -> void:
	for id in ["title","hair","panel_tinted"]:
		var source := Image.new()
		source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/reference/"+id+".png"))
		var imported: Image = load("res://assets/reference/"+id+".png").get_image()
		source.convert(Image.FORMAT_RGBA8)
		imported.convert(Image.FORMAT_RGBA8)
		var a := source.get_data()
		var b := imported.get_data()
		var alpha_diff := 0
		var hidden_diff := 0
		var visible_diff := 0
		for at in range(0,mini(a.size(),b.size()),4):
			if a[at+3] != b[at+3]:
				alpha_diff += 1
			if a[at] != b[at] or a[at+1] != b[at+1] or a[at+2] != b[at+2]:
				if a[at+3] == 0:
					hidden_diff += 1
				else:
					visible_diff += 1
		print(id," bytes ",a.size(),"/",b.size()," alpha ",alpha_diff," hidden ",hidden_diff," visible ",visible_diff)
	quit()
