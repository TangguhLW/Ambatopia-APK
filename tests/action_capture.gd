extends SceneTree

var app
var folder := "res://evidence/multiplayer-2026-10-23"
var images: Array[Image] = []

func _initialize() -> void:
	call_deferred("run")

func sample(name: String) -> Image:
	app.screen.avatar.queue_redraw()
	app.screen.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var full := root.get_texture().get_image()
	full.save_png(folder+"/"+name+".png")
	var region := Rect2i(Vector2i(app.screen.avatar.position)-Vector2i(70,75),Vector2i(140,100))
	var crop := full.get_region(region)
	images.append(crop)
	return crop

func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	app = load("res://scenes/app.tscn").instantiate()
	app.session.store.directory = "user://action-render-fixtures"
	root.add_child(app)
	app.start_local("Action reference")
	app.enter_world("ACTIONVISUAL")
	await process_frame
	var play = app.screen
	play.set_process(false)
	play.backdrop.set_process(false)
	play.avatar.set_process(false)
	play.player.reset_appearance()
	play.player.grounded = true
	play.player.punch_time = 0
	play.player.velocity = Vector2.ZERO
	var idle: Image = await sample("idle")
	play.player.punch_time = 0.15
	var windup: Image = await sample("punch-windup")
	play.player.punch_time = 0.08
	var extended: Image = await sample("punch-extended")
	play.player.punch_time = 0
	play.player.velocity.x = 150
	play.avatar.elapsed = 0.11
	var walking: Image = await sample("walk")
	play.player.grounded = false
	var jumping: Image = await sample("jump")
	var checks := {"punch_changes_pose":idle.get_data()!=windup.get_data(),"punch_extension_changes":windup.get_data()!=extended.get_data(),"walking_changes_native_body_frame":idle.get_data()!=walking.get_data(),"jump_changes_pose":walking.get_data()!=jumping.get_data()}
	var file := FileAccess.open(folder+"/action-render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"  "))
	file.close()
	var strip := Image.create(140*images.size(),100,false,Image.FORMAT_RGBA8)
	for index in images.size():
		strip.blit_rect(images[index],Rect2i(0,0,140,100),Vector2i(index*140,0))
	strip.resize(strip.get_width()*3,300,Image.INTERPOLATE_NEAREST)
	strip.save_png(folder+"/action-strip.png")
	app.queue_free()
	await process_frame
	quit(1 if checks.values().has(false) else 0)
