# RESPIRE — Game Design Document
> *« Ici, tout le monde retient son souffle. »*

**Genre** : Horreur psychologique / survie furtive, vue à la première personne
**Moteur** : Godot 4.3 (Forward+ / Mobile-compatible, renderer GL Compatibility supporté)
**Cible** : PC (clavier/souris) — build desktop Linux/Windows
**Durée du vertical slice** : 10–20 minutes

---

## 1. Pitch

Sanatorium du **Mont-Cendre**, 1961. Fermé après « l'incident du pavillon C ».
Vous êtes descendu documenter le bâtiment avant sa démolition. La porte s'est refermée.

Quelque chose arpente les couloirs. C'est **aveugle**. Ça chasse au **son**.

Et le son le plus fort dans un bâtiment vide, c'est **votre propre respiration**.

---

## 2. Le pilier de design : la respiration

Tout le jeu tourne autour d'une seule ressource : **le souffle**.

| État | Bruit émis | Effet sur le souffle |
|---|---|---|
| Immobile / accroupi | très faible | récupération lente |
| Marche | faible | stable |
| **Course** | **fort** | consommation rapide, puis état « essoufflé » persistant |
| **Apnée** (maintien) | **quasi nul** | vidange très rapide |
| **Halètement forcé** (souffle à 0) | **pic maximal** | verrouillage de l'apnée pendant 4 s |

### La boucle de tension
```
        exploration            l'entité approche
   ┌──────────────────┐      ┌────────────────────┐
   │  calme, souffle  │─────▶│  choix : APNÉE ?   │
   │  qui se régénère │      │  ou FUITE ?        │
   └────────▲─────────┘      └─────────┬──────────┘
            │                          │
            │   l'entité s'éloigne     ▼
            └──────────────┬───  apnée : silence mais
                           │      le souffle se vide
                           │
                     fuite : on sème l'entité
                     mais on reste ESSOUFFLÉ
                     (= bruyant) pendant 10 s
```

**La panique se paye.** Courir sauve l'instant présent et condamne les 10 secondes suivantes.
C'est le joueur lui-même qui devient sa propre menace.

### La boucle de peur (feedback négatif)
Plus l'entité est proche → plus le **rythme cardiaque** monte → plus le souffle
se consomme vite → plus l'apnée est courte → plus il est difficile de se cacher.
**Avoir peur rend objectivement le jeu plus dur.**

---

## 3. L'antagoniste — « La Veilleuse »

Ancienne infirmière de nuit du pavillon C. Grande, décharnée, **les yeux recousus**.
Elle se déplace en écoutant. Elle ne court jamais… sauf quand elle vous a localisé.

### Machine à états

```
                  bruit entendu (> seuil)
   ┌─────────┐ ──────────────────────────▶ ┌──────────────┐
   │ PATROUILLE │                          │ INVESTIGATION │
   └─────────┘ ◀────────────────────────── └──────────────┘
        ▲            perte de piste (12 s)         │
        │                                          │ contact direct
        │                                          │ / bruit très fort
        │        perte de vue + silence (8 s)      ▼
        └──────────────────────────────────── ┌────────┐
                                              │ CHASSE │
                                              └────┬───┘
                                                   │ contact < 1.2 m
                                                   ▼
                                              ┌────────┐
                                              │  MORT  │
                                              └────────┘
```

- **PATROUILLE** : parcours de points d'intérêt, lent (1.1 m/s), tête qui pivote.
- **INVESTIGATION** : se dirige vers le dernier bruit, ralentit, fouille la zone (1.5 m/s).
- **CHASSE** : trajet direct vers le joueur, rapide (3,4 m/s), râle audible, musique.

**Elle ouvre les portes.** Une créature qu'un battant arrête n'est pas une
menace ; et le grincement de gond qui la précède renseigne le joueur sur sa
position, ce qui rend la traque lisible plutôt qu'arbitraire.

**Elle ne se coince pas.** Si elle n'avance plus alors qu'un chemin existe
(vantail bloqué, meuble déplacé, angle serré), elle saute le point de passage
courant, recalcule et se décale légèrement.

### Sources de bruit (rayon d'audibilité)
| Source | Rayon |
|---|---|
| Pas accroupi | 3 m |
| Pas marche | 8 m |
| Pas course | 18 m |
| Respiration calme | 4 m |
| Respiration essoufflée | 11 m |
| **Halètement (apnée ratée)** | **22 m** |
| Porte qui grince | 12 m |
| Objet renversé | 16 m |
| Lampe allumée (si ligne de vue) | bonus de détection |

