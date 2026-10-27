extends RefCounted

const SPEED := 150.0
const GRAVITY := 1100.0
const JUMP := -390.0
const HALF_WIDTH := 10.0
const HEIGHT := 30.0

func catchup_steps(delta: float) -> int:
	return mini(int(delta * 60), 5)

func collides(world, feet: Vector2) -> bool:
	for y in range(floori((feet.y - HEIGHT) / 32), floori((feet.y - 0.01) / 32) + 1):
		for x in range(floori((feet.x - HALF_WIDTH) / 32), floori((feet.x + HALF_WIDTH - 0.01) / 32) + 1):
			if world.solid(Vector2i(x, y)):
				return true
	return false

func step(world, player, input: Dictionary, dt: float) -> Array[Dictionary]:
	player.jump_held=bool(input.get("jump_held",false))
	dt = clampf(dt, 0, 1.0 / 30.0)
	var death_events: Array[Dictionary]=[]
	if player.death_time>=0:
		death_events=advance_death(world,player,dt)
		if player.death_time>=0 and player.death_time<2.0:return death_events
	var axis := clampf(float(input.get("axis", 0)), -1, 1)
	player.world_rules=world.world_effects.get("xenonite",{})
	var tile=Vector2i(floori(player.position.x/32),floori((player.position.y-8)/32))
	player.in_water=world.extras.get(str(tile.y*world.size.x+tile.x),{}).get("water",false)
	player.tick_modifiers(dt)
	var services: Dictionary=preload("res://src/game/source_machine_rules.gd").flags(world)
	var body_id: int=preload("res://src/game/terrain_renderer.gd").source(world.tile_at(tile))
	var antigravity: bool=services.antigravity or body_id==6748
	var low_gravity:=0.375 if antigravity else 0.75 if world.weather=="mars" else 1.0
	if antigravity:player.modifiers["Antigravity"]={"remaining":0.2,"kind":"world_machine","tint":"","item":4992}
	elif player.modifiers.get("Antigravity",{}).get("kind")=="world_machine":player.modifiers.erase("Antigravity")
	var abilities: Dictionary=player.abilities()
	var foot:=Vector2i(floori(player.position.x/32),floori((player.position.y+0.1)/32))
	var floor_id: int=preload("res://src/game/terrain_renderer.gd").source(world.tile_at(foot))
	var moving_rules: Dictionary=preload("res://src/game/wardrobe_effects.gd").movement
	var slippery: bool=(floor_id in moving_rules.slippery or abilities.slippery_clothes) and not abilities.anti_slip and player.grounded
	var horizontal: float=axis*SPEED*player.speed_multiplier()
	player.velocity.x=(move_toward(player.velocity.x,horizontal,180*dt) if slippery else horizontal)+player.knockback.x
	player.knockback=player.knockback.move_toward(Vector2.ZERO,600*dt)
	if axis != 0:
		player.facing = 1 if axis > 0 else -1
	if player.grounded:
		player.air_jumps = 0
	if input.get("jump_pressed", false) and not player.modifiers.has("Frozen"):
		if player.grounded:
			var weak: bool=floor_id==5108 or floor_id==5396 and not abilities.snowshoes
			player.velocity.y = JUMP * float(player.abilities().jump)*(0.6 if weak else 1.0)
			player.grounded = false
		elif player.can_double_jump() and player.air_jumps < 1:
			player.velocity.y = JUMP * float(player.abilities().jump)
			if not antigravity:player.air_jumps += 1
	player.velocity.y = minf(player.velocity.y + GRAVITY * low_gravity * dt, 600)
	if player.in_water and abilities.floaties:
		player.velocity.y=-320 if input.get("jump_held",false) else minf(player.velocity.y,40)
	var travel: Vector2 = player.velocity * dt
	var count := maxi(1, ceili(travel.length() / 4.0))
	player.grounded = false
	for i in count:
		var next: Vector2 = player.position + Vector2(travel.x / count, 0)
		if not collides(world, next):
			player.position.x = next.x
		else:
			player.velocity.x = 0
			if abilities.climb and axis!=0 and not input.get("jump_pressed",false):
				player.velocity.y=0;player.grounded=true;travel.y=0
		next = player.position + Vector2(0, travel.y / count)
		if not collides(world, next):
			player.position.y = next.y
		else:
			if travel.y > 0:
				player.grounded = true
			player.velocity.y = 0
	player.punch_time = maxf(0, player.punch_time - dt)
	death_events.append_array(lava_step(world,player,dt))
	return death_events

func advance_death(world,player,dt: float) -> Array[Dictionary]:
	var before: float=player.death_time
	player.death_time+=dt
	var events: Array[Dictionary]=[]
	for sound in player.death_profile.get("snd",[]):
		if float(sound[0])>before and float(sound[0])<=player.death_time:events.append({"type":"death_sound","sound":str(sound[1])})
	if before<2.0 and player.death_time>=2.0:
		player.position=world.spawn_position();player.velocity=Vector2.ZERO;player.air_jumps=0
		player.respawn_invulnerability=0.8
		events.append({"type":"player_respawned"})
	if player.death_time>=float(player.death_profile.B.d):player.death_time=-1
	return events

func lava_step(world,player,dt: float) -> Array[Dictionary]:
	if player.god_mode or player.abilities().fireproof or player.death_time>=0 or player.respawn_invulnerability>0:
		player.burn_time=0;player.lava_exposure=0;player.lava_cooldown=0
		return []
	var touching:=false
	for y in range(floori((player.position.y-HEIGHT)/32),floori((player.position.y-0.01)/32)+1):
		for x in range(floori((player.position.x-HALF_WIDTH)/32),floori((player.position.x+HALF_WIDTH-0.01)/32)+1):
			if world.tile_at(Vector2i(x,y)) in [7,200004,100004]:touching=true
	if not touching or not player.begin_death():return []
	var events: Array[Dictionary]=[{"type":"death_started"}]
	for sound in player.death_profile.get("snd",[]):
		if float(sound[0])==0:events.append({"type":"death_sound","sound":str(sound[1])})
	return events
