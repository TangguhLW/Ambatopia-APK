extends SceneTree
func _initialize():call_deferred("run")
func run():
	var W=load("res://src/game/web_wardrobe.gd")
	var R=load("res://src/game/special_wardrobe.gd")
	var source=JSON.parse_string(FileAccess.get_file_as_string("res://evidence/special-017-catalog-audit.json"))
	var rows: Array=[];var failures: Array=[];var updates:=0
	for row in source.rows:
		if row.partial_features.is_empty():continue
		var record: Dictionary=W.definition(int(row.id));var renderer=R.new()
		var p=load("res://src/game/player_state.gd").new()
		p.catalog_equipment={R.SLOTS[int(record.slot)]:int(row.id)}
		var commands:=0;var poses: Dictionary={}
		for pose in ["idle","walk","jump","fall","punch"]:
			p.grounded=pose in ["idle","walk","punch"]
			p.velocity=Vector2(150 if pose=="walk" else 0,-180 if pose=="jump" else 180 if pose=="fall" else 0)
			var count:=0
			for tick in (190 if pose=="idle" else 30):
				p.punch_time=maxf(0,0.32-tick/60.0) if pose=="punch" else 0
				renderer.update(p,1.0/60,sin(tick*0.2),-sin(tick*0.2),0,0);updates+=1
				for hook in renderer.compiled:
					for command in renderer.compiled[hook]:
						if command.has("line"):
							if not command.line[0].is_finite() or not command.line[1].is_finite():failures.append({"id":row.id,"pose":pose,"kind":"line"})
						else:
							var sheet: Dictionary=W.index().sheets[command.key]
							if not Rect2(Vector2.ZERO,Vector2(sheet.width,sheet.height)).encloses(command.source) or not command.destination.position.is_finite() or not command.destination.size.is_finite():failures.append({"id":row.id,"pose":pose,"kind":"sprite"})
						count+=1
			poses[pose]=count;commands+=count
		rows.append({"id":row.id,"name":row.name,"draws":commands,"poses":poses})
	var report={"items":rows.size(),"updates":updates,"failures":failures,"scope":"Runtime/bounds timeline audit, not certification of pixel or behavioral parity","rows":rows}
	var file=FileAccess.open("res://evidence/wardrobe-019-265-timeline.json",FileAccess.WRITE);file.store_string(JSON.stringify(report));file.close()
	print("ADVANCED_TIMELINE ",rows.size()," items; ",updates," updates; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
