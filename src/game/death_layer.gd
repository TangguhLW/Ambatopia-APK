extends Node2D
var avatar
var additive:=false
func _ready() -> void:
	if additive:
		var blend=CanvasItemMaterial.new();blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD;material=blend
func _process(_dt: float) -> void:
	if avatar==null or avatar.player==null:return
	var body_scale:=float(avatar.death_sequence.visual(avatar.player).scale) if avatar.player.death_time>=0 else 1.0
	scale=Vector2.ONE/maxf(0.01,body_scale)
	queue_redraw()
func _draw() -> void:
	if avatar!=null and avatar.player!=null:avatar.death_sequence.draw(self,avatar.player,additive)
