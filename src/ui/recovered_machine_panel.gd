extends RefCounted
const UI=preload("res://src/ui/theme.gd")
const Icons=preload("res://src/game/inventory_icons.gd")
func note(body,text: String) -> void:
	var label:=UI.label(text,17);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;body.add_child(label)
func picker(body,pool: Array) -> OptionButton:
	var control:=OptionButton.new()
	control.fit_to_longest_item=false;control.custom_minimum_size.y=48
	control.clip_text=true
	for row in pool:
		control.add_item("%s × %d"%[row.get("name",str(row.id)),int(row.get("amount",1))])
		var image:=Icons.texture(int(row.id))
		if image!=null:control.set_item_icon(control.item_count-1,image)
	body.add_child(control)
	return control
func populate(body,view,tile: Vector2i,id: int) -> bool:
	var r=view.item_runtime
	var recovered=r.recovered
	if recovered.spent(id):
		note(body,"This item is spent. All of its rewards have been collected.")
		body.add_child(UI.button("Close",func():view.close_modal()))
		return true
	if not recovered.handles(id):return false
	if recovered.data.providers.has(str(id)):
		var row: Dictionary=recovered.data.providers[str(id)]
		note(body,"Drops 1–2 "+str(r.Sim.items()[str(int(row.output))][0])+" · every 22 hours.")
		body.add_child(UI.button("Harvest",func():view.perform_item(tile,"harvest"),20))
		body.add_child(UI.button("Creative grow",func():view.perform_item(tile,"grow"),20))
	elif recovered.data.calendars.has(str(id)):
		note(body,"Historical calendar · 25 gifts maximum. Gifts accumulate at 00:00 Growtopia time (UTC−5).")
		note(body,"Creative reward replay: choose from this day's published rewards. Original server RNG odds are unavailable.")
		var day_label:=UI.label("",20);body.add_child(day_label)
		var choice:=picker(body,[])
		choice.name="CalendarRewardPicker"
		var claim:=UI.button("Collect selected gift",func():view.perform_item(tile,"harvest",{"choice":choice.selected}),20)
		claim.name="CalendarClaim"
		body.add_child(claim)
		var refresh:=func():
			var day: int=int(r.state(view.world,tile).get("claimed",0))+1
			if r.source(view.world.tile_at(tile))!=id:day=26
			day_label.text="Day %d / 25 · %d available"%[mini(day,25),maxi(0,recovered.calendar_available(id)-day+1)] if day<=25 else "All 25 gifts collected"
			if int(choice.get_meta("day",-1))==day:return
			choice.set_meta("day",day);choice.clear()
			for row in recovered.calendar_pool(id,day):choice.add_item("%s × %d"%[row.name,int(row.amount)])
			claim.disabled=choice.item_count==0
		refresh.call()
		claim.pressed.connect(refresh)
		var timer:=Timer.new();timer.wait_time=0.25;timer.autostart=true;timer.timeout.connect(refresh);body.add_child(timer)
		body.add_child(UI.button("Unlock all days · creative replay",func():view.perform_item(tile,"grow"),18))
	elif id==10656:
		note(body,"Five Golden Booty Chests per contribution · full at 200. This creative replay supplies chests from the free inventory.")
		note(body,"Choose the contribution reward from the published chest pool; original best-of-five RNG is not simulated.")
		var choice:=picker(body,recovered.data.well.pool)
		var contribution:=UI.button("Contribute 5 creative chests",func():view.perform_item(tile,"contribute",{"choice":choice.selected}),20)
		contribution.name="WellContribution";body.add_child(contribution)
		note(body,"Full well: 96.75% Pure Love Essence, 3.25% epic. Choose which epic to preview if that branch wins; individual epic odds are unavailable.")
		var pool: Array=[]
		for item in recovered.data.well.epic:pool.append({"id":int(item),"name":str(r.Sim.items()[str(int(item))][0])})
		var epic:=picker(body,pool)
		body.add_child(UI.button("Harvest full well",func():view.perform_item(tile,"harvest",{"choice":epic.selected}),20))
	body.add_child(UI.button("Close",func():view.close_modal()))
	return true
