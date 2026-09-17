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
		"objectif": {
			"nombre": 4,
			"objet": "Fusible céramique",
			"panneau": "Tableau électrique",
		},
		"sols": {},
		"veilleuse": {},
		"lampe": true,
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
