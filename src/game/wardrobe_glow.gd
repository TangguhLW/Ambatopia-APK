extends Node2D
var avatar
func _ready() -> void:
	var blend=CanvasItemMaterial.new()
	blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	material=blend
func _process(_dt: float) -> void:queue_redraw()
func _draw() -> void:
	if avatar==null or avatar.player==null or avatar.player.amba:return
	draw_set_transform(Vector2.ZERO,0,Vector2(avatar.player.facing,1))
	for hook in avatar.special_wardrobe.compiled:
		avatar.special_wardrobe.draw_hook(self,hook,avatar.player.facing,true)
	avatar.legacy_particles.draw(self,avatar.player,true)
	avatar.ancestral_particles.draw(self,avatar.player,true)
	if not preload("res://src/game/rayman_controller.gd").equipped(avatar.player):avatar.item_tracks.draw_punch(self,avatar.player,true)
