extends Node3D
## Point d'entrée : assemble le monde, le joueur, la Veilleuse et l'interface.
##
## Tout est construit par code ; les .tscn se réduisent à un noeud racine.
## La géométrie du sanatorium est générée depuis une grille textuelle
## (voir LevelBuilder), pas placée à la main.

var level: Node3D
var player: Player
var veilleuse: Veilleuse
var hud: CanvasLayer
var menu: CanvasLayer
var _amb: AudioStreamPlayer
var _music: AudioStreamPlayer
var _creak_t := 0.0

var shot_path := ""
var shot_frames := -1
var autoplay := false
# Options de vérification (voir tools/verify/playtest.py). Elles n'ont aucun
# effet sur une partie normale : rien de tout cela n'est atteignable sans
# passer d'arguments en ligne de commande.
var dbg_light := 0.0
var dbg_tp := Vector3.INF
var dbg_yaw := INF
var dbg_pitch := 0.0
var dbg_torch := -1
var dbg_no_entity := false
var dbg_overview := 0.0
var dbg_ent := Vector3.INF
var dbg_aitest := 0.0
var dbg_alert := false
var dbg_rungame := false
var dbg_hide := false
var dbg_mousetest := false
var dbg_nopost := false
var dbg_ecran := ""
var dbg_settings := false
var dbg_lum := -1.0
var dbg_menutest := false
var dbg_lisibilite := false
var dbg_bruit := -1.0
var dbg_menace := -1.0
var dbg_lore := false
var dbg_doc := ""
var dbg_tpdoc := -1


func _ready() -> void:
	# Les phases PAUSE et LECTURE figent l'arbre. Sans ceci, _process ne
	# tournerait plus et la touche qui referme un document ne serait jamais lue.
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_parse_cmdline()
	_build_world()


func _parse_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--shot" and i + 2 < args.size():
			shot_path = args[i + 1]
			shot_frames = int(args[i + 2])
		elif args[i] == "--autoplay":
			autoplay = true
		elif args[i] == "--light" and i + 1 < args.size():
			dbg_light = float(args[i + 1])
		elif args[i] == "--tp" and i + 2 < args.size():
			dbg_tp = Vector3(float(args[i + 1]), 0.0, float(args[i + 2]))
		elif args[i] == "--yaw" and i + 1 < args.size():
			dbg_yaw = deg_to_rad(float(args[i + 1]))
		elif args[i] == "--pitch" and i + 1 < args.size():
			dbg_pitch = deg_to_rad(float(args[i + 1]))
		elif args[i] == "--torch" and i + 1 < args.size():
			dbg_torch = int(args[i + 1])
		elif args[i] == "--noent":
			dbg_no_entity = true
		elif args[i] == "--overview" and i + 1 < args.size():
			dbg_overview = float(args[i + 1])
		elif args[i] == "--ent" and i + 2 < args.size():
			dbg_ent = Vector3(float(args[i + 1]), 0.0, float(args[i + 2]))
		elif args[i] == "--aitest" and i + 1 < args.size():
			dbg_aitest = float(args[i + 1])
		elif args[i] == "--alert":
			dbg_alert = true
		elif args[i] == "--rungame":
			dbg_rungame = true
		elif args[i] == "--hide":
			dbg_hide = true
		elif args[i] == "--mousetest":
			dbg_mousetest = true
		elif args[i] == "--nopost":
			dbg_nopost = true
		elif args[i] == "--ecran" and i + 1 < args.size():
			dbg_ecran = args[i + 1]
		elif args[i] == "--settingstest":
			dbg_settings = true
		elif args[i] == "--menutest":
			dbg_menutest = true
		elif args[i] == "--lisibilite":
			dbg_lisibilite = true
		elif args[i] == "--loretest":
			dbg_lore = true
		elif args[i] == "--doc" and i + 1 < args.size():
			dbg_doc = args[i + 1]
		elif args[i] == "--tpdoc" and i + 1 < args.size():
			dbg_tpdoc = int(args[i + 1])
		elif args[i] == "--bruit" and i + 1 < args.size():
			dbg_bruit = float(args[i + 1])
		elif args[i] == "--menace" and i + 1 < args.size():
			dbg_menace = float(args[i + 1])
		elif args[i] == "--lum" and i + 1 < args.size():
			dbg_lum = float(args[i + 1])


func _build_world() -> void:
	# l'état de reprise doit être connu AVANT de semer les fusibles
	GameState.reset_run()

	var wenv := WorldEnvironment.new()
	wenv.environment = load("res://scenes/env.tres")
	add_child(wenv)

	level = preload("res://scripts/LevelBuilder.gd").new()
	level.name = "Level"
	add_child(level)
	level.build()

	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = level.spawn_point()
	player.set_floor_kind(level.floor_kind_at(level.spawn_point()))

	_spawn_pickups()
	if not dbg_no_entity:
		_spawn_veilleuse()

	hud = preload("res://scripts/HUD.gd").new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind(player)

	_amb = Audio.make_loop("amb_drone", -17.0)
	_amb.play()
	_music = Audio.make_loop("music_chase", -60.0)
	_music.play()

	menu = preload("res://scripts/Menu.gd").new()
	menu.name = "Menu"
	add_child(menu)
	menu.bind(player)

	if GameState.power_restored:
		_rallumer()
	# le menu a demandé d'enchaîner : on saute l'écran-titre
	if GameState.demarrer_en_jeu:
		GameState.demarrer_en_jeu = false
		GameState.set_phase(GameState.Phase.JEU, true)
	else:
		GameState.set_phase(GameState.Phase.TITRE, true)

	_apply_debug()
	if dbg_aitest > 0.0:
		_run_ai_test()
	if dbg_rungame:
		_run_objective_test()
	if dbg_mousetest:
		_run_mouse_test()
	if dbg_settings:
		_run_settings_test()
	if dbg_menutest or GameState.test_menu > 0:
		_run_menu_test()
	if dbg_lisibilite:
		_run_lisibilite_test()
	if dbg_lore:
		_run_lore_test()
	if shot_frames >= 0:
		_do_shot()


