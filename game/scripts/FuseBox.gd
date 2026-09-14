extends Node3D
## Tableau électrique du sous-sol : l'objectif du jeu.

var installed := 0
var _door_pivot: Node3D
var _angle := 0.0
var _target := 0.0
var _lamps: Array[OmniLight3D] = []


func setup(body_scene: PackedScene, door_scene: PackedScene, pos: Vector3, rot: float) -> void:
	position = pos
	rotation.y = rot
	add_to_group("fusebox")

	var body := body_scene.instantiate()
	add_child(body)
	MaterialLib.apply(body)

	_door_pivot = Node3D.new()
	add_child(_door_pivot)
	var leaf := door_scene.instantiate()
	_door_pivot.add_child(leaf)
	MaterialLib.apply(leaf)
	_target = 1.9                     # le tableau est trouvé porte ouverte
	_angle = 1.9
	_door_pivot.rotation.y = _angle

	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.35)
	l.light_energy = 0.55
	l.omni_range = 2.2
	l.shadow_enabled = false
	l.position = Vector3(0, 0, -0.25)
	add_child(l)

	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.90, 1.10, 0.90)
	cs.shape = bx
	cs.position = Vector3(0, 0, -0.3)
	area.add_child(cs)
	add_child(area)


func interact(_who) -> void:
	if GameState.power_restored:
		GameState.say("Le courant est rétabli. Le monte-charge attend.", 3.0)
		return
	if GameState.fuses_held <= 0:
		GameState.say("Il manque %d fusibles céramiques." %
				(GameState.FUSES_REQUIRED - GameState.fuses_installed), 3.0)
		return
	var n := GameState.install_fuses()
	installed = GameState.fuses_installed
	GameState.poser_point_de_controle()
	Audio.noise_3d("fuse_insert", global_position, "fusible", -4.0)
	if installed >= GameState.FUSES_REQUIRED:
		_power_up()
	else:
		GameState.say("%d fusible(s) posé(s). %d manquant(s)." %
				[n, GameState.FUSES_REQUIRED - installed], 3.5)


func _power_up() -> void:
	GameState.power_restored = true
	Audio.noise_3d("power_on", global_position, "courant", 0.0)
	GameState.say("LE COURANT EST REVENU.\nElle l'a entendu. Courez au monte-charge.", 5.0)
	# la lumière revient partout : la fin de partie se joue à découvert
	var racine := get_tree().current_scene
	if racine and racine.has_method("_rallumer"):
		racine._rallumer()


func prompt() -> String:
	if GameState.power_restored:
		return "Tableau alimenté"
	if GameState.fuses_held > 0:
		return "Poser %d fusible(s)" % GameState.fuses_held
	return "Tableau électrique (%d/%d)" % [GameState.fuses_installed, GameState.FUSES_REQUIRED]
