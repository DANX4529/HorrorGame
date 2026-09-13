class_name Veilleuse
extends CharacterBody3D
## La Veilleuse.
##
## Elle est AVEUGLE. Son unique perception est le NoiseBus : un bruit
## l'atteint si la distance qui la sépare de la source est inférieure au
## rayon déclaré. Aucun raycast de vision, aucun cône de détection — ce qui
## rend le comportement lisible pour le joueur : ce qu'il entend, elle
## l'entend.

enum Etat { PATROUILLE, INVESTIGATION, CHASSE, ATTAQUE }

signal state_changed(e: Etat)

const V_PATROUILLE := 1.15
const V_INVESTIGATION := 1.60
const V_CHASSE := 3.40
const ROT_VITESSE := 6.0
const PORTEE_TUE := 1.25
const PORTEE_FOUILLE := 1.7       ## distance à laquelle elle fouille une cachette

const PATIENCE_INVESTIGATION := 12.0
const PATIENCE_CHASSE := 7.5
const SEUIL_CHASSE := 14.0        ## un bruit de ce rayon ou plus déclenche la chasse
const REPATH := 0.45

var etat: Etat = Etat.PATROUILLE
var level: Node3D
var player: Player

var _astar := AStarGrid2D.new()
var _path: PackedVector3Array = []
var _path_i := 0
var _repath_t := 0.0
var _target := Vector3.ZERO
var _patience := 0.0
var _patrol_i := 0
var _anim: AnimationPlayer
var _model: Node3D
var _rasp: AudioStreamPlayer3D
var _step_t := 0.0
var _cur_anim := ""
var _spawn_grace := 6.0
var _last_heard_kind := ""
var _rng := RandomNumberGenerator.new()
var _door_ray: RayCast3D
var _stuck_t := 0.0
var _stuck_ref := Vector3.ZERO


func setup(lvl: Node3D, pl: Player) -> void:
	level = lvl
	player = pl


func _ready() -> void:
	add_to_group("veilleuse")
	_rng.randomize()
	collision_layer = 4
	collision_mask = 1
	floor_max_angle = deg_to_rad(60)

	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.34
	caps.height = 1.90
	col.shape = caps
	col.position.y = 0.95
	add_child(col)

	_model = load("res://assets/models/char/veilleuse.glb").instantiate()
	add_child(_model)
	MaterialLib.apply(_model)
	_anim = _find_anim(_model)
	if _anim:
		for n in _anim.get_animation_list():
			if n != "attack":
				var a := _anim.get_animation(n)
				a.loop_mode = Animation.LOOP_LINEAR
	_play("idle")

	_rasp = AudioStreamPlayer3D.new()
	_rasp.stream = Audio.stream("entity_rasp", true)
	_rasp.max_distance = 26.0
	_rasp.unit_size = 4.0
	_rasp.volume_db = -14.0
	add_child(_rasp)
	_rasp.play()

	# Elle ouvre les portes. Une créature qu'un battant arrête n'est pas une
	# menace — et le grincement qui la précède renseigne le joueur sur sa
	# position, ce qui rend la traque lisible plutôt qu'arbitraire.
	_door_ray = RayCast3D.new()
	_door_ray.target_position = Vector3(0, 0, -1.55)
	_door_ray.position = Vector3(0, 1.05, 0)
	_door_ray.collision_mask = 1
	add_child(_door_ray)

	_build_astar()
	_stuck_ref = global_position
	NoiseBus.noise.connect(_on_noise)
	# la position définitive est posée par Main juste après add_child :
	# on attend une image avant de calculer la première ronde.
	await get_tree().process_frame
	_next_patrol()


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null


# ==========================================================================
#  Navigation
# ==========================================================================
func _build_astar() -> void:
	_astar.region = level.nav_rect
	_astar.cell_size = Vector2(level.NAV_RES, level.NAV_RES)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for g in level.solid_grid:
		if _astar.is_in_boundsv(g):
			_astar.set_point_solid(g, true)


