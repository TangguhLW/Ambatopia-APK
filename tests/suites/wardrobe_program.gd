extends RefCounted
func run(t):
	var R=load("res://src/game/special_wardrobe.gd")
	var W=load("res://src/game/web_wardrobe.gd")
	var p=load("res://src/game/player_state.gd").new();p.grounded=true
	var renderer=R.new();p.catalog_equipment={"back":14338}
	for i in 60:renderer.update(p,1.0/60,0,0,0,0)
	var ctx: Dictionary=renderer.contexts[14338].vars
	t.check(ctx.get("BalloonPos") is Array and absf(float(ctx.get("BalloonPos",[0])[0]))>0.5,"Balloon Backpack advances its own variable curve")
	p.catalog_equipment={"hand":14238};renderer=R.new()
	for i in 190:renderer.update(p,1.0/60,0,0,0,0)
	t.check(renderer.compiled.get("RenderHandItem",[]).size()>0,"Lace Parasol sequence produces visible draw commands after delay")
	if not renderer.has_method("expanded_rules"):
		t.check(false,"Nested renderer groups and conditions are interpreted")
		return
	p.catalog_equipment={"shirt":14084};renderer=R.new();renderer.update(p,1.0/60,0,0,0,0)
	t.check(renderer.contexts[14084].vars.has("frontArmRotation"),"Growch Biceps retains its declared vector variables")
	var rules=renderer.expanded_rules([{ "grp":[{"tr":[2,3]},{"scl":[2,2]},{"spr":0}]}],{},p)
	t.check(rules.size()==1 and rules[0].get("_scale")==Vector2(2,2) and rules[0].get("_offset")==Vector2(2,3),"Nested transformations compose without leaking to siblings")
	var stopped=renderer.expanded_rules([{"stop":[0,[["a",0,2]]]},{"spr":0}],{},p)
	t.check(stopped.is_empty(),"Satisfied stop rule ends the current group")
	var particles=load("res://src/game/wardrobe_particles.gd").new()
	p.catalog_equipment={"hand":14238};p.grounded=false;p.velocity.y=80;renderer=R.new()
	for i in 30:
		renderer.update(p,1.0/60,0,0,0,0);particles.update(p,renderer,1.0/60)
	t.check(particles.particles.any(func(v):return v.name=="fall_heartSparkle" and v.sheet=="particles11" and v.life==0.5),"Lace Parasol falling emits its recovered heart sprites and lifetime")
	t.check(particles.particles.size()<=7,"Source emitter respects its own particle capacity")
	p.grounded=true;p.velocity=Vector2.ZERO;p.catalog_equipment={"back":14338};renderer=R.new()
	renderer.update(p,1.0/60,0,0,0,0)
	t.check(renderer.contexts[14338].vars.get("BaloonOffset1",[0])[0]== -9,"Balloon tether endpoints use the source vector assignment operation")
	t.check(renderer.compiled.get("RenderBehind",[]).filter(func(c):return c.has("line")).size()==3,"Balloon Backpack draws all three authored tethers")
	p.grounded=false;p.velocity.y=80;p.catalog_equipment={"hand":14238};renderer=R.new()
	renderer.update(p,1.0/60,0,0,0,0)
	t.check(renderer.get("pose_overrides") is Dictionary and renderer.get("pose_overrides").get("armF",0)== -140,"Lace Parasol applies its authored falling arm pose")
	var Program=load("res://src/game/wardrobe_program.gd")
	t.check(Program.condition(["v","flag",2,["l",true]],{"flag":true},p),"Boolean variable conditions follow source equality semantics")
	t.check(Program.condition(["v","point",2,["l",[1.0,2.0]]],{"point":[1.0,2.0]},p),"Vector conditions compare actual components")
