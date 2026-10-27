extends Node
var app
var folder := ""
var applied := ""
var elapsed := 0.0
var updates := 0

func _ready():
	folder=OS.get_executable_path().get_base_dir().path_join("../../build/live").simplify_path()
	if not FileAccess.file_exists(folder.path_join("../../project.godot").simplify_path()):
		set_process(false)
		return
	DisplayServer.window_set_title("Ambatopia — LIVE Windows")
	if OS.get_cmdline_args().has("--preview-world"):
		call_deferred("open_preview_world")

func open_preview_world():
	app.start_local("Preview")
	app.enter_world("LIVEPREVIEW")

func _process(delta: float):
	elapsed+=delta
	if elapsed<0.5:return
	elapsed=0
	var marker:=folder.path_join("update.json")
	if not FileAccess.file_exists(marker):return
	var update=JSON.parse_string(FileAccess.get_file_as_string(marker))
	if not update is Dictionary or str(update.get("sha256",""))==applied:return
	var filename:=str(update.get("pack",""))
	if not filename.begins_with("update-") or not filename.ends_with(".pck") or filename.get_file()!=filename:return
	var pack:=folder.path_join(filename)
	if not FileAccess.file_exists(pack) or FileAccess.get_sha256(pack)!=str(update.get("sha256","")):return
	if not update.get("scripts") is Array or update.scripts.size()>128:return
	for path in update.scripts:
		if not str(path).begins_with("res://src/") or ".." in str(path) or not str(path).ends_with(".gd") or str(path).ends_with("live_preview.gd"):return
	applied=update.sha256
	if not ProjectSettings.load_resource_pack(pack,true):return
	var previous: Dictionary={}
	for path in update.scripts:
		var script: GDScript=load(path)
		if script==null:return
		previous[path]=script.source_code
		script.source_code=FileAccess.get_file_as_string(path)
		if script.reload(true)!=OK:
			for restored in previous:
				var old: GDScript=load(restored)
				old.source_code=previous[restored]
				old.reload(true)
			DisplayServer.window_set_title("Ambatopia — LIVE · update rejected")
			return
	var route: String=app.route
	var view=app.screen
	var old_zoom: float=view.zoom if route=="play" else 1.0
	var old_item: int=view.selected_item if route=="play" else 0
	preload("res://src/game/item_catalog.gd").enrichment.clear()
	app.navigate(route)
	if route=="play":
		app.screen.zoom=old_zoom
		app.screen.select_action("place" if old_item>0 else "punch",old_item)
	updates+=1
	DisplayServer.window_set_title("Ambatopia — LIVE Windows · update "+str(updates))
	var report={"pid":OS.get_process_id(),"updates":updates,"sha256":applied,"route":route,"window_kept_open":true}
	var file:=FileAccess.open(folder.path_join("applied.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
