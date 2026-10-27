extends RefCounted

const TEAL := Color("a5e3fb")
const PANEL := Color("15546be8")
static var source_bounds: Dictionary={}

static func box(color: Color, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("182d38")
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2, 3)
	return style

static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = load("res://assets/reference/font.ttf")
	theme.default_font_size = 24
	for type in ["Button", "Label", "LineEdit", "CheckButton"]:
		theme.set_color("font_color", type, Color.WHITE)
		theme.set_color("font_shadow_color", type, Color("172e38"))
		theme.set_constant("shadow_offset_x", type, 1)
		theme.set_constant("shadow_offset_y", type, 2)
	for state in ["normal","hover","pressed","disabled"]:
		theme.set_stylebox(state,"Button",button_style())
	theme.set_stylebox("focus", "Button", box(Color(0.4, 0.8, 0.9, 0.25)))
	theme.set_stylebox("panel", "PanelContainer", panel_style())
	theme.set_stylebox("normal", "LineEdit", box(Color("325967")))
	theme.set_stylebox("focus", "LineEdit", box(Color("386c80")))
	theme.set_color("font_outline_color","Button",Color("20303a"))
	theme.set_constant("outline_size","Button",1)
	return theme

static func button_style() -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	style.texture=load("res://assets/reference/panel_up.png")
	style.modulate_color=TEAL
	style.texture_margin_left=9
	style.texture_margin_right=9
	style.texture_margin_top=9
	style.texture_margin_bottom=9
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=4
	style.content_margin_bottom=4
	return style

static func panel_style() -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = load("res://assets/reference/panel_tinted.png")
	style.texture_margin_left = 15
	style.texture_margin_right = 15
	style.texture_margin_top = 15
	style.texture_margin_bottom = 15
	style.content_margin_left = 12
	style.content_margin_top = 6
	style.content_margin_right = 12
	style.content_margin_bottom = 6
	return style

static func slot_style(category: String, selected: bool=false) -> StyleBoxTexture:
	var cells={"clothing":Vector2(40,80),"lock":Vector2(0,80),"seed":Vector2(0,40),"consumable":Vector2(80,40)}
	var style:=StyleBoxTexture.new()
	style.texture=load("res://assets/reference/itembox.png")
	style.region_rect=Rect2(Vector2(40,40) if selected else cells.get(category,Vector2.ZERO),Vector2(40,40))
	for side in ["left","right","top","bottom"]:
		style.set_texture_margin(side_index(side),6)
		style.set_content_margin(side_index(side),6)
	return style

static func side_index(value: String) -> Side:
	return {"left":SIDE_LEFT,"right":SIDE_RIGHT,"top":SIDE_TOP,"bottom":SIDE_BOTTOM}[value]

static func sprite(id: String, region: Rect2 = Rect2()) -> Texture2D:
	var texture: Texture2D = load("res://assets/reference/%s.png" % id)
	if region.size==Vector2.ZERO and id in ["left","right","jump","punch","menu_toggle","chat_handle"]:
		if source_bounds.is_empty():
			var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/reference/manifest.json"))
			for entry in manifest:
				if entry.has("originalWidth"):source_bounds[entry.id]=Vector2(entry.originalWidth,entry.originalHeight)
		if source_bounds.has(id):region=Rect2(Vector2.ZERO,source_bounds[id])
	if region.size != Vector2.ZERO:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = region
		atlas.filter_clip = true
		return atlas
	return texture

static func item_icon(item_id: int) -> Texture2D:
	if item_id>=200000:
		return preload("res://src/game/inventory_icons.gd").texture(item_id-200000)
	if item_id>=100000:
		return preload("res://src/game/inventory_icons.gd").texture(item_id-100000)
	if item_id == -1:
		return sprite("tiles",Rect2(992,32,32,32))
	if item_id == 0:
		return sprite("tiles", Rect2(352, 32, 32, 32))
	return preload("res://src/game/inventory_icons.gd").texture(int({1:2,2:8,3:10,4:6,5:242,6:108,7:4}.get(item_id,-1)))

static func label(text: String, font_size: int = 24) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func button(text: String, callback: Callable, font_size: int = 28) -> Button:
	var result: Button = load("res://src/ui/text_button.gd").new()
	result.text = text
	result.alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", font_size)
	result.custom_minimum_size.y = 52
	result.pressed.connect(callback)
	return result

static func panel(parent: Control, width: float = 700) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_meta("motion_visual",true)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size.x = minf(width,maxf(200,parent.size.x-32))
	center.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var resize_panel := func():
		frame.custom_minimum_size.x = minf(width,maxf(200,parent.size.x-32))
		scroll.custom_minimum_size.y = minf(maxf(120,parent.size.y-48),column.get_combined_minimum_size().y+44)
	parent.resized.connect(resize_panel)
	column.minimum_size_changed.connect(resize_panel)
	return column
