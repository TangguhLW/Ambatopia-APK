extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var args=OS.get_cmdline_user_args()
	var label: String=args[0] if not args.is_empty() else "after"
	for weather in ["iceage","rlm"]:
		var bg=load("res://src/ui/background.gd").new()
		if label=="surface":
			bg.menu_mode=false
			bg.set_meta("force_weather_viewport",true)
		root.add_child(bg);bg.menu_mode=false;bg.weather=weather;bg.camera_offset=1600;bg.set_process(false)
		for age in [0.25,4.5]:
			bg.elapsed=age;bg.queue_redraw()
			if bg.weather_canvas!=null:bg.sync_weather_surface()
			await process_frame;await RenderingServer.frame_post_draw
			await process_frame;await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/render-regression/weather-"+label+"-"+weather+"-"+str(age)+".png")
		bg.queue_free();await process_frame
	print("WEATHER_CAPTURE_DONE: "+label)
	quit()
