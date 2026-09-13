extends Node3D
## Construit le Sanatorium du Mont-Cendre à partir d'une grille textuelle.
##
## Une case = 4 m. Un mur est posé sur chaque arête séparant deux cases de
## natures différentes ; les portes et les ouvertures sont déclarées à part.
## Le plan forme volontairement un ANNEAU de couloirs : le joueur doit pouvoir
## contourner la Veilleuse, jamais se retrouver dans un cul-de-sac obligatoire.

const CELL := 4.0
const WALL_H := 3.0

# --------------------------------------------------------------------------
#  Le plan
#     .  maçonnerie pleine / extérieur
#     C  couloir            A  archives         D,E  dortoirs
#     S  salle de soins     W  salle d'eau      H  hall d'entrée
#     R  réserve            T  chaufferie       M  monte-charge (sortie)
# --------------------------------------------------------------------------
const MAP := [
	".............",
	".AA.DD.EE....",
	".AA.DD.EE....",
	".CCCCCCCCCC..",
	".C........C..",
	".C.SS.WW..C..",
	".C.SS.WW..C..",
	".CCCCCCCCCC..",
	"...HH..RR.TT.",
	"...HH..RR.TM.",
	".............",
]

## Portes : [x, y, direction] — la direction désigne l'arête de la case.
const DOORS := [
	[2, 2, "S"],            # archives -> couloir
	[4, 2, "S"],            # dortoir D -> couloir
	[8, 2, "S"],            # dortoir E -> couloir
	[3, 6, "S"],            # soins -> couloir
	[7, 6, "S"],            # salle d'eau -> couloir
	[3, 8, "N"],            # hall -> couloir
	[8, 8, "N"],            # réserve -> couloir
	[10, 8, "N"],           # chaufferie -> couloir (porte métallique)
]

## Ouvertures francches (pas de mur du tout)
const OPENINGS := [
	[11, 9, "W"],           # chaufferie -> monte-charge
]

## Cases utilisant le kit béton (sous-sol technique)
const BETON := ["T", "M", "R"]

# --------------------------------------------------------------------------
var _env_scenes: Dictionary = {}
var _prop_scenes: Dictionary = {}
var _cells: Dictionary = {}          # Vector2i -> lettre
var _doors: Dictionary = {}          # clé d'arête -> true
var _openings: Dictionary = {}
var solid_grid: Dictionary = {}      # Vector2i (grille de nav) -> true si bloqué
var nav_rect := Rect2i()
var nav_reachable := 0
var nav_total := 0
var patrol_points: PackedVector3Array = []
var fuse_spawns: PackedVector3Array = []
var battery_spawns: PackedVector3Array = []
var hiding_spots: Array[Node3D] = []
var fusebox: Node3D = null
var exit_gate: Node3D = null
var _rng := RandomNumberGenerator.new()

const NAV_RES := 0.5                 # pas de la grille de navigation, en mètres
const AGENT_R := 0.42                # rayon d'encombrement de la Veilleuse


# ==========================================================================
func build(seed_val := 0) -> void:
	_rng.seed = seed_val if seed_val != 0 else 0x5EED
	_load_scenes()
	_parse_map()
	_build_shell()
	_build_doors()
	_dress_rooms()
	_build_lights()
	_bake_nav()
	_pick_spawns()


func _load_scenes() -> void:
	for n in ["wall_plain", "wall_plain_2m", "wall_door", "wall_window",
			"wall_concrete", "wall_concrete_door", "floor_lino", "floor_concrete",
			"ceiling", "ceiling_concrete"]:
		_env_scenes[n] = load("res://assets/models/env/%s.glb" % n)
	for n in ["door", "door_metal", "locker_body", "locker_door", "hospital_bed",
			"wheelchair", "iv_stand", "cabinet", "ceiling_lamp", "wall_lamp",
			"fuse_box_body", "fuse_box_door", "fuse", "battery", "chair", "desk",
			"radiator", "crate", "debris", "papers", "pipe_junction", "elevator_gate"]:
		# les casiers et le tableau électrique sont exportés en deux objets
		# (caisson + porte) mais proviennent d'un même fichier .glb
		var base: String = n
		if n.begins_with("locker") or n.begins_with("fuse_box"):
			base = n.replace("_body", "").replace("_door", "")
		_prop_scenes[n] = load("res://assets/models/props/%s.glb" % base)


