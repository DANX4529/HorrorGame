extends Node3D
## Monte-charge. Inutilisable tant que le courant n'est pas revenu.
##
## Il ne fait plus gagner : il DESCEND. C'est le pivot de la campagne — et le
## seul endroit où ce qu'on a lu devient ce qu'on possède.

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
	Audio.play_3d("locker_close", global_position, -6.0)
	GameState.remonter_butin()
	# La cabine s'ouvre même s'il n'y a plus rien en dessous : c'est elle qui
	# annonce la fin de la campagne, et le joueur a droit au décompte de son
	# butin dans les deux cas.
	GameState.set_phase(GameState.Phase.CABINE)


func prompt() -> String:
	if not GameState.power_restored:
		return "Grille sans courant"
	var n := GameState.documents_en_cours()
	if n > 0:
		return "Descendre  (%d document%s à l'abri)" % [n, "s" if n > 1 else ""]
	return "Descendre"
