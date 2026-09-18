"""
build_props — mobilier et accessoires du Sanatorium du Mont-Cendre.

Chaque prop est exporté en .glb avec des slots de matériaux nommés
(remplacés à l'import par les .tres côté Godot).
Origine : centre de l'empreinte au sol, Z=0 au sol — sauf mention contraire.
"""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import blib as B
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "models", "props")
PI = math.pi


# ==========================================================================
#  Ouvrants
# ==========================================================================
def door(name="door"):
    """Vantail de porte. Origine sur l'axe des paumelles (x=0) -> rotation Z directe."""
    W, Hh, D = 1.04, 2.10, 0.045
    bm = B.bm_new()
    B.box(bm, size=(W, D, Hh), center=(W * 0.5, 0, Hh * 0.5), mat=0)
    # panneaux moulurés en creux
    for (cz, ph) in ((0.55, 0.78), (1.52, 0.85)):
        for s in (-1, 1):
            B.box(bm, size=(W - 0.24, 0.012, ph),
                  center=(W * 0.5, s * (D * 0.5 - 0.004), cz), mat=0)
    # traverses
    for cz in (0.12, 1.02, 2.02):
        B.box(bm, size=(W, D + 0.008, 0.10), center=(W * 0.5, 0, cz), mat=0)
    # paumelles
    for cz in (0.28, 1.05, 1.86):
        B.cylinder(bm, 0.016, 0.10, 8, center=(0.01, 0, cz), rot=(0, 0, 0), mat=1)
        B.box(bm, size=(0.07, D + 0.01, 0.085), center=(0.04, 0, cz), mat=1)
    # bec-de-cane + rosace, des deux côtés
    for s in (-1, 1):
        y = s * (D * 0.5)
        B.cylinder(bm, 0.042, 0.012, 12, center=(W - 0.09, y + s * 0.006, 1.04),
                   rot=(PI / 2, 0, 0), mat=1)
        B.cylinder(bm, 0.014, 0.055, 8, center=(W - 0.09, y + s * 0.03, 1.04),
                   rot=(PI / 2, 0, 0), mat=1)
        B.box(bm, size=(0.11, 0.022, 0.022), center=(W - 0.135, y + s * 0.055, 1.04), mat=1)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=1.0)
    return [B.finish(bm, name, ["wood_old", "metal_painted"])]


def door_metal(name="door_metal"):
    """Porte technique métallique du sous-sol, avec hublot grillagé."""
    W, Hh, D = 1.04, 2.10, 0.055
    bm = B.bm_new()
    B.box(bm, size=(W, D, Hh), center=(W * 0.5, 0, Hh * 0.5), mat=0)
    for s in (-1, 1):   # raidisseurs emboutis
        for cz in (0.45, 1.55):
            B.box(bm, size=(W - 0.16, 0.010, 0.55),
                  center=(W * 0.5, s * (D * 0.5 - 0.003), cz), mat=0)
    # hublot
    B.box(bm, size=(0.34, D + 0.012, 0.30), center=(W * 0.5, 0, 1.58), mat=1)
    B.box(bm, size=(0.28, 0.010, 0.24), center=(W * 0.5, 0, 1.58), mat=2)
    for i in range(4):  # grille
        B.box(bm, size=(0.28, 0.014, 0.010), center=(W * 0.5, 0, 1.47 + i * 0.073), mat=1)
    for cz in (0.30, 1.05, 1.80):
        B.box(bm, size=(0.05, D + 0.02, 0.12), center=(0.02, 0, cz), mat=1)
    for s in (-1, 1):   # barre de poussée
        B.box(bm, size=(0.06, 0.05, 0.32), center=(W - 0.10, s * (D * 0.5 + 0.03), 1.02), mat=1)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=1.0)
    return [B.finish(bm, name, ["metal_painted", "metal_rust", "glass_dirty"])]


# ==========================================================================
#  Cachettes
# ==========================================================================
def locker(name="locker"):
    """Vestiaire métallique. Deux objets : corps + porte (pivot à gauche)."""
    W, D, Hh = 0.40, 0.48, 1.86
    bm = B.bm_new()
    # caisson : 5 faces, l'avant reste ouvert
    B.box(bm, size=(W, 0.02, Hh), center=(0, D * 0.5 - 0.01, Hh * 0.5), mat=0)     # dos
    for s in (-1, 1):
        B.box(bm, size=(0.02, D, Hh), center=(s * (W * 0.5 - 0.01), 0, Hh * 0.5), mat=0)
    B.box(bm, size=(W, D, 0.02), center=(0, 0, Hh - 0.01), mat=0)                  # dessus
    B.box(bm, size=(W, D, 0.02), center=(0, 0, 0.12), mat=0)                       # plancher
    # étagère haute + tringle
    B.box(bm, size=(W - 0.04, D - 0.04, 0.015), center=(0, 0, 1.42), mat=0)
    B.tube(bm, 0.008, W, 8, (-W * 0.5 + 0.03, 0, 1.36), (W * 0.5 - 0.03, 0, 1.36), mat=1)
    # piètement
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box(bm, size=(0.035, 0.035, 0.12),
                  center=(sx * (W * 0.5 - 0.03), sy * (D * 0.5 - 0.03), 0.06), mat=1)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=1.0)
    body = B.finish(bm, name + "_body", ["metal_painted", "metal_rust"])

    # --- porte : pivot sur l'arête gauche, x=0 ---
    bd = B.bm_new()
    B.box(bd, size=(W - 0.02, 0.018, Hh - 0.15), center=((W - 0.02) * 0.5, 0, 0), mat=0)
    # ouïes d'aération embouties
    for i in range(5):
        z = (Hh - 0.15) * 0.5 - 0.10 - i * 0.055
        B.box(bd, size=(W - 0.14, 0.026, 0.016), center=((W - 0.02) * 0.5, -0.004, z), mat=0)
    # poignée à came + fente d'étiquette
    B.box(bd, size=(0.035, 0.055, 0.16), center=(W - 0.10, -0.030, -0.05), mat=1)
    B.cylinder(bd, 0.016, 0.03, 10, center=(W - 0.10, -0.055, -0.05), rot=(PI / 2, 0, 0), mat=1)
    B.box(bd, size=(0.10, 0.020, 0.045), center=((W - 0.02) * 0.5, -0.006, 0.52), mat=1)
    B.bevel_sharp(bd, 0.003, 1)
    B.uv_world_box(bd, scale=1.0)
    dobj = B.finish(bd, name + "_door", ["metal_painted", "metal_rust"])
    # position du pivot : bord gauche du caisson, à mi-hauteur de la porte
    dobj.location = (-W * 0.5 + 0.01, -D * 0.5 + 0.01, 0.13 + (Hh - 0.15) * 0.5)
    return [body, dobj]


# ==========================================================================
#  Mobilier médical
# ==========================================================================
def hospital_bed(name="hospital_bed"):
    W, L, FH = 0.94, 2.02, 0.56
    bm = B.bm_new()
    r = 0.019
    # longerons + traverses du sommier
    for s in (-1, 1):
        B.tube(bm, r, L, 8, (s * (W * 0.5 - r), -L * 0.5, FH), (s * (W * 0.5 - r), L * 0.5, FH), mat=0)
    for i in range(7):
        y = -L * 0.5 + 0.14 + i * (L - 0.28) / 6.0
        B.tube(bm, 0.010, W, 6, (-W * 0.5 + r, y, FH - 0.012), (W * 0.5 - r, y, FH - 0.012), mat=0)
    # montants + têtes de lit
    for sy, hh in ((-1, 0.92), (1, 0.62)):
        y = sy * (L * 0.5 - 0.02)
        for sx in (-1, 1):
            x = sx * (W * 0.5 - r)
            B.tube(bm, 0.022, hh, 8, (x, y, 0.10), (x, y, hh), mat=0)
        B.tube(bm, 0.020, W, 8, (-W * 0.5 + r, y, hh), (W * 0.5 - r, y, hh), mat=0)   # lisse haute
        B.tube(bm, 0.014, W, 8, (-W * 0.5 + r, y, hh - 0.22), (W * 0.5 - r, y, hh - 0.22), mat=0)
        for i in range(5):   # barreaux
            x = -W * 0.5 + 0.14 + i * (W - 0.28) / 4.0
            B.tube(bm, 0.009, hh, 6, (x, y, FH), (x, y, hh - 0.01), mat=0)
    # roulettes
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W * 0.5 - r), sy * (L * 0.5 - 0.02)
            B.cylinder(bm, 0.018, 0.08, 8, center=(x, y, 0.06), mat=1)
            B.cylinder(bm, 0.038, 0.022, 12, center=(x, y, 0.038), rot=(0, PI / 2, 0), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=1.0)
    frame = B.finish(bm, name + "_frame", ["metal_painted", "metal_rust"], smooth_angle=True)

    # matelas affaissé
    bmm = B.bm_new()
    fs = B.grid_plane(bmm, size=(W - 0.08, L - 0.10), center=(0, 0, FH + 0.09), subdiv=10, mat=0)
    verts = list({v for f in fs for v in f.verts})
    for v in verts:      # creux d'usure au centre
        u = v.co.x / (W * 0.5); w = v.co.y / (L * 0.5)
        v.co.z -= (1.0 - u * u) * (1.0 - w * w) * 0.045
    B.extrude(bmm, fs, (0, 0, -0.115))
    B.bevel_sharp(bmm, 0.020, 2, angle=0.9)
    B.uv_world_box(bmm, scale=1.0)
    mat_obj = B.finish(bmm, name + "_mattress", ["fabric_mattress"], smooth_angle=True)
    return [frame, mat_obj]


