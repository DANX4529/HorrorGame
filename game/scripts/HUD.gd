extends CanvasLayer
## Interface et post-traitement.
##
## Le HUD est volontairement minimal : une jauge de souffle, un objectif,
## une invite d'interaction. Tout le reste de l'information passe par le son
## et par l'image (vignettage, désaturation, battement).

var player: Player
var _mat: ShaderMaterial
var _rect: ColorRect
var _ui: Control
var _breath_bg: ColorRect
var _breath_fill: ColorRect
var _breath_lbl: Label
var _obj_lbl: Label
var _bat_lbl: Label
var _prompt: Label
var _msg: Label
var _msg_t := 0.0
var _slats: Control
var _t := 0.0
var _dark := 0.0
var _bruit := 0.0            ## impulsion de bruit en cours, 0..1
var _menace := Vector2.ZERO  ## direction écran de la Veilleuse
var _menace_f := 0.0         ## force du signal de menace, 0..1
var _feuille: Control        ## panneau de lecture d'un document


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_post()
	_build_ui()
	# Aucun élément d'interface ne doit intercepter la souris : sinon il mange
	# les mouvements destinés à la vue. Les Control sont en MOUSE_FILTER_STOP
	# par défaut, y compris le réticule placé au centre exact de l'écran.
	_ignore_mouse(self)
	_build_feuille()
	Tactile.mode_change.connect(func(_a): _placer_souffle())
	NoiseBus.noise.connect(_on_noise)
	GameState.document_ouvert.connect(_on_document)
	GameState.message.connect(_on_message)
	GameState.phase_changed.connect(_on_phase)
	GameState.fuses_changed.connect(func(_a, _b): _refresh_objective())
	# On se cale sur l'état courant plutôt que d'attendre un signal : au
	# démarrage la phase est déjà TITRE, donc aucun changement n'est émis.
	_on_phase(GameState.phase)


## Coupe le post-traitement (outil de vérification de la géométrie).
func disable_post() -> void:
	if _rect:
		_rect.visible = false


func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)


func bind(p: Player) -> void:
	player = p
	p.hide_changed.connect(func(h): _slats.visible = h)
	p.died.connect(_on_died)
	_refresh_objective()


# --------------------------------------------------------------------------
func _build_post() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/postprocess.gdshader")
	_rect.material = _mat
	cl.add_child(_rect)


func _lbl(parent: Control, txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 3)
	parent.add_child(l)
	return l


func _build_ui() -> void:
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	# --- jauge de souffle, en bas au centre ---
	_breath_bg = ColorRect.new()
	_breath_bg.color = Color(0.05, 0.05, 0.06, 0.72)
	_placer_souffle()
	_ui.add_child(_breath_bg)

	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.82, 0.84, 0.80, 0.92)
	_breath_fill.position = Vector2(1, 1)
	_breath_fill.size = Vector2(338, 7)
	_breath_bg.add_child(_breath_fill)

	_breath_lbl = _lbl(_ui, "", 15, Color(0.92, 0.88, 0.78))
	_placer_souffle()
	_breath_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- objectif, en haut à gauche ---
	_obj_lbl = _lbl(_ui, "", 15, Color(0.80, 0.82, 0.76))
	_obj_lbl.position = Vector2(22, 18)

	_bat_lbl = _lbl(_ui, "", 14, Color(0.70, 0.73, 0.68))
	_bat_lbl.position = Vector2(22, 40)

	# --- invite d'interaction, au centre ---
	_prompt = _lbl(_ui, "", 16, Color(0.95, 0.93, 0.85))
	_prompt.set_anchors_preset(Control.PRESET_CENTER, false)
	_prompt.offset_left = -220; _prompt.offset_right = 220
	_prompt.offset_top = 30; _prompt.offset_bottom = 56
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# réticule discret
	var dot := ColorRect.new()
	dot.color = Color(0.9, 0.9, 0.88, 0.30)
	dot.set_anchors_preset(Control.PRESET_CENTER, false)
	dot.offset_left = -1.5; dot.offset_right = 1.5
	dot.offset_top = -1.5; dot.offset_bottom = 1.5
	_ui.add_child(dot)

	# --- message narratif, en bas ---
	_msg = _lbl(_ui, "", 17, Color(0.90, 0.86, 0.74))
	_msg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
	_msg.offset_left = -330; _msg.offset_right = 330
	_msg.offset_top = -150; _msg.offset_bottom = -86
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# --- ouïes du casier ---
	_slats = Control.new()
	_slats.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slats.visible = false
	_ui.add_child(_slats)
	for i in 9:
		var band := ColorRect.new()
		band.color = Color(0, 0, 0, 0.97)
		band.set_anchors_preset(Control.PRESET_TOP_WIDE, false)
		band.offset_top = i * 64.0
		band.offset_bottom = i * 64.0 + 46.0
		_slats.add_child(band)
	for s in [-1, 1]:
		var side := ColorRect.new()
		side.color = Color(0, 0, 0, 1.0)
		side.set_anchors_preset(Control.PRESET_LEFT_WIDE if s < 0 else Control.PRESET_RIGHT_WIDE, false)
		if s < 0:
			side.offset_right = 160
		else:
			side.offset_left = -160
		_slats.add_child(side)


# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	# l'impulsion de bruit retombe vite : c'est un événement, pas un état.
	# Assez lentement toutefois pour qu'un pas de course reste perceptible
	# entre deux foulées (0.34 s à l'allure de course).
	_bruit = maxf(0.0, _bruit - delta * 3.4)
	_update_menace(delta)
	_update_post(delta)
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t, 0.0, 1.0)
		if _msg_t <= 0.0:
			_msg.text = ""
	if GameState.phase == GameState.Phase.JEU and player:
		_update_gameplay_ui()


func _update_post(delta: float) -> void:
	if _mat == null:
		return
	var peur := 0.0
	var souffle := 1.0
	if player:
		peur = player.breath.heart
		souffle = player.breath.breath
	var target_dark := 0.0
	if GameState.phase == GameState.Phase.MORT:
		target_dark = 0.55
	_dark = lerpf(_dark, target_dark, delta * 1.6)
	_mat.set_shader_parameter("t", _t)
	_mat.set_shader_parameter("peur", peur)
	_mat.set_shader_parameter("souffle", souffle)
	_mat.set_shader_parameter("noirceur", _dark)
	_mat.set_shader_parameter("gamma", Settings.gamma())
	_mat.set_shader_parameter("bruit", _bruit)
	_mat.set_shader_parameter("menace", _menace)
	_mat.set_shader_parameter("menace_force", _menace_f)


func _update_gameplay_ui() -> void:
	var b := player.breath
	_breath_fill.size.x = maxf(0.0, 338.0 * b.breath)
	var col := Color(0.82, 0.84, 0.80, 0.92)
	match b.state:
		BreathSystem.State.APNEE:
			col = Color(0.45, 0.66, 0.88, 0.95)
		BreathSystem.State.ESSOUFFLE:
			col = Color(0.90, 0.62, 0.26, 0.95)
		BreathSystem.State.HALETEMENT:
			col = Color(0.88, 0.24, 0.20, 1.0)
	_breath_fill.color = col

	var txt := b.label()
	if txt == "" and b.can_hold():
		# en tactile, le bouton EST l'invite : la répéter en texte n'apprendrait
		# rien et mangerait de la place
		txt = "" if Tactile.actif else "[Ctrl] retenir son souffle"
	elif not b.can_hold() and b.state != BreathSystem.State.HALETEMENT:
		txt = "impossible de retenir  (%.1f s)" % b.hold_lock
	_breath_lbl.text = txt

	_bat_lbl.text = "Lampe  %s  %d s" % ["●" if player.torch_on else "○", int(player.battery)]

	var tgt := player.current_target()
	if player.is_hidden:
		_prompt.text = Tactile.libelle("[E] Sortir", "AGIR  ▸  Sortir")
	elif tgt != null and tgt.has_method("prompt"):
		_prompt.text = Tactile.libelle("[E]  ", "AGIR  ▸  ") + tgt.prompt()
	else:
		_prompt.text = ""


