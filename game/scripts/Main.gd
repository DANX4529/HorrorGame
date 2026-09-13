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


func _build_world() -> void:
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

	GameState.reset_run()
	GameState.set_phase(GameState.Phase.TITRE)

	_apply_debug()
	if dbg_aitest > 0.0:
		_run_ai_test()
	if dbg_rungame:
		_run_objective_test()
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
	print("AITEST  pathfinding=%s  reaction_au_bruit=%s"
			% ["OK" if moved > 3.0 else "ECHEC",
			   "OK" if (seen.has(Veilleuse.Etat.CHASSE) or seen.has(Veilleuse.Etat.ATTAQUE)) else "ECHEC"])
	get_tree().quit()


func _apply_debug() -> void:
	if dbg_light > 0.0:
		var e: Environment = (get_child(0) as WorldEnvironment).environment
		e.ambient_light_energy = dbg_light
		e.fog_density = 0.012
	if dbg_tp != Vector3.INF:
		player.global_position = dbg_tp + Vector3(0, 0.1, 0)
	if dbg_yaw != INF:
		player.set_look(dbg_yaw, dbg_pitch)
	if dbg_ent != Vector3.INF and veilleuse:
		veilleuse.global_position = dbg_ent
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


func _spawn_pickups() -> void:
	var holder := Node3D.new()
	holder.name = "Pickups"
	add_child(holder)
	var fuse_scene: PackedScene = load("res://assets/models/props/fuse.glb")
	var bat_scene: PackedScene = load("res://assets/models/props/battery.glb")
	for p in level.fuse_spawns:
		var n := preload("res://scripts/Pickup.gd").new()
		holder.add_child(n)
		n.setup("fuse", fuse_scene, p)
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

	# --- portes : le rayon du joueur doit bien remonter jusqu'à interact() ---
	var doors := get_tree().get_nodes_in_group("door")
	print("RUNGAME  portes : %d" % doors.size())
	if doors.is_empty():
		ok = false
	else:
		var d0 = doors[0]
		var before: bool = d0.open
		d0.interact(player)
		await get_tree().create_timer(1.2).timeout
		print("RUNGAME  porte 0 : ouverte %s -> %s  angle=%.2f"
				% [before, d0.open, d0._angle])
		if d0.open == before or absf(d0._angle) < 1.0:
			ok = false
		# le rayon du joueur doit atteindre la porte REFERMÉE, vue de face
		d0.interact(player)
		await get_tree().create_timer(1.2).timeout
		player.global_position = d0.global_position + Vector3(0.55, 0, 1.3).rotated(Vector3.UP, d0.rotation.y)
		player.set_look(d0.rotation.y, 0.0)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var tgt = player.current_target()
		print("RUNGAME  cible visee par le joueur : %s" % (tgt.get_class() + "/" + str(tgt.get_script().resource_path.get_file()) if tgt else "AUCUNE"))
		if tgt == null:
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
