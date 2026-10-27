extends PanelContainer

signal item_selected(item_id: int)
signal equipment_changed(slot: String,item_id: int)
signal catalog_equip_requested(item_id: int)
signal catalog_unequip_requested(slot: String)
signal save_set_requested
signal close_requested
signal drawer_dragged(distance: float, finished: bool)
const UI = preload("res://src/ui/theme.gd")
const Catalog = preload("res://src/game/item_catalog.gd")
const PAGE_SIZE := 32
var developer := false
var mode := "blocks"
var grid: GridContainer
var item_scroll: ScrollContainer
var item_content: Control
var window_start := -1
var window_end := -1
var search: LineEdit
var slot_filter: OptionButton
var supported_filter: CheckButton
var category_filter: OptionButton
var entries: Array = []
var page := 0
var page_label: Label
var detail: Label
var preview: TextureRect
var save_set: Button
var selected := -1
var worn: Dictionary = {}
var last_tapped := -1
var last_tap_time := 0
var handle_origin := 0.0
var handle_active := false
var handle_control: Control
var inspect_row: Control
var category_rail: ScrollContainer
var rail_buttons: Dictionary={}
var worn_dock: HBoxContainer
var card_width:=100.0
const CARD_HEIGHT:=106.0

func activate_item(id: int, now: int) -> void:
	inspect_item(id)
	if last_tapped == id and now - last_tap_time <= 400:
		var entry := Catalog.summary(id)
		if entry.get("equip",false) and entry.get("slot") != null:
			if is_worn(id):
				catalog_unequip_requested.emit(entry.slot)
			else:
				catalog_equip_requested.emit(id)
		last_tapped = -1
	else:
		last_tapped = id
	last_tap_time = now

