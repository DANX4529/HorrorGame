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
##   niveau  étage où le document se trouve. Un papier du pavillon C n'a rien
##           à faire au service de veille : c'est ce champ qui l'y retient.
##   titre   ce qui s'affiche en tête du document et dans le journal
##   genre   "note", "dossier", "registre", "lettre", "carnet", "mur"
##   lieu    lettres des salles où le document a un sens (voir LevelBuilder.MAP).
##           Donner PLUSIEURS choix n'est pas une commodité : les salles sont
##           petites et meublées, et le placeur impose un écart minimal entre
##           deux documents. Enfermer plusieurs documents dans une seule salle
##           les fait déborder au couloir, où ils perdent le sens que le lieu
##           leur donnait. En viser deux ou trois est la bonne pratique.
##   texte   le corps du document

## Prologue, frappé à l'écran avant la première image du jeu.
##
## Il pose la situation SANS livrer le récit : le service, la date, le fait que
## quelqu'un soit resté. Qui elle était, ce qu'on lui a fait et pourquoi elle
## l'a demandé se découvrent dans les documents — un prologue qui raconterait
## tout enlèverait toute raison de fouiller.
##
## Une ligne vide marque une respiration ; la frappe y marque un temps d'arrêt.
const PROLOGUE := """Sanatorium du Mont-Cendre.

Le service de veille occupait le niveau −1.
On y plaçait ceux qui ne dormaient plus.

On y soignait la peur en supprimant la lumière.

Le 9 novembre 1961, le service a été fermé.
Le courant coupé. Le monte-charge condamné.

Tout le monde est remonté.

Presque.

Soixante ans ont passé.

Vous descendez chercher un dossier
que personne n'a jamais transmis.

Le tableau électrique est au fond.
Il manque quatre fusibles.

Elle ne vous verra pas.

Elle vous écoute."""


## Crédits. Chaque entrée : [titre de section, lignes].
##
## Les enregistrements sont tous sous CC0 1.0 : l'attribution est donnée par
## honnêteté, pas par obligation. Elle doit rester d'accord avec
## docs/CREDITS_AUDIO.md, qui est engendré par tools/audio/sources.py.
const CREDITS := [
	["", [
		"RESPIRE",
		"Sanatorium du Mont-Cendre — 1961",
		"version 1.3.3",
	]],
	["Conception, écriture et réalisation", [
		"Liam RIIS",
	]],
	["Moteur", [
		"Godot Engine 4.3 — licence MIT",
		"godotengine.org",
	]],
	["Modèles et textures", [
		"Créés pour ce jeu, sans banque d'assets.",
		"Décors, mobilier et la Veilleuse sont bâtis par script",
		"sous Blender ; les textures sont engendrées en numpy",
		"(bruits tuilables, normales, occlusion).",
	]],
	["Enregistrements sonores — tous CC0 1.0", [
		"Owlish Media (owlstorm) — Sound Effects Pack",
		"      respiration, halètement, cri, pas, impacts,",
		"      grondement du bâtiment, horloge, toux",
		"rubberduck — 100 CC0 metal and wood SFX",
		"      portes, serrures, tôle, grincements,",
		"      chutes, sommiers, claquements lointains",
		"Fantozzi — Fantozzi's Footsteps",
		"      pas sur pierre",
		"qubodup — Ghost Monster Voice Moaning & Growling",
		"      râles de la Veilleuse, plaintes lointaines",
		"Spring Spring — Dark Cavern Ambient",
		"      nappe d'ambiance souterraine",
		"Ogrebane — Heartbeat sounds",
		"      battement de coeur",
		"Tous sur opengameart.org",
	]],
	["Bande-son synthétisée", [
		"Apnée, nappe de traque, remise sous tension, stings et",
		"les trois nappes de dread sont synthétisés pour ce jeu",
		"(DSP numpy). Les bruits d'ambiance sont recomposés à",
		"partir des enregistrements ci-dessus : ralentis,",
		"transposés, éloignés dans une réverbération.",
	]],
	["Sur téléphone", [
		"Le jeu détecte le doigt et adapte ses commandes :",
		"manche à gauche, visée à droite, boutons à portée de pouce.",
		"À jouer en paysage.",
	]],
	["Merci", [
		"À celles et ceux qui ont testé dans le noir.",
	]],
]


const CHAPITRES := {
	1: "Le service de veille",
	2: "La cure d'obscurité",
	3: "Marthe",
	4: "Le pavillon C",
	5: "Les bains",
}

