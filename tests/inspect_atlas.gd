extends SceneTree

func _initialize() -> void:
	var image := Image.load_from_file("res://assets/reference/tiles.png")
	var region := image.get_region(Rect2i(256, 640, 224, 192))
	region.resize(896, 768, Image.INTERPOLATE_NEAREST)
	region.save_png("res://evidence/dirt-frame-inspection.png")
	quit()
