extends RefCounted
const UI=preload("res://src/ui/theme.gd")

func populate(body: VBoxContainer,game,tile: Vector2i,id: int) -> bool:
	var r=game.item_runtime
	var rules=r.automation
	if not rules.handles(id):return false
	rules.initialize(r,game.world,tile,id)
	var d: Dictionary=r.state(game.world,tile)
	if id in rules.CRYSTALS:
		var choices:=HFlowContainer.new()
		body.add_child(choices)
		for item in rules.CRYSTALS:
			choices.add_child(UI.button("+ "+str(r.Sim.items()[str(item)][0]),func():game.perform_item(tile,"add_crystal",{"item":item}),16))
		body.add_child(UI.button("Shatter aligned cluster",func():game.perform_item(tile,"shatter"),18))
	elif id==2072:
		for power in rules.POWERS:
			var row:=HBoxContainer.new()
			row.add_theme_constant_override("separation",8)
			var name:=UI.label(rules.POWERS[power],16)
			name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			name.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			row.add_child(name)
			var mode:=OptionButton.new()
			mode.custom_minimum_size=Vector2(105,44)
			mode.add_item("Normal")
			if power!="pwr":mode.add_item("Force")
			mode.add_item("Block")
			var settings: Dictionary=game.world.world_effects.get("xenonite",{})
			mode.select(mode.item_count-1 if settings.get("block",{}).get(power,false) else 1 if settings.get("force",{}).get(power,false) and power!="pwr" else 0)
			mode.item_selected.connect(func(index):game.perform_item(tile,"xenonite",{"power":power,"mode":mode.get_item_text(index).to_lower()}))
			row.add_child(mode)
			body.add_child(row)
	else:
		var search:=LineEdit.new()
		search.placeholder_text="Find target item"
		search.custom_minimum_size.y=44
		body.add_child(search)
		var picker:=OptionButton.new()
		picker.fit_to_longest_item=false
		picker.clip_text=true
		picker.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		picker.custom_minimum_size.y=44
		body.add_child(picker)
		var choices: Array=[]
		search.text_changed.connect(func(text):
			choices.assign(r.Sim.query(text).filter(func(item):return r.is_seed(int(item.id)) if id==6946 else true).slice(0,30))
			picker.clear()
			for item in choices:picker.add_item(item.name))
		search.text="Dirt Seed" if id==6946 else "Dirt"
		search.text_changed.emit(search.text)
		body.add_child(UI.button("Choose target",func():
			if picker.selected>=0 and picker.selected<choices.size():game.perform_item(tile,"select_target",{"item":int(choices[picker.selected].id)}),18))
		var amount:=SpinBox.new()
		amount.min_value=1
		amount.max_value=8000 if id in rules.AUTO else int(rules.STORAGE[id])
		amount.value=1
		amount.custom_minimum_size.y=44
		body.add_child(amount)
		if rules.STORAGE.has(id):
			body.add_child(UI.button("Add free stock",func():game.perform_item(tile,"deposit",{"amount":int(amount.value)}),18))
			var collection:=CheckButton.new()
			collection.text="Collect matching floating items"
			collection.button_pressed=d.get("enabled",true)
			collection.custom_minimum_size.y=44
			collection.toggled.connect(func(enabled):game.perform_item(tile,"configure",{"enabled":enabled}))
			body.add_child(collection)
		else:
			body.add_child(UI.button("Add free fuel (gems)",func():game.perform_item(tile,"refuel",{"amount":int(amount.value)}),18))
			body.add_child(UI.button("Start / stop automation",func():game.perform_item(tile,"activate"),18))
			body.add_child(UI.button("Remove fuel",func():game.perform_item(tile,"remove_fuel"),18))
			if id==6954:
				for field in ["trees","seeds"]:
					var option:=CheckButton.new()
					option.text="Harvest trees" if field=="trees" else "Collect seeds (off: collect blocks)"
					option.button_pressed=d.get(field,true)
					option.toggled.connect(func(enabled):game.perform_item(tile,"configure",{field:enabled}))
					body.add_child(option)
		body.add_child(UI.button("Retrieve stored items",func():game.perform_item(tile,"withdraw",{"amount":int(amount.value)}),18))
		if id==5638:
			body.add_child(UI.button("Toggle building + get remote",func():game.perform_item(tile,"activate"),18))
			body.add_child(UI.button("Get remote",func():game.perform_item(tile,"get_remote"),18))
	body.add_child(UI.button("Close",func():
		game.modal.queue_free()
		game.modal=null
		game.item_status=null
		game.input.set_text_focus(false),22))
	return true
