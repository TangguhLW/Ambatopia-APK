extends SceneTree
func _initialize():
	var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/reference/manifest.json"))
	var checked:=0
	var failures: Array=[]
	for entry in manifest:
		if not entry.output_file.ends_with(".png"):continue
		var path="res://assets/reference/"+entry.output_file
		var raw:=Image.new()
		if raw.load_png_from_buffer(FileAccess.get_file_as_bytes(path))!=OK:
			failures.append(entry.id+": PNG decode failed")
			continue
		var imported: Image=load(path).get_image()
		raw.convert(Image.FORMAT_RGBA8)
		imported.convert(Image.FORMAT_RGBA8)
		if raw.get_size()!=imported.get_size() or raw.get_data()!=imported.get_data():
			failures.append(entry.id+": imported RGBA differs")
		checked+=1
	var result={"checked":checked,"failures":failures,"engine":Engine.get_version_info().string,"scope":"Exact decoded PNG bytes versus Godot imported RGBA8; no installation folder is read by this test"}
	var report:=FileAccess.open("res://evidence/ui-revision/resource-pixels.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(result,"\t"))
	report.close()
	print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