---

## 4. Objectif

Une partie n'est pas une partie : c'est une **descente**. Le monte-charge ne fait
pas gagner, il emmène plus bas. Chaque étage réclame de réunir un petit nombre de
pièces, de les poser, et de rejoindre la cabine.

La *forme* ne change pas d'un étage à l'autre — c'est délibéré : ce qui distingue
les étages, ce sont leurs mécaniques neuves, pas une errance réinventée qu'il
faudrait réapprendre à chaque fois.

**Ce qu'on lit n'est acquis qu'une fois remonté.** Un document ramassé reste *en
main* jusqu'au passage de la cabine ; mourir le laisse en bas, et renvoie au début
de l'étage sur le même plan. C'est là qu'est l'enjeu de la descente.

Au niveau −1, il manque **4 fusibles céramiques** au monte-charge, dispersés dans
trois ailes.

1. Explorer, trouver les 4 fusibles (points d'apparition semi-aléatoires)
2. Les insérer dans le tableau électrique du sous-sol
3. Survivre à la **traque finale** : la Veilleuse entre en chasse permanente
4. Atteindre le monte-charge

---

## 5. Systèmes

### 5.1 Lampe torche
Batterie limitée (90 s d'autonomie). Piles à ramasser. Faisceau étroit + halo.
Allumée, elle **révèle** — mais si la Veilleuse a une ligne de vue, la détection est immédiate.
Clic d'allumage = petit bruit.

### 5.2 Cachettes
Vestiaires métalliques, semés dans les pièces et les couloirs. Entrer met le
joueur hors d'atteinte physique et restreint son champ à celui des ouïes
d'aération (± 41° de débattement, superposition à l'écran).

Mais la Veilleuse est aveugle : se cacher ne la rend pas sourde. Si elle
fouille à moins de 1,70 m et que la respiration porte encore à plus de 2 m,
elle ouvre le casier. **Dans une cachette, l'apnée est la seule défense.**

### 5.3 Portes
Ouverture progressive à la souris (maintenir + glisser). Ouvrir vite = grincement = bruit.

### 5.4 Peur / rythme cardiaque
`heart` 0→1 selon distance et ligne de vue de l'entité.
Effets : battements audibles, vignette qui pulse, aberration chromatique, grain,
tremblement de caméra, consommation du souffle ×(1 + heart).

---

## 6. Contrôles

| Touche | Action |
|---|---|
| ZQSD / WASD | Déplacement |
| Souris | Regarder |
| Maj gauche | Courir |
| **Ctrl gauche (maintenu)** | **Retenir sa respiration** |
| C | S'accroupir |
| E | Interagir / ramasser / entrer-sortir d'une cachette |
| F | Lampe torche |
| Échap | Pause |

---

## 7. Direction artistique

- **Palette** : vert-de-gris hôpital, ocre des lampes de secours, noir profond. Saturation basse.
- **Lumière** : quasi tout est noir. Les seules sources sont la torche, les veilleuses
  de secours rouges, et la lune par les fenêtres brisées.
- **Rendu** : grain de pellicule, vignette lourde, aberration chromatique, léger flou de bord,
  courbe de contraste « bain d'argent ».
- **Son** : nappes graves, craquements de structure, gouttes, et **toujours** la respiration
  du joueur au premier plan du mix.

### Pipeline d'assets (100 % fait maison)
- **Modélisation** : scripts Python `bpy` → Blender 5.0 → export glTF (`.glb`)
- **Textures** : générateur procédural numpy/PIL → albédo + normale + rugosité + AO, tuilables
- **Audio** : synthèse numpy (bruit filtré, granulaire, modèles physiques simples) → `.wav`

---

## 8. Périmètre livré

- [x] **1 niveau de 58 cases de 4 m** (~930 m²), généré depuis une grille
      textuelle : hall, anneau de couloirs, deux dortoirs, salle de soins,
      salle d'eau, archives, réserve, chaufferie, monte-charge.
      Le plan est un **anneau** : le joueur peut toujours contourner.
- [x] **La Veilleuse** : IA sonore complète, 4 états, A* sur grille
      d'occupation à 0,50 m, 5 animations, ouverture des portes.
- [x] **Système de souffle** complet, avec boucle de peur.
- [x] Torche à batterie et piles, cachettes, portes battantes, ramassage,
      tableau électrique, monte-charge.
- [x] Écrans titre / pause / mort / victoire.
- [x] **Assets intégralement produits par le dépôt** : 17 matériaux PBR
      procéduraux, 10 modules d'architecture, 21 props, 1 personnage riggé,
      41 sons synthétisés.

### Les étages

| Étage | Idée neuve | Objectif |
|---|---|---|
| **−1 Le service de veille** | *(l'apprentissage : le souffle, elle)* | 4 fusibles |
| **−2 Le pavillon C** | **Lancer un objet** pour l'attirer ailleurs | 3 disjoncteurs |
| **−3 Les bains** | **Les surfaces** : l'eau et le verre portent votre bruit | 4 volants de vanne |
| −4 La cure d'obscurité *(à venir)* | Le noir total : la lampe meurt | traverser |
| −5 La ronde *(à venir)* | Elle repasse où elle vous a entendu | la trouver |

Le plan d'un étage est de la **donnée** (`game/scripts/Etages.gd`), sur le même
contrat que le récit : agrandir le jeu, c'est ajouter une ligne à la table.

Aux bains, `sols` attribue à chaque lettre de salle un facteur de bruit qui
passe par le MÊME paramètre que le reste — eau 1,70, verre 2,10, lino 0,80.
Ce n'est donc pas un échantillon sonore de plus : c'est réellement la distance
à laquelle elle vous entend qui change, et le chemin le plus court cesse
d'être le plus sûr.

### Ce qui reste ouvert pour une suite

- Trois étages sur les cinq prévus. Restent le −4 (le noir total, où la lampe
  meurt) et le −5 (elle repasse où elle vous a entendu).
- Les trois fins dépendent du −5 : le jeu n'a donc pour l'instant **pas de
  fin**, la descente s'arrête aux bains.
- Une seule entité.
- Les casiers sont la seule forme de cachette (pas de dessous-de-lit).
- Trois documents sur quatorze atterrissent en couloir au niveau −1 quand leurs
  salles de prédilection sont prises. Corriger le placeur déplacerait un étage
  déjà publié : c'est un arbitrage, pas un oubli.

---

## 9. Difficulté et confort

Les paliers de difficulté agissent sur **ce qu'elle perçoit**, jamais sur ce
que le joueur émet : le retour sonore reste identique à tous les niveaux, seule
change la portée de son ouïe. Un joueur qui apprend le jeu en *Veilleur*
apprend donc les mêmes réflexes qu'en *Pensionnaire*.

| | Ouïe | Vitesse | Souffle | Lampe |
|---|---|---|---|---|
| Veilleur | ×0,72 | ×0,86 | ×0,78 | ×1,35 |
| Patient | ×1,00 | ×1,00 | ×1,00 | ×1,00 |
| Pensionnaire | ×1,24 | ×1,12 | ×1,26 | ×0,80 |

Le nombre de fusibles ne bouge pas : la structure de la partie doit rester la
même d'un palier à l'autre.

**Point de contrôle** posé à chaque fusible installé. Dans une partie de quinze
minutes, repartir de zéro à chaque mort décourage plus qu'il n'effraie.

**Réglages** persistés (`user://respire.cfg`) : sensibilité, inversion de l'axe
vertical, luminosité, et cinq volumes sur bus séparés — la respiration a son
propre bus, puisqu'elle est censée dominer le mixage.

---

## 10. Vérification

Le jeu se teste sans intervention humaine, en rendu logiciel sous Xvfb :

| Outil | Ce qu'il vérifie |
|---|---|
| `tools/verify/playtest.py` | Capture d'écran depuis n'importe quel point (téléportation, cap, éclairage de contrôle, vue de dessus) |
| `--aitest N` | La Veilleuse entend un bruit fort, passe en chasse, et la **longueur de son chemin** décroît jusqu'au contact |
| `--rungame` | Les 4 fusibles sont atteignables, le tableau accepte la pose, le monte-charge déclenche la victoire, les portes répondent au rayon du joueur, les cachettes fonctionnent |
| `tools/verify/render_assets.py` | Planches contact Cycles des modèles |
| `tools/verify/spectro.py` | Spectrogrammes du sound design |

Trois défauts de conception ont été trouvés par ces tests, pas à l'œil :
le mobilier aléatoire pouvait **murer une pièce** ; les fusibles
apparaissaient **dans les meubles** ; les portes étaient **injouables**
(volume d'interaction mal parenté).
