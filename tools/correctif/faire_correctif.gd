extends SceneTree
## Fabrique une archive de correctif : un .pck ne contenant QUE les fichiers
## listés. Lancé par faire_correctif.sh, qui établit la liste à partir de git.
##
##   godot --headless --path game --script res://../tools/correctif/faire_correctif.gd \
##         -- <sortie.pck> <fichier-liste>
##
## Passe par PCKPacker plutôt que par un export : un export produit TOUT le
## jeu, ce qu'on cherche précisément à éviter. Les chemins sont donnés tels que
## le jeu les connaît (res://…) et non tels qu'ils sont sur le disque.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: ... -- <sortie.pck> <fichier-liste>")
		quit(2)
		return
	var sortie: String = args[0]
	var liste: String = args[1]

	var f := FileAccess.open(liste, FileAccess.READ)
	if f == null:
		printerr("liste illisible : %s" % liste)
		quit(2)
		return
	var chemins: Array[String] = []
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l != "":
			chemins.append(l)
	f.close()

	var p := PCKPacker.new()
	if p.pck_start(sortie) != OK:
		printerr("impossible d'ouvrir %s en écriture" % sortie)
		quit(2)
		return
	var n := 0
	var absents: Array[String] = []
	for c in chemins:
		# Une ressource importée (texture, son, modèle) ne se joue pas depuis
		# son fichier source mais depuis sa version importée, dans .godot.
		# Emballer le .png d'origine ne remplacerait donc rien.
		var reel := c
		if ResourceLoader.exists(c) and not FileAccess.file_exists(c):
			reel = c
		if not FileAccess.file_exists(reel):
			absents.append(c)
			continue
		p.add_file(c, reel)
		n += 1
	if p.flush(false) != OK:
		printerr("écriture du .pck échouée")
		quit(2)
		return
	for a in absents:
		print("  absent, ignoré : %s" % a)
	print("CORRECTIF %d fichier(s) -> %s" % [n, sortie])
	quit(0)