const DOCUMENTS := [
# =========================================================================
#  CHAPITRE I — LE SERVICE DE VEILLE
#  Ce que ce lieu était, et la règle qui y régnait.
# =========================================================================
{
	"id": "plaque_service", "chap": 1, "niveau": -1, "genre": "mur", "lieu": ["H"],
	"titre": "Plaque de service",
	"texte": """SANATORIUM DU MONT-CENDRE
NIVEAU −1 — SERVICE DE VEILLE

Le silence est un soin.

Prière de ne pas réveiller les pensionnaires.""",
},
{
	"id": "note_eclairage", "chap": 1, "niveau": -1, "genre": "note", "lieu": ["A", "C"],
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
	"id": "registre_admissions", "chap": 1, "niveau": -1, "genre": "registre", "lieu": ["A", "R"],
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
	"id": "fiche_veilleuse", "chap": 1, "niveau": -1, "genre": "dossier", "lieu": ["S", "A"],
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
	"id": "lacaze_theorie", "chap": 2, "niveau": -1, "genre": "note", "lieu": ["S"],
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
	"id": "protocole_cure", "chap": 2, "niveau": -1, "genre": "dossier", "lieu": ["S"],
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
	"id": "observation_17", "chap": 2, "niveau": -1, "genre": "dossier", "lieu": ["S", "D", "E"],
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
	"id": "lettre_pensionnaire", "chap": 2, "niveau": -1, "genre": "lettre", "lieu": ["D", "E"],
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
	"id": "carnet_marthe_1", "chap": 3, "niveau": -1, "genre": "carnet", "lieu": ["C", "R"],
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
	"id": "carnet_marthe_2", "chap": 3, "niveau": -1, "genre": "carnet", "lieu": ["C", "R", "W"],
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
	"id": "consentement_marthe", "chap": 3, "niveau": -1, "genre": "dossier", "lieu": ["A", "S"],
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
	"id": "carnet_marthe_3", "chap": 3, "niveau": -1, "genre": "carnet", "lieu": ["D", "E", "W", "C"],
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
	"id": "derniere_ronde", "chap": 3, "niveau": -1, "genre": "note", "lieu": ["T", "M"],
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
	"id": "inscription_dortoir", "chap": 3, "niveau": -1, "genre": "mur", "lieu": ["D", "E", "W", "S"],
	"titre": "Gravé dans la peinture",
	"texte": """Creusé à l'ongle, très profond, repassé
un grand nombre de fois :

      E L L E   N E   F A I T   P A S
         D E   M A L

      E L L E   C R O I T   Q U E
         T U   N E   D O R S   P A S""",
},
# =========================================================================
#  CHAPITRE IV — LE PAVILLON C   (niveau −2)
#  Ce qui s'est passé en bas, et qui a ouvert les portes.
# =========================================================================
{
	"id": "pavillon_consigne", "chap": 4, "niveau": -2, "genre": "mur",
	"lieu": ["P", "C"],
	"titre": "Consigne permanente",
	"texte": """PAVILLON C — NIVEAU −2

Le silence est observé sans interruption.

Il n'est pas demandé aux pensionnaires de dormir.
Il leur est demandé de ne pas faire de bruit.

Le personnel de nuit circule sans annoncer son passage.

Toute parole, tout appel, tout coup porté à une porte
sera consigné au dossier du pensionnaire.""",
},
{
	"id": "pavillon_affectation", "chap": 4, "niveau": -2, "genre": "registre",
	"lieu": ["G", "A"],
	"titre": "Tableau d'affectation — novembre",
	"texte": """PAVILLON C — SERVICE DE NUIT

  21 h – 5 h     DELAUNAY, M.        (seule)

  Effectif du pavillon        31
  dont transférables          19
  dont NON TRANSFÉRABLES      12

Rappel : les non-transférables ne quittent le pavillon
sous aucun prétexte, y compris en cas d'alerte.

Une seule veilleuse par nuit. Le docteur estime qu'un
effectif plus nombreux produirait trop de bruit.""",
},
{
	"id": "liste_non_transferables", "chap": 4, "niveau": -2, "genre": "dossier",
	"lieu": ["A", "R"],
	"titre": "Liste des non-transférables",
	"texte": """PHASE III ACHEVÉE — NE PEUVENT ÊTRE PRÉSENTÉS
À L'EXTÉRIEUR

  ch. 2   BRUNET, Aimée           14 ans
  ch. 4   COLLIN, Marcel          9 ans
  ch. 5   DELORME, Jeanne         11 ans
  ch. 7   FAURE, Henri            8 ans
  ch. 9   GARNIER, Suzanne        12 ans
  ...

  ch. 14  DELAUNAY, Marthe        29 ans
                                  (à titre de
                                  démonstration)

Motif commun : état des paupières.""",
},
{
	"id": "incident_rapport", "chap": 4, "niveau": -2, "genre": "dossier",
	"lieu": ["G", "A"],
	"titre": "Rapport d'incident — nuit du 3 au 4",
	"texte": """À 3 h 15, l'agent de relève a trouvé le pavillon C
vide de ses chambres et ses douze pensionnaires
non transférables réunis dans la salle commune.

Ils se tenaient debout, en cercle, sans lumière.

Ils ne parlaient pas. Interrogés, ils n'ont pas
répondu. Aucun n'a cherché à fuir. Aucun n'a été
trouvé blessé.

Aucune serrure n'a été forcée. Les douze portes
avaient été ouvertes de l'extérieur, dans l'ordre
de la ronde.

L'agent déclare qu'en entrant il a entendu, avant
de faire de la lumière, qu'ils respiraient tous
ensemble.""",
},
{
	"id": "carnet_marthe_4", "chap": 4, "niveau": -2, "genre": "carnet",
	"lieu": ["C", "D", "E", "R"],
	"titre": "Carnet de Marthe — IV",
	"texte": """Nuit du 3.

Je les ai fait sortir.

Ça fait onze semaines qu'ils sont seuls dans le noir
à quatre mètres les uns des autres, et qu'ils
s'écoutent respirer à travers les murs sans pouvoir
se répondre. Ils savaient déjà qui était où. Ils
n'avaient besoin de personne pour se trouver.

Je n'ai eu qu'à ouvrir.

Ils se sont mis en cercle tout seuls. Personne n'a
parlé. La petite Delorme m'a cherché la main, et
quand elle l'a eue elle n'a plus bougé.

On écrira que c'est un incident.

Je recommencerai demain.""",
},
{
	"id": "lacaze_defense", "chap": 4, "niveau": -2, "genre": "lettre",
	"lieu": ["G", "S", "A"],
	"titre": "Lettre du Dr Lacaze à la direction",
	"texte": """Monsieur le Directeur,

L'incident du pavillon C ne met pas la cure en cause.
Il la confirme.

Douze sujets privés de vue se sont rassemblés dans
l'obscurité totale, sans un mot, en se guidant sur le
seul souffle de leurs voisins. Aucun sujet ordinaire
n'en serait capable. C'est précisément le degré
d'écoute que la Phase III recherche.

Ce qui doit être corrigé n'est pas le traitement,
mais la surveillance. Une veilleuse qui ouvre les
portes n'est plus une veilleuse.

Je demande son retrait immédiat du service de nuit.

                                        L. LACAZE""",
},
{
	"id": "pavillon_graffiti", "chap": 4, "niveau": -2, "genre": "mur",
	"lieu": ["D", "E", "P"],
	"titre": "Sous la peinture écaillée",
	"texte": """Douze traits creusés côte à côte, à hauteur
d'enfant assis. Le douzième est repassé plus
profond que les autres.

En dessous, d'une autre main, plus haut :

      O N   E S T   T O U S   L À

Et plus bas, minuscule, presque effacé :

      e l l e   a u s s i""",
},
# =========================================================================
#  CHAPITRE V — LES BAINS   (niveau −3)
#  Où l'on envoyait ceux qui faisaient du bruit.
# =========================================================================
{
	"id": "bains_reglement", "chap": 5, "niveau": -3, "genre": "mur",
	"lieu": ["C", "B"],
	"titre": "Règlement affiché",
	"texte": """HYDROTHÉRAPIE — NIVEAU −3

Le bain prolongé n'est pas une punition.

C'est un apaisement. Le pensionnaire y est descendu
lorsque son agitation trouble le repos des autres.

Durée minimale : six heures.
Durée maximale : à l'appréciation du service.

L'eau est maintenue à trente-quatre degrés.

Il est inutile d'appeler. La galerie est carrelée,
et le personnel n'entend rien depuis le palier.""",
},
{
	"id": "bains_registre", "chap": 5, "niveau": -3, "genre": "registre",
	"lieu": ["N", "V"],
	"titre": "Registre des bains — novembre",
	"texte": """  NOM              ENTRÉE   SORTIE

  COLLIN, M.        21 h 10   6 h 05
  BRUNET, A.        21 h 40   7 h 20
  FAURE, H.         22 h 00   —
  GARNIER, S.       22 h 15   —
  DELORME, J.       22 h 30   —
  BRUNET, A.        23 h 05   —

  (six lignes suivantes, même écriture,
   colonne SORTIE vide)

Note du service : cesser de porter les heures de
sortie tant que la mesure est en cours.""",
},
{
	"id": "bains_protocole", "chap": 5, "niveau": -3, "genre": "dossier",
	"lieu": ["N", "O"],
	"titre": "Protocole — bain continu",
	"texte": """1. Le sujet est immergé jusqu'aux épaules.

2. Une toile est tendue au-dessus de la baignoire
   et fermée au cou. Le sujet ne peut pas se lever
   seul. C'est l'effet recherché.

3. La température est vérifiée toutes les heures.
   En cas de baisse, ouvrir la vanne d'appoint.

4. Le sujet ne doit pas être laissé dans le noir :
   la privation combinée de la vue et du mouvement
   produit une agitation contraire au but.

   (Cette clause est rayée. Au-dessus, d'une autre
   main : « ne s'applique pas aux sujets de
   Phase III ».)""",
},
{
	"id": "bains_delorme", "chap": 5, "niveau": -3, "genre": "dossier",
	"lieu": ["B", "O"],
	"titre": "Fiche de bain — DELORME, Jeanne",
	"texte": """DELORME, Jeanne — 11 ans — ch. 5
Phase III achevée le 2 septembre.

Motif de descente : a parlé après l'extinction.
A recommencé après rappel à l'ordre.

Entrée : 4 novembre, 22 h 30.

Observations horaires :
  23 h 30   calme
  00 h 30   calme
  01 h 30   calme, demande si quelqu'un est là
  02 h 30   calme
  03 h 30   —
  04 h 30   —

La surveillance de nuit n'a pas été assurée après
3 h : la veilleuse affectée a quitté son poste.""",
},
{
	"id": "carnet_marthe_5", "chap": 5, "niveau": -3, "genre": "carnet",
	"lieu": ["C", "V", "L"],
	"titre": "Carnet de Marthe — V",
	"texte": """Ils ne m'ont pas renvoyée. Ils m'ont descendue.

Le docteur a écrit que je n'étais plus une veilleuse.
Il a raison. En bas, il n'y a rien à veiller : ils
sont sanglés sous une toile et ils ne peuvent pas
sortir, alors on n'a plus besoin de personne pour
les surveiller.

On a besoin de quelqu'un pour relever la température.

Je descends les voir un par un. Je dis mon nom en
entrant, chaque fois, parce qu'ils ne peuvent plus
voir qui arrive et que l'eau fait du bruit.

La galerie est carrelée. J'ai compris pourquoi ils
l'ont voulue comme ça.""",
},
{
	"id": "bains_chaudiere", "chap": 5, "niveau": -3, "genre": "note",
	"lieu": ["N", "T"],
	"titre": "Consigne de chauffe",
	"texte": """NOURRICE PRINCIPALE — NIVEAU −3

Les quatre volants de vanne ont été déposés et
rangés séparément sur ordre du service.

Sans eux, l'eau des bassins ne peut être ni
réchauffée ni vidangée.

Cette mesure est provisoire. Elle vise à empêcher
qu'une personne non habilitée n'ouvre les vidanges
pendant la nuit.

                              Visa : L. LACAZE""",
},
{
	"id": "bains_graffiti", "chap": 5, "niveau": -3, "genre": "mur",
	"lieu": ["B", "V"],
	"titre": "Sous le carrelage descellé",
	"texte": """Gravé dans le joint, à hauteur de baignoire,
par quelqu'un qui ne pouvait pas voir ce qu'il
écrivait — les lettres se chevauchent :

      J E   N E   D O R S   P A S

      D I S   T O N   N O M""",
},
]


## Index id -> document, construit une fois.
var _par_id: Dictionary = {}


func _ready() -> void:
	for d in DOCUMENTS:
		_par_id[d["id"]] = d


func doc(id: String) -> Dictionary:
	return _par_id.get(id, {})


## Les documents d'un étage donné.
func du_niveau(niveau: int) -> Array:
	var v := []
	for d in DOCUMENTS:
		if int(d.get("niveau", -1)) == niveau:
			v.append(d)
	return v


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
