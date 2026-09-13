"""
build_env — kit architectural modulaire du Sanatorium du Mont-Cendre.

Grille de construction : module de 4 m, hauteur sous plafond 3 m, murs de 0,20 m.
Origine de chaque pièce : centre de l'empreinte au sol, Z=0 au niveau du sol.
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import blib as B
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models", "env")

# --- constantes d'architecture -------------------------------------------
MOD = 4.0          # largeur d'un module
H = 3.0            # hauteur sous plafond
T = 0.20           # épaisseur de mur
SKIRT_H, SKIRT_P = 0.14, 0.022      # plinthe : hauteur, débord
WAINS_H, WAINS_P = 1.48, 0.014      # lambris carrelé : hauteur, débord
CAP_H, CAP_P = 0.045, 0.030         # bandeau de couronnement
RAIL_Z, RAIL_H, RAIL_P = 2.52, 0.035, 0.022   # cimaise
DOOR_W, DOOR_H = 1.10, 2.15         # baie de porte
WIN_W, WIN_H, WIN_Z = 1.60, 1.30, 1.05        # baie de fenêtre

# Deux surfaces opaques exactement coplanaires font vaciller le tampon de
# profondeur (« z-fighting ») : en mouvement, les murs semblent se superposer.
# On enfonce donc chaque élément de quelques millimètres dans son voisin pour
# qu'aucune face ne partage un plan avec une autre.
OV = 0.004          # recouvrement entre moulures
Z0 = -0.015         # les murs descendent sous le niveau du sol
Z1 = H + 0.015      # ... et remontent dans la dalle de plafond

# slots de matériaux communs aux modules de mur
WALL_MATS = ["wall_tile", "wall_plaster", "wood_old", "metal_painted", "glass_dirty"]
M_TILE, M_PLAS, M_WOOD, M_MET, M_GLASS = 0, 1, 2, 3, 4


# ==========================================================================
#  Détails partagés
# ==========================================================================
def _wall_face_detail(bm, width, side, x0=0.0, skip_x=None):
    """
    Ajoute plinthe / lambris / bandeau / cimaise sur une face de mur.
    `side` = +1 (face +Y) ou -1 (face -Y). `skip_x` = (min,max) zone à ne pas couvrir.
    """
    y = side * (T * 0.5)

    def seg(xa, xb, z0, z1, proud, mat):
        if xb - xa < 1e-4:
            return
        d = proud
        B.box(bm, size=(xb - xa, d, z1 - z0),
              center=((xa + xb) * 0.5, y + side * d * 0.5, (z0 + z1) * 0.5), mat=mat)

    spans = [(x0 - width * 0.5, x0 + width * 0.5)]
    if skip_x:
        a, b = skip_x
        spans = []
        if a > x0 - width * 0.5:
            spans.append((x0 - width * 0.5, a))
        if b < x0 + width * 0.5:
            spans.append((b, x0 + width * 0.5))

    for xa, xb in spans:
        # la plinthe descend dans le sol, le lambris (moins épais) est mordu
        # en haut et en bas par ses voisins plus saillants : plus aucune face
        # horizontale ne reste coplanaire.
        seg(xa, xb, -0.018, SKIRT_H, SKIRT_P, M_WOOD)                    # plinthe
        seg(xa, xb, SKIRT_H - OV, WAINS_H + OV, WAINS_P, M_TILE)         # lambris carrelé
        seg(xa, xb, WAINS_H, WAINS_H + CAP_H, CAP_P, M_WOOD)             # bandeau
        seg(xa, xb, RAIL_Z, RAIL_Z + RAIL_H, RAIL_P, M_WOOD)             # cimaise


def _frame(bm, cx, cz, w, h, depth=T + 0.05, jamb=0.07, mat=M_WOOD):
    """Encadrement (chambranle) autour d'une baie."""
    B.box(bm, size=(jamb, depth, h + jamb), center=(cx - w * 0.5 - jamb * 0.5, 0, cz), mat=mat)
    B.box(bm, size=(jamb, depth, h + jamb), center=(cx + w * 0.5 + jamb * 0.5, 0, cz), mat=mat)
    B.box(bm, size=(w + jamb * 2, depth, jamb),
          center=(cx, 0, cz + h * 0.5 + jamb * 0.5), mat=mat)


