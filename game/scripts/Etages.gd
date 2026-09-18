extends Node
## Les étages du sanatorium, comme données.
##
## Agrandir le jeu = ajouter une entrée à ETAGES. Tout le reste — la
## construction du niveau, le placement des documents, la progression, les
## records — se règle sur cette table et n'a pas à être touché.
##
## Même contrat que Lore.gd : le contenu vit ici, la mécanique vit ailleurs.
##
## Champs d'un étage
##   niveau            entier négatif, -1 est le plus haut. C'est la CLÉ de
##                     sauvegarde : ne jamais la renuméroter.
##   titre             nom affiché (écran de descente, cabine, relevé)
##   chapitres         chapitres de Lore présents à cet étage
##   carte             la grille textuelle, une case = 4 m
##   portes            [x, y, direction] — l'arête porte un vantail
##   ouvertures        [x, y, direction] — pas de mur du tout
##   lettres_beton     cases utilisant le kit béton plutôt que lino/plâtre
##   cellule_tableau   case équipée du tableau électrique
##   objectif          {nombre, objet, panneau} — ce qu'il faut réunir
##   sols              lettre -> {kind, bruit} ; absent = sol par défaut
##   veilleuse         surcharges de ses réglages ; {} = valeurs de base
##   lampe             false si la torche ne fonctionne pas à cet étage


