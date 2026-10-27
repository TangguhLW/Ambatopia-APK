extends RefCounted

# Simulator set.readable.js: _0x47db38 and pet update at 46669–47080.
# Coordinates are world pixels, with the player's feet as origin.
const STEP:=1.0/60
const PORTED:=["d","f","k","h","y","j","p","e","o","u","l"]
var definition: Dictionary={}
var position:=Vector2.ZERO
var velocity:=Vector2.ZERO
var face:=1
var angle:=0.0
var bob:=0.0
var bob_velocity:=0.0
var history: Array=[]
var state:="i"
var age:=0.0
var clock:=0.0
var accumulator:=0.0
var timer:=0.0
var hop_target:=Vector2.ZERO
var amplitude:=0.0
var active_id:=0
var last_player:=Vector2.ZERO
var idle:=0.0
var mode:=0
var floor_y:=0.0
var scale_in:=0.01
var midpoint_random:=false
var punch_age:=100.0
var previous_punch:=0.0

func random_range(low: float,high: float) -> float:
	return (low+high)/2 if midpoint_random else randf_range(low,high)

func reset(id: int,pet: Dictionary,player) -> void:
	definition=pet;active_id=id;face=player.facing
	var off: Array=pet.get("off",[0,0])
	position=player.position-Vector2((float(off[0])+16)*face,float(off[1])*face)
	velocity=Vector2.ZERO;angle=0;bob=0;bob_velocity=0;clock=0;age=0;accumulator=0;timer=0;state="i"
	history=[]
	for i in 20:history.append(sample(player,position))
	last_player=player.position;idle=0;mode=0;floor_y=position.y;scale_in=0.01;previous_punch=0;punch_age=100

static func sample(player,point: Vector2) -> Dictionary:
	return {"point":point,"velocity":player.velocity,"grounded":player.grounded,"face":player.facing}

func update(id: int,pet: Dictionary,player,dt: float) -> void:
	if pet.is_empty():
		active_id=0;definition={};history.clear();return
	if active_id!=id or player.position.distance_to(last_player)>350:reset(id,pet,player)
	last_player=player.position
	clock+=dt;age+=dt;accumulator+=dt
	punch_age=0 if player.punch_time>previous_punch+0.001 else punch_age+dt
	previous_punch=player.punch_time
	scale_in=minf(1,scale_in+dt)
	idle=idle+dt if player.grounded and player.velocity==Vector2.ZERO and player.punch_time<=0 else 0
	# Cap catch-up work after a suspended window, without allocating a trail per frame.
	for i in mini(12,int((accumulator+0.0000001)/STEP)):
		step(player,STEP);accumulator-=STEP
	accumulator=minf(accumulator,STEP)

func step(player,dt: float) -> void:
	var off: Array=definition.get("off",[0,0])
	var trail: Vector2=player.position-Vector2((float(off[0])+16)*player.facing,float(off[1])*player.facing)
	var tail: Vector2=history[-1].point
	if (off[0]!=0 or off[1]!=0) and trail.distance_to(tail)>20:trail=tail+(trail-tail)/2
	history.pop_front();history.append(sample(player,trail))
	var delayed: Dictionary=history[0]
	var next:="u" if not player.grounded and player.velocity.y<0 else "d" if not player.grounded else "w" if absf(player.velocity.x)>1 else "i"
	match str(definition.get("k","")):
		"d":
			if int(definition.t) in [2,13]:
				var dx: float=delayed.point.x-position.x
				angle=fposmod(angle+300*dx*dt,360)
				bob+=dt*bob_velocity;bob_velocity+=400*dt
				if bob>=0:
					bob=0
					if dx!=0:bob_velocity=-60
			position=Vector2(move_toward(position.x,delayed.point.x,350*dt),move_toward(position.y,delayed.point.y,350*dt))
			if position.distance_to(delayed.point)>60:position=delayed.point
			face=int(delayed.face)
			next="i" if delayed.grounded and absf(delayed.velocity.x)<=1 else "w" if delayed.grounded else "u" if delayed.velocity.y<0 else "d"
		"f":fly(player,dt)
		"y":
			if not player.grounded:timer=2
			if timer>0:
				timer-=dt;fly(player,dt)
			else:
				position=Vector2(move_toward(position.x,delayed.point.x,350*dt),move_toward(position.y,delayed.point.y,350*dt))
				if position.distance_to(delayed.point)>250:position=delayed.point
				face=int(delayed.face)
		"k":
			var kp: Array=definition.get("kp",[96,96,"p"])
			var target: Vector2=player.position-Vector2(float(kp[0])*player.facing,float(kp[1]))
			accelerate_box(target,200,32,dt)
			velocity.x=clampf(velocity.x+random_range(-90,90)*dt,-250,250)
			velocity.y=clampf(velocity.y+random_range(-90,90)*dt,-250,250)
			position+=velocity*dt
			if str(kp[2])=="v":
				if absf(velocity.x)>6:face=1 if velocity.x>0 else -1
				if player.punch_time>0:face=1 if player.position.x+player.punch_direction.x*player.punch_distance>position.x else -1
			elif absf(position.x-player.position.x)>32:face=1 if position.x<player.position.x else -1
			var distance:=position.distance_to(target)
			if distance>700:position=target
			elif distance>100:position+=position.direction_to(target)*20*dt
			settle(player,dt)
		"j":
			timer-=dt
			if timer>0:
				bob=sin(2*timer*PI)*amplitude*-0.2;bob_velocity=0
				position=Vector2(move_toward(position.x,hop_target.x,amplitude*dt),move_toward(position.y,hop_target.y,amplitude*dt));velocity=Vector2.ZERO
			else:
				bob=0;bob_velocity=0
				if absf(position.x-delayed.point.x)>1:face=1 if position.x<delayed.point.x else -1
				var distance:=position.distance_to(delayed.point)
				if distance>=5 and delayed.grounded:timer=0.5;hop_target=delayed.point;amplitude=2*distance
		"p":
			timer-=dt;position=player.position+Vector2(velocity.x,-15+velocity.y)
			if timer<=0:
				velocity=Vector2(random_range(-10,10),random_range(-15,9))
				angle=random_range(0,90)+(90 if velocity.x>0 else 0)
				if velocity.y>0:angle=360-angle
				face=-1 if randf()<0.5 else 1
				if face==-1:angle=-angle
				timer=random_range(0.1,1)
		"h":hover(player,dt)
		"e","o":perch(player,dt,trail)
		"u":umbrella(player,dt)
		"l":ball(player,dt)
	if int(definition.t)==30:angle=20*sin(clock*TAU/4)
	if player.punch_time>0 and definition.get("S",{}).has("p"):next="p"
	if next!=state:state=next;age=0

