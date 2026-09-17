extends CanvasLayer
## Écrans pleins : titre, options, pause, mort, victoire.
##
## Séparés du HUD, qui ne garde que l'affichage en cours de partie et le
## post-traitement. Tout est construit par code, comme le reste du projet.

enum Ecran { AUCUN, TITRE, OPTIONS, PAUSE, MORT, VICTOIRE, JOURNAL, DOSSIER, CREDITS,
		CABINE }

const OR := Color(0.87, 0.83, 0.74)
const GRIS := Color(0.70, 0.72, 0.67)
const SOURD := Color(0.48, 0.50, 0.46)

var _voile: ColorRect
var _boite: VBoxContainer
var _ecran: Ecran = Ecran.AUCUN
var _retour: Ecran = Ecran.TITRE
var _joueur: Player
var _defilement: ScrollContainer
var _principal: Button      ## bouton qui reçoit le focus à l'ouverture de l'écran


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

	# Le menu défile. Sans cela, le journal — qui s'allonge à chaque chapitre
	# ajouté — poussait son bouton « Retour » hors de l'écran, et un écran
	# devenait inatteignable au fur et à mesure qu'on enrichissait le récit.
	_defilement = ScrollContainer.new()
	_defilement.set_anchors_preset(Control.PRESET_FULL_RECT)
	_defilement.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defilement.follow_focus = true
	racine.add_child(_defilement)

	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_defilement.add_child(centre)

	_boite = VBoxContainer.new()
	_boite.add_theme_constant_override("separation", 10)
	_boite.custom_minimum_size = Vector2(620, 0)
	centre.add_child(_boite)


# ==========================================================================
#  Briques d'interface
# ==========================================================================
func _vider() -> void:
	_principal = null
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


## Désigne le bouton qui prendra le focus : celui sur lequel Entrée doit agir.
##
## Explicite, et non déduit de « premier bouton accentué » : sur l'écran-titre
## le premier accentué est le sélecteur de difficulté, si bien qu'Entrée
## changeait la difficulté au lieu de lancer la partie.
func _focus(b: Button) -> Button:
	_principal = b
	return b


func _espace(h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	_boite.add_child(c)


func _bouton(t: String, appui: Callable, accent := false) -> Button:
	var b := Button.new()
	b.text = t
	# Au doigt, un bouton de 38 px se rate : les repères d'accessibilité
	# tournent autour de 44 px, on prend 54 pour un jeu où l'on est pressé.
	b.custom_minimum_size = Vector2(0, Tactile.hauteur_bouton())
	b.add_theme_font_size_override("font_size", Tactile.taille_police(17))
	b.add_theme_color_override("font_color", OR if accent else GRIS)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.90))
	b.add_theme_color_override("font_focus_color", Color(1, 0.97, 0.90))
	b.flat = true
	b.pressed.connect(func():
		Audio.play_2d("ui_select", -14.0)
		appui.call())
	b.mouse_entered.connect(func(): Audio.play_2d("ui_move", -24.0))
	_boite.add_child(b)
	# Le bouton principal prend le focus : on peut alors traverser tout le menu
	# au clavier (flèches puis Entrée) sans jamais toucher la souris. Sans cela
	# aucun élément n'était focalisable et la navigation clavier n'existait pas.

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
		GameState.Phase.CABINE:  _afficher(Ecran.CABINE)
		_:                       _afficher(Ecran.AUCUN)