func _ready() -> void:
	var panel_style := UI.box(Color("24334c"),8)
	panel_style.border_color=Color("89cce5")
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	add_theme_stylebox_override("panel",panel_style)
	var backing:=ColorRect.new()
	backing.color=Color("24334c")
	backing.show_behind_parent=true
	backing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",3)
	add_child(body)
	var handle := UI.label("━━━━",18)
	handle_control = handle
	handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle.custom_minimum_size.y = 44
	handle.mouse_filter = Control.MOUSE_FILTER_STOP
	handle.gui_input.connect(handle_gesture)
	body.add_child(handle)
	var header := HBoxContainer.new()
	body.add_child(header)
	search = LineEdit.new()
	search.add_theme_font_size_override("font_size",16)
	search.placeholder_text = "Search all items…"
	search.add_theme_stylebox_override("normal",catalog_style(false))
	search.add_theme_stylebox_override("focus",catalog_style(true))
	search.custom_minimum_size.y = 44
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(search)
	var close := compact_button("×",func(): close_requested.emit(),30)
	close.custom_minimum_size = Vector2(48,48)
	header.add_child(close)
	var tabs := HFlowContainer.new()
	body.add_child(tabs)
	for entry in [["Blocks","blocks"],["Clothes","clothes"],["All items","simulator"]]:
		tabs.add_child(compact_button(entry[0],func(): mode = entry[1]; page = 0; item_scroll.scroll_vertical=0; rebuild(),18))
	var filters := HFlowContainer.new()
	body.add_child(filters)
	slot_filter = OptionButton.new()
	slot_filter.fit_to_longest_item = false
	slot_filter.custom_minimum_size.y = 44
	slot_filter.add_theme_font_size_override("font_size",16)
	for slot in ["Slot","hat","hair","face","shirt","pants","feet","hand","back","neck","artifact"]:
		slot_filter.add_item(slot)
	filters.add_child(slot_filter)
	category_filter = OptionButton.new()
	category_filter.fit_to_longest_item = false
	category_filter.custom_minimum_size.y = 44
	category_filter.add_theme_font_size_override("font_size",14)
	for category in ["Category","clothing","block","seed","background","consumable","lock","tool","other"]:
		category_filter.add_item(category)
	filters.add_child(category_filter)
	supported_filter = CheckButton.new()
	supported_filter.text = "Equip"
	supported_filter.add_theme_font_size_override("font_size",14)
	filters.add_child(supported_filter)
	var content_row:=HBoxContainer.new()
	content_row.size_flags_vertical=Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation",8)
	body.add_child(content_row)
	category_rail=ScrollContainer.new()
	category_rail.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	category_rail.custom_minimum_size.x=132
	content_row.add_child(category_rail)
	set_meta("category_rail",true)
	var rail:=VBoxContainer.new()
	rail.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	category_rail.add_child(rail)
	for key in ["","hat","hair","face","shirt","pants","feet","hand","back","neck","artifact"]:
		var label: String={"":"All","neck":"Chest","artifact":"Ancestral"}.get(key,key.capitalize())
		var button:=Button.new()
		button.text=label;button.tooltip_text=label
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size=Vector2(0,44)
		button.add_theme_font_size_override("font_size",15)
		button.add_theme_stylebox_override("normal",catalog_style(false))
		button.add_theme_stylebox_override("pressed",catalog_style(true))
		button.pressed.connect(func():choose_slot(key))
		rail.add_child(button);rail_buttons[key]=button
	var scroll := ScrollContainer.new()
	item_scroll = scroll
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().value_changed.connect(func(_value): render_window())
	scroll.resized.connect(update_columns)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 60
	content_row.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	item_content = Control.new()
	item_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_content)
	item_content.add_child(grid)
	var dock_scroll:=ScrollContainer.new()
	dock_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	dock_scroll.custom_minimum_size.y=50
	body.add_child(dock_scroll)
	worn_dock=HBoxContainer.new()
	worn_dock.add_theme_constant_override("separation",4)
	dock_scroll.add_child(worn_dock)
	var footer := HBoxContainer.new()
	body.add_child(footer)
	page_label = Label.new()
	page_label.add_theme_font_size_override("font_size",14)
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(page_label)
	save_set=compact_button("Outfits",func(): save_set_requested.emit(),16)
	save_set.name="SaveSet"
	save_set.tooltip_text="Save or load outfit 1, 2 or 3 on this device. Your last worn set saves automatically."
	footer.add_child(save_set)
	var inspect := HBoxContainer.new()
	inspect_row = inspect
	inspect.custom_minimum_size.y = 48
	body.add_child(inspect)
	preview = TextureRect.new()
	preview.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(48,48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inspect.add_child(preview)
	detail = Label.new()
	detail.text = "Select an item. Unsupported effects are not simulated."
	detail.add_theme_font_size_override("font_size",13)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	inspect.add_child(detail)
	search.text_changed.connect(func(_text): page = 0; rebuild())
	slot_filter.item_selected.connect(func(_index): page = 0; rebuild())
	category_filter.item_selected.connect(func(_index): page = 0; rebuild())
	supported_filter.toggled.connect(func(_on): page = 0; rebuild())
	resized.connect(update_columns)
	rebuild()

func update_columns() -> void:
	if is_instance_valid(grid):
		if is_instance_valid(category_rail):
			category_rail.custom_minimum_size.x=84 if size.x<600 else 132
		var available:=maxf(100,item_scroll.size.x-12)
		grid.columns = clampi(int(available/100),2,10)
		card_width=maxf(72,floorf((available-(grid.columns-1)*4)/grid.columns))
		if is_instance_valid(item_content):
			item_content.custom_minimum_size.y = ceili(entries.size()/float(grid.columns))*CARD_HEIGHT
		window_start = -1
		render_window()

func scroll_page(direction: int) -> void:
	item_scroll.scroll_vertical = maxi(0,item_scroll.scroll_vertical+direction*maxi(64,int(item_scroll.size.y)-64))
	render_window()

func rebuild() -> void:
	if not is_instance_valid(grid):
		return
	slot_filter.visible = false
	category_rail.visible=mode in ["clothes","catalog"]
	supported_filter.visible = false
	category_filter.visible = mode in ["catalog","simulator"]
	save_set.visible = mode in ["clothes","catalog"]
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	entries.clear()
	if mode == "blocks":
		entries = preload("res://src/game/simulator_catalog.gd").query(search.text)
		entries = entries.filter(func(e): return e.category in ["block","background","lock","other"] and int(e.id) not in [0,1,18,32])
	elif mode == "simulator" or mode=="clothes":
		entries = preload("res://src/game/simulator_catalog.gd").query(search.text,"clothing" if mode=="clothes" else "" if category_filter.selected == 0 else category_filter.get_item_text(category_filter.selected))
		if mode=="clothes":
			entries = entries.filter(func(e): return preload("res://src/game/simulator_catalog.gd").slot(int(e.id))!="" and (slot_filter.selected==0 or preload("res://src/game/simulator_catalog.gd").slot(int(e.id))==slot_filter.get_item_text(slot_filter.selected)))
			var names := {}
			for entry in entries:
				names[str(entry.name).to_lower()] = true
			for entry in Catalog.query(search.text,"clothing","" if slot_filter.selected==0 else slot_filter.get_item_text(slot_filter.selected),true):
				if not names.has(str(entry.name).to_lower()):
					entries.append(entry)
	else:
		var slot := "" if slot_filter.selected == 0 else slot_filter.get_item_text(slot_filter.selected)
		var category := "" if category_filter.selected == 0 else category_filter.get_item_text(category_filter.selected)
		entries = Catalog.query(search.text,"clothing" if mode == "clothes" else category,slot,supported_filter.button_pressed)
	window_start = -1
	refresh_dock()
	update_columns()

func render_window() -> void:
	if not is_instance_valid(grid) or not is_instance_valid(item_scroll):
		return
	var first := maxi(0,int(item_scroll.scroll_vertical/CARD_HEIGHT)-1)*grid.columns
	var last := mini(entries.size(),first+(maxi(1,ceili(item_scroll.size.y/CARD_HEIGHT))+3)*grid.columns)
	if first==window_start and last==window_end:
		return
	window_start=first
	window_end=last
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	grid.position=Vector2(0,int(first/grid.columns)*CARD_HEIGHT)
	page_label.text="%d items · %d–%d" % [entries.size(),mini(first+1,entries.size()),last]
	for entry in entries.slice(first,last):
		var button := Button.new()
		button.custom_minimum_size = Vector2(card_width,CARD_HEIGHT-4)
		button.tooltip_text = entry.name
		if entry.get("simulator",false) and int(entry.id) in [6,7,8,9] and not developer:
			button.disabled = true
		var category: String = entry.get("category","lock" if entry.id == 5 else "block")
		var runtime_id: int=int(entry.id)+200000 if entry.get("simulator",false) else int(entry.id)
		button.set_meta("item_id",runtime_id)
		for state in ["normal","hover","pressed"]:button.add_theme_stylebox_override(state,catalog_style(selected==runtime_id))
		button.icon = preload("res://src/game/inventory_icons.gd").texture(int(entry.id)) if entry.get("simulator",false) else Catalog.icon(entry.original) if entry.has("original") else (UI.item_icon(entry.id) if entry.get("local",false) else Catalog.icon(int(entry.id)))
		if button.icon == null and entry.has("original"):
			button.icon = preload("res://src/game/inventory_icons.gd").texture(int(entry.original))
		var icon:=TextureRect.new()
		icon.name="ItemIcon"
		icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture=button.icon;button.icon=null
		icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var extent:=32.0*(2 if card_width>=72 else 1)
		icon.position=Vector2(floorf((card_width-extent)/2),4);icon.size=Vector2.ONE*extent
		icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		if entry.get("simulator",false) and category=="seed":
			var grown_id:=int(entry.id)-1
			var grown: Array=preload("res://src/game/simulator_catalog.gd").items().get(str(grown_id),[])
			if not grown.is_empty():
				button.tooltip_text+="\nGrows: "+str(grown[0])
				var result_icon:=TextureRect.new()
				result_icon.name="SeedResult"
				result_icon.texture=preload("res://src/game/inventory_icons.gd").texture(grown_id)
				result_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
				result_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				result_icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				result_icon.position=Vector2(card_width-36,36);result_icon.size=Vector2(32,32)
				result_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
				button.add_child(result_icon)
		var name_label:=UI.label(str(entry.name),13)
		name_label.name="ItemName"
		name_label.position=Vector2(5,70);name_label.size=Vector2(card_width-10,28)
		name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		name_label.max_lines_visible=2;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		button.add_child(name_label)
		if icon.texture == null:
			button.text = str(int(entry.id))
			button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func():
			if entry.get("simulator",false):
				var id := int(entry.id)
				var sim = preload("res://src/game/simulator_catalog.gd")
				if entry.category=="seed":inspect_item(200000+id)
				if sim.slot(id)!="":
					activate_item(200000+id,Time.get_ticks_msec())
				elif preload("res://src/game/placeable_blocks.gd").supports(100000+id) and entry.category == "lock":
					item_selected.emit(100000+id)
				elif sim.supported(200000+id):
					item_selected.emit(200000+id)
				elif developer and id in [6,8]:
					item_selected.emit(4 if id == 6 else 2)
				elif id in [6,7,8,9]:
					detail.text = "Main Door and Bedrock cannot be taken."
				elif not Catalog.summary(id).is_empty() and entry.name == Catalog.summary(id).name:
					activate_item(id,Time.get_ticks_msec())
				else:
					detail.text = entry.name + " · behavior not implemented yet"
			elif entry.get("local",false):
				item_selected.emit(entry.id)
			else:
				activate_item(int(entry.id),Time.get_ticks_msec()))
		grid.add_child(button)
		if not entry.get("local",false):
			var tick := UI.label("✓",18)
			tick.name="WornTick"
			tick.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			tick.position = Vector2(card_width-24,CARD_HEIGHT-27)
			tick.mouse_filter=Control.MOUSE_FILTER_IGNORE
			tick.modulate = Color("8dff73")
			tick.visible=is_worn(runtime_id)
			button.add_child(tick)