def wheelchair(name="wheelchair"):
    """Fauteuil roulant d'hôpital : jantes à rayons, cerceaux, toile affaissée."""
    bm = B.bm_new()
    SW, SD, SH = 0.46, 0.44, 0.50
    RW = 0.295                      # rayon des grandes roues
    AX_Z = RW + 0.02                # hauteur de l'essieu

    # ---- châssis tubulaire (deux flancs identiques) ----
    for sx in (-1, 1):
        x = sx * SW * 0.5
        B.tube(bm, 0.016, 1, 8, (x, -SD * 0.52, SH), (x, SD * 0.52, SH), mat=0)     # rail d'assise
        B.tube(bm, 0.016, 1, 8, (x, SD * 0.52, SH), (x, SD * 0.50, SH + 0.50), mat=0)  # montant dossier
        B.tube(bm, 0.016, 1, 8, (x, SD * 0.50, SH + 0.50), (x, SD * 0.62, SH + 0.46), mat=0)
        B.tube(bm, 0.014, 1, 8, (x, -SD * 0.52, SH), (x, -SD * 0.46, 0.16), mat=0)  # jambe avant
        B.tube(bm, 0.014, 1, 8, (x, SD * 0.52, SH), (x, SD * 0.40, 0.20), mat=0)    # jambe arrière
        B.tube(bm, 0.014, 1, 8, (x, -SD * 0.46, 0.16), (x, SD * 0.40, 0.20), mat=0) # longeron bas
        B.tube(bm, 0.013, 1, 8, (x, SD * 0.40, 0.20), (x, 0.02, AX_Z), mat=0)       # support d'essieu
        B.tube(bm, 0.013, 1, 8, (x, -SD * 0.30, SH), (x, 0.02, AX_Z), mat=0)
        # repose-pieds
        B.tube(bm, 0.013, 1, 8, (x, -SD * 0.48, 0.34), (x, -SD * 0.92, 0.16), mat=0)
        B.box(bm, size=(0.11, 0.19, 0.016), center=(x * 0.86, -SD * 0.92, 0.145),
              rot=(0.12, 0, 0), mat=0)
        # accoudoir
        B.tube(bm, 0.013, 1, 8, (x, SD * 0.30, SH + 0.02), (x, SD * 0.30, SH + 0.22), mat=0)
        B.tube(bm, 0.013, 1, 8, (x, -SD * 0.30, SH + 0.02), (x, -SD * 0.30, SH + 0.22), mat=0)
        B.tube(bm, 0.013, 1, 8, (x, -SD * 0.30, SH + 0.22), (x, SD * 0.30, SH + 0.22), mat=0)
        B.box(bm, size=(0.055, 0.34, 0.022), center=(x, 0.0, SH + 0.235), mat=1)
    # entretoises transversales
    B.tube(bm, 0.013, 1, 8, (-SW * 0.5, SD * 0.40, 0.20), (SW * 0.5, SD * 0.40, 0.20), mat=0)
    B.tube(bm, 0.013, 1, 8, (-SW * 0.5, -SD * 0.46, 0.16), (SW * 0.5, -SD * 0.46, 0.16), mat=0)
    B.tube(bm, 0.014, 1, 8, (-SW * 0.5, SD * 0.62, SH + 0.46), (SW * 0.5, SD * 0.62, SH + 0.46), mat=0)

    # ---- toile d'assise (affaissée) et dossier ----
    fs = B.grid_plane(bm, size=(SW - 0.02, SD * 0.98), center=(0, 0, SH - 0.008),
                      subdiv=6, mat=1)
    for v in {v for f in fs for v in f.verts}:
        u = v.co.x / (SW * 0.5); w = v.co.y / (SD * 0.5)
        v.co.z -= (1.0 - u * u) * (1.0 - w * w) * 0.055
    B.extrude(bm, fs, (0, 0, -0.012))
    bs = B.grid_plane(bm, size=(SW - 0.02, 0.46), center=(0, SD * 0.50, SH + 0.26),
                      rot=(math.pi / 2, 0, 0), subdiv=6, mat=1)
    for v in {v for f in bs for v in f.verts}:
        u = v.co.x / (SW * 0.5); w = (v.co.z - (SH + 0.26)) / 0.23
        v.co.y += (1.0 - u * u) * (1.0 - w * w) * 0.05
    B.extrude(bm, bs, (0, 0.012, 0))

    # ---- grandes roues : jante + rayons + moyeu + cerceau ----
    for sx in (-1, 1):
        x = sx * (SW * 0.5 + 0.055)
        c = (x, 0.02, AX_Z)
        ry = (0, math.pi / 2, 0)
        B.torus(bm, RW, 0.022, 28, 8, center=c, rot=ry, mat=2)            # pneu
        B.torus(bm, RW - 0.028, 0.010, 26, 6, center=c, rot=ry, mat=0)    # jante
        B.torus(bm, RW + 0.028, 0.011, 26, 6,
                center=(x + sx * 0.042, 0.02, AX_Z), rot=ry, mat=0)       # main courante
        for k in range(3):                                                # entretoises du cerceau
            a = k * 2 * math.pi / 3
            B.tube(bm, 0.006, 1, 5,
                   (x, 0.02 + math.cos(a) * (RW - 0.01), AX_Z + math.sin(a) * (RW - 0.01)),
                   (x + sx * 0.042, 0.02 + math.cos(a) * (RW + 0.02),
                    AX_Z + math.sin(a) * (RW + 0.02)), mat=0)
        B.cylinder(bm, 0.030, 0.075, 12, center=c, rot=ry, mat=0)         # moyeu
        B.cylinder(bm, 0.012, 0.14, 8, center=(sx * SW * 0.5, 0.02, AX_Z), rot=ry, mat=0)
        for k in range(12):                                               # rayons croisés
            a = k * math.pi / 6
            off = 0.020 * (1 if k % 2 else -1)
            B.tube(bm, 0.0035, 1, 4, (x + off, 0.02, AX_Z),
                   (x, 0.02 + math.cos(a) * (RW - 0.030), AX_Z + math.sin(a) * (RW - 0.030)), mat=0)

    # ---- roulettes pivotantes avant ----
    for sx in (-1, 1):
        x = sx * SW * 0.5
        fy, fz = -SD * 0.46, 0.075
        B.tube(bm, 0.011, 1, 8, (x, fy, 0.16), (x, fy, fz + 0.02), mat=0)
        B.box(bm, size=(0.055, 0.030, 0.085), center=(x, fy, fz + 0.03), mat=0)
        B.torus(bm, 0.062, 0.017, 18, 7, center=(x, fy, fz), rot=(0, math.pi / 2, 0), mat=2)
        B.cylinder(bm, 0.050, 0.026, 14, center=(x, fy, fz), rot=(0, math.pi / 2, 0), mat=0)

    # ---- poignées de poussée ----
    for sx in (-1, 1):
        B.cylinder(bm, 0.017, 0.125, 12,
                   center=(sx * SW * 0.5, SD * 0.62 + 0.02, SH + 0.455),
                   rot=(math.pi / 2, 0, 0), mat=1)

    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.8)
    return [B.finish(bm, name, ["metal_painted", "cloth_gown", "metal_rust"], smooth_angle=True)]

def iv_stand(name="iv_stand"):
    bm = B.bm_new()
    B.tube(bm, 0.016, 1, 10, (0, 0, 0.07), (0, 0, 1.78), mat=0)
    for i in range(5):    # pied étoile
        a = i * 2 * PI / 5
        B.tube(bm, 0.010, 1, 6, (0, 0, 0.09),
               (math.cos(a) * 0.26, math.sin(a) * 0.26, 0.055), mat=0)
        B.cylinder(bm, 0.026, 0.020, 10,
                   center=(math.cos(a) * 0.26, math.sin(a) * 0.26, 0.026), rot=(0, PI / 2, 0), mat=0)
    for sx in (-1, 1):    # crochets
        B.tube(bm, 0.008, 1, 6, (0, 0, 1.76), (sx * 0.09, 0, 1.80), mat=0)
        B.tube(bm, 0.008, 1, 6, (sx * 0.09, 0, 1.80), (sx * 0.09, 0, 1.72), mat=0)
    # poche de perfusion vide et fripée
    B.box(bm, size=(0.13, 0.05, 0.26), center=(-0.09, 0, 1.55), mat=1)
    B.tube(bm, 0.005, 1, 6, (-0.09, 0, 1.42), (-0.02, 0.05, 1.05), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.6)
    return [B.finish(bm, name, ["metal_painted", "glass_dirty"], smooth_angle=True)]


