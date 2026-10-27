extends RefCounted

static func verify() -> Array[String]:
	var failures: Array[String]=[]
	var manifest_path:="res://assets/reference/manifest.json"
	if not FileAccess.file_exists(manifest_path):
		return ["Required asset manifest is missing."]
	var manifest=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Array or manifest.is_empty():return ["Required asset manifest is invalid."]
	for entry in manifest:
		if not entry is Dictionary or not entry.get("output_file") is String:
			failures.append("Invalid asset mapping.");continue
		var filename: String=entry.output_file
		if filename.get_file()!=filename or ".." in filename or ":" in filename:
			failures.append("Unsafe asset mapping.");continue
		if not ResourceLoader.exists("res://assets/reference/"+filename):
			failures.append("Missing required asset: "+filename)
	return failures
