extends RefCounted
func run(t):
	var W=load("res://src/game/web_wardrobe.gd")
	var A=load("res://src/game/avatar_view.gd")
	var P=load("res://src/game/player_state.gd")
	var p=P.new();p.grounded=true
	p.equip_catalog(40)
	var special=load("res://src/game/special_wardrobe.gd").new()
	special.update(p,1.0/60,0,0,0,0)
	t.check(special.hidden_parts.has("footA") and special.hidden_parts.has("footB"),"Ordinary shoes apply source body masks, not just special costumes")
	if not W.has_method("phase_commands") or not A.has_method("punch_geometry"):
		t.check(false,"Source arm passes and fist geometry are implemented")
		return
	var tux=W.definition(38)
	t.check(W.phase_commands(tux,0,"stand",-1,"body").size()==1,"Tuxedo body pass excludes both arm sleeves")
	t.check(W.phase_commands(tux,0,"stand",-1,"back_arm")[0].kind=="rA","Rear sleeve renders with rear arm")
	t.check(W.phase_commands(tux,0,"stand",-1,"front_arm")[0].kind=="rB","Front sleeve renders after shirt at its own shoulder")
	p.begin_punch(Vector2(64,-16))
	t.check(is_equal_approx(p.punch_time,0.32),"Punch retains the recovered extension and recovery interval")
	var pose=A.punch_geometry(0.1,Vector2.RIGHT)
	t.check(pose.source==Rect2(180,0,20,48),"Bare fist samples source column nine, not a glove overlay")
	t.check(pose.shoulder.is_equal_approx(Vector2(8.4,-14)),"Fist originates at the reference right shoulder")
	var ray=Vector2.DOWN.rotated(pose.angle)
	t.check(ray.dot(Vector2.RIGHT)>0.99,"Punch sprite points toward the target")
	t.check(A.arm_geometry(true).destination==Rect2(-3,-1,6,10),"Idle arm uses the six by ten source extent and shoulder pivot")
	var avatar=A.new();avatar.player=p;p.punch_time=0.22
	avatar.advance_limbs(1.0/60)
	t.check(is_equal_approx(avatar.arm2,deg_to_rad(20)),"Punch front arm and its sleeve share the same recovered angle")
	if not avatar.has_method("face_frame"):
		t.check(false,"Source face expression resolver exists")
	else:
		t.check(avatar.face_frame()==4,"Bare punch selects the recovered angry face, not smile frame three")
	avatar.free()
	var transport=load("res://src/network/supabase_client.gd").new()
	transport.accounts=load("res://src/network/accounts.gd").new()
	transport.accounts.profile={"id":"self"}
	transport.peers={"peer":{"id":"peer"}}
	var packet={"seq":1,"x":64.0,"y":64.0,"vx":0.0,"vy":0.0,"facing":-1,"punch":0.32,"grounded":true,"punch_dx":-1.0,"punch_dy":0.0}
	transport.accept_motion("peer",packet)
	t.check(transport.peer_sequences.get("peer",-1)==1,"Realtime accepts the first frame of the longer recovered punch")
	packet.seq=2;packet.punch=0.33
	transport.accept_motion("peer",packet)
	t.check(transport.peer_sequences.get("peer",-1)==1,"Realtime still rejects punch durations beyond the recovered interval")
	transport.accounts.free();transport.free()