def cabinet(name="cabinet"):
    """Vitrine à pharmacie."""
    W, D, Hh = 0.72, 0.34, 1.62
    bm = B.bm_new()
    B.box(bm, size=(W, 0.02, Hh), center=(0, D * 0.5, Hh * 0.5), mat=0)
    for s in (-1, 1):
        B.box(bm, size=(0.02, D, Hh), center=(s * W * 0.5, 0, Hh * 0.5), mat=0)
    B.box(bm, size=(W, D, 0.02), center=(0, 0, Hh), mat=0)
    B.box(bm, size=(W, D, 0.03), center=(0, 0, 0.14), mat=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box(bm, size=(0.04, 0.04, 0.14),
                  center=(sx * (W * 0.5 - 0.04), sy * (D * 0.5 - 0.04), 0.07), mat=0)
    for i in range(4):    # étagères
        B.box(bm, size=(W - 0.05, D - 0.04, 0.014), center=(0, 0, 0.42 + i * 0.30), mat=0)
    for sx in (-1, 1):    # portes vitrées
        B.box(bm, size=(W * 0.5 - 0.01, 0.018, Hh - 0.20),
              center=(sx * W * 0.25, -D * 0.5 + 0.01, 0.16 + (Hh - 0.20) * 0.5), mat=0)
        B.box(bm, size=(W * 0.5 - 0.10, 0.008, Hh - 0.30),
              center=(sx * W * 0.25, -D * 0.5 + 0.01, 0.16 + (Hh - 0.20) * 0.5), mat=1)
        B.cylinder(bm, 0.010, 0.05, 8, center=(sx * 0.04, -D * 0.5 - 0.01, 0.95),
                   rot=(PI / 2, 0, 0), mat=2)
    # flacons oubliés
    rnd = random.Random(7)
    for i in range(6):
        x = -0.26 + rnd.random() * 0.52
        z = 0.44 + [0, 1, 2][i % 3] * 0.30
        B.cylinder(bm, 0.022 + rnd.random() * 0.012, 0.09 + rnd.random() * 0.05, 10,
                   center=(x, rnd.random() * 0.08 - 0.04, z + 0.06), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.8)
    return [B.finish(bm, name, ["metal_painted", "glass_dirty", "metal_rust"])]


# ==========================================================================
#  Éclairage
# ==========================================================================
def ceiling_lamp(name="ceiling_lamp"):
    """Suspension émaillée. Origine au plafond (Z=0), la lampe pend vers -Z."""
    bm = B.bm_new()
    B.cylinder(bm, 0.055, 0.025, 12, center=(0, 0, -0.012), mat=0)          # rosace
    B.tube(bm, 0.008, 1, 8, (0, 0, -0.02), (0, 0, -0.34), mat=0)            # tige
    B.cylinder(bm, 0.20, 0.16, 24, center=(0, 0, -0.42), radius_top=0.055, mat=0)  # abat-jour
    B.cylinder(bm, 0.205, 0.012, 24, center=(0, 0, -0.50), mat=0)           # jonc de bord
    B.cylinder(bm, 0.026, 0.05, 10, center=(0, 0, -0.36), mat=1)            # douille
    B.sphere(bm, 0.035, 12, 8, center=(0, 0, -0.45), scale=(1, 1, 1.35), mat=2)    # ampoule
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.5)
    return [B.finish(bm, name, ["metal_painted", "metal_rust", "glass_dirty"], smooth_angle=True)]


def wall_lamp(name="wall_lamp"):
    """Applique de secours grillagée. Origine au mur (Y=0), dépasse vers -Y."""
    bm = B.bm_new()
    B.box(bm, size=(0.13, 0.03, 0.20), center=(0, 0.015, 0), mat=0)         # platine
    B.cylinder(bm, 0.055, 0.10, 14, center=(0, -0.07, 0), rot=(PI / 2, 0, 0), mat=0)
    B.sphere(bm, 0.048, 12, 8, center=(0, -0.13, 0), scale=(1, 1.2, 1), mat=2)
    for i in range(6):     # cage de protection
        a = i * PI / 3
        B.tube(bm, 0.004, 1, 4, (math.cos(a) * 0.055, -0.06, math.sin(a) * 0.055),
               (math.cos(a) * 0.035, -0.19, math.sin(a) * 0.035), mat=1)
    B.cylinder(bm, 0.038, 0.008, 14, center=(0, -0.185, 0), rot=(PI / 2, 0, 0), mat=1)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["metal_painted", "metal_rust", "glass_dirty"], smooth_angle=True)]


# ==========================================================================
#  Objectif : électricité
# ==========================================================================
def fuse_box(name="fuse_box"):
    """Tableau électrique mural. Origine au mur (Y=0). Corps + porte pivotante."""
    W, Hh, D = 0.62, 0.78, 0.17
    bm = B.bm_new()
    B.box(bm, size=(W, 0.02, Hh), center=(0, D - 0.01, 0), mat=0)
    for sx in (-1, 1):
        B.box(bm, size=(0.02, D, Hh), center=(sx * W * 0.5, D * 0.5, 0), mat=0)
    for sz in (-1, 1):
        B.box(bm, size=(W, D, 0.02), center=(0, D * 0.5, sz * Hh * 0.5), mat=0)
    # platine + 4 porte-fusibles
    B.box(bm, size=(W - 0.08, 0.015, Hh - 0.10), center=(0, D - 0.04, 0), mat=1)
    for i in range(4):
        x = -0.21 + i * 0.14
        B.cylinder(bm, 0.035, 0.045, 14, center=(x, D - 0.07, 0.10), rot=(PI / 2, 0, 0), mat=2)
        B.cylinder(bm, 0.024, 0.020, 12, center=(x, D - 0.10, 0.10), rot=(PI / 2, 0, 0), mat=1)
    # interrupteur général + bornier
    B.box(bm, size=(0.10, 0.06, 0.14), center=(-0.16, D - 0.08, -0.20), mat=1)
    B.box(bm, size=(0.035, 0.05, 0.08), center=(-0.16, D - 0.12, -0.16), mat=3)
    for i in range(6):
        B.box(bm, size=(0.018, 0.03, 0.05), center=(0.02 + i * 0.032, D - 0.07, -0.22), mat=1)
    # conduits sortants
    B.cylinder(bm, 0.022, 0.14, 10, center=(-W * 0.3, D * 0.5, Hh * 0.5 + 0.07), mat=1)
    B.cylinder(bm, 0.022, 0.14, 10, center=(W * 0.3, D * 0.5, -Hh * 0.5 - 0.07), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.5)
    body = B.finish(bm, name + "_body", ["metal_painted", "metal_rust", "wall_tile", "wood_old"])

    bd = B.bm_new()      # porte, pivot sur l'arête gauche
    B.box(bd, size=(W, 0.016, Hh), center=(W * 0.5, 0, 0), mat=0)
    B.box(bd, size=(W - 0.10, 0.020, Hh - 0.10), center=(W * 0.5, -0.004, 0), mat=0)
    B.box(bd, size=(0.10, 0.012, 0.07), center=(W * 0.5, -0.012, Hh * 0.5 - 0.11), mat=2)  # étiquette
    B.cylinder(bd, 0.012, 0.035, 8, center=(W - 0.06, -0.022, 0), rot=(PI / 2, 0, 0), mat=1)
    B.bevel_sharp(bd, 0.003, 1)
    B.uv_world_box(bd, scale=0.5)
    dobj = B.finish(bd, name + "_door", ["metal_painted", "metal_rust", "paper_aged"])
    dobj.location = (-W * 0.5, -0.008, 0)
    return [body, dobj]


def fuse(name="fuse"):
    """Fusible céramique à ramasser. Origine au centre."""
    bm = B.bm_new()
    B.cylinder(bm, 0.021, 0.076, 16, center=(0, 0, 0), mat=0)
    for s in (-1, 1):
        B.cylinder(bm, 0.024, 0.016, 16, center=(0, 0, s * 0.042), mat=1)
        B.cylinder(bm, 0.019, 0.010, 14, center=(0, 0, s * 0.053), mat=1)
    for i in range(3):    # nervures
        B.cylinder(bm, 0.0235, 0.006, 16, center=(0, 0, -0.018 + i * 0.018), mat=0)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.25)
    return [B.finish(bm, name, ["wall_tile", "metal_painted"], smooth_angle=True)]