func _nearest_free(g: Vector2i) -> Vector2i:
	if _astar.is_in_boundsv(g) and not _astar.is_point_solid(g):
		return g
	for r in range(1, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := g + Vector2i(dx, dy)
				if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
					return c
	return g


func _set_path_to(w: Vector3) -> void:
	var a := _nearest_free(level.world_to_grid(global_position))
	var b := _nearest_free(level.world_to_grid(w))
	var ids := _astar.get_id_path(a, b)
	if ids.is_empty() and a != b:
		push_warning("Veilleuse: pas de chemin %s->%s (region=%s, a_solide=%s b_solide=%s, a_bornes=%s b_bornes=%s)"
				% [a, b, _astar.region, _astar.is_point_solid(a) if _astar.is_in_boundsv(a) else "hors",
				   _astar.is_point_solid(b) if _astar.is_in_boundsv(b) else "hors",
				   _astar.is_in_boundsv(a), _astar.is_in_boundsv(b)])
	_path = PackedVector3Array()
	for id in ids:
		_path.append(level.grid_to_world(id))
	_path_i = 0
	# on saute le premier point s'il est déjà derrière nous
	if _path.size() > 1 and global_position.distance_to(_path[0]) < level.NAV_RES:
		_path_i = 1


# ==========================================================================
#  Perception
# ==========================================================================
func _on_noise(pos: Vector3, radius: float, kind: String) -> void:
	if GameState.phase != GameState.Phase.JEU or _spawn_grace > 0.0:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	_last_heard_kind = kind

	match etat:
		Etat.PATROUILLE:
			_target = pos
			_patience = PATIENCE_INVESTIGATION
			if radius >= SEUIL_CHASSE:
				_enter(Etat.CHASSE)
			else:
				_enter(Etat.INVESTIGATION)
				Audio.play_2d("stinger_detect", -20.0)
			_repath_t = 0.0
		Etat.INVESTIGATION:
			_target = pos
			_patience = PATIENCE_INVESTIGATION
			# un bruit fort, ou proche, transforme le doute en certitude
			if radius >= SEUIL_CHASSE or d < 6.5:
				_enter(Etat.CHASSE)
			_repath_t = 0.0
		Etat.CHASSE:
			_target = pos
			_patience = PATIENCE_CHASSE


func is_hunting() -> bool:
	return etat == Etat.CHASSE or etat == Etat.ATTAQUE


# ==========================================================================
#  Boucle principale
# ==========================================================================
func _physics_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.JEU:
		velocity = Vector3.ZERO
		return
	if _spawn_grace > 0.0:
		_spawn_grace -= delta

	_repath_t -= delta
	_patience -= delta

	match etat:
		Etat.PATROUILLE: _tick_patrouille(delta)
		Etat.INVESTIGATION: _tick_investigation(delta)
		Etat.CHASSE: _tick_chasse(delta)
		Etat.ATTAQUE: _tick_attaque(delta)

	_open_door_ahead()
	_unstick(delta)
	_update_audio(delta)
	_check_catch()


## Ouvre le battant qui lui barre la route.
func _open_door_ahead() -> void:
	if _door_ray == null or not _door_ray.is_colliding():
		return
	var c = _door_ray.get_collider()
	while c != null and not c.has_method("interact"):
		c = c.get_parent()
	if c != null and c.is_in_group("door") and not c.open:
		c.interact(self)


## Filet de sécurité : si elle n'avance plus alors qu'un chemin existe
## (battant coincé, meuble poussé, angle serré), on recalcule et on la décale
## légèrement plutôt que de la laisser vibrer contre un mur.
func _unstick(delta: float) -> void:
	if _path_i >= _path.size():
		_stuck_t = 0.0
		_stuck_ref = global_position
		return
	_stuck_t += delta
	if _stuck_t < 1.2:
		return
	var moved := _stuck_ref.distance_to(global_position)
	_stuck_t = 0.0
	_stuck_ref = global_position
	if moved > 0.35:
		return
	# vraiment bloquée : on saute le point courant et on recalcule
	_path_i = mini(_path_i + 2, _path.size())
	_repath_t = 0.0
	var side := Vector3(cos(rotation.y), 0, sin(rotation.y)) * 0.25
	global_position += side


func _tick_patrouille(delta: float) -> void:
	if _path_i >= _path.size():
		_next_patrol()
	_advance(delta, V_PATROUILLE)


func _tick_investigation(delta: float) -> void:
	if _repath_t <= 0.0:
		_repath_t = REPATH
		_set_path_to(_target)
	if _path_i >= _path.size():
		# arrivée sur place : elle fouille, immobile, puis renonce
		_advance(delta, 0.0)
		_play("listen")
		if _patience <= 0.0:
			_enter(Etat.PATROUILLE)
			_next_patrol()
		return
	_advance(delta, V_INVESTIGATION)
	if _patience <= 0.0:
		_enter(Etat.PATROUILLE)
		_next_patrol()


func _tick_chasse(delta: float) -> void:
	if is_instance_valid(player):
		# en chasse elle a un cap sur le joueur, mais ne le suit que
		# tant qu'il reste bruyant : se taire finit par la semer
		var pn := player.breath.noise_radius()
		var d := global_position.distance_to(player.global_position)
		if pn > 2.0 or d < 9.0:
			_target = player.global_position
			_patience = maxf(_patience, 2.5)
	if _repath_t <= 0.0:
		_repath_t = REPATH * 0.6
		_set_path_to(_target)
	_advance(delta, V_CHASSE)
	if _patience <= 0.0:
		_enter(Etat.INVESTIGATION)
		_patience = PATIENCE_INVESTIGATION * 0.5


func _tick_attaque(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


func _advance(delta: float, speed: float) -> void:
	if speed <= 0.0 or _path_i >= _path.size():
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		if etat != Etat.INVESTIGATION:
			_play("idle")
		return

	var wp: Vector3 = _path[_path_i]
	var to := wp - global_position
	to.y = 0.0
	if to.length() < 0.32:
		_path_i += 1
		if _path_i >= _path.size():
			return
		wp = _path[_path_i]
		to = wp - global_position
		to.y = 0.0

	var dir := to.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()

	# orientation : le modèle regarde vers -Z, atan2 donne le cap voulu
	var want := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, ROT_VITESSE * delta)

	_play("hunt" if speed > 2.2 else "walk")
	_footsteps(delta, speed)


func _footsteps(delta: float, speed: float) -> void:
	_step_t += delta * (speed / V_PATROUILLE)
	var interval := 0.72
	if _step_t < interval:
		return
	_step_t = 0.0
	var n := _rng.randi_range(1, 3)
	Audio.play_3d("step_entity_%d" % n, global_position, -7.0, _rng.randf_range(0.9, 1.05))


func _next_patrol() -> void:
	var pts: PackedVector3Array = level.patrol_points
	if pts.is_empty():
		return
	# on choisit un point éloigné : elle traverse le bâtiment plutôt que
	# de tourner sur place
	var best := -1
	var best_d := -1.0
	for i in 7:
		var k := _rng.randi() % pts.size()
		var d := global_position.distance_to(pts[k])
		if d > best_d and d > 6.0:
			best_d = d
			best = k
	if best < 0:
		best = _rng.randi() % pts.size()
	_patrol_i = best
	_set_path_to(pts[best])


func _enter(e: Etat) -> void:
	if etat == e:
		return
	etat = e
	state_changed.emit(e)
	match e:
		Etat.CHASSE:
			Audio.play_3d("entity_scream", global_position, -3.0)
			_patience = PATIENCE_CHASSE
		Etat.INVESTIGATION:
			_play("listen")


func _play(name: String) -> void:
	if _anim == null or _cur_anim == name:
		return
	if not _anim.has_animation(name):
		return
	_cur_anim = name
	_anim.play(name, 0.25)


func _update_audio(delta: float) -> void:
	if _rasp == null:
		return
	var base := -16.0
	if etat == Etat.CHASSE:
		base = -6.0
	elif etat == Etat.INVESTIGATION:
		base = -12.0
	_rasp.volume_db = lerpf(_rasp.volume_db, base, delta * 3.0)
	_rasp.pitch_scale = 1.0 if etat != Etat.CHASSE else 1.18


func _check_catch() -> void:
	if etat == Etat.ATTAQUE or not is_instance_valid(player):
		return
	var d := global_position.distance_to(player.global_position)
	if player.is_hidden:
		# Cachée, elle ne voit rien — mais elle entend. Retenir son souffle
		# dans le casier est la seule façon de survivre à une fouille.
		if d < PORTEE_FOUILLE and player.breath.noise_radius() > 2.0:
			_seize()
		return
	if d < PORTEE_TUE:
		_seize()


func _seize() -> void:
	_enter(Etat.ATTAQUE)
	_play("attack")
	if _anim and _anim.has_animation("attack"):
		_anim.play("attack", 0.1)
		_cur_anim = "attack"
	if player.is_hidden:
		player.exit_hiding()
	player.kill(self)
