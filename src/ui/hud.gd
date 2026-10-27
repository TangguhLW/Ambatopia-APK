extends Control

signal hold_started(action: String)
signal hold_ended(action: String)
signal mode_selected(action: String,item_id: int)
signal inventory_requested
signal inventory_dragged(distance: float, finished: bool)
signal menu_requested
signal chat_requested
signal chat_height_requested(height: float)
const UI = preload("res://src/ui/theme.gd")
var title: Label
var status: Label
var top: Control
var bar: HBoxContainer
var left: Button
var right: Button
var jump: Button
var punch: Button
var menu: Button
var chat_button: Button
var drawer: TextureRect
var drawer_pressed := false
var drawer_moved := false
var drawer_origin := 0.0
var inventory_drawer: Button
var touch_bindings := {}
var message_until := 0
var inventory_drag_origin := Vector2.ZERO
var ignore_inventory_click_until := 0
var inventory_touch := -1
var overlay_blocked := false
var quick_images: Array[TextureRect]=[]
var selected_slot:=0

func show_message(text: String, seconds: float = 5) -> void:
	status.text = text
	status.visible = true
	status.position = Vector2(16,65)
	status.size = Vector2(size.x - 32,50)
	message_until = Time.get_ticks_msec() + roundi(seconds * 1000)

func _process(_delta: float) -> void:
	if status != null and status.visible and Time.get_ticks_msec() > message_until:
		status.visible = false

func clear_touches() -> void:
	for action in touch_bindings.values():
		hold_ended.emit(action)
	touch_bindings.clear()

func route_touch(index: int,point: Vector2,pressed: bool) -> bool:
	if not pressed:
		if touch_bindings.has(index):
			hold_ended.emit(touch_bindings[index])
			touch_bindings.erase(index)
			return true
		return false
	if overlay_blocked:
		return false
	for pair in [[left,"left"],[right,"right"],[jump,"jump"],[punch,"punch"]]:
		if pair[0].get_global_rect().has_point(point):
			touch_bindings[index] = pair[1]
			hold_started.emit(pair[1])
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not overlay_blocked and inventory_drawer.get_global_rect().has_point(event.position):
			inventory_touch = event.index
			inventory_drag_origin = event.position
			inventory_dragged.emit(0.0,false)
			get_viewport().set_input_as_handled()
			return
		if event.index == inventory_touch and not event.pressed:
			inventory_touch = -1
			ignore_inventory_click_until = Time.get_ticks_msec()+300
			inventory_dragged.emit(inventory_drag_origin.y-event.position.y,true)
			get_viewport().set_input_as_handled()
			return
		if route_touch(event.index,event.position,event.pressed):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == inventory_touch:
		inventory_dragged.emit(inventory_drag_origin.y-event.position.y,false)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touch_bindings.has(event.index):
		route_touch(event.index,event.position,false)
		route_touch(event.index,event.position,true)
		get_viewport().set_input_as_handled()

