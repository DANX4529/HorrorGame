class_name Player
extends CharacterBody3D
## Le joueur. Toute la hiérarchie est construite par code (voir _build).

signal died
signal hide_changed(hidden: bool)

const VITESSE_MARCHE := 2.65
const VITESSE_COURSE := 4.70
const VITESSE_ACCROUPI := 1.35
const ACCEL := 12.0
const FREIN := 14.0
const HAUTEUR_OEIL := 1.66
const HAUTEUR_OEIL_ACCROUPI := 0.98
const HAUTEUR_OEIL_CACHE := 1.34
const SENSIBILITE := 0.0022
const PORTEE_INTERACTION := 2.6
## Combien de morceaux de plâtre on peut porter. Deux, pas dix : le verbe doit
## rester une décision, pas une mitraillette.
const JETABLES_MAX := 2

const BATTERIE_MAX := 90.0
const PAS_INTERVALLE_MARCHE := 0.62
const PAS_INTERVALLE_COURSE := 0.38
const PAS_INTERVALLE_ACCROUPI := 0.90

var breath := BreathSystem.new()
var head: Node3D
var cam: Camera3D
var torch: SpotLight3D
var ray: RayCast3D
var torch_on := false
var battery := BATTERIE_MAX
var crouched := false
var is_hidden := false
var hiding_spot: Node3D = null
var can_move := true

var _yaw := 0.0
var _pitch := 0.0
var _step_t := 0.0
var _bob := 0.0
var _shake := 0.0
var _floor_kind := "lino"
var jetables := 0
var _breath_player: AudioStreamPlayer
var _heart_player: AudioStreamPlayer
var _breath_stream_name := ""
var _cam_base := Vector3.ZERO
var _look_target: Node3D = null     ## utilisé pendant la mort
var _hide_yaw := 0.0                ## cap du casier : on ne peut pas se retourner dedans


func _ready() -> void:
	add_to_group("player")
	_build()
	breath.gasped.connect(_on_gasp)
	breath.state_changed.connect(_on_breath_state)
	battery = BATTERIE_MAX * Settings.autonomie_lampe()
	_set_breath_loop("breath_calm")
	# on arrive lampe allumée : sans elle le sanatorium est illisible
	torch_on = true
	torch.visible = true
	_heart_player = Audio.make_loop("heart_slow", -40.0, "Souffle")
	_heart_player.play()


func _build() -> void:
	collision_layer = 2          # joueur
	collision_mask = 1           # monde
	floor_max_angle = deg_to_rad(50)

	var col := CollisionShape3D.new()
	var caps := CapsuleShape3D.new()
	caps.radius = 0.32
	caps.height = 1.78
	col.shape = caps
	col.position.y = 0.89
	add_child(col)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = HAUTEUR_OEIL
	add_child(head)

	cam = Camera3D.new()
	cam.fov = 76.0
	# Un plan proche à 0,05 m gaspille la moitié de la précision du tampon de
	# profondeur ; à 0,12 m on double la résolution en profondeur sur tout le
	# reste de la scène, ce qui supprime le scintillement des murs.
	cam.near = 0.12
	cam.far = 65.0
	head.add_child(cam)

	# Torche : un cône serré avec un halo large, pour que le faisceau
	# découpe l'obscurité sans jamais éclairer confortablement la pièce.
	torch = SpotLight3D.new()
	torch.light_color = Color(0.97, 0.96, 0.91)
	torch.light_energy = 1.85
	torch.spot_range = 21.0
	torch.spot_angle = 30.0
	torch.spot_angle_attenuation = 1.5
	torch.spot_attenuation = 0.85
	torch.shadow_enabled = true
	torch.shadow_bias = 0.04
	torch.position = Vector3(0.20, -0.14, 0.02)
	torch.visible = false
	cam.add_child(torch)

	var halo := OmniLight3D.new()          # petite fuite de lumière autour du porteur
	halo.light_color = Color(0.96, 0.95, 0.90)
	halo.light_energy = 0.45
	halo.omni_range = 4.0
	halo.shadow_enabled = false
	halo.name = "Halo"
	torch.add_child(halo)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -PORTEE_INTERACTION)
	ray.collision_mask = 1 | 8            # monde + interactif
	ray.collide_with_areas = true
	cam.add_child(ray)

	_cam_base = cam.position


