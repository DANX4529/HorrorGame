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
- **CHASSE** : ligne droite vers le joueur, rapide (3.4 m/s), respiration audible, musique.

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

Le monte-charge du sous-sol est la seule sortie. Il lui manque **4 fusibles céramiques**,
dispersés dans trois ailes du sanatorium.

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
Casiers métalliques et dessous de lits. Entrer coupe la ligne de vue.
En cachette : vue au travers des fentes, respiration amplifiée, l'entité peut *fouiller*.

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

## 8. Périmètre du vertical slice

- [x] 1 niveau : rez-de-chaussée + aile Est + sous-sol (~30 pièces)
- [x] 1 entité complète avec IA sonore
- [x] Système de souffle complet
- [x] Torche, cachettes, portes, ramassage
- [x] Objectif fusibles + fin de partie (victoire / mort)
- [x] Écrans titre / pause / mort / victoire
