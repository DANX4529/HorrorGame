#!/usr/bin/env python3
"""Génère toutes les textures PBR du jeu.  usage: build_textures.py [--res 1024] [--only nom]"""
import argparse, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw
import materials as M

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "textures")


def contact_sheet(results, path, cell=190):
    """Planche contact : albédo / normale / ORM pour contrôle visuel."""
    names = list(results.keys())
    cols = 3
    rows = len(names)
    pad, label = 6, 20
    W = cols * (cell + pad) + pad
    H = rows * (cell + pad + label) + pad
    sheet = Image.new("RGB", (W, H), (18, 18, 20))
    d = ImageDraw.Draw(sheet)
    for r, n in enumerate(names):
        y = pad + r * (cell + pad + label)
        d.text((pad, y), f"{n}   [albedo | normal | ORM]", fill=(190, 195, 185))
        for c, img in enumerate(results[n]):
            im = Image.fromarray(img).resize((cell, cell), Image.LANCZOS)
            sheet.paste(im, (pad + c * (cell + pad), y + label))
    sheet.save(path)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--res", type=int, default=1024)
    ap.add_argument("--only", type=str, default=None)
    ap.add_argument("--sheet", type=str, default=None)
    a = ap.parse_args()

    os.makedirs(OUT, exist_ok=True)
    todo = [a.only] if a.only else list(M.RECIPES.keys())
    preview = {}
    t0 = time.time()
    for name in todo:
        t = time.time()
        res = a.res if name not in ("glass_dirty",) else max(256, a.res // 2)
        data = M.RECIPES[name](res=res)
        normal, orm = M.write_material(name, data, OUT)
        preview[name] = (M._u8(data["albedo"]), M._u8(normal), M._u8(orm))
        print(f"  {name:<18} {res}x{res}  {time.time()-t:5.1f}s")
    print(f"total {time.time()-t0:.1f}s -> {OUT}")
    if a.sheet:
        print("sheet:", contact_sheet(preview, a.sheet))


if __name__ == "__main__":
    main()