# ==========================================================================
## On écoute dans _input et non _unhandled_input : un Control de l'interface
## qui se trouve sous le curseur (le réticule est pile au centre de l'écran)
## consommerait l'évènement avant qu'il n'arrive jusqu'ici.
## Et on se fie à la phase de jeu plutôt qu'à Input.mouse_mode : sur certaines
## configurations la capture du curseur échoue en silence, ce qui bloquait
## totalement la vue.
func _input(e: InputEvent) -> void:
	if GameState.phase != GameState.Phase.JEU:
		return
	if e is InputEventMouseMotion:
		# En tactile, la visée vient du glissement d'un doigt, pas d'ici. Godot
		# émule aussi une souris à partir des touchers : sans cette garde, un
		# glissement pivotait la vue DEUX fois, et pousser le manche de
		# déplacement faisait tourner la tête en plus d'avancer.
		if Tactile.actif:
			return
		tourner((e as InputEventMouseMotion).relative)


## Fait pivoter la vue d'un déplacement exprimé en pixels.
##
## Extrait de _input pour que le glissement d'un doigt emprunte EXACTEMENT le
## même chemin que la souris : même sensibilité, même inversion d'axe, mêmes
## butées, et la même restriction de champ quand on est dans un casier. Deux
## implémentations parallèles auraient fini par diverger, et le joueur mobile
## aurait hérité d'une visée aux règles subtilement différentes.
func tourner(delta: Vector2) -> void:
	var sens := Settings.sensibilite_rad()
	var sy := -1.0 if Settings.inverser_y else 1.0
	_yaw -= delta.x * sens
	_pitch = clampf(_pitch - delta.y * sens * sy, -1.45, 1.45)
	if is_hidden:
		# dans un casier on ne tourne pas la tête à 360° : le champ est
		# celui des ouïes d'aération.
		var d := wrapf(_yaw - _hide_yaw, -PI, PI)
		_yaw = _hide_yaw + clampf(d, -0.72, 0.72)
		_pitch = clampf(_pitch, -0.55, 0.55)


func _physics_process(delta: float) -> void:
	if GameState.phase != GameState.Phase.JEU:
		return

	if _look_target != null:              # séquence de mort : la caméra la suit
		_death_look(delta)
		return

	_update_torch(delta)
	_update_interaction()
	_didacticiel_souffle()

	if is_hidden:
		_sprinting = false
		velocity = Vector3.ZERO
		rotation.y = _yaw
		_update_breath(delta)
		_apply_camera(delta, 0.0)
		return

	# le mouvement d'abord : le souffle doit réagir à la course de CETTE image
	_update_movement(delta)
	_update_breath(delta)
	_apply_camera(delta, velocity.length())


# --------------------------------------------------------------------------
func _update_movement(delta: float) -> void:
	rotation.y = _yaw

	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch != crouched:
		if not want_crouch and _blocked_above():
			want_crouch = true
		crouched = want_crouch
		var c := get_child(0) as CollisionShape3D
		var caps := c.shape as CapsuleShape3D
		caps.height = 1.12 if crouched else 1.78
		c.position.y = caps.height * 0.5

	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if not can_move:
		input = Vector2.ZERO
	var dir := (transform.basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	if dir.length_squared() > 1.0:
		dir = dir.normalized()

	var sprinting := (Input.is_action_pressed("sprint") and not crouched
			and input.y < -0.1 and breath.breath > 0.03
			and breath.state != BreathSystem.State.APNEE)
	var speed := VITESSE_ACCROUPI if crouched else (VITESSE_COURSE if sprinting else VITESSE_MARCHE)
	# on court moins vite quand on manque d'air
	if sprinting:
		speed *= lerpf(0.72, 1.0, clampf(breath.breath * 2.0, 0.0, 1.0))

	var target := dir * speed
	var rate := ACCEL if dir.length_squared() > 0.01 else FREIN
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()

	_update_steps(delta, sprinting)
	_sprinting = sprinting


var _sprinting := false


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.9)
	q.exclude = [get_rid()]
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