func _refresh_objective() -> void:
	var held := GameState.fuses_held
	var inst := GameState.fuses_installed
	if GameState.power_restored:
		_obj_lbl.text = "OBJECTIF  ▸  Rejoindre le monte-charge"
	else:
		_obj_lbl.text = "OBJECTIF  ▸  %s  %d/%d posés   (en main : %d)" % [
				GameState.objectif_panneau, inst, GameState.objectif_nombre, held]


func _on_message(txt: String, secs: float) -> void:
	_msg.text = txt
	_msg_t = secs
	_msg.modulate.a = 1.0


func _on_died() -> void:
	GameState.set_phase(GameState.Phase.MORT)


func _on_phase(p: int) -> void:
	_ui.visible = (p == GameState.Phase.JEU)
	if _feuille:
		_feuille.visible = (p == GameState.Phase.LECTURE)


# --------------------------------------------------------------------------
#  Lisibilité de la traque
# --------------------------------------------------------------------------
## Un bruit vient d'être émis quelque part : est-ce le joueur qui l'a fait ?
##
## On n'écoute pas le joueur directement mais le bus sonore, pour une raison
## de fond : le joueur doit voir EXACTEMENT ce que la Veilleuse entend. Une
## porte qu'il pousse, un casier qu'il referme, un fusible qu'il enfonce le
## trahissent autant que ses pas, et tout cela passe déjà par ici.
##
## La respiration est écartée : elle est émise à chaque image, elle ferait une
## impulsion permanente donc illisible. C'est la jauge de souffle qui la porte.
func _on_noise(pos: Vector3, radius: float, kind: String) -> void:
	if kind == "souffle" or player == null:
		return
	if pos.distance_to(player.global_position) > 2.5:
		return          # un bruit lointain n'est pas le sien
	_bruit = maxf(_bruit, NoiseBus.portee(radius))


## Où est-elle, vue de l'écran ? -1 à gauche, +1 à droite.
func _update_menace(delta: float) -> void:
	var cible := 0.0
	var v := get_tree().get_first_node_in_group("veilleuse")
	if v and player and GameState.phase == GameState.Phase.JEU \
			and v.has_method("is_hunting") and v.is_hunting():
		var d := player.global_position.distance_to(v.global_position)
		# le signal ne sert qu'à courte portée : au-delà, l'audio positionnel
		# suffit et une indication permanente tuerait le doute.
		cible = clampf(inverse_lerp(26.0, 6.0, d), 0.0, 1.0)
		var local: Vector3 = player.cam.global_transform.basis.inverse() \
				* (v.global_position - player.global_position)
		var dir := Vector2(local.x, -local.y)
		# derrière soi : l'ombre se referme des deux côtés, et c'est pire
		if local.z > 0.0:
			dir = Vector2(signf(local.x if absf(local.x) > 0.01 else 1.0), 0.0)
			cible *= 1.15
		_menace = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
	_menace_f = move_toward(_menace_f, clampf(cible, 0.0, 1.0), delta * (2.2 if cible > _menace_f else 1.1))


