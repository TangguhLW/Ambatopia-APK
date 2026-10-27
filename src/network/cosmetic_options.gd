extends RefCounted

static func valid(value) -> bool:
	if not value is Dictionary or value.size()>16:return false
	for key in value:
		if not key is String or not key.begins_with("pet_") or not key.substr(4).is_valid_int() or not value[key] is bool:return false
		var id:=int(key.substr(4))
		if id<=0 or id>=200000 or key!="pet_"+str(id):return false
	return true

static func sanitized(value) -> Dictionary:
	return value.duplicate(true) if valid(value) else {}
