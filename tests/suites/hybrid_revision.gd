extends RefCounted

func run(t) -> void:
	var app=load("res://scenes/app.tscn").instantiate()
	t.root.add_child(app)
	await t.process_frame
	t.check(app.audio_feedback.music.stream.resource_path.ends_with("main-theme.mp3"),"Opening menu plays the supplied main theme")
	var music=app.audio_feedback.music
	app.navigate("options")
	t.check(app.audio_feedback.music==music and music.playing,"Options preserves the current menu music player")
	app.navigate("worlds")
	t.check(music.stream.resource_path.ends_with("world-menu.mp3"),"World chooser retains its separate choir")
	app.start_local("HYBRIDQA")
	app.enter_world("HYBRIDQA")
	t.check(not music.playing,"Menu music stops inside a world")
	app.navigate("menu")
	app.screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for extent in [Vector2(1280,720),Vector2(568,320),Vector2(390,844)]:
		app.screen.size=extent
		app.screen.layout()
		await t.process_frame
		for button in app.screen.controls.values():
			t.check(button.caption.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER and button.caption.vertical_alignment==VERTICAL_ALIGNMENT_CENTER,"Menu captions use centered text")
			t.check(button.caption.get_rect().get_center().is_equal_approx(button.size/2),"Caption bounds remain centered after resizing")
	app.queue_free()
	await t.process_frame
	var path="res://src/game/web_wardrobe.gd"
	if not ResourceLoader.exists(path):
		t.check(false,"Native wardrobe adapter exists without loading WebView")
		return
	var wardrobe=load(path)
	t.check(wardrobe.index().items.size()==4083,"Native wardrobe has the complete reference mapping")
	var cap=wardrobe.definition(46)
	var commands=wardrobe.commands(cap,0,"stand")
	t.check(commands.size()==1 and commands[0].destination==Rect2(-11,-39,27,9),"Cap uses its cropped atlas dimensions and head anchor")
	var tex=wardrobe.texture(cap.bk)
	t.check(tex!=null and tex.get_size()==Vector2(27,9),"Packed cap decodes to its verified PNG dimensions")
	t.check(wardrobe.definition(200046).id==46,"Simulator IDs map to the same clothing record")
	t.check(wardrobe.commands(wardrobe.definition(40),0,"stand").size()==2,"Shoes preserve separate front and back foot layers")
	var tiny=wardrobe.definition(592)
	t.check(wardrobe.frame_index(tiny,0,"up")==22 and wardrobe.frame_index(tiny,160,"up")!=22,"Wardrobe frame selection follows the reference jump sequence")
