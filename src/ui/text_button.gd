extends Button

var caption: Label
func _ready() -> void:
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.clip_text = true
	caption.add_theme_color_override("font_shadow_color",Color("172e38"))
	caption.add_theme_color_override("font_color",get_meta("caption_color",Color.WHITE))
	caption.add_theme_constant_override("shadow_offset_x",1)
	caption.add_theme_constant_override("shadow_offset_y",2)
	add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	update_caption()
func _process(_delta: float) -> void:
	update_caption()
func update_caption() -> void:
	if caption == null:
		return
	if caption.text != text:
		caption.text = text
	var font_size := get_theme_font_size("font_size")
	if caption.get_theme_font_size("font_size") != font_size:
		caption.add_theme_font_size_override("font_size",font_size)
	caption.modulate.a = 0.45 if disabled else 1.0
	var offset: float=preload("res://src/ui/motion.gd").PRESS_OFFSET if is_pressed() and not disabled else 0.0
	caption.offset_top=offset
	caption.offset_bottom=offset
