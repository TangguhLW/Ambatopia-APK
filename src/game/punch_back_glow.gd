extends Node2D
var avatar
func _ready() -> void:
	show_behind_parent=true
	var blend=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
func _process(_dt: float) -> void:queue_redraw()
func _draw() -> void:
	if avatar==null or avatar.player==null:return
	if not preload("res://src/game/rayman_controller.gd").equipped(avatar.player):avatar.item_tracks.draw_punch(self,avatar.player,true,false)
