extends RefCounted
var jump_held:=false
var wrench_selected:=false

var position := Vector2.ZERO
var velocity := Vector2.ZERO
var facing := 1
var grounded := false
var equipment := {"hair": -1, "shirt": -1, "pants": -1}
var catalog_equipment: Dictionary = {}
var world_rules: Dictionary={}
var machine_remote: Dictionary={}
var actor_key="local"
var in_water=false
var knockback=Vector2.ZERO
var air_jumps := 0
const PUNCH_DURATION := 0.32
var punch_time := 0.0
var punch_direction := Vector2.RIGHT
var punch_distance:=36.0
var talk_time := 0.0
var item_options: Dictionary={}
var rayman_charge:=0.0
var rayman_level:=0
var rayman_fire:=0.0
var burn_time:=0.0
var lava_exposure:=0.0
var lava_cooldown:=0.0
var death_time:=-1.0
var death_epoch:=0
var death_origin:=Vector2.ZERO
var death_profile: Dictionary={}
var respawn_invulnerability:=0.0
func begin_death() -> bool:
	if death_time>=0:return false
	death_profile=preload("res://src/game/death_sequence.gd").profile(self)
	death_time=0;death_epoch+=1;death_origin=position
	velocity=Vector2.ZERO;knockback=Vector2.ZERO;punch_time=0
	burn_time=0;lava_exposure=0;rayman_charge=0;rayman_fire=0
	return true
func begin_punch(target: Vector2) -> void:
	var delta:=target-(position-Vector2(0,16))
	punch_distance=delta.length()
	if delta.length_squared()>0.01:
		punch_direction=delta.normalized()
		if absf(delta.x)>4:facing=1 if delta.x>0 else -1
	punch_time=PUNCH_DURATION
func begin_speech(text: String) -> void:
	talk_time=clampf(text.length()*0.055,0.35,2.5)
var display_name := "Player"
const SKINS := ["c39582","f4c7a0","d9ad86","9b704f","72503c","4b3429"]
var skin_index := 0
var country := "ID"
var god_mode := false
var modifiers: Dictionary = {}
var visual_lift:=0.0
var collected: Dictionary = {}
var ability_cache: Dictionary = {}
var outfit_hash := 0
func abilities() -> Dictionary:
	var current := catalog_equipment.hash()
	if ability_cache.is_empty() or current!=outfit_hash:
		ability_cache = preload("res://src/game/wardrobe_effects.gd").abilities(catalog_equipment)
		outfit_hash = current
	var result=ability_cache.duplicate()
	var force: Dictionary=world_rules.get("force",{})
	var block: Dictionary=world_rules.get("block",{})
	for key in ["dbl","hig","asb","pun","lng","spd","lngb","siw","sp2"]:
		if not force.get(key,false) and not block.get(key,false):continue
		var enabled=bool(force.get(key,false)) and not block.get(key,false)
		match key:
			"dbl":result.double_jump=enabled
			"hig":result.jump=1.15 if enabled else 1.0
			"asb":result.fireproof=enabled
			"pun":result.strong_punch=enabled
			"lng":result.range=128.0 if enabled else 96.0
			"spd":result.speed=1.25 if enabled else 1.0
			"lngb":result.build_range=128.0 if enabled else 96.0
			"siw":result.speed_in_water=enabled
			"sp2":result.dig=2.0 if enabled else 1.0
	return result
func tick_modifiers(dt: float) -> void:
	respawn_invulnerability=maxf(0,respawn_invulnerability-dt)
	burn_time=maxf(0,burn_time-dt)
	lava_cooldown=maxf(0,lava_cooldown-dt)
	rayman_fire=maxf(0,rayman_fire-dt)
	talk_time=maxf(0,talk_time-dt)
	for key in modifiers.keys():
		modifiers[key].remaining -= dt
		if modifiers[key].remaining<=0:
			modifiers.erase(key)
func speed_multiplier() -> float:
	if modifiers.has("Frozen"):
		return 0.0
	var speed := 1.0 if in_water else float(abilities().speed)
	if in_water and abilities().get("speed_in_water",false):speed=maxf(speed,1.25)
	for key in modifiers:
		if not in_water and "speedy" in str(key).to_lower() and not world_rules.get("block",{}).get("spd",false):
			speed=maxf(speed,1.25)
	return speed

func equip_catalog(id: int) -> bool:
	var item: Dictionary = preload("res://src/game/item_catalog.gd").summary(id)
	if item.is_empty() or not item.equip or item.slot == null:
		return false
	catalog_equipment[item.slot] = id
	if equipment.has(item.slot):
		equipment[item.slot] = -1
	return true

func unequip_catalog(slot: String) -> void:
	catalog_equipment.erase(slot)
	if equipment.has(slot):
		equipment[slot] = -1

func reset_appearance() -> void:
	catalog_equipment.clear()
	for slot in equipment:
		equipment[slot] = -1

func can_double_jump() -> bool:
	return abilities().double_jump

func punch_power() -> float:
	return float(abilities().dig)*(2.0 if rayman_level>=2 and preload("res://src/game/rayman_controller.gd").equipped(self) else 1.0)

var amba := false

var developer := false
