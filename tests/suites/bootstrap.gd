extends RefCounted

func run(t) -> void:
	t.check(Engine.get_version_info().string.begins_with("4.7.2"), "Pinned Godot version")
	if OS.get_name() == "Windows":
		t.check(OS.get_user_data_dir().length() + "/shader_cache/ParticlesCopyShaderGLES3/".length() + 64 < 248, "Shader cache directory fits Windows path limit")
	t.check(ResourceLoader.exists("res://scenes/app.tscn"), "Runnable app scene exists")
	if not ResourceLoader.exists("res://scenes/app.tscn"):
		return
	var app = load("res://scenes/app.tscn").instantiate()
	t.root.add_child(app)
	await t.process_frame
	app.navigate("options")
	t.check(app.route == "options", "Options route")
	app.navigate("invalid")
	t.check(app.route == "options", "Unknown route preserves current screen")
	app.navigate("menu")
	t.check(app.route == "menu", "Return to menu")
	app.queue_free()
	await t.process_frame
