extends "res://src/ui/motion_panel.gd"

const UI = preload("res://src/ui/theme.gd")
var app
var kind := "about"
var close_action: Callable

func _ready() -> void:
	reduced_motion=not app.settings.get("animations",true)
	super._ready()
	add_child(load("res://src/ui/background.gd").new())
	var panel=load("res://src/ui/page_panel.gd").new()
	panel.name="PagePanel"
	panel.set_meta("motion_visual",true)
	add_child(panel)
	var column: VBoxContainer=panel.column
	column.add_child(UI.label({"options":"Options", "about":"About Ambatopia", "terms":"Terms & Conditions", "download":"Download Ambatopia"}.get(kind,kind),26))
	match kind:
		"about":
			column.name = "AboutText"
			var flag := TextureRect.new()
			flag.texture = load("res://assets/ambatopia/indonesia.svg")
			flag.custom_minimum_size = Vector2(36,24)
			flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			flag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			column.add_child(flag)
			for paragraph in ["Created by Thangguh · Indonesia","Ambatopia is a fan-made creative sandbox and outfit planner built through local resource analysis and behavioral reconstruction with REA.","Explore worlds, plan outfits and experiment together. Metadata, wearable rendering and gameplay support are verified separately; advanced behaviors remain in development.","This independent project is not affiliated with or endorsed by Growtopia or its owners. Original artwork and sounds belong to their respective owners.","Version 0.13 · Godot 4.7.2 · Supabase shared worlds"]:
				column.add_child(UI.label(paragraph,18))
			column.add_child(UI.button("TikTok · @tangguhlw",func(): OS.shell_open("https://www.tiktok.com/@tangguhlw")))
		"terms":
			column.add_child(UI.label("Ambatopia is an independent fan-made project for fun, research and creative experimentation. It is not an official Growtopia service.\n\nRespect other players and the rights of asset owners. Do not impersonate staff, harass others or upload private information. A fan-made disclaimer does not grant permission to redistribute third-party assets.\n\nAccounts and supported shared-world actions use the dedicated Supabase project. Use a unique password. Registration is limited to two accounts per IP; shared networks use the same quota. Local creative saves stay on your device.",18))
		"download":
			column.add_child(UI.label("Download the latest local build from this PC. Supported online gameplay connects directly to Supabase without a USB tunnel. Public download hosting is not configured.",18))
			column.add_child(UI.button("Download APK · Android",func(): OS.shell_open("http://127.0.0.1:4193/download/android"),24))
			column.add_child(UI.button("Download · Windows",func(): OS.shell_open("http://127.0.0.1:4193/download/windows"),24))
		"options":
			column.add_child(UI.label("Graphics",24))
			var quality := OptionButton.new()
			quality.fit_to_longest_item = false
			quality.clip_text = true
			quality.add_item("Normal · full clouds and particles")
			quality.add_item("Low · reduced clouds, no particles")
			quality.selected = 1 if app.settings.graphics == "low" else 0
			quality.custom_minimum_size.y = 48
			quality.item_selected.connect(func(index): app.settings.graphics = "low" if index == 1 else "normal"; app.save_settings())
			column.add_child(quality)
			var frames := OptionButton.new()
			for rate in [30,60,120]:
				frames.add_item("%d FPS limit" % rate)
			frames.selected = [30,60,120].find(int(app.settings.fps))
			frames.custom_minimum_size.y = 48
			frames.item_selected.connect(func(index): app.settings.fps = [30,60,120][index]; Engine.max_fps = app.settings.fps; app.save_settings())
			column.add_child(frames)
			column.add_child(UI.button("Terms & Conditions",func(): kind = "terms"; rebuild(),22))
			column.add_child(UI.button("Project credits",func(): kind = "about"; rebuild(),22))
			for entry in [["Sound · master","master"],["Sound effects","effects"],["World menu music","music"]]:
				column.add_child(UI.label(entry[0]))
				var slider := HSlider.new()
				slider.max_value = 1
				slider.step = 0.05
				slider.value = app.settings.get(entry[1],0.7)
				slider.custom_minimum_size.y = 48
				var key: String = entry[1]
				slider.value_changed.connect(func(value): app.settings[key] = value; app.save_settings())
				column.add_child(slider)
			for entry in [["Enable chat","chat"],["Menu animations","animations"]]:
				var option := CheckButton.new()
				option.text = entry[0]
				option.custom_minimum_size.y = 48
				option.button_pressed = app.settings.get(entry[1],true)
				var key: String = entry[1]
				option.toggled.connect(func(value): app.settings[key] = value; app.save_settings())
				column.add_child(option)
			if OS.get_name() != "Android":
				var fullscreen := CheckButton.new()
				fullscreen.text = "Fullscreen"
				fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				fullscreen.toggled.connect(func(value): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
				column.add_child(fullscreen)
			column.add_child(UI.label("Graphics: pixel filtering · compatibility renderer\nA/D or arrows: move · Space: jump · F: punch · E: backpack\nDouble-tap supported clothes to wear or remove.",20))
	column.add_child(UI.button("Back",func(): close_action.call() if close_action.is_valid() else app.navigate("menu")))

func rebuild() -> void:
	visual=null
	progress=0
	target=1
	transition_state="closed"
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_ready()