# --------------------------------------------------------------------------
#  Lecture d'un document
# --------------------------------------------------------------------------
## Construit la feuille de lecture.
##
## Rendue comme une page posée devant soi, pas comme une boîte de dialogue :
## fond papier, texte à chasse fixe, marges larges. Le reste de l'écran est
## noirci sans l'être tout à fait — on doit continuer à sentir la pièce autour.
func _build_feuille() -> void:
	_feuille = Control.new()
	_feuille.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feuille.visible = false
	_feuille.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_feuille)

	var voile := ColorRect.new()
	voile.color = Color(0.0, 0.0, 0.0, 0.82)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feuille.add_child(voile)

	# La page se dimensionne sur son contenu : à hauteur fixe, un document
	# court laissait une grande moitié de papier vide sous le texte.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feuille.add_child(centre)

	var page := PanelContainer.new()
	page.custom_minimum_size = Vector2(660, 0)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.847, 0.816, 0.741)          # papier jauni
	st.border_color = Color(0.36, 0.33, 0.28)
	st.set_border_width_all(1)
	st.content_margin_left = 46; st.content_margin_right = 46
	st.content_margin_top = 34; st.content_margin_bottom = 30
	page.add_theme_stylebox_override("panel", st)
	centre.add_child(page)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	page.add_child(col)

	var titre := Label.new()
	titre.name = "Titre"
	titre.add_theme_font_size_override("font_size", 19)
	titre.add_theme_color_override("font_color", Color(0.16, 0.13, 0.10))
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(titre)

	var filet := ColorRect.new()
	filet.color = Color(0.36, 0.33, 0.28, 0.55)
	filet.custom_minimum_size = Vector2(0, 1)
	col.add_child(filet)

	var corps := Label.new()
	corps.name = "Corps"
	corps.add_theme_font_size_override("font_size", 16)
	corps.add_theme_color_override("font_color", Color(0.19, 0.16, 0.13))
	corps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(corps)

	var ecart := Control.new()
	ecart.custom_minimum_size = Vector2(0, 10)
	col.add_child(ecart)

	var pied := Label.new()
	pied.name = "Pied"
	pied.add_theme_font_size_override("font_size", 13)
	pied.add_theme_color_override("font_color", Color(0.40, 0.36, 0.30))
	pied.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(pied)

	_ignore_mouse(_feuille)


func _on_document(id: String) -> void:
	var d: Dictionary = Lore.doc(id)
	if d.is_empty() or _feuille == null:
		return
	var page := _feuille.get_child(1).get_child(0)
	var col := page.get_child(0)
	(col.get_node("Titre") as Label).text = str(d.get("titre", ""))
	(col.get_node("Corps") as Label).text = str(d.get("texte", ""))
	# Le « % » lie plus fort que le « + » : écrite en concaténation, la mise en
	# forme s'appliquait au libellé de fermeture — qui n'a aucun marqueur — et
	# non à la phrase. Résultat à chaque ouverture : une erreur d'exécution
	# « not all arguments converted », et un pied de page affichant « %s · %d /
	# %d documents » en toutes lettres. Une seule chaîne, un seul %.
	(col.get_node("Pied") as Label).text = "%s  ·  %d / %d documents  ·  %s" % [
			Lore.CHAPITRES.get(int(d.get("chap", 1)), ""),
			GameState.documents_trouves(), Lore.total(),
			Tactile.libelle("[E] refermer", "toucher pour refermer")]


## Place la jauge de souffle selon le mode d'entrée.
##
## En tactile elle remonte en haut : le bas de l'écran appartient aux pouces et
## les boutons la recouvraient. Recalculée à chaque changement de mode, parce
## qu'un appareil hybride peut basculer en pleine partie — la disposer une
## seule fois au démarrage laissait la jauge sous les boutons.
func _placer_souffle() -> void:
	if _breath_bg == null:
		return
	if Tactile.actif:
		_breath_bg.set_anchors_preset(Control.PRESET_CENTER_TOP, false)
		_breath_bg.offset_top = 30; _breath_bg.offset_bottom = 39
		if _breath_lbl:
			_breath_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP, false)
			_breath_lbl.offset_top = 46; _breath_lbl.offset_bottom = 68
	else:
		_breath_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
		_breath_bg.offset_top = -64; _breath_bg.offset_bottom = -55
		if _breath_lbl:
			_breath_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
			_breath_lbl.offset_top = -90; _breath_lbl.offset_bottom = -68
	_breath_bg.offset_left = -170; _breath_bg.offset_right = 170
	if _breath_lbl:
		_breath_lbl.offset_left = -170; _breath_lbl.offset_right = 170
