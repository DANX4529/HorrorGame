extends Node
## Bibliothèque de matériaux.
##
## Les .glb exportés depuis Blender ne contiennent que la géométrie et des
## slots de matériaux nommés `mat_<nom>`. On remplace ici chaque slot par la
## ressource ORMMaterial3D correspondante : les textures restent partagées sur
## le disque au lieu d'être dupliquées dans chaque fichier de modèle.

const DIR := "res://assets/materials/"
const NAMES := [
	"wall_tile", "wall_plaster", "floor_concrete", "floor_lino", "ceiling_plaster",
	"wood_old", "metal_painted", "metal_rust", "fabric_mattress", "cloth_gown",
	"paper_aged", "skin_pale", "grime_dark", "hair_dark", "glass_dirty",
	# Les bains (niveau -3)
	"bath_tile", "bath_floor", "water_dark", "glass_shards", "metal_verdigris",
	"email",
]

var mats: Dictionary = {}
var _missing: Dictionary = {}

## Variantes par matériau : nom -> [base, v1, v2, ...].
##
## Une texture posée sur trente mètres de couloir se répète en damier visible ;
## plusieurs tirages de la même recette cassent ce damier. Elles partagent
## normale et ORM, seules les taches changent.
var variantes: Dictionary = {}

## Substitutions en vigueur : nom d'origine -> nom à employer.
##
## Les modèles d'architecture sont les mêmes à tous les étages ; ce sont leurs
## MATÉRIAUX qui changent. Repeindre un étage entier tient donc dans une table,
## sans dupliquer un seul .glb — et un étage qui n'en déclare pas est rendu
## exactement comme avant.
var substituts: Dictionary = {}


func poser_substituts(d: Dictionary) -> void:
	substituts = d


func _ready() -> void:
	for n in NAMES:
		var m := load(DIR + n + ".tres")
		if m:
			mats[n] = m
			var liste: Array = [m]
			# On s'arrête à la première manquante : les variantes sont
			# numérotées sans trou par gen_materials.
			var k := 1
			while ResourceLoader.exists(DIR + "%s_v%d.tres" % [n, k]):
				liste.append(load(DIR + "%s_v%d.tres" % [n, k]))
				k += 1
			if liste.size() > 1:
				variantes[n] = liste
		else:
			push_warning("Matériau introuvable : " + n)


## Numéro de variante stable pour une case donnée.
##
## Déterministe et SANS _rng : un tirage aléatoire de plus décalerait toute la
## suite des tirages du niveau et ferait bouger un étage déjà publié.
func variante_de(x: int, y: int, n: int) -> int:
	if n <= 1:
		return 0
	# Le mélange n'est pas décoratif. « % n » ne lit que les bits BAS, et un
	# simple produit ne les brasse pas : deux points espacés d'un multiple de n
	# retombaient sur la même variante. Les pans de mur, espacés de 4 m, étaient
	# hachés sur leur position au demi-mètre — donc un pas de 8, multiple de 4 —
	# et affichaient TOUS la variante 0 : la même coulure, au même endroit, sur
	# toute la longueur d'un couloir. Les sols, eux, défilaient en 0-3-2-1-0-3-2-1,
	# une diagonale régulière plutôt qu'une dispersion.
	#
	# L'avalanche ci-dessous fait dépendre chaque bit du résultat de tous les
	# bits d'entrée. Mesuré : répartition à 1 % de l'équilibre sur 14 400 cases,
	# et des longueurs de répétition indiscernables du hasard vrai.
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
	h = ((h ^ (h >> 16)) * 0x7feb352d) & 0x7fffffff
	h = ((h ^ (h >> 15)) * 0x846ca68b) & 0x7fffffff
	h = (h ^ (h >> 16)) & 0x7fffffff
	return h % n


func get_mat(n: String) -> Material:
	return mats.get(n)


## Applique les matériaux à tout un sous-arbre fraîchement instancié.
func apply(root: Node, variante := -1) -> void:
	for mi in _all_meshes(root):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			var key := ""
			if src != null:
				key = _strip(src.resource_name)
			key = str(substituts.get(key, key))
			if key == "" or not mats.has(key):
				if key != "" and not _missing.has(key):
					_missing[key] = true
					push_warning("Slot de matériau inconnu : '%s' sur %s" % [key, mi.name])
				continue
			var choisi: Material = mats[key]
			if variante >= 0 and variantes.has(key):
				var l: Array = variantes[key]
				choisi = l[variante % l.size()]
			mi.set_surface_override_material(i, choisi)


## Force UN matériau sur tout un sous-arbre, sans passer par les slots.
##
## Sert aux sols qui changent de nature d'une case à l'autre : le modèle de
## dalle est le même partout, c'est la case qui décide si on marche sur du
## carrelage, dans l'eau ou sur du verre.
func forcer(root: Node, nom: String) -> void:
	var m: Material = mats.get(nom)
	if m == null:
		return
	for mi in _all_meshes(root):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, m)


func _strip(n: String) -> String:
	# Godot suffixe parfois les noms importés (« mat_bois.001 »)
	var s := n
	if s.begins_with("mat_"):
		s = s.substr(4)
	var dot := s.rfind(".")
	if dot > 0 and s.substr(dot + 1).is_valid_int():
		s = s.substr(0, dot)
	return s


func _all_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out
