extends RefCounted
const UI=preload("res://src/ui/theme.gd")
const Sim=preload("res://src/game/simulator_catalog.gd")
func number(body,label: String,value: float,minimum: float,maximum: float) -> SpinBox:
	body.add_child(UI.label(label,18))
	var input:=SpinBox.new();input.min_value=minimum;input.max_value=maximum;input.value=value;input.custom_minimum_size.y=44;body.add_child(input)
	return input
func populate(body,view,tile: Vector2i,id: int) -> void:
	var d: Dictionary=view.item_runtime.state(view.world,tile)
	if id==6280:
		body.add_child(UI.label("Guild mascot rain · set its foreground/background at the Guild Lock. Visual motion is reconstructed from the recorded reference; global guild membership is not simulated.",16))
		var gravity:=number(body,"Gravity",float(d.get("gravity",50)),-500,500)
		gravity.name="GuildGravity"
		var spin:=CheckButton.new();spin.text="Spin Items";spin.button_pressed=d.get("spin",false);spin.name="GuildSpin";body.add_child(spin)
		var invert:=CheckButton.new();invert.text="Invert Sky Colors";invert.button_pressed=d.get("invert",false);invert.name="GuildInvert";body.add_child(invert)
		var apply:=UI.button("Apply guild weather settings",func():view.perform_item(tile,"configure",{"gravity":int(gravity.value),"spin":spin.button_pressed,"invert":invert.button_pressed}),18)
		apply.name="ApplyGuildWeather";body.add_child(apply)
	if id==3694:
		var red:=number(body,"Red",float(d.get("r",255)),0,255)
		var green:=number(body,"Green",float(d.get("g",128)),0,255)
		var blue:=number(body,"Blue",float(d.get("b",0)),0,255)
		body.add_child(UI.button("Apply heatwave color",func():view.perform_item(tile,"configure",{"r":int(red.value),"g":int(green.value),"b":int(blue.value)}),18))
	if id in [3832,5000]:
		var search:=LineEdit.new();search.placeholder_text="Find falling item" if id==3832 else "Find background block";search.custom_minimum_size.y=44;body.add_child(search)
		var picker:=OptionButton.new();picker.custom_minimum_size.y=44;picker.fit_to_longest_item=false;picker.clip_text=true;body.add_child(picker)
		var selected: int=int(d.get("item",2) if id==3832 else d.get("bg",14))
		picker.add_item(str(Sim.items()[str(selected)][0]),selected)
		search.text_changed.connect(func(text):
			picker.clear()
			for row in Sim.query(text):
				if id==5000 and int(Sim.items()[str(row.id)][7]) not in [18,22,23,28]:continue
				picker.add_item(row.name,row.id)
				if picker.item_count>=60:break)
		if id==5000:
			body.add_child(UI.button("Apply background block",func():
				if picker.selected>=0:view.perform_item(tile,"configure",{"bg":picker.get_selected_id()}),18))
		else:
			var gravity:=number(body,"Falling speed / gravity",float(d.get("gravity",50)),-500,500)
			var spin:=CheckButton.new();spin.text="Spin";spin.button_pressed=d.get("spin",false);body.add_child(spin)
			var invert:=CheckButton.new();invert.text="Invert";invert.button_pressed=d.get("invert",false);body.add_child(invert)
			body.add_child(UI.button("Apply falling items",func():
				if picker.selected>=0:view.perform_item(tile,"configure",{"item":picker.get_selected_id(),"gravity":int(gravity.value),"spin":spin.button_pressed,"invert":invert.button_pressed}),18))