func _afficher(e: Ecran) -> void:
	_ecran = e
	_vider()
	if _defilement:
		_defilement.scroll_vertical = 0
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
		Ecran.JOURNAL:  _ecran_journal()
		Ecran.DOSSIER:  _ecran_dossier()
		Ecran.CREDITS:  _ecran_credits()
		Ecran.CABINE:   _ecran_cabine()
	# Le focus se prend une fois l'écran entièrement construit : on peut alors
	# traverser tout le menu au clavier (flèches puis Entrée) sans souris.
	# Appel direct, pas différé : les boutons sont déjà dans l'arbre ici, alors
	# qu'un appel différé s'exécutait après un éventuel changement d'écran, sur
	# un bouton déjà libéré.
	if _principal and _principal.is_inside_tree():
		_principal.grab_focus()


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
		_focus(_bouton("Reprendre la descente", func():
			GameState.reprendre()
			_relancer(false), true))
		_bouton("Recommencer depuis le début", func(): _relancer())
	else:
		_focus(_bouton("Descendre", func(): _relancer(), true))
	_bouton("Ce qu'on a retrouvé   (%d/%d)"
			% [GameState.documents_trouves(), Lore.total()], func():
		_retour = Ecran.TITRE
		_afficher(Ecran.JOURNAL))
	_bouton("Crédits", func():
		_retour = Ecran.TITRE
		_afficher(Ecran.CREDITS))
	_bouton("Options", func():
		_retour = Ecran.TITRE
		_afficher(Ecran.OPTIONS))
	if not OS.has_feature("web"):
		_bouton("Quitter", func(): get_tree().quit())

	_espace(12)
	var mt := GameState.meilleur_temps()
	if mt > 0.0:
		_texte("Meilleur temps en %s : %s" % [Settings.nom_difficulte(), _mmss(mt)], 13, SOURD)
	_texte(Tactile.libelle(
			"ZQSD / WASD  se déplacer      Maj  courir      C  s'accroupir\n"
			+ "Ctrl  RETENIR SON SOUFFLE      E  interagir      F  lampe      Échap  pause",
			"Manche à gauche  se déplacer  ·  pousser à fond  courir\n"
			+ "Glisser à droite  regarder  ·  BAISSÉ  s'accroupir\n"
			+ "SOUFFLE  retenir son souffle  ·  AGIR  interagir  ·  II  pause"),
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
	_focus(_bouton("Retour", func(): _afficher(_retour), true))


func _ecran_pause() -> void:
	_texte("PAUSE", 40, OR)
	_espace(16)
	_focus(_bouton("Reprendre", func(): GameState.set_phase(GameState.Phase.JEU), true))
	_bouton("Options", func():
		_retour = Ecran.PAUSE
		_afficher(Ecran.OPTIONS))
	_bouton("Ce qu'on a retrouvé   (%d/%d)"
			% [GameState.documents_trouves(), Lore.total()], func():
		_retour = Ecran.PAUSE
		_afficher(Ecran.JOURNAL))
	_bouton("Recommencer la partie", func(): _relancer())
	_bouton("Retour au titre", func(): _retour_titre())
	_espace(12)
	_texte("Difficulté : %s     ·     Descente n° %d"
			% [Settings.nom_difficulte(), GameState.graine], 13, SOURD)


func _ecran_mort() -> void:
	_texte("ELLE VOUS A TROUVÉ", 44, Color(0.78, 0.26, 0.22))
	_espace(10)
	# Dire ce qu'on vient de perdre, nommément. Une règle qui coûte sans
	# jamais s'énoncer se lit comme un bug, pas comme un enjeu.
	var perdus := GameState.documents_en_cours()
	if perdus > 0:
		_texte("%d document%s que vous n'avez pas remonté%s."
				% [perdus, "s" if perdus > 1 else "", "s" if perdus > 1 else ""],
				16, Color(0.78, 0.26, 0.22))
		_texte("Ils sont restés en bas.", 14, SOURD)
		_espace(8)
	_releve()
	_espace(14)
	if GameState.a_un_point_de_controle():
		_focus(_bouton("Reprendre au tableau électrique", func():
			GameState.reprendre()
			_relancer(false), true))
		_bouton("Recommencer l'étage", func(): _refaire_etage())
	else:
		# Même graine : on refait CE plan-ci. Ce qu'on a appris du bâtiment en
		# mourant sert encore, ce qui est toute la différence entre réessayer
		# et repartir de zéro.
		_focus(_bouton("Recommencer l'étage", func(): _refaire_etage(), true))
	_bouton("Retour au titre", func(): _retour_titre())


## Refait l'étage courant à l'identique. Le butin est déjà perdu : reset_run()
## vide documents_en_main à chaque reconstruction du monde.
func _refaire_etage() -> void:
	GameState.effacer_point_de_controle()
	GameState.montrer_prologue = false
	_relancer(false)


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
	_focus(_bouton("Rejouer", func(): _relancer(), true))
	_bouton("Retour au titre", func(): _retour_titre())


## La cabine du monte-charge : le seul endroit où le butin devient acquis.
##
## L'écran existe pour rendre la règle VISIBLE. Le joueur doit voir, noir sur
## blanc, que ce qu'il portait vient d'être mis à l'abri — sinon « perdre ce
## qu'on n'a pas remonté » n'est qu'une punition arbitraire découverte trop
## tard. C'est aussi le seul temps mort de la descente : la seule respiration.
func _ecran_cabine() -> void:
	var def := GameState.etage_def()
	var dessous := Etages.etage(Etages.suivant(GameState.etage_courant))
	_texte("LE MONTE-CHARGE DESCEND", 34, OR)
	_espace(8)
	_texte("Niveau %d   —   %s" % [GameState.etage_courant,
			str(def.get("titre", ""))], 15, SOURD)
	_espace(14)

	var butin := GameState.butin_remonte
	if butin > 0:
		_texte("%d document%s mis à l'abri" % [butin, "s" if butin > 1 else ""],
				17, OR)
	else:
		_texte("Vous remontez les mains vides.", 15, GRIS)
	_texte("Archive : %d sur %d" % [GameState.documents_acquis(), Lore.total()],
			14, SOURD)
	_espace(16)

	if dessous.is_empty():
		_texte("Il n'y a plus rien en dessous.", 15, GRIS)
		_espace(12)
		_focus(_bouton("Remonter", func():
			GameState.set_phase(GameState.Phase.VICTOIRE), true))
		return

	_texte("Niveau %d   —   %s" % [int(dessous["niveau"]),
			str(dessous.get("titre", ""))], 19, OR)
	_espace(6)
	_texte("Plus bas, elle entend mieux.", 14, SOURD)
	_espace(14)
	_focus(_bouton(Tactile.libelle("Descendre", "Descendre"), func():
		_descendre(), true))
	_bouton("Retour au titre", func(): _retour_titre())


func _descendre() -> void:
	if not GameState.descendre_etage():
		GameState.set_phase(GameState.Phase.VICTOIRE)
		return
	# Même protocole que _relancer() : rien ne s'exécute après un rechargement
	# de scène, donc l'intention transite par l'autoload et Main la consomme.
	GameState.demarrer_en_jeu = true
	get_tree().paused = false
	get_tree().reload_current_scene()


## Relevé de partie, commun à la mort et à la victoire.
func _releve() -> void:
	var s := GameState.stats
	var lignes := [
		["Temps", _mmss(GameState.time_survived)],
		["Difficulté", Settings.nom_difficulte()],
		[GameState.objectif_panneau, "%d / %d" % [GameState.fuses_installed,
				GameState.objectif_nombre]],
		["Distance parcourue", "%d m" % int(s.get("distance", 0.0))],
		["Fois où elle vous a entendu", "%d" % int(s.get("detections", 0.0))],
		["Traques déclenchées", "%d" % int(s.get("chasses", 0.0))],
		["Fois caché dans un casier", "%d" % int(s.get("cachettes", 0.0))],
		["Halètements", "%d" % int(s.get("haletements", 0.0))],
		["Documents retrouvés", "%d / %d" % [GameState.documents_trouves(), Lore.total()]],
		# Chaque descente est tirée au sort : afficher sa graine permet de dire
		# « celle-là était bonne », et de rejouer exactement le même sous-sol.
		["Descente n°", str(GameState.graine)],
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


## Crédits, construits depuis Lore.CREDITS : une section ajoutée s'affiche
## toute seule, et l'écran défile déjà.
func _ecran_credits() -> void:
	var premier := true
	for section in Lore.CREDITS:
		var titre := str(section[0])
		if titre != "":
			_espace(12)
			_texte(titre, 15, OR)
		for ligne in section[1]:
			var l := str(ligne)
			if premier:
				# la première ligne du premier bloc est le titre du jeu
				_texte(l, 42, OR)
				premier = false
				continue
			# les lignes indentées sont des précisions : plus petites, plus mates
			var indente: bool = l.begins_with("   ")
			_texte(l.strip_edges() if indente else l,
					13 if indente else 15, SOURD if indente else GRIS)
	_espace(18)
	_focus(_bouton("Retour", func(): _afficher(_retour), true))


## Journal : ce que le joueur a retrouvé de l'histoire, chapitre par chapitre.
##
## Se construit depuis Lore : une mise à jour qui ajoute un chapitre le fait
## apparaître ici toute seule, avec son compte, et les découvertes déjà faites
## restent acquises. C'est ce qui donne au joueur une raison de redescendre.
func _ecran_journal() -> void:
	_texte("CE QU'ON A RETROUVÉ", 34, OR)
	_texte("%d documents sur %d" % [GameState.documents_acquis(), Lore.total()],
			14, SOURD)
	var en_main := GameState.documents_en_cours()
	if en_main > 0:
		# Dire ce qu'on risque, et le dire AVANT de mourir. Une règle punitive
		# qu'on découvre après coup n'est pas de la tension.
		_texte("%d en main — perdu%s si vous ne remontez pas"
				% [en_main, "s" if en_main > 1 else ""], 14, OR)
	_espace(12)

	for n in Lore.chapitres():
		var docs: Array = Lore.du_chapitre(n)
		var lus := 0
		for d in docs:
			if GameState.a_acquis(str(d["id"])):
				lus += 1
		_espace(8)
		_texte("%s   —   %d/%d" % [Lore.CHAPITRES[n], lus, docs.size()],
				17, OR if lus > 0 else SOURD)
		for d in docs:
			var id := str(d["id"])
			if GameState.a_acquis(id):
				_bouton("   " + str(d["titre"]), func(): _ouvrir_dossier(id))
			elif GameState.documents_en_main.has(id):
				# lu, mais pas encore ressorti avec : lisible, et marqué
				_bouton("   %s   (en main)" % str(d["titre"]),
						func(): _ouvrir_dossier(id))
			else:
				# une entrée jamais trouvée reste visible mais muette : le joueur
				# sait qu'il lui manque quelque chose, sans savoir quoi
				_texte("   ·  ·  ·", 15, SOURD)

	_espace(16)
	_focus(_bouton("Retour", func(): _afficher(_retour), true))


var _dossier := ""


func _ouvrir_dossier(id: String) -> void:
	_dossier = id
	_afficher(Ecran.DOSSIER)


## Relecture d'un document depuis le journal.
func _ecran_dossier() -> void:
	var d: Dictionary = Lore.doc(_dossier)
	_texte(str(d.get("titre", "")), 24, OR)
	_texte(Lore.CHAPITRES.get(int(d.get("chap", 1)), ""), 13, SOURD)
	_espace(14)
	var corps := _texte(str(d.get("texte", "")), 15, GRIS, 5)
	corps.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_espace(16)
	_focus(_bouton("Retour", func(): _afficher(Ecran.JOURNAL), true))


# ==========================================================================
func _retour_titre() -> void:
	GameState.demarrer_en_jeu = false
	GameState.set_phase(GameState.Phase.TITRE, true)
	get_tree().reload_current_scene()


## Reconstruit le monde et enchaîne sur la partie.
##
## On ne peut RIEN faire après reload_current_scene() : ce noeud est détruit
## par le rechargement. L'intention est donc posée dans GameState, que Main
## relit à la fin de sa construction.
func _relancer(nouvelle := true) -> void:
	# Toute relance qui n'est pas une reprise ouvre une NOUVELLE campagne :
	# on repart de l'étage le plus haut, avec une autre graine. Une reprise,
	# elle, doit retrouver son plan intact — d'où le paramètre plutôt qu'un
	# tirage implicite.
	if nouvelle:
		GameState.nouvelle_campagne()
	GameState.demarrer_en_jeu = true
	GameState.set_phase(GameState.Phase.TITRE, true)
	get_tree().reload_current_scene()


func _mmss(t: float) -> String:
	return "%d min %02d s" % [int(t) / 60, int(t) % 60]


func _unhandled_input(e: InputEvent) -> void:
	if _ecran == Ecran.OPTIONS and e.is_action_pressed("pause"):
		_afficher(_retour)
		get_viewport().set_input_as_handled()
