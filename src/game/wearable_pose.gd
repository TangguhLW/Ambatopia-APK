extends RefCounted
const W=preload("res://src/game/web_wardrobe.gd")
const Expr=preload("res://src/game/special_wardrobe.gd")

static func no_walk(player) -> bool:
	return player.catalog_equipment.values().any(func(id):return bool(W.definition(int(id)).get("nw",false)))

static func lift(player,time: float) -> float:
	if player.amba or player.death_time>=0:return 0
	var result:=0.0
	var hover:=false
	var suppress_hover:=false
	for id in player.catalog_equipment.values():
		var item:=W.definition(int(id));var ro: Dictionary=item.get("ro",{})
		hover=hover or bool(item.get("hb",false))
		suppress_hover=suppress_hover or bool(ro.get("hv",false))
		var offset: Array=ro.get("bo",[])
		if offset.size()>1:result+=float(offset[1])
	var feet:=W.definition(int(player.catalog_equipment.get("feet",0)))
	var ride: Dictionary=feet.get("ro",{}).get("ride",{})
	if ride.has("lift"):result+=Expr.value(ride.lift,{"T":time*1000})
	if hover and not suppress_hover:result+=-5+2*sin(TAU*time)
	return result
