extends RefCounted
var random_stream: Array=[]
static var chest_rules: Dictionary={}
func roll(size: int) -> int:
	return clampi(int(float(random_stream.pop_front())*size),0,size-1) if not random_stream.is_empty() else randi_range(0,maxi(0,size-1))
func pick(pool: Array) -> int:return int(pool[roll(pool.size())]) if not pool.is_empty() else 0
func chest(id: int) -> Array:
	if chest_rules.is_empty():chest_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/chest-rewards-030.json"))
	if not chest_rules.rare_denominator.has(str(id)):return []
	var pool: Array=chest_rules.common.duplicate()
	if id==9350:pool.append_array(chest_rules.super_add)
	if roll(int(chest_rules.rare_denominator[str(id)]))<1:pool=chest_rules.rare
	if roll(int(chest_rules.override_denominator))<1:pool=chest_rules.override
	var output:=pick(pool)
	var count:=5 if chest_rules.amount5.any(func(value):return int(value)==output) else 2 if chest_rules.amount2.any(func(value):return int(value)==output) else 1
	return [output,count]
func provider(r,id: int) -> Array:
	if id==1008:return [[112,roll(250)+1]]
	var pool: Array=r.Sim.use_rules.provider_drop.get(str(id),[])
	if pool.is_empty():return []
	var selected: Array=pool[roll(pool.size())]
	return [[int(selected[0]),roll(int(selected[1]))+1 if int(selected[1])>1 else 1]]
func broken(r,w,tile: Vector2i,id: int) -> Array:
	if id in [392,3402,9350]:
		var reward:=chest(id)
		return grant(r,w,tile,int(reward[0]),int(reward[1]))
	var tables: Dictionary=r.rest.data.A_treasure
	var output:=0;var count:=1
	match id:
		120:output=112;count=roll(51)
		542:
			if roll(200)<1:output=2574
			else:output=112;count=roll(101)
		3604:
			output=pick(tables.hoard_rare if roll(500)<1 else tables.hoard)
			if output==112:count=roll(400)
		7628:output=pick(tables.hidden)
		2478:
			output=pick(tables.locke_clothes) if roll(2)!=0 else pick(tables.locke_block)-1 if roll(2)!=0 else pick(tables.locke_block)
			if roll(25)<1:output=pick(tables.locke_rare)
		_:return []
	if count<=0 or output<=0:return []
	return grant(r,w,tile,output,count)

func grant(r,w,tile: Vector2i,id: int,count: int) -> Array:
	var events: Array=[]
	while count>0 and w.drops.size()<256:
		var stack:=mini(count,200)
		events.append(r.reward(w,tile,id,stack));count-=stack
	return events
