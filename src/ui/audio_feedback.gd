extends Node

var app
var voice: AudioStreamPlayer
var click_count := 0
var music: AudioStreamPlayer
var music_path := ""

const MAIN_THEME := "res://assets/ambatopia/main-theme.mp3"
const WORLD_THEME := "res://assets/ambatopia/world-menu.mp3"

static func track_for_page(page: String) -> String:
	if page in ["worlds","multiplayer"]:return WORLD_THEME
	if page in ["menu","login","options","about","download","terms"]:return MAIN_THEME
	return ""

func _exit_tree() -> void:
	for player in [voice,music]:
		if is_instance_valid(player):
			player.stop()
			player.stream=null

func set_page(page: String) -> void:
	if music == null:
		music = AudioStreamPlayer.new()
		add_child(music)
	var requested := track_for_page(page)
	if requested.is_empty():
		music.stop()
		return
	if requested != music_path:
		music.stop()
		music.stream=load(requested)
		music.stream.loop=true
		music_path=requested
	if not music.playing:
		music.play()

func _process(_delta: float) -> void:
	if music != null:
		music.volume_db = linear_to_db(maxf(0.0001,app.settings.master * app.settings.get("music",0.7)))

func _ready() -> void:
	voice = AudioStreamPlayer.new()
	voice.stream = load("res://assets/reference/click_sound.wav")
	voice.max_polyphony = 8
	add_child(voice)
	get_tree().node_added.connect(hook)

func hook(node: Node) -> void:
	if node is BaseButton and not node.has_meta("click_audio"):
		node.set_meta("click_audio",true)
		node.pressed.connect(play_click)

func play_click() -> void:
	click_count += 1
	voice.volume_db = linear_to_db(maxf(0.0001,app.settings.master*app.settings.effects))
	voice.play()
