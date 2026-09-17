extends Node
## État global de la partie + configuration des entrées.
##
## Les actions d'entrée sont déclarées ici plutôt que dans project.godot :
## c'est plus lisible, et ça permet de gérer AZERTY et QWERTY d'un seul geste.

## L'ordre est porteur : Main._run_menu_test compare à un tableau de chaînes
## rangé dans le même ordre. Toute phase nouvelle s'ajoute À LA FIN.
enum Phase { TITRE, JEU, PAUSE, MORT, VICTOIRE, LECTURE, PROLOGUE, CABINE }

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

# --------------------------------------------------------------------------
#  Campagne
#
#  Une partie n'est plus une partie : c'est une DESCENTE, et la campagne est
#  la suite des étages traversés. Le niveau est un entier négatif, -1 étant le
#  plus haut ; c'est la clé de sauvegarde, il ne se renumérote jamais.
# --------------------------------------------------------------------------
## Étage en cours. 0 = aucun (on est au menu).
var etage_courant := 0
## Le plus profond étage atteint, toutes campagnes confondues.
var etage_atteint := 0
## Niveaux dont on est ressorti par le monte-charge.
var etages_termines: Dictionary = {}
var campagne_terminee := false
var fin_obtenue := ""
## Ce que la cabine vient de mettre à l'abri, pour que l'écran puisse le dire.
## Vit ici et non dans le menu : reconstruire l'écran (redimensionnement,
## bascule tactile) ne doit ni recompter ni remettre à zéro.
var butin_remonte := 0

## Point de contrôle : posé à chaque fusible installé. Permet de reprendre
## sans tout refaire — dans un jeu de 15 minutes, repartir de zéro à chaque
## mort décourage plus qu'il n'effraie.
const FICHIER_PROGRESSION := "user://progression.cfg"
## Version du format de sauvegarde. 1 = avant la campagne (pas de clé écrite).
const VERSION_SAUVEGARDE := 2
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

## Documents lus à l'étage en cours et PAS ENCORE REMONTÉS.
##
## C'est tout l'enjeu de la descente : lire un document ne suffit pas, il faut
## ressortir avec. Mourir vide cette table ; prendre le monte-charge la verse
## dans documents_lus, qui lui est persisté.
##
## Pour tout ce qui concerne le PLACEMENT, un document en main compte comme lu
## — sinon il réapparaîtrait à deux mètres de l'endroit où on vient de le
## ramasser. Pour tout ce qui concerne l'ARCHIVE, il ne compte pas encore.
var documents_en_main: Dictionary = {}

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

## Le prologue doit-il précéder la partie ? Vrai pour une descente neuve, faux
## pour une reprise : on ne réexplique pas la situation à quelqu'un qui reprend
## là où il est mort.
var montrer_prologue := false

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
		etage_courant = int(c.get_value("campagne", "etage_courant", 0))
		etage_atteint = int(c.get_value("campagne", "etage_atteint", 0))
		campagne_terminee = bool(c.get_value("campagne", "terminee", false))
		fin_obtenue = str(c.get_value("campagne", "fin", ""))
		for n in c.get_value("campagne", "etages_termines", []):
			etages_termines[int(n)] = true
		_migrer(c)
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
	get_tree().paused = (p == Phase.PAUSE or p == Phase.LECTURE
			or p == Phase.PROLOGUE or p == Phase.CABINE)
	# la souris reste capturée pendant la lecture : rien à cliquer, et on
	# revient au jeu sans reprise de contrôle visible
	var captured := (p == Phase.JEU or p == Phase.LECTURE or p == Phase.PROLOGUE)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	phase_changed.emit(p)


## Ouvre une nouvelle descente : nouvelle graine, point de reprise effacé.
func nouvelle_descente() -> void:
	graine = randi_range(1, 0x7FFFFFFF)
	montrer_prologue = true
	effacer_point_de_controle()


func reset_run() -> void:
	# filet de sécurité : lancement direct, outil de vérification, reprise d'une
	# sauvegarde antérieure à l'existence des graines
	if graine == 0:
		graine = randi_range(1, 0x7FFFFFFF)
	fuses_held = 0
	# Filet de sécurité : le butin ne survit JAMAIS à une reconstruction du
	# monde. Le monte-charge l'a déjà versé dans l'archive avant de descendre ;
	# dans tous les autres cas — mort, retour au titre, relance — il est perdu,
	# et c'est la règle.
	documents_en_main.clear()
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
	c.set_value("reprise", "etage", etage_courant)
	c.save(FICHIER_PROGRESSION)


## Le point de reprise au tableau ne subsiste qu'en Veilleur.
##
## Aux deux autres paliers l'ÉTAGE est l'unité de reprise : reprendre au
## tableau rendrait la mort presque gratuite, et « perdre ce qu'on n'a pas
## remonté » ne voudrait plus rien dire. Le palier le plus doux garde le filet,
## puisqu'il est là pour ça.
func a_un_point_de_controle() -> bool:
	if Settings.difficulte != Settings.Diff.VEILLEUR:
		return false
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
	# on retrouve l'étage exactement tel qu'on l'a quitté : son plan (la graine)
	# et son niveau, faute de quoi une reprise rebâtirait le bon plan au mauvais
	# étage — mêmes salles, autre mobilier, autres documents.
	graine = int(c.get_value("reprise", "graine", 0))
	etage_courant = int(c.get_value("reprise", "etage", etage_courant))
	montrer_prologue = false
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
#  Campagne
# --------------------------------------------------------------------------
## Reprend une sauvegarde antérieure à la campagne.
##
## Aucune clé n'est renommée et aucune n'est retirée : une sauvegarde v1 se lit
## telle quelle, et ce qui manque prend sa valeur par défaut. La migration ne
## fait qu'AJOUTER ce que la campagne a besoin de savoir — à savoir que le
## joueur a déjà vu l'étage -1, ce qu'un meilleur temps suffit à établir.
func _migrer(c: ConfigFile) -> void:
	if int(c.get_value("meta", "version", 1)) >= VERSION_SAUVEGARDE:
		return
	var premier := Etages.premier()
	# Un meilleur temps, à n'importe quelle difficulté, veut dire que l'étage a
	# été terminé au moins une fois : c'était la seule façon d'en enregistrer un.
	for d in 3:
		if float(c.get_value("records", "meilleur_%d" % d, 0.0)) > 0.0:
			etages_termines[premier] = true
			c.set_value("records", "etage_%d_%d" % [premier, d],
					c.get_value("records", "meilleur_%d" % d))
	if not documents_lus.is_empty() or not etages_termines.is_empty():
		etage_atteint = premier
	c.set_value("meta", "version", VERSION_SAUVEGARDE)
	c.set_value("campagne", "etage_atteint", etage_atteint)
	c.set_value("campagne", "etages_termines", etages_termines.keys())
	c.save(FICHIER_PROGRESSION)


