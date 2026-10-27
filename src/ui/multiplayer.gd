extends Control

const UI = preload("res://src/ui/theme.gd")
var app
var name_field: LineEdit
var world_field: LineEdit
var status: Label

func _ready() -> void:
	var background = load("res://src/ui/background.gd").new()
	background.generic_mode = true
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 340
	center.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	body.add_child(UI.label("Shared worlds — local test",24))
	name_field = LineEdit.new()
	name_field.text = app.profile.display_name
	name_field.max_length = 18
	name_field.placeholder_text = "Player name"
	body.add_child(name_field)
	world_field = LineEdit.new()
	world_field.text = "START"
	world_field.max_length = 18
	body.add_child(world_field)
	status = UI.label("Run the project server on this PC.\nAndroid connects through the USB test tunnel.\n64 players · session worlds · no official accounts.",16)
	body.add_child(status)
	body.add_child(UI.button("Join shared world",connect_room,22))
	body.add_child(UI.button("Back",func(): app.network.close(); app.navigate("login"),22))
	app.network.disconnected.connect(on_disconnect)
	app.network.received.connect(func(packet):
		if packet.get("ok") == false:
			status.text = str(packet.get("error","Could not join world."))
			app.network.close())

func connect_room() -> void:
	status.text = "Connecting to local game server..."
	var error: int = app.network.connect_room("ws://127.0.0.1:4192",name_field.text,world_field.text)
	if error != OK:
		status.text = "Could not connect ("+str(error)+")."

func on_disconnect() -> void:
	status.text = "Disconnected. Start the local server and try again."