def battery(name="battery"):
    bm = B.bm_new()
    B.cylinder(bm, 0.0165, 0.050, 16, center=(0, 0, 0), mat=0)
    B.cylinder(bm, 0.0165, 0.006, 16, center=(0, 0, 0.0245), mat=1)
    B.cylinder(bm, 0.006, 0.004, 10, center=(0, 0, 0.028), mat=1)
    B.cylinder(bm, 0.0168, 0.020, 16, center=(0, 0, -0.004), mat=1)
    B.bevel_sharp(bm, 0.001, 1)
    B.uv_world_box(bm, scale=0.15)
    return [B.finish(bm, name, ["metal_painted", "metal_rust"], smooth_angle=True)]


def flashlight(name="flashlight"):
    """Lampe torche à main. Origine à la crosse, le faisceau part vers +Z."""
    bm = B.bm_new()
    B.cylinder(bm, 0.024, 0.155, 18, center=(0, 0, 0.078), mat=0)
    for i in range(9):   # moletage
        B.cylinder(bm, 0.0252, 0.004, 18, center=(0, 0, 0.030 + i * 0.010), mat=0)
    B.cylinder(bm, 0.030, 0.030, 18, center=(0, 0, 0.168), radius_top=0.042, mat=0)
    B.cylinder(bm, 0.043, 0.020, 20, center=(0, 0, 0.192), mat=1)
    B.cylinder(bm, 0.038, 0.006, 20, center=(0, 0, 0.200), mat=2)   # lentille
    B.box(bm, size=(0.022, 0.014, 0.030), center=(0, -0.026, 0.055), mat=1)  # interrupteur
    B.cylinder(bm, 0.021, 0.008, 16, center=(0, 0, -0.004), mat=1)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.2)
    return [B.finish(bm, name, ["metal_painted", "metal_rust", "glass_dirty"], smooth_angle=True)]


# ==========================================================================
#  Mobilier courant / décor
# ==========================================================================
def chair(name="chair"):
    bm = B.bm_new()
    SH, S = 0.46, 0.42
    B.box(bm, size=(S, S, 0.030), center=(0, 0, SH), mat=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = SH + (0.46 if sy > 0 else 0.0)
            B.box(bm, size=(0.035, 0.035, h),
                  center=(sx * (S * 0.5 - 0.028), sy * (S * 0.5 - 0.028), h * 0.5), mat=0)
    for sy in (-1, 1):   # entretoises
        B.box(bm, size=(S - 0.04, 0.022, 0.022), center=(0, sy * (S * 0.5 - 0.028), 0.16), mat=0)
    for cz in (SH + 0.24, SH + 0.40):
        B.box(bm, size=(S - 0.06, 0.028, 0.075), center=(0, S * 0.5 - 0.028, cz), mat=0)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=0.6)
    return [B.finish(bm, name, ["wood_old"])]


def desk(name="desk"):
    bm = B.bm_new()
    W, D, Hh = 1.30, 0.66, 0.76
    B.box(bm, size=(W, D, 0.040), center=(0, 0, Hh), mat=0)
    B.box(bm, size=(W - 0.04, 0.030, 0.10), center=(0, D * 0.5 - 0.02, Hh - 0.07), mat=0)
    for sx in (-1, 1):
        B.box(bm, size=(0.055, 0.055, Hh), center=(sx * (W * 0.5 - 0.05), -D * 0.5 + 0.05, Hh * 0.5), mat=0)
        B.box(bm, size=(0.055, 0.055, Hh), center=(sx * (W * 0.5 - 0.05), D * 0.5 - 0.05, Hh * 0.5), mat=0)
    # caisson à 3 tiroirs
    B.box(bm, size=(0.42, D - 0.06, Hh - 0.14), center=(W * 0.5 - 0.25, 0, (Hh - 0.14) * 0.5 + 0.07), mat=0)
    for i in range(3):
        z = 0.18 + i * 0.20
        B.box(bm, size=(0.40, 0.020, 0.17), center=(W * 0.5 - 0.25, -D * 0.5 + 0.02, z), mat=0)
        B.box(bm, size=(0.11, 0.028, 0.020), center=(W * 0.5 - 0.25, -D * 0.5 + 0.01, z), mat=1)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=0.8)
    return [B.finish(bm, name, ["wood_old", "metal_painted"])]


def radiator(name="radiator"):
    """Radiateur fonte à colonnes. Origine au mur (Y=0)."""
    bm = B.bm_new()
    n, sp = 12, 0.052
    w = n * sp
    for i in range(n):
        x = -w * 0.5 + sp * 0.5 + i * sp
        for cz in (0.16, 0.72):
            B.cylinder(bm, 0.030, 0.11, 10, center=(x, 0.055, cz), rot=(PI / 2, 0, 0), mat=0)
        B.box(bm, size=(0.030, 0.10, 0.58), center=(x, 0.055, 0.44), mat=0)
        B.cylinder(bm, 0.020, w / n, 8, center=(x, 0.055, 0.44), rot=(0, PI / 2, 0), mat=0)
    B.cylinder(bm, 0.024, w, 10, center=(0, 0.055, 0.16), rot=(0, PI / 2, 0), mat=0)
    B.cylinder(bm, 0.024, w, 10, center=(0, 0.055, 0.72), rot=(0, PI / 2, 0), mat=0)
    for sx in (-1, 1):   # pieds + robinet
        B.box(bm, size=(0.05, 0.14, 0.16), center=(sx * (w * 0.5 - 0.04), 0.055, 0.08), mat=0)
    B.cylinder(bm, 0.016, 0.10, 8, center=(-w * 0.5 - 0.02, 0.055, 0.16), rot=(0, PI / 2, 0), mat=1)
    B.cylinder(bm, 0.030, 0.020, 10, center=(-w * 0.5 - 0.08, 0.055, 0.16), rot=(0, PI / 2, 0), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.5)
    return [B.finish(bm, name, ["metal_painted", "metal_rust"], smooth_angle=True)]


def crate(name="crate"):
    bm = B.bm_new()
    S = 0.56
    for sx in (-1, 1):    # montants
        for sy in (-1, 1):
            B.box(bm, size=(0.05, 0.05, S), center=(sx * (S * 0.5 - 0.025), sy * (S * 0.5 - 0.025), S * 0.5), mat=0)
    for i in range(4):    # planches
        z = 0.07 + i * 0.145
        for sy in (-1, 1):
            B.box(bm, size=(S, 0.018, 0.115), center=(0, sy * (S * 0.5 - 0.009), z), mat=0)
        for sx in (-1, 1):
            B.box(bm, size=(0.018, S, 0.115), center=(sx * (S * 0.5 - 0.009), 0, z), mat=0)
    B.box(bm, size=(S, S, 0.020), center=(0, 0, S - 0.01), mat=0)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=0.5)
    return [B.finish(bm, name, ["wood_old"])]


def debris(name="debris", seed=3):
    """Tas de gravats — plâtre tombé, morceaux de brique."""
    rnd = random.Random(seed)
    bm = B.bm_new()
    for i in range(34):
        a = rnd.random() * 2 * PI
        r = rnd.random() ** 0.6 * 0.62
        s = 0.035 + rnd.random() * 0.10
        B.box(bm, size=(s, s * (0.5 + rnd.random()), s * (0.3 + rnd.random() * 0.5)),
              center=(math.cos(a) * r, math.sin(a) * r,
                      s * 0.3 + max(0.0, (0.5 - r)) * 0.22 * rnd.random()),
              rot=(rnd.random() * 0.6, rnd.random() * 0.6, rnd.random() * PI),
              mat=0 if rnd.random() > 0.35 else 1)
    B.jitter(bm, amount=0.012, seed=seed)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=0.6)
    return [B.finish(bm, name, ["ceiling_plaster", "wall_plaster"])]


def papers(name="papers", seed=5):
    """Documents éparpillés au sol."""
    rnd = random.Random(seed)
    bm = B.bm_new()
    for i in range(16):
        a = rnd.random() * 2 * PI
        r = rnd.random() ** 0.5 * 0.45
        B.box(bm, size=(0.21, 0.297, 0.0012),
              center=(math.cos(a) * r, math.sin(a) * r, 0.001 + i * 0.0013),
              rot=(0, 0, rnd.random() * PI), mat=0)
    B.uv_world_box(bm, scale=0.3)
    return [B.finish(bm, name, ["paper_aged"])]


def pipe_junction(name="pipe_junction"):
    """Nœud de tuyauterie pour la chaufferie. Origine au sol."""
    bm = B.bm_new()
    B.cylinder(bm, 0.085, 2.4, 14, center=(0, 0, 1.2), mat=0)
    for cz in (0.35, 1.15, 1.95):
        B.cylinder(bm, 0.105, 0.06, 14, center=(0, 0, cz), mat=0)
    B.tube(bm, 0.055, 1, 12, (0, 0, 1.55), (0.9, 0, 1.55), mat=0)
    B.cylinder(bm, 0.075, 0.07, 12, center=(0.25, 0, 1.55), rot=(0, PI / 2, 0), mat=0)
    B.cylinder(bm, 0.13, 0.05, 16, center=(0.55, 0, 1.55), rot=(0, PI / 2, 0), mat=1)  # volant
    for i in range(5):
        a = i * 2 * PI / 5
        B.tube(bm, 0.010, 1, 5, (0.55, 0, 1.55),
               (0.55, math.cos(a) * 0.12, 1.55 + math.sin(a) * 0.12), mat=1)
    B.tube(bm, 0.040, 1, 10, (0, 0, 0.75), (0, -0.7, 0.75), mat=0)
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["metal_rust", "metal_painted"], smooth_angle=True)]


