extends RefCounted

func run(t) -> void:
	var app = load("res://scenes/app.tscn").instantiate()
	t.root.add_child(app)
	await t.process_frame
	t.check(app.has_method("prepare_close"), "Window close handled centrally across routes")
	t.check(app.has_method("go_back"), "Android Back navigation exists")
	if app.has_method("go_back"):
		app.navigate("options")
		app.go_back()
		t.check(app.route == "menu", "Back closes Options")
		t.check(app.prepare_close().ok, "Menu can close without an active world")
	t.check(app.has_method("start_local"), "Local login and play flow exists")
	if app.has_method("start_local"):
		app.navigate("login")
		t.check(app.screen.find_child("ProfileName", true, false) != null, "Profile entry exists")
		app.start_local("Tester")
		t.check(app.route == "worlds", "Local login routes to chooser")
		app.navigate("about")
		t.check(app.screen.find_child("AboutText", true, false) != null, "About explains reconstruction")
	app.queue_free()
	await t.process_frame
