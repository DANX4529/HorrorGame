extends CanvasLayer
## Prologue : écran noir, texte frappé caractère par caractère.
##
## Il s'intercale entre le lancement d'une partie et la première image jouable.
## Le monde est déjà construit derrière, mais l'arbre est figé : rien ne bouge,
## la Veilleuse ne patrouille pas, le souffle ne s'entame pas.
##
## Le texte défile PAR TEMPS — un paragraphe frappé, puis on ATTEND le joueur.
## D'un bloc, il dépassait le bas de l'écran et recouvrait l'invite ; par temps,
## il tient toujours, quelle que soit la longueur qu'on ajoutera.
##
## L'enchaînement est manuel, pas minuté : chacun lit à son rythme, et une
## minuterie assez lente pour le lecteur le plus posé serait interminable pour
## tous les autres. Trois usages d'une même touche, dans l'ordre où ils viennent
## naturellement sous le doigt :
##
##   pendant la frappe  -> affiche le paragraphe d'un coup
##   une fois affiché   -> passe au suivant
##   au dernier         -> commence la partie
##
## Échap reste à part et saute TOUT. Il le faut : une descente est tirée au
## sort, donc on recommence souvent, et onze validations à chaque essai
## deviendraient une punition. Les deux invites sont visibles dès la première
## seconde — on ne doit jamais se sentir prisonnier de l'introduction.

const VITESSE := 54.0          ## caractères par seconde
const FONDU := 0.28            ## effacement entre deux temps
## Court délai avant que l'invite « continuer » ne réponde, pour qu'une touche
## maintenue depuis la frappe ne fasse pas défiler deux temps d'un coup.
const GARDE := 0.18

enum Etat { FRAPPE, ATTENTE, FONDU }

var _texte: Label
var _invite: Label
var _temps: PackedStringArray = []
var _i := 0
var _etat: Etat = Etat.FRAPPE
var _montres := 0.0
var _minuteur := 0.0
var _t := 0.0
var _garde := 0.0


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_construire()
	GameState.phase_changed.connect(_sur_phase)


func _construire() -> void:
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 1)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_texte = Label.new()
	_texte.custom_minimum_size = Vector2(680, 0)
	_texte.add_theme_font_size_override("font_size", 21)
	_texte.add_theme_color_override("font_color", Color(0.87, 0.84, 0.76))
	_texte.add_theme_constant_override("line_spacing", 11)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(_texte)

	_invite = Label.new()
	_invite.add_theme_font_size_override("font_size", 13)
	_invite.add_theme_color_override("font_color", Color(0.44, 0.46, 0.42))
	_invite.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_invite.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
	_invite.offset_left = -240; _invite.offset_right = 240
	_invite.offset_top = -56; _invite.offset_bottom = -34
	_invite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_invite)


func _sur_phase(p: int) -> void:
	if p == GameState.Phase.PROLOGUE:
		_demarrer()
	else:
		visible = false


## Découpe le prologue en temps : un temps par paragraphe (ligne vide).
func _demarrer() -> void:
	_temps = PackedStringArray()
	for bloc in Lore.PROLOGUE.split("\n\n"):
		var b := (bloc as String).strip_edges()
		if b != "":
			_temps.append(b)
	_i = 0
	_etat = Etat.FRAPPE
	_montres = 0.0
	_minuteur = 0.0
	_t = 0.0
	_invite.modulate.a = 0.0
	_garde = 0.0
	_maj_invite()
	_texte.modulate.a = 1.0
	_texte.text = _temps[0] if not _temps.is_empty() else ""
	_texte.visible_characters = 0
	visible = true


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PROLOGUE:
		return
	_t += delta
	_garde = maxf(0.0, _garde - delta)
	var paru := minf(1.0, _t * 1.4)
	# l'invite se renforce quand c'est au joueur de jouer
	_invite.modulate.a = paru * (1.0 if _etat == Etat.ATTENTE else 0.62)

	# Échap saute tout ; « interact » (E ou Espace) agit selon l'état
	if Input.is_action_just_pressed("pause"):
		_terminer()
		return
	var avance := Input.is_action_just_pressed("interact")

	match _etat:
		Etat.FRAPPE:
			if avance:
				# on n'attend pas la fin de la frappe pour lire
				_texte.visible_characters = _texte.text.length()
				_montres = float(_texte.text.length())
				_passer_en_attente()
				return
			_montres += delta * VITESSE
			var n := mini(int(_montres), _texte.text.length())
			if n > _texte.visible_characters:
				_texte.visible_characters = n
			if n >= _texte.text.length():
				_passer_en_attente()
		Etat.ATTENTE:
			if avance and _garde <= 0.0:
				if _i + 1 >= _temps.size():
					_terminer()
					return
				_etat = Etat.FONDU
				_minuteur = FONDU
				_maj_invite()
		Etat.FONDU:
			_minuteur -= delta
			_texte.modulate.a = clampf(_minuteur / FONDU, 0.0, 1.0)
			if _minuteur <= 0.0:
				_i += 1
				_texte.text = _temps[_i]
				_texte.visible_characters = 0
				_texte.modulate.a = 1.0
				_montres = 0.0
				_etat = Etat.FRAPPE
				_maj_invite()
				# une frappe discrète par temps, pas par caractère : au
				# caractère, des centaines de déclenchements crépiteraient
				Audio.play_2d("ui_move", -28.0, 0.92)


func _passer_en_attente() -> void:
	_etat = Etat.ATTENTE
	_garde = GARDE
	_maj_invite()


## L'invite dit ce que la touche fait MAINTENANT : « afficher » pendant la
## frappe, « continuer » ensuite, « descendre » au dernier temps. Une invite
## figée mentirait deux fois sur trois.
func _maj_invite() -> void:
	var dernier: bool = _i + 1 >= _temps.size()
	var action := "afficher"
	if _etat == Etat.ATTENTE:
		action = "descendre" if dernier else "continuer"
	_invite.text = "[Espace] %s          [Échap] passer l'introduction" % action


func _terminer() -> void:
	if GameState.phase != GameState.Phase.PROLOGUE:
		return
	visible = false
	GameState.set_phase(GameState.Phase.JEU, true)


## Temps de FRAPPE cumulé, hors attentes. La durée réelle dépend du joueur :
## c'est tout l'objet de l'enchaînement manuel. Sert au test.
func duree_frappe() -> float:
	var d := 0.0
	for b in _temps:
		d += (b as String).length() / VITESSE + FONDU
	return d