def elevator_gate(name="elevator_gate"):
    """Grille de monte-charge — la sortie."""
    bm = B.bm_new()
    W, Hh = 1.90, 2.30
    for sx in (-1, 1):   # huisserie
        B.box(bm, size=(0.10, 0.16, Hh), center=(sx * W * 0.5, 0, Hh * 0.5), mat=0)
    B.box(bm, size=(W + 0.20, 0.16, 0.14), center=(0, 0, Hh + 0.07), mat=0)
    B.box(bm, size=(0.34, 0.10, 0.24), center=(0, -0.10, Hh + 0.07), mat=1)   # cartouche d'étage
    for sx in (-1, 1):   # deux vantaux en ciseaux
        ox = sx * W * 0.25
        for i in range(7):
            x = ox + (i - 3) * 0.065
            B.box(bm, size=(0.022, 0.022, Hh - 0.10), center=(x, -0.03, (Hh - 0.10) * 0.5),
                  rot=(0, 0.22 * (1 if i % 2 else -1), 0), mat=0)
            B.box(bm, size=(0.022, 0.022, Hh - 0.10), center=(x, 0.03, (Hh - 0.10) * 0.5),
                  rot=(0, -0.22 * (1 if i % 2 else -1), 0), mat=0)
        for cz in (0.12, 1.15, 2.15):
            B.box(bm, size=(0.48, 0.07, 0.035), center=(ox, 0, cz), mat=0)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["metal_rust", "metal_painted"])]



# ==========================================================================
#  Pavillon C (niveau -2)
#
#  Le mobilier d'un SERVICE, pas d'un sous-sol technique : ce qu'on trouve
#  dans une salle commune, un poste de garde, une lingerie. C'est ce lot qui
#  fait qu'on sent avoir changé d'étage plutôt que de couloir.
# ==========================================================================
def _castors(bm, w, d, z=0.06, mat=1):
    """Quatre roulettes pivotantes. Tout ce qui roule dans un hôpital en a."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * w * 0.5, sy * d * 0.5
            B.tube(bm, 0.012, 1, 6, (x, y, z + 0.09), (x, y, z + 0.02), mat=mat)
            B.cylinder(bm, z, 0.026, 12, center=(x, y, z), rot=(0, PI / 2, 0), mat=mat)


def gurney(name="gurney"):
    """Brancard à roulettes. Plus étroit et plus haut qu'un lit : on le
    reconnaît de loin, et c'est ce qu'on veut d'un prop de couloir."""
    W, D, H = 0.66, 1.98, 0.76
    bm = B.bm_new()
    B.box(bm, size=(W, D, 0.05), center=(0, 0, H), mat=0)                  # plateau
    B.box(bm, size=(W - 0.06, D - 0.12, 0.07), center=(0, -0.02, H + 0.06), mat=2)
    B.box(bm, size=(W - 0.10, 0.44, 0.10), center=(0, D * 0.5 - 0.30, H + 0.12),
          rot=(-0.34, 0, 0), mat=2)                                        # dossier relevé
    for sx in (-1, 1):                                                     # piètement en X
        B.tube(bm, 0.020, 1, 8, (sx * (W * 0.5 - 0.04), -D * 0.5 + 0.16, H),
               (sx * (W * 0.5 - 0.04), -D * 0.5 + 0.16, 0.14), mat=0)
        B.tube(bm, 0.020, 1, 8, (sx * (W * 0.5 - 0.04), D * 0.5 - 0.16, H),
               (sx * (W * 0.5 - 0.04), D * 0.5 - 0.16, 0.14), mat=0)
        B.tube(bm, 0.016, 1, 6, (sx * (W * 0.5 - 0.04), -D * 0.5 + 0.16, 0.30),
               (sx * (W * 0.5 - 0.04), D * 0.5 - 0.16, 0.30), mat=0)
        for sy in (-1, 1):                                                 # barrières
            B.tube(bm, 0.013, 1, 6,
                   (sx * W * 0.5, sy * 0.10, H + 0.04), (sx * W * 0.5, sy * 0.10, H + 0.30), mat=0)
        B.tube(bm, 0.013, 1, 6,
               (sx * W * 0.5, -0.10, H + 0.30), (sx * W * 0.5, 0.10, H + 0.30), mat=0)
    _castors(bm, W - 0.08, D - 0.32, 0.07, 1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["metal_painted", "metal_rust", "fabric_mattress"],
                     smooth_angle=True)]


def screen(name="screen"):
    """Paravent d'hôpital, trois panneaux en zigzag. Silhouette immédiatement
    reconnaissable, et il cache ce qu'il y a derrière."""
    Hh = 1.72
    bm = B.bm_new()
    angles = (-0.45, 0.0, 0.45)
    x = -0.52
    for i, a in enumerate(angles):
        pw = 0.52
        cx = x + math.cos(a) * pw * 0.5
        cy = math.sin(a) * pw * 0.5
        B.box(bm, size=(pw, 0.026, Hh - 0.24), center=(cx, cy, 0.12 + (Hh - 0.24) * 0.5),
              rot=(0, 0, a), mat=1)                                         # toile
        for sx in (-1, 1):                                                  # montants
            mx = x + math.cos(a) * pw * (0.5 + sx * 0.5)
            my = math.sin(a) * pw * (0.5 + sx * 0.5)
            B.tube(bm, 0.015, 1, 8, (mx, my, 0.0), (mx, my, Hh), mat=0)
        B.box(bm, size=(pw, 0.03, 0.035), center=(cx, cy, Hh - 0.03), rot=(0, 0, a), mat=0)
        x += math.cos(a) * pw
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.8)
    return [B.finish(bm, name, ["metal_painted", "cloth_gown"], smooth_angle=True)]


def trolley(name="trolley"):
    """Chariot de soins à deux plateaux, avec ses cuvettes."""
    W, D, H = 0.48, 0.66, 0.84
    bm = B.bm_new()
    for z in (H, H - 0.34):
        B.box(bm, size=(W, D, 0.024), center=(0, 0, z), mat=0)
        B.box(bm, size=(W, 0.02, 0.035), center=(0, -D * 0.5 + 0.01, z + 0.02), mat=0)
        B.box(bm, size=(W, 0.02, 0.035), center=(0, D * 0.5 - 0.01, z + 0.02), mat=0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.tube(bm, 0.015, 1, 8, (sx * (W * 0.5 - 0.03), sy * (D * 0.5 - 0.03), H),
                   (sx * (W * 0.5 - 0.03), sy * (D * 0.5 - 0.03), 0.13), mat=0)
    B.tube(bm, 0.016, 1, 8, (-W * 0.5 - 0.06, -D * 0.5 + 0.06, H + 0.16),
           (-W * 0.5 - 0.06, D * 0.5 - 0.06, H + 0.16), mat=0)              # poignée
    for sy in (-1, 1):
        B.tube(bm, 0.014, 1, 6, (-W * 0.5 - 0.06, sy * (D * 0.5 - 0.06), H + 0.16),
               (-W * 0.5 + 0.02, sy * (D * 0.5 - 0.06), H), mat=0)
    B.cylinder(bm, 0.11, 0.055, 14, center=(0.06, -0.14, H + 0.04), mat=1)  # cuvette
    B.cylinder(bm, 0.075, 0.045, 12, center=(-0.09, 0.16, H + 0.035), mat=1)
    _castors(bm, W - 0.06, D - 0.06, 0.065, 1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.6)
    return [B.finish(bm, name, ["metal_painted", "metal_rust"], smooth_angle=True)]


def counter(name="counter"):
    """Comptoir du poste de garde : c'est le meuble qui dit « ici on
    surveillait ». Origine au centre, il se pose contre un mur."""
    W, D, H = 1.86, 0.62, 1.08
    bm = B.bm_new()
    B.box(bm, size=(W, D, 0.06), center=(0, 0, H), mat=0)                   # tablette
    B.box(bm, size=(W - 0.10, D - 0.16, 0.05), center=(0, 0.04, H - 0.32), mat=0)
    B.box(bm, size=(W, 0.035, H - 0.10), center=(0, -D * 0.5 + 0.02, (H - 0.10) * 0.5), mat=0)
    for sx in (-1, 1):
        B.box(bm, size=(0.04, D, H - 0.10), center=(sx * (W * 0.5 - 0.02), 0,
              (H - 0.10) * 0.5), mat=0)
    for i in range(3):                                                      # tiroirs
        x = -0.55 + i * 0.55
        B.box(bm, size=(0.50, 0.03, 0.20), center=(x, -D * 0.5 - 0.005, H - 0.20), mat=1)
        B.box(bm, size=(0.16, 0.026, 0.022), center=(x, -D * 0.5 - 0.025, H - 0.20), mat=1)
    B.box(bm, size=(W, D, 0.04), center=(0, 0, 0.02), mat=1)                # plinthe
    B.bevel_sharp(bm, 0.004, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["wood_old", "metal_painted"])]