func _update_steps(delta: float, sprinting: bool) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.35 or not is_on_floor():
		_step_t = 0.32           # le premier pas repart vite après un arrêt
		return
	var interval := PAS_INTERVALLE_ACCROUPI if crouched else (
			PAS_INTERVALLE_COURSE if sprinting else PAS_INTERVALLE_MARCHE)
	_step_t += delta
	if _step_t < interval:
		return
	_step_t = 0.0
	GameState.stat("distance", 0.72 if crouched else (1.55 if sprinting else 1.05))
	var kind := "pas_accroupi" if crouched else ("pas_course" if sprinting else "pas_marche")
	var n := randi_range(1, 4)
	var db := -20.0 if crouched else (-8.0 if sprinting else -13.0)
	# accroupi (3 m) le couloir ne répond pas ; en courant (18 m) il claque.
	Audio.noise_3d("step_%s_%d" % [_floor_kind, n], global_position, kind, db,
			randf_range(0.92, 1.08))
	_bob = 1.0


func set_look(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	cam.rotation.x = _pitch


## Ramasse un morceau de plâtre. Faux si les mains sont pleines.
func ramasser_jetable() -> bool:
	if jetables >= JETABLES_MAX:
		GameState.say("Les mains sont pleines.", 2.0)
		return false
	jetables += 1
	GameState.say("Morceau de plâtre  (%d/%d)   [G] pour le jeter"
			% [jetables, JETABLES_MAX], 3.0)
	return true


## Jette un morceau devant soi. Le bruit se fait à l'impact, pas au lancer :
## c'est là que la Veilleuse doit aller, pas là où l'on se trouve.
func jeter() -> void:
	if jetables <= 0:
		return
	jetables -= 1
	var scn: PackedScene = _jetable_scene
	if scn == null:
		return
	var j = preload("res://scripts/Jetable.gd").new()
	get_parent().add_child(j)
	var origine := cam.global_position + cam.global_transform.basis.z * -0.55
	j.setup(scn, origine, false)
	# Une composante haute franche : lancé à plat, le morceau touche le sol à
	# trois mètres et le verbe ne sert à rien. Avec cette gerbe il porte à une
	# dizaine de mètres, c'est-à-dire assez loin pour qu'elle aille AILLEURS.
	j.lancer(-cam.global_transform.basis.z + Vector3.UP * 0.36)
	# le geste lui-même est discret : c'est l'impact qui parle
	Audio.play_3d("flashlight_click", global_position, -26.0)


var _jetable_scene: PackedScene


func set_jetable_scene(s: PackedScene) -> void:
	_jetable_scene = s


func set_floor_kind(k: String) -> void:
	_floor_kind = k


# --------------------------------------------------------------------------
func _update_breath(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.4
	breath.update(delta, Input.is_action_pressed("hold_breath"), _sprinting,
			moving, crouched, _fear_level())

	# la respiration est émise en continu : c'est ce qui trahit le joueur
	NoiseBus.emit_noise(global_position, breath.noise_radius(), "souffle")

	# mixage : le souffle est toujours au premier plan
	var want := "breath_calm"
	match breath.state:
		BreathSystem.State.APNEE: want = "breath_hold"
		BreathSystem.State.ESSOUFFLE, BreathSystem.State.HALETEMENT: want = "breath_winded"
	_set_breath_loop(want)
	if _breath_player:
		var base := -15.0
		if breath.state == BreathSystem.State.ESSOUFFLE:
			base = -6.0
		elif breath.state == BreathSystem.State.APNEE:
			base = -11.0
		_breath_player.volume_db = lerpf(_breath_player.volume_db, base + breath.heart * 3.0,
				delta * 4.0)
		_breath_player.pitch_scale = 1.0 + breath.heart * 0.10

	if _heart_player:
		var want_heart := "heart_fast" if breath.heart > 0.45 else "heart_slow"
		if _heart_player.stream != Audio.stream(want_heart, true):
			var pos := _heart_player.get_playback_position()
			_heart_player.stream = Audio.stream(want_heart, true)
			_heart_player.play(pos)
		_heart_player.volume_db = lerpf(-46.0, -11.0, pow(breath.heart, 1.4))
		_heart_player.pitch_scale = lerpf(0.92, 1.12, breath.heart)


func _set_breath_loop(name: String) -> void:
	if _breath_stream_name == name:
		return
	_breath_stream_name = name
	if _breath_player == null:
		_breath_player = Audio.make_loop(name, -15.0, "Souffle")
	else:
		_breath_player.stream = Audio.stream(name, true)
	_breath_player.play()


## Enseigne l'apnée au moment exact où elle sert.
##
## Pas au premier couloir, où la consigne serait abstraite et oubliée : à la
## première fois qu'elle chasse ET qu'elle est proche. Le joueur a alors une
## raison d'essayer, le résultat est immédiat, et la leçon tient en une fois.
## Vu une seule fois dans la vie du joueur — l'indicateur est persisté.
func _didacticiel_souffle() -> void:
	if GameState.souffle_appris or not breath.can_hold():
		return
	var v := get_tree().get_first_node_in_group("veilleuse")
	if v == null or not v.has_method("is_hunting") or not v.is_hunting():
		return
	if global_position.distance_to(v.global_position) > 14.0:
		return
	GameState.apprendre_souffle()
	GameState.say("Elle vous entend respirer.\n[Ctrl] retenez votre souffle.", 5.0)


func _fear_level() -> float:
	var v := get_tree().get_first_node_in_group("veilleuse")
	if v == null:
		return 0.0
	var d := global_position.distance_to(v.global_position)
	var f := clampf(inverse_lerp(20.0, 3.0, d), 0.0, 1.0)
	if v.has_method("is_hunting") and v.is_hunting():
		f = clampf(f * 1.35 + 0.25, 0.0, 1.0)
	if is_hidden:
		f = clampf(f * 1.15, 0.0, 1.0)     # caché, on entend son coeur encore plus
	return f


func _on_gasp() -> void:
	Audio.play_2d("gasp", -2.0, 1.0, "Souffle")
	Audio.play_echo("gasp", global_position, NoiseBus.R["halètement"])
	NoiseBus.emit_kind(global_position, "halètement")
	GameState.stat("haletements")
	_shake = 1.0
	GameState.say("Vous n'avez pas pu tenir.", 2.0)


func _on_breath_state(s: int) -> void:
	if s == BreathSystem.State.ESSOUFFLE:
		_shake = maxf(_shake, 0.35)


# --------------------------------------------------------------------------
func _update_torch(delta: float) -> void:
	if Input.is_action_just_pressed("lancer"):
		jeter()
	if Input.is_action_just_pressed("flashlight") and battery > 0.0:
		torch_on = not torch_on
		torch.visible = torch_on
		Audio.play_2d("flashlight_click", -12.0)
		NoiseBus.emit_kind(global_position, "lampe")
	if torch_on:
		battery = maxf(0.0, battery - delta)
		# la lampe faiblit et clignote en fin de charge
		var f := clampf(battery / 18.0, 0.0, 1.0)
		var flick := 1.0
		if f < 1.0:
			flick = 1.0 - (1.0 - f) * 0.45 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.021))
			if f < 0.25 and randf() < 0.02:
				flick *= 0.25
		torch.light_energy = 1.85 * flick
		if battery <= 0.0:
			torch_on = false
			torch.visible = false
			GameState.say("La lampe est morte.", 3.0)


