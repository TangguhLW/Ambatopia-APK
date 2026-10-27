extends RefCounted

static func equipment(value) -> Dictionary:
	if not value is Dictionary or value.size()>10:return {}
	var result: Dictionary={}
	var slots=preload("res://src/game/simulator_catalog.gd").SLOTS
	for key in value:
		if key not in slots:return {}
	for slot in slots:
		if not value.has(slot):continue
		var id=value[slot]
		if not (id is int or id is float) or not is_finite(float(id)) or float(id)!=int(id) or int(id)<0 or int(id)>500000:return {}
		result[slot]=int(id)
	return result
