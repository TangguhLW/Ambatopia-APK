extends Control

const UI = preload("res://src/ui/theme.gd")
const RECTS := {"play": Rect2(319,382,376,84), "options": Rect2(397,479,220,66), "about": Rect2(397,555,220,66), "quit": Rect2(397,631,220,66), "logo": Rect2(115,22,785,315)}
var app
var logo: TextureRect
var elapsed := 0.0
var controls := {}
var account: VBoxContainer
var version: Label

func reference_geometry(view: Vector2) -> Dictionary:
	var factor := minf(view.x / 1015.0, view.y / 772.0)
	var origin := Vector2((view.x - 1015 * factor) / 2, 0)
	var result := {}
	for id in RECTS:
		var rect: Rect2 = RECTS[id]
		result[id] = Rect2((origin + rect.position * factor).round(), (rect.size * factor).round())
	return result

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(load("res://src/ui/background.gd").new())
	logo = TextureRect.new()
	logo.texture = load("res://assets/ambatopia/title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	for entry in [["play","Play Online","login"],["options","Options","options"],["about","About","about"],["quit","Download","download"]]:
		var destination: String = entry[2]
		var button := UI.button(entry[1], func(): get_tree().quit() if destination == "quit" else app.navigate(destination))
		button.custom_minimum_size = Vector2.ZERO
		if entry[0] == "play":
			button.add_theme_stylebox_override("normal", UI.box(Color("2cbd30")))
			button.add_theme_stylebox_override("hover", UI.box(Color("37d139")))
		controls[entry[0]] = button
		add_child(button)
	account = VBoxContainer.new()
	add_child(account)
	account.add_child(UI.label("Logged in as:",26))
	var name_label := UI.label(app.profile.display_name,28)
	name_label.modulate = Color("75ff16")
	account.add_child(name_label)
	var logout := UI.button("Logout", func(): app.accounts.logout(); app.shared_selection = false; app.profile.display_name = "Player"; app.set_meta("profile_active",false); app.navigate("menu"),36)
	logout.add_theme_stylebox_override("normal", UI.box(Color("ffd000")))
	logout.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	logout.custom_minimum_size.x = 160
	account.add_child(logout)
	account.visible = app.get_meta("profile_active",false)
	version = UI.label("Godot "+str(JSON.parse_string(FileAccess.get_file_as_string("res://data/build-info.json")).get("version","")).split("-")[0],18)
	add_child(version)
	resized.connect(layout)
	layout()

func layout() -> void:
	var geometry := reference_geometry(size)
	logo.position = geometry.logo.position
	logo.size = geometry.logo.size
	var factor := minf(size.x / 1015,size.y / 772)
	for id in controls:
		controls[id].add_theme_font_size_override("font_size",roundi((56 if id == "play" else (36 if id == "quit" else 48)) * factor))
		controls[id].position = geometry[id].position
		controls[id].size = geometry[id].size
	account.position = Vector2(20 * factor,size.y - 170 * factor)
	account.size = Vector2(250 * factor,150 * factor)
	version.position = Vector2(size.x - 155,size.y - 45)
	version.size = Vector2(140,34)
	for child in account.get_children():
		child.add_theme_font_size_override("font_size",maxi(14,roundi(26*factor)))
	if size.x < 650 and size.y > size.x:
		logo.position = Vector2(size.x*0.05,30)
		logo.size = Vector2(size.x*0.9,size.x*0.5)
		var index := 0
		for id in controls:
			controls[id].add_theme_font_size_override("font_size",28 if id == "play" else 24)
			controls[id].position = Vector2(size.x*0.14,logo.position.y+logo.size.y+24+index*62)
			controls[id].size = Vector2(size.x*0.72,52)
			index += 1
		account.position = Vector2(16,size.y-155)
		account.size = Vector2(210,140)
		for child in account.get_children():
			child.add_theme_font_size_override("font_size",18)

func _process(delta: float) -> void:
	if app.get_meta("visual_freeze",false):
		return
	elapsed += delta
	var geometry := reference_geometry(size)
	var base_y: float = 30 if size.x < 650 and size.y > size.x else geometry.logo.position.y
	logo.position.y = base_y + roundf(sin(elapsed * 1.5) * minf(size.y,600) * 0.008)
