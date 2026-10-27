extends RefCounted

func run(t) -> void:
	if not ResourceLoader.exists("res://src/game/input_router.gd"):
		t.check(false, "Semantic input router exists")
		return
	var input = load("res://src/game/input_router.gd").new()
	input.press("left")
	t.check(input.sample().axis == -1.0, "Left action")
	input.press("right")
	t.check(input.sample().axis == 0.0, "Opposite directions cancel")
	input.cancel_all()
	t.check(input.sample().axis == 0.0, "Focus loss clears held movement")
	input.press("punch")
	t.check(input.sample().action == "punch", "Punch semantic action")
	input.set_text_focus(true)
	t.check(input.sample().action == "none", "Typing suppresses punch")
	input.press("right")
	t.check(input.sample().axis == 0.0, "Typing suppresses movement")
	input.set_text_focus(false)
	t.check(input.sample().axis == 0.0, "Closing input does not resume held key")
	input.press("jump")
	t.check(input.sample().jump_pressed, "Jump press edge")
	t.check(not input.sample().jump_pressed, "Jump edge consumed once")
	input.cancel_all()
