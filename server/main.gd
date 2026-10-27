extends SceneTree

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	root.add_child(load("res://server/runtime.gd").new())
