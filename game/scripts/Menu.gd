extends CanvasLayer
## Écrans pleins : titre, options, pause, mort, victoire.
##
## Séparés du HUD, qui ne garde que l'affichage en cours de partie et le
## post-traitement. Tout est construit par code, comme le reste du projet.

enum Ecran { AUCUN, TITRE, OPTIONS, PAUSE, MORT, VICTOIRE }

const OR := Color(0.87, 0.83, 0.74)
const GRIS := Color(0.70, 0.72, 0.67)
const SOURD := Color(0.48, 0.50, 0.46)

var _voile: ColorRect
var _boite: VBoxContainer
var _ecran: Ecran = Ecran.AUCUN
var _retour: Ecran = Ecran.TITRE
var _joueur: Player


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	GameState.phase_changed.connect(_sur_phase)
	_sur_phase(GameState.phase)


func bind(p: Player) -> void:
	_joueur = p


func _construire() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)

	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0.86)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	racine.add_child(_voile)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	racine.add_child(centre)

	_boite = VBoxContainer.new()
	_boite.add_theme_constant_override("separation", 10)
	_boite.custom_minimum_size = Vector2(620, 0)
	centre.add_child(_boite)


# ==========================================================================
#  Briques d'interface
# ==========================================================================
func _vider() -> void:
	for c in _boite.get_children():
		c.queue_free()


func _texte(t: String, taille: int, col: Color, esp := 0.0) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	if esp > 0.0:
		l.add_theme_constant_override("line_spacing", int(esp))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boite.add_child(l)
	return l