func _parse_map() -> void:
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var c := row[x]
			if c != ".":
				_cells[Vector2i(x, y)] = c
	for d in DOORS:
		_doors[_edge_key(d[0], d[1], d[2])] = true
		_door_zones.append(_door_zone(d[0], d[1], d[2]))
	for o in OPENINGS:
		_openings[_edge_key(o[0], o[1], o[2])] = true
		_door_zones.append(_door_zone(o[0], o[1], o[2]))


## Rectangle qui doit rester libre de part et d'autre d'une baie, sans quoi
## un meuble posé au hasard peut murer une pièce entière.
func _door_zone(x: int, y: int, dir: String) -> Dictionary:
	var c := world_of(x, y)
	var half_w := 1.05          # largeur de la baie + marge
	var depth := 2.20           # profondeur dégagée de chaque côté
	match dir:
		"N": return {"pos": c + Vector3(0, 0, -CELL * 0.5), "hx": half_w, "hz": depth}
		"S": return {"pos": c + Vector3(0, 0, CELL * 0.5), "hx": half_w, "hz": depth}
		"W": return {"pos": c + Vector3(-CELL * 0.5, 0, 0), "hx": depth, "hz": half_w}
		_:   return {"pos": c + Vector3(CELL * 0.5, 0, 0), "hx": depth, "hz": half_w}


func _in_door_zone(pos: Vector3, size: Vector3, rot: float) -> bool:
	# encombrement approché par sa boîte englobante alignée sur les axes
	var ex := absf(size.x * cos(rot)) * 0.5 + absf(size.z * sin(rot)) * 0.5 + AGENT_R
	var ez := absf(size.x * sin(rot)) * 0.5 + absf(size.z * cos(rot)) * 0.5 + AGENT_R
	for z in _door_zones:
		if absf(pos.x - z.pos.x) < z.hx + ex and absf(pos.z - z.pos.z) < z.hz + ez:
			return true
	return false


## Clé canonique d'une arête : la même arête vue des deux cases donne la même clé.
func _edge_key(x: int, y: int, dir: String) -> String:
	match dir:
		"N": return "H:%d:%d" % [x, y - 1]       # arête horizontale au-dessus
		"S": return "H:%d:%d" % [x, y]
		"W": return "V:%d:%d" % [x - 1, y]       # arête verticale à gauche
		_:   return "V:%d:%d" % [x, y]


func _at(x: int, y: int) -> String:
	return _cells.get(Vector2i(x, y), ".")


func _is_beton(c: String) -> bool:
	return c in BETON


func world_of(x: int, y: int) -> Vector3:
	return Vector3(x * CELL, 0.0, y * CELL)


