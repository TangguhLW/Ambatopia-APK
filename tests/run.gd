extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: ", message)

func run() -> void:
	var requested := OS.get_cmdline_user_args()
	var suite := requested[0] if not requested.is_empty() else "all"
	var suites := ["bootstrap", "asset_catalog", "menu_flow", "simulation", "input_router", "interactions", "local_store", "end_to_end", "fidelity", "wardrobe", "actions_revision", "multiplayer", "ambatopia_ui", "account_game", "next_rules", "item_gameplay", "special_rules", "automation_rules", "ui_revision", "reference_revision", "render_regression", "hybrid_revision", "special_wardrobe", "render_performance", "wardrobe_fidelity", "wardrobe_panel", "wardrobe_program"] if suite == "all" else [suite]
	if suite=="all":suites.append("click_cracks")
	if suite=="all":suites.append("avatar_material_audio")
	if suite=="all":suites.append("source_effects")
	if suite=="all":suites.append("terrain_heat_reset")
	if suite=="all":suites.append("death_punch_buffs")
	if suite=="all":suites.append("source_effects_023")
	if suite=="all":suites.append("rides_024")
	if suite=="all":suites.append("pets_025")
	if suite=="all":suites.append("inventory_icons_026")
	if suite=="all":suites.append("wardrobe_save_seed_027")
	if suite=="all":suites.append("machines_028")
	if suite=="all":suites.append("machines_029")
	if suite=="all":suites.append("outfit_slots_030")
	if suite=="all":suites.append("machine_animation_030")
	if suite=="all":suites.append("chest_rewards_030")
	if suite=="all":suites.append("guild_weather_031")
	if suite=="all":suites.append("wearable_revision_032")
	if suite=="all":suites.append("wearable_online_033")
	if suite=="all":suites.append("appearance_sync_034")
	for name in suites:
		var path := "res://tests/suites/%s.gd" % name
		if not ResourceLoader.exists(path):
			check(false, "Missing suite: " + name)
			continue
		var script = load(path)
		if script == null or not script.can_instantiate():
			check(false, "Suite must compile: " + name)
			continue
		await script.new().run(self)
	print("CHECKS: %d FAILED: %d" % [checks, failures])
	quit(1 if failures else 0)