def bench(name="bench"):
    """Banc d'attente à lattes."""
    W, D, H = 1.54, 0.40, 0.44
    bm = B.bm_new()
    for i in range(4):
        B.box(bm, size=(W, 0.075, 0.028), center=(0, -D * 0.5 + 0.05 + i * 0.10, H), mat=0)
    for sx in (-1, 1):
        x = sx * (W * 0.5 - 0.13)
        B.box(bm, size=(0.05, D, 0.035), center=(x, 0, H - 0.035), mat=1)
        for sy in (-1, 1):
            B.tube(bm, 0.017, 1, 6, (x, sy * (D * 0.5 - 0.05), H - 0.05),
                   (x, sy * (D * 0.5 - 0.05), 0.0), mat=1)
        B.tube(bm, 0.014, 1, 6, (x, -D * 0.5 + 0.05, 0.14), (x, D * 0.5 - 0.05, 0.14), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["wood_old", "metal_painted"])]


def long_table(name="long_table"):
    """Table de réfectoire de la salle commune."""
    W, D, H = 2.10, 0.78, 0.74
    bm = B.bm_new()
    B.box(bm, size=(W, D, 0.038), center=(0, 0, H), mat=0)
    B.box(bm, size=(W - 0.16, 0.05, 0.07), center=(0, 0, H - 0.055), mat=0)
    for sx in (-1, 1):
        x = sx * (W * 0.5 - 0.14)
        for sy in (-1, 1):
            B.box(bm, size=(0.055, 0.055, H - 0.04), center=(x, sy * (D * 0.5 - 0.10),
                  (H - 0.04) * 0.5), mat=1)
        B.box(bm, size=(0.04, D - 0.18, 0.04), center=(x, 0, 0.16), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.8)
    return [B.finish(bm, name, ["wood_old", "metal_painted"])]


def shelving(name="shelving"):
    """Étagère de lingerie, avec ses piles de linge."""
    W, D, H = 0.94, 0.38, 1.86
    bm = B.bm_new()
    for i in range(4):
        z = 0.22 + i * 0.52
        B.box(bm, size=(W, D, 0.022), center=(0, 0, z), mat=0)
        if i < 3:
            for j in range(2):
                B.box(bm, size=(0.34, D - 0.10, 0.16),
                      center=(-0.22 + j * 0.44, 0, z + 0.09),
                      rot=(0, 0, 0.05 * (1 if j else -1)), mat=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box(bm, size=(0.032, 0.032, H), center=(sx * (W * 0.5 - 0.02),
                  sy * (D * 0.5 - 0.02), H * 0.5), mat=0)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["metal_rust", "cloth_gown"])]


def laundry_cart(name="laundry_cart"):
    """Chariot à linge : un bac de toile sur un cadre à roulettes."""
    W, D, H = 0.72, 0.52, 0.82
    bm = B.bm_new()
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.tube(bm, 0.016, 1, 8, (sx * (W * 0.5 - 0.04), sy * (D * 0.5 - 0.04), H),
                   (sx * (W * 0.5 - 0.04), sy * (D * 0.5 - 0.04), 0.13), mat=0)
    for sy in (-1, 1):
        B.tube(bm, 0.016, 1, 8, (-W * 0.5 + 0.04, sy * (D * 0.5 - 0.04), H),
               (W * 0.5 - 0.04, sy * (D * 0.5 - 0.04), H), mat=0)
    for sx in (-1, 1):
        B.tube(bm, 0.016, 1, 8, (sx * (W * 0.5 - 0.04), -D * 0.5 + 0.04, H),
               (sx * (W * 0.5 - 0.04), D * 0.5 - 0.04, H), mat=0)
    # le sac, affaissé : des parois légèrement rentrantes
    for sx in (-1, 1):
        B.box(bm, size=(0.022, D - 0.08, H - 0.30), center=(sx * (W * 0.5 - 0.06), 0,
              0.15 + (H - 0.30) * 0.5), rot=(0, sx * -0.05, 0), mat=1)
    for sy in (-1, 1):
        B.box(bm, size=(W - 0.08, 0.022, H - 0.30), center=(0, sy * (D * 0.5 - 0.06),
              0.15 + (H - 0.30) * 0.5), rot=(sy * 0.05, 0, 0), mat=1)
    B.box(bm, size=(W - 0.14, D - 0.14, 0.02), center=(0, 0, 0.16), mat=1)
    B.box(bm, size=(W - 0.20, D - 0.20, 0.13), center=(0.03, -0.02, H - 0.10), mat=1)
    _castors(bm, W - 0.08, D - 0.08, 0.065, 0)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["metal_painted", "cloth_gown"], smooth_angle=True)]


def wall_clock(name="wall_clock"):
    """Horloge de service, arrêtée. Origine au mur (Y=0), dépasse vers -Y."""
    bm = B.bm_new()
    B.cylinder(bm, 0.155, 0.055, 24, center=(0, -0.028, 0), rot=(PI / 2, 0, 0), mat=0)
    B.cylinder(bm, 0.138, 0.010, 24, center=(0, -0.057, 0), rot=(PI / 2, 0, 0), mat=1)
    B.cylinder(bm, 0.142, 0.012, 24, center=(0, -0.064, 0), rot=(PI / 2, 0, 0), mat=2)
    for i in range(12):                                                     # index des heures
        a = i * math.pi / 6.0
        B.box(bm, size=(0.010, 0.006, 0.020), center=(math.sin(a) * 0.118, -0.062,
              math.cos(a) * 0.118), rot=(0, -a, 0), mat=0)
    # Aiguilles arrêtées. Pas à midi : une horloge d'hôpital qui s'est arrêtée
    # le fait à une heure quelconque, et c'est ce détail qui la rend crédible.
    for ang, lg, ep in ((0.72, 0.070, 0.009), (3.55, 0.104, 0.006)):
        B.box(bm, size=(ep, 0.005, lg), center=(math.sin(ang) * lg * 0.5, -0.066,
              math.cos(ang) * lg * 0.5), rot=(0, -ang, 0), mat=0)
    B.cylinder(bm, 0.009, 0.010, 10, center=(0, -0.068, 0), rot=(PI / 2, 0, 0), mat=0)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.3)
    return [B.finish(bm, name, ["wood_old", "paper_aged", "glass_dirty"], smooth_angle=True)]


def notice_board(name="notice_board"):
    """Panneau d'affichage du poste de garde. Origine au mur (Y=0), vers -Y."""
    W, Hh = 0.86, 0.62
    bm = B.bm_new()
    B.box(bm, size=(W, 0.028, Hh), center=(0, -0.014, 0), mat=2)            # liège
    for sx in (-1, 1):                                                      # cadre
        B.box(bm, size=(0.035, 0.038, Hh), center=(sx * (W * 0.5 - 0.017), -0.019, 0), mat=0)
    for sz in (-1, 1):
        B.box(bm, size=(W, 0.038, 0.035), center=(0, -0.019, sz * (Hh * 0.5 - 0.017)), mat=0)
    rnd = random.Random(4)                                                  # punaisé de travers
    for i in range(7):
        w, h = rnd.uniform(0.11, 0.17), rnd.uniform(0.14, 0.21)
        B.box(bm, size=(w, 0.002, h),
              center=(rnd.uniform(-0.30, 0.30), -0.030, rnd.uniform(-0.18, 0.18)),
              rot=(0, rnd.uniform(-0.09, 0.09), 0), mat=1)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["wood_old", "paper_aged", "grime_dark"])]


def wall_phone(name="wall_phone"):
    """Téléphone mural en bakélite. Origine au mur (Y=0), dépasse vers -Y."""
    bm = B.bm_new()
    B.box(bm, size=(0.17, 0.09, 0.26), center=(0, -0.045, 0), mat=0)        # boîtier
    B.box(bm, size=(0.13, 0.02, 0.09), center=(0, -0.095, 0.05), mat=0)
    B.cylinder(bm, 0.052, 0.018, 16, center=(0, -0.098, -0.05), rot=(PI / 2, 0, 0), mat=1)
    B.box(bm, size=(0.055, 0.052, 0.20), center=(0, -0.118, 0.02), mat=0)   # combiné
    for sz in (-1, 1):
        B.cylinder(bm, 0.038, 0.030, 12, center=(0, -0.126, 0.02 + sz * 0.098),
                   rot=(PI / 2, 0, 0), mat=0)
    for i in range(6):                                                      # cordon pendant
        z0 = -0.10 - i * 0.055
        B.torus(bm, 0.026, 0.006, 10, 5, center=(0.02, -0.11, z0), rot=(PI / 2, 0, 0), mat=0)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.3)
    return [B.finish(bm, name, ["metal_painted", "metal_rust"], smooth_angle=True)]


