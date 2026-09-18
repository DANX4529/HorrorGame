# RESPIRE — conventions du dépôt

Jeu d'horreur psychologique à la première personne, Godot 4.3.
Tout est produit par les scripts du dépôt : aucune banque d'assets.

---

## Textures : TOUJOURS 3 à 4 variantes

**Règle. Toute texture posée sur une grande surface — sol, mur, plafond —
doit exister en 3 ou 4 variantes.** Une seule, si tuilable soit-elle, se
répète en damier visible dès qu'on la pose sur trente mètres de couloir :
on reconnaît la même tache au même endroit de chaque case, et c'est laid.

Une variante = la même recette, une autre graine. Elles partagent la carte
de normales et l'ORM (la structure — grille de carreaux, grain — est la
même d'une variante à l'autre) et ne diffèrent que par l'albédo, qui est ce
qui porte les taches. C'est ce qui coûte le moins cher : des variantes
complètes pèsent trois fois plus pour un gain qu'on ne voit pas.

Déclarer le nombre de variantes dans `VARIANTES` (`tools/texgen/materials.py`).
Le choix se fait **par case**, par un hachage des coordonnées — jamais avec
`_rng`, qui décalerait tous les tirages suivants et ferait bouger un étage
déjà publié.

## Le raccord se juge à l'œil, pas au nombre

`tools/verify/seams.py` tuile chaque texture 2×2 sur une planche. Une couture
s'y voit en une seconde.

Trois métriques automatiques ont été écrites et jetées : toutes condamnaient
des textures saines (un joint qui tombe sur le bord, deux périodes
superposées). L'outil ne rend donc **aucun verdict** et n'entre pas dans la
barrière CI. Un contrôle qu'on a vu juger mal apprend à passer outre.

## L'étage −1 ne doit pas bouger

C'est le seul étage que des joueurs connaissent. Avant/après tout refactor :

```
tools/.../empreinte.sh <projet> <sortie> 60      # 60 graines, --seedreport
```

L'empreinte (positions des objectifs et documents, nombre de props, cases
navigables, plan ASCII des salles amputées) doit être **identique ligne pour
ligne**. Toute fonctionnalité nouvelle se branche donc de façon qu'un étage
qui ne la déclare pas ne fasse aucun tirage supplémentaire.

## Tout système a son test dans la barrière

Dix tests tournent avant chaque publication (`.github/workflows/release.yml`) :

```
ambiancetest tactiletest v1test menutest rungame
loretest lisibilite sauvetest jettest etagetest
```

Et `--seedcheck` prouve qu'un étage est complétable — à passer sur 40 à 60
graines par étage. Il a déjà attrapé : une graine sur vingt injouable, un
brancard qui coupait un anneau, un local technique entièrement emmuré.

**Une erreur d'analyse GDScript fige le jeu SANS RIEN AFFICHER.** Devant un
lancement qui ne rend rien, faire `--check-only --script res://scripts/X.gd`
plutôt que deviner. Cause la plus fréquente : `:=` sur le retour d'une
méthode appelée sur une variable typée trop large (`level` est `Node3D`).

## Un `match` : le bras `_` en DERNIER

`_` attrape tout et les bras sont essayés dans l'ordre. Placé avant un autre,
il l'avale — silencieusement, parce qu'une branche non prise ne lève rien.

C'est arrivé : dans `_dress_rooms()`, `_` posé au-dessus de `"C"` a supprimé
l'habillage de tous les couloirs — 45 % de l'étage −1, 56 % du −2, cachettes
comprises. Rien n'a planté, aucun test n'a bronché, et le défaut a vécu deux
commits ; seule l'empreinte l'a vu, parce que les tirages manquants
déplaçaient les fusibles.

Leçon générale : **déclarer qu'un cas est géré ne prouve pas qu'il est
atteint.** `--etagetest` bâtit désormais chaque étage et vérifie qu'aucune
lettre ne tombe dans le bras `_`.

## Chaînes de production

| | |
|---|---|
| Modèles | `tools/blender/build_props.py` — une fonction par prop, `bpy` |
| Textures | `tools/texgen/build_textures.py` — numpy, puis `tools/godot/gen_materials.py` |
| Sons | `tools/audio/build_audio.py` — synthèse + sources CC0 recomposées |
| Captures | `tools/verify/playtest.py NOM --tp X Z --yaw D --light E` |

Un étage entier est de la **donnée** (`game/scripts/Etages.gd`) : plan,
matériaux, mobilier, sols, objectif. Agrandir le jeu = ajouter une ligne.

## Langue

Code, commentaires, messages de commit et texte de jeu : **en français**.
Les commentaires disent *pourquoi*, pas *quoi*.
