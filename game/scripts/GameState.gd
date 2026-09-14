extends Node
## État global de la partie + configuration des entrées.
##
## Les actions d'entrée sont déclarées ici plutôt que dans project.godot :
## c'est plus lisible, et ça permet de gérer AZERTY et QWERTY d'un seul geste.

enum Phase { TITRE, JEU, PAUSE, MORT, VICTOIRE, LECTURE }

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

## Le didacticiel de l'apnée a-t-il déjà été montré ? Chargé au démarrage
## depuis le fichier de progression : un joueur ne doit le voir qu'une fois
## dans sa vie, pas à chaque partie.
var souffle_appris := false

## Identifiants des documents déjà lus, toutes parties confondues. Le récit se
## collectionne à travers les descentes : mourir ne fait pas oublier ce qu'on a
## lu. Persisté, donc une mise à jour qui ajoute un chapitre laisse intact ce
## que le joueur avait déjà.
var documents_lus: Dictionary = {}

## Graine de la descente en cours. Elle détermine tout ce que le sanatorium a
## de variable : mobilier, fusibles, piles, lampes, documents.
##
## Elle doit rester STABLE pendant toute une partie. Un rechargement de scène
## reconstruit le monde de zéro ; si la graine changeait à ce moment-là,
## reprendre à un point de contrôle rebâtirait un autre sous-sol et les
## fusibles déjà posés se retrouveraient ailleurs. Elle est donc tirée à
## l'ouverture d'une descente, pas à la construction du niveau, et enregistrée
## avec le point de reprise.
var graine := 0

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
	var c := ConfigFile.new()
	if c.load(FICHIER_PROGRESSION) == OK:
		souffle_appris = bool(c.get_value("didacticiel", "souffle", false))
		for id in c.get_value("documents", "lus", []):
			documents_lus[id] = true
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
	# La lecture fige le monde. C'est délibéré : si lire coûtait la vie, les
	# joueurs sauteraient les documents, et tout le récit deviendrait décoratif.
	get_tree().paused = (p == Phase.PAUSE or p == Phase.LECTURE)
	# la souris reste capturée pendant la lecture : rien à cliquer, et on
	# revient au jeu sans reprise de contrôle visible
	var captured := (p == Phase.JEU or p == Phase.LECTURE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	phase_changed.emit(p)


## Ouvre une nouvelle descente : nouvelle graine, point de reprise effacé.
func nouvelle_descente() -> void:
	graine = randi_range(1, 0x7FFFFFFF)
	effacer_point_de_controle()


func reset_run() -> void:
	# filet de sécurité : lancement direct, outil de vérification, reprise d'une
	# sauvegarde antérieure à l'existence des graines
	if graine == 0:
		graine = randi_range(1, 0x7FFFFFFF)
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
	# charger d'abord : ConfigFile.save() n'écrit que ce qu'il a en mémoire, si
	# bien qu'enregistrer sans relire écrasait records et didacticiel.
	c.load(FICHIER_PROGRESSION)
	c.set_value("reprise", "fusibles", fuses_installed)
	c.set_value("reprise", "temps", time_survived)
	c.set_value("reprise", "difficulte", Settings.difficulte)
	c.set_value("reprise", "graine", graine)
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
	# on retrouve le sous-sol exactement tel qu'on l'a quitté
	graine = int(c.get_value("reprise", "graine", 0))
	Settings.difficulte = clampi(int(c.get_value("reprise", "difficulte",
			Settings.difficulte)), 0, 2)


## Efface le point de reprise — et RIEN D'AUTRE.
##
## Cette fonction supprimait le fichier de progression entier. Comme les
## meilleurs temps et le suivi du didacticiel y vivent aussi, chaque clic sur
## « Descendre » détruisait les records du joueur : la fonction « meilleur
## temps » ne pouvait donc jamais rien afficher d'une partie à l'autre.
func effacer_point_de_controle() -> void:
	reprise_fusibles = 0
	reprise_temps = 0.0
	var c := ConfigFile.new()
	if c.load(FICHIER_PROGRESSION) != OK:
		return          # rien d'enregistré : il n'y a rien à effacer
	c.set_value("reprise", "fusibles", 0)
	c.set_value("reprise", "temps", 0.0)
	c.save(FICHIER_PROGRESSION)


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


## Marque le didacticiel de l'apnée comme vu, définitivement.
func apprendre_souffle() -> void:
	if souffle_appris:
		return
	souffle_appris = true
	var c := ConfigFile.new()
	c.load(FICHIER_PROGRESSION)
	c.set_value("didacticiel", "souffle", true)
	c.save(FICHIER_PROGRESSION)


# --------------------------------------------------------------------------
#  Récit
# --------------------------------------------------------------------------
signal document_lu(id: String)
signal document_ouvert(id: String)

## Identifiant du document affiché, "" si aucun.
var document_ouvert_id := ""


## Ouvre un document : bascule en phase LECTURE et l'enregistre comme lu.
func ouvrir_document(id: String) -> void:
	if phase != Phase.JEU:
		return
	document_ouvert_id = id
	lire_document(id)
	document_ouvert.emit(id)
	set_phase(Phase.LECTURE)


func fermer_document() -> void:
	if phase != Phase.LECTURE:
		return
	document_ouvert_id = ""
	set_phase(Phase.JEU)


func a_lu(id: String) -> bool:
	return documents_lus.has(id)


## Marque un document comme lu et l'enregistre. Renvoie true si c'est une
## découverte, false si le joueur l'avait déjà trouvé lors d'une autre descente.
func lire_document(id: String) -> bool:
	if documents_lus.has(id):
		return false
	documents_lus[id] = true
	var c := ConfigFile.new()
	c.load(FICHIER_PROGRESSION)
	c.set_value("documents", "lus", documents_lus.keys())
	c.save(FICHIER_PROGRESSION)
	document_lu.emit(id)
	return true


func documents_trouves() -> int:
	return documents_lus.size()
