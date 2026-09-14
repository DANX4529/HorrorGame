extends Node3D
## Un document lisible posé dans le monde.
##
## Volontairement identique au décor : le jeu disperse déjà des liasses de
## papier un peu partout, et un document du récit en est une. Rien ne le
## distingue de loin, sinon la lueur infime qui signale tout objet ramassable.
## Chercher l'histoire demande donc de fouiller, ce qui est le but.

var id := ""
var _t := 0.0
var _halo: OmniLight3D


func setup(doc_id: String, scene: PackedScene, pos: Vector3, rot := 0.0) -> void:
	id = doc_id
	position = pos
	rotation.y = rot
	if scene:
		var m := scene.instantiate()
		add_child(m)
		MaterialLib.apply(m)

	# Une lueur froide et faible. Les objets utiles (fusible, pile) sont chauds :
	# le joueur distingue ainsi d'un coup d'oeil ce qui sert à survivre de ce qui
	# sert à comprendre, sans qu'aucun texte ait à le lui dire.
	_halo = OmniLight3D.new()
	_halo.light_color = Color(0.76, 0.80, 0.92)
	_halo.light_energy = 0.34
	_halo.omni_range = 1.25
	_halo.shadow_enabled = false
	add_child(_halo)

	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	# Volume de saisie VERTICAL, pas une sphère posée au sol.
	#
	# Le rayon d'interaction part de la caméra, à hauteur d'yeux. Une sphère de
	# 42 cm plaquée au sol n'était atteignable qu'en se plaçant à 80 cm et en
	# regardant à plus de 50° vers le bas — un joueur qui s'approche normalement
	# de papiers au sol ne l'aurait jamais attrapée, et aurait manqué l'histoire
	# sans jamais savoir qu'elle existait. Une colonne montant à hauteur de
	# poitrine se laisse viser depuis une posture naturelle.
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.46
	cyl.height = 1.30
	cs.shape = cyl
	cs.position = Vector3(0, 0.62, 0)
	area.add_child(cs)
	add_child(area)

	_maj_halo()


## Un document déjà lu garde sa lueur, mais affaiblie : le joueur repère au
## premier regard ce qu'il n'a pas encore ouvert, sans perdre la trace du reste.
func _maj_halo() -> void:
	if _halo:
		_halo.light_energy = 0.12 if GameState.a_lu(id) else 0.34


func interact(_who) -> void:
	GameState.ouvrir_document(id)
	_maj_halo()


func prompt() -> String:
	var d: Dictionary = Lore.doc(id)
	var t: String = d.get("titre", "document")
	return "Relire : %s" % t if GameState.a_lu(id) else "Lire : %s" % t


func _process(delta: float) -> void:
	# il ne tourne pas sur lui-même comme les objets ramassables : un papier
	# posé reste posé. Seule la lueur respire un peu.
	_t += delta
	if _halo:
		var base: float = 0.12 if GameState.a_lu(id) else 0.34
		_halo.light_energy = base * (0.86 + 0.14 * sin(_t * 1.4))
