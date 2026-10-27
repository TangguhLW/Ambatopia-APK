extends SceneTree
var app
var checks=[]
var failures=[]
func _initialize():call_deferred("run")
func check(value: bool,label: String):
 checks.append(label)
 if not value:failures.append(label)
func save(path: String,value):
 var f=FileAccess.open(path,FileAccess.WRITE)
 f.store_string(JSON.stringify(value,"\t"));f.close()
func run():
 var config=JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
 app=load("res://scenes/app.tscn").instantiate()
 app.set_meta("visual_freeze",true)
 root.add_child(app)
 app.settings.master=0
 app.accounts.access_token=config.token;app.accounts.profile=config.profile
 app.profile={"id":config.profile.id,"display_name":config.profile.amba_id}
 app.shared_selection=true
 app.enter_world(config.world)
 var deadline=Time.get_ticks_msec()+30000
 var ready=false
 while Time.get_ticks_msec()<deadline:
  if app.route=="play" and app.network.peers.size()>=config.expected+1:
   ready=true
   for topic in app.network.topics.values():
    if not topic.ready:ready=false
   if ready:break
  await create_timer(.05).timeout
 check(ready,"All private crowd topics ready in real Godot transport")
 save(config.ready_path,{"ready":ready})
 if ready:
  var game=app.screen
  check(game.remote_players.size()==int(config.expected),"World view instantiates eight distinct remote avatar states")
  var moving={};var punching={};deadline=Time.get_ticks_msec()+60000
  while Time.get_ticks_msec()<deadline:
   for uid in app.network.peers:
    if uid==app.accounts.profile.id:continue
    var peer=app.network.peers[uid]
    if peer.get("vx",0)!=0:moving[uid]=true
    if peer.get("punch",0)>0:punching[uid]=true
   if game.local_messages.any(func(text):return "Crowd bridge verification" in text) and game.world.tile_at(Vector2i(48,23))==1:break
   await create_timer(.03).timeout
  check(moving.size()==int(config.expected),"Every remote player supplies a valid moving state")
  check(punching.size()==int(config.expected),"Every remote player's punch reaches Godot")
  check(game.local_messages.any(func(text):return "Crowd bridge verification" in text),"Crowd chat reaches actual Godot world")
  check(game.world.tile_at(Vector2i(48,23))==1,"Crowd block mutation reaches actual Godot world")
  check(game.remote_players.size()==int(config.expected),"All peer avatars remain distinct after movement and edits")
 save(config.report_path,{"checks":checks,"failures":failures,"platform":"Windows Godot headless, real Supabase","remote_players":app.screen.remote_players.size() if app.route=="play" else 0})
 await app.accounts.database_call("game_leave",{"p_player_id":app.network.id})
 app.network.close();app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
