extends Node3D
## Porte battante.
##
## Le noeud porte lui-même le script, et le vantail / sa collision / son
## volume d'interaction sont ses enfants : la remontée de parents effectuée
## par le rayon du joueur trouve donc bien `interact()`.

const VITESSE := 2.4
const ANGLE_OUVERT := 1.62

var metal := false
var open := false
var _angle := 0.0
var _target := 0.0
var _leaf: Node3D
var _body: AnimatableBody3D
var _area: Area3D
var _last_sound := 0.0


func setup(pos: Vector3, rot: float, is_metal: bool, leaf_scene: PackedScene) -> void:
	metal = is_metal
	# le vantail pivote sur son bord gauche : on décale l'origine de 0,55 m
	position = pos + Vector3(-0.55, 0, 0).rotated(Vector3.UP, rot)
	rotation.y = rot

	_leaf = leaf_scene.instantiate()
	add_child(_leaf)
	MaterialLib.apply(_leaf)

	_body = AnimatableBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.04, 2.10, 0.06)
	cs.shape = bx
	cs.position = Vector3(0.52, 1.05, 0.0)
	_body.add_child(cs)
	add_child(_body)

	_area = Area3D.new()
	_area.collision_layer = 8
	_area.collision_mask = 0
	var acs := CollisionShape3D.new()
	var abx := BoxShape3D.new()
	abx.size = Vector3(1.20, 2.10, 0.70)
	acs.shape = abx
	acs.position = Vector3(0.52, 1.05, 0.0)
	_area.add_child(acs)
	add_child(_area)
	add_to_group("door")


## Porte trouvée entrouverte au démarrage (sans bruit ni animation).
func set_ajar() -> void:
	open = true
	_angle = ANGLE_OUVERT
	_target = ANGLE_OUVERT
	_leaf.rotation.y = _angle
	_body.rotation.y = _angle
	_area.rotation.y = _angle


func interact(_who) -> void:
	if not open:
		GameState.stat("portes")
	open = not open
	_target = ANGLE_OUVERT if open else 0.0
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_sound > 0.35:
		_last_sound = now
		Audio.noise_3d("door_open" if open else "door_close", global_position,
				"porte", -6.0, randf_range(0.94, 1.06) * (0.88 if metal else 1.0))


func prompt() -> String:
	return "Fermer la porte" if open else "Ouvrir la porte"


func _process(delta: float) -> void:
	if is_equal_approx(_angle, _target):
		return
	_angle = move_toward(_angle, _target, VITESSE * delta)
	# seuls le vantail, sa collision et son volume tournent ; le noeud porte
	# conserve l'orientation du mur.
	_leaf.rotation.y = _angle
	_body.rotation.y = _angle
	_area.rotation.y = _angle
