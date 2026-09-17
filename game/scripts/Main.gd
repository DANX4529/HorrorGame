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
var prologue: CanvasLayer
var tactile: CanvasLayer
var menu: CanvasLayer
var ambiance: Node
var _music: AudioStreamPlayer

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
var dbg_seed := 0
var dbg_seedreport := false
var dbg_seedcheck := false
var dbg_verbose := false
## Les tests enchaînent directement sur la partie : un prologue à traverser
## ferait échouer toute vérification qui suppose la phase JEU au démarrage.
var dbg_sansprologue := false
var dbg_v1 := false
var dbg_tactile := 0
## Un doigt posé pendant la lecture d'un document. Sur mobile aucune action
## clavier n'est émise : sans cela, la feuille resterait ouverte pour toujours.
var _tape_lecture := false
var dbg_tactiletest := false
var dbg_ambiance := false


func _ready() -> void:
	# Les phases PAUSE et LECTURE figent l'arbre. Sans ceci, _process ne
	# tournerait plus et la touche qui referme un document ne serait jamais lue.
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_parse_cmdline()
	# avant _build_world : l'interface se dispose différemment selon le mode,
	# et forcer après coup laissait le HUD dessiné pour un clavier
	if dbg_tactile != 0:
		Tactile.forcer(dbg_tactile > 0)
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
		elif args[i] == "--seed" and i + 1 < args.size():
			dbg_seed = int(args[i + 1])
		elif args[i] == "--seedreport":
			dbg_seedreport = true
		elif args[i] == "--seedcheck":
			dbg_seedcheck = true
		elif args[i] == "--verbose":
			dbg_verbose = true
		elif args[i] == "--sansprologue":
			dbg_sansprologue = true
		elif args[i] == "--v1test":
			dbg_v1 = true
		elif args[i] == "--tactile":
			dbg_tactile = 1
		elif args[i] == "--clavier":
			dbg_tactile = -1
		elif args[i] == "--tactiletest":
			dbg_tactiletest = true
		elif args[i] == "--ambiancetest":
			dbg_ambiance = true
		elif args[i] == "--bruit" and i + 1 < args.size():
			dbg_bruit = float(args[i + 1])
		elif args[i] == "--menace" and i + 1 < args.size():
			dbg_menace = float(args[i + 1])
		elif args[i] == "--lum" and i + 1 < args.size():
			dbg_lum = float(args[i + 1])


func _build_world() -> void:
	if dbg_lore:
		# Les documents lus ne réapparaissent plus : ce qui est placé dépend
		# donc du disque. Le test doit partir d'une ardoise vierge AVANT la
		# construction, sinon il mesure l'historique de la machine.
		DirAccess.remove_absolute(GameState.FICHIER_PROGRESSION)
		GameState.documents_lus.clear()
		GameState.souffle_appris = false
	# l'état de reprise doit être connu AVANT de semer les fusibles
	GameState.reset_run()

	var wenv := WorldEnvironment.new()
	wenv.environment = load("res://scenes/env.tres")
	add_child(wenv)

	level = preload("res://scripts/LevelBuilder.gd").new()
	level.name = "Level"
	add_child(level)
	if dbg_seed != 0:
		GameState.graine = dbg_seed
	level.build(GameState.graine)

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

	_music = Audio.make_loop("music_chase", -60.0, "Musique")
	_music.play()

	ambiance = preload("res://scripts/Ambiance.gd").new()
	ambiance.name = "Ambiance"
	ambiance.joueur = player
	add_child(ambiance)

	menu = preload("res://scripts/Menu.gd").new()
	menu.name = "Menu"
	add_child(menu)
	menu.bind(player)

	tactile = preload("res://scripts/TouchControls.gd").new()
	tactile.name = "TouchControls"
	tactile.joueur = player
	add_child(tactile)

	# au-dessus du menu : le prologue couvre tout, y compris l'interface
	prologue = preload("res://scripts/Prologue.gd").new()
	prologue.name = "Prologue"
	add_child(prologue)

	if GameState.power_restored:
		_rallumer()
	# le menu a demandé d'enchaîner : on saute l'écran-titre
	if GameState.demarrer_en_jeu:
		GameState.demarrer_en_jeu = false
		# une descente neuve commence par le prologue ; une reprise non
		if GameState.montrer_prologue and not dbg_sansprologue:
			GameState.montrer_prologue = false
			GameState.set_phase(GameState.Phase.PROLOGUE, true)
		else:
			GameState.set_phase(GameState.Phase.JEU, true)
	else:
		GameState.set_phase(GameState.Phase.TITRE, true)

	_apply_debug()
	if dbg_aitest > 0.0:
		_run_ai_test()
	if dbg_seedcheck:
		_run_seed_check()
	if dbg_seedreport:
		_run_seed_report()
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
	if dbg_v1:
		_run_v1_test()
	if dbg_tactiletest:
		_run_tactile_test()
	if dbg_ambiance:
		_run_ambiance_test()
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
			"credits":
				menu._afficher(menu.Ecran.CREDITS)
			"prologue":
				GameState.montrer_prologue = true
				GameState.set_phase(GameState.Phase.PROLOGUE, true)
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
	if ambiance:
		ambiance.veilleuse = veilleuse
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
func _input(e: InputEvent) -> void:
	if GameState.phase == GameState.Phase.LECTURE \
			and e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed:
		_tape_lecture = true


