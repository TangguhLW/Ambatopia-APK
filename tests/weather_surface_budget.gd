extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	var bg=load("res://src/ui/background.gd").new()
	bg.menu_mode=false;bg.weather="rlm";bg.set_meta("force_weather_viewport",true)
	root.add_child(bg)
	for i in 10:await process_frame
	bg.frame_probe.totals.clear();bg.frame_probe.enabled=true
	for i in 60:await process_frame
	var count:=int(bg.frame_probe.totals.get("weather_draw",{}).get("count",0))
	print("WEATHER_DRAW_BUDGET: ",count," weather draw callbacks / 60 main frames")
	quit(0 if count>0 and count<=61 else 1)