func add_battery(secs: float) -> void:
	battery = minf(BATTERIE_MAX * Settings.autonomie_lampe(), battery + secs)


# --------------------------------------------------------------------------
func _update_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	if is_hidden:
		exit_hiding()
		return
	if not ray.is_colliding():
		return
	var c = ray.get_collider()
	while c != null and not c.has_method("interact"):
		c = c.get_parent()
	if c != null:
		c.interact(self)


func current_target() -> Node:
	if is_hidden:
		return null
	if not ray.is_colliding():
		return null
	var c = ray.get_collider()
	while c != null and not c.has_method("interact"):
		c = c.get_parent()
	return c


# --------------------------------------------------------------------------
func enter_hiding(spot: Node3D) -> void:
	is_hidden = true
	hiding_spot = spot
	can_move = false
	collision_layer = 0            # la Veilleuse ne peut plus nous toucher
	if spot.has_method("global_position_hidden"):
		global_position = spot.global_position_hidden()
	else:
		global_position = spot.global_position
	if spot.has_method("look_yaw"):
		_hide_yaw = spot.look_yaw()
		_yaw = _hide_yaw
		rotation.y = _yaw
	hide_changed.emit(true)


func exit_hiding() -> void:
	if not is_hidden:
		return
	is_hidden = false
	can_move = true
	collision_layer = 2
	if hiding_spot and hiding_spot.has_method("release"):
		hiding_spot.release()
		global_position = hiding_spot.exit_position()
	hiding_spot = null
	hide_changed.emit(false)


