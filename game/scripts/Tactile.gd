extends Node
## Détection du mode d'entrée : doigt ou clavier/souris.
##
## Deux sources, parce qu'aucune ne suffit seule :
##
## * la plateforme — un navigateur mobile ou un système mobile annonce
##   « web_android », « web_ios » ou « mobile », et là c'est certain ;
## * le PREMIER TOUCHER — un portable Windows à écran tactile, un Chromebook,
##   une tablette en mode bureau ne s'annoncent pas, et
##   DisplayServer.is_touchscreen_available() y répond vrai alors que la
##   personne joue au clavier. On n'allume donc pas les commandes tactiles sur
##   cette seule promesse : on attend qu'un doigt se pose réellement.
##
## Et l'inverse est vrai aussi : une touche ou un mouvement de souris rebascule
## en mode clavier. Un appareil hybride suit ainsi ce qu'on fait, sans réglage.

signal mode_change(tactile: bool)

## Vrai quand l'interface doit s'adresser à un doigt.
var actif := false

## Forcé par --tactile / --clavier, pour les vérifications.
var _force := 0                     # 0 = auto, 1 = tactile, -1 = clavier

## Instant du dernier vrai toucher, en millisecondes.
##
## Godot convertit les touchers en événements souris (emulate_mouse_from_touch,
## actif par défaut, et nécessaire pour que les boutons de menu répondent au
## doigt). Sans cette garde, chaque glissement de visée émettait aussi une
## motion souris, Tactile croyait voir une souris, et les commandes tactiles
## disparaissaient en pleine partie.
var _dernier_toucher := 0
const FENETRE_EMULATION := 200      # ms


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web_android") or OS.has_feature("web_ios") \
			or OS.has_feature("mobile"):
		actif = true


func forcer(tactile: bool) -> void:
	_force = 1 if tactile else -1
	_basculer(tactile)


func _input(e: InputEvent) -> void:
	if _force != 0:
		return
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_dernier_toucher = Time.get_ticks_msec()
		_basculer(true)
	elif e is InputEventKey or e is InputEventMouseButton \
			or e is InputEventMouseMotion:
		# un événement souris qui suit immédiatement un toucher est une
		# émulation, pas une vraie souris
		if Time.get_ticks_msec() - _dernier_toucher < FENETRE_EMULATION:
			return
		# un mouvement de souris minuscule ne compte pas : sur certains
		# portables, le pavé tactile en émet au repos
		if e is InputEventMouseMotion and (e as InputEventMouseMotion).relative.length() < 2.0:
			return
		_basculer(false)


func _basculer(vers: bool) -> void:
	if actif == vers:
		return
	actif = vers
	mode_change.emit(actif)


## Libellé d'action adapté au mode. Les invites du jeu nomment des touches
## (« [E] Ouvrir la porte »), ce qui ne veut rien dire pour un doigt.
func libelle(clavier: String, tactile: String) -> String:
	return tactile if actif else clavier


## Taille de cible confortable. Un bouton de menu de 38 px se rate au doigt :
## les recommandations d'accessibilité tournent autour de 44 px, on prend 54
## pour un jeu où l'on est pressé et dans le noir.
func hauteur_bouton() -> int:
	return 54 if actif else 38


func taille_police(base: int) -> int:
	return base + 2 if actif else base


## Vrai si cet événement souris n'est que l'écho d'un toucher.
func echo_de_toucher() -> bool:
	return actif and Time.get_ticks_msec() - _dernier_toucher < FENETRE_EMULATION