func inspect_item(id: int) -> void:
	selected = id
	refresh_card_states()
	inspect_row.visible = true
	var item := Catalog.record(id)
	var entry := Catalog.summary(id)
	if item.is_empty() or entry.is_empty():
		return
	preview.texture = Catalog.icon(id)
	var wearable: bool = entry.get("equip",false) and entry.get("slot") != null
	var state := "Wearable · double-tap to wear/remove" if wearable else "Select to use"
	if item.effects.any(func(effect): return effect.implementation == "local_gameplay"):
		state += " · local ability"
	if item.effects.any(func(effect): return effect.implementation == "not_implemented"):
		state += " · effects unavailable"
	detail.text = "%s (#%d)\n%s" % [item.name,id,state]
	detail.tooltip_text = str(item.description)
	var source:=Catalog.source_notes(id)
	if not source.is_empty():
		detail.tooltip_text+="\nGrowtopia Wiki · "+str(source.source_url)+"\n"+str(source.wiki_fields)
	if entry.get("category","")=="seed" and id>=200000:
		var grown: Array=preload("res://src/game/simulator_catalog.gd").items().get(str(id-200001),[])
		if not grown.is_empty():detail.text="%s\nGrows: %s"%[item.name,grown[0]]

func refresh_card_states() -> void:
	for card in grid.get_children():
		var id: int=card.get_meta("item_id",-1)
		for state in ["normal","hover","pressed"]:
			card.add_theme_stylebox_override(state,catalog_style(id==selected))
		var tick=card.get_node_or_null("WornTick")
		if tick!=null:tick.visible=is_worn(id)