## Ouvre une campagne neuve au premier étage.
func nouvelle_campagne() -> void:
	etage_courant = Etages.premier()
	documents_en_main.clear()
	campagne_terminee = false
	fin_obtenue = ""
	nouvelle_descente()


## Enregistre l'état de campagne. Comme partout ici : relire avant d'écrire,
## sinon ConfigFile.save() n'écrit que ce qu'il a en mémoire et efface le reste.
func _ecrire_campagne() -> void:
	var c := ConfigFile.new()
	c.load(FICHIER_PROGRESSION)
	c.set_value("meta", "version", VERSION_SAUVEGARDE)
	c.set_value("campagne", "etage_courant", etage_courant)
	c.set_value("campagne", "etage_atteint", etage_atteint)
	c.set_value("campagne", "etages_termines", etages_termines.keys())
	c.set_value("campagne", "terminee", campagne_terminee)
	c.set_value("campagne", "fin", fin_obtenue)
	c.set_value("campagne", "graine", graine)
	c.save(FICHIER_PROGRESSION)


## Le monte-charge : on remonte le butin, on descend d'un étage.
##
## C'est ICI que la descente prend son sens. Tout ce qui a été lu depuis le
## début de l'étage n'est acquis qu'à cet instant précis.
func remonter_butin() -> int:
	var n := documents_en_main.size()
	butin_remonte = n
	if n > 0:
		for id in documents_en_main:
			documents_lus[id] = true
		documents_en_main.clear()
		var c := ConfigFile.new()
		c.load(FICHIER_PROGRESSION)
		c.set_value("documents", "lus", documents_lus.keys())
		c.save(FICHIER_PROGRESSION)
	etages_termines[etage_courant] = true
	_ecrire_campagne()
	return n


## Mourir : le butin de l'étage est perdu, l'archive ne l'est pas.
func perdre_butin() -> int:
	var n := documents_en_main.size()
	documents_en_main.clear()
	return n


## Passe à l'étage du dessous. Renvoie false s'il n'y en a plus.
func descendre_etage() -> bool:
	var suivant := Etages.suivant(etage_courant)
	if suivant == 0:
		return false
	etage_courant = suivant
	etage_atteint = mini(etage_atteint, suivant)
	# une graine par étage : chaque étage est un plan neuf, et rejouer le même
	# étage après une mort doit redonner le même plan.
	graine = randi_range(1, 0x7FFFFFFF)
	montrer_prologue = false
	_ecrire_campagne()
	return true


func etage_def() -> Dictionary:
	return Etages.etage(etage_courant)


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


## A-t-on déjà ce document SOUS LES YEUX de cette descente ?
##
## Vrai aussi pour un document en main : c'est la question que pose le
## PLACEMENT, et un papier qu'on vient de ramasser ne doit pas réapparaître
## deux mètres plus loin parce qu'on n'est pas encore remonté.
func a_lu(id: String) -> bool:
	return documents_lus.has(id) or documents_en_main.has(id)


## Ce document est-il dans l'archive, pour de bon ?
##
## C'est la question que pose le JOURNAL. Un document en main n'y répond pas
## encore oui : il faut ressortir avec.
func a_acquis(id: String) -> bool:
	return documents_lus.has(id)


## Prend un document. Renvoie true si c'est une découverte, false si le joueur
## l'avait déjà trouvé lors d'une descente précédente.
##
## N'ÉCRIT RIEN SUR LE DISQUE : le document n'est qu'en main. Il n'entre dans
## l'archive qu'au passage du monte-charge (remonter_butin). C'est la règle qui
## donne son enjeu à la descente — mourir coûte ce qu'on n'a pas remonté.
func lire_document(id: String) -> bool:
	if a_lu(id):
		return false
	documents_en_main[id] = true
	document_lu.emit(id)
	return true


## Ce que le joueur a lu : l'archive plus ce qu'il porte.
func documents_trouves() -> int:
	return documents_lus.size() + documents_en_main.size()


## Ce qui est acquis pour de bon, sans le butin en cours.
func documents_acquis() -> int:
	return documents_lus.size()


func documents_en_cours() -> int:
	return documents_en_main.size()


## Ardoise vierge : l'archive ET le butin. Réservé aux outils de diagnostic et
## aux tests, qui doivent partir d'un état connu.
##
## Les deux tables se vident ensemble. N'en vider qu'une laisse un document
## « déjà lu » que plus rien n'affiche — de quoi faire échouer un test pour une
## raison qui n'a rien à voir avec ce qu'il mesure.
func oublier_tout() -> void:
	documents_lus.clear()
	documents_en_main.clear()
