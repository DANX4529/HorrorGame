# RESPIRE

> *Sanatorium du Mont-Cendre, 1961.*
> *Quelque chose arpente les couloirs. C'est aveugle. Ça chasse au son.*
> *Et le bruit le plus fort dans un bâtiment vide, c'est votre propre respiration.*

Jeu d'horreur psychologique à la première personne. **Godot 4.3.**
Tous les assets — modèles, textures, animations, sons — sont **fabriqués par
les scripts de ce dépôt**. Rien n'est téléchargé.

---

## Jouer

1. Télécharger **Godot 4.3** (standard, pas .NET) : https://godotengine.org/download
2. Cloner ce dépôt, puis :

```bash
git clone https://github.com/danx4529/horrorgame.git
cd horrorgame
```

3. Lancer le jeu :

```bash
godot --path game
```

Ou : ouvrir Godot → **Importer** → sélectionner `game/project.godot` → **Jouer** (F5).

> Le premier lancement importe ~250 fichiers (textures 1024², modèles, sons) :
> comptez une à deux minutes. Les lancements suivants sont immédiats.

Le jeu utilise le renderer **GL Compatibility** : il tourne sans Vulkan, y
compris sur machine modeste ou en VM.

### Commandes

| Touche | Action |
|---|---|
| ZQSD / WASD | Se déplacer |
| Souris | Regarder |
| Maj gauche | Courir |
| **Ctrl gauche (maintenu)** | **Retenir sa respiration** |
| C | S'accroupir |
| E | Interagir / ramasser / entrer et sortir d'une cachette |
| F | Lampe torche |
| Échap | Pause |

### But

Le monte-charge du sous-sol est la seule sortie. Il lui manque **4 fusibles
céramiques**, dispersés dans le bâtiment. Les trouver, les poser au tableau
électrique de la chaufferie, puis atteindre le monte-charge.

Rétablir le courant fait un bruit énorme. Elle l'entendra.

---

## Le pilier de conception : la respiration

Une seule ressource, et tout en découle.

```
        exploration              elle approche
   ┌──────────────────┐      ┌────────────────────┐
   │  calme, souffle  │─────▶│  choix : APNÉE ?   │
   │  qui se régénère │      │  ou FUITE ?        │
   └────────▲─────────┘      └─────────┬──────────┘
            │                          │
            │   elle s'éloigne         ▼
            └──────────────┬───  apnée : silence, mais
                           │      le souffle se vide — et
                           │      à zéro, HALÈTEMENT
                           │
                     fuite : on la sème,
                     mais on reste ESSOUFFLÉ
                     (donc bruyant) 10 secondes
```

**La panique se paye.** Courir sauve l'instant présent et condamne les dix
secondes suivantes. Et plus elle est proche, plus le cœur s'emballe, plus le
souffle part vite : **avoir peur rend le jeu objectivement plus difficile.**

Le détail des rayons sonores, de l'IA et de la direction artistique est dans
[`docs/DESIGN.md`](docs/DESIGN.md).

---

## Régénérer les assets

```bash
pip install bpy pillow numpy        # bpy = Blender 5.0 en module Python

python3 tools/texgen/build_textures.py --res 1024   # 17 matériaux PBR
python3 tools/blender/build_env.py                  # kit architectural
python3 tools/blender/build_props.py                # 21 props
python3 tools/blender/build_entity.py               # la Veilleuse (riggée)
python3 tools/audio/build_audio.py                  # 41 sons
python3 tools/godot/gen_materials.py                # ressources .tres Godot
```

| Dossier | Contenu |
|---|---|
| `tools/texgen/` | Bruits tuilables (valeur, fBm, Worley, ridged) et recettes PBR |
| `tools/blender/` | Bibliothèque bmesh, kit d'environnement, props, personnage |
| `tools/audio/` | DSP numpy et sound design |
| `tools/godot/` | Génération des matériaux Godot |
| `tools/verify/` | Rendus et tests automatisés (voir ci-dessous) |

---

## Vérification

Le projet se teste sans intervention humaine, en rendu logiciel sous Xvfb.

```bash
# capture d'écran depuis n'importe quel point du niveau
python3 tools/verify/playtest.py couloir --tp 20 12 --yaw -90 --light 0.7

# plan du niveau vu de dessus
python3 tools/verify/playtest.py plan --overview 32 --noent

# planche contact des modèles (rendu Cycles)
python3 tools/verify/render_assets.py "game/assets/models/props/*.glb" --out /tmp/props.png

# spectrogrammes du sound design
python3 tools/verify/spectro.py game/assets/audio/*.wav /tmp/spec.png
```

Deux tests d'intégration tournent dans le jeu lui-même :

```bash
# IA : provoque un bruit fort et vérifie que la Veilleuse passe en chasse
# et que la longueur de son chemin décroît réellement jusqu'au joueur
godot --path game -- --autoplay --aitest 34 --tp 20 28

# boucle d'objectif : les 4 fusibles, le tableau, la sortie,
# puis les portes et les cachettes
godot --path game -- --rungame
```

Ces options de ligne de commande n'ont aucun effet sur une partie normale.

---

## Architecture

```
game/
├── project.godot
├── scenes/          Main.tscn (racine nue) + env.tres
├── shaders/         post-traitement (grain, vignettage, aberration)
├── scripts/
│   ├── GameState    phases, objectif, table d'entrées
│   ├── NoiseBus     bus sonore — l'unique perception de la Veilleuse
│   ├── BreathSystem le souffle, la peur, le halètement
│   ├── Player       déplacement, torche, interaction, caméra
│   ├── Veilleuse    machine à états + A* sur grille d'occupation
│   ├── LevelBuilder génère le sanatorium depuis une grille textuelle
│   └── …            Door, Locker, Pickup, FuseBox, ExitGate, HUD, Flicker
└── assets/          models/ textures/ audio/ materials/
```

Le niveau n'est pas placé à la main : `LevelBuilder.MAP` est une grille de
caractères, et murs, portes, mobilier, éclairage, navigation et points
d'apparition en sont déduits. Le plan forme un **anneau de couloirs** pour que
le joueur puisse toujours contourner plutôt que se retrouver acculé.
