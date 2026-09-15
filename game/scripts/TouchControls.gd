extends CanvasLayer
## Commandes tactiles : manche de déplacement, zone de visée, boutons d'action.
##
## Elles pilotent les MÊMES actions que le clavier, via Input.action_press :
## rien dans Player, Veilleuse ou Menu n'a besoin de savoir qu'un doigt existe.
## Le déplacement passe par get_action_strength(), donc pousser le manche à
## moitié fait avancer à moitié — un véritable analogique, pas quatre flèches.
##
## Disposition, pensée pour deux pouces en paysage :
##   moitié gauche   manche apparaissant sous le pouce, là où il se pose
##   moitié droite   glissement = visée ; les boutons y flottent
##   bas droite      RETENIR SON SOUFFLE, dans le COIN, large
##   au-dessus       agir, lampe, s'accroupir
##   haut droite     pause
##
## Le souffle occupe le coin parce que c'est le geste d'urgence et que le coin
## est le seul endroit qu'un pouce atteint sans réfléchir. Le centre du bas,
## où il était d'abord, n'est atteignable par aucun des deux pouces quand on
## tient un téléphone en paysage — et il recouvrait la jauge de souffle.
##
## Le manche apparaît où l'on touche plutôt qu'à un endroit fixe : sur un
## téléphone tenu à deux mains, la position du pouce varie de plusieurs
## centimètres d'une prise à l'autre, et un manche fixe se rate sans arrêt.

const RAYON := 96.0            ## amplitude du manche, en pixels
const ZONE_MORTE := 0.14
const SEUIL_COURSE := 0.82     ## pousser à fond = courir
const TAILLE_BOUTON := 82.0
const VISEE_GAIN := 1.35       ## un doigt parcourt moins de chemin qu'une souris

var joueur: Node = null

var _racine: Control
var _manche_fond: Control
var _manche_tete: Control
var _doigt_manche := -1        ## index du doigt qui tient le manche
var _doigt_visee := -1
var _centre := Vector2.ZERO
var _dir := Vector2.ZERO
var _boutons: Dictionary = {}  ## action -> Control
var _souffle: Control


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_INHERIT
	_construire()
	visible = false
	Tactile.mode_change.connect(func(_a): _rafraichir())
	GameState.phase_changed.connect(func(_p): _rafraichir())
	_rafraichir()


## Visibles seulement en tactile ET pendant le jeu : afficher un manche par
## dessus un menu ou l'écran de mort ne ferait que masquer des boutons.
func _rafraichir() -> void:
	var montrer: bool = Tactile.actif and GameState.phase == GameState.Phase.JEU
	visible = montrer
	if not montrer:
		_relacher_tout()


## Relâche TOUT, y compris les boutons.
##
## Indispensable : presser « pause » change la phase, donc masque ces
## commandes, et le doigt qui se lève n'est alors plus reçu. L'action resterait
## enfoncée et se redéclencherait au retour au jeu — on rebasculerait en pause
## aussitôt sorti de la pause.
func _relacher_tout() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(a)
	for action in _boutons:
		var b: Control = _boutons[action]
		Input.action_release(action)
		if b.has_meta("doigt"):
			b.remove_meta("doigt")
		_marquer(b, false)
	_doigt_manche = -1
	_doigt_visee = -1
	_dir = Vector2.ZERO
	if _manche_fond:
		_manche_fond.visible = false


# --------------------------------------------------------------------------
func _cercle(diam: float, couleur: Color, epaisseur: float) -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(diam, diam)
	c.size = Vector2(diam, diam)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = couleur
	st.set_corner_radius_all(int(diam * 0.5))
	st.border_color = Color(0.86, 0.84, 0.78, 0.30)
	st.set_border_width_all(int(epaisseur))
	c.add_theme_stylebox_override("panel", st)
	return c


func _construire() -> void:
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)

	_manche_fond = _cercle(RAYON * 2.0, Color(1, 1, 1, 0.055), 2.0)
	_manche_fond.visible = false
	_racine.add_child(_manche_fond)
	_manche_tete = _cercle(RAYON * 0.78, Color(0.88, 0.86, 0.80, 0.16), 2.0)
	_manche_tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_manche_fond.add_child(_manche_tete)

	_bouton("interact", "AGIR", Vector2(-112, -196), 82.0)
	_bouton("flashlight", "LAMPE", Vector2(-210, -192), 78.0)
	_bouton("crouch", "BAISSÉ", Vector2(-300, -100), 78.0)
	_bouton("pause", "II", Vector2(-84, 40), 56.0)

	# Le souffle est la mécanique centrale : large, dans le coin, impossible à
	# manquer dans la panique. C'est le seul bouton qu'on presse en urgence.
	_souffle = _panneau_texte("SOUFFLE", Vector2(190, 80))
	_souffle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, false)
	_souffle.offset_left = -210; _souffle.offset_right = -20
	_souffle.offset_top = -100; _souffle.offset_bottom = -20
	var st: StyleBoxFlat = _souffle.get_theme_stylebox("panel")
	st.set_corner_radius_all(18)
	_racine.add_child(_souffle)
	_boutons["hold_breath"] = _souffle


