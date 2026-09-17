extends Node
## Chef d'orchestre de l'ambiance : ce que le sanatorium fait tout seul.
##
## Trois couches, de la plus continue à la plus rare :
##
##   NAPPES      deux boucles superposées en permanence — la cave et le souffle
##               du bâtiment — plus une horloge qui va et vient. Elles tiennent
##               le silence : un lieu muet n'est pas inquiétant, il est vide.
##   BRUITS      sons isolés posés DANS le monde, à distance et hors de vue :
##               une tôle qui travaille, une porte qui claque ailleurs, une
##               toux. Leur direction compte autant que leur contenu.
##   NAPPES MUSICALES  rares, courtes, et jamais deux fois de suite la même.
##
## RIEN DE TOUT CELA NE PASSE PAR NoiseBus. Ces sons n'existent pas pour la
## Veilleuse. L'inverse voudrait dire qu'un tuyau qui grince la dérange autant
## qu'un pas du joueur, et l'équité de la mécanique s'effondrerait : le joueur
## serait puni pour un bruit qu'il n'a pas fait.
##
## Rien ne se déclenche non plus pendant une traque. La musique de chasse y
## occupe déjà tout l'espace, et un grincement de plus n'ajouterait que de la
## confusion au moment où le joueur a le plus besoin d'entendre clair.

## Bruits isolés : nom, volume, et s'ils doivent sonner LOIN ou tout près.
const BRUITS := [
	{"son": "peur_tole",       "db": -15.0, "loin": true},
	{"son": "peur_claque",     "db": -13.0, "loin": true},
	{"son": "peur_chute",      "db": -15.0, "loin": true},
	{"son": "peur_toux",       "db": -17.0, "loin": true},
	{"son": "peur_plainte",    "db": -19.0, "loin": true},
	{"son": "peur_grincement", "db": -16.0, "loin": false},
	{"son": "peur_ressort",    "db": -17.0, "loin": false},
	# le seul qui vient de tout près : à réserver, il fait sursauter
	{"son": "peur_souffle",    "db": -20.0, "loin": false, "rare": true},
	{"son": "creak_1",         "db": -15.0, "loin": false},
	{"son": "creak_2",         "db": -15.0, "loin": false},
	{"son": "creak_3",         "db": -15.0, "loin": false},
	{"son": "drip_1",          "db": -17.0, "loin": false},
	{"son": "drip_2",          "db": -17.0, "loin": false},
	{"son": "drip_3",          "db": -17.0, "loin": false},
]

const MUSIQUES := ["musique_1", "musique_2", "musique_3"]

const BRUIT_MIN := 11.0        ## secondes entre deux bruits isolés
const BRUIT_MAX := 27.0
const MUSIQUE_MIN := 95.0      ## ... et entre deux nappes musicales
const MUSIQUE_MAX := 180.0
const HORLOGE_MIN := 70.0
const HORLOGE_MAX := 160.0

var joueur: Node3D = null
var veilleuse: Node = null

var _cave: AudioStreamPlayer
var _souffle: AudioStreamPlayer
var _horloge: AudioStreamPlayer
var _musique: AudioStreamPlayer
var _t_bruit := 6.0
var _t_musique := 45.0
var _t_horloge := 30.0
var _horloge_visee := -60.0
var _derniere_musique := -1
var _dernier_bruit := -1

## Journal des déclenchements, pour la vérification.
var joues: Array[String] = []


func _ready() -> void:
	_cave = Audio.make_loop("amb_drone", -17.0, "Ambiance")
	_cave.play()
	_souffle = Audio.make_loop("amb_souffle", -22.0, "Ambiance")
	_souffle.play()
	_horloge = Audio.make_loop("amb_horloge", -60.0, "Ambiance")
	_horloge.play()
	_musique = Audio.make_loop("musique_1", -60.0, "Musique")


## Vrai quand l'ambiance doit se taire : la traque a besoin de clarté.
func _en_traque() -> bool:
	return is_instance_valid(veilleuse) and veilleuse.has_method("is_hunting") \
			and veilleuse.is_hunting()


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.JEU or not is_instance_valid(joueur):
		return
	var traque := _en_traque()

	# l'horloge va et vient : toujours présente, elle deviendrait un meuble
	_t_horloge -= delta
	if _t_horloge <= 0.0:
		_t_horloge = randf_range(HORLOGE_MIN, HORLOGE_MAX)
		_horloge_visee = -60.0 if _horloge_visee > -50.0 else randf_range(-30.0, -24.0)
	_horloge.volume_db = move_toward(_horloge.volume_db, _horloge_visee, delta * 3.0)

	if traque:
		# on laisse la musique de traque seule à l'avant-plan
		_musique.volume_db = move_toward(_musique.volume_db, -60.0, delta * 9.0)
		return

	_t_bruit -= delta
	if _t_bruit <= 0.0:
		_t_bruit = randf_range(BRUIT_MIN, BRUIT_MAX)
		_lancer_bruit()

	_t_musique -= delta
	if _t_musique <= 0.0:
		_t_musique = randf_range(MUSIQUE_MIN, MUSIQUE_MAX)
		_lancer_musique()
	# la nappe s'installe doucement puis s'efface d'elle-même
	if _musique.playing:
		var reste: float = _musique.stream.get_length() - _musique.get_playback_position()
		var cible := -24.0 if reste > 6.0 else -60.0
		_musique.volume_db = move_toward(_musique.volume_db, cible, delta * 4.0)
		if reste <= 0.15:
			_musique.stop()


## Place un bruit dans le monde, jamais sur le joueur.
##
## La direction fait la moitié du travail : un son qui vient de derrière une
## cloison inquiète, le même son joué sur la tête n'est qu'un effet.
func _lancer_bruit() -> void:
	# Les sons marqués « rare » ne sortent qu'une fois sur quatre, et aucun son
	# ne se répète d'affilée : un sursaut répété n'est plus un sursaut.
	#
	# On retire jusqu'à obtenir un candidat acceptable plutôt que de décaler
	# l'indice d'un cran : le décalage pouvait retomber pile sur le son
	# précédent, et la répétition qu'on voulait interdire passait quand même.
	var i := randi() % BRUITS.size()
	for essai in 12:
		var refuse: bool = i == _dernier_bruit \
				or (BRUITS[i].get("rare", false) and randf() > 0.25)
		if not refuse:
			break
		i = randi() % BRUITS.size()
	_dernier_bruit = i
	var b: Dictionary = BRUITS[i]
	var loin: bool = b.get("loin", false)
	var a := randf() * TAU
	var r: float = randf_range(14.0, 26.0) if loin else randf_range(4.0, 11.0)
	var pos: Vector3 = joueur.global_position \
			+ Vector3(cos(a) * r, randf_range(0.2, 2.6), sin(a) * r)
	Audio.play_3d(str(b["son"]), pos, float(b["db"]), randf_range(0.92, 1.08))
	joues.append(str(b["son"]))


func _lancer_musique() -> void:
	var i := randi() % MUSIQUES.size()
	if i == _derniere_musique:
		i = (i + 1) % MUSIQUES.size()
	_derniere_musique = i
	_musique.stream = Audio.stream(MUSIQUES[i])
	_musique.volume_db = -60.0
	_musique.play()
	joues.append(MUSIQUES[i])


## Force un déclenchement — sert à la vérification.
func provoquer(quoi: String) -> void:
	if quoi == "bruit":
		_lancer_bruit()
	elif quoi == "musique":
		_lancer_musique()
