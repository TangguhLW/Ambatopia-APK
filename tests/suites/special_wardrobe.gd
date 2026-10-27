extends RefCounted
func run(t):
	var path="res://src/game/special_wardrobe.gd"
	if not ResourceLoader.exists(path):
		t.check(false,"Special wardrobe uses native compiled render hooks")
		return
	var R=load(path)
	var W=load("res://src/game/web_wardrobe.gd")
	t.check(R.value(["if",["lt","vx",0],3,7],{"vx":-2})==3,"Recorded conditional chooses the matching motion branch")
	t.check(R.value(["pick",2,10,20,30],{})==30,"Recorded component selection uses the bounded index")
	t.check(R.value(["//",-7,2],{})==-3,"Recorded integer division truncates toward zero")
	var p=load("res://src/game/player_state.gd").new()
	p.grounded=true
	p.equip_catalog(1780)
	var renderer=R.new()
	renderer.update(p,1.0/60,0,0,0,0)
	var bot=renderer.commands(W.definition(1780),"RenderBehind",p)
	t.check(bot.size()==6,"Legendbot assembles all six recovered rear body pieces")
	t.check(renderer.hidden_parts.has("body") and renderer.hidden_parts.has("head"),"Mech replaces the base body instead of overlaying its thumbnail")
	t.check(renderer.hidden_slots.has(3),"Mech hides incompatible shoes")
	t.check(bot[4].source.position.x==3*41 and bot[4].destination.size==Vector2(41,47),"Mech torso samples its own atlas component")
	p.catalog_equipment={"face":15898}
	renderer.update(p,1.0/60,0,0,0,0)
	var helmet=renderer.commands(W.definition(15898),"RenderFaceItem",p)
	t.check(helmet.size()==1 and helmet[0].destination==Rect2(-13,-41,26,25),"Battlegrid face hook includes the recovered vertical offset and crop")
	p.catalog_equipment={"back":15416}
	renderer.update(p,1.0/60,0,0,0,0)
	var idle=renderer.commands(W.definition(15416),"RenderBackpack",p)
	t.check(idle.size()==4,"Constellation idle draws both wings and both glow layers")
	p.grounded=false;p.velocity.y=-180
	renderer.update(p,1.0/60,0,0,0,0)
	var jump=renderer.commands(W.definition(15416),"RenderBackpack",p)
	t.check(jump.size()==2 and jump[0].frame==3,"Jump changes wing frame and removes the idle glow")
	p.velocity.y=180
	renderer.update(p,1.0/60,0,0,0,0)
	var fall=renderer.commands(W.definition(15416),"RenderBackpack",p)
	t.check(fall.size()==2 and fall[0].frame==2,"Fall selects its dedicated wing pose")
	p.catalog_equipment.clear()
	renderer.update(p,1.0/60,0,0,0,0)
	t.check(renderer.hidden_parts.is_empty() and renderer.contexts.is_empty(),"Unequipping a costume clears its body masks and state")
	p.grounded=true;p.velocity=Vector2(180,0)
	renderer.update(p,1.0/60,0,0,0,0)
	t.check(renderer.enabled(["PlayerAction.Move"]),"Recorded movement actions use the same walking state as native physics")
