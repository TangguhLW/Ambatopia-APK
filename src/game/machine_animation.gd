extends RefCounted
const Sim=preload("res://src/game/simulator_catalog.gd")
const ACTIONS=[12,31,122,45,41,81,89,134]
static func handles(id: int) -> bool:
	var row: Array=Sim.items().get(str(id),[])
	return row.size()>18 and int(row[7]) in ACTIONS

static func sequence(frames: Array,period: int,flags: int,ms: int) -> Vector2i:
	var count:=frames.size()
	var length:=2*count-1 if flags&2 else count
	var index:=floori(float(ms)/period)%maxi(1,length) if period>0 else 0
	if index>=count:index=2*count-2-index
	var frame: Array=frames[maxi(0,index)]
	return Vector2i(int(frame[0]),int(frame[1]))

static func cell(id: int,row: Array,base: Vector2i,columns: int,enabled: bool,ms: int,weather: int=-1) -> Vector2i:
	var action:=int(row[7]);var kind:=int(row[13]);var period:=int(row[16]);var flags:=int(row[17])
	if row[14] is Array and not row[14].is_empty() and int(row[4])==1 and flags&1 and enabled:return sequence(row[14],period,flags,ms)
	if action==122 and not enabled and flags&32 and row[18] is Array and not row[18].is_empty():return sequence(row[18],period,flags,ms)
	var blink:=floori(float(ms)/period)&1 if period>0 else 0
	var frame:=0
	if action in [122,12]:frame=(1 if blink else 2) if enabled else 0
	elif action==31:frame=(columns if int(row[4]) in [3,7,10] else 1)+(blink if kind==4 else 0) if enabled else 0
	elif action==45 and id not in [3772,4712]:frame=1 if enabled else 0
	elif id==4712:frame=(0 if enabled else 2)+(floori(float(ms)/400)&1)
	elif action in [41,81,89,134]:
		var current_weather:=weather if weather>=0 else period if enabled else 4
		if (enabled if id in [5958,10058] else current_weather==period):frame=1+(floori(float(ms)/300)&1)
	if id in [3770,3768,7394]:frame=1 if enabled else 0
	if id==3564 and enabled:frame=32
	if kind==42 and enabled:frame+=1
	if id in [7866,9030,9200]:frame=0
	if id==9270:frame=0 if enabled else 1
	if id==14898 and enabled:frame=16
	if id==16244 and enabled:frame=64
	if id==4380 and enabled:
		var phase:=ms%800
		frame=2 if phase<75 else 3 if phase<175 else 2 if phase<250 else 1
	if kind in [4,10] and blink:frame+=columns if int(row[4]) in [3,4,7,8,9,10] else 2*columns if int(row[4])==5 else 1
	if kind==26:frame+=columns
	var linear:=base.x+base.y*columns+frame
	return Vector2i(linear%columns,floori(float(linear)/columns))