## Test d'intégration de l'IA : on provoque un bruit fort, puis on vérifie
## que la Veilleuse passe bien en chasse ET qu'elle se rapproche réellement
## (le pathfinding aboutit) au lieu de rester bloquée contre un mur.
func _run_ai_test() -> void:
	GameState.set_phase(GameState.Phase.JEU)
	player.can_move = false
	var ETAT := ["PATROUILLE", "INVESTIGATION", "CHASSE", "ATTAQUE"]
	var t := 0.0
	var d0 := veilleuse.global_position.distance_to(player.global_position)
	var d_min := d0
	var seen := {}
	var moved := 0.0
	var path_max := 0
	var path_min := 99999
	var prev := veilleuse.global_position
	var noise_done := false
	print("AITEST start  d0=%.1f m  points_ronde=%d  cases_bloquees=%d  atteignable=%d/%d  props_ecartes=%d"
			% [d0, level.patrol_points.size(), level.solid_grid.size(),
			   level.nav_reachable, level.nav_total, level.skipped_props])
	while t < dbg_aitest:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		moved += prev.distance_to(veilleuse.global_position)
		prev = veilleuse.global_position
		var d := veilleuse.global_position.distance_to(player.global_position)
		d_min = minf(d_min, d)
		if veilleuse.etat == Veilleuse.Etat.CHASSE:
			path_max = maxi(path_max, veilleuse._path.size())
			path_min = mini(path_min, veilleuse._path.size())
		seen[veilleuse.etat] = true
		if not noise_done and t > 7.0:
			noise_done = true
			# Le bruit doit porter jusqu'à elle, sinon le test ne teste rien.
			# Il émettait un halètement (22 m) à un instant fixe : selon l'endroit
			# de sa ronde, elle était souvent hors de portée (30 m et plus) et le
			# test échouait sans qu'aucun code de perception soit en cause.
			# On choisit donc le bruit en fonction de la distance réelle, et on
			# journalise les deux pour que le résultat reste interprétable.
			var kind := "halètement" if d < NoiseBus.R["halètement"] * 0.9 else "courant"
			NoiseBus.emit_kind(player.global_position, kind)
			print("AITEST  t=%.1f  bruit '%s' (%.0f m) emis a %.1f m  -> l'entend=%s"
					% [t, kind, NoiseBus.R[kind], d,
					   d <= NoiseBus.R[kind] * Settings.ouie()])
		if fmod(t, 1.0) < 1.0 / 60.0:
			print("AITEST  t=%4.1f  etat=%-13s d=%5.1f m  chemin=%d  parcouru=%.1f m"
					% [t, ETAT[veilleuse.etat], d, veilleuse._path.size(), moved])
	print("AITEST RESULTAT  d_initiale=%.1f  d_min=%.1f  distance_parcourue=%.1f  etats=%s"
			% [d0, d_min, moved, str(seen.keys().map(func(k): return ETAT[k]))])
	print("AITEST  chemin en chasse : %d -> %d points (%.1f m -> %.1f m)"
			% [path_max, path_min, path_max * level.NAV_RES, path_min * level.NAV_RES])
	var chase := seen.has(Veilleuse.Etat.CHASSE) or seen.has(Veilleuse.Etat.ATTAQUE)
	print("AITEST  deplacement=%s  reaction_au_bruit=%s  progression_vers_joueur=%s"
			% ["OK" if moved > 3.0 else "ECHEC",
			   "OK" if chase else "ECHEC",
			   "OK" if (path_max > 0 and path_min < path_max * 0.5) else "ECHEC"])
	get_tree().quit()


func _apply_debug() -> void:
	# fige les retours de lisibilité à une valeur donnée, le temps d'une
	# capture : ils sont trop brefs pour être saisis autrement.
	if dbg_bruit >= 0.0 or dbg_menace >= 0.0:
		hud.set_process(false)
		if dbg_bruit >= 0.0:
			hud._bruit = dbg_bruit
		if dbg_menace >= 0.0:
			hud._menace_f = dbg_menace
			hud._menace = Vector2.RIGHT
		hud._update_post(0.016)
	if dbg_light > 0.0:
		var e: Environment = (get_child(0) as WorldEnvironment).environment
		# la couleur d'ambiance du jeu est presque noire : pour inspecter la
		# géométrie il faut aussi l'éclaircir, pas seulement monter l'énergie
		e.ambient_light_color = Color(0.62, 0.64, 0.66)
		e.ambient_light_energy = dbg_light
		e.fog_density = 0.012 / maxf(dbg_light, 1.0)
	if dbg_tp != Vector3.INF:
		player.global_position = dbg_tp + Vector3(0, 0.1, 0)
	if dbg_yaw != INF:
		player.set_look(dbg_yaw, dbg_pitch)
	if dbg_lum >= 0.0:
		Settings.luminosite = dbg_lum
	if dbg_tpdoc >= 0 and player and level.document_spawns.size() > dbg_tpdoc:
		var d: Dictionary = level.document_spawns[dbg_tpdoc]
		var pos: Vector3 = d["pos"]
		# la caméra regarde -Z quand yaw vaut 0 : on se place donc EN +Z du
		# document et on garde yaw = 0 pour l'avoir en face
		player.global_position = pos + Vector3(0, 1.05, 1.4)
		player.set_look(0.0, -0.52)
		print("TPDOC  %s a (%.1f, %.1f)" % [d["id"], pos.x, pos.z])
	if dbg_ecran != "" and menu:
		match dbg_ecran:
			"titre":    GameState.set_phase(GameState.Phase.TITRE, true)
			"options":  menu._afficher(menu.Ecran.OPTIONS)
			"pause":    GameState.set_phase(GameState.Phase.PAUSE, true)
			"mort":     GameState.set_phase(GameState.Phase.MORT, true)
			"victoire": GameState.set_phase(GameState.Phase.VICTOIRE, true)
			"journal":
				# on marque quelques documents comme trouvés : un journal vide
				# ne montrerait pas la mise en page réelle
				for i in 6:
					GameState.lire_document(str(Lore.DOCUMENTS[i]["id"]))
				menu._afficher(menu.Ecran.JOURNAL)
			"lecture":
				GameState.set_phase(GameState.Phase.JEU, true)
				GameState.ouvrir_document(dbg_doc if dbg_doc != "" \
						else str(Lore.DOCUMENTS[0]["id"]))
	if dbg_nopost:
		# inspection de la géométrie : sans grain ni vignettage, le
		# scintillement du tampon de profondeur devient évident.
		hud.disable_post()
	if dbg_ent != Vector3.INF and veilleuse:
		veilleuse.global_position = dbg_ent
	if dbg_hide:
		var spots := get_tree().get_nodes_in_group("hiding")
		if not spots.is_empty():
			var best_spot = spots[0]
			var bd := 1e9
			for sp in spots:
				var d: float = sp.exit_position().distance_to(player.global_position)
				if d < bd:
					bd = d
					best_spot = sp
			best_spot.interact(player)
	if dbg_alert and veilleuse:
		veilleuse._spawn_grace = 0.0
		veilleuse._target = player.global_position
		veilleuse._enter(Veilleuse.Etat.CHASSE)
	if dbg_torch >= 0:
		player.torch_on = dbg_torch > 0
		player.torch.visible = player.torch_on
	if dbg_overview > 0.0:
		# vue de dessus : on retire les plafonds et on rajoute un soleil
		for c in get_tree().get_nodes_in_group("ceiling"):
			c.visible = false
		var sun := DirectionalLight3D.new()
		sun.light_energy = 1.5
		sun.rotation = Vector3(-1.15, 0.6, 0.0)
		sun.shadow_enabled = false
		add_child(sun)
		var e2: Environment = (get_child(0) as WorldEnvironment).environment
		e2.ambient_light_energy = 1.2
		e2.fog_enabled = false
		var cam := player.cam
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = dbg_overview
		cam.far = 200.0
		player.global_position = Vector3(22.0, 46.0, 20.0)
		player.set_look(0.0, -PI * 0.5)
		player.can_move = false
		player.torch_on = false
		player.torch.visible = false


