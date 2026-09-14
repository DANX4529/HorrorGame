extends CanvasLayer
## Prologue : écran noir, texte frappé caractère par caractère.
##
## Il s'intercale entre le lancement d'une partie et la première image jouable.
## Le monde est déjà construit derrière, mais l'arbre est figé : rien ne bouge,
## la Veilleuse ne patrouille pas, le souffle ne s'entame pas.
##
## Le texte défile PAR TEMPS — un paragraphe frappé, tenu, puis effacé avant le
## suivant. D'un bloc, il dépassait le bas de l'écran et recouvrait l'invite ;
## par temps, il tient toujours, quelle que soit la longueur qu'on ajoutera.
## C'est aussi la respiration qui convient à un prologue : une phrase à la fois.
##
## TOUJOURS interrompable. Une descente est tirée au sort, donc on recommence
## souvent ; un prologue qu'on ne peut pas passer deviendrait une punition au
## troisième essai. L'invite apparaît dès la première seconde.

const VITESSE := 54.0          ## caractères par seconde
const TENUE := 0.78            ## temps de lecture une fois le temps frappé
const FONDU := 0.28            ## effacement entre deux temps
const FIN_ATTENTE := 1.1       ## noir final avant la première image jouable

enum Etat { FRAPPE, TENUE, FONDU, FIN }

var _texte: Label
var _invite: Label
var _temps: PackedStringArray = []
var _i := 0
var _etat: Etat = Etat.FRAPPE
var _montres := 0.0
var _minuteur := 0.0
var _t := 0.0


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
	_invite.text = "[Espace] passer"
	_invite.modulate.a = 0.0
	_texte.modulate.a = 1.0
	_texte.text = _temps[0] if not _temps.is_empty() else ""
	_texte.visible_characters = 0
	visible = true


func _process(delta: float) -> void:
	if GameState.phase != GameState.Phase.PROLOGUE:
		return
	_t += delta
	_invite.modulate.a = minf(1.0, _t * 1.4) * 0.8

	# « interact » couvre E et Espace, « pause » couvre Échap
	if Input.is_action_just_pressed("interact") \
			or Input.is_action_just_pressed("pause"):
		_terminer()
		return

	match _etat:
		Etat.FRAPPE:
			_montres += delta * VITESSE
			var n := mini(int(_montres), _texte.text.length())
			if n > _texte.visible_characters:
				_texte.visible_characters = n
			if n >= _texte.text.length():
				_etat = Etat.TENUE
				_minuteur = TENUE
		Etat.TENUE:
			_minuteur -= delta
			if _minuteur <= 0.0:
				_etat = Etat.FONDU
				_minuteur = FONDU
		Etat.FONDU:
			_minuteur -= delta
			_texte.modulate.a = clampf(_minuteur / FONDU, 0.0, 1.0)
			if _minuteur <= 0.0:
				_i += 1
				if _i >= _temps.size():
					_etat = Etat.FIN
					_minuteur = FIN_ATTENTE
					return
				_texte.text = _temps[_i]
				_texte.visible_characters = 0
				_texte.modulate.a = 1.0
				_montres = 0.0
				_etat = Etat.FRAPPE
				# une frappe discrète par temps, pas par caractère : au
				# caractère, des centaines de déclenchements crépiteraient
				Audio.play_2d("ui_move", -28.0, 0.92)
		Etat.FIN:
			_minuteur -= delta
			if _minuteur <= 0.0:
				_terminer()


func _terminer() -> void:
	if GameState.phase != GameState.Phase.PROLOGUE:
		return
	visible = false
	GameState.set_phase(GameState.Phase.JEU, true)


## Durée totale si on ne passe rien — sert au test.
func duree_estimee() -> float:
	var d := FIN_ATTENTE
	for b in _temps:
		d += (b as String).length() / VITESSE + TENUE + FONDU
	return d
