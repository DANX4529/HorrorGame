extends Node3D
## Objet ramassable : fusible céramique ou pile.

var kind := "fuse"
var _mesh: Node3D
var _t := 0.0


func setup(k: String, scene: PackedScene, pos: Vector3) -> void:
	kind = k
	position = pos + Vector3(0, 0.78 if k == "fuse" else 0.74, 0)
	_mesh = scene.instantiate()
	add_child(_mesh)
	MaterialLib.apply(_mesh)
	# une lueur minuscule : sans elle, un objet de 8 cm est introuvable
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.88, 0.62) if k == "fuse" else Color(0.7, 0.85, 1.0)
	l.light_energy = 0.5
	l.omni_range = 1.5
	l.shadow_enabled = false
	add_child(l)

	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.34
	cs.shape = sp
	area.add_child(cs)
	add_child(area)


func interact(who) -> void:
	if kind == "fuse":
		GameState.add_fuse()
		Audio.play_3d("pickup_fuse", global_position, -5.0)
	else:
		who.add_battery(35.0)
		Audio.play_3d("pickup_battery", global_position, -7.0)
		GameState.say("Pile récupérée. +35 s de lampe.", 2.5)
	NoiseBus.emit_kind(global_position, "fusible", 0.5)
	queue_free()


func prompt() -> String:
	return "Prendre le fusible" if kind == "fuse" else "Prendre la pile"


func _process(delta: float) -> void:
	_t += delta
	if _mesh:
		_mesh.rotation.y = _t * 1.1
		_mesh.position.y = sin(_t * 1.9) * 0.03
