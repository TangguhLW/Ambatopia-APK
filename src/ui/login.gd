extends Control

const UI = preload("res://src/ui/theme.gd")
var app
var field: LineEdit
var password_field: LineEdit
var error: Label
var form: VBoxContainer
var busy := false
var online_button: Button
var credentials: VBoxContainer

func _ready() -> void:
	var background = load("res://src/ui/background.gd").new()
	background.generic_mode = true
	add_child(background)
	var panel=load("res://src/ui/page_panel.gd").new()
	panel.name="AccountPanel"
	panel.max_width=600
	add_child(panel)
	form=panel.column
	form.add_child(UI.label("Welcome to Ambatopia",26))
	credentials = VBoxContainer.new()
	credentials.add_theme_constant_override("separation",8)
	form.add_child(credentials)
	credentials.add_child(UI.label("AmbaID",18))
	field = LineEdit.new()
	field.name = "ProfileName"
	field.placeholder_text = "AmbaID"
	field.max_length = 18
	field.custom_minimum_size.y = 48
	credentials.add_child(field)
	credentials.add_child(UI.label("Password",18))
	password_field = LineEdit.new()
	password_field.secret = true
	password_field.placeholder_text = "Password"
	password_field.max_length = 72
	password_field.custom_minimum_size.y = 48
	password_field.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_PASSWORD
	credentials.add_child(password_field)
	var actions := HFlowContainer.new()
	credentials.add_child(actions)
	actions.add_child(UI.button("Login",func(): authenticate(false),24))
	actions.add_child(UI.button("Create AmbaID",func(): authenticate(true),24))
	error = UI.label("Private game account · no email or SMS required",18)
	form.add_child(error)
	var secondary := HFlowContainer.new()
	form.add_child(secondary)
	secondary.add_child(UI.button("Offline creative",connect_local,20))
	online_button = UI.button("Online mode · checking...",choose_online,20)
	secondary.add_child(online_button)
	secondary.add_child(UI.button("Back",func(): app.navigate("menu"),22))
	password_field.text_submitted.connect(func(_text): authenticate(false))
	credentials.visible = app.accounts.access_token.is_empty()
	if not credentials.visible:
		error.text = "Signed in as " + app.accounts.profile.amba_id
	update_online()

func update_online() -> void:
	var result: Dictionary = await app.accounts.request("/online",{},HTTPClient.METHOD_GET)
	if is_instance_valid(online_button):
		online_button.text = "Online mode · %d online" % int(result.get("online",0)) if result.ok else "Online mode · server unavailable"

func choose_online() -> void:
	if app.accounts.access_token.is_empty():
		credentials.show()
		field.grab_focus()
		return
	app.profile = {"id":app.accounts.profile.id,"display_name":app.accounts.profile.amba_id}
	app.shared_selection = true
	app.navigate("worlds")

func authenticate(register: bool) -> void:
	if busy:
		return
	busy = true
	error.text = "Creating AmbaID..." if register else "Logging in..."
	var result: Dictionary = await app.accounts.authenticate(field.text,password_field.text,register)
	busy = false
	password_field.text = ""
	if not result.ok:
		error.text = result.get("error","Login failed.")
		return
	app.profile = {"id":result.profile.id,"display_name":result.profile.amba_id}
	app.set_meta("profile_active",true)
	app.shared_selection = true
	app.navigate("worlds")

func connect_local() -> void:
	var value := field.text.strip_edges()
	if value.length()<2:
		value = "Player"
	app.start_local(value)