const ETAGES := [
	{
		"niveau": -1,
		"titre": "Le service de veille",
		"chapitres": [1, 2, 3],

		# .  maçonnerie pleine / extérieur
		# C  couloir            A  archives         D,E  dortoirs
		# S  salle de soins     W  salle d'eau      H  hall d'entrée
		# R  réserve            T  chaufferie       M  monte-charge (sortie)
		"carte": [
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
		],
		"portes": [
			[2, 2, "S"],            # archives -> couloir
			[4, 2, "S"],            # dortoir D -> couloir
			[8, 2, "S"],            # dortoir E -> couloir
			[3, 6, "S"],            # soins -> couloir
			[7, 6, "S"],            # salle d'eau -> couloir
			[3, 8, "N"],            # hall -> couloir
			[8, 8, "N"],            # réserve -> couloir
			[10, 8, "N"],           # chaufferie -> couloir (porte métallique)
		],
		"ouvertures": [
			[11, 9, "W"],           # chaufferie -> monte-charge
		],
		"lettres_beton": ["T", "M", "R"],
		"cellule_tableau": Vector2i(10, 8),
		# On arrive par l'escalier, dans le hall.
		"depart": Vector2i(3, 9),
		"depart_ecart": Vector3(0.8, 0.0, 0.8),
		# Ces trois listes étaient des valeurs par défaut dans LevelBuilder.
		# Elles sont écrites ici parce que leur ORDRE est tiré au sort avec la
		# graine : laissées ailleurs, elles décideraient du placement d'un étage
		# depuis un fichier qui ne parle pas de lui.
		"ronde": ["C", "D", "E", "S", "A", "W", "R"],
		"ailes": ["D", "E", "S", "A", "W", "R"],
		"piles": ["C", "H", "D", "E", "S", "R"],
		"objectif": {
			"nombre": 4,
			"objet": "Fusible céramique",
			"panneau": "Tableau électrique",
		},
		"sols": {},
		"veilleuse": {},
		"lampe": true,
	},
	{
		"niveau": -2,
		"titre": "Le pavillon C",
		"chapitres": [4],

		# Le pavillon où « l'incident » a eu lieu. Deux anneaux empilés plutôt
		# qu'un seul : on peut toujours la contourner, mais il faut choisir PAR
		# OÙ, et les deux couloirs transversaux sont des pièges à mi-parcours.
		#
		# .  maçonnerie pleine     C  couloir          D,E  dortoirs
		# P  salle commune         G  poste de garde   R    lingerie
		# A  archives              T  local technique  M    monte-charge
		"carte": [
			".............",
			".DDD.PPP.EE..",
			".DDD.PPP.EE..",
			".CCCCCCCCCC..",
			".C...GG...C..",
			".C...GG...C..",
			".CCCCCCCCCC..",
			".C...RR...C..",
			".C...RR...C..",
			".CCCCCCCCCC..",
			".AAA...TTM...",
			".............",
		],
		"portes": [
			[2, 2, "S"],            # dortoir D -> couloir haut
			[6, 2, "S"],            # salle commune -> couloir haut
			[9, 2, "S"],            # dortoir E -> couloir haut
			[5, 4, "N"],            # poste de garde -> couloir haut
			[5, 7, "N"],            # lingerie -> couloir milieu
			[2, 10, "N"],           # archives -> couloir bas
			[7, 10, "N"],           # local technique -> couloir bas
		],
		"ouvertures": [
			[9, 10, "W"],           # local technique -> monte-charge
		],
		"lettres_beton": ["T", "M", "R"],
		"cellule_tableau": Vector2i(7, 10),
		"veilleuses": [
			Vector2i(1, 3), Vector2i(10, 3), Vector2i(1, 6), Vector2i(10, 6),
			Vector2i(1, 9), Vector2i(10, 9), Vector2i(2, 10), Vector2i(6, 1),
			Vector2i(9, 1),
		],
		# On arrive par la cabine : le joueur se réveille où il est descendu.
		"depart": Vector2i(8, 10),
		"depart_ecart": Vector3(0.7, 0.0, 0.7),
		"ronde": ["C", "D", "E", "P", "G", "R", "A"],
		"ailes": ["D", "E", "P", "G", "R", "A"],
		"piles": ["C", "D", "E", "P", "R"],
		"objectif": {
			"nombre": 3,
			"objet": "Disjoncteur",
			"pluriel": "disjoncteurs",
			"panneau": "Armoire électrique",
		},
		"sols": {},
		"veilleuse": {},
		"lampe": true,
		"jetables": 7,
		# Le mobilier du pavillon est plus encombrant que celui du -1 : sans
		# passage garanti d'un bord à l'autre, un brancard en travers suffit à
		# couper l'anneau — et deux coupures amputent l'étage entier.
		"voie_traversante": true,

		# Le mobilier du PAVILLON, par-dessus l'habillage commun. C'est lui qui
		# fait qu'on sent avoir changé d'étage et non de couloir : un brancard
		# abandonné en travers, un paravent qui cache ce qu'il y a derrière,
		# l'horloge du service arrêtée, le comptoir d'où partait la ronde.
		"mobilier": {
			"C": [
				# Le brancard est long de 2 m dans une case de 4 : rare, et
				# rangé le long du mur plutôt que planté en travers.
				{"prop": "gurney", "chance": 0.12, "ecart": 1.4, "rot": 0.0,
				 "boite": Vector3(0.70, 1.10, 2.00)},
				{"prop": "trolley", "chance": 0.14, "ecart": 1.3,
				 "boite": Vector3(0.52, 1.00, 0.70)},
				{"prop": "bench", "chance": 0.10, "ecart": 1.4, "rot": 0.0,
				 "boite": Vector3(1.55, 0.50, 0.45)},
				# meubles muraux : contre la face nord de la case, à hauteur d'œil
				{"prop": "wall_clock", "chance": 0.12, "unique": true,
				 "pos": Vector3(0, 2.28, -1.93), "rot": 0.0},
				{"prop": "coat_rack", "chance": 0.12, "unique": true,
				 "pos": Vector3(0, 1.74, -1.93), "rot": 0.0},
				{"prop": "wall_phone", "chance": 0.08, "unique": true,
				 "pos": Vector3(1.1, 1.52, -1.93), "rot": 0.0},
			],
			"D": [
				{"prop": "screen", "chance": 0.55, "ecart": 1.1,
				 "boite": Vector3(1.20, 1.75, 0.50)},
				{"prop": "trolley", "chance": 0.34, "ecart": 1.2,
				 "boite": Vector3(0.52, 1.00, 0.70)},
				{"prop": "gurney", "chance": 0.22, "ecart": 1.0,
				 "boite": Vector3(0.70, 1.10, 2.00)},
			],
			"E": [
				{"prop": "screen", "chance": 0.55, "ecart": 1.1,
				 "boite": Vector3(1.20, 1.75, 0.50)},
				{"prop": "trolley", "chance": 0.34, "ecart": 1.2,
				 "boite": Vector3(0.52, 1.00, 0.70)},
				{"prop": "gurney", "chance": 0.22, "ecart": 1.0,
				 "boite": Vector3(0.70, 1.10, 2.00)},
			],
			"P": [
				{"prop": "long_table", "chance": 0.72, "unique": true, "ecart": 0.7,
				 "boite": Vector3(2.15, 0.80, 0.85)},
				{"prop": "bench", "chance": 0.62, "ecart": 1.1,
				 "boite": Vector3(1.55, 0.50, 0.45)},
				{"prop": "wall_clock", "chance": 0.45, "unique": true,
				 "pos": Vector3(0, 2.28, -1.93), "rot": 0.0},
			],
			"G": [
				{"prop": "counter", "chance": 0.88, "unique": true,
				 "pos": Vector3(0, 0, -1.30), "rot": 0.0,
				 "boite": Vector3(1.90, 1.10, 0.65)},
				{"prop": "notice_board", "chance": 0.75, "unique": true,
				 "pos": Vector3(-0.9, 1.62, -1.93), "rot": 0.0},
				{"prop": "wall_phone", "chance": 0.68, "unique": true,
				 "pos": Vector3(1.2, 1.52, -1.93), "rot": 0.0},
			],
			"R": [
				{"prop": "shelving", "chance": 0.82, "ecart": 1.0,
				 "boite": Vector3(0.95, 1.90, 0.40)},
				{"prop": "laundry_cart", "chance": 0.58, "unique": true, "ecart": 1.1,
				 "boite": Vector3(0.75, 0.90, 0.55)},
			],
			"A": [
				{"prop": "shelving", "chance": 0.48, "ecart": 1.0,
				 "boite": Vector3(0.95, 1.90, 0.40)},
				{"prop": "coat_rack", "chance": 0.30, "unique": true,
				 "pos": Vector3(0, 1.74, -1.93), "rot": 0.0},
			],
			"T": [
				{"prop": "trolley", "chance": 0.30, "ecart": 0.9,
				 "boite": Vector3(0.52, 1.00, 0.70)},
			],
		},
	},
]


var _par_niveau: Dictionary = {}


func _ready() -> void:
	for e in ETAGES:
		_par_niveau[int(e["niveau"])] = e


## L'étage de ce niveau, ou {} s'il n'existe pas.
func etage(niveau: int) -> Dictionary:
	if _par_niveau.is_empty():
		for e in ETAGES:
			_par_niveau[int(e["niveau"])] = e
	return _par_niveau.get(niveau, {})


## Le premier étage d'une campagne.
func premier() -> int:
	return int(ETAGES[0]["niveau"])


## Le niveau le plus profond qui existe.
func dernier() -> int:
	var d := 0
	for e in ETAGES:
		d = mini(d, int(e["niveau"]))
	return d


## Le niveau sous celui-ci, ou 0 s'il n'y a plus rien en dessous.
func suivant(niveau: int) -> int:
	var n := niveau - 1
	return n if not etage(n).is_empty() else 0


func total() -> int:
	return ETAGES.size()
