extends Node
## Le fond narratif de RESPIRE.
##
## Tout le texte du jeu vit ici, dans une table. Ajouter du récit — une mise à
## jour, un chapitre entier — consiste à ajouter des entrées à DOCUMENTS : le
## placement dans le niveau, le journal, la persistance et la progression s'y
## adaptent seuls. Aucun code à toucher.
##
## Chaque entrée :
##   id      clé stable, sert à la sauvegarde — NE JAMAIS la renommer, sinon
##           les joueurs perdent ce qu'ils ont déjà trouvé
##   chap    numéro de chapitre (voir CHAPITRES)
##   titre   ce qui s'affiche en tête du document et dans le journal
##   genre   "note", "dossier", "registre", "lettre", "carnet", "mur"
##   lieu    lettres des salles où le document a un sens (voir LevelBuilder.MAP).
##           Donner PLUSIEURS choix n'est pas une commodité : les salles sont
##           petites et meublées, et le placeur impose un écart minimal entre
##           deux documents. Enfermer plusieurs documents dans une seule salle
##           les fait déborder au couloir, où ils perdent le sens que le lieu
##           leur donnait. En viser deux ou trois est la bonne pratique.
##   texte   le corps du document

const CHAPITRES := {
	1: "Le service de veille",
	2: "La cure d'obscurité",
	3: "Marthe",
}

