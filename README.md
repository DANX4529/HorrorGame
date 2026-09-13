# RESPIRE

> *Sanatorium du Mont-Cendre, 1961. Ici, tout le monde retient son souffle.*

Jeu d'horreur psychologique à la première personne. Une créature aveugle
chasse au son — et le bruit le plus fort dans un bâtiment vide, c'est votre
propre respiration.

- **Moteur** : Godot 4.3
- **Document de conception** : [`docs/DESIGN.md`](docs/DESIGN.md)
- **Assets** : intégralement générés par les scripts de `tools/`
  (modèles Blender, textures PBR procédurales, audio synthétisé)

## Démarrage rapide

```bash
# Ouvrir le projet
godot --path game

# Ou lancer directement
godot --path game --rendering-driver opengl3
```

## Régénérer les assets

```bash
pip install bpy pillow numpy      # Blender 5.0 en module Python

python3 tools/texgen/build_textures.py --res 1024   # textures PBR
python3 tools/blender/build_env.py                  # kit architectural
python3 tools/blender/build_props.py                # mobilier
python3 tools/blender/build_entity.py               # la Veilleuse (riggée)
python3 tools/audio/build_audio.py                  # sons et ambiances
```
