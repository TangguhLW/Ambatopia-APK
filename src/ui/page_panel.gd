extends PanelContainer
const UI=preload("res://src/ui/theme.gd")
var column: VBoxContainer
var scroll: ScrollContainer
var previous_extent:=Vector2.ZERO
var previous_keyboard:=-1
var max_width:=720.0
func _ready():
	add_theme_stylebox_override("panel",UI.panel_style())
	var backing:=ColorRect.new()
	backing.color=Color("123e50")
	backing.show_behind_parent=true
	backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	add_child(scroll)
	var margin:=MarginContainer.new()
	margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,12)
	scroll.add_child(margin)
	column=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	reflow()
func _process(_dt):
	if get_parent().size!=previous_extent or keyboard_height()!=previous_keyboard:reflow()
func keyboard_height() -> int:
	return DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0
func reflow(keyboard_override: int=-1):
	if not is_instance_valid(scroll):return
	var extent: Vector2=get_parent().size
	var physical:=Vector2(DisplayServer.window_get_size())
	var scale_y:=extent.y/maxf(1,physical.y)
	var keyboard:=keyboard_height() if keyboard_override<0 else keyboard_override
	previous_extent=extent
	previous_keyboard=keyboard
	var inset:=Vector4(12,12,12,12)
	if OS.get_name()=="Android":
		var safe:=DisplayServer.get_display_safe_area()
		var window:=Rect2i(DisplayServer.window_get_position(),DisplayServer.window_get_size())
		var scale_x:=extent.x/maxf(1,physical.x)
		inset.x+=maxi(0,safe.position.x-window.position.x)*scale_x
		inset.y+=maxi(0,safe.position.y-window.position.y)*scale_y
		inset.z+=maxi(0,window.end.x-safe.end.x)*scale_x
		inset.w+=maxi(0,window.end.y-safe.end.y)*scale_y
	var available:=Vector2(maxf(100,extent.x-inset.x-inset.z),maxf(80,extent.y-inset.y-inset.w-keyboard*scale_y))
	size=Vector2(minf(max_width,available.x),available.y)
	position=Vector2(inset.x+(available.x-size.x)/2,inset.y)
	var focused:=get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and is_ancestor_of(focused):scroll.call_deferred("ensure_control_visible",focused)
