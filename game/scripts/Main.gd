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


func _ready() -> void:
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
			# équivalent d'un halètement : audible à 22 m
			NoiseBus.emit_kind(player.global_position, "halètement")
			print("AITEST  t=%.1f  bruit fort emis a %.1f m" % [t, d])
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
	if dbg_ecran != "" and menu:
		match dbg_ecran:
			"titre":    GameState.set_phase(GameState.Phase.TITRE, true)
			"options":  menu._afficher(menu.Ecran.OPTIONS)
			"pause":    GameState.set_phase(GameState.Phase.PAUSE, true)
			"mort":     GameState.set_phase(GameState.Phase.MORT, true)
			"victoire": GameState.set_phase(GameState.Phase.VICTOIRE, true)
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