func perch(player,dt: float,trail: Vector2) -> void:
	var owl: bool=definition.k=="o"
	var pk: Array=definition.get("pk",[0,0,0])
	var target: Vector2=player.position+Vector2(3*player.facing,-67) if owl else player.position+Vector2(0,-25)
	if not owl:
		if pk[1] is Array:target=player.position+Vector2(float(pk[1][0])*player.facing,float(pk[1][1]))
		elif int(pk[0])==1:target=trail+Vector2(-6*player.facing,-8)
		if int(player.catalog_equipment.get("hat",0))==0:target.y+=2
		target.y+=float(pk[2])
	if idle<2:
		mode=0;fly(player,dt);return
	if not owl and idle>=10:
		position=target;mode=2;return
	if mode<1:
		if position.distance_to(target)<4:
			position=target;mode=3 if owl else 1;timer=0
			if owl or active_id==2484:face=player.facing
		else:
			velocity.x=clampf(velocity.x+signf(target.x-position.x)*300*dt,-50,50)
			velocity.y=clampf(velocity.y+signf(target.y-position.y)*300*dt,-50,50)
			position+=velocity*dt
			if absf(velocity.x)>5:face=1 if velocity.x>0 else -1
			position=Vector2(move_toward(position.x,target.x,5*dt),move_toward(position.y,target.y,5*dt))
	elif owl:
		timer+=dt
		if mode<5:
			position=target+Vector2(0,mode-3)
			if timer>1:mode+=1;timer-=1
		else:
			position=target+Vector2(0,2);face=player.facing
			if mode==6 and timer>2.2:mode=5;timer-=random_range(0.1,4)
			elif mode==5 and timer>=2:mode=6
	else:position=target

func umbrella(player,dt: float) -> void:
	var target: Vector2=player.position+Vector2(-16*player.facing,-48)
	if idle>=2:
		target=player.position+Vector2(0,-40)
		angle=move_toward(angle,10*face,180*dt)
		if position.distance_to(target)<4:position=target;angle=0;velocity=Vector2.ZERO;return
		velocity.x=clampf(velocity.x+signf(target.x-position.x)*300*dt,-50,50)
		velocity.y=clampf(velocity.y+signf(target.y-position.y)*300*dt,-50,50)
		position+=velocity*dt;angle=move_toward(angle,0,2*dt)
		if absf(velocity.x)>5:face=1 if velocity.x>0 else -1
		position=Vector2(move_toward(position.x,target.x,5*dt),move_toward(position.y,target.y,5*dt));return
	accelerate_box(target,800,32,dt)
	velocity=velocity.clamp(Vector2(-250,-250),Vector2(250,250));velocity.x+=random_range(-30,30)*dt
	position+=velocity*dt
	var lean:=0.0
	if absf(velocity.x)>=6:face=1 if velocity.x>0 else -1;lean=10*face
	angle=move_toward(angle,lean,180*dt)
	var distance:=position.distance_to(target)
	if distance>700:position=target
	elif distance>100:
		var away: Vector2=(position-target).normalized()
		position+=away*Vector2(20,5)*dt
	if player.velocity.length()<1:
		if absf(velocity.x)>40:velocity.x=move_toward(velocity.x,0,100*dt)
		if absf(velocity.y)>40:velocity.y=move_toward(velocity.y,0,100*dt)
		velocity+=Vector2(random_range(-60,60),random_range(-5,5))*dt

