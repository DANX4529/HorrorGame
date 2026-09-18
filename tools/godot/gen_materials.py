#!/usr/bin/env python3
"""Génère les ressources ORMMaterial3D (.tres) à partir des textures produites."""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = "res://assets/textures"
OUT = os.path.join(ROOT, "game", "assets", "materials")

# ds = rendu double face ; alpha = transparence ; spec = lignes brutes en plus
MATS = {
    "wall_tile":       dict(),
    "wall_plaster":    dict(),
    "floor_concrete":  dict(),
    "floor_lino":      dict(),
    "ceiling_plaster": dict(),
    "wood_old":        dict(),
    "metal_painted":   dict(spec="metallic = 0.65\nroughness = 1.0"),
    "metal_rust":      dict(spec="metallic = 0.70\nroughness = 1.0"),
    "fabric_mattress": dict(ds=True),
    "cloth_gown":      dict(ds=True),
    "paper_aged":      dict(ds=True),
    "skin_pale":       dict(),
    "grime_dark":      dict(),
    "hair_dark":       dict(ds=True),
    # Les bains (niveau -3)
    "bath_tile":       dict(),
    "bath_floor":      dict(),
    "glass_shards":    dict(),
    "metal_verdigris": dict(spec="metallic = 0.70\nroughness = 1.0"),
    # L'eau : sombre et lisse. Pas de transparence — on ne voit pas le fond
    # d'un bassin d'hydrothérapie qui n'a pas été vidé depuis 1961, et une
    # surface opaque et miroitante se lit mieux qu'un verre teinté.
    "water_dark":      dict(spec="metallic = 0.25\nroughness = 1.0"),
    "email":           dict(),
    "glass_dirty":     dict(ds=True, alpha=True,
                            spec="albedo_color = Color(0.75, 0.78, 0.75, 0.34)"),
}


def write(name, o, variante=0):
    """Écrit un .tres. variante>0 pointe sur l'albédo de la variante et
    RÉUTILISE la normale et l'ORM de la texture de base : la structure est la
    même, seules les taches changent."""
    base = name
    alb = name if variante == 0 else f"{name}_v{variante}"
    lines = ['[gd_resource type="ORMMaterial3D" format=3]', ""]
    for i, suffix in enumerate(("albedo", "normal", "orm")):
        src = alb if suffix == "albedo" else base
        lines.append(f'[ext_resource type="Texture2D" path="{TEX}/{src}_{suffix}.png" id="t{i}"]')
    lines += ["", "[resource]", f'resource_name = "{alb}"',
              'albedo_texture = ExtResource("t0")',
              "normal_enabled = true",
              'normal_texture = ExtResource("t1")',
              "normal_scale = 1.0",
              'orm_texture = ExtResource("t2")',
              "texture_filter = 5",   # LINEAR_WITH_MIPMAPS_ANISOTROPIC
              "texture_repeat = true"]
    if o.get("ds"):
        lines.append("cull_mode = 2")
    if o.get("alpha"):
        lines.append("transparency = 1")
    if o.get("spec"):
        lines.append(o["spec"])
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, (name if variante == 0 else f"{name}_v{variante}") + ".tres")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    return path


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.join(ROOT, "tools", "texgen"))
    try:
        import materials as MX
        VAR = MX.VARIANTES
    except Exception:
        VAR = {}

    TEXDIR = os.path.join(ROOT, "game", "assets", "textures")
    missing, ecrits = [], 0
    for n, o in MATS.items():
        for s in ("albedo", "normal", "orm"):
            fp = os.path.join(TEXDIR, f"{n}_{s}.png")
            if not os.path.exists(fp):
                missing.append(os.path.basename(fp))
        write(n, o)
        ecrits += 1
        # Une variante n'est écrite que si son albédo existe vraiment : sinon
        # Godot chargerait une ressource pointant sur un fichier absent, et le
        # niveau se bâtirait avec un matériau vide sans rien signaler.
        for k in range(1, VAR.get(n, 1)):
            if os.path.exists(os.path.join(TEXDIR, f"{n}_v{k}_albedo.png")):
                write(n, o, k)
                ecrits += 1
            else:
                missing.append(f"{n}_v{k}_albedo.png")
    print(f"  {ecrits} materiaux ecrits ({len(MATS)} de base)")
    print("  TEXTURES MANQUANTES:", missing if missing else "aucune")