# --------------------------------------------------------------------------
func _apply_camera(delta: float, speed: float) -> void:
	var eye := HAUTEUR_OEIL
	if is_hidden:
		eye = HAUTEUR_OEIL_CACHE
	elif crouched:
		eye = HAUTEUR_OEIL_ACCROUPI
	head.position.y = lerpf(head.position.y, eye, delta * 9.0)

	_bob = move_toward(_bob, 0.0, delta * 3.2)
	_shake = move_toward(_shake, 0.0, delta * 1.1)

	var t := Time.get_ticks_msec() * 0.001
	# oscillation de marche
	var walk := sin(t * 9.0) * 0.012 * clampf(speed / VITESSE_MARCHE, 0.0, 1.6)
	# soulèvement de la cage thoracique, amplifié par l'essoufflement
	var chest := sin(t * (2.0 + breath.heart * 5.0)) * lerpf(0.004, 0.020, 1.0 - breath.breath)
	# tremblement de peur
	var fear := breath.heart * 0.010 + _shake * 0.030
	var jx := (randf() - 0.5) * fear
	var jy := (randf() - 0.5) * fear

	cam.position = _cam_base + Vector3(jx, walk + chest + jy + _bob * 0.010, 0.0)
	cam.rotation.x = _pitch + sin(t * 4.5) * breath.heart * 0.004
	cam.rotation.z = lerpf(cam.rotation.z, -velocity.dot(transform.basis.x) * 0.012, delta * 6.0)
	# le champ de vision se resserre sous la peur
	cam.fov = lerpf(cam.fov, 76.0 - breath.heart * 5.0, delta * 3.0)


# --------------------------------------------------------------------------
func kill(by: Node3D) -> void:
	if _look_target != null:
		return
	_look_target = by
	can_move = false
	velocity = Vector3.ZERO
	Audio.play_2d("jumpscare", -1.0)
	died.emit()


func _death_look(delta: float) -> void:
	if not is_instance_valid(_look_target):
		return
	var to := _look_target.global_position + Vector3.UP * 1.55 - head.global_position
	var want_yaw := atan2(-to.x, -to.z)
	_yaw = lerp_angle(_yaw, want_yaw, delta * 7.0)
	rotation.y = _yaw
	_pitch = lerpf(_pitch, clampf(asin(clampf(to.normalized().y, -1.0, 1.0)), -1.2, 1.2), delta * 7.0)
	cam.rotation.x = _pitch
	cam.position = _cam_base + Vector3((randf() - 0.5) * 0.06, (randf() - 0.5) * 0.06, 0)
	cam.fov = lerpf(cam.fov, 58.0, delta * 4.0)