func _espace(h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_boite.add_child(c)


func _bouton(t: String, appui: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", OR if accent else GRIS)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.90))
	b.add_theme_color_override("font_focus_color", Color(1, 0.97, 0.90))
	b.flat = true
	b.pressed.connect(func():
		Audio.play_2d("ui_select", -14.0)
		appui.call())
	b.mouse_entered.connect(func(): Audio.play_2d("ui_move", -24.0))
	_boite.add_child(b)
	return b


## Ligne « intitulé ............ réglage »
func _ligne(intitule: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.custom_minimum_size = Vector2(0, 32)
	var l := Label.new()
	l.text = intitule
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GRIS)
	l.custom_minimum_size = Vector2(250, 0)
	h.add_child(l)
	_boite.add_child(h)
	return h


func _reglage_glissiere(intitule: String, val: float, sur_change: Callable) -> void:
	var h := _ligne(intitule)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = val
	s.custom_minimum_size = Vector2(260, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(s)
	var v := Label.new()
	v.text = "%3d %%" % int(round(val * 100))
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", SOURD)
	v.custom_minimum_size = Vector2(62, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(v)
	s.value_changed.connect(func(x):
		v.text = "%3d %%" % int(round(x * 100))
		sur_change.call(x)
		Settings.appliquer()
		Settings.sauver())


func _reglage_bascule(intitule: String, val: bool, sur_change: Callable) -> void:
	var h := _ligne(intitule)
	var b := Button.new()
	b.text = "Oui" if val else "Non"
	b.custom_minimum_size = Vector2(322, 30)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", OR)
	b.flat = true
	b.pressed.connect(func():
		var nv := b.text == "Non"
		b.text = "Oui" if nv else "Non"
		sur_change.call(nv)
		Settings.sauver()
		Audio.play_2d("ui_select", -16.0))
	h.add_child(b)


# ==========================================================================
#  Écrans
# ==========================================================================
func _sur_phase(p: int) -> void:
	match p:
		GameState.Phase.TITRE:   _afficher(Ecran.TITRE)
		GameState.Phase.PAUSE:   _afficher(Ecran.PAUSE)
		GameState.Phase.MORT:    _afficher(Ecran.MORT)
		GameState.Phase.VICTOIRE: _afficher(Ecran.VICTOIRE)
		_:                       _afficher(Ecran.AUCUN)


func _afficher(e: Ecran) -> void:
	_ecran = e
	_vider()
	_voile.visible = e != Ecran.AUCUN
	visible = e != Ecran.AUCUN
	if e == Ecran.AUCUN:
		return
	match e:
		Ecran.TITRE:    _ecran_titre()
		Ecran.OPTIONS:  _ecran_options()
		Ecran.PAUSE:    _ecran_pause()
		Ecran.MORT:     _ecran_mort()
		Ecran.VICTOIRE: _ecran_victoire()


func _ecran_titre() -> void:
	_texte("RESPIRE", 56, OR)
	_texte("Sanatorium du Mont-Cendre — 1961", 15, SOURD)
	_espace(14)
	_texte("Quelque chose arpente les couloirs. C'est aveugle.\n"
		+ "Ça chasse au son. Et le bruit le plus fort dans un bâtiment vide,\n"
		+ "c'est votre propre respiration.", 15, GRIS, 6)
	_espace(18)

	var noms := Settings.DIFF_NOMS
	var desc := _texte(Settings.DIFF_DESC[Settings.difficulte], 13, SOURD)
	var b := _bouton("Difficulté   ‹  %s  ›" % noms[Settings.difficulte], func(): pass, true)
	b.pressed.connect(func():
		Settings.difficulte = (Settings.difficulte + 1) % noms.size()
		b.text = "Difficulté   ‹  %s  ›" % noms[Settings.difficulte]
		desc.text = Settings.DIFF_DESC[Settings.difficulte]
		Settings.sauver())
	_boite.move_child(b, desc.get_index())

	_espace(10)
	if GameState.a_un_point_de_controle():
		_bouton("Reprendre la descente", func():
			GameState.reprendre()
			_relancer(), true)
		_bouton("Recommencer depuis le début", func():
			GameState.effacer_point_de_controle()
			_relancer())
	else:
		_bouton("Descendre", func():
			GameState.effacer_point_de_controle()
			_relancer(), true)
	_bouton("Options", func():
		_retour = Ecran.TITRE
		_afficher(Ecran.OPTIONS))
	if not OS.has_feature("web"):
		_bouton("Quitter", func(): get_tree().quit())

	_espace(12)
	var mt := GameState.meilleur_temps()
	if mt > 0.0:
		_texte("Meilleur temps en %s : %s" % [Settings.nom_difficulte(), _mmss(mt)], 13, SOURD)
	_texte("ZQSD / WASD  se déplacer      Maj  courir      C  s'accroupir\n"
		+ "Ctrl  RETENIR SON SOUFFLE      E  interagir      F  lampe      Échap  pause",
		13, SOURD, 4)


func _ecran_options() -> void:
	_texte("OPTIONS", 34, OR)
	_espace(14)
	_texte("COMMANDES", 13, SOURD)
	_reglage_glissiere("Sensibilité de la souris", Settings.sensibilite,
		func(v): Settings.sensibilite = v)
	_reglage_bascule("Inverser l'axe vertical", Settings.inverser_y,
		func(v): Settings.inverser_y = v)
	_espace(10)
	_texte("IMAGE", 13, SOURD)
	_reglage_glissiere("Luminosité", Settings.luminosite,
		func(v): Settings.luminosite = v)
	_espace(10)
	_texte("SON", 13, SOURD)
	_reglage_glissiere("Volume général", Settings.vol_general,
		func(v): Settings.vol_general = v)
	_reglage_glissiere("Effets", Settings.vol_effets, func(v): Settings.vol_effets = v)
	_reglage_glissiere("Respiration et coeur", Settings.vol_souffle,
		func(v): Settings.vol_souffle = v)
	_reglage_glissiere("Ambiance", Settings.vol_ambiance, func(v): Settings.vol_ambiance = v)
	_reglage_glissiere("Musique", Settings.vol_musique, func(v): Settings.vol_musique = v)
	_espace(14)
	_bouton("Valeurs par défaut", func():
		Settings.remettre_defauts()
		_afficher(Ecran.OPTIONS))
	_bouton("Retour", func(): _afficher(_retour), true)


func _ecran_pause() -> void:
	_texte("PAUSE", 40, OR)
	_espace(16)
	_bouton("Reprendre", func(): GameState.set_phase(GameState.Phase.JEU), true)
	_bouton("Options", func():
		_retour = Ecran.PAUSE
		_afficher(Ecran.OPTIONS))
	_bouton("Recommencer la partie", func(): _relancer())
	_bouton("Retour au titre", func():
		GameState.set_phase(GameState.Phase.TITRE, true)
		get_tree().reload_current_scene())
	_espace(12)
	_texte("Difficulté : %s" % Settings.nom_difficulte(), 13, SOURD)


func _ecran_mort() -> void:
	_texte("ELLE VOUS A TROUVÉ", 44, Color(0.78, 0.26, 0.22))
	_espace(10)
	_releve()
	_espace(14)
	if GameState.a_un_point_de_controle():
		_bouton("Reprendre au tableau électrique", func():
			GameState.reprendre()
			_relancer(), true)
		_bouton("Recommencer depuis le début", func():
			GameState.effacer_point_de_controle()
			_relancer())
	else:
		_bouton("Recommencer", func(): _relancer(), true)
	_bouton("Retour au titre", func():
		GameState.set_phase(GameState.Phase.TITRE, true)
		get_tree().reload_current_scene())


func _ecran_victoire() -> void:
	var t := GameState.time_survived
	var record := GameState.enregistrer_temps(t)
	_texte("VOUS ÊTES SORTI", 44, OR)
	_espace(6)
	_texte("Le monte-charge remonte. Derrière vous, le bâtiment se tait.", 15, GRIS)
	_espace(10)
	if record:
		_texte("★  MEILLEUR TEMPS EN %s" % Settings.nom_difficulte().to_upper(), 15, OR)
	_releve()
	_espace(14)
	_bouton("Rejouer", func(): _relancer(), true)
	_bouton("Retour au titre", func():
		GameState.set_phase(GameState.Phase.TITRE, true)
		get_tree().reload_current_scene())


## Relevé de partie, commun à la mort et à la victoire.
func _releve() -> void:
	var s := GameState.stats
	var lignes := [
		["Temps", _mmss(GameState.time_survived)],
		["Difficulté", Settings.nom_difficulte()],
		["Fusibles posés", "%d / %d" % [GameState.fuses_installed, GameState.FUSES_REQUIRED]],
		["Distance parcourue", "%d m" % int(s.get("distance", 0.0))],
		["Fois où elle vous a entendu", "%d" % int(s.get("detections", 0.0))],
		["Traques déclenchées", "%d" % int(s.get("chasses", 0.0))],
		["Fois caché dans un casier", "%d" % int(s.get("cachettes", 0.0))],
		["Halètements", "%d" % int(s.get("haletements", 0.0))],
	]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 3)
	for l in lignes:
		var a := Label.new()
		a.text = l[0]
		a.add_theme_font_size_override("font_size", 14)
		a.add_theme_color_override("font_color", SOURD)
		a.custom_minimum_size = Vector2(300, 0)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(a)
		var b := Label.new()
		b.text = str(l[1])
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", GRIS)
		g.add_child(b)
	_boite.add_child(g)


# ==========================================================================
func _relancer() -> void:
	GameState.set_phase(GameState.Phase.TITRE, true)
	get_tree().reload_current_scene()
	await get_tree().process_frame
	GameState.set_phase(GameState.Phase.JEU)


func _mmss(t: float) -> String:
	return "%d min %02d s" % [int(t) / 60, int(t) % 60]


func _unhandled_input(e: InputEvent) -> void:
	if _ecran == Ecran.OPTIONS and e.is_action_pressed("pause"):
		_afficher(_retour)
		get_viewport().set_input_as_handled()
