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

## Relevé de la partie en cours, affiché à l'écran de fin.
var stats := {}

## Point de contrôle : posé à chaque fusible installé. Permet de reprendre
## sans tout refaire — dans un jeu de 15 minutes, repartir de zéro à chaque
## mort décourage plus qu'il n'effraie.
const FICHIER_PROGRESSION := "user://progression.cfg"
var reprise_fusibles := 0
var reprise_temps := 0.0

## Recharger la scène détruit tous les noeuds, menu compris. Une continuation
## écrite après reload_current_scene() ne s'exécute donc jamais. L'intention
## « enchaîner directement sur la partie » transite par cet autoload, qui lui
## survit, et c'est Main qui la consomme une fois le monde reconstruit.
var demarrer_en_jeu := false

## Étape du test de menu (voir Main._run_menu_test). Comme le test traverse un
## rechargement de scène, son avancement doit lui aussi vivre dans l'autoload.
var test_menu := 0

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


func set_phase(p: Phase, force := false) -> void:
	if phase == p and not force:
		return
	phase = p
	get_tree().paused = (p == Phase.PAUSE)
	var captured := (p == Phase.JEU)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	phase_changed.emit(p)


func reset_run() -> void:
	fuses_held = 0
	fuses_installed = reprise_fusibles
	# reprendre avec tous les fusibles posés veut dire que le courant était
	# déjà revenu : sans ça le tableau deviendrait inutilisable.
	power_restored = reprise_fusibles >= FUSES_REQUIRED
	time_survived = reprise_temps
	stats = {"detections": 0, "chasses": 0, "cachettes": 0, "haletements": 0,
			"distance": 0.0, "portes": 0, "piles": 0}


## Incrémente un compteur du relevé de partie.
func stat(cle: String, n := 1.0) -> void:
	if phase == Phase.JEU:
		stats[cle] = stats.get(cle, 0.0) + n


# --------------------------------------------------------------------------
#  Point de contrôle
# --------------------------------------------------------------------------
func poser_point_de_controle() -> void:
	var c := ConfigFile.new()
	c.set_value("reprise", "fusibles", fuses_installed)
	c.set_value("reprise", "temps", time_survived)
	c.set_value("reprise", "difficulte", Settings.difficulte)
	c.save(FICHIER_PROGRESSION)


func a_un_point_de_controle() -> bool:
	var c := ConfigFile.new()
	if c.load(FICHIER_PROGRESSION) != OK:
		return false
	return int(c.get_value("reprise", "fusibles", 0)) > 0


func reprendre() -> void:
	var c := ConfigFile.new()
	if c.load(FICHIER_PROGRESSION) != OK:
		return
	reprise_fusibles = int(c.get_value("reprise", "fusibles", 0))
	reprise_temps = float(c.get_value("reprise", "temps", 0.0))
	Settings.difficulte = clampi(int(c.get_value("reprise", "difficulte",
			Settings.difficulte)), 0, 2)


func effacer_point_de_controle() -> void:
	reprise_fusibles = 0
	reprise_temps = 0.0
	DirAccess.remove_absolute(FICHIER_PROGRESSION)


# --------------------------------------------------------------------------
#  Meilleur temps
# --------------------------------------------------------------------------
func meilleur_temps() -> float:
	var c := ConfigFile.new()
	if c.load(FICHIER_PROGRESSION) != OK:
		return 0.0
	return float(c.get_value("records", "meilleur_%d" % Settings.difficulte, 0.0))


func enregistrer_temps(t: float) -> bool:
	var c := ConfigFile.new()
	c.load(FICHIER_PROGRESSION)
	var cle := "meilleur_%d" % Settings.difficulte
	var ancien := float(c.get_value("records", cle, 0.0))
	var record := ancien <= 0.0 or t < ancien
	if record:
		c.set_value("records", cle, t)
	# la partie est finie : le point de reprise n'a plus lieu d'être
	c.set_value("reprise", "fusibles", 0)
	c.set_value("reprise", "temps", 0.0)
	c.save(FICHIER_PROGRESSION)
	reprise_fusibles = 0
	reprise_temps = 0.0
	return record


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
