extends Node
const Audio=preload("res://src/game/machine_audio.gd")
const Rules=preload("res://src/game/source_machine_rules.gd")
var voices: Dictionary={}
var elapsed:=0.0
var contact_clock:=0.0
var contacts: Dictionary={}
var contact_world:=0
signal contact_sound(path: String)
func update(w,p,delta: float,gain: float) -> void:
	elapsed+=delta
	contact_clock+=delta
	if elapsed<0.1:return
	elapsed=0
	Audio.load_data()
	if contact_world!=w.get_instance_id():contacts.clear();contact_world=w.get_instance_id()
	var tile:=Vector2i(((p.position-Vector2(0,16))/32).floor())
	var index: int=tile.y*w.size.x+tile.x
	var present: Dictionary={}
	if w.contains(tile):
		for layer in ["foreground","background"]:
			var id:=Rules.source(int(w[layer][index]))
			var rule: Dictionary=Audio.data.sfx.get(str(id),{})
			if rule.get("kind","")!=("sfx_fg" if layer=="foreground" else "sfx_bg"):continue
			var path: String="audio/"+str(rule.get("sound",""))
			if not Audio.data.entries.has(path):continue
			var key: String=str(index)+":"+layer+":"+str(id)
			present[key]=true
			var prior: Dictionary=contacts.get(key,{"inside":false,"left":-1000.0})
			if not prior.inside and contact_clock-float(prior.left)>=float(rule.get("audio_volume_ms",200))/1000.0:contact_sound.emit(path)
			contacts[key]={"inside":true,"left":prior.left}
	for key in contacts.keys():
		if not present.has(key) and contacts[key].inside:contacts[key]={"inside":false,"left":contact_clock}
		if not contacts[key].inside and contact_clock-float(contacts[key].left)>11:contacts.erase(key)
	var wanted: Dictionary={}
	for entry in Rules.flags(w).active:
		if entry.silent:continue
		var path=Audio.data.music.get(str(entry.item))
		if not path is String or not Audio.data.entries.has(path):continue
		var point:=Vector2(entry.index%w.size.x,floori(float(entry.index)/w.size.x))*32+Vector2(16,16)
		var distance: float=point.distance_to(p.position)
		if distance>640 or wanted.size()>=4:continue
		wanted[entry.index]=true
		if voices.has(entry.index) and voices[entry.index].get_meta("source_path","")!=path:voices[entry.index].queue_free();voices.erase(entry.index)
		if not voices.has(entry.index):
			var sound: AudioStream=Audio.stream(path)
			if sound==null:continue
			var voice:=AudioStreamPlayer.new()
			voice.stream=sound
			voice.set_meta("source_path",path)
			add_child(voice);voices[entry.index]=voice
		var voice: AudioStreamPlayer=voices[entry.index]
		voice.volume_db=linear_to_db(maxf(0.0001,gain*(1-distance/640.0)*0.6))
		if not voice.playing:voice.play()
	for key in voices.keys():
		if not wanted.has(key):voices[key].queue_free();voices.erase(key)
