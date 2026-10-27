extends RefCounted

var directory := "user://local-worlds"

func valid_slot(slot: String) -> bool:
	if slot.length() < 1 or slot.length() > 24:
		return false
	for c in slot:
		if not c.to_lower() in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true

func save(slot: String, payload: Dictionary) -> Error:
	if not valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var path := directory + "/" + slot + ".json"
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(path + ".tmp", path)

func load_slot(slot: String) -> Dictionary:
	var result := {"ok": false, "data": {}, "error": "Save not found"}
	if not valid_slot(slot):
		result.error = "Invalid save slot"
		return result
	var path := directory + "/" + slot + ".json"
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2000000:
		result.error = "Save unreadable or too large"
		return result
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	var data = parser.data if parsed == OK else null
	if not data is Dictionary or (data.get("schema_version") != 1 and data.get("schema_version") != 2):
		result.error = "Save corrupt or unsupported version; original preserved"
		return result
	result.ok = true
	result.data = data
	result.error = ""
	return result
