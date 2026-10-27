extends SceneTree

var app
var folder := "res://evidence/catalog-2026-10-22"
var checks: Array = []

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name+".png")

func dimensions(value: Vector2i) -> void:
	root.content_scale_size = value
	root.size = value
	DisplayServer.window_set_size(value)
	await process_frame
	await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	await dimensions(Vector2i(1280,720))
	app = load("res://scenes/app.tscn").instantiate()
	app.session.store.directory = "user://catalog-visual-fixtures"
	root.add_child(app)
	app.start_local("Wardrobe QA")
	app.enter_world("CATALOGVISUAL")
	await process_frame
	app.screen.player.equip_catalog(34)
	app.screen.player.equip_catalog(36)
	app.screen.player.equip_catalog(48)
	app.screen.player.equip_catalog(40)
	app.screen.player.equip_catalog(44)
	app.screen.player.equip_catalog(362)
	app.screen.toggle_inventory()
	var inventory = app.screen.inventory
	inventory.mode = "clothes"
	inventory.supported_filter.button_pressed = true
	inventory.rebuild()
	inventory.inspect_item(362)
	await shot("wardrobe-desktop")
	for view in [Vector2i(390,844),Vector2i(844,390)]:
		await dimensions(view)
		app.screen.layout_overlays()
		await process_frame
		await process_frame
		checks.append({"viewport":[view.x,view.y],"panel":[inventory.position.x,inventory.position.y,inventory.size.x,inventory.size.y],"fits":Rect2(Vector2.ZERO,view).encloses(inventory.get_global_rect()),"grid_columns":inventory.grid.columns})
		await shot("wardrobe-%dx%d" % [view.x,view.y])
	for view in [Vector2i(390,844),Vector2i(844,390)]:
		await dimensions(view)
		app.navigate("login")
		await process_frame
		await process_frame
		checks.append({"screen":"login","viewport":[view.x,view.y],"fits":Rect2(Vector2.ZERO,view).encloses(app.screen.form.get_global_rect())})
		await shot("login-%dx%d" % [view.x,view.y])
		app.navigate("multiplayer")
		await shot("multiplayer-%dx%d" % [view.x,view.y])
	var file := FileAccess.open(folder+"/layout.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"  "))
	file.close()
	app.queue_free()
	await process_frame
	quit(1 if checks.any(func(row): return not row.fits) else 0)
