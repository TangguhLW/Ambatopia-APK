extends Node2D
var avatar
func _ready() -> void:
	show_behind_parent=true
	var blend:=CanvasItemMaterial.new()
	blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	material=blend
func _process(_dt: float) -> void:queue_redraw()
func _draw() -> void:
	if avatar==null or avatar.player==null or avatar.player.amba:return
	avatar.ancestral_particles.draw(self,avatar.player,true,false)