# ==========================================================================
#  Modules de mur
# ==========================================================================
def wall_plain(width=MOD, name="wall_plain"):
    bm = B.bm_new()
    B.box(bm, size=(width, T, Z1 - Z0), center=(0, 0, (Z0 + Z1) * 0.5), mat=M_PLAS)
    _wall_face_detail(bm, width, +1)
    _wall_face_detail(bm, width, -1)
    B.bevel_sharp(bm, 0.006, 1)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, WALL_MATS)


def wall_door(width=MOD, name="wall_door"):
    """Mur percé d'une baie de porte centrée (pas de vantail : voir prop_door)."""
    bm = B.bm_new()
    hw, hd = width * 0.5, DOOR_W * 0.5
    # jambages + linteau
    B.box(bm, size=(hw - hd, T, Z1 - Z0), center=(-(hd + (hw - hd) * 0.5), 0, (Z0 + Z1) * 0.5), mat=M_PLAS)
    B.box(bm, size=(hw - hd, T, Z1 - Z0), center=(+(hd + (hw - hd) * 0.5), 0, (Z0 + Z1) * 0.5), mat=M_PLAS)
    B.box(bm, size=(DOOR_W, T, Z1 - DOOR_H), center=(0, 0, (DOOR_H + Z1) * 0.5), mat=M_PLAS)
    _wall_face_detail(bm, width, +1, skip_x=(-hd - 0.09, hd + 0.09))
    _wall_face_detail(bm, width, -1, skip_x=(-hd - 0.09, hd + 0.09))
    _frame(bm, 0.0, DOOR_H * 0.5, DOOR_W, DOOR_H)
    B.bevel_sharp(bm, 0.006, 1)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, WALL_MATS)


def wall_window(width=MOD, name="wall_window"):
    bm = B.bm_new()
    hw, hw2 = width * 0.5, WIN_W * 0.5
    z0, z1 = WIN_Z, WIN_Z + WIN_H
    B.box(bm, size=(hw - hw2, T, Z1 - Z0), center=(-(hw2 + (hw - hw2) * 0.5), 0, (Z0 + Z1) * 0.5), mat=M_PLAS)
    B.box(bm, size=(hw - hw2, T, Z1 - Z0), center=(+(hw2 + (hw - hw2) * 0.5), 0, (Z0 + Z1) * 0.5), mat=M_PLAS)
    B.box(bm, size=(WIN_W, T, z0 - Z0), center=(0, 0, (Z0 + z0) * 0.5), mat=M_PLAS)
    B.box(bm, size=(WIN_W, T, Z1 - z1), center=(0, 0, (z1 + Z1) * 0.5), mat=M_PLAS)
    _wall_face_detail(bm, width, +1, skip_x=(-hw2 - 0.09, hw2 + 0.09))
    _wall_face_detail(bm, width, -1, skip_x=(-hw2 - 0.09, hw2 + 0.09))
    # appui de fenêtre
    B.box(bm, size=(WIN_W + 0.24, T + 0.10, 0.05), center=(0, 0, z0 - 0.02), mat=M_WOOD)
    _frame(bm, 0.0, (z0 + z1) * 0.5, WIN_W, WIN_H, jamb=0.06)
    # meneaux + vitrage
    B.box(bm, size=(0.045, 0.05, WIN_H), center=(0, 0, (z0 + z1) * 0.5), mat=M_WOOD)
    B.box(bm, size=(WIN_W, 0.05, 0.045), center=(0, 0, (z0 + z1) * 0.5), mat=M_WOOD)
    B.box(bm, size=(WIN_W - 0.02, 0.012, WIN_H - 0.02), center=(0, 0, (z0 + z1) * 0.5), mat=M_GLASS)
    B.bevel_sharp(bm, 0.005, 1)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, WALL_MATS)


def wall_concrete(width=MOD, name="wall_concrete"):
    """Mur du sous-sol technique : béton nu, sans lambris, avec tuyauterie."""
    bm = B.bm_new()
    B.box(bm, size=(width, T, Z1 - Z0), center=(0, 0, (Z0 + Z1) * 0.5), mat=0)
    # coffrage : lignes de banches
    for i in range(3):
        z = 0.9 + i * 0.7
        B.box(bm, size=(width, T + 0.012, 0.018), center=(0, 0, z), mat=0)
    # faisceau de tuyaux courant le long du mur
    for i, (dz, r) in enumerate(((2.35, 0.055), (2.20, 0.038), (2.05, 0.072))):
        B.tube(bm, r, width, 10, (-width * 0.5, T * 0.5 + r + 0.02, dz),
               (width * 0.5, T * 0.5 + r + 0.02, dz), mat=1)
        for s in (-1, 1):       # colliers de fixation
            B.box(bm, size=(0.05, 0.10, r * 2 + 0.06),
                  center=(s * width * 0.28, T * 0.5 + r * 0.5, dz), mat=1)
    B.bevel_sharp(bm, 0.005, 1)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, ["floor_concrete", "metal_rust"])


