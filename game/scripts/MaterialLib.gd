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
]

var mats: Dictionary = {}
var _missing: Dictionary = {}


func _ready() -> void:
	for n in NAMES:
		var m := load(DIR + n + ".tres")
		if m:
			mats[n] = m
		else:
			push_warning("Matériau introuvable : " + n)


func get_mat(n: String) -> Material:
	return mats.get(n)


## Applique les matériaux à tout un sous-arbre fraîchement instancié.
func apply(root: Node) -> void:
	for mi in _all_meshes(root):
		var mesh := mi.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			var key := ""
			if src != null:
				key = _strip(src.resource_name)
			if key == "" or not mats.has(key):
				if key != "" and not _missing.has(key):
					_missing[key] = true
					push_warning("Slot de matériau inconnu : '%s' sur %s" % [key, mi.name])
				continue
			mi.set_surface_override_material(i, mats[key])


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
