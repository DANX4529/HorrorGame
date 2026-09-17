# Crédits audio

Les enregistrements utilisés par RESPIRE proviennent tous de banques
sous **CC0 1.0** (domaine public) : leur redistribution dans ce dépôt
est libre et sans obligation. L'attribution ci-dessous est donnée par
honnêteté, pas par obligation légale.

Le reste de la bande-son (apnée, nappe de traque, remise sous tension,
stings et les trois nappes de dread) est synthétisé par
`tools/audio/build_audio.py` — voir `tools/audio/synth.py`.

Les bruits d'ambiance (`peur_*`) et les nappes de fond (`amb_*`) ne sont
pas des extraits bruts : ils sont **recomposés** à partir des
enregistrements ci-dessus — ralentis, transposés, filtrés et éloignés
dans une réverbération, pour qu'un même claquement de porte devienne
« une porte, ailleurs, que vous n'avez pas ouverte ».

| Banque | Auteur / page | Licence | Ce qui en est tiré |
|---|---|---|---|
| Sound Effects Pack | [Owlish Media (owlstorm)](https://opengameart.org/content/sound-effects-pack) | CC0 1.0 | respiration humaine, halètement, cri, pas sur sol dur, impacts, papier, tissu, grondement du bâtiment, horloge, toux dans le noir |
| 100 CC0 metal and wood SFX | [rubberduck](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | CC0 1.0 | portes, serrures, tôle, grincements, claquements, chutes métalliques, sommiers |
| Fantozzi's Footsteps (Grass/Sand & Stone) | [Fantozzi](https://opengameart.org/content/fantozzis-footsteps-grasssand-stone) | CC0 1.0 | pas sur pierre |
| Ghost Monster Voice Moaning & Growling | [qubodup](https://opengameart.org/content/ghost-monster-voice-moaning-growling) | CC0 1.0 | râles et grognements de la Veilleuse, plaintes lointaines |
| Dark Cavern Ambient | [Spring Spring](https://opengameart.org/content/dark-cavern-ambient) | CC0 1.0 | nappe d'ambiance souterraine (2 min, bouclable) |
| Heartbeat sounds | [Ogrebane](https://opengameart.org/content/heartbeat-sounds) | CC0 1.0 | battement de coeur lent |

Récupération reproductible :

```bash
python3 tools/audio/sources.py
```
