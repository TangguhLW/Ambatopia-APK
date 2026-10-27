extends RefCounted

const Sim=preload("res://src/game/simulator_catalog.gd")
const PAIRS={1:["glass_hit","punch_glass"],2:["rock_hit","rock_destroy"],3:["metal_hit","metal_destroy"]}
const FILES=["wood_damage","wood_break","punch_glass","metal_hit","punch_miss","punch_locked","glass_hit","rock_hit","rock_destroy","metal_destroy","punch_organic"]

static func material(item: int) -> int:
	var source: int=item-200000 if item>=200000 else item-100000 if item>=100000 else {1:2,2:8,3:10,4:6,5:242,6:108,7:4}.get(item,0)
	var row: Array=Sim.items().get(str(source),[])
	return int(row[11]) if row.size()>11 else 0

static func pair(item: int) -> Array:
	var source: int=item-200000 if item>=200000 else item-100000 if item>=100000 else {1:2,2:8,3:10,4:6,5:242,6:108,7:4}.get(item,0)
	if source in [2,16]:return ["wood_damage","wood_break"]
	return PAIRS.get(material(item),["wood_damage","wood_break"])

static func impact(item: int, protected: bool=false) -> String:
	return "punch_locked" if protected else "punch_miss" if item==0 else str(pair(item)[0])
