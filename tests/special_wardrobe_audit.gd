extends SceneTree
func _initialize():call_deferred("run")
func run():
	var W=load("res://src/game/web_wardrobe.gd")
	var R=load("res://src/game/special_wardrobe.gd")
	var p=load("res://src/game/player_state.gd").new()
	var rows: Array=[]
	var failures: Array=[]
	var command_count:=0
	for id in W.index().renderers:
		if W.index().renderers[id] not in ["g","xr"]:continue
		var record: Dictionary=W.definition(int(id))
		p.catalog_equipment={R.SLOTS[int(record.slot)]:int(id)}
		var renderer=R.new()
		var counts: Array=[]
		for pose in ["idle","jump","fall","punch"]:
			p.grounded=pose in ["idle","punch"]
			p.velocity.y=-180 if pose=="jump" else 180 if pose=="fall" else 0
			p.punch_time=0.12 if pose=="punch" else 0
			renderer.update(p,1.0/60,0,0,0,0)
			var count:=0
			for hook in renderer.compiled:
				for command in renderer.compiled[hook]:
					var sheet: Dictionary=W.index().sheets[command.key]
					var source: Rect2=command.source
					if not Rect2(Vector2.ZERO,Vector2(sheet.width,sheet.height)).encloses(source) or not command.destination.position.is_finite() or not command.destination.size.is_finite():failures.append({"id":id,"pose":pose,"hook":hook})
					count+=1
			counts.append(count);command_count+=count
		var unsupported: Array=[]
		for hook in record.ro.st:
			for rule in record.ro.st[hook]:
				for key in ["ci","ln","tr","rot","scl","alp","stt","rtt","grp","stop"]:
					if rule.has(key) and key not in unsupported:unsupported.append(key)
		if record.ro.get("an",[]).any(func(a):return a.k in ["q","p","vi","vc"]):unsupported.append("advanced_animation")
		rows.append({"id":int(id),"name":record.name,"kind":record.ro.k,"commands_by_pose":counts,"partial_features":unsupported})
	var result={"items":rows.size(),"poses_each":4,"draw_commands":command_count,"failures":failures,"items_with_partial_features":rows.filter(func(r):return not r.partial_features.is_empty()).size(),"items_without_visible_command":rows.filter(func(r):return r.commands_by_pose.all(func(c):return c==0)).size(),"rows":rows}
	var file=FileAccess.open("res://evidence/special-017-catalog-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	print("SPECIAL_AUDIT: ",rows.size()," items; ",command_count," commands; ",failures.size()," bounds failures; ",result.items_with_partial_features," partially supported rule sets")
	quit(0 if failures.is_empty() else 1)
