extends Control
const Motion=preload("res://src/ui/motion.gd")
var transition_state := "closed"
var progress := 0.0
var target := 1.0
var reduced_motion := false
var closing_action: Callable
var visual: Control
var base_y := 0.0

func _ready():
	call_deferred("initial_open")

func initial_open():
	if transition_state=="closed" and target==1:
		open()

func open():
	closing_action=Callable()
	target=1
	transition_state="opening"
	visible=true
	mouse_filter=Control.MOUSE_FILTER_STOP
	if not is_instance_valid(visual):
		for child in get_children():
			if child is Control and child.get_meta("motion_visual",false):
				visual=child
				base_y=visual.position.y
	set_process(true)
	advance(1.0 if reduced_motion else 0.0)

func request_close(callback: Callable):
	closing_action=callback
	target=0
	transition_state="closing"
	set_process(true)
	advance(1.0 if reduced_motion else 0.0)

func _process(delta: float):
	advance(delta)

func advance(delta: float):
	progress=move_toward(progress,target,delta/Motion.PANEL_DURATION)
	var eased:=1-pow(1-progress,3)
	if is_instance_valid(visual):
		visual.position.y=base_y-(1-eased)*Motion.PANEL_OFFSET
		visual.modulate.a=progress
	if is_equal_approx(progress,target):
		set_process(false)
		transition_state="open" if target==1 else "closed"
		if target==0:
			visible=false
			mouse_filter=Control.MOUSE_FILTER_IGNORE
			var callback:=closing_action
			closing_action=Callable()
			if callback.is_valid():
				callback.call()
