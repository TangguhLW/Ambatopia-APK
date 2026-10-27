extends SceneTree
func _initialize():call_deferred("run")
func run():
	root.size=Vector2i(1000,900);root.content_scale_size=root.size
	DisplayServer.window_set_size(root.size)
	var canvas=Control.new();root.add_child(canvas)
	var bg=ColorRect.new();bg.color=Color("173342");bg.size=root.size;canvas.add_child(bg)
	var samples=[5078,5080,5082,5084,7166,5134,5152,5170,5188,9212]
	for i in samples.size():
		var p=load("res://src/game/player_state.gd").new();p.grounded=true;p.catalog_equipment={"artifact":samples[i]}
		var avatar=load("res://src/game/avatar_view.gd").new();avatar.scale=Vector2.ONE*4
		avatar.position=Vector2(150+(i%5)*190,230+int(i/5)*380)
		canvas.add_child(avatar);avatar.present(p,0)
		var label=load("res://src/ui/theme.gd").label(str(samples[i]),22)
		label.position=avatar.position+Vector2(-35,50);canvas.add_child(label)
		label.size=Vector2(130,40);label.autowrap_mode=TextServer.AUTOWRAP_OFF
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/render-regression/ancestral-021.png")
	quit()