def wall_concrete_door(width=MOD, name="wall_concrete_door"):
    bm = B.bm_new()
    hw, hd = width * 0.5, DOOR_W * 0.5
    B.box(bm, size=(hw - hd, T, Z1 - Z0), center=(-(hd + (hw - hd) * 0.5), 0, (Z0 + Z1) * 0.5), mat=0)
    B.box(bm, size=(hw - hd, T, Z1 - Z0), center=(+(hd + (hw - hd) * 0.5), 0, (Z0 + Z1) * 0.5), mat=0)
    B.box(bm, size=(DOOR_W, T, Z1 - DOOR_H), center=(0, 0, (DOOR_H + Z1) * 0.5), mat=0)
    # huisserie métallique
    for s in (-1, 1):
        B.box(bm, size=(0.08, T + 0.06, DOOR_H), center=(s * (hd + 0.04), 0, DOOR_H * 0.5), mat=1)
    B.box(bm, size=(DOOR_W + 0.16, T + 0.06, 0.08), center=(0, 0, DOOR_H + 0.04), mat=1)
    B.bevel_sharp(bm, 0.005, 1)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, ["floor_concrete", "metal_rust"])


# ==========================================================================
#  Sols et plafonds
# ==========================================================================
def floor_slab(size=MOD, mat="floor_lino", name="floor_lino"):
    bm = B.bm_new()
    B.box(bm, size=(size, size, 0.10), center=(0, 0, -0.05), mat=0)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, [mat])


def ceiling_slab(size=MOD, name="ceiling"):
    bm = B.bm_new()
    B.box(bm, size=(size, size, 0.12), center=(0, 0, H + 0.06), mat=0)
    # corniche périphérique
    for (sx, sy, cx, cy) in ((size, 0.09, 0, size * 0.5 - 0.045),
                             (size, 0.09, 0, -size * 0.5 + 0.045),
                             (0.09, size, size * 0.5 - 0.045, 0),
                             (0.09, size, -size * 0.5 + 0.045, 0)):
        B.box(bm, size=(sx, sy, 0.07), center=(cx, cy, H - 0.028), mat=1)
    B.bevel_sharp(bm, 0.005, 1)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, ["ceiling_plaster", "wood_old"])


def ceiling_concrete(size=MOD, name="ceiling_concrete"):
    bm = B.bm_new()
    B.box(bm, size=(size, size, 0.12), center=(0, 0, H + 0.06), mat=0)
    # solives apparentes
    for i in (-1, 0, 1):
        B.box(bm, size=(size, 0.16, 0.19), center=(0, i * size * 0.3, H - 0.085), mat=0)
    B.uv_world_box(bm, scale=2.0)
    return B.finish(bm, name, ["floor_concrete"])


# ==========================================================================
def build_all():
    os.makedirs(OUT, exist_ok=True)
    specs = [
        ("wall_plain",         lambda: wall_plain()),
        ("wall_plain_2m",      lambda: wall_plain(2.0, "wall_plain_2m")),
        ("wall_door",          lambda: wall_door()),
        ("wall_window",        lambda: wall_window()),
        ("wall_concrete",      lambda: wall_concrete()),
        ("wall_concrete_door", lambda: wall_concrete_door()),
        ("floor_lino",         lambda: floor_slab(MOD, "floor_lino", "floor_lino")),
        ("floor_concrete",     lambda: floor_slab(MOD, "floor_concrete", "floor_concrete")),
        ("ceiling",            lambda: ceiling_slab()),
        ("ceiling_concrete",   lambda: ceiling_concrete()),
    ]
    report = []
    for name, fn in specs:
        B.scene_reset()
        obj = fn()
        path = os.path.join(OUT, f"{name}.glb")
        B.export_glb([obj], path)
        report.append((name, B.tri_count([obj]), os.path.getsize(path)))
    return report


if __name__ == "__main__":
    for n, t, s in build_all():
        print(f"  {n:<22} {t:>6} tris  {s/1024:>7.1f} KB")
