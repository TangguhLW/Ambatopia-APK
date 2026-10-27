extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://src/storage/local_store.gd"):
		t.check(false, "Versioned local store exists")
		return
	var store = load("res://src/storage/local_store.gd").new()
	store.directory = "user://test-fixtures"
	t.check(store.save("roundtrip", {"schema_version": 1, "equipment": {"shirt": 1}}) == OK, "Local write")
	var loaded = store.load_slot("roundtrip")
	t.check(loaded.ok and loaded.data.equipment.shirt == 1, "Equipment roundtrip")
	t.check(store.save("../escape", {}) != OK, "Reject path traversal")
	t.check(not store.load_slot("missing").ok, "Missing slot is recoverable")
	var f = FileAccess.open(store.directory + "/bad.json", FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	t.check(not store.load_slot("bad").ok, "Corrupt save is recoverable")
	store.save("future", {"schema_version": 999})
	t.check(not store.load_slot("future").ok, "Unknown schema rejected")
	var world = load("res://src/game/world_state.gd").new()
	world.create_default("VALIDATE")
	var data: Dictionary = world.serialize()
	data.size = ["not a number", []]
	t.check(not world.restore(data), "Malformed world dimensions rejected without exception")
	data = world.serialize()
	data.background[0] = {}
	t.check(not world.restore(data), "Malformed background item rejected without exception")
