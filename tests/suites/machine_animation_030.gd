extends RefCounted
func run(t) -> void:
	var path="res://src/game/machine_animation.gd"
	t.check(ResourceLoader.exists(path),"Machine animation uses source frame selection")
	if not ResourceLoader.exists(path):return
	var A=load(path)
	var Sim=load("res://src/game/simulator_catalog.gd")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://research/machines-030/tile-selector-fixtures.json"))
	t.check(fixture.errors.is_empty(),"Every isolated original machine selector executes without errors")
	for sample in fixture.samples:
		var row: Array=Sim.items()[str(int(sample.id))]
		var base:=Vector2i(int(row[2]),int(row[3]))
		var result: Vector2i=A.cell(int(sample.id),row,base,int(sample.columns),bool(sample.enabled),int(sample.ms))
		t.check(result==Vector2i(int(sample.expected[0]),int(sample.expected[1])),"Original frame %s/%s/%s"%[sample.id,sample.enabled,sample.ms])