func icon_button(texture: Texture2D,tip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(image)
	return button

func held_button(id: String,action: String) -> Button:
	var button := icon_button(UI.sprite(id),action.capitalize())
	button.modulate.a = 0.78
	button.button_down.connect(func(): hold_started.emit(action))
	button.button_up.connect(func(): hold_ended.emit(action))
	add_child(button)
	return button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = UI.label("",16)
	add_child(title)
	title.visible = false
	status = UI.label("",17)
	add_child(status)
	status.visible = false
	top = Control.new()
	add_child(top)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = icon_button(UI.sprite("menu_toggle",Rect2(0,0,141,138)),"World menu")
	menu.pressed.connect(func(): menu_requested.emit())
	top.add_child(menu)
	chat_button = icon_button(UI.sprite("chat",Rect2(0,0,136,106)),"Chat")
	chat_button.pressed.connect(func(): chat_requested.emit())
	top.add_child(chat_button)
	drawer = TextureRect.new()
	drawer.texture = UI.sprite("chat_handle")
	drawer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drawer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	drawer.gui_input.connect(draw_chat_input)
	add_child(drawer)
	inventory_drawer = icon_button(UI.sprite("chat_handle"),"Open inventory")
	inventory_drawer.pressed.connect(func():
		if Time.get_ticks_msec() >= ignore_inventory_click_until:
			inventory_requested.emit())
	add_child(inventory_drawer)
	bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation",3)
	add_child(bar)
	for entry in [[0,"Punch","punch"],[1,"Dirt","place"],[3,"Rock","place"],[-1,"Wrench","wrench"]]:
		var button := Button.new()
		button.custom_minimum_size = Vector2(66,72)
		button.tooltip_text = entry[1]
		button.set_meta("item",int(entry[0]))
		var style := StyleBoxTexture.new()
		style.texture = UI.sprite("itembox",Rect2(40,40,40,40) if entry[0] == 0 else Rect2(0,0,40,40))
		style.texture_margin_left = 9
		style.texture_margin_right = 9
		style.texture_margin_top = 9
		style.texture_margin_bottom = 9
		button.add_theme_stylebox_override("normal",style)
		var picture := TextureRect.new()
		picture.texture = UI.item_icon(entry[0])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 8
		picture.offset_top = 8
		picture.offset_right = -8
		picture.offset_bottom = -8
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
		quick_images.append(picture)
		button.pressed.connect(func(): mode_selected.emit(entry[2],int(button.get_meta("item"))))
		bar.add_child(button)
	left = held_button("left","left")
	right = held_button("right","right")
	jump = held_button("jump","jump")
	punch = held_button("punch","punch")
	resized.connect(layout)
	bar.minimum_size_changed.connect(layout)
	layout()

func set_selection(action: String,id: int) -> void:
	selected_slot=0 if action=="punch" else 3 if action=="wrench" else 2 if id==3 else 1
	if action=="place" and selected_slot==1:
		bar.get_child(1).set_meta("item",id)
		quick_images[1].texture=UI.item_icon(id)
		bar.get_child(1).tooltip_text="Selected item #"+str(id)
	for i in bar.get_child_count():
		var style:=StyleBoxTexture.new()
		style.texture=UI.sprite("itembox",Rect2(40,40,40,40) if i==selected_slot else Rect2(0,0,40,40))
		style.texture_margin_left=9
		style.texture_margin_right=9
		style.texture_margin_top=9
		style.texture_margin_bottom=9
		bar.get_child(i).add_theme_stylebox_override("normal",style)

func draw_chat_input(event: InputEvent) -> void:
	var pointer := 0.0
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = event.global_position.y
		if event.pressed:
			drawer_pressed = true
			drawer_moved = false
			drawer_origin = pointer
		else:
			drawer_pressed = false
			if not drawer_moved:
				chat_requested.emit()
	elif event is InputEventMouseMotion and drawer_pressed:
		pointer = event.global_position.y
		if absf(pointer - drawer_origin) > 5:
			drawer_moved = true
			chat_height_requested.emit(clampf(pointer,0,size.y * 0.7))
	elif event is InputEventScreenTouch:
		if event.pressed:
			drawer_pressed = true
			drawer_moved = false
			drawer_origin = event.position.y + drawer.position.y
		else:
			drawer_pressed = false
			if not drawer_moved:
				chat_requested.emit()
	elif event is InputEventScreenDrag and drawer_pressed:
		pointer = event.position.y + drawer.position.y
		if absf(pointer - drawer_origin) > 5:
			drawer_moved = true
			chat_height_requested.emit(clampf(pointer,0,size.y * 0.7))
	drawer.accept_event()

func layout() -> void:
	if not is_instance_valid(bar):
		return
	var factor := minf(size.x / 1037,size.y / 505)
	top.position = Vector2.ZERO
	top.size = size
	menu.position = Vector2(size.x - maxf(140 * factor,64),0)
	menu.size = (Vector2(75,80) * factor).max(Vector2(48,48))
	chat_button.position = Vector2(size.x - maxf(140 * factor,64),maxf(95 * factor,60))
	chat_button.size = (Vector2(75,58) * factor).max(Vector2(52,44))
	drawer.position = Vector2(size.x / 2 - 32 * factor,-8 * factor)
	drawer.size = Vector2(64,54) * factor
	inventory_drawer.position = Vector2(size.x / 2 - 32 * factor,size.y - 125 * factor)
	inventory_drawer.size = Vector2(64,48) * factor
	left.position = Vector2(50 * factor,size.y - maxf(105 * factor,48))
	right.position = Vector2(214 * factor,size.y - maxf(105 * factor,48))
	left.size = (Vector2(156,100) * factor).max(Vector2(52,44))
	right.size = (Vector2(156,100) * factor).max(Vector2(52,44))
	jump.position = Vector2(size.x - 355 * factor,size.y - 124 * factor)
	punch.position = Vector2(size.x - 185 * factor,size.y - 124 * factor)
	jump.size = Vector2(135,122) * factor
	punch.size = Vector2(135,122) * factor
	var slot_size := clampf(66*factor,48,72)
	for button in bar.get_children():
		button.custom_minimum_size = Vector2(slot_size,slot_size)
	bar.size = Vector2(slot_size*4+9,slot_size).max(bar.get_combined_minimum_size())
	bar.position = Vector2((size.x-bar.size.x)/2,size.y-bar.size.y-8)
	inventory_drawer.size = Vector2(64,44)
	inventory_drawer.position = Vector2((size.x-64)/2,bar.position.y-44)
	jump.size = jump.size.max(Vector2(56,56))
	punch.size = punch.size.max(Vector2(56,56))
	if size.x < 700:
		var controls_y := bar.position.y-68
		left.size = Vector2(64,56)
		right.size = Vector2(64,56)
		left.position = Vector2(8,controls_y)
		right.position = Vector2(76,controls_y)
		jump.size = Vector2(56,56)
		punch.size = Vector2(56,56)
		jump.position = Vector2(size.x-128,controls_y)
		punch.position = Vector2(size.x-64,controls_y)
