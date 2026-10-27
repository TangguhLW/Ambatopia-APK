extends RefCounted
func run(t) -> void:
	var P=load("res://src/game/player_state.gd")
	var W=load("res://src/game/web_wardrobe.gd")
	var A=load("res://src/game/ancestral_particles.gd")
	for id in [1740,4988,5264]:
		var p=P.new();p.equip_catalog(id)
		t.check(p.speed_multiplier()>1,"Source-confirmed clothing grants actual movement speed: "+str(id))
		p.catalog_equipment.clear()
		t.check(p.speed_multiplier()==1,"Unequip removes worn speed without stale timed modifiers")
	var path="res://src/game/wearable_pose.gd"
	t.check(ResourceLoader.exists(path),"Wearable body lift is a separate source pose, not collision movement")
	if ResourceLoader.exists(path):
		var Pose=load(path);var p=P.new();p.grounded=true;p.equip_catalog(6064)
		t.check(is_equal_approx(Pose.lift(p,0),-5) and is_equal_approx(Pose.lift(p,0.25),-3) and is_equal_approx(Pose.lift(p,0.75),-7),"Spirit Guide follows the original one-second hover equation")
		p.catalog_equipment.clear();p.equip_catalog(1740)
		t.check(is_equal_approx(Pose.lift(p,0),-9) and is_equal_approx(Pose.lift(p,0.25),-7),"StarBoard uses its recovered ride lift instead of the Spirit Guide offset")
		p.catalog_equipment.clear()
		t.check(Pose.lift(p,0)==0,"Unequip restores the original visual feet anchor")
	var p=P.new();p.equip_catalog(5264);p.velocity=Vector2(180,0);p.grounded=true
	var fx=A.new()
	for i in 12:fx.update(p,1.0/60)
	t.check(not fx.particles.is_empty(),"Neon Nerves executes its type-39 particle emitter while moving")
	if not fx.particles.is_empty():
		var particle: Dictionary=fx.particles[0]
		t.check(particle.item==5264 and particle.region==Rect2(416,416,32,32),"Neon trail uses the original particles atlas cell 13,13")
		fx.elapsed=0;var first=fx.geometry(particle).color
		fx.elapsed=2.5
		t.check(first!=fx.geometry(particle).color,"Rainbow-enabled typed particles follow the source colour cycle")
	p.velocity=Vector2.ZERO
	for i in 45:fx.update(p,1.0/60)
	t.check(fx.particles.is_empty(),"Stopping movement expires the Neon trail instead of leaving permanent particles")
	var legacy=load("res://src/game/source_legacy_particles.gd").new()
	p.catalog_equipment.clear();p.equip_catalog(4988);p.velocity=Vector2(180,0)
	for i in 18:legacy.update(p,1.0/60)
	t.check(legacy.particles.any(func(row):return int(row.item)==4988),"Speed Medallion retains its own lightning particle program")
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/clothing-mods-032.json"))
	for id in registry.speedy:
		var record: Dictionary=load("res://src/game/item_catalog.gd").summary(200000+int(id))
		t.check(not record.is_empty() and record.equip,"Confirmed Speedy mod is mapped to a wearable item: "+str(id))
		p.catalog_equipment={str(record.get("slot","feet")):int(id)}
		t.check(p.speed_multiplier()>1,"Each confirmed Speedy item has a functional buff: "+str(id))
	p.catalog_equipment={"shirt":5264};p.velocity=Vector2(180,0);fx=A.new();fx.update(p,1.0/60)
	t.check(not fx.particles.is_empty() and fx.geometry(fx.particles[0]).behind,"Neon trail respects source byte 529 so it does not cover the body")
	p.in_water=true
	t.check(p.speed_multiplier()==1,"Land-only Speedy does not become a swimming buff")
	p.in_water=false;p.world_rules={"block":{"spd":true}}
	t.check(p.speed_multiplier()==1,"Xenonite still suppresses worn Speedy")