def coat_rack(name="coat_rack"):
    """Patère de couloir avec une blouse restée là. Origine au mur, vers -Y."""
    bm = B.bm_new()
    B.box(bm, size=(1.08, 0.028, 0.13), center=(0, -0.014, 0), mat=0)
    for i in range(5):
        x = -0.42 + i * 0.21
        B.tube(bm, 0.009, 1, 6, (x, -0.02, 0.02), (x, -0.075, 0.02), mat=1)
        B.tube(bm, 0.009, 1, 6, (x, -0.075, 0.02), (x, -0.085, -0.035), mat=1)
    # une blouse suspendue : deux plans qui tombent, légèrement écartés
    B.box(bm, size=(0.30, 0.05, 0.62), center=(-0.21, -0.075, -0.35), rot=(0.05, 0, 0), mat=2)
    B.box(bm, size=(0.20, 0.035, 0.34), center=(-0.21, -0.055, -0.70), rot=(-0.04, 0, 0.03), mat=2)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.5)
    return [B.finish(bm, name, ["wood_old", "metal_rust", "cloth_gown"])]



# ==========================================================================
#  Les bains — niveau -3
#
#  L'hydrothérapie du Mont-Cendre : baignoires scellées, jets, tables
#  d'enveloppement. Tout ce qui est en laiton a viré au vert-de-gris.
# ==========================================================================
def bathtub(name="bathtub"):
    """Baignoire de balnéothérapie, fonte émaillée sur pieds griffes.

    Bâtie en PAROIS et non en bloc : une cuve creusée par un pavé intérieur
    ne se voit pas — de l'extérieur on n'a qu'un bloc plein, et c'est le prop
    qui doit dire d'un coup d'œil où l'on se trouve.
    """
    W, D, H = 0.74, 1.72, 0.62
    Z0, EP = 0.16, 0.055                      # hauteur du dessous, épaisseur
    bm = B.bm_new()
    # fond
    B.box(bm, size=(W, D, EP), center=(0, 0, Z0 + EP * 0.5), mat=0)
    # quatre parois
    for sx in (-1, 1):
        B.box(bm, size=(EP, D, H), center=(sx * (W - EP) * 0.5, 0, Z0 + H * 0.5), mat=0)
    for sy in (-1, 1):
        B.box(bm, size=(W - EP * 2, EP, H), center=(0, sy * (D - EP) * 0.5, Z0 + H * 0.5),
              mat=0)
    # rebord roulé
    for sx in (-1, 1):
        B.cylinder(bm, EP * 0.6, D, 10, center=(sx * (W - EP) * 0.5, 0, Z0 + H),
                   rot=(PI / 2, 0, 0), mat=0)
    for sy in (-1, 1):
        B.cylinder(bm, EP * 0.6, W - EP * 2, 10, center=(0, sy * (D - EP) * 0.5, Z0 + H),
                   rot=(0, PI / 2, 0), mat=0)
    for sy in (-1, 1):                                       # pieds griffes
        for sx in (-1, 1):
            B.cylinder(bm, 0.045, Z0, 10,
                       center=(sx * (W * 0.5 - 0.09), sy * (D * 0.5 - 0.14), Z0 * 0.5), mat=2)
            B.sphere(bm, 0.055, 10, 6,
                     center=(sx * (W * 0.5 - 0.09), sy * (D * 0.5 - 0.14), 0.05),
                     scale=(1, 1, 0.7), mat=2)
    # robinetterie en bout
    B.cylinder(bm, 0.030, 0.16, 10, center=(0, -D * 0.5 + 0.10, Z0 + H + 0.20),
               rot=(PI / 2, 0, 0), mat=2)
    B.cylinder(bm, 0.022, 0.13, 10, center=(0, -D * 0.5 + 0.02, Z0 + H + 0.15), mat=2)
    for sx in (-1, 1):
        B.torus(bm, 0.045, 0.010, 12, 6,
                center=(sx * 0.15, -D * 0.5 + 0.06, Z0 + H + 0.06), rot=(PI / 2, 0, 0), mat=2)
    # eau croupie au fond, presque affleurante
    B.box(bm, size=(W - EP * 2.4, D - EP * 2.4, 0.012),
          center=(0, 0, Z0 + EP + 0.10), mat=1)
    B.cylinder(bm, 0.035, 0.014, 12, center=(0, D * 0.5 - 0.24, Z0 + EP + 0.01), mat=2)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["email", "water_dark", "metal_verdigris"],
                     smooth_angle=True)]


def shower_head(name="shower_head"):
    """Douche à jet. Origine au mur (Y=0), dépasse vers -Y."""
    bm = B.bm_new()
    B.box(bm, size=(0.10, 0.04, 0.16), center=(0, -0.02, 0), mat=0)
    B.tube(bm, 0.018, 1, 10, (0, -0.03, 0.02), (0, -0.03, 0.62), mat=0)
    B.tube(bm, 0.018, 1, 10, (0, -0.03, 0.62), (0, -0.30, 0.62), mat=0)
    B.cylinder(bm, 0.075, 0.045, 16, center=(0, -0.33, 0.58), rot=(0.35, 0, 0),
               mat=0, radius_top=0.055)
    for sx in (-1, 1):                                       # volants
        B.torus(bm, 0.048, 0.011, 12, 6, center=(sx * 0.13, -0.03, 0.10),
                rot=(PI / 2, 0, 0), mat=0)
        B.tube(bm, 0.013, 1, 8, (0, -0.03, 0.10), (sx * 0.13, -0.03, 0.10), mat=0)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["metal_verdigris"], smooth_angle=True)]


def massage_table(name="massage_table"):
    """Table d'enveloppement : on y roulait les pensionnaires dans des draps
    mouillés. Sangles comprises."""
    W, D, H = 0.66, 1.84, 0.78
    bm = B.bm_new()
    B.box(bm, size=(W, D, 0.06), center=(0, 0, H), mat=0)
    B.box(bm, size=(W - 0.04, D - 0.08, 0.09), center=(0, 0, H + 0.07), mat=1)
    for sy in (-0.55, 0.0, 0.55):                            # sangles
        B.box(bm, size=(W + 0.03, 0.055, 0.016), center=(0, sy * D * 0.5, H + 0.12), mat=2)
        B.box(bm, size=(0.05, 0.05, 0.10), center=(W * 0.5 + 0.01, sy * D * 0.5, H + 0.06),
              rot=(0.3, 0, 0), mat=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.tube(bm, 0.022, 1, 8, (sx * (W * 0.5 - 0.06), sy * (D * 0.5 - 0.12), H),
                   (sx * (W * 0.5 - 0.06), sy * (D * 0.5 - 0.12), 0.0), mat=0)
        B.tube(bm, 0.016, 1, 6, (sx * (W * 0.5 - 0.06), -D * 0.5 + 0.12, 0.24),
               (sx * (W * 0.5 - 0.06), D * 0.5 - 0.12, 0.24), mat=0)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["metal_verdigris", "fabric_mattress", "cloth_gown"],
                     smooth_angle=True)]


def changing_cabin(name="changing_cabin"):
    """Cabine de déshabillage : trois cloisons et une tringle. Le rideau a
    disparu, la tringle non."""
    W, D, Hh = 0.98, 0.92, 2.05
    bm = B.bm_new()
    for sx in (-1, 1):                                        # joues
        B.box(bm, size=(0.035, D, Hh - 0.22), center=(sx * W * 0.5, 0, 0.22 + (Hh - 0.22) * 0.5),
              mat=0)
    B.box(bm, size=(W, 0.035, Hh - 0.22), center=(0, D * 0.5, 0.22 + (Hh - 0.22) * 0.5), mat=0)
    B.box(bm, size=(W + 0.06, D + 0.04, 0.05), center=(0, 0, Hh), mat=0)   # linteau
    B.tube(bm, 0.014, 1, 8, (-W * 0.5, -D * 0.5 + 0.05, Hh - 0.10),
           (W * 0.5, -D * 0.5 + 0.05, Hh - 0.10), mat=1)      # tringle
    for i in range(5):                                        # anneaux restants
        B.torus(bm, 0.022, 0.005, 10, 5,
                center=(-0.34 + i * 0.17, -D * 0.5 + 0.05, Hh - 0.10),
                rot=(0, PI / 2, 0), mat=1)
    B.box(bm, size=(W - 0.10, 0.22, 0.04), center=(0, D * 0.5 - 0.14, 0.44), mat=2)  # banc
    for sx in (-1, 1):
        B.tube(bm, 0.015, 1, 6, (sx * (W * 0.5 - 0.12), D * 0.5 - 0.14, 0.42),
               (sx * (W * 0.5 - 0.12), D * 0.5 - 0.14, 0.0), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.7)
    return [B.finish(bm, name, ["wood_old", "metal_verdigris", "wood_old"])]


