extends RefCounted
var enabled := false
var totals: Dictionary={}
func start() -> int:
	return Time.get_ticks_usec() if enabled else 0
func end(name: String,started: int) -> void:
	if not enabled:return
	var value: Dictionary=totals.get(name,{"us":0,"count":0,"max_us":0})
	var duration:=Time.get_ticks_usec()-started
	value.us+=duration
	value.count+=1
	value.max_us=maxi(value.max_us,duration)
	totals[name]=value
