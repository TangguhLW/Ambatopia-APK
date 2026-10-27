extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var app=load("res://scenes/app.tscn").instantiate();root.add_child(app)
	app.session.store.directory="user://dirt-audio-0251-fixture"
	app.start_local("DirtAudioQA");app.enter_world("DIRTAUDIOQA")
	await create_timer(0.2).timeout
	var view=app.screen;view.set_process(false)
	var tile:=Vector2i(48,23)
	view.player.position=Vector2(47*32+16,24*32);view.world.set_tile(tile,200002)
	var sounds: Array=[];var voices: Array=[]
	for hit in 3:
		view.actions.cooldown=0
		var result: Dictionary=view.actions.apply(view.world,view.player,"punch",tile,0)
		for event in result.events:
			view.receive_event(event)
			if event.type in ["punch_started","tile_removed"]:
				sounds.append(view.get_meta("last_sfx",""))
				voices.append(view.voices[(view.voice_index-1)%view.voices.size()].stream.resource_path)
		await create_timer(0.4).timeout
	var passed: bool=sounds==["wood_damage","wood_damage","wood_damage","wood_break"] and view.world.tile_at(tile)==0
	var report={"passed":passed,"sounds":sounds,"streams":voices,"remaining_tile":view.world.tile_at(tile)}
	FileAccess.open("res://evidence/dirt-0251-live-audio.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("DIRT_AUDIO_QA ",JSON.stringify(report))
	quit(0 if passed else 1)
