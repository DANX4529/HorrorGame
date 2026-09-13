#!/usr/bin/env python3
"""
Force des réglages d'import 3D corrects sur les textures.

Godot classe par défaut un PNG comme texture 2D : mipmaps désactivés. Utilisée
sur une surface 3D, elle scintille violemment en mouvement — un damier de sol
ou des joints de carrelage vus en fuyante deviennent une bouillie mouvante.
Ce script écrit explicitement mipmaps + compression VRAM sur chaque texture.
"""
import glob, os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TEX = os.path.join(ROOT, "game", "assets", "textures")


def patch(path):
    with open(path) as f:
        src = f.read()
    is_normal = "_normal.png" in path
    wanted = {
        "mipmaps/generate": "true",
        "compress/mode": "2",                       # compression VRAM
        "compress/normal_map": "1" if is_normal else "0",
        "detect_3d/compress_to": "0",               # déjà compressé : pas de réimport
    }
    out = src
    for key, val in wanted.items():
        pat = re.compile(rf"^{re.escape(key)}=.*$", re.M)
        if pat.search(out):
            out = pat.sub(f"{key}={val}", out)
        else:
            out = out.replace("[params]\n", f"[params]\n\n{key}={val}", 1)
    if out != src:
        with open(path, "w") as f:
            f.write(out)
        return True
    return False


if __name__ == "__main__":
    files = sorted(glob.glob(os.path.join(TEX, "*.png.import")))
    n = sum(1 for f in files if patch(f))
    print(f"  {n}/{len(files)} fichiers .import corrigés (mipmaps + compression VRAM)")
