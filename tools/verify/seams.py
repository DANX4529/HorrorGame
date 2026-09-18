#!/usr/bin/env python3
"""
seams — planche de contrôle des raccords de textures.

    python3 tools/verify/seams.py [sortie.png]

Produit une planche où chaque texture est tuilée 2x2. Une couture s'y voit
immédiatement : une barre en travers, ou un motif qui se casse au milieu.

POURQUOI PAS DE VERDICT AUTOMATIQUE. Trois mesures ont été écrites et jetées :

  1. « écart au raccord / écart moyen de l'image » — condamne tout carrelage
     dont un joint tombe sur le bord, alors qu'il tuile parfaitement.
  2. « rang de l'écart au raccord parmi toutes les colonnes » — même défaut :
     un joint bat mécaniquement 97 % des colonnes de faïence lisse.
  3. « écart au raccord comparé aux colonnes de même phase, période trouvée par
     autocorrélation » — se trompe de période dès qu'il y en a deux
     superposées : sur le bois, elle attrape le veinage et non les planches,
     et note 6 sur 10 une texture dont on a vérifié à l'œil qu'elle est saine.

Un contrôle dont on a constaté trois fois qu'il juge mal ne doit pas barrer la
route à une livraison : on apprendrait à passer outre, et le jour où il aurait
raison on ne l'écouterait pas. La planche, elle, tranche en une seconde.

Les nombres restent imprimés à titre INDICATIF, pour repérer où regarder.
"""
import numpy as np, os, sys
from PIL import Image, ImageDraw


def indice(a, axe):
    """Écart au raccord rapporté à l'écart interne médian. Indicatif."""
    d = np.abs(a - np.roll(a, 1, axis=axe)).mean(axis=1 - axe)
    return float(d[0] / max(np.median(d), 1e-6))


def planche(tex_dir, sortie, cell=300, cols=5):
    noms = sorted(f[:-11] for f in os.listdir(tex_dir) if f.endswith("_albedo.png"))
    lignes = (len(noms) + cols - 1) // cols
    sheet = Image.new("RGB", (cell * cols, (cell + 20) * lignes), (16, 16, 18))
    d = ImageDraw.Draw(sheet)
    for i, n in enumerate(noms):
        im = Image.open(os.path.join(tex_dir, n + "_albedo.png")).convert("RGB")
        t = Image.new("RGB", (im.width * 2, im.height * 2))
        for a in range(2):
            for b in range(2):
                t.paste(im, (a * im.width, b * im.height))
        x, y = (i % cols) * cell, (i // cols) * (cell + 20)
        sheet.paste(t.resize((cell, cell)), (x, y + 20))
        g = np.asarray(im.convert("L")).astype(np.float32)
        d.text((x + 5, y + 4), "%s   h%.1f v%.1f" % (n, indice(g, 1), indice(g, 0)),
               fill=(205, 205, 195))
    sheet.save(sortie)
    return sortie, len(noms)


if __name__ == "__main__":
    tex = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                       "..", "..", "game", "assets", "textures"))
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/raccords.png"
    p, n = planche(tex, out)
    print("%d textures tuilees 2x2 -> %s" % (n, p))
    print("Les nombres sont indicatifs : c'est la planche qui tranche.")