def pipe_bank(name="pipe_bank"):
    """Nourrice : la batterie de tuyaux et de vannes qui alimentait les bains.
    Origine au mur (Y=0), dépasse vers -Y."""
    bm = B.bm_new()
    B.box(bm, size=(1.16, 0.05, 0.14), center=(0, -0.025, 1.05), mat=0)
    for i in range(4):
        x = -0.42 + i * 0.28
        B.tube(bm, 0.032, 1, 10, (x, -0.08, -1.10), (x, -0.08, 1.10), mat=0)
        B.cylinder(bm, 0.052, 0.09, 12, center=(x, -0.08, 0.10), mat=0)     # corps de vanne
        B.tube(bm, 0.014, 1, 8, (x, -0.08, 0.15), (x, -0.20, 0.15), mat=0)
        B.torus(bm, 0.062, 0.012, 14, 6, center=(x, -0.23, 0.15), rot=(PI / 2, 0, 0), mat=0)
        for k in range(3):                                                   # rayons du volant
            a = k * PI / 3.0
            B.tube(bm, 0.008, 1, 5,
                   (x + math.cos(a) * 0.06, -0.23, 0.15 + math.sin(a) * 0.06),
                   (x - math.cos(a) * 0.06, -0.23, 0.15 - math.sin(a) * 0.06), mat=0)
        B.box(bm, size=(0.10, 0.10, 0.03), center=(x, -0.08, -0.62), mat=0)  # colliers
        B.box(bm, size=(0.10, 0.10, 0.03), center=(x, -0.08, 0.72), mat=0)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.5)
    return [B.finish(bm, name, ["metal_verdigris"], smooth_angle=True)]


def basin(name="basin"):
    """Lavabo mural en faïence. Origine au mur (Y=0), dépasse vers -Y."""
    bm = B.bm_new()
    B.box(bm, size=(0.56, 0.42, 0.16), center=(0, -0.21, 0), mat=0)
    B.box(bm, size=(0.44, 0.31, 0.10), center=(0, -0.20, 0.04), mat=0)
    B.cylinder(bm, 0.028, 0.10, 10, center=(0, -0.05, 0.13), mat=1)
    B.tube(bm, 0.018, 1, 8, (0, -0.05, 0.17), (0, -0.14, 0.15), mat=1)
    for sx in (-1, 1):
        B.torus(bm, 0.032, 0.008, 10, 5, center=(sx * 0.10, -0.05, 0.11),
                rot=(PI / 2, 0, 0), mat=1)
    B.tube(bm, 0.026, 1, 8, (0, -0.20, -0.08), (0, -0.20, -0.42), mat=1)  # siphon
    B.tube(bm, 0.026, 1, 8, (0, -0.20, -0.42), (0, -0.04, -0.46), mat=1)
    B.bevel_sharp(bm, 0.003, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["email", "metal_verdigris"], smooth_angle=True)]


def floor_drain(name="floor_drain"):
    """Bonde de sol. À peine 4 cm de haut, mais c'est ce qui dit que la pièce
    était faite pour être inondée."""
    bm = B.bm_new()
    B.box(bm, size=(0.34, 0.34, 0.035), center=(0, 0, 0.017), mat=0)
    B.box(bm, size=(0.24, 0.24, 0.05), center=(0, 0, 0.005), mat=1)
    for i in range(5):
        B.box(bm, size=(0.22, 0.016, 0.02), center=(0, -0.09 + i * 0.045, 0.030), mat=0)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.3)
    return [B.finish(bm, name, ["metal_verdigris", "grime_dark"])]


def bucket(name="bucket"):
    bm = B.bm_new()
    B.cylinder(bm, 0.135, 0.30, 16, center=(0, 0, 0.15), mat=0, radius_top=0.155)
    B.cylinder(bm, 0.145, 0.016, 16, center=(0, 0, 0.30), mat=0)
    B.torus(bm, 0.145, 0.006, 16, 5, center=(0, 0, 0.13), mat=0)
    for sx in (-1, 1):                                        # anse
        B.tube(bm, 0.006, 1, 5, (sx * 0.150, 0, 0.27), (sx * 0.115, 0, 0.40), mat=0)
    B.tube(bm, 0.006, 1, 5, (-0.115, 0, 0.40), (0.115, 0, 0.40), mat=0)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["metal_painted"], smooth_angle=True)]


def stool(name="stool"):
    bm = B.bm_new()
    B.cylinder(bm, 0.17, 0.035, 14, center=(0, 0, 0.44), mat=0)
    for i in range(3):
        a = i * 2 * PI / 3
        B.tube(bm, 0.014, 1, 6, (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.42),
               (math.cos(a) * 0.19, math.sin(a) * 0.19, 0.0), mat=1)
    B.torus(bm, 0.145, 0.008, 14, 5, center=(0, 0, 0.16), mat=1)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["wood_old", "metal_verdigris"], smooth_angle=True)]


def hose_coil(name="hose_coil"):
    """Lance d'hydrothérapie, enroulée sur son crochet. Origine au mur."""
    bm = B.bm_new()
    B.box(bm, size=(0.08, 0.06, 0.10), center=(0, -0.03, 0), mat=0)
    B.tube(bm, 0.012, 1, 6, (0, -0.05, 0), (0, -0.16, 0), mat=0)
    for i in range(7):                                        # couronnes du tuyau
        r = 0.20 - i * 0.012
        B.torus(bm, r, 0.021, 20, 6, center=(0, -0.13 - (i % 2) * 0.03, -0.16),
                rot=(PI / 2, 0, 0), mat=1)
    B.cylinder(bm, 0.020, 0.20, 10, center=(0.16, -0.20, -0.40), rot=(0.5, 0, 0.4), mat=0)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.4)
    return [B.finish(bm, name, ["metal_verdigris", "grime_dark"], smooth_angle=True)]


def valve(name="valve"):
    """Volant de vanne — la pièce à retrouver au niveau -3. Petit objet posé,
    comme le fusible : origine au centre, Z=0 au sol."""
    bm = B.bm_new()
    B.torus(bm, 0.075, 0.014, 18, 8, center=(0, 0, 0.075), rot=(PI / 2, 0, 0), mat=0)
    for k in range(3):
        a = k * PI / 3.0
        B.tube(bm, 0.010, 1, 6, (math.cos(a) * 0.072, 0, 0.075 + math.sin(a) * 0.072),
               (-math.cos(a) * 0.072, 0, 0.075 - math.sin(a) * 0.072), mat=0)
    B.cylinder(bm, 0.022, 0.05, 10, center=(0, 0, 0.075), rot=(PI / 2, 0, 0), mat=0)
    B.cylinder(bm, 0.013, 0.07, 8, center=(0, -0.04, 0.075), rot=(PI / 2, 0, 0), mat=1)
    B.bevel_sharp(bm, 0.002, 1)
    B.uv_world_box(bm, scale=0.25)
    return [B.finish(bm, name, ["metal_verdigris", "metal_painted"], smooth_angle=True)]


# ==========================================================================
PROPS = {
    "door": door, "door_metal": door_metal, "locker": locker,
    "hospital_bed": hospital_bed, "wheelchair": wheelchair, "iv_stand": iv_stand,
    "cabinet": cabinet, "ceiling_lamp": ceiling_lamp, "wall_lamp": wall_lamp,
    "fuse_box": fuse_box, "fuse": fuse, "battery": battery, "flashlight": flashlight,
    "chair": chair, "desk": desk, "radiator": radiator, "crate": crate,
    "debris": debris, "papers": papers, "pipe_junction": pipe_junction,
    "elevator_gate": elevator_gate,
    # Pavillon C (niveau -2)
    "gurney": gurney, "screen": screen, "trolley": trolley, "counter": counter,
    "bench": bench, "long_table": long_table, "shelving": shelving,
    "laundry_cart": laundry_cart, "wall_clock": wall_clock,
    "notice_board": notice_board, "wall_phone": wall_phone, "coat_rack": coat_rack,
    # Les bains (niveau -3)
    "bathtub": bathtub, "shower_head": shower_head, "massage_table": massage_table,
    "changing_cabin": changing_cabin, "pipe_bank": pipe_bank, "basin": basin,
    "floor_drain": floor_drain, "bucket": bucket, "stool": stool,
    "hose_coil": hose_coil, "valve": valve,
}


def build_all(only=None):
    os.makedirs(OUT, exist_ok=True)
    report = []
    for name, fn in PROPS.items():
        if only and name not in only:
            continue
        B.scene_reset()
        objs = fn()
        path = os.path.join(OUT, f"{name}.glb")
        B.export_glb(objs, path)
        report.append((name, B.tri_count(objs), os.path.getsize(path)))
    return report


if __name__ == "__main__":
    only = sys.argv[1:] or None
    for n, t, s in build_all(only):
        print(f"  {n:<18} {t:>6} tris  {s/1024:>7.1f} KB")