func refresh_equipment() -> void:
	refresh_dock()
	refresh_card_states()
	if selected>=0:inspect_item(selected)

func compact_button(text: String, callback: Callable, font_size: int = 16) -> Button:
	var button := UI.button(text,callback,font_size)
	button.custom_minimum_size.y = 44
	for state in ["normal","pressed","focus"]:
		var style := catalog_style(state == "pressed")
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state,style)
	return button

func handle_gesture(event: InputEvent) -> void:
	var pointer := get_global_mouse_position().y
	var begin := false
	var finish := false
	if event is InputEventScreenTouch:
		pointer = event.position.y + handle_control.global_position.y
		begin = event.pressed
		finish = not event.pressed
	elif event is InputEventScreenDrag:
		pointer = event.position.y + handle_control.global_position.y
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		begin = event.pressed
		finish = not event.pressed
	elif not event is InputEventMouseMotion:
		return
	if begin:
		handle_active = true
		handle_origin = pointer
		drawer_dragged.emit(0.0,false)
	elif handle_active:
		drawer_dragged.emit(handle_origin-pointer,finish)
		if finish:
			handle_active = false
	get_viewport().set_input_as_handled()

static func catalog_style(selected: bool) -> StyleBoxFlat:
	var style:=UI.box(Color("354969") if selected else Color("27374f"),6)
	style.border_color=Color("ffe672") if selected else Color("567399")
	style.set_border_width_all(2)
	style.shadow_size=0
	style.content_margin_left=8;style.content_margin_right=8
	return style

func choose_slot(slot: String) -> void:
	mode="clothes"
	for i in slot_filter.item_count:
		if (i==0 and slot.is_empty()) or slot_filter.get_item_text(i)==slot:slot_filter.select(i);break
	item_scroll.scroll_vertical=0
	rebuild()
	for key in rail_buttons:
		rail_buttons[key].add_theme_stylebox_override("normal",catalog_style(key==slot))

func refresh_dock() -> void:
	if not is_instance_valid(worn_dock):return
	for child in worn_dock.get_children():
		worn_dock.remove_child(child)
		child.queue_free()
	for slot in ["hat","hair","face","shirt","pants","feet","hand","back","neck","artifact"]:
		var button:=Button.new()
		button.custom_minimum_size=Vector2(44,44)
		button.tooltip_text=slot.capitalize()+" — "+("tap to remove" if worn.has(slot) else "empty")
		button.add_theme_stylebox_override("normal",catalog_style(worn.has(slot)))
		if worn.has(slot):
			button.icon=Catalog.icon(int(worn[slot]));button.expand_icon=true
			button.add_theme_constant_override("icon_max_width",30)
			button.pressed.connect(func():catalog_unequip_requested.emit(slot))
		else:
			var sample: int={"hat":46,"hair":44,"face":34,"shirt":36,"pants":48,"feet":40,"hand":98,"back":362,"neck":1454,"artifact":5078}.get(slot,34)
			button.icon=Catalog.icon(sample);button.expand_icon=true
			button.add_theme_constant_override("icon_max_width",28)
			button.self_modulate=Color(0.7,0.8,0.9,0.65)
			button.pressed.connect(func():choose_slot(slot))
		worn_dock.add_child(button)

func is_worn(id: int) -> bool:
	if worn.values().has(id):return true
	var original:=id-200000 if id>=200000 else id
	for worn_id in worn.values():
		var other:=int(worn_id)-200000 if int(worn_id)>=200000 else int(worn_id)
		if other==original and Catalog.summary(int(worn_id)).get("name")==Catalog.summary(id).get("name"):return true
	return false