func _process(delta: float) -> void:
	# Un document ouvert se referme avec la touche qui l'a ouvert, ou Échap.
	# Prioritaire sur la pause : sinon Échap sur un document ouvrirait le menu
	# par-dessus la feuille.
	if GameState.phase == GameState.Phase.LECTURE:
		if Input.is_action_just_pressed("interact") \
				or Input.is_action_just_pressed("pause") or _tape_lecture:
			_tape_lecture = false
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
	# Une descente neuve passe désormais par le prologue. On le traverse comme
	# le ferait un joueur — en appuyant pour le passer — plutôt que de le
	# désactiver : c'est ce chemin-là qu'il faut vérifier, pas un raccourci.
	if GameState.phase == GameState.Phase.PROLOGUE:
		print("MENUTEST  prologue affiche, on le passe")
		prologue._terminer()
		await get_tree().process_frame
	var ETAT := ["TITRE", "JEU", "PAUSE", "MORT", "VICTOIRE", "LECTURE", "PROLOGUE"]
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
	print("LORE  graine=%d  documents ecrits=%d  places dans le niveau=%d"
			% [GameState.graine, Lore.total(), places.size()])
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
	if bien < places.size():
		for d in Lore.DOCUMENTS:
			if not places.has(d["id"]):
				continue
			var gg: Vector2i = level.world_to_cell(places[d["id"]])
			var cc: String = level._cells.get(gg, "")
			if not (cc in (d.get("lieu", []) as Array)):
				print("LORE    hors salle : %-22s voulait %s, a atterri en '%s'"
						% [d["id"], str(d.get("lieu", [])), cc])
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
		# On balaie les postures plausibles d'un joueur qui s'approche : QUATRE
		# directions d'approche, reculs de 0.8 à 2.0 m, regard de 30° à 50° vers
		# le bas. N'essayer qu'une direction jugeait inaccessible un document
		# adossé au mur de ce côté-là, alors qu'on l'attrape très bien en
		# faisant le tour.
		for dir in [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
			for d in [0.8, 1.2, 1.6, 2.0]:
				for pitch in [-0.9, -0.7, -0.5]:
					# les PIEDS au niveau du sol : l'origine du joueur est à ses
					# pieds et la caméra se place au-dessus. Ajouter une hauteur
					# ici éloignait la caméra du sol au point que le rayon
					# n'atteignait plus rien du tout.
					player.global_position = pos + dir * d
					player.set_look(atan2(dir.x, dir.z), pitch)
					player.ray.force_raycast_update()
					var t := player.current_target()
					if t != null and t.get_script() == preload("res://scripts/Document.gd"):
						postures += 1
		total_postures += postures
		if postures >= 6:
			vises += 1
		else:
			var gg: Vector2i = level.world_to_cell(pos)
			print("LORE    peu saisissable : %-22s %d/48 postures, en '%s' a (%.1f,%.1f)"
					% [level.document_spawns[i]["id"], postures,
					   level._cells.get(gg, "?"), pos.x, pos.z])
	print("LORE  attrapables confortablement : %d / %d  (%.1f postures valides sur 48 en moyenne)"
			% [vises, essais, float(total_postures) / maxi(essais, 1)])
	if vises < essais:
		print("LORE  ! des documents sont visibles mais penibles ou impossibles a ramasser")
		ok = false

	# --- 4 ter. un document lu ne doit plus reparaitre ---
	var lus_test := 5
	for i in lus_test:
		GameState.lire_document(str(Lore.DOCUMENTS[i]["id"]))
	level.document_spawns.clear()
	level._placer_documents()
	var restants: int = level.document_spawns.size()
	var revenus := []
	for e in level.document_spawns:
		if GameState.a_lu(str(e["id"])):
			revenus.append(e["id"])
	print("LORE  apres %d documents lus : %d places (attendu %d)"
			% [lus_test, restants, Lore.total() - lus_test])
	if restants != Lore.total() - lus_test or not revenus.is_empty():
		print("LORE  ! des documents deja lus reapparaissent : %s" % str(revenus))
		ok = false
	# tout lu : une descente sans document doit rester constructible
	for d in Lore.DOCUMENTS:
		GameState.lire_document(str(d["id"]))
	level.document_spawns.clear()
	level._placer_documents()
	var apres_tout: int = level.document_spawns.size()
	print("LORE  tout lu : %d documents places (attendu 0)" % apres_tout)
	if apres_tout != 0:
		ok = false
	GameState.documents_lus.clear()

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


## Ambiance : nappes, bruits isolés, nappes musicales.
##
## Le risque propre à ce système est d'un genre particulier : il ne plante pas,
## il DÉSÉQUILIBRE. Un son d'ambiance que la Veilleuse entendrait ferait punir
## le joueur pour un bruit qu'il n'a pas fait ; une nappe qui se déclencherait
## pendant une traque couvrirait l'information dont il a le plus besoin.
func _run_ambiance_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := true
	GameState.set_phase(GameState.Phase.JEU, true)

	# --- 1. tous les sons déclarés existent réellement ---
	var manquants := []
	for b in ambiance.BRUITS:
		if Audio.stream(str(b["son"])) == null:
			manquants.append(b["son"])
	for m in ambiance.MUSIQUES:
		if Audio.stream(str(m)) == null:
			manquants.append(m)
	print("AMB  %d bruits + %d nappes musicales declares, introuvables : %s"
			% [ambiance.BRUITS.size(), ambiance.MUSIQUES.size(), str(manquants)])
	if not manquants.is_empty() or ambiance.BRUITS.size() < 8:
		ok = false

	# --- 2. AUCUN son d'ambiance ne doit atteindre la Veilleuse ---
	var entendus := 0
	var temoin := func(_p, _r, _k): entendus += 1
	NoiseBus.noise.connect(temoin)
	for i in 40:
		ambiance.provoquer("bruit")
	ambiance.provoquer("musique")
	NoiseBus.noise.disconnect(temoin)
	print("AMB  40 bruits + 1 nappe : %d ont atteint le bus sonore (attendu 0)" % entendus)
	if entendus != 0:
		print("AMB  ! l'ambiance nourrit la perception de la Veilleuse")
		ok = false

	# --- 3. la variété est réelle ---
	var uniques := {}
	for s2 in ambiance.joues:
		uniques[s2] = true
	var repets := 0
	for i in range(1, ambiance.joues.size()):
		if ambiance.joues[i] == ambiance.joues[i - 1]:
			repets += 1
	print("AMB  sur %d declenchements : %d sons differents, %d repetitions immediates"
			% [ambiance.joues.size(), uniques.size(), repets])
	if uniques.size() < 8 or repets > 0:
		print("AMB  ! pas assez de variete, ou un son se repete d'affilee")
		ok = false

	# --- 4. silence pendant la traque ---
	# On place la Veilleuse en chasse et on laisse tourner : rien ne doit partir.
	if veilleuse:
		veilleuse.etat = Veilleuse.Etat.CHASSE
		ambiance.veilleuse = veilleuse
		ambiance._t_bruit = 0.05
		ambiance._t_musique = 0.05
		var avant: int = ambiance.joues.size()
		for f in 90:
			await get_tree().process_frame
		var pendant: int = ambiance.joues.size() - avant
		print("AMB  en traque, sur 90 images : %d declenchements (attendu 0)" % pendant)
		if pendant != 0:
			ok = false
		veilleuse.etat = Veilleuse.Etat.PATROUILLE
		# et hors traque, ça repart
		ambiance._t_bruit = 0.05
		var avant2: int = ambiance.joues.size()
		for f in 30:
			await get_tree().process_frame
		var apres: int = ambiance.joues.size() - avant2
		print("AMB  hors traque, sur 30 images : %d declenchements (attendu >=1)" % apres)
		if apres < 1:
			ok = false

	# --- 5. les nappes de fond sont armées et bouclent ---
	#
	# On ne teste PAS `playing` : ce conteneur n'a pas de carte son, et
	# music_chase — antérieure à ce travail et parfaitement fonctionnelle en
	# jeu — s'y déclare également à l'arrêt. Ce qui est vérifiable ici, c'est
	# que chaque nappe porte bien un flux et qu'il est marqué bouclant : une
	# nappe non bouclée s'arrêterait au bout de dix secondes, laissant le
	# sous-sol muet pour le reste de la partie.
	var nappes := {"cave": ambiance._cave, "souffle": ambiance._souffle,
			"horloge": ambiance._horloge}
	var defauts := []
	for nom in nappes:
		var j: AudioStreamPlayer = nappes[nom]
		var flux := j.stream as AudioStreamWAV
		if flux == null or flux.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			defauts.append(nom)
	print("AMB  nappes armees et bouclantes : %d/3, defaillantes %s"
			% [3 - defauts.size(), str(defauts)])
	if not defauts.is_empty():
		ok = false

	# --- 6. chaque son part sur le bon bus, pour que les réglages agissent ---
	var bus_ok: bool = ambiance._cave.bus == "Ambiance" \
			and ambiance._souffle.bus == "Ambiance" \
			and ambiance._horloge.bus == "Ambiance" \
			and ambiance._musique.bus == "Musique"
	print("AMB  bus : nappes=%s musique=%s" % [ambiance._cave.bus, ambiance._musique.bus])
	if not bus_ok:
		ok = false

	print("AMB RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


## Commandes tactiles.
##
## Ce qui casse en silence ici : un bouton qui en recouvre un autre (les
## positions sont posées à la main), une action qui reste enfoncée après que
## les commandes ont disparu, ou un manche qui ne rendrait que du tout-ou-rien
## là où le jeu attend une force analogique.
func _run_tactile_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := true
	Tactile.forcer(true)
	GameState.set_phase(GameState.Phase.JEU, true)
	await get_tree().process_frame

	print("TACT  mode tactile=%s  commandes visibles=%s" % [Tactile.actif, tactile.visible])
	if not Tactile.actif or not tactile.visible:
		ok = false

	# --- 1. aucun bouton n'en recouvre un autre, et tous tiennent à l'écran ---
	var ecran := get_viewport().get_visible_rect()
	# tactile est typé CanvasLayer : l'accès à ses membres rend du Variant
	var noms: Array = tactile._boutons.keys()
	var chevauche := 0
	var dehors := []
	for i in noms.size():
		var ra: Rect2 = (tactile._boutons[noms[i]] as Control).get_global_rect()
		if not ecran.encloses(ra):
			dehors.append(noms[i])
		for j in range(i + 1, noms.size()):
			var rb: Rect2 = (tactile._boutons[noms[j]] as Control).get_global_rect()
			if ra.intersects(rb):
				print("TACT  ! %s recouvre %s" % [noms[i], noms[j]])
				chevauche += 1
	print("TACT  %d boutons : %d chevauchements, hors ecran %s  (ecran %.0fx%.0f)"
			% [noms.size(), chevauche, str(dehors), ecran.size.x, ecran.size.y])
	if chevauche > 0 or not dehors.is_empty():
		ok = false

	# --- 2. le manche rend une force ANALOGIQUE, pas du tout-ou-rien ---
	var centre: Vector2 = Vector2(ecran.size.x * 0.22, ecran.size.y * 0.7)
	tactile._poser(0, centre)
	tactile._maj_manche(centre + Vector2(0, -tactile.RAYON * 0.5))
	var demi: float = Input.get_action_strength("move_forward")
	var sprint_demi := Input.is_action_pressed("sprint")
	tactile._maj_manche(centre + Vector2(0, -tactile.RAYON))
	var plein: float = Input.get_action_strength("move_forward")
	var sprint_plein := Input.is_action_pressed("sprint")
	tactile._maj_manche(centre + Vector2(tactile.RAYON, 0))
	var droite: float = Input.get_action_strength("move_right")
	print("TACT  manche : moitie avant=%.2f (course=%s)  plein avant=%.2f (course=%s)  plein droite=%.2f"
			% [demi, sprint_demi, plein, sprint_plein, droite])
	if absf(demi - 0.5) > 0.12 or plein < 0.97 or droite < 0.97 \
			or sprint_demi or not sprint_plein:
		print("TACT  ! le manche ne restitue pas une force analogique correcte")
		ok = false

	tactile._lever(0, centre)
	var relache: bool = Input.get_action_strength("move_forward") == 0.0 \
			and not Input.is_action_pressed("sprint")
	print("TACT  doigt leve : tout relache=%s" % relache)
	if not relache:
		ok = false

	# --- 3. chaque bouton presse SON action, et la relâche ---
	var mauvais := []
	for action in tactile._boutons:
		var b: Control = tactile._boutons[action]
		var c: Vector2 = b.get_global_rect().get_center()
		tactile._poser(1, c)
		var presse: bool = Input.is_action_pressed(action)
		tactile._lever(1, c)
		var laché: bool = not Input.is_action_pressed(action)
		if not presse or not laché:
			mauvais.append(action)
	print("TACT  boutons : %d testes, defaillants %s" % [tactile._boutons.size(), str(mauvais)])
	if not mauvais.is_empty():
		ok = false

	# --- 4. rien ne reste enfoncé quand les commandes disparaissent ---
	#
	# C'est le piège du bouton pause : il change la phase, donc masque les
	# commandes, et le doigt qui se lève n'est alors plus reçu — l'action
	# resterait enfoncée et on rebasculerait en pause aussitôt sorti.
	#
	# On presse le bouton et on laisse LE JEU réagir, sans forcer la phase à la
	# main : forcer en plus du bouton provoquait un double basculement qui
	# remettait en jeu, et le test mesurait alors sa propre interférence.
	# Le doigt n'est volontairement jamais levé : c'est tout le sujet.
	tactile._poser(2, (tactile._boutons["pause"] as Control).get_global_rect().get_center())
	for f in 4:
		await get_tree().process_frame
	print("TACT  bouton pause : phase=%s" % [GameState.phase == GameState.Phase.PAUSE])
	if GameState.phase != GameState.Phase.PAUSE:
		ok = false
	var coince := []
	for a in ["pause", "interact", "hold_breath", "crouch", "flashlight",
			"move_forward", "sprint"]:
		if Input.is_action_pressed(a):
			coince.append(a)
	print("TACT  apres masquage : commandes visibles=%s  actions restees enfoncees %s"
			% [tactile.visible, str(coince)])
	if tactile.visible or not coince.is_empty():
		ok = false

	# --- 5. la visée passe par le même chemin que la souris ---
	GameState.set_phase(GameState.Phase.JEU, true)
	await get_tree().process_frame
	player.set_look(0.0, 0.0)
	var avant: float = player._yaw
	player.tourner(Vector2(120, 0))
	var apres: float = player._yaw
	# tourner() met à jour le lacet ; c'est _physics_process qui le reporte sur
	# le noeud, d'où l'attente avant de vérifier que la vue a réellement pivoté
	await get_tree().physics_frame
	await get_tree().physics_frame
	var applique: float = player.rotation.y
	print("TACT  visee : lacet %.3f -> %.3f, rotation du noeud %.3f"
			% [avant, apres, applique])
	if absf(apres - avant) < 0.01 or absf(applique - apres) > 0.01:
		ok = false

	# --- 4 bis. DEUX DOIGTS À LA FOIS : avancer en regardant autour ---
	# Le geste normal du jeu, et celui qu'aucune vérification ne couvrait :
	# les doigts étaient posés puis levés l'un après l'autre.
	GameState.set_phase(GameState.Phase.JEU, true)
	await get_tree().process_frame
	player.set_look(0.0, 0.0)
	var g := Vector2(ecran.size.x * 0.22, ecran.size.y * 0.7)
	var d := Vector2(ecran.size.x * 0.78, ecran.size.y * 0.5)
	tactile._poser(0, g)                      # pouce gauche : le manche
	tactile._poser(1, d)                      # pouce droit : la visée
	print("TACT  deux doigts : manche=%d visee=%d" % [tactile._doigt_manche, tactile._doigt_visee])
	tactile._maj_manche(g + Vector2(0, -tactile.RAYON))
	var av_yaw: float = player._yaw
	# on simule le glissement du pouce droit comme le fait l'evenement reel
	for k in 10:
		var ev := InputEventScreenDrag.new()
		ev.index = 1
		ev.position = d + Vector2(k * 6, 0)
		ev.relative = Vector2(6, 0)
		tactile._unhandled_input(ev)
	var avance: float = Input.get_action_strength("move_forward")
	var tourne: float = absf(player._yaw - av_yaw)
	print("TACT  en glissant a droite : avance=%.2f  rotation=%.3f rad" % [avance, tourne])
	if avance < 0.9:
		print("TACT  ! regarder autour interrompt le deplacement")
		ok = false
	if tourne < 0.01:
		print("TACT  ! avancer empeche de regarder autour")
		ok = false
	# et l'inverse : bouger le manche ne doit pas faire tourner la tete
	var yaw2: float = player._yaw
	for k in 8:
		var ev2 := InputEventScreenDrag.new()
		ev2.index = 0
		ev2.position = g + Vector2(k * 5, -tactile.RAYON)
		ev2.relative = Vector2(5, 0)
		tactile._unhandled_input(ev2)
	var parasite: float = absf(player._yaw - yaw2)
	print("TACT  en bougeant le manche : rotation parasite=%.4f rad (attendu 0)" % parasite)
	if parasite > 0.0001:
		print("TACT  ! le manche fait pivoter la vue")
		ok = false
	# le pouce droit se pose SUR un bouton puis glisse : il doit viser
	var bcoin: Control = tactile._boutons["hold_breath"]
	var pb: Vector2 = bcoin.get_global_rect().get_center()
	var yaw3: float = player._yaw
	tactile._lever(1, d)
	tactile._poser(1, pb)
	var presse_dabord: bool = Input.is_action_pressed("hold_breath")
	for k in 8:
		var ev3 := InputEventScreenDrag.new()
		ev3.index = 1
		ev3.position = pb + Vector2(-14 * k, -6 * k)
		ev3.relative = Vector2(-14, -6)
		tactile._unhandled_input(ev3)
	var rendu: bool = not Input.is_action_pressed("hold_breath")
	var vise: float = absf(player._yaw - yaw3)
	print("TACT  doigt pose SUR un bouton puis glisse : bouton presse=%s puis relache=%s, rotation=%.3f rad"
			% [presse_dabord, rendu, vise])
	if not presse_dabord or not rendu or vise < 0.01:
		print("TACT  ! un doigt parti d'un bouton ne peut jamais viser")
		ok = false
	tactile._lever(1, pb)

	# un SECOND doigt posé à gauche doit viser aussi, pas être ignoré
	var yaw4: float = player._yaw
	tactile._poser(2, Vector2(ecran.size.x * 0.30, ecran.size.y * 0.35))
	for k in 6:
		var ev4 := InputEventScreenDrag.new()
		ev4.index = 2
		ev4.position = Vector2(ecran.size.x * 0.30 + 12 * k, ecran.size.y * 0.35)
		ev4.relative = Vector2(12, 0)
		tactile._unhandled_input(ev4)
	var vise2: float = absf(player._yaw - yaw4)
	print("TACT  second doigt a gauche : rotation=%.3f rad" % vise2)
	if vise2 < 0.01:
		print("TACT  ! un second doigt pose a gauche est ignore")
		ok = false
	tactile._lever(2, Vector2(ecran.size.x * 0.30, ecran.size.y * 0.35))

	tactile._lever(0, g)

	# --- 4 ter. tourner EN MARCHANT ne doit pas faire basculer la vue ---
	# cam.rotation.z s'incline selon l'angle entre la vitesse et le cap. Quand
	# on pivote tout en avançant, la vitesse acquise devient un « pas de côté »
	# aux yeux de cette formule, et la caméra roule.
	GameState.set_phase(GameState.Phase.JEU, true)
	player.set_look(0.0, 0.0)
	player.can_move = true
	Input.action_press("move_forward", 1.0)
	Input.action_press("sprint")
	for f in 40:
		await get_tree().physics_frame
	var v_avant: float = player.velocity.length()
	var roulis_max := 0.0
	# demi-tour rapide, comme un joueur qui se retourne en fuyant
	for f in 30:
		player.tourner(Vector2(26, 0))
		await get_tree().physics_frame
		roulis_max = maxf(roulis_max, absf(player.cam.rotation.z))
	Input.action_release("move_forward")
	Input.action_release("sprint")
	print("TACT  demi-tour en courant (%.1f m/s) : roulis maximal %.4f rad = %.2f degres"
			% [v_avant, roulis_max, rad_to_deg(roulis_max)])
	if rad_to_deg(roulis_max) > 4.0:
		print("TACT  ! la vue bascule visiblement quand on tourne en marchant")
		ok = false

	# --- 5 bis. la souris émulée ne doit PAS pivoter la vue ---
	# Godot fabrique des événements souris à partir des touchers. Sans garde,
	# un glissement de visée s'appliquait deux fois, et le manche de
	# déplacement faisait tourner la tête en même temps qu'avancer.
	player.set_look(0.0, 0.0)
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(200, 0)
	player._input(mm)
	var bouge_tactile: float = absf(player._yaw)
	Tactile.forcer(false)
	player.set_look(0.0, 0.0)
	player._input(mm)
	var bouge_clavier: float = absf(player._yaw)
	Tactile.forcer(true)
	print("TACT  motion souris : en tactile lacet=%.3f (attendu 0)  en clavier lacet=%.3f (doit bouger)"
			% [bouge_tactile, bouge_clavier])
	if bouge_tactile > 0.0001 or bouge_clavier < 0.01:
		print("TACT  ! la souris emulee pivote la vue en plus du doigt")
		ok = false

	# --- 6. les menus offrent des cibles au doigt ---
	var h_tactile: int = Tactile.hauteur_bouton()
	Tactile.forcer(false)
	var h_clavier: int = Tactile.hauteur_bouton()
	Tactile.forcer(true)
	print("TACT  hauteur de bouton : tactile %d px, clavier %d px" % [h_tactile, h_clavier])
	if h_tactile < 44 or h_tactile <= h_clavier:
		ok = false

	Tactile.forcer(false)
	print("TACT RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


## Prologue et crédits : les deux ajouts qui bouclent la V1.
##
## Ce qu'on vérifie ici est ce qui casse en silence : un prologue impossible à
## passer (on recommence souvent, une descente étant tirée au sort), un
## prologue qui ne rend jamais la main, un texte qui déborde de l'écran, ou des
## crédits dont le bouton de sortie part hors cadre.
func _run_v1_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var ok := true

	# --- 1. découpage du prologue, et tenue à l'écran ---
	GameState.montrer_prologue = true
	GameState.set_phase(GameState.Phase.PROLOGUE, true)
	await get_tree().process_frame
	var temps: PackedStringArray = prologue._temps
	print("V1  prologue : %d temps, frappe cumulee %.1f s, monde fige=%s"
			% [temps.size(), prologue.duree_frappe(), get_tree().paused])
	if temps.size() < 4 or not get_tree().paused:
		ok = false
	var trop_long := []
	for b in temps:
		var lignes: PackedStringArray = (b as String).split("\n")
		# on affiche à 21 px avec 11 px d'interligne : au-delà de 6 lignes, ou
		# d'une ligne de plus de 64 signes, le bloc sort du cadre
		if lignes.size() > 6:
			trop_long.append(b)
		for l in lignes:
			if (l as String).length() > 64:
				trop_long.append(l)
	print("V1  prologue : %d temps trop longs pour l'ecran (attendu 0)" % trop_long.size())
	if not trop_long.is_empty():
		print("V1  ! %s" % str(trop_long).substr(0, 160))
		ok = false

	# --- 1 bis. l'enchaînement est MANUEL ---
	# C'est le cœur de la correction : un paragraphe affiché doit attendre le
	# joueur. S'il repartait tout seul au bout d'un délai, la lecture
	# redeviendrait une course, et le défaut serait revenu sans bruit.
	prologue._texte.visible_characters = prologue._texte.text.length()
	prologue._montres = float(prologue._texte.text.length())
	for f in 4:
		await get_tree().process_frame
	var en_attente: bool = prologue._etat == prologue.Etat.ATTENTE
	var index_avant: int = prologue._i
	# on laisse passer largement de quoi voir un enchaînement automatique
	for f in 150:
		await get_tree().process_frame
	var reste: bool = prologue._i == index_avant \
			and prologue._etat == prologue.Etat.ATTENTE
	print("V1  paragraphe affiche : etat ATTENTE=%s, puis 150 images sans touche -> temps %d (etait %d), immobile=%s"
			% [en_attente, prologue._i, index_avant, reste])
	if not en_attente or not reste:
		print("V1  ! un paragraphe avance sans le joueur")
		ok = false

	# L'invite doit dire ce que l'entrée fait maintenant, ET le saut doit
	# rester accessible. Les deux prennent une forme différente selon le mode :
	# au clavier tout tient dans la ligne d'invite, au doigt le saut devient un
	# bouton — un doigt ne peut pas presser Échap.
	var invite: String = prologue._invite.text
	var avance_nommee: bool = "continuer" in invite or "descendre" in invite
	var saut_possible: bool = ("passer" in invite) if not Tactile.actif \
			else (prologue._passer != null and prologue._passer.visible)
	print("V1  invite en attente : \"%s\"  (mode %s, saut accessible=%s)"
			% [invite, "tactile" if Tactile.actif else "clavier", saut_possible])
	if not avance_nommee or not saut_possible:
		print("V1  ! l'avance ou le saut n'est pas accessible dans ce mode")
		ok = false

	# une pression fait bien avancer d'UN temps
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	for f in 40:
		await get_tree().process_frame
	var avance: bool = prologue._i == index_avant + 1
	print("V1  apres une pression : temps %d (attendu %d)" % [prologue._i, index_avant + 1])
	if not avance:
		ok = false

	# --- 2. il rend la main, et on peut le passer ---
	prologue._terminer()
	var rendu: bool = GameState.phase == GameState.Phase.JEU and not get_tree().paused
	print("V1  prologue passe : phase=%s  monde relance=%s"
			% [GameState.phase == GameState.Phase.JEU, not get_tree().paused])
	if not rendu:
		ok = false

	# --- 3. une reprise ne le rejoue pas ---
	GameState.nouvelle_descente()
	var neuve: bool = GameState.montrer_prologue
	GameState.fuses_installed = 2
	GameState.poser_point_de_controle()
	GameState.reprendre()
	var reprise: bool = GameState.montrer_prologue
	print("V1  descente neuve -> prologue=%s   reprise -> prologue=%s" % [neuve, reprise])
	if not neuve or reprise:
		ok = false
	GameState.effacer_point_de_controle()

	# --- 4. crédits : contenu réel et sortie atteignable ---
	menu._afficher(menu.Ecran.CREDITS)
	await get_tree().process_frame
	await get_tree().process_frame
	var textes := ""
	for c in menu._boite.get_children():
		if c is Label:
			textes += (c as Label).text + "\n"
	var attendus := ["Liam RIIS", "Godot", "Owlish", "rubberduck", "Fantozzi",
			"qubodup", "Spring Spring", "Ogrebane", "CC0", "Blender"]
	var absents := []
	for a in attendus:
		if not (a in textes):
			absents.append(a)
	print("V1  credits : %d lignes, mentions manquantes %s"
			% [textes.split("\n").size() - 1, str(absents)])
	if not absents.is_empty():
		ok = false
	var haut_contenu: float = menu._boite.get_combined_minimum_size().y
	var haut_vue: float = menu._defilement.size.y
	var sortie := _trouver_bouton(menu, "Retour")
	var atteignable: bool = sortie != null and (haut_contenu <= haut_vue
			or menu._defilement.get_v_scroll_bar().max_value >= haut_contenu - 1.0)
	print("V1  credits : contenu %.0f px, vue %.0f px, sortie atteignable=%s"
			% [haut_contenu, haut_vue, atteignable])
	if not atteignable:
		ok = false
	menu._afficher(menu.Ecran.AUCUN)

	print("V1 RESULTAT : %s" % ("OK" if ok else "ECHEC"))
	get_tree().quit()


## Une descente tirée au sort est-elle TERMINABLE ?
##
## C'est la question que pose le hasard : un fusible derrière un meuble qui
## cloisonne, un tableau électrique coupé du reste, et la partie devient
## impossible — sans rien casser visiblement. On vérifie donc qu'un chemin
## existe réellement, avec le même A* que la Veilleuse, du point de départ du
## joueur vers chaque objectif.
func _run_seed_check() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var pbs: Array[String] = []

	if veilleuse == null:
		pbs.append("pas de Veilleuse")
	else:
		# On passe par _nearest_free, comme la Veilleuse : une case peut porter
		# l'emprise d'un meuble et compter pour bloquée alors qu'on s'y tient
		# parfaitement — le joueur lui-même apparaît sur une telle case.
		var depart: Vector2i = veilleuse._nearest_free(
				level.world_to_grid(player.global_position))
		var joignable := func(cible: Vector3, nom: String) -> void:
			var g: Vector2i = veilleuse._nearest_free(level.world_to_grid(cible))
			if dbg_verbose:
				print("SEEDCHECK  diag %-28s pos=(%.1f,%.1f) brute=%s libre=%s bornes=%s solide=%s"
						% [nom, cible.x, cible.z, level.world_to_grid(cible), g,
						   veilleuse._astar.is_in_boundsv(g),
						   veilleuse._astar.is_point_solid(g) if veilleuse._astar.is_in_boundsv(g) else "hors"])
			if not veilleuse._astar.is_in_boundsv(g) or veilleuse._astar.is_point_solid(g):
				pbs.append("%s hors navigation" % nom)
				return
			if g != depart and veilleuse._astar.get_id_path(depart, g).is_empty():
				pbs.append("%s injoignable" % nom)

		if level.fuse_spawns.size() != GameState.FUSES_REQUIRED:
			pbs.append("%d fusibles au lieu de %d"
					% [level.fuse_spawns.size(), GameState.FUSES_REQUIRED])
		for i in level.fuse_spawns.size():
			joignable.call(level.fuse_spawns[i], "fusible %d" % (i + 1))

		# On vise les points d'ACCÈS, pas les objets : le tableau est encastré
		# dans le mur et la grille du monte-charge est infranchissable — leurs
		# positions propres sont solides par construction.
		if get_tree().get_first_node_in_group("fusebox") == null:
			pbs.append("tableau electrique absent")
		else:
			joignable.call(level.acces_tableau, "acces au tableau")

		if get_tree().get_first_node_in_group("exit") == null:
			pbs.append("monte-charge absent")
		else:
			joignable.call(level.acces_sortie, "acces au monte-charge")

		joignable.call(veilleuse.global_position, "apparition de la Veilleuse")

		for e in level.document_spawns:
			joignable.call(e["pos"], "document %s" % e["id"])

	var attendus := 0
	for d in Lore.DOCUMENTS:
		if not GameState.a_lu(str(d["id"])):
			attendus += 1
	if level.document_spawns.size() != attendus:
		pbs.append("%d documents places au lieu de %d"
				% [level.document_spawns.size(), attendus])
	if level.battery_spawns.is_empty():
		pbs.append("aucune pile")
	if get_tree().get_nodes_in_group("hiding").is_empty():
		pbs.append("aucune cachette")

	if pbs.is_empty():
		print("SEEDCHECK %d OK  (fusibles %d, docs %d, piles %d, cachettes %d)"
				% [GameState.graine, level.fuse_spawns.size(),
				   level.document_spawns.size(), level.battery_spawns.size(),
				   get_tree().get_nodes_in_group("hiding").size()])
	else:
		print("SEEDCHECK %d ECHEC : %s" % [GameState.graine, " | ".join(pbs)])
	get_tree().quit()


## Empreinte d'une descente : de quoi comparer objectivement deux graines.
func _run_seed_report() -> void:
	await get_tree().process_frame
	var f := []
	for p in level.fuse_spawns:
		f.append("(%.0f,%.0f)" % [p.x, p.z])
	var d := []
	for e in level.document_spawns:
		d.append("(%.0f,%.0f)" % [(e["pos"] as Vector3).x, (e["pos"] as Vector3).z])
	var props: int = level.get_node("Props").get_child_count() if level.has_node("Props") else -1
	# Plan de ce qui reste navigable après élagage. Une salle entièrement
	# amputée saute aux yeux ici, là où un simple total ne dit pas OÙ.
	print("SEEDCHECK  plan (minuscule = amputee, . = vide) :")
	for y in level.carte.size():
		var ligne := ""
		for x in (level.carte[y] as String).length():
			var c: String = (level.carte[y] as String)[x]
			if c == ".":
				ligne += "."
				continue
			var libres := 0
			var g0: Vector2i = level.world_to_grid(level.world_of(x, y) - Vector3(1.9, 0, 1.9))
			var g1: Vector2i = level.world_to_grid(level.world_of(x, y) + Vector3(1.9, 0, 1.9))
			for gy in range(g0.y, g1.y + 1):
				for gx in range(g0.x, g1.x + 1):
					if not level.solid_grid.has(Vector2i(gx, gy)):
						libres += 1
			ligne += c if libres > 0 else c.to_lower()
		print("    " + ligne)
	print("SEED %d | fusibles %s | piles %d | docs %s | props %d | cases_libres %d | rondes %d"
			% [dbg_seed, " ".join(f), level.battery_spawns.size(), " ".join(d),
			   props, level.nav_reachable, level.patrol_points.size()])
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
