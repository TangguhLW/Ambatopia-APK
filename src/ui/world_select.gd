extends Control

const UI = preload("res://src/ui/theme.gd")
var app
var field: LineEdit
var error: Label
var chat_panel: PanelContainer
var worlds: HFlowContainer
var back: Button
var enter: Button
var world_label: Label
var hint: Label

func _ready() -> void:
	var background = load("res://src/ui/background.gd").new()
	background.generic_mode = true
	add_child(background)
	chat_panel = PanelContainer.new()
	chat_panel.name = "WorldChat"
	add_child(chat_panel)
	var history := UI.label("Where would you like to go?\nLocal project environment • " + app.profile.display_name + "\nChoose a saved world or enter a new name.",16)
	history.autowrap_mode = TextServer.AUTOWRAP_OFF
	chat_panel.add_child(history)
	world_label = UI.label("World Name:",22)
	world_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(world_label)
	field = LineEdit.new()
	field.text = "START"
	field.max_length = 18
	field.add_theme_font_size_override("font_size",24)
	add_child(field)
	hint = UI.label("Tap 'Enter World' to enter this local world!",20)
	add_child(hint)
	worlds = HFlowContainer.new()
	worlds.add_theme_constant_override("h_separation",14)
	worlds.add_theme_constant_override("v_separation",10)
	add_child(worlds)
	var showing := UI.button("Showing: Local Worlds", func(): field.text = "START",24)
	showing.add_theme_stylebox_override("normal",UI.box(Color("783586")))
	worlds.add_child(showing)
	for world in app.session.world_names():
		var button := UI.button(world, func(): field.text = world,22)
		button.custom_minimum_size.y = 36
		button.add_theme_stylebox_override("normal",UI.box(Color("783586")))
		worlds.add_child(button)
	back = UI.button("Back",func(): app.navigate("menu"),50)
	enter = UI.button("Enter World",enter_world,50)
	for button in [back,enter]:
		button.add_theme_stylebox_override("normal",UI.box(Color("587985")))
		add_child(button)
	error = UI.label("",18)
	error.modulate = Color("ffdc8a")
	add_child(error)
	field.text_submitted.connect(func(_value): enter_world())
	resized.connect(layout)
	layout()
	if app.shared_selection:
		hint.text = "Choose a shared world or enter a new name."
		showing.text = "Shared worlds"
		app.network.received.connect(func(packet):
			if packet.get("ok") == false:
				error.text = packet.get("error","Could not enter world.")
				app.network.close())
		load_shared_worlds()

func load_shared_worlds() -> void:
	var result: Dictionary = await app.accounts.request("/worlds",{},HTTPClient.METHOD_GET)
	if not is_inside_tree():
		return
	if not result.ok:
		error.text = result.get("error","Could not load shared worlds.")
		return
	for child in worlds.get_children():
		child.queue_free()
	for entry in result.worlds:
		var button := UI.button("%s (%d)" % [entry.name,entry.get("count",0)],func(): field.text = entry.name,22)
		button.add_theme_stylebox_override("normal",UI.box(Color("783586")))
		worlds.add_child(button)

func layout() -> void:
	var sx := size.x / 1061
	var sy := size.y / 543
	chat_panel.position = Vector2.ZERO
	chat_panel.size = Vector2(size.x * 0.918,size.y * 0.154)
	hint.position = Vector2(192 * sx,103 * sy)
	hint.size = Vector2(size.x * 0.75,26)
	world_label.position = Vector2(42 * sx,134 * sy)
	world_label.size = Vector2(142 * sx,38)
	field.position = Vector2(183 * sx,127 * sy)
	field.size = Vector2(658 * sx,44 * sy)
	worlds.position = Vector2(15 * sx,183 * sy)
	worlds.size = Vector2(size.x - 30 * sx,150 * sy)
	back.position = Vector2(86 * sx,size.y - 102 * sy)
	back.size = Vector2(146 * sx,86 * sy)
	enter.position = Vector2(size.x - 450 * sx,size.y - 102 * sy)
	enter.size = Vector2(289 * sx,86 * sy)
	var factor := minf(sx,sy)
	for button in [back,enter]:
		button.add_theme_font_size_override("font_size",roundi(50 * factor))
	error.position = Vector2(size.x * 0.18,size.y * 0.64)
	error.size = Vector2(size.x * 0.7,40)

func enter_world() -> void:
	var result: Dictionary = app.enter_world(field.text)
	if not result.ok:
		error.text = result.error
