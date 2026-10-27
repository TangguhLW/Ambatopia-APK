extends RefCounted
func run(t) -> void:
	var S=load("res://src/game/local_session.gd")
	var session=S.new();session.store.directory="user://outfits030-"+str(Time.get_ticks_usec())
	var profile={"id":"slots030","display_name":"SlotsQA"}
	session.enter(profile,"SLOTS")
	t.check(session.has_method("save_outfit_slot") and session.has_method("load_outfit_slot"),"Three explicit outfit save/load slots are implemented")
	if not session.has_method("save_outfit_slot"):return
	var p=session.player
	p.equip_catalog(34);p.skin_index=3;p.item_options={"pet_5480":false}
	t.check(session.save_outfit_slot(1).ok,"Save outfit 1")
	p.unequip_catalog("face");p.equip_catalog(362);p.skin_index=1;p.item_options={}
	t.check(session.save_outfit_slot(2).ok,"Save outfit 2")
	p.unequip_catalog("back");session.save_outfit_slot(3)
	p.equip_catalog(34);session.save_set()
	t.check(session.load_outfit_slot(2).ok and p.catalog_equipment=={"back":362} and p.skin_index==1,"Load restores slot 2, not the last automatic checkpoint")
	t.check(session.load_outfit_slot(1).ok and p.catalog_equipment=={"face":34} and p.skin_index==3 and p.item_options=={"pet_5480":false},"Slot 1 restores skin and pet options without inheriting slot 2")
	t.check(session.load_outfit_slot(3).ok and p.catalog_equipment.is_empty(),"Empty outfit can be saved and loaded")
	for index in [-1,0,4,100]:
		t.check(not session.save_outfit_slot(index).ok and not session.load_outfit_slot(index).ok,"Out-of-range slots rejected")
	session.load_outfit_slot(1)
	var fresh=S.new();fresh.store.directory=session.store.directory;fresh.enter(profile,"OTHER")
	t.check(fresh.player.catalog_equipment=={"face":34},"Loading a named slot updates the last-used checkpoint for re-entry")
	fresh.enter({"id":"other030","display_name":"SlotsQA"},"OTHER")
	t.check(not fresh.load_outfit_slot(1).ok and fresh.player.catalog_equipment.is_empty(),"Named slots are isolated between accounts")
	var storage=session.outfits
	storage.store.save(storage.slot(profile)+"_2",{"schema_version":2,"equipment":{},"catalog_equipment":{"hat":34},"skin":0})
	var before=p.catalog_equipment.duplicate()
	t.check(not session.load_outfit_slot(2).ok and p.catalog_equipment==before,"Corrupt named slot does not change the outfit")
	t.check(not p.developer and not p.god_mode,"Outfit load does not grant role capabilities")
	t.check(preload("res://src/game/machine_audio.gd").stream("audio/change_clothes.wav")!=null,"Original change-clothes recording is packaged and decodes")
