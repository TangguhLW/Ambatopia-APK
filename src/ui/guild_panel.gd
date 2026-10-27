extends RefCounted
const UI=preload("res://src/ui/theme.gd")
const Sim=preload("res://src/game/simulator_catalog.gd")
const Guild=preload("res://src/game/guild_weather.gd")
const Icons=preload("res://src/game/inventory_icons.gd")
func picker(body,label: String,selected: int,is_background: bool) -> OptionButton:
	body.add_child(UI.label(label,18))
	var search:=LineEdit.new();search.placeholder_text="Search background blocks" if is_background else "Search foreground blocks";search.custom_minimum_size.y=44;body.add_child(search)
	var input:=OptionButton.new();input.fit_to_longest_item=false;input.clip_text=true;input.custom_minimum_size.y=48
	input.name="GuildBackgroundPicker" if is_background else "GuildForegroundPicker"
	body.add_child(input)
	var fill:=func(text):
		input.clear()
		if is_background:input.add_item("None · foreground-only creative mascot",0)
		for row in Sim.query(text):
			if not (Guild.background(int(row.id)) if is_background else Guild.foreground(int(row.id))):continue
			input.add_item(row.name,int(row.id))
			var image:=Icons.texture(int(row.id))
			if image!=null:input.set_item_icon(input.item_count-1,image)
			if input.item_count>=60:break
	fill.call("")
	var at:=input.get_item_index(selected)
	if at<0 and Sim.items().has(str(selected)):
		input.add_item(str(Sim.items()[str(selected)][0]),selected);at=input.item_count-1
	if at>=0:input.select(at)
	search.text_changed.connect(fill)
	return input
func populate(body,view,tile: Vector2i) -> void:
	var settings: Dictionary=view.item_runtime.state(view.world,tile)
	body.add_child(UI.label("Creative guild mascot",24))
	body.add_child(UI.label("A mascot combines a foreground item over a background item. Guild weather inherits it from this Guild Lock. This local creative setup does not create a global guild membership or reserve a unique mascot.",16))
	var fg:=picker(body,"Foreground",int(settings.get("mascot_fg",2)),false)
	var bg:=picker(body,"Background",int(settings.get("mascot_bg",14)),true)
	var save:=UI.button("Save guild mascot",func():
		if fg.selected>=0 and bg.selected>=0:view.perform_item(tile,"configure",{"mascot_fg":fg.get_selected_id(),"mascot_bg":bg.get_selected_id()}),20)
	save.name="SaveGuildMascot";body.add_child(save)
	body.add_child(UI.button("Close",func():view.close_modal(),20))
