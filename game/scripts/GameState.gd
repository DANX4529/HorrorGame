extends Node
## État global de la partie + configuration des entrées.
##
## Les actions d'entrée sont déclarées ici plutôt que dans project.godot :
## c'est plus lisible, et ça permet de gérer AZERTY et QWERTY d'un seul geste.

enum Phase { TITRE, JEU, PAUSE, MORT, VICTOIRE }

signal phase_changed(p: Phase)
signal fuses_changed(n: int, total: int)
signal message(txt: String, secs: float)

const FUSES_REQUIRED := 4

var phase: Phase = Phase.TITRE
var fuses_held := 0
var fuses_installed := 0
var power_restored := false
var time_survived := 0.0
var deaths := 0

const ACTIONS := {
	"move_forward": [KEY_W, KEY_Z, KEY_UP],
	"move_back":    [KEY_S, KEY_DOWN],
	"move_left":    [KEY_A, KEY_Q, KEY_LEFT],
	"move_right":   [KEY_D, KEY_RIGHT],
	"sprint":       [KEY_SHIFT],
	"hold_breath":  [KEY_CTRL],
	"crouch":       [KEY_C],
	"interact":     [KEY_E, KEY_SPACE],
	"flashlight":   [KEY_F],
	"pause":        [KEY_ESCAPE],
	"restart":      [KEY_R],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name in ACTIONS:
		if not InputMap.has_action(name):
			InputMap.add_action(name)
		for key in ACTIONS[name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(name, ev)


func _process(delta: float) -> void:
	if phase == Phase.JEU:
		time_survived += delta


func set_phase(p: Phase) -> void:
	if phase == p:
		return
	phase = p
	get_tree().paused = (p == Phase.PAUSE)
	var captured := (p == Phase.JEU)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	phase_changed.emit(p)


func reset_run() -> void:
	fuses_held = 0
	fuses_installed = 0
	power_restored = false
	time_survived = 0.0


func add_fuse() -> void:
	fuses_held += 1
	fuses_changed.emit(fuses_installed, FUSES_REQUIRED)
	say("Fusible céramique récupéré  (%d/%d)" % [fuses_held + fuses_installed, FUSES_REQUIRED], 3.0)


func install_fuses() -> int:
	var n := fuses_held
	fuses_installed += n
	fuses_held = 0
	fuses_changed.emit(fuses_installed, FUSES_REQUIRED)
	return n


func say(txt: String, secs := 3.0) -> void:
	message.emit(txt, secs)