func _panneau_texte(texte: String, taille: Vector2) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = taille
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.06, 0.07, 0.42)
	st.set_corner_radius_all(14)
	st.border_color = Color(0.86, 0.84, 0.78, 0.26)
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = texte
	l.name = "Texte"
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82, 0.86))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


## Bouton rond ancré en bas à droite (décalage négatif) ou en haut (positif y).
func _bouton(action: String, texte: String, decalage: Vector2, diam := TAILLE_BOUTON) -> void:
	var b := _panneau_texte(texte, Vector2(diam, diam))
	var st: StyleBoxFlat = b.get_theme_stylebox("panel")
	st.set_corner_radius_all(int(diam * 0.5))
	if decalage.y > 0.0:
		b.set_anchors_preset(Control.PRESET_TOP_RIGHT, false)
		b.offset_top = decalage.y; b.offset_bottom = decalage.y + diam
	else:
		b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, false)
		b.offset_top = decalage.y; b.offset_bottom = decalage.y + diam
	b.offset_left = decalage.x; b.offset_right = decalage.x + diam
	_racine.add_child(b)
	_boutons[action] = b


# --------------------------------------------------------------------------
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_poser(t.index, t.position)
		else:
			_lever(t.index, t.position)
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _doigt_manche:
			_maj_manche(d.position)
		elif d.index == _doigt_visee and is_instance_valid(joueur):
			joueur.tourner(d.relative * VISEE_GAIN)
		get_viewport().set_input_as_handled()


func _poser(index: int, pos: Vector2) -> void:
	# un bouton l'emporte sur tout : il peut déborder sur la moitié gauche
	for action in _boutons:
		var b: Control = _boutons[action]
		if b.get_global_rect().has_point(pos):
			Input.action_press(action)
			_marquer(b, true)
			b.set_meta("doigt", index)
			return
	if pos.x < get_viewport().get_visible_rect().size.x * 0.5:
		if _doigt_manche == -1:
			_doigt_manche = index
			_centre = pos
			_manche_fond.visible = true
			_manche_fond.position = pos - Vector2(RAYON, RAYON)
			_maj_manche(pos)
	elif _doigt_visee == -1:
		_doigt_visee = index


func _lever(index: int, _pos: Vector2) -> void:
	for action in _boutons:
		var b: Control = _boutons[action]
		if b.has_meta("doigt") and int(b.get_meta("doigt")) == index:
			Input.action_release(action)
			_marquer(b, false)
			b.remove_meta("doigt")
			return
	if index == _doigt_manche:
		_doigt_manche = -1
		_manche_fond.visible = false
		_dir = Vector2.ZERO
		_appliquer_deplacement()
	elif index == _doigt_visee:
		_doigt_visee = -1


func _maj_manche(pos: Vector2) -> void:
	var v := (pos - _centre) / RAYON
	if v.length() > 1.0:
		v = v.normalized()
	_dir = v
	_manche_tete.position = Vector2(RAYON * 0.61, RAYON * 0.61) + v * RAYON * 0.62
	_appliquer_deplacement()


## Traduit le manche en forces d'action. On presse les quatre directions avec
## une force analogique plutôt que de bricoler un vecteur ailleurs : Player lit
## déjà get_action_strength, donc le clavier et le doigt suivent le même code.
func _appliquer_deplacement() -> void:
	var v := _dir
	if v.length() < ZONE_MORTE:
		v = Vector2.ZERO
	_force("move_right", v.x)
	_force("move_left", -v.x)
	_force("move_back", v.y)
	_force("move_forward", -v.y)
	# pousser à fond vers l'avant équivaut à courir : un bouton de course de
	# plus aurait encombré l'écran pour une action qu'on fait déjà « à fond »
	if v.y < -SEUIL_COURSE:
		Input.action_press("sprint")
	else:
		Input.action_release("sprint")


func _force(action: String, f: float) -> void:
	if f > 0.0:
		Input.action_press(action, clampf(f, 0.0, 1.0))
	else:
		Input.action_release(action)


func _marquer(b: Control, enfonce: bool) -> void:
	var st: StyleBoxFlat = b.get_theme_stylebox("panel")
	st.bg_color = Color(0.82, 0.80, 0.74, 0.30) if enfonce else Color(0.06, 0.06, 0.07, 0.42)


func _process(_delta: float) -> void:
	# le bouton de souffle se teinte quand l'apnée est impossible : sans retour,
	# on appuierait dans le vide sans comprendre pourquoi rien ne se passe
	if visible and _souffle and is_instance_valid(joueur):
		var l := _souffle.get_node("Texte") as Label
		var peut: bool = joueur.breath.can_hold()
		l.modulate.a = 0.86 if peut else 0.34