const DOCUMENTS := [
# =========================================================================
#  CHAPITRE I — LE SERVICE DE VEILLE
#  Ce que ce lieu était, et la règle qui y régnait.
# =========================================================================
{
	"id": "plaque_service", "chap": 1, "genre": "mur", "lieu": ["H"],
	"titre": "Plaque de service",
	"texte": """SANATORIUM DU MONT-CENDRE
NIVEAU −1 — SERVICE DE VEILLE

Le silence est un soin.

Prière de ne pas réveiller les pensionnaires.""",
},
{
	"id": "note_eclairage", "chap": 1, "genre": "note", "lieu": ["A", "C"],
	"titre": "Note de service n° 14",
	"texte": """Il est rappelé au personnel de nuit que l'éclairage du
niveau −1 demeure interdit en dehors des rondes.

Les lampes portatives sont remises en début de service et
restituées à la relève. Aucune exception ne sera tolérée.

Les pensionnaires du service de veille ne supportent pas
la lumière. Ils la réclament pourtant, et avec insistance.
Ne cédez pas : céder une fois, c'est devoir céder toutes
les nuits.

Le directeur""",
},
{
	"id": "registre_admissions", "chap": 1, "genre": "registre", "lieu": ["A", "R"],
	"titre": "Registre d'admission — page arrachée",
	"texte": """ADMISSIONS — SERVICE DE VEILLE — 1959

14.03  BRUNET, Colette, 34 ans
       terreurs nocturnes depuis sept ans
02.04  MAHÉ, Julien, 41 ans
       insomnie totale, refus du sommeil
19.04  SERRE, Aimé, 58 ans
       hurle au coucher, calme le jour
27.05  DELORME, Paule, 9 ans
       ne dort plus depuis la mort de sa mère

La colonne SORTIES est vide sur toute la page.
Elle l'est aussi sur les suivantes.""",
},
{
	"id": "fiche_veilleuse", "chap": 1, "genre": "dossier", "lieu": ["S", "A"],
	"titre": "Fiche de poste — veilleuse de nuit",
	"texte": """La veilleuse porte l'unique lampe du service.

Elle effectue une ronde toutes les quarante minutes.
À chaque porte, elle s'arrête et elle écoute.

Un pensionnaire qui dort ne fait aucun bruit.
Un pensionnaire éveillé doit être signalé au médecin
de garde, et ramené au sommeil par les moyens prescrits.

Ne jamais courir dans le service.
Le bruit réveille ceux qui étaient calmes.""",
},

# =========================================================================
#  CHAPITRE II — LA CURE D'OBSCURITÉ
#  Ce qu'on a fait ici, et la logique qui l'a permis.
# =========================================================================
{
	"id": "lacaze_theorie", "chap": 2, "genre": "note", "lieu": ["S"],
	"titre": "Communication du Dr Lacaze",
	"texte": """La terreur n'entre pas par l'oreille.
Elle entre par l'œil.

Le patient ne craint pas ce qu'il entend : il craint ce
qu'il croit voir. Rendez-lui l'obscurité complète et vous
lui ôtez la matière même de sa peur.

On m'objecte que l'obscurité effraie. C'est une confusion.
Ce n'est pas le noir qui effraie, c'est ce que l'œil y
cherche encore.

Il faut donc que l'œil cesse de chercher.

H. Lacaze""",
},
{
	"id": "protocole_cure", "chap": 2, "genre": "dossier", "lieu": ["S"],
	"titre": "Protocole — cure d'obscurité",
	"texte": """PHASE I — Obscurité continue, quatorze jours.
  Aucune lampe. Repas servis à l'aveugle.

PHASE II — Bandage occlusif, vingt et un jours.
  Retiré une fois par semaine pour examen.

PHASE III — Suture palpébrale.
  Réservée aux cas rebelles aux phases I et II.
  Intervention sous anesthésie locale.
  Durée : quarante minutes environ.

La phase III est irréversible. Le consentement écrit
du pensionnaire est requis, ou à défaut celui de la
famille, ou à défaut celui de l'administration.""",
},
{
	"id": "observation_17", "chap": 2, "genre": "dossier", "lieu": ["S", "D", "E"],
	"titre": "Observation clinique — pensionnaire n° 17",
	"texte": """J+3 après phase III.

Le pensionnaire ne crie plus.

Il reste assis sur le bord du lit, la tête un peu
inclinée. Il écoute. Il écoute avec une attention que je
n'avais observée chez aucun de mes patients.

Interrogé, il répond calmement qu'il n'a plus peur.
Interrogé sur ce qu'il écoute, il répond qu'il écoute
si quelqu'un d'autre est réveillé.

Résultat consigné : succès.""",
},
{
	"id": "lettre_pensionnaire", "chap": 2, "genre": "lettre", "lieu": ["D", "E"],
	"titre": "Lettre non postée",
	"texte": """Ma chère sœur,

On me dit que c'est demain. On me dit que ça dure moins
d'une heure et qu'après je dormirai enfin.

Je voudrais que tu saches que j'ai signé. Personne ne
m'a forcé. J'ai signé parce que je n'ai pas dormi depuis
onze semaines et que je ne sais plus ce que je ferais
d'une douzième.

Ne viens pas. Je ne veux pas que ce soit toi qui voies
ça en premier.

Si tu reçois cette lettre, c'est que quelqu'un l'a
trouvée. Je n'ai pas pu la donner : on ne donne rien à
personne, ici, après huit heures.

Julien""",
},

# =========================================================================
#  CHAPITRE III — MARTHE
#  Qui elle était, et ce qu'elle a choisi.
# =========================================================================
{
	"id": "carnet_marthe_1", "chap": 3, "genre": "carnet", "lieu": ["C", "R"],
	"titre": "Carnet de Marthe — I",
	"texte": """Ronde de 23 h 40.

Chambre 2, éveillée. Chambre 5, éveillé. Chambre 9,
éveillée — c'est la petite Delorme, elle respire trop
vite, elle croit que je ne l'entends pas.

Je dois les signaler. Je les signale.

J'ai remarqué une chose : quand je m'arrête devant une
porte, celui qui est derrière retient son souffle. Tous.
Sans se concerter, sans se voir. Ils ont appris ça tout
seuls.

C'est la seule chose qu'on leur laisse décider.""",
},
{
	"id": "carnet_marthe_2", "chap": 3, "genre": "carnet", "lieu": ["C", "R", "W"],
	"titre": "Carnet de Marthe — II",
	"texte": """Ronde de 2 h.

Je n'ai signalé personne cette nuit. Ni la précédente.

Je laisse la lampe un moment devant chaque porte, le
temps que la lumière passe sous le battant. Ils ne
peuvent pas la voir, la plupart. Mais ils sentent la
chaleur, je crois, ou bien ils entendent que je reste.

Le docteur dit que la lumière leur fait du mal.

Je veux bien le croire. Mais je vois bien qu'ils
attendent mes pas, et que ce n'est pas de la peur.""",
},
{
	"id": "consentement_marthe", "chap": 3, "genre": "dossier", "lieu": ["A", "S"],
	"titre": "Formulaire de consentement",
	"texte": """CURE D'OBSCURITÉ — PHASE III
CONSENTEMENT DU SUJET

Nom : DELAUNAY, Marthe
Qualité : veilleuse de nuit, service de veille
Âge : 29 ans

Motif de l'intervention :
  à titre de démonstration.

Observation du praticien :
  Le sujet ne présente aucun trouble du sommeil.
  Le sujet a insisté à trois reprises.
  Le sujet déclare que les pensionnaires accepteront
  plus volontiers s'ils savent que quelqu'un est passé
  avant eux.

Signature du sujet : M. Delaunay""",
},
{
	"id": "carnet_marthe_3", "chap": 3, "genre": "carnet", "lieu": ["D", "E", "W", "C"],
	"titre": "Carnet de Marthe — III",
	"texte": """Les lignes se chevauchent, écrites sans regarder.

j'écris gros parce que je ne sais pas si j'écris droit

ce n'est pas le noir. le noir je l'avais déjà, on l'a
tous ici. c'est que le noir ne s'arrête plus quand on
ouvre

j'entends le couloir maintenant. j'entends lequel de
mes pas sonne creux. je sais où est chaque porte rien
qu'au bruit que ma jupe fait contre le mur

je continue les rondes. personne ne m'a dit d'arrêter

ils respirent moins fort quand je passe. ils
me reconnaissent""",
},
{
	"id": "derniere_ronde", "chap": 3, "genre": "note", "lieu": ["T", "M"],
	"titre": "Ordre d'évacuation",
	"texte": """MONT-CENDRE — 9 NOVEMBRE 1961

Le service de veille est fermé sur décision
préfectorale à compter de ce jour.

Les pensionnaires transférables ont été remontés par le
monte-charge entre 6 h et 11 h.

Le courant du niveau −1 sera coupé au tableau après
le passage du dernier agent.

Mademoiselle Delaunay, veilleuse, a refusé de remonter.
Elle a déclaré qu'elle terminait sa ronde.

Le monte-charge a été condamné à 11 h 40.""",
},
{
	"id": "inscription_dortoir", "chap": 3, "genre": "mur", "lieu": ["D", "E", "W", "S"],
	"titre": "Gravé dans la peinture",
	"texte": """Creusé à l'ongle, très profond, repassé
un grand nombre de fois :

      E L L E   N E   F A I T   P A S
         D E   M A L

      E L L E   C R O I T   Q U E
         T U   N E   D O R S   P A S""",
},
]


## Index id -> document, construit une fois.
var _par_id: Dictionary = {}


func _ready() -> void:
	for d in DOCUMENTS:
		_par_id[d["id"]] = d


func doc(id: String) -> Dictionary:
	return _par_id.get(id, {})


func total() -> int:
	return DOCUMENTS.size()


## Documents d'un chapitre, dans l'ordre de la table.
func du_chapitre(n: int) -> Array:
	return DOCUMENTS.filter(func(d): return int(d["chap"]) == n)


## Chapitres réellement peuplés, triés. Un chapitre déclaré mais encore vide
## n'apparaît pas : une mise à jour peut donc préparer son titre à l'avance.
func chapitres() -> Array:
	var v := []
	for n in CHAPITRES:
		if not du_chapitre(n).is_empty():
			v.append(n)
	v.sort()
	return v
