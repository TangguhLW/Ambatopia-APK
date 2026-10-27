extends RefCounted

var held := {}
var jump_edge := false
var text_focus := false
var selected_action := "punch"
var target := Vector2i.ZERO

func press(action: String) -> void:
	if text_focus:
		return
	if action == "jump" and not held.get(action, false):
		jump_edge = true
	held[action] = true

func release(action: String) -> void:
	held.erase(action)

func cancel_all() -> void:
	held.clear()
	jump_edge = false

func set_text_focus(active: bool) -> void:
	text_focus = active
	cancel_all()

func sample() -> Dictionary:
	var result := {"axis": 0.0, "jump_pressed": false, "jump_held": false, "action": "none", "target": target, "pressed": false}
	if text_focus:
		return result
	result.axis = float(held.get("right", false)) - float(held.get("left", false))
	result.jump_pressed = jump_edge
	result.jump_held = held.get("jump", false)
	result.direct_punch = held.get("punch", false)
	jump_edge = false
	if held.get("punch", false):
		result.action = "punch"
	elif held.get("interact", false):
		result.action = selected_action
	result.pressed = result.action != "none"
	return result
