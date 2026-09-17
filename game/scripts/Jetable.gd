extends RigidBody3D
## Un morceau de plâtre qu'on ramasse et qu'on jette.
##
## C'est le premier verbe du jeu qui ne sert pas à se cacher. Jusqu'ici la
## Veilleuse ne pouvait qu'être évitée ; elle peut maintenant être ENVOYÉE
## quelque part. Le bruit d'impact porte à 16 m, au-dessus du seuil de chasse
## (14 m) : un jet réussi ne l'intrigue pas, il la lance — ailleurs.
##
## Le rayon "objet" existait dans NoiseBus depuis le premier jour sans un seul
## appelant. Il attendait ce verbe-là.

const VITESSE := 9.5
const DUREE_VIE := 25.0       ## au-delà, l'objet disparaît : on ne meuble pas
                              ## le niveau de projectiles à chaque descente

var pose := true              ## posé au sol (ramassable) ou en vol
var _mesh: Node3D
var _a_sonne := false
var _age := 0.0


func setup(scene: PackedScene, pos: Vector3, au_sol := true) -> void:
	position = pos
	pose = au_sol
	collision_layer = 16
	collision_mask = 1
	gravity_scale = 1.0
	# un projectile qui rebondit trois fois émettrait trois bruits : on le veut
	# lourd et mat, comme un morceau de plâtre
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.05
	physics_material_override.friction = 0.9
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_sur_contact)

	_mesh = scene.instantiate()
	_mesh.scale = Vector3.ONE * 0.55
	add_child(_mesh)
	MaterialLib.apply(_mesh)

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.17
	cs.shape = sp
	add_child(cs)

	if pose:
		freeze = true
		# volume d'interaction : même couche 8 que les autres ramassables, pour
		# que le rayon du joueur le trouve sans traitement particulier
		var area := Area3D.new()
		area.collision_layer = 8
		area.collision_mask = 0
		var acs := CollisionShape3D.new()
		var asp := SphereShape3D.new()
		asp.radius = 0.42
		acs.shape = asp
		area.add_child(acs)
		add_child(area)


func lancer(dir: Vector3) -> void:
	pose = false
	freeze = false
	_a_sonne = false
	_age = 0.0
	linear_velocity = dir.normalized() * VITESSE
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6),
			randf_range(-6, 6))


func _physics_process(delta: float) -> void:
	if pose:
		return
	_age += delta
	if _age > DUREE_VIE:
		queue_free()


## Le premier contact fait le bruit, et lui seul.
##
## Un objet qui roule cognerait plusieurs murs et ferait autant d'appels : la
## Veilleuse se verrait tirée d'un point à l'autre par un seul jet, ce qui
## rendrait le verbe illisible. Un jet = un bruit = un endroit.
func _sur_contact(_corps: Node) -> void:
	if pose or _a_sonne:
		return
	_a_sonne = true
	Audio.noise_3d("peur_chute", global_position, "objet", -4.0,
			randf_range(0.92, 1.1))


func interact(who) -> void:
	if not pose:
		return
	if who.has_method("ramasser_jetable") and who.ramasser_jetable():
		Audio.play_3d("pickup_battery", global_position, -14.0)
		queue_free()


func prompt() -> String:
	return "Prendre le morceau de plâtre"
