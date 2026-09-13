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
var _center: Control
var _big: Label
var _sub: Label
var _slats: Control
var _t := 0.0
var _dark := 0.0


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_post()
	_build_ui()
	GameState.message.connect(_on_message)
	GameState.phase_changed.connect(_on_phase)
	GameState.fuses_changed.connect(func(_a, _b): _refresh_objective())
	# On se cale sur l'état courant plutôt que d'attendre un signal : au
	# démarrage la phase est déjà TITRE, donc aucun changement n'est émis.
	_on_phase(GameState.phase)


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
	_breath_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
	_breath_bg.offset_left = -170; _breath_bg.offset_right = 170
	_breath_bg.offset_top = -64; _breath_bg.offset_bottom = -55
	_ui.add_child(_breath_bg)

	_breath_fill = ColorRect.new()
	_breath_fill.color = Color(0.82, 0.84, 0.80, 0.92)
	_breath_fill.position = Vector2(1, 1)
	_breath_fill.size = Vector2(338, 7)
	_breath_bg.add_child(_breath_fill)

	_breath_lbl = _lbl(_ui, "", 15, Color(0.92, 0.88, 0.78))
	_breath_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, false)
	_breath_lbl.offset_left = -170; _breath_lbl.offset_right = 170
	_breath_lbl.offset_top = -90; _breath_lbl.offset_bottom = -68
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

	# --- écrans pleins (titre / mort / victoire / pause) ---
	_center = Control.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.80)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.add_child(veil)
	_big = _lbl(_center, "", 54, Color(0.88, 0.85, 0.78))
	_big.set_anchors_preset(Control.PRESET_CENTER, false)
	_big.offset_left = -480; _big.offset_right = 480
	_big.offset_top = -120; _big.offset_bottom = -46
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub = _lbl(_center, "", 17, Color(0.74, 0.76, 0.70))
	_sub.set_anchors_preset(Control.PRESET_CENTER, false)
	_sub.offset_left = -430; _sub.offset_right = 430
	_sub.offset_top = -28; _sub.offset_bottom = 200
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.visible = false


# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	_update_post(delta)
	if _msg_t > 0.0:
		_msg_t -= delta
		_msg.modulate.a = clampf(_msg_t, 0.0, 1.0)
		if _msg_t <= 0.0:
			_msg.text = ""
	if GameState.phase == GameState.Phase.JEU and player:
		_update_gameplay_ui()
	if GameState.phase in [GameState.Phase.TITRE, GameState.Phase.MORT, GameState.Phase.VICTOIRE]:
		if Input.is_anything_pressed():
			_advance_screen()


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
		txt = "[Ctrl] retenir son souffle"
	elif not b.can_hold() and b.state != BreathSystem.State.HALETEMENT:
		txt = "impossible de retenir  (%.1f s)" % b.hold_lock
	_breath_lbl.text = txt

	_bat_lbl.text = "Lampe  %s  %d s" % ["●" if player.torch_on else "○", int(player.battery)]

	var tgt := player.current_target()
	if player.is_hidden:
		_prompt.text = "[E] Sortir"
	elif tgt != null and tgt.has_method("prompt"):
		_prompt.text = "[E]  " + tgt.prompt()
	else:
		_prompt.text = ""


func _refresh_objective() -> void:
	var held := GameState.fuses_held
	var inst := GameState.fuses_installed
	if GameState.power_restored:
		_obj_lbl.text = "OBJECTIF  ▸  Rejoindre le monte-charge"
	else:
		_obj_lbl.text = "OBJECTIF  ▸  Fusibles  %d/%d posés   (en main : %d)" % [
				inst, GameState.FUSES_REQUIRED, held]


func _on_message(txt: String, secs: float) -> void:
	_msg.text = txt
	_msg_t = secs
	_msg.modulate.a = 1.0


func _on_died() -> void:
	GameState.set_phase(GameState.Phase.MORT)


func _on_phase(p: int) -> void:
	_ui.visible = (p == GameState.Phase.JEU)
	match p:
		GameState.Phase.TITRE:
			_show("RESPIRE",
				"Sanatorium du Mont-Cendre — 1961\n\n" +
				"Quelque chose arpente les couloirs. C'est aveugle.\n" +
				"Ça chasse au son.\n\n" +
				"Et le bruit le plus fort dans un bâtiment vide,\n" +
				"c'est votre propre respiration.\n\n" +
				"ZQSD / WASD  déplacement      Maj  courir      C  s'accroupir\n" +
				"Ctrl  RETENIR SON SOUFFLE      E  interagir      F  lampe\n\n" +
				"— une touche pour descendre —")
		GameState.Phase.MORT:
			_show("ELLE VOUS A TROUVÉ",
				"Vous avez tenu %d secondes.\n\n— une touche pour recommencer —"
						% int(GameState.time_survived))
		GameState.Phase.VICTOIRE:
			_show("VOUS ÊTES SORTI",
				"Le monte-charge remonte.\n\nTemps : %d s\n\n— une touche pour rejouer —"
						% int(GameState.time_survived))
		GameState.Phase.PAUSE:
			_show("PAUSE", "— Échap pour reprendre —")
		_:
			_center.visible = false


func _show(big: String, sub: String) -> void:
	_big.text = big
	_sub.text = sub
	_center.visible = true


func _advance_screen() -> void:
	match GameState.phase:
		GameState.Phase.TITRE:
			GameState.set_phase(GameState.Phase.JEU)
		GameState.Phase.MORT, GameState.Phase.VICTOIRE:
			GameState.reset_run()
			GameState.set_phase(GameState.Phase.TITRE)
			get_tree().reload_current_scene()
