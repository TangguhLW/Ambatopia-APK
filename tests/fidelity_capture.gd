extends SceneTree

var app
var output := "res://evidence/fidelity-2026-10-22"

func _initialize() -> void:
	call_deferred("run")

func dimensions(value: Vector2i) -> void:
	root.content_scale_size = value
	root.size = value
	DisplayServer.window_set_size(value)
	await process_frame
	await process_frame

func capture(name: String) -> void:
	for child in app.screen.get_children():
		if child.get_script() == load("res://src/ui/background.gd"):
			child.elapsed = 0
			child.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var actual := root.get_texture().get_image()
	actual.save_png(output + "/actual/" + name + ".png")
	var reference := Image.load_from_file(output + "/references/" + name + ".png")
	if name == "menu":
		reference = reference.get_region(Rect2i(0,28,1015,772))
	elif name == "login":
		reference = reference.get_region(Rect2i(0,28,1017,766))
	reference.save_png(output + "/normalized/" + name + ".png")
	if reference.get_size() != actual.get_size():
		push_error("Comparison size mismatch: " + name)
		return
	var diff := Image.create(actual.get_width(),actual.get_height(),false,Image.FORMAT_RGBA8)
	for y in actual.get_height():
		for x in actual.get_width():
			var a := actual.get_pixel(x,y)
			var b := reference.get_pixel(x,y)
			diff.set_pixel(x,y,Color(absf(a.r-b.r),absf(a.g-b.g),absf(a.b-b.b),1))
	diff.save_png(output + "/difference/" + name + ".png")

func run() -> void:
	for folder in ["actual","normalized","difference"]:
		DirAccess.make_dir_recursive_absolute(output + "/" + folder)
	await dimensions(Vector2i(1015,772))
	app = load("res://scenes/app.tscn").instantiate()
	app.set_meta("visual_freeze",true)
	app.profile.display_name = "Thaney"
	app.set_meta("profile_active",true)
	app.session.store.directory = "user://fidelity-visual-fixtures"
	root.add_child(app)
	await process_frame
	await capture("menu")
	await dimensions(Vector2i(1017,766))
	app.navigate("login")
	await capture("login")
	await dimensions(Vector2i(1061,543))
	app.start_local("Thaney")
	print("WORLD_PANEL ",app.screen.chat_panel.size," min ",app.screen.chat_panel.get_combined_minimum_size())
	await capture("worlds")
	await dimensions(Vector2i(1037,505))
	app.enter_world("VISUAL")
	app.screen.player.display_name = "Local reference"
	await create_timer(0.15).timeout
	await capture("gameplay")
	app.screen.toggle_inventory()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/actual/inventory.png")
	app.queue_free()
	await process_frame
	quit()