# ==========================================================================
#  Gros oeuvre : sols, plafonds, murs
# ==========================================================================
func _build_shell() -> void:
	var shell := Node3D.new()
	shell.name = "Shell"
	add_child(shell)

	for cell in _cells:
		var c: String = _cells[cell]
		var beton := _is_beton(c)
		var p := world_of(cell.x, cell.y)
		_place(shell, "floor_concrete" if beton else "floor_lino", p, 0.0, true)
		var ceil_inst := _place(shell, "ceiling_concrete" if beton else "ceiling", p, 0.0, false)
		if ceil_inst:
			ceil_inst.add_to_group("ceiling")
		_add_box(shell, p + Vector3(0, -0.05, 0), Vector3(CELL, 0.1, CELL))
		_add_box(shell, p + Vector3(0, WALL_H + 0.06, 0), Vector3(CELL, 0.12, CELL))

	# arêtes horizontales : mur entre (x,y) et (x,y+1)
	for y in range(-1, MAP.size()):
		for x in range(0, MAP[0].length()):
			var a := _at(x, y)
			var b := _at(x, y + 1)
			if a == b:
				continue
			if a == "." and b == ".":
				continue
			var key := "H:%d:%d" % [x, y]
			var pos := Vector3(x * CELL, 0.0, y * CELL + CELL * 0.5)
			_edge(shell, key, pos, 0.0, _is_beton(a) or _is_beton(b), a, b)

	# arêtes verticales : mur entre (x,y) et (x+1,y)
	for y in range(0, MAP.size()):
		for x in range(-1, MAP[0].length()):
			var a := _at(x, y)
			var b := _at(x + 1, y)
			if a == b:
				continue
			if a == "." and b == ".":
				continue
			var key := "V:%d:%d" % [x, y]
			var pos := Vector3(x * CELL + CELL * 0.5, 0.0, y * CELL)
			_edge(shell, key, pos, PI * 0.5, _is_beton(a) or _is_beton(b), a, b)


func _edge(parent: Node3D, key: String, pos: Vector3, rot: float,
		beton: bool, a: String, b: String) -> void:
	if _openings.has(key):
		return
	var is_door: bool = _doors.has(key)
	var scene_name := ""
	if is_door:
		scene_name = "wall_concrete_door" if beton else "wall_door"
	elif not beton and (a == "." or b == ".") and _rng.randf() < 0.34 and a != "H" and b != "H":
		scene_name = "wall_window"          # ouverture sur la nuit, façade uniquement
	else:
		scene_name = "wall_concrete" if beton else "wall_plain"
	_place(parent, scene_name, pos, rot, false)
	_wall_collision(parent, pos, rot, is_door)
	if is_door:
		_pending_doors.append({"pos": pos, "rot": rot, "beton": beton})


var _pending_doors: Array = []


func _wall_collision(parent: Node3D, pos: Vector3, rot: float, is_door: bool) -> void:
	var t := 0.30
	if not is_door:
		_add_box(parent, pos + Vector3(0, WALL_H * 0.5, 0),
				Vector3(CELL, WALL_H, t), rot)
		return
	# jambages + linteau, l'ouverture (1,10 m) reste franchissable
	var side := (CELL - 1.10) * 0.5
	for s in [-1.0, 1.0]:
		var off := Vector3(s * (1.10 * 0.5 + side * 0.5), WALL_H * 0.5, 0).rotated(Vector3.UP, rot)
		_add_box(parent, pos + off, Vector3(side, WALL_H, t), rot)
	_add_box(parent, pos + Vector3(0, 2.15 + (WALL_H - 2.15) * 0.5, 0),
			Vector3(1.10, WALL_H - 2.15, t), rot)


func _place(parent: Node3D, scene_name: String, pos: Vector3, rot: float,
		is_floor := false) -> Node3D:
	var ps: PackedScene = _env_scenes.get(scene_name)
	if ps == null:
		return null
	var inst := ps.instantiate()
	inst.position = pos
	inst.rotation.y = rot
	parent.add_child(inst)
	MaterialLib.apply(inst)
	return inst


