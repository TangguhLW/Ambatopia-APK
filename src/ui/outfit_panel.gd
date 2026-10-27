extends RefCounted
const UI=preload("res://src/ui/theme.gd")
func populate(body,view) -> void:
	body.add_child(UI.label("Saved outfits",28))
	body.add_child(UI.label("Three slots on this device, separate for each account. Your last worn set also saves automatically.",16))
	for index in range(1,4):
		var row:=HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		body.add_child(row)
		var status:=UI.label("",18)
		status.name="OutfitStatus"+str(index)
		status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(status)
		var load_button:=UI.button("Load",func():
			var result: Dictionary=view.app.session.load_outfit_slot(index)
			if result.ok:
				view.sync_outfit()
				view.play_sound("audio/change_clothes.wav","wear")
			view.hud.show_message("Outfit %d loaded"%index if result.ok else result.error,3),18)
		load_button.name="LoadOutfit"+str(index)
		var refresh:=func():
			var info: Dictionary=view.app.session.outfit_slot_info(index)
			status.text="Outfit %d · %s"%[index,("%d item"%info.items)+( "s" if info.items!=1 else "") if info.ok else "Empty slot"]
			load_button.disabled=not info.ok
		var save_button:=UI.button("Save",func():
			var result: Dictionary=view.app.session.save_outfit_slot(index)
			view.hud.show_message("Outfit %d saved"%index if result.ok else result.error,3)
			refresh.call(),18)
		save_button.name="SaveOutfit"+str(index)
		row.add_child(save_button)
		row.add_child(load_button)
		refresh.call()
	body.add_child(UI.button("Back to backpack",func():view.close_modal(func():view.toggle_inventory()),20))
