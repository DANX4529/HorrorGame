extends Node3D
## Vestiaire métallique — la seule cachette du jeu.
##
## Entrer coupe la ligne de vue de la Veilleuse mais ne la rend pas sourde :
## la respiration continue d'être émise, amplifiée par la tôle.

const VITESSE := 3.4
const ANGLE_OUVERT := 1.75

var body: Node3D
var occupied := false
var facing := 0.0
var _leaf: Node3D
var _angle := 0.0
var _target := 0.0
var _base_pos := Vector3.ZERO


func setup(b: Node3D, door_scene: PackedScene, pos: Vector3, rot: float) -> void:
	body = b
	facing = rot
	_base_pos = pos
	add_to_group("hiding")

	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation.y = rot
	add_child(pivot)
	_leaf = door_scene.instantiate()
	pivot.add_child(_leaf)
	MaterialLib.apply(_leaf)

	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.60, 1.90, 0.95)
	cs.shape = bx
	cs.position = Vector3(0, 0.95, 0.25)
	area.add_child(cs)
	pivot.add_child(area)


func interact(who) -> void:
	if occupied:
		return
	occupied = true
	_target = ANGLE_OUVERT
	Audio.play_3d("locker_open", _base_pos, -8.0)
	NoiseBus.emit_kind(_base_pos, "casier")
	who.enter_hiding(self)
	await get_tree().create_timer(0.45).timeout
	if occupied:
		_target = 0.0
		Audio.play_3d("locker_close", _base_pos, -10.0)


func release() -> void:
	occupied = false
	_target = ANGLE_OUVERT
	Audio.play_3d("locker_open", _base_pos, -8.0)
	NoiseBus.emit_kind(_base_pos, "casier")
	await get_tree().create_timer(0.6).timeout
	_target = 0.0


func prompt() -> String:
	return "Se cacher"


## Position du joueur une fois caché : au ras des ouïes d'aération, côté
## pièce. Plus en arrière, la caméra se retrouve dans l'épaisseur du battant
## et le joueur ne voit plus rien du tout.
func global_position_hidden() -> Vector3:
	return _base_pos + Vector3(0, 0, 0.30).rotated(Vector3.UP, facing)


## Cap imposé au joueur caché : il regarde par les ouïes, vers la pièce.
## L'avant du caisson est son +Z local ; l'avant d'un Node3D est son -Z :
## d'où le demi-tour.
func look_yaw() -> float:
	return facing + PI


func exit_position() -> Vector3:
	return _base_pos + Vector3(0, 0, 0.85).rotated(Vector3.UP, facing)


func _process(delta: float) -> void:
	if is_equal_approx(_angle, _target):
		return
	_angle = move_toward(_angle, _target, VITESSE * delta)
	if _leaf:
		_leaf.rotation.y = _angle