func _add_box(parent: Node3D, center: Vector3, size: Vector3, rot := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	body.add_child(cs)
	body.position = center
	body.rotation.y = rot
	parent.add_child(body)
	return body


# ==========================================================================
#  Portes battantes
# ==========================================================================
func _build_doors() -> void:
	var holder := Node3D.new()
	holder.name = "Doors"
	add_child(holder)
	for d in _pending_doors:
		var scn: PackedScene = _prop_scenes["door_metal" if d.beton else "door"]
		var ctrl := preload("res://scripts/Door.gd").new()
		holder.add_child(ctrl)
		ctrl.setup(d.pos, d.rot, d.beton, scn)
		if _rng.randf() < 0.45:
			ctrl.set_ajar()


# ==========================================================================
#  Ameublement
# ==========================================================================
func _dress_rooms() -> void:
	var props := Node3D.new()
	props.name = "Props"
	add_child(props)
	for cell in _cells:
		var c: String = _cells[cell]
		var p := world_of(cell.x, cell.y)
		match c:
			"D", "E": _dress_dortoir(props, p, cell)
			"S":      _dress_soins(props, p, cell)
			"A":      _dress_archives(props, p, cell)
			"H":      _dress_hall(props, p, cell)
			"R":      _dress_reserve(props, p, cell)
			"T":      _dress_technique(props, p, cell)
			"M":      _dress_monte_charge(props, p, cell)
			"W":      _dress_eau(props, p, cell)
			"C":      _dress_couloir(props, p, cell)


func _prop(parent: Node3D, name: String, pos: Vector3, rot := 0.0,
		box := Vector3.ZERO, box_off := Vector3.ZERO) -> Node3D:
	var ps: PackedScene = _prop_scenes.get(name)
	if ps == null:
		return null
	# Un meuble ne doit jamais condamner une baie : on l'écarte, et à défaut
	# on renonce à le poser. Une pièce inaccessible casserait le niveau.
	if box != Vector3.ZERO and _in_door_zone(pos, box, rot):
		var placed := false
		for k in 10:
			var a := TAU * k / 10.0
			var cand := pos + Vector3(cos(a), 0, sin(a)) * (0.9 + k * 0.18)
			if not _in_door_zone(cand, box, rot) and _same_cell(cand, pos):
				pos = cand
				placed = true
				break
		if not placed:
			skipped_props += 1
			return null
	var inst := ps.instantiate()
	inst.position = pos
	inst.rotation.y = rot
	parent.add_child(inst)
	MaterialLib.apply(inst)
	if box != Vector3.ZERO:
		_add_box(parent, pos + box_off.rotated(Vector3.UP, rot) + Vector3(0, box.y * 0.5, 0),
				box, rot)
		_block_nav(pos, box, rot)
	return inst


var _nav_blockers: Array = []
var _door_zones: Array = []
var skipped_props := 0


func _same_cell(a: Vector3, b: Vector3) -> bool:
	return roundi(a.x / CELL) == roundi(b.x / CELL) and roundi(a.z / CELL) == roundi(b.z / CELL)


func _block_nav(pos: Vector3, size: Vector3, rot: float) -> void:
	_nav_blockers.append({"pos": pos, "size": size, "rot": rot})


func _r(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func _dress_dortoir(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	for i in 2:
		var x := -1.15 + i * 2.30
		var bed := _prop(p, "hospital_bed", o + Vector3(x, 0, _r(-0.4, 0.4)),
				_r(-0.06, 0.06), Vector3(1.0, 0.62, 2.1))
		if _rng.randf() < 0.5:
			_prop(p, "iv_stand", o + Vector3(x + 0.75, 0, -1.15), _r(0, TAU),
					Vector3(0.5, 1.8, 0.5))
	if _rng.randf() < 0.55:
		_prop(p, "wheelchair", o + Vector3(_r(-1.2, 1.2), 0, 1.35), _r(0, TAU),
				Vector3(0.7, 1.0, 0.9))
	_add_locker(p, o + Vector3(1.65, 0, 1.70), PI)
	if _rng.randf() < 0.6:
		_prop(p, "debris", o + Vector3(_r(-1.4, 1.4), 0, _r(-1.4, 1.4)), _r(0, TAU))
	_prop(p, "radiator", o + Vector3(0, 0, -1.88), 0.0)


func _dress_soins(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	_prop(p, "cabinet", o + Vector3(-1.55, 0, -1.55), _r(-0.1, 0.1),
			Vector3(0.76, 1.65, 0.40))
	_prop(p, "desk", o + Vector3(0.9, 0, 0.8), _r(1.4, 1.8),
			Vector3(1.35, 0.80, 0.70))
	_prop(p, "chair", o + Vector3(0.2, 0, 1.1), _r(0, TAU), Vector3(0.45, 0.95, 0.45))
	_prop(p, "papers", o + Vector3(_r(-1.0, 1.0), 0.01, _r(-1.0, 1.0)), _r(0, TAU))
	_add_locker(p, o + Vector3(1.68, 0, -1.2), PI * 0.5)


func _dress_archives(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	for i in 3:
		_prop(p, "cabinet", o + Vector3(-1.6 + i * 0.8, 0, -1.6), 0.0,
				Vector3(0.76, 1.65, 0.40))
	_prop(p, "desk", o + Vector3(0.6, 0, 1.0), _r(-0.2, 0.2), Vector3(1.35, 0.80, 0.70))
	_prop(p, "crate", o + Vector3(1.5, 0, -0.4), _r(0, TAU), Vector3(0.6, 0.6, 0.6))
	_prop(p, "papers", o + Vector3(_r(-1.2, 1.2), 0.01, _r(-1.2, 1.2)), _r(0, TAU))


func _dress_hall(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	_prop(p, "desk", o + Vector3(-1.2, 0, -1.0), PI * 0.5, Vector3(0.70, 0.80, 1.35))
	_prop(p, "chair", o + Vector3(-0.4, 0, -1.4), _r(0, TAU), Vector3(0.45, 0.95, 0.45))
	if _rng.randf() < 0.7:
		_prop(p, "wheelchair", o + Vector3(1.2, 0, 1.0), _r(0, TAU), Vector3(0.7, 1.0, 0.9))
	_prop(p, "debris", o + Vector3(_r(-1.2, 1.2), 0, _r(-1.2, 1.2)), _r(0, TAU))


func _dress_reserve(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	for i in 4:
		_prop(p, "crate", o + Vector3(_r(-1.5, 1.5), 0, _r(-1.5, 1.5)), _r(0, TAU),
				Vector3(0.6, 0.6, 0.6))
	_add_locker(p, o + Vector3(-1.68, 0, 0.6), -PI * 0.5)


func _dress_technique(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	if cell == Vector2i(10, 8):
		fusebox = preload("res://scripts/FuseBox.gd").new()
		p.add_child(fusebox)
		fusebox.setup(_prop_scenes["fuse_box_body"], _prop_scenes["fuse_box_door"],
				o + Vector3(1.30, 1.35, -1.86), 0.0)
		_block_nav(o + Vector3(1.30, 0, -1.60), Vector3(0.9, 2.0, 0.7), 0.0)
	_prop(p, "pipe_junction", o + Vector3(-1.5, 0, -1.5), _r(0, TAU),
			Vector3(0.5, 2.4, 0.5))
	_prop(p, "crate", o + Vector3(1.3, 0, 1.2), _r(0, TAU), Vector3(0.6, 0.6, 0.6))
	_prop(p, "debris", o + Vector3(_r(-1.0, 1.0), 0, _r(-1.0, 1.0)), _r(0, TAU))


func _dress_monte_charge(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	exit_gate = _prop(p, "elevator_gate", o + Vector3(0, 0, 1.85), 0.0)
	var script := preload("res://scripts/ExitGate.gd")
	var ctrl := script.new()
	add_child(ctrl)
	ctrl.setup(o + Vector3(0, 0, 1.0))


func _dress_eau(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	_prop(p, "radiator", o + Vector3(0, 0, -1.88), 0.0)
	_add_locker(p, o + Vector3(-1.68, 0, -1.0), -PI * 0.5)
	_prop(p, "debris", o + Vector3(_r(-1.2, 1.2), 0, _r(-1.2, 1.2)), _r(0, TAU))


func _dress_couloir(p: Node3D, o: Vector3, cell: Vector2i) -> void:
	var r := _rng.randf()
	if r < 0.16:
		_prop(p, "wheelchair", o + Vector3(_r(-1.0, 1.0), 0, _r(-1.0, 1.0)), _r(0, TAU),
				Vector3(0.7, 1.0, 0.9))
	elif r < 0.30:
		_prop(p, "debris", o + Vector3(_r(-1.2, 1.2), 0, _r(-1.2, 1.2)), _r(0, TAU))
	elif r < 0.40:
		_prop(p, "hospital_bed", o + Vector3(_r(-0.8, 0.8), 0, 1.2), PI * 0.5,
				Vector3(2.1, 0.62, 1.0))
	elif r < 0.48:
		_prop(p, "papers", o + Vector3(_r(-1.4, 1.4), 0.01, _r(-1.4, 1.4)), _r(0, TAU))
	if _rng.randf() < 0.22:
		_add_locker(p, o + Vector3(_r(-1.2, 1.2), 0, _r(-1.5, 1.5)), _r(0, TAU))


func _add_locker(p: Node3D, pos: Vector3, rot: float) -> void:
	var body := _prop(p, "locker_body", pos, rot, Vector3(0.44, 1.86, 0.52))
	if body == null:
		return
	var doorscn: PackedScene = _prop_scenes["locker_door"]
	var spot := preload("res://scripts/Locker.gd").new()
	p.add_child(spot)
	spot.setup(body, doorscn, pos, rot)
	hiding_spots.append(spot)


# ==========================================================================
#  Éclairage
#  Presque tout est mort. Ce qui reste allumé est faible, jaune sale, et
#  clignote : la lumière doit inquiéter, jamais rassurer.
# ==========================================================================
func _build_lights() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)

	var corridors: Array[Vector2i] = []
	for cell in _cells:
		if _cells[cell] == "C":
			corridors.append(cell)
	corridors.sort_custom(func(a, b): return (a.y * 100 + a.x) < (b.y * 100 + b.x))

	var i := 0
	for cell in corridors:
		i += 1
		var o := world_of(cell.x, cell.y)
		# la suspension est là partout : c'est le décor
		_prop(lights, "ceiling_lamp", o + Vector3(0, WALL_H, 0), _r(-0.2, 0.2))
		# une sur quatre fonctionne encore
		if i % 4 == 1:
			_add_bulb(lights, o + Vector3(0, WALL_H - 0.46, 0),
					Color(1.0, 0.86, 0.62), 1.45, 6.2, _rng.randf() < 0.55)

	# veilleuses de secours, rouges, dans les pièces et aux angles
	var emergency := [Vector2i(1, 3), Vector2i(10, 3), Vector2i(1, 7), Vector2i(10, 7),
			Vector2i(3, 8), Vector2i(8, 8), Vector2i(10, 8), Vector2i(4, 1), Vector2i(8, 1)]
	for cell in emergency:
		if not _cells.has(cell):
			continue
		var o := world_of(cell.x, cell.y)
		_prop(lights, "wall_lamp", o + Vector3(0, 2.35, -1.92), 0.0)
		_add_bulb(lights, o + Vector3(0, 2.35, -1.72), Color(1.0, 0.30, 0.20), 1.15, 4.6, false)

	# le monte-charge : une lueur froide, le seul point de fuite du niveau
	if _cells.has(Vector2i(11, 9)):
		var o := world_of(11, 9)
		_add_bulb(lights, o + Vector3(0, 2.5, 0), Color(0.62, 0.78, 1.0), 1.6, 6.0, false)


func _add_bulb(parent: Node3D, pos: Vector3, col: Color, energy: float,
		rng_range: float, flicker: bool) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_range
	l.omni_attenuation = 1.6
	l.shadow_enabled = false          # coût trop élevé en GL Compatibility
	l.position = pos
	l.set_meta("base", energy)
	l.add_to_group("bulb")
	parent.add_child(l)
	if flicker:
		var f := preload("res://scripts/Flicker.gd").new()
		l.add_child(f)
		f.setup(l, energy)


# ==========================================================================
#  Navigation : grille d'occupation + A*
# ==========================================================================
func _bake_nav() -> void:
	var minx := 1e9
	var minz := 1e9
	var maxx := -1e9
	var maxz := -1e9
	for cell in _cells:
		minx = minf(minx, cell.x * CELL - CELL * 0.5)
		maxx = maxf(maxx, cell.x * CELL + CELL * 0.5)
		minz = minf(minz, cell.y * CELL - CELL * 0.5)
		maxz = maxf(maxz, cell.y * CELL + CELL * 0.5)
	nav_rect = Rect2i(Vector2i(floori(minx / NAV_RES), floori(minz / NAV_RES)),
			Vector2i(ceili((maxx - minx) / NAV_RES) + 1, ceili((maxz - minz) / NAV_RES) + 1))

	for gy in range(nav_rect.position.y, nav_rect.end.y):
		for gx in range(nav_rect.position.x, nav_rect.end.x):
			var w := Vector3(gx * NAV_RES, 0, gy * NAV_RES)
			if not _walkable(w):
				solid_grid[Vector2i(gx, gy)] = true
	_keep_main_component()


## Remplissage par diffusion depuis le hall. Tout ce qui n'est pas atteignable
## est déclaré solide : la Veilleuse ne cherchera jamais un chemin impossible,
## et aucun fusible ne sera posé dans une pièce coupée du reste.
func _keep_main_component() -> void:
	var start := world_to_grid(spawn_point())
	if solid_grid.has(start):
		for r in range(1, 12):
			var found := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var c := start + Vector2i(dx, dy)
					if not solid_grid.has(c) and nav_rect.has_point(c):
						start = c
						found = true
						break
				if found:
					break
			if found:
				break
	var seen := {start: true}
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var g: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = g + d
			if seen.has(n) or solid_grid.has(n) or not nav_rect.has_point(n):
				continue
			seen[n] = true
			stack.append(n)
	var total := nav_rect.size.x * nav_rect.size.y - solid_grid.size()
	nav_reachable = seen.size()
	nav_total = total
	for gy in range(nav_rect.position.y, nav_rect.end.y):
		for gx in range(nav_rect.position.x, nav_rect.end.x):
			var g := Vector2i(gx, gy)
			if not solid_grid.has(g) and not seen.has(g):
				solid_grid[g] = true
	if total > 0 and float(nav_reachable) / float(total) < 0.85:
		push_warning("Navigation : seulement %d/%d cases atteignables depuis le hall"
				% [nav_reachable, total])


func _walkable(w: Vector3) -> bool:
	# 1. être à l'intérieur d'une case habitable
	var cx := roundi(w.x / CELL)
	var cy := roundi(w.z / CELL)
	if _at(cx, cy) == ".":
		return false
	# 2. se tenir à distance des murs, sauf en face d'une porte
	var lx := w.x - cx * CELL          # -2..2 dans la case
	var lz := w.z - cy * CELL
	var margin := CELL * 0.5 - (0.15 + AGENT_R)
	for dir in [["N", lz < -margin, Vector2i(cx, cy - 1)],
			["S", lz > margin, Vector2i(cx, cy + 1)],
			["W", lx < -margin, Vector2i(cx - 1, cy)],
			["E", lx > margin, Vector2i(cx + 1, cy)]]:
		if not dir[1]:
			continue
		var nb: Vector2i = dir[2]
		var same := _at(nb.x, nb.y) == _at(cx, cy)
		if same:
			continue                                   # même pièce : on passe
		var key := _edge_key(cx, cy, dir[0])
		if _openings.has(key):
			continue
		if _doors.has(key):
			# l'ouverture de porte ne fait que 1,10 m de large
			var across := absf(lz if dir[0] in ["W", "E"] else lx)
			if across < 0.55 - AGENT_R * 0.5:
				continue
		return false
	# 3. ne pas traverser le mobilier
	for b in _nav_blockers:
		var d: Vector3 = (w - b.pos).rotated(Vector3.UP, -b.rot)
		var hx: float = b.size.x * 0.5 + AGENT_R
		var hz: float = b.size.z * 0.5 + AGENT_R
		if absf(d.x) < hx and absf(d.z) < hz:
			return false
	return true


func is_solid(g: Vector2i) -> bool:
	return solid_grid.has(g)


func world_to_grid(w: Vector3) -> Vector2i:
	return Vector2i(roundi(w.x / NAV_RES), roundi(w.z / NAV_RES))


func grid_to_world(g: Vector2i) -> Vector3:
	return Vector3(g.x * NAV_RES, 0.0, g.y * NAV_RES)


# ==========================================================================
#  Points d'apparition
# ==========================================================================
func _pick_spawns() -> void:
	# ronde de la Veilleuse : les couloirs, plus quelques pièces
	for cell in _cells:
		var c: String = _cells[cell]
		if c == "C" or c in ["D", "E", "S", "A", "W", "R"]:
			var w := _free_spot(world_of(cell.x, cell.y))
			if _reachable(w):
				patrol_points.append(w)

	# fusibles : un par aile, jamais deux dans la même pièce
	var candidates := {"D": [], "E": [], "S": [], "A": [], "W": [], "R": [], "H": []}
	for cell in _cells:
		var c: String = _cells[cell]
		if candidates.has(c):
			candidates[c].append(cell)
	var wings := ["D", "E", "S", "A", "W", "R"]
	_shuffle(wings)
	var used: Array[Vector2i] = []
	for i in GameState.FUSES_REQUIRED:
		var placed := false
		# on parcourt les ailes dans l'ordre, puis toutes les autres, jusqu'à
		# trouver une pièce qui offre un emplacement atteignable
		for k in wings.size() * 2:
			var w: String = wings[(i + k) % wings.size()]
			var list: Array = candidates[w]
			if list.is_empty():
				continue
			var cell: Vector2i = list[_rng.randi() % list.size()]
			if cell in used and k < wings.size():
				continue
			var spot := _free_spot(world_of(cell.x, cell.y))
			if _reachable(spot):
				fuse_spawns.append(spot)
				used.append(cell)
				placed = true
				break
		if not placed:
			push_warning("Aucun emplacement atteignable pour le fusible %d" % (i + 1))

	var bat_rooms := ["C", "H", "D", "E", "S", "R"]
	for i in 5:
		var pool: Array = []
		for cell in _cells:
			if _cells[cell] == bat_rooms[i % bat_rooms.size()]:
				pool.append(cell)
		if pool.is_empty():
			continue
		var cell: Vector2i = pool[_rng.randi() % pool.size()]
		var spot := _free_spot(world_of(cell.x, cell.y))
		if _reachable(spot):
			battery_spawns.append(spot)


func _reachable(w: Vector3) -> bool:
	return not solid_grid.has(world_to_grid(w))


## Cherche un emplacement réellement atteignable autour d'un point.
## On balaie la grille de navigation au lieu de tirer au hasard : dans une
## pièce meublée, un tirage aléatoire échoue presque toujours et finissait
## par déposer les fusibles à l'intérieur des meubles.
func _free_spot(center: Vector3, radius := 1.6) -> Vector3:
	for r in [radius, radius + 0.9, radius + 1.8]:
		var found: Array[Vector3] = []
		var g0 := world_to_grid(center - Vector3(r, 0, r))
		var g1 := world_to_grid(center + Vector3(r, 0, r))
		for gy in range(g0.y, g1.y + 1):
			for gx in range(g0.x, g1.x + 1):
				var g := Vector2i(gx, gy)
				if solid_grid.has(g) or not nav_rect.has_point(g):
					continue
				found.append(grid_to_world(g))
		if not found.is_empty():
			return found[_rng.randi() % found.size()]
	return center


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


# ==========================================================================
#  Requêtes
# ==========================================================================
func spawn_point() -> Vector3:
	return world_of(3, 9) + Vector3(0.8, 0.0, 0.8)


func floor_kind_at(w: Vector3) -> String:
	var c := _at(roundi(w.x / CELL), roundi(w.z / CELL))
	return "concrete" if _is_beton(c) else "lino"


func cell_letter_at(w: Vector3) -> String:
	return _at(roundi(w.x / CELL), roundi(w.z / CELL))


func fusebox_position() -> Vector3:
	return world_of(10, 8) + Vector3(0.0, 1.35, -1.80)