## Remet les veilleuses à pleine puissance : appelé au retour du courant et
## à la reprise d'une partie où il était déjà revenu.
func _rallumer() -> void:
	for l in get_tree().get_nodes_in_group("bulb"):
		if l is OmniLight3D:
			l.light_energy = float(l.get_meta("base", l.light_energy)) * 2.1


func _spawn_pickups() -> void:
	var holder := Node3D.new()
	holder.name = "Pickups"
	add_child(holder)
	var fuse_scene: PackedScene = load("res://assets/models/props/fuse.glb")
	var bat_scene: PackedScene = load("res://assets/models/props/battery.glb")
	# à la reprise, les fusibles déjà posés ne réapparaissent pas
	var deja: int = GameState.fuses_installed
	for i in level.fuse_spawns.size():
		if i < deja:
			continue
		var n := preload("res://scripts/Pickup.gd").new()
		holder.add_child(n)
		n.setup("fuse", fuse_scene, level.fuse_spawns[i])
	for p in level.battery_spawns:
		var n := preload("res://scripts/Pickup.gd").new()
		holder.add_child(n)
		n.setup("battery", bat_scene, p)

	# Les documents du récit vivent dans leur PROPRE noeud, pas parmi les
	# ramassables. Mêlés à eux, ils cassaient le parcours des objectifs, qui
	# lisait `kind` sur chaque enfant — une propriété qu'un document n'a pas.
	# Deux familles d'objets, deux conteneurs.
	var docs := Node3D.new()
	docs.name = "Documents"
	add_child(docs)
	var papiers: PackedScene = load("res://assets/models/props/papers.glb")
	for d in level.document_spawns:
		var n := preload("res://scripts/Document.gd").new()
		docs.add_child(n)
		n.setup(d["id"], papiers, (d["pos"] as Vector3) + Vector3(0, 0.02, 0),
				randf() * TAU)


func _spawn_veilleuse() -> void:
	veilleuse = Veilleuse.new()
	veilleuse.name = "Veilleuse"
	veilleuse.setup(level, player)
	add_child(veilleuse)
	# elle démarre à l'opposé du joueur, dans l'aile nord
	var best: Vector3 = level.spawn_point()
	var best_d := -1.0
	for p in level.patrol_points:
		var d: float = p.distance_to(level.spawn_point())
		if d > best_d:
			best_d = d
			best = p
	veilleuse.global_position = best


# --------------------------------------------------------------------------
func _process(delta: float) -> void:
	# Un document ouvert se referme avec la touche qui l'a ouvert, ou Échap.
	# Prioritaire sur la pause : sinon Échap sur un document ouvrirait le menu
	# par-dessus la feuille.
	if GameState.phase == GameState.Phase.LECTURE:
		if Input.is_action_just_pressed("interact") \
				or Input.is_action_just_pressed("pause"):
			GameState.fermer_document()
		return

	if Input.is_action_just_pressed("pause"):
		if GameState.phase == GameState.Phase.JEU:
			GameState.set_phase(GameState.Phase.PAUSE)
		elif GameState.phase == GameState.Phase.PAUSE:
			GameState.set_phase(GameState.Phase.JEU)

	if GameState.phase != GameState.Phase.JEU:
		return

	# La capture du curseur peut être perdue (clic hors fenêtre, alt-tab) ou
	# avoir échoué au démarrage : on la rétablit tant qu'on est en jeu.
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# le sol change de matériau entre les ailes
	if player:
		player.set_floor_kind(level.floor_kind_at(player.global_position))

	# musique de traque : elle monte quand la Veilleuse chasse
	if _music and veilleuse:
		var want := -13.0 if veilleuse.is_hunting() else -60.0
		_music.volume_db = lerpf(_music.volume_db, want, delta * (2.5 if want > -40.0 else 0.7))

	# craquements et gouttes, placés au hasard autour du joueur
	_creak_t -= delta
	if _creak_t <= 0.0:
		_creak_t = randf_range(7.0, 20.0)
		var a := randf() * TAU
		var r := randf_range(5.0, 14.0)
		var pos: Vector3 = player.global_position + Vector3(cos(a) * r, randf_range(0.2, 2.4), sin(a) * r)
		if randf() < 0.55:
			Audio.play_3d("creak_%d" % randi_range(1, 3), pos, -14.0, randf_range(0.85, 1.15))
		else:
			Audio.play_3d("drip_%d" % randi_range(1, 3), pos, -16.0, randf_range(0.9, 1.1))


