extends Node3D
## Monte-charge : la sortie. Inutilisable tant que le courant n'est pas revenu.

func setup(pos: Vector3) -> void:
	position = pos
	add_to_group("exit")
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(2.2, 2.4, 1.6)
	cs.shape = bx
	cs.position = Vector3(0, 1.2, 0)
	area.add_child(cs)
	add_child(area)


func interact(_who) -> void:
	if not GameState.power_restored:
		GameState.say("La grille est morte. Il faut du courant.", 3.0)
		Audio.play_3d("locker_close", global_position, -12.0)
		return
	GameState.set_phase(GameState.Phase.VICTOIRE)


func prompt() -> String:
	return "Prendre le monte-charge" if GameState.power_restored else "Grille sans courant"
