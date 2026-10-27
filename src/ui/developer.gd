extends Control

const UI = preload("res://src/ui/theme.gd")
var app
var world_view
var close_action: Callable
var players: Array = []
var picker: OptionButton
var info: Label
var status: Label
var busy := false

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("123e50f5")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20
	scroll.offset_top = 12
	scroll.offset_right = -20
	scroll.offset_bottom = -12
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(UI.label("Developer · @Thaney",30))
	var toggles := HFlowContainer.new()
	body.add_child(toggles)
	for entry in [["God mode","god"],["Invisible","invisible"],["Transform Amba","amba"]]:
		var button := CheckButton.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 48
		button.button_pressed = world_view.get_meta(entry[1],false)
		button.toggled.connect(func(on):
			world_view.set_meta(entry[1],on)
			if entry[1] == "god":
				world_view.player.god_mode = on
			if entry[1] == "amba":
				world_view.player.amba = on
			app.network.send({"type":"developer","command":entry[1],"enabled":on}))
		toggles.add_child(button)
	picker = OptionButton.new()
	picker.custom_minimum_size.y = 48
	picker.item_selected.connect(show_player)
	body.add_child(picker)
	info = UI.label("Loading players...",20)
	body.add_child(info)
	var actions := HFlowContainer.new()
	body.add_child(actions)
	for entry in [["Ban · 24h","ban"],["Unban","unban"],["Mute · 24h","curse"],["Warning","warn"],["Promote to Mod","promote"],["Remove Mod","demote"]]:
		actions.add_child(UI.button(entry[0],func(): moderate(entry[1]),20))
	status = UI.label("",18)
	body.add_child(status)
	body.add_child(UI.button("Refresh",refresh,22))
	body.add_child(UI.button("Close",close_action,22))
	refresh()

func refresh() -> void:
	if busy:
		return
	busy = true
	var result: Dictionary = await app.accounts.request("/admin/players",{},HTTPClient.METHOD_GET)
	busy = false
	if not is_inside_tree():
		return
	if not result.ok:
		status.text = result.get("error","Could not load players.")
		return
	players = result.players
	picker.clear()
	for row in players:
		row.worlds = result.worlds.filter(func(w): return w.owner_id == row.id).map(func(w): return w.name)
		picker.add_item(row.amba_id + (" · online" if row.online else " · offline"))
	status.text = "%d players · %d audit records" % [players.size(),result.logs.size()]
	if not players.is_empty():
		show_player(0)

func show_player(index: int) -> void:
	if index < 0 or index >= players.size():
		return
	var row: Dictionary = players[index]
	info.text = "%s\nCreated: %s\nLast online: %s\nPlay time: %.2f hours / %.2f days\nConnection IP: %s\nOwned worlds: %s" % [row.amba_id,row.created_at,str(row.last_seen_at),float(row.played_seconds)/3600,float(row.played_seconds)/86400,str(row.ip),", ".join(row.worlds)]

func moderate(action: String) -> void:
	if busy or picker.selected < 0 or players.is_empty():
		return
	busy = true
	var result: Dictionary = await app.accounts.request("/admin/moderate",{"target":players[picker.selected].id,"action":action})
	busy = false
	status.text = "Applied. Online enforcement updates within 5 seconds." if result.ok else result.get("error","Action failed.")