func ball(player,dt: float) -> void:
	if player.punch_time>0:
		timer=-10
		var phase:=clampf(4*punch_age,0,1)
		var target: Vector2=player.position+player.punch_direction*player.punch_distance
		position=player.position.lerp(target,phase)
		velocity=Vector2(-player.facing*random_range(40,300),random_range(-400,-20));floor_y=target.y;return
	if timer < -1:timer=1;return
	if timer<=0:
		angle=fposmod(angle+(player.position.x-position.x)*300*dt,360)
		bob+=dt*bob_velocity;bob_velocity+=400*dt
		if bob>=0:
			bob=0
			if position.x!=player.position.x:bob_velocity=-60
		position=Vector2(move_toward(position.x,player.position.x,700*dt),move_toward(position.y,player.position.y,700*dt));velocity=Vector2.ZERO
		if position.distance_to(player.position)>200:position=player.position
		if position.distance_to(player.position)<4 and player.velocity.length()>50:
			timer=1.5;velocity=Vector2(player.facing*random_range(160,240),0.25*player.velocity.y+100);floor_y=player.position.y+2
	else:
		position+=velocity*dt;timer=maxf(0,timer-dt);velocity.y+=400*dt;velocity.x=move_toward(velocity.x,0,100*dt)
		angle=fposmod(angle+dt*velocity.x*3,360);floor_y=maxf(floor_y,player.position.y)
		if position.y>floor_y and velocity.y>0:velocity.y=-velocity.y
		if timer<1.25 and absf(position.x-player.position.x)<=10 and position.y<player.position.y and position.y>player.position.y-30:timer=0

func accelerate_box(target: Vector2,acceleration: float,radius: float,dt: float) -> void:
	if position.x<target.x-radius:velocity.x+=acceleration*dt
	if position.x>target.x+radius:velocity.x-=acceleration*dt
	if position.y<target.y-radius:velocity.y+=acceleration*dt
	if position.y>target.y+radius:velocity.y-=acceleration*dt

func settle(player,dt: float) -> void:
	if player.velocity.length()>=1:return
	if absf(velocity.x)>40:velocity.x=move_toward(velocity.x,0,100*dt)
	if absf(velocity.y)>40:velocity.y=move_toward(velocity.y,0,100*dt)
	velocity+=Vector2(random_range(-60,60),random_range(-60,60))*dt

func fly(player,dt: float) -> void:
	var target: Vector2=player.position
	if position.x>target.x+32:velocity+=Vector2(-800,80)*dt
	if position.x<target.x-32:velocity+=Vector2(800,-80)*dt
	if position.y<target.y-32:velocity+=Vector2(80,800)*dt
	if position.y>target.y+32:velocity+=Vector2(-80,-800)*dt
	velocity.x=clampf(velocity.x+random_range(-30,30)*dt,-250,250)
	velocity.y=clampf(velocity.y+random_range(-30,30)*dt,-250,250)
	position+=velocity*dt
	if absf(velocity.x)>5:face=1 if velocity.x>0 else -1
	var distance:=position.distance_to(target)
	if distance>350:position=target
	elif distance>100:position+=(position-target).normalized()*20*dt
	settle(player,dt)

func hover(player,dt: float) -> void:
	var target: Vector2=player.position+Vector2(-16*player.facing,-8)
	for speed in ([180,90] if int(definition.t)==32 else [90]):
		var distance:=position.distance_to(target)
		if distance>800:position=target
		velocity=Vector2(move_toward(velocity.x,0,40*dt),move_toward(velocity.y,0,40*dt))
		var cap:=32.0
		if distance>16:
			cap=maxf(distance,90)
			var desired:=position.direction_to(target)*cap
			velocity=Vector2(move_toward(velocity.x,desired.x,dt*speed),move_toward(velocity.y,desired.y,dt*speed))
		else:velocity+=Vector2(random_range(-120,120),random_range(-120,120))*dt
		velocity=velocity.clamp(Vector2(-cap,-cap),Vector2(cap,cap))
		timer-=dt
		if timer<=0:face=1 if position.x<=player.position.x else -1;timer=0.5
		position+=velocity*dt

func anchor_delta(player,nominal:=Vector2(0,32)) -> Vector2:
	return Vector2(16+(position.x-player.position.x)*player.facing,position.y-player.position.y+32)-nominal
