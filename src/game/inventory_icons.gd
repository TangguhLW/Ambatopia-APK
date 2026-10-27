extends RefCounted

static var index: Dictionary={}
static var pages: Dictionary={}
static var icons: Dictionary={}
static var warned: Dictionary={}
const PAGE_LIMIT:=3
const ICON_LIMIT:=256

static func load_index() -> void:
	if index.is_empty():index=JSON.parse_string(FileAccess.get_file_as_string("res://data/inventory-icons.json"))

static func texture(id: int,native:=false) -> Texture2D:
	load_index()
	var key: String=("n" if native else "s")+str(id)
	if icons.has(key):return icons[key]
	var frame: Array=index.entries.get(key,[])
	if frame.is_empty():
		if index.get("unavailable",{}).has(key) and not warned.has(key):
			push_warning("Inventory icon unavailable in source: "+str(index.unavailable[key]));warned[key]=true
		return null
	var page:=int(frame[0])
	if not pages.has(page):
		var entry: Dictionary=index.pages[page]
		var file:=FileAccess.open("res://assets/inventory/icons.bin",FileAccess.READ)
		if file==null:push_error("Inventory icon pack missing");return null
		file.seek(int(entry.offset))
		var image:=Image.new()
		if image.load_png_from_buffer(file.get_buffer(int(entry.bytes)))!=OK or image.get_size()!=Vector2i(1024,1024):
			push_error("Inventory icon page invalid: "+str(page));return null
		if pages.size()>=PAGE_LIMIT:pages.erase(pages.keys()[0])
		pages[page]=ImageTexture.create_from_image(image)
	var result:=AtlasTexture.new()
	result.filter_clip=true;result.atlas=pages[page];result.region=Rect2(frame[1],frame[2],32,32)
	if icons.size()>=ICON_LIMIT:icons.erase(icons.keys()[0])
	icons[key]=result
	return result