## Parcours automatique de la boucle d'objectif : ramasser les 4 fusibles,
## les poser au tableau, puis sortir par le monte-charge. Vérifie que chaque
## point de passage est bien atteignable et que les états s'enchaînent.
func _run_objective_test() -> void:
	GameState.set_phase(GameState.Phase.JEU)
	player.can_move = false
	if veilleuse:
		veilleuse.queue_free()
		veilleuse = null
	await get_tree().create_timer(0.4).timeout
	print("RUNGAME  fusibles a trouver : %d" % level.fuse_spawns.size())
	var ok := true

	var n := 0
	for holder in get_node("Pickups").get_children():
		if not is_instance_valid(holder) or holder.kind != "fuse":
			continue
		player.global_position = holder.global_position - Vector3(0, 0.6, 0)
		await get_tree().physics_frame
		var reachable: bool = not level.solid_grid.has(level.world_to_grid(holder.global_position))
		holder.interact(player)
		n += 1
		print("RUNGAME  fusible %d ramasse a (%.1f, %.1f)  atteignable=%s"
				% [n, holder.global_position.x, holder.global_position.z, reachable])
		if not reachable:
			ok = false
	print("RUNGAME  en main : %d / %d" % [GameState.fuses_held, GameState.FUSES_REQUIRED])

	var fb = get_tree().get_first_node_in_group("fusebox")
	if fb == null:
		print("RUNGAME  ECHEC : tableau electrique absent")
		ok = false
	else:
		player.global_position = fb.global_position + Vector3(0, -1.2, 0.9)
		await get_tree().physics_frame
		fb.interact(player)
		print("RUNGAME  tableau : poses=%d  courant=%s"
				% [GameState.fuses_installed, GameState.power_restored])
		if not GameState.power_restored:
			ok = false

	var ex = get_tree().get_first_node_in_group("exit")
	if ex == null:
		print("RUNGAME  ECHEC : monte-charge absent")
		ok = false
	else:
		ex.interact(player)
		await get_tree().process_frame
		print("RUNGAME  phase finale = %d (VICTOIRE=%d)"
				% [GameState.phase, GameState.Phase.VICTOIRE])
		if GameState.phase != GameState.Phase.VICTOIRE:
			ok = false

	# --- portes : ouverture réelle ET accessibilité au rayon du joueur ---
	var doors := get_tree().get_nodes_in_group("door")
	print("RUNGAME  portes : %d" % doors.size())
	if doors.is_empty():
		ok = false
	else:
		var d0 = doors[0]
		# certaines portes sont trouvées entrouvertes : on part d'un état connu
		if d0.open:
			d0.interact(player)
			await get_tree().create_timer(1.2).timeout
		# 1. le rayon du joueur doit atteindre la porte fermée, vue de face
		player.global_position = d0.global_position + Vector3(0.55, 0, 1.3).rotated(Vector3.UP, d0.rotation.y)
		player.set_look(d0.rotation.y, 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var tgt = player.current_target()
		print("RUNGAME  cible visee : %s" % (tgt.get_script().resource_path.get_file() if tgt else "AUCUNE"))
		if tgt == null or not tgt.has_method("prompt"):
			ok = false
		# 2. l'ouverture fait bien pivoter le vantail
		d0.interact(player)
		await get_tree().create_timer(1.2).timeout
		print("RUNGAME  porte 0 : ouverte=%s  angle=%.2f rad" % [d0.open, d0._angle])
		if not d0.open or d0._angle < 1.0:
			ok = false

	# --- cachettes ---
	var spots := get_tree().get_nodes_in_group("hiding")
	print("RUNGAME  cachettes : %d" % spots.size())
	if spots.is_empty():
		ok = false
	else:
		var lk = spots[0]
		lk.interact(player)
		await get_tree().create_timer(0.7).timeout
		var hid: bool = player.is_hidden
		var pos_in := player.global_position
		player.exit_hiding()
		await get_tree().create_timer(0.2).timeout
		print("RUNGAME  casier : cache=%s  sorti=%s  deplacement=%.2f m"
				% [hid, not player.is_hidden, pos_in.distance_to(player.global_position)])
		if not hid or player.is_hidden:
			ok = false

	print("RUNGAME RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


## Vérifie que la souris pilote bien la vue : on injecte un mouvement dans le
## pipeline d'entrées normal et on regarde si le cap du joueur bouge.
func _run_mouse_test() -> void:
	GameState.set_phase(GameState.Phase.JEU)
	await get_tree().process_frame
	await get_tree().process_frame
	print("MOUSETEST  mouse_mode=%d (CAPTURED=%d)" % [Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])
	var y0: float = player._yaw
	var p0: float = player._pitch
	for i in 5:
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(60, 30)
		ev.screen_relative = Vector2(60, 30)
		ev.position = get_viewport().get_visible_rect().size * 0.5
		ev.global_position = ev.position
		Input.parse_input_event(ev)
		await get_tree().process_frame
	print("MOUSETEST  yaw %.4f -> %.4f (delta %.4f)   pitch %.4f -> %.4f (delta %.4f)"
			% [y0, player._yaw, player._yaw - y0, p0, player._pitch, player._pitch - p0])
	print("MOUSETEST RESULTAT : %s"
			% ("OK" if absf(player._yaw - y0) > 0.01 and absf(player._pitch - p0) > 0.01 else "ECHEC"))
	get_tree().quit()


## Vérifie que les réglages agissent RÉELLEMENT sur le jeu, et pas seulement
## sur l'affichage du menu.
func _run_settings_test() -> void:
	GameState.set_phase(GameState.Phase.JEU)
	await get_tree().process_frame
	var ok := true

	# --- sensibilité de la souris ---
	var mesures := []
	for s in [0.1, 0.5, 1.0]:
		Settings.sensibilite = s
		player.set_look(0.0, 0.0)
		await get_tree().process_frame
		var ev := InputEventMouseMotion.new()
		ev.relative = Vector2(100, 0)
		ev.position = get_viewport().get_visible_rect().size * 0.5
		Input.parse_input_event(ev)
		await get_tree().process_frame
		mesures.append(absf(player._yaw))
	print("SETTINGS  sensibilite 0.1/0.5/1.0 -> rotation %.4f / %.4f / %.4f rad"
			% [mesures[0], mesures[1], mesures[2]])
	if not (mesures[0] < mesures[1] and mesures[1] < mesures[2]):
		ok = false

	# --- inversion de l'axe vertical ---
	Settings.sensibilite = 0.5
	var pitches := []
	for inv in [false, true]:
		Settings.inverser_y = inv
		player.set_look(0.0, 0.0)
		await get_tree().process_frame
		var ev2 := InputEventMouseMotion.new()
		ev2.relative = Vector2(0, 100)
		ev2.position = get_viewport().get_visible_rect().size * 0.5
		Input.parse_input_event(ev2)
		await get_tree().process_frame
		pitches.append(player._pitch)
	print("SETTINGS  axe vertical normal %.4f / inverse %.4f" % [pitches[0], pitches[1]])
	if signf(pitches[0]) == signf(pitches[1]) or absf(pitches[0]) < 0.01:
		ok = false
	Settings.inverser_y = false

	# --- volumes : les bus doivent bouger ---
	var lignes := []
	for v in [0.0, 0.5, 1.0]:
		Settings.vol_effets = v
		Settings.appliquer()
		var i := AudioServer.get_bus_index("SFX")
		lignes.append("%.1f->%s" % [v, ("coupé" if AudioServer.is_bus_mute(i)
				else "%.1f dB" % AudioServer.get_bus_volume_db(i))])
	print("SETTINGS  bus SFX : " + " | ".join(lignes))
	Settings.vol_effets = 1.0
	Settings.appliquer()

	# --- difficulté : ouïe, vitesse, souffle, lampe ---
	for d in 3:
		Settings.difficulte = d
		print("SETTINGS  %-13s ouie x%.2f  vitesse x%.2f  souffle x%.2f  lampe x%.2f"
				% [Settings.nom_difficulte(), Settings.ouie(), Settings.vitesse_entite(),
				   Settings.drain_souffle(), Settings.autonomie_lampe()])
	Settings.difficulte = 1

	# --- persistance ---
	Settings.luminosite = 0.77
	Settings.sensibilite = 0.33
	Settings.sauver()
	Settings.luminosite = 0.0
	Settings.sensibilite = 0.0
	Settings.charger()
	print("SETTINGS  persistance : luminosite %.2f  sensibilite %.2f"
			% [Settings.luminosite, Settings.sensibilite])
	if absf(Settings.luminosite - 0.77) > 0.01 or absf(Settings.sensibilite - 0.33) > 0.01:
		ok = false

	# --- point de contrôle ---
	GameState.effacer_point_de_controle()
	var avant := GameState.a_un_point_de_controle()
	GameState.fuses_installed = 2
	GameState.time_survived = 91.0
	GameState.poser_point_de_controle()
	GameState.reprise_fusibles = 0
	GameState.reprendre()
	print("SETTINGS  point de controle : avant=%s  apres reprise fusibles=%d temps=%.0f s"
			% [avant, GameState.reprise_fusibles, GameState.reprise_temps])
	if avant or GameState.reprise_fusibles != 2 or absf(GameState.reprise_temps - 91.0) > 0.5:
		ok = false
	GameState.effacer_point_de_controle()

	Settings.remettre_defauts()
	print("SETTINGS RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


## Cherche un bouton par son intitulé dans tout un sous-arbre.
func _trouver_bouton(n: Node, texte: String) -> Button:
	if n is Button and texte in (n as Button).text:
		return n
	for c in n.get_children():
		var r := _trouver_bouton(c, texte)
		if r:
			return r
	return null


## Test de bout en bout du menu : on PRESSE réellement « Descendre » et on
## vérifie que la partie démarre.
##
## Ce test traverse un rechargement de scène, qui détruit tous les noeuds. Son
## avancement transite donc par GameState, seul survivant. C'est exactement le
## piège qui avait laissé passer le bouton inopérant : les autres tests
## court-circuitent le menu et n'empruntent jamais ce chemin.
func _run_menu_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if GameState.test_menu == 0:
		GameState.test_menu = 1

	if GameState.test_menu == 1:
		var au_titre: bool = GameState.phase == GameState.Phase.TITRE
		var b := _trouver_bouton(menu, "Descendre")
		print("MENUTEST  etape 1 : ecran titre=%s  bouton 'Descendre' trouve=%s"
				% [au_titre, b != null])
		if b == null or not au_titre:
			print("MENUTEST RESULTAT : ECHEC")
			GameState.test_menu = 0
			get_tree().quit()
			return
		GameState.test_menu = 2
		b.pressed.emit()
		return

	# --- après un rechargement déclenché par un bouton ---
	var ETAT := ["TITRE", "JEU", "PAUSE", "MORT", "VICTOIRE"]
	var etape: int = GameState.test_menu
	var jouable: bool = (GameState.phase == GameState.Phase.JEU
			and is_instance_valid(player) and player.can_move
			and level != null and level.fuse_spawns.size() > 0)
	print("MENUTEST  etape %d : phase=%s  joueur=%s  peut_bouger=%s  fusibles=%d  menu visible=%s"
			% [etape, ETAT[GameState.phase], is_instance_valid(player),
			   player.can_move if is_instance_valid(player) else false,
			   level.fuse_spawns.size() if level else -1,
			   menu.visible if menu else "?"])
	var ok: bool = jouable and (menu == null or not menu.visible)
	if not ok:
		print("MENUTEST RESULTAT : ECHEC")
		GameState.test_menu = 0
		get_tree().quit()
		return

	if etape == 2:
		# on passe par l'écran de mort, chemin le plus emprunté par un joueur
		print("MENUTEST  souris capturee=%s" % [Input.mouse_mode == Input.MOUSE_MODE_CAPTURED])
		GameState.set_phase(GameState.Phase.MORT, true)
		await get_tree().process_frame
		var b := _trouver_bouton(menu, "Recommencer")
		print("MENUTEST  ecran de mort : bouton 'Recommencer' trouve=%s" % [b != null])
		if b == null:
			print("MENUTEST RESULTAT : ECHEC")
			GameState.test_menu = 0
			get_tree().quit()
			return
		GameState.test_menu = 3
		b.pressed.emit()
		return

	print("MENUTEST RESULTAT : OK")
	GameState.test_menu = 0
	get_tree().quit()


## Vérifie que la traque est LISIBLE — c'est-à-dire que le joueur reçoit
## bien, par l'oreille et par l'image, l'information que le jeu prétend lui
## donner sur sa mécanique centrale.
##
## Quatre affirmations, mesurées et non supposées :
##   1. l'écho du couloir suit le rayon sonore, et se tait sous le seuil ;
##   2. l'impulsion visuelle suit la même échelle que l'écho ;
##   3. les trois transitions d'état émettent chacune leur signal ;
##   4. la direction de la menace pointe du bon côté de l'écran.
func _run_lisibilite_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := true

	# --- 1. l'écho suit le rayon ---
	var echelle := [
		["accroupi", NoiseBus.R["pas_accroupi"]],
		["marche", NoiseBus.R["pas_marche"]],
		["course", NoiseBus.R["pas_course"]],
		["halètement", NoiseBus.R["halètement"]],
	]
	var dbs: Array[float] = []
	for e in echelle:
		var r: float = e[1]
		var db: float = Audio.echo_db(r)
		dbs.append(db)
		print("LISIB  echo %-11s rayon %5.1f m -> %s"
				% [e[0], r, ("SILENCE" if db == -INF else "%.1f dB" % db)])
	if dbs[0] != -INF:
		print("LISIB  ! un pas accroupi ne doit rien renvoyer")
		ok = false
	for i in range(1, dbs.size()):
		if dbs[i] == -INF or dbs[i] <= dbs[i - 1]:
			print("LISIB  ! l'echo ne croit pas avec le rayon")
			ok = false
	# l'écart marche/course doit sauter à l'oreille : au moins 6 dB
	var saut: float = dbs[2] - dbs[1]
	print("LISIB  ecart marche -> course = %.1f dB (attendu >= 6)" % saut)
	if saut < 6.0:
		ok = false

	# --- 2. l'impulsion visuelle parle la même échelle ---
	print("LISIB  portee : accroupi=%.2f  marche=%.2f  course=%.2f  halètement=%.2f"
			% [NoiseBus.portee(NoiseBus.R["pas_accroupi"]),
			   NoiseBus.portee(NoiseBus.R["pas_marche"]),
			   NoiseBus.portee(NoiseBus.R["pas_course"]),
			   NoiseBus.portee(NoiseBus.R["halètement"])])
	if NoiseBus.portee(NoiseBus.R["pas_accroupi"]) != 0.0:
		ok = false
	# le HUD doit réagir à un vrai bruit émis près du joueur, et l'ignorer loin
	GameState.set_phase(GameState.Phase.JEU, true)
	await get_tree().process_frame
	var mesures := {}
	for cas in [["pres_course", player.global_position, "pas_course"],
				["pres_accroupi", player.global_position, "pas_accroupi"],
				["loin_course", player.global_position + Vector3(30, 0, 0), "pas_course"]]:
		hud._bruit = 0.0
		NoiseBus.emit_kind(cas[1], cas[2])
		mesures[cas[0]] = hud._bruit
	print("LISIB  impulsion HUD : course pres=%.2f  accroupi pres=%.2f  course loin=%.2f"
			% [mesures["pres_course"], mesures["pres_accroupi"], mesures["loin_course"]])
	if mesures["pres_course"] < 0.4 or mesures["pres_accroupi"] != 0.0 \
			or mesures["loin_course"] != 0.0:
		print("LISIB  ! l'impulsion visuelle ne discrimine pas correctement")
		ok = false
	# la respiration est continue : elle ne doit jamais declencher d'impulsion
	hud._bruit = 0.0
	NoiseBus.emit_noise(player.global_position, NoiseBus.R["halètement"], "souffle")
	print("LISIB  impulsion sur respiration = %.2f (attendu 0.00)" % hud._bruit)
	if hud._bruit != 0.0:
		ok = false

	# --- 3. les trois transitions signalent ---
	if veilleuse == null:
		print("LISIB  ! pas de Veilleuse")
		ok = false
	else:
		veilleuse._spawn_grace = 0.0
		var attendu := [
			[Veilleuse.Etat.PATROUILLE, Veilleuse.Etat.INVESTIGATION, "stinger_detect"],
			[Veilleuse.Etat.INVESTIGATION, Veilleuse.Etat.CHASSE, "entity_scream"],
			[Veilleuse.Etat.CHASSE, Veilleuse.Etat.INVESTIGATION, "stinger_lost"],
			[Veilleuse.Etat.INVESTIGATION, Veilleuse.Etat.PATROUILLE, "stinger_lost"],
		]
		for a in attendu:
			veilleuse.etat = a[0]
			Audio.dernier_sting = ""
			veilleuse._enter(a[1])
			var recu: String = Audio.dernier_sting
			var bon: bool = recu == a[2]
			print("LISIB  %-14s -> %-14s : signal '%s' %s"
					% [_nom_etat(a[0]), _nom_etat(a[1]), recu, "OK" if bon else "ATTENDU " + a[2]])
			if not bon:
				ok = false

	# --- 4. la direction de la menace ---
	if veilleuse and player:
		var cas := [["a droite", Vector3(6, 0, 0), 1.0], ["a gauche", Vector3(-6, 0, 0), -1.0]]
		player.set_look(0.0, 0.0)
		await get_tree().process_frame
		for c in cas:
			veilleuse.global_position = player.global_position + (c[1] as Vector3)
			veilleuse.etat = Veilleuse.Etat.CHASSE
			hud._menace_f = 0.0
			for i in 30:
				hud._update_menace(0.05)
			var signe: float = signf(hud._menace.x)
			var bon: bool = signe == c[2] and hud._menace_f > 0.3
			print("LISIB  menace %-9s : x=%+.2f force=%.2f  %s"
					% [c[0], hud._menace.x, hud._menace_f, "OK" if bon else "ECHEC"])
			if not bon:
				ok = false
		# hors traque, aucun signal ne doit subsister
		veilleuse.etat = Veilleuse.Etat.PATROUILLE
		for i in 60:
			hud._update_menace(0.05)
		print("LISIB  hors traque : force=%.2f (attendu 0.00)" % hud._menace_f)
		if hud._menace_f > 0.01:
			ok = false

	# --- 5. effacer un point de reprise ne doit PAS effacer les records ---
	# Le test part d'un disque vierge : sans cela il héritait du record écrit
	# par --rungame (une victoire scriptée en 0.4 s), et mesurait l'ordre
	# d'exécution de la suite plutôt que le comportement visé.
	DirAccess.remove_absolute(GameState.FICHIER_PROGRESSION)
	GameState.souffle_appris = false
	Settings.difficulte = 1
	GameState.enregistrer_temps(412.0)
	var avant_record := GameState.meilleur_temps()
	GameState.fuses_installed = 2
	GameState.poser_point_de_controle()
	GameState.effacer_point_de_controle()
	var apres_record := GameState.meilleur_temps()
	print("LISIB  record avant=%.1f s  apres effacement du point de reprise=%.1f s"
			% [avant_record, apres_record])
	if absf(avant_record - 412.0) > 0.5 or absf(apres_record - 412.0) > 0.5:
		print("LISIB  ! effacer le point de reprise detruit les meilleurs temps")
		ok = false
	if GameState.a_un_point_de_controle():
		print("LISIB  ! le point de reprise survit a son effacement")
		ok = false

	# --- 6. le didacticiel de l'apnée : une fois, et une seule ---
	GameState.souffle_appris = false
	var vues := 0
	for i in 3:
		var avant := GameState.souffle_appris
		GameState.apprendre_souffle()
		if not avant and GameState.souffle_appris:
			vues += 1
	print("LISIB  didacticiel declenche %d fois sur 3 appels (attendu 1)" % vues)
	if vues != 1:
		ok = false
	GameState.souffle_appris = false
	GameState.apprendre_souffle()
	var relu := ConfigFile.new()
	relu.load(GameState.FICHIER_PROGRESSION)
	var persiste: bool = bool(relu.get_value("didacticiel", "souffle", false))
	print("LISIB  didacticiel persiste sur disque : %s" % persiste)
	if not persiste:
		ok = false
	DirAccess.remove_absolute(GameState.FICHIER_PROGRESSION)
	GameState.souffle_appris = false

	print("LISIB RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


func _nom_etat(e: int) -> String:
	return ["PATROUILLE", "INVESTIGATION", "CHASSE", "ATTAQUE"][e]


## Vérifie le système de récit : que TOUT le texte écrit soit réellement
## atteignable en jeu, que la lecture fonctionne, et qu'elle se conserve.
##
## Le risque propre à ce système est silencieux : un document mal placé ne
## plante rien, il devient simplement invisible, et un joueur ne saura jamais
## qu'il lui manque un morceau de l'histoire.
func _run_lore_test() -> void:
	await get_tree().process_frame
	var ok := true
	DirAccess.remove_absolute(GameState.FICHIER_PROGRESSION)
	GameState.documents_lus.clear()

	# --- 1. tout document écrit est placé, et atteignable ---
	var places := {}
	for d in level.document_spawns:
		places[d["id"]] = d["pos"]
	print("LORE  documents ecrits=%d  places dans le niveau=%d"
			% [Lore.total(), places.size()])
	var manquants := []
	for d in Lore.DOCUMENTS:
		if not places.has(d["id"]):
			manquants.append(d["id"])
	if not manquants.is_empty():
		print("LORE  ! jamais places : %s" % str(manquants))
		ok = false

	var hors := []
	for id in places:
		if not level._reachable(places[id]):
			hors.append(id)
	if not hors.is_empty():
		print("LORE  ! places dans un mur : %s" % str(hors))
		ok = false

	# --- 2. pas deux documents au même endroit ---
	var doublons := 0
	var ecart_min := 9999.0
	var ids_places := places.keys()
	for i in ids_places.size():
		for j in range(i + 1, ids_places.size()):
			var a: Vector3 = places[ids_places[i]]
			var b: Vector3 = places[ids_places[j]]
			var d := a.distance_to(b)
			ecart_min = minf(ecart_min, d)
			if d < level.DOC_ECART_MIN:
				doublons += 1
				print("LORE  ! %s et %s a %.2f m l'un de l'autre"
						% [ids_places[i], ids_places[j], d])
	print("LORE  ecart minimal entre deux documents : %.2f m (exige %.2f)"
			% [ecart_min, level.DOC_ECART_MIN])
	if doublons > 0:
		ok = false

	# --- 3. chacun tombe-t-il dans une salle qui lui donne du sens ? ---
	var bien := 0
	for d in Lore.DOCUMENTS:
		if not places.has(d["id"]):
			continue
		# level est typé Node3D : l'appel est dynamique, donc le type de retour
		# ne s'infère pas. Sans annotation, l'analyse échoue et le jeu se fige
		# au démarrage sans le moindre message.
		var g: Vector2i = level.world_to_cell(places[d["id"]])
		var c: String = level._cells.get(g, "")
		if c in (d.get("lieu", []) as Array):
			bien += 1
	print("LORE  places dans une salle pertinente : %d / %d" % [bien, places.size()])
	if bien < places.size() * 0.75:
		print("LORE  ! trop de documents echouent hors de leur salle")
		ok = false

	# --- 4. objets lisibles réellement présents dans la scène ---
	var noeuds := get_node("Documents").get_child_count()
	print("LORE  objets lisibles instancies : %d" % noeuds)
	if noeuds != places.size():
		ok = false

	# --- 4 bis. le joueur peut-il REELLEMENT en attraper un ? ---
	# Un document est posé au sol à 2 cm ; le rayon d'interaction part de la
	# caméra à hauteur d'homme. Rien ne garantit qu'il touche la petite sphère
	# de collision. C'est le même piège qui avait rendu les portes inutilisables :
	# l'objet existait, mais le rayon ne le trouvait jamais.
	GameState.set_phase(GameState.Phase.JEU, true)
	var vises := 0
	var total_postures := 0
	var essais = mini(6, level.document_spawns.size())
	for i in essais:
		var pos: Vector3 = level.document_spawns[i]["pos"]
		var postures := 0
		# on balaie les postures plausibles d'un joueur qui s'approche : reculs
		# de 0.8 à 2.0 m, regard de 30° à 50° vers le bas
		for d in [0.8, 1.2, 1.6, 2.0]:
			for pitch in [-0.9, -0.7, -0.5]:
				# les PIEDS au niveau du sol : l'origine du joueur est à ses
				# pieds et la caméra se place au-dessus. Ajouter une hauteur ici
				# éloignait la caméra du sol au point que le rayon n'atteignait
				# plus rien du tout.
				player.global_position = Vector3(pos.x, pos.y, pos.z + d)
				player.set_look(0.0, pitch)
				player.ray.force_raycast_update()
				var t := player.current_target()
				if t != null and t.get_script() == preload("res://scripts/Document.gd"):
					postures += 1
		total_postures += postures
		if postures >= 6:
			vises += 1
	print("LORE  attrapables confortablement : %d / %d  (%.1f postures valides sur 12 en moyenne)"
			% [vises, essais, float(total_postures) / maxi(essais, 1)])
	if vises < essais:
		print("LORE  ! des documents sont visibles mais penibles ou impossibles a ramasser")
		ok = false

	# --- 5. lecture : phase, enregistrement, fermeture ---
	GameState.set_phase(GameState.Phase.JEU, true)
	var premier: String = str(Lore.DOCUMENTS[0]["id"])
	var neuf := GameState.a_lu(premier)
	GameState.ouvrir_document(premier)
	var en_lecture: bool = GameState.phase == GameState.Phase.LECTURE
	var fige: bool = get_tree().paused
	var enregistre: bool = GameState.a_lu(premier)
	GameState.fermer_document()
	var revenu: bool = GameState.phase == GameState.Phase.JEU and not get_tree().paused
	print("LORE  lecture : deja_lu_avant=%s  phase LECTURE=%s  monde fige=%s  enregistre=%s  retour au jeu=%s"
			% [neuf, en_lecture, fige, enregistre, revenu])
	if neuf or not en_lecture or not fige or not enregistre or not revenu:
		ok = false

	# --- 6. la découverte se conserve d'une descente à l'autre ---
	for d in Lore.DOCUMENTS:
		GameState.lire_document(str(d["id"]))
	var avant := GameState.documents_trouves()
	GameState.documents_lus.clear()
	var relu := ConfigFile.new()
	relu.load(GameState.FICHIER_PROGRESSION)
	for id in relu.get_value("documents", "lus", []):
		GameState.documents_lus[id] = true
	print("LORE  persistance : %d lus -> %d relus depuis le disque"
			% [avant, GameState.documents_trouves()])
	if avant != Lore.total() or GameState.documents_trouves() != avant:
		ok = false

	# --- 7. cohérence de la table elle-même ---
	var ids := {}
	var vides := []
	for d in Lore.DOCUMENTS:
		var i: String = str(d["id"])
		if ids.has(i):
			print("LORE  ! identifiant en double : %s" % i)
			ok = false
		ids[i] = true
		if str(d.get("titre", "")).is_empty() or str(d.get("texte", "")).length() < 40:
			vides.append(i)
		if not Lore.CHAPITRES.has(int(d.get("chap", 0))):
			print("LORE  ! chapitre inconnu pour %s" % i)
			ok = false
	if not vides.is_empty():
		print("LORE  ! documents vides ou trop courts : %s" % str(vides))
		ok = false
	var repartition := []
	for n in Lore.chapitres():
		repartition.append("%d:%s (%d)" % [n, Lore.CHAPITRES[n], Lore.du_chapitre(n).size()])
	print("LORE  chapitres  " + "  |  ".join(repartition))

	# --- 8. le journal doit rester utilisable quand le récit grossit ---
	# C'est la promesse du système : ajouter un chapitre ne doit rien casser.
	# Or l'écran poussait son bouton de sortie hors de l'écran dès 14 entrées.
	for i in 6:
		GameState.lire_document(str(Lore.DOCUMENTS[i]["id"]))
	menu._afficher(menu.Ecran.JOURNAL)
	await get_tree().process_frame
	await get_tree().process_frame
	var entrees := 0
	var lus_cliquables := 0
	for c in menu._boite.get_children():
		if c is Button:
			lus_cliquables += 1
		if c is Label and "·" in (c as Label).text:
			entrees += 1
	var retour := _trouver_bouton(menu, "Retour")
	# le bouton de sortie doit être ATTEIGNABLE, donc soit dans l'écran, soit
	# accessible par défilement
	# menu est typé CanvasLayer : l'accès à ses membres rend du Variant, donc
	# rien ne s'infère. Sans annotation, le jeu se fige au démarrage sans message.
	var haut_contenu: float = menu._boite.get_combined_minimum_size().y
	var haut_vue: float = menu._defilement.size.y
	var atteignable: bool = retour != null and (haut_contenu <= haut_vue
			or menu._defilement.get_v_scroll_bar().max_value >= haut_contenu - 1.0)
	print("LORE  journal : %d titres lisibles + %d entrees masquees = %d / %d"
			% [lus_cliquables - 1, entrees, lus_cliquables - 1 + entrees, Lore.total()])
	print("LORE  journal : contenu %.0f px, vue %.0f px, sortie atteignable=%s"
			% [haut_contenu, haut_vue, atteignable])
	if lus_cliquables - 1 + entrees != Lore.total() or not atteignable:
		ok = false
	menu._afficher(menu.Ecran.AUCUN)

	DirAccess.remove_absolute(GameState.FICHIER_PROGRESSION)
	GameState.documents_lus.clear()
	print("LORE RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


func _do_shot() -> void:
	if autoplay:
		GameState.set_phase(GameState.Phase.JEU)
	await get_tree().process_frame
	for i in shot_frames:
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(shot_path)
	print("SHOT ", shot_path)
	get_tree().quit()
