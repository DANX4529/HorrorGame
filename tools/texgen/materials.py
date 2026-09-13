"""
materials — recettes de textures PBR procédurales pour RESPIRE.

Chaque recette retourne un dict :
    { 'albedo': (H,W,3) float, 'height': (H,W) float,
      'rough': (H,W) float, 'metal': (H,W) float, 'ao': (H,W) float | None,
      'normal_strength': float }

Sortie disque (convention Godot ORMMaterial3D) :
    <nom>_albedo.png   sRGB
    <nom>_normal.png   tangent-space, OpenGL (vert vers le haut)
    <nom>_orm.png      R = occlusion ambiante, G = rugosité, B = métallicité
"""
import numpy as np
from PIL import Image
import noiselib as N


# ==========================================================================
#  Palette RESPIRE — tout est désaturé, vert-de-gris institutionnel
# ==========================================================================
PAL = {
    "tile_green":   (0.541, 0.592, 0.541),
    "tile_pale":    (0.706, 0.729, 0.690),
    "grout":        (0.290, 0.290, 0.267),
    "grime":        (0.145, 0.137, 0.110),
    "rust":         (0.357, 0.176, 0.086),
    "rust_dark":    (0.180, 0.094, 0.055),
    "paint_cream":  (0.647, 0.616, 0.529),
    "plaster":      (0.435, 0.408, 0.365),
    "brick":        (0.333, 0.216, 0.180),
    "concrete":     (0.376, 0.373, 0.357),
    "steel":        (0.400, 0.412, 0.424),
    "steel_dark":   (0.180, 0.192, 0.204),
    "wood":         (0.243, 0.161, 0.098),
    "wood_light":   (0.400, 0.282, 0.176),
    "lino_dark":    (0.106, 0.110, 0.106),
    "lino_light":   (0.588, 0.561, 0.494),
    "flesh":        (0.639, 0.596, 0.549),
    "flesh_dark":   (0.357, 0.302, 0.286),
    "paper":        (0.686, 0.647, 0.549),
    "water_stain":  (0.400, 0.322, 0.204),
}


def _c(name):
    return np.array(PAL[name], dtype=np.float32)


def _solid(res, name):
    return np.broadcast_to(_c(name), (res, res, 3)).astype(np.float32).copy()


# ==========================================================================
#  Recettes
# ==========================================================================
def wall_tile(res=1024, seed=11):
    """Carrelage de sanatorium : faïence vert pâle, joints encrassés, éclats."""
    tile, tid, (fx, fy) = N.brick_grid(res, cols=6, rows=12, offset=0.5, mortar=0.030)

    # variation de teinte par carreau + micro-variation continue
    var = N.per_tile_random(tid, seed, 0.72, 1.06)
    fine = N.fbm(res, 8, 5, seed=seed + 1) * 0.10 + 0.95

    base = N.mix_rgb(_solid(res, "tile_pale"), _solid(res, "tile_green"),
                     N.per_tile_random(tid, seed + 4, 0.0, 1.0) * 0.75)
    base *= (var * fine)[..., None]

    # éclats sur les bords des carreaux (chipping)
    chip_noise = N.fbm(res, 26, 4, seed=seed + 2)
    edge_prox = 1.0 - N.smootherstep_range(np.minimum.reduce([fx, 1 - fx, fy, 1 - fy]), 0.0, 0.16)
    chips = N.clamp01((chip_noise * edge_prox - 0.52) * 9.0) * tile

    # craquelures fines dans l'émail
    craze = N.clamp01((N.ridged(res, 10, 5, seed=seed + 3) - 0.70) * 5.5) * tile

    # joints
    grout_m = 1.0 - tile
    grout_tex = N.fbm(res, 64, 4, seed=seed + 5)
    grout_col = _solid(res, "grout") * (0.62 + 0.6 * grout_tex)[..., None]

    col = N.mix_rgb(base, grout_col, grout_m)
    col = N.mix_rgb(col, _solid(res, "plaster") * 0.85, chips)
    col *= (1.0 - craze * 0.35)[..., None]

    # crasse : s'accumule dans les joints, en bas, et en coulures
    dirt = N.clamp01(N.fbm(res, 5, 6, seed=seed + 6) * 1.25 - 0.20)
    dirt = N.clamp01(dirt + grout_m * 0.45 + N.drips(res, 26, seed + 7, drop=0.45) * 0.75)
    dirt = N.clamp01(dirt * (0.55 + 0.75 * N.fbm(res, 3, 4, seed=seed + 8)))
    col = N.mix_rgb(col, _solid(res, "grime"), dirt * 0.62)

    # moisissure verdâtre localisée
    mold = N.clamp01((N.fbm(res, 4, 6, seed=seed + 9) - 0.60) * 4.0)
    col = N.mix_rgb(col, np.broadcast_to(np.array([0.16, 0.18, 0.12], np.float32),
                                         (res, res, 3)).copy(), mold * 0.55)

    h = tile * 0.80 + (1 - tile) * 0.10 + fine * 0.05 - chips * 0.55 - craze * 0.18
    rough = 0.22 + grout_m * 0.62 + dirt * 0.42 + chips * 0.45 + mold * 0.3
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(rough), metal=np.zeros((res, res), np.float32),
                normal_strength=2.4)


def wall_plaster(res=1024, seed=21):
    """Plâtre peint qui s'écaille en larges plaques, briques apparentes, humidité."""
    # --- couche de brique en dessous ---------------------------------------
    btile, btid, _ = N.brick_grid(res, cols=7, rows=16, offset=0.5, mortar=0.055)
    bvar = N.per_tile_random(btid, seed + 30, 0.60, 1.25)
    bgrain = N.fbm(res, 50, 4, seed=seed + 31)
    brick_col = _solid(res, "brick") * (bvar * (0.80 + 0.40 * bgrain))[..., None]
    mortar_col = _solid(res, "plaster") * (0.70 + 0.35 * N.fbm(res, 70, 3, seed=seed + 32))[..., None]
    under = N.mix_rgb(mortar_col, brick_col, btile)
    under = N.mix_rgb(under, _solid(res, "grime"),
                      N.clamp01((N.fbm(res, 6, 5, seed=seed + 33) - 0.55) * 3.0) * 0.45)

    # --- plâtre / peinture par-dessus --------------------------------------
    plaster_tex = N.fbm(res, 6, 7, seed=seed + 1)
    paint = _solid(res, "paint_cream") * (0.80 + 0.35 * plaster_tex)[..., None]

    # masque d'écaillage : grandes plaques continentales, bords rongés
    conti = N.fbm(res, 2, 4, seed=seed + 2)                    # très grande échelle
    medium = N.fbm(res, 5, 4, seed=seed + 10)
    field = conti * 0.68 + medium * 0.32
    peel = N.smootherstep_range(field, 0.50, 0.565)            # bord net
    # érosion du bord par du bruit fin -> contour déchiqueté, pas de bulles
    erode = N.fbm(res, 34, 3, seed=seed + 4)
    peel = N.clamp01(N.smootherstep_range(field + (erode - 0.5) * 0.085, 0.50, 0.545))

    col = N.mix_rgb(paint, under, peel)

    # liseré sombre + surépaisseur claire au bord de la plaque
    grow = N.blur(peel, 2.2)
    rim_in = N.clamp01((grow - peel) * 3.0)                    # côté brique
    rim_out = N.clamp01((peel - N.blur(peel, 1.0)) * 2.0)
    col *= (1.0 - rim_in * 0.60)[..., None]
    col = N.mix_rgb(col, _solid(res, "paint_cream") * 1.25, rim_out * 0.35)

    # --- humidité : auréoles concentriques ---------------------------------
    stain_f = N.fbm(res, 3, 5, seed=seed + 5)
    rings = N.clamp01(1.0 - np.abs(np.sin(stain_f * 22.0)) * 1.5)
    stain = N.clamp01((stain_f - 0.55) * 3.4)
    col = N.mix_rgb(col, _solid(res, "water_stain"),
                    N.clamp01(stain * (0.45 + rings * 0.5)) * 0.55)
    col = N.mix_rgb(col, _solid(res, "grime"), N.drips(res, 30, seed + 6, drop=0.5) * 0.40)
    # salissure générale plus dense en bas des murs
    col *= (0.80 + 0.35 * N.fbm(res, 4, 4, seed=seed + 7))[..., None]

    h = 0.62 + plaster_tex * 0.10 - peel * 0.34 + btile * peel * 0.16 - rim_in * 0.10
    rough = 0.62 + peel * 0.24 + stain * 0.10
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(rough), metal=np.zeros((res, res), np.float32),
                normal_strength=2.2)


def floor_concrete(res=1024, seed=31):
    """Béton brut taché, granulats apparents, fissures."""
    grain = N.fbm(res, 64, 3, seed=seed + 1)
    agg = N.clamp01((N.worley(res, 46, seed=seed + 2, mode="F1") - 0.35) * 2.2)
    broad = N.fbm(res, 4, 6, seed=seed + 3)

    col = _solid(res, "concrete") * (0.72 + 0.45 * broad + 0.22 * grain)[..., None]
    col = N.mix_rgb(col, _solid(res, "concrete") * 1.35, agg * 0.35)

    cracks = N.clamp01((N.ridged(res, 5, 6, seed=seed + 4) - 0.74) * 7.0)
    cracks = N.clamp01(cracks + N.clamp01((N.ridged(res, 12, 5, seed=seed + 9) - 0.80) * 6.0) * 0.6)
    col *= (1.0 - cracks * 0.72)[..., None]

    stains = N.clamp01((N.fbm(res, 3, 6, seed=seed + 5) - 0.50) * 2.6)
    col = N.mix_rgb(col, _solid(res, "grime"), stains * 0.45)
    col = N.mix_rgb(col, _solid(res, "rust_dark"),
                    N.clamp01((N.fbm(res, 7, 5, seed=seed + 6) - 0.68) * 4.0) * 0.35)

    h = 0.5 + grain * 0.18 + agg * 0.12 - cracks * 0.55
    rough = 0.78 + grain * 0.12 - agg * 0.1 + stains * 0.08
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(rough), metal=np.zeros((res, res), np.float32),
                normal_strength=1.5)


def floor_lino(res=1024, seed=41):
    """Linoléum damier d'hôpital, usé jusqu'à la trame par endroits."""
    checker, tid, (fx, fy) = N.brick_grid(res, cols=8, rows=8, offset=0.0, mortar=0.008)
    parity = ((tid // 1) % 2).astype(np.float32)
    # damier réel : alterne selon ligne+colonne
    lin = np.linspace(0, 1, res, endpoint=False, dtype=np.float32)
    gy, gx = np.meshgrid(lin, lin, indexing="ij")
    chk = ((np.floor(gx * 8) + np.floor(gy * 8)) % 2).astype(np.float32)

    speck = N.fbm(res, 90, 3, seed=seed + 1)
    dark = _solid(res, "lino_dark") * (0.8 + 0.7 * speck)[..., None]
    light = _solid(res, "lino_light") * (0.82 + 0.4 * speck)[..., None]
    col = N.mix_rgb(light, dark, chk)
    col *= (1.0 - (1.0 - checker) * 0.55)[..., None]   # rainure entre dalles

    # usure : chemins de passage et éclats
    wear = N.clamp01((N.fbm(res, 3, 5, seed=seed + 2) - 0.42) * 2.6)
    col = N.mix_rgb(col, _solid(res, "plaster") * 0.7, wear * 0.45)
    scr = N.scratches(res, 220, seed + 3, length=0.10, width=0.8)
    col *= (1.0 - N.clamp01(scr - 0.45) * 0.5)[..., None]

    lift = N.clamp01((N.fbm(res, 6, 5, seed=seed + 4) - 0.70) * 5.0)
    col = N.mix_rgb(col, _solid(res, "concrete") * 0.55, lift)
    col = N.mix_rgb(col, _solid(res, "grime"), N.drips(res, 18, seed + 5, drop=0.3) * 0.35)

    h = 0.6 - (1 - checker) * 0.3 - lift * 0.35 + speck * 0.04
    rough = 0.36 + wear * 0.42 + lift * 0.35 + N.clamp01(scr - 0.4) * 0.3
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(rough), metal=np.zeros((res, res), np.float32),
                normal_strength=1.2)


def wood_old(res=1024, seed=51):
    """Bois ancien verni, veines marquées, coups et éraflures."""
    lin = np.linspace(0, 1, res, endpoint=False, dtype=np.float32)
    gy, gx = np.meshgrid(lin, lin, indexing="ij")
    warp = N.fbm(res, 4, 5, seed=seed + 1) * 0.10
    rings = np.sin((gx + warp) * np.pi * 2 * 11.0 + N.fbm(res, 3, 4, seed=seed + 2) * 6.0)
    grain_fine = N.fbm(res, 110, 3, seed=seed + 3)
    g = N.normalize(rings) * 0.7 + grain_fine * 0.3

    col = N.mix_rgb(_solid(res, "wood"), _solid(res, "wood_light"), g)
    # planches verticales
    plank, ptid, (pfx, pfy) = N.brick_grid(res, cols=4, rows=1, offset=0.0, mortar=0.012)
    col *= (0.75 + 0.5 * N.per_tile_random(ptid, seed + 4, 0.4, 1.0))[..., None]
    col *= (1.0 - (1 - plank) * 0.7)[..., None]

    scr = N.scratches(res, 130, seed + 5, length=0.14, width=0.7)
    col *= (1.0 - N.clamp01(scr - 0.5) * 0.45)[..., None]
    dirt = N.clamp01((N.fbm(res, 4, 5, seed=seed + 6) - 0.48) * 2.4)
    col = N.mix_rgb(col, _solid(res, "grime"), dirt * 0.5)

    h = 0.55 + g * 0.10 - (1 - plank) * 0.35 - N.clamp01(scr - 0.5) * 0.2
    rough = 0.45 + dirt * 0.35 + N.clamp01(scr - 0.5) * 0.3 - g * 0.08
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(rough), metal=np.zeros((res, res), np.float32),
                normal_strength=1.4)


def metal_painted(res=1024, seed=61):
    """Acier peint institutionnel : peinture qui s'écaille en plaques, rouille dessous."""
    tex = N.fbm(res, 26, 4, seed=seed + 1)
    paint = _solid(res, "tile_green") * 0.72 * (0.85 + 0.30 * tex)[..., None]

    # rouille sous-jacente
    rlayer = N.fbm(res, 14, 5, seed=seed + 6)
    rust_col = N.mix_rgb(_solid(res, "rust_dark"), _solid(res, "rust"), N.clamp01(rlayer * 1.25))
    rust_col = N.mix_rgb(rust_col, _solid(res, "rust") * 1.30,
                         N.clamp01((N.fbm(res, 32, 3, seed=seed + 9) - 0.55) * 3.0) * 0.5)

    # plaques d'écaillage : grande échelle + bord érodé (pas de bulles worley)
    field = N.fbm(res, 4, 5, seed=seed + 3) * 0.7 + N.fbm(res, 9, 4, seed=seed + 2) * 0.3
    erode = N.fbm(res, 40, 3, seed=seed + 10)
    chip = N.clamp01(N.smootherstep_range(field + (erode - 0.5) * 0.09, 0.505, 0.545))
    # halo de corrosion qui déborde autour des plaques
    creep = N.clamp01((N.blur(chip, 4.0) - 0.08) * 1.6) * N.clamp01(N.fbm(res, 18, 4, seed=seed + 4) * 1.4)
    rust_m = N.clamp01(chip + creep * 0.75)

    col = N.mix_rgb(paint, rust_col, rust_m)
    rim = N.clamp01((N.blur(chip, 1.6) - chip) * 3.0)
    col *= (1.0 - rim * 0.45)[..., None]

    bare = N.clamp01((chip - 0.55) * 2.2) * N.clamp01((1.0 - rlayer) * 1.6)
    col = N.mix_rgb(col, _solid(res, "steel"), bare * 0.55)

    scr = N.scratches(res, 200, seed + 7, length=0.10, width=0.6)
    col = N.mix_rgb(col, _solid(res, "steel") * 1.15, N.clamp01(scr - 0.55) * 0.40)
    col = N.mix_rgb(col, _solid(res, "grime"), N.drips(res, 22, seed + 8, drop=0.4) * 0.45)

    h = 0.66 + tex * 0.05 - chip * 0.28 - creep * 0.06
    rough = 0.32 + rust_m * 0.50 + chip * 0.15 - bare * 0.12
    metal = N.clamp01(bare * 0.80 + (1.0 - rust_m) * 0.08)
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(rough), metal=metal, normal_strength=2.0)


def metal_rust(res=1024, seed=71):
    """Acier entièrement corrodé — tuyauterie, structure du sous-sol."""
    broad = N.fbm(res, 3, 5, seed=seed + 8)          # grandes zones claires/sombres
    layer = N.fbm(res, 9, 6, seed=seed + 1)
    flake = N.clamp01((N.fbm(res, 6, 4, seed=seed + 3) - 0.46) * 3.4)
    scale = N.clamp01((N.worley(res, 14, seed=seed + 7, mode="F2-F1") - 0.40) * 2.6)

    # piqûres : seulement dans les zones les plus attaquées, pas partout
    pit_mask = N.clamp01((broad - 0.42) * 2.6)
    pit = N.clamp01((N.worley(res, 30, seed=seed + 2, mode="F1") - 0.30) * 2.2)
    pit = pit * pit_mask

    # rampe de rouille à 4 tons : noir -> brun profond -> orange -> orange vif
    t = N.clamp01(broad * 0.62 + layer * 0.38 + 0.12)
    col = N.mix_rgb(_solid(res, "steel_dark") * 0.85, _solid(res, "rust_dark"), N.clamp01(t * 2.2))
    col = N.mix_rgb(col, _solid(res, "rust"), N.clamp01((t - 0.30) * 2.2))
    col = N.mix_rgb(col, _solid(res, "rust") * 1.65, N.clamp01((t - 0.60) * 2.8) * 0.9)
    col = N.mix_rgb(col, _solid(res, "rust") * 1.95, flake * scale * 0.55)
    col *= (0.80 + 0.30 * (1.0 - pit))[..., None]
    col = N.mix_rgb(col, _solid(res, "grime") * 0.9,
                    N.clamp01((N.fbm(res, 5, 5, seed=seed + 9) - 0.62) * 3.5) * 0.40)

    h = 0.5 + layer * 0.22 + flake * scale * 0.22 - pit * 0.22 + broad * 0.10
    rough = N.clamp01(0.70 + layer * 0.22 - flake * scale * 0.16)
    metal = N.clamp01(0.90 * (0.35 + 0.65 * (1.0 - N.clamp01(t * 1.25))))
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=rough, metal=metal, normal_strength=2.2)


def fabric_mattress(res=1024, seed=81):
    """Coutil de matelas rayé, taché, moisi."""
    lin = np.linspace(0, 1, res, endpoint=False, dtype=np.float32)
    gy, gx = np.meshgrid(lin, lin, indexing="ij")
    stripes = (np.sin(gx * np.pi * 2 * 16.0) > 0.55).astype(np.float32)
    weave = (np.sin(gx * np.pi * 2 * res / 4) * np.sin(gy * np.pi * 2 * res / 4)) * 0.5 + 0.5

    base = _solid(res, "paper") * 1.05
    col = N.mix_rgb(base, np.broadcast_to(np.array([0.35, 0.38, 0.42], np.float32),
                                          (res, res, 3)).copy(), stripes * 0.55)
    col *= (0.85 + 0.25 * weave)[..., None]

    stain = N.clamp01((N.fbm(res, 3, 6, seed=seed + 1) - 0.42) * 2.4)
    col = N.mix_rgb(col, _solid(res, "water_stain"), stain * 0.65)
    mold = N.clamp01((N.fbm(res, 9, 5, seed=seed + 2) - 0.66) * 5.0)
    col = N.mix_rgb(col, np.broadcast_to(np.array([0.13, 0.14, 0.10], np.float32),
                                         (res, res, 3)).copy(), mold * 0.75)
    col *= (0.75 + 0.4 * N.fbm(res, 5, 4, seed=seed + 3))[..., None]

    h = 0.5 + weave * 0.25 + stripes * 0.06
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(0.88 + stain * 0.08), metal=np.zeros((res, res), np.float32),
                normal_strength=1.1)


def ceiling_plaster(res=1024, seed=91):
    """Plafond plâtre : auréoles, cloques, fissures, morceaux tombés."""
    tex = N.fbm(res, 7, 6, seed=seed + 1)
    col = _solid(res, "paint_cream") * (0.88 + 0.28 * tex)[..., None]

    stain_f = N.fbm(res, 3, 6, seed=seed + 2)
    halo = N.clamp01((stain_f - 0.48) * 2.8)
    rings = N.clamp01(1.0 - np.abs(np.sin(stain_f * 26.0)) * 1.6)
    col = N.mix_rgb(col, _solid(res, "water_stain"),
                    N.clamp01(halo * (0.4 + rings * 0.55)) * 0.62)

    cracks = N.clamp01((N.ridged(res, 6, 6, seed=seed + 3) - 0.76) * 7.0)
    col *= (1.0 - cracks * 0.6)[..., None]
    fallen = N.clamp01((N.fbm(res, 5, 5, seed=seed + 4) - 0.71) * 5.5)
    col = N.mix_rgb(col, _solid(res, "concrete") * 0.42, fallen)

    h = 0.6 + tex * 0.12 - cracks * 0.4 - fallen * 0.45
    rough = N.clamp01(0.80 + halo * 0.1 + fallen * 0.15)
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=rough, metal=np.zeros((res, res), np.float32), normal_strength=1.8)


def skin_pale(res=1024, seed=101):
    """Peau de la Veilleuse : cireuse, veineuse, marbrée."""
    pores = N.fbm(res, 160, 3, seed=seed + 1)
    blotch = N.fbm(res, 6, 5, seed=seed + 2)
    col = N.mix_rgb(_solid(res, "flesh_dark"), _solid(res, "flesh"),
                    N.clamp01(blotch * 1.3 - 0.1))
    col *= (0.9 + 0.18 * pores)[..., None]

    veins = N.clamp01((N.ridged(res, 5, 6, seed=seed + 3) - 0.70) * 5.0)
    veins += N.clamp01((N.ridged(res, 11, 5, seed=seed + 6) - 0.78) * 6.0) * 0.7
    col = N.mix_rgb(col, np.broadcast_to(np.array([0.24, 0.22, 0.29], np.float32),
                                         (res, res, 3)).copy(), N.clamp01(veins) * 0.55)

    bruise = N.clamp01((N.fbm(res, 4, 5, seed=seed + 4) - 0.60) * 3.5)
    col = N.mix_rgb(col, np.broadcast_to(np.array([0.22, 0.16, 0.20], np.float32),
                                         (res, res, 3)).copy(), bruise * 0.5)
    grime = N.clamp01((N.fbm(res, 8, 5, seed=seed + 5) - 0.62) * 4.0)
    col = N.mix_rgb(col, _solid(res, "grime") * 1.2, grime * 0.35)

    h = 0.5 + pores * 0.10 + veins * 0.22 - blotch * 0.05
    rough = N.clamp01(0.52 + pores * 0.12 + grime * 0.25 - blotch * 0.08)
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=rough, metal=np.zeros((res, res), np.float32), normal_strength=1.6)


def cloth_gown(res=1024, seed=111):
    """Blouse d'infirmière souillée — tissu épais, sang séché, moisissure."""
    weave_f = N.fbm(res, 200, 2, seed=seed + 1)
    lin = np.linspace(0, 1, res, endpoint=False, dtype=np.float32)
    gy, gx = np.meshgrid(lin, lin, indexing="ij")
    weave = (np.abs(np.sin(gx * np.pi * res / 3)) * 0.5 +
             np.abs(np.sin(gy * np.pi * res / 3)) * 0.5)

    base = np.broadcast_to(np.array([0.52, 0.52, 0.49], np.float32), (res, res, 3)).copy()
    col = base * (0.72 + 0.35 * weave + 0.2 * weave_f)[..., None]

    blood = N.clamp01((N.fbm(res, 4, 6, seed=seed + 2) - 0.56) * 3.2)
    blood = N.clamp01(blood + N.drips(res, 24, seed + 3, drop=0.55) * 0.85)
    col = N.mix_rgb(col, np.broadcast_to(np.array([0.20, 0.047, 0.035], np.float32),
                                         (res, res, 3)).copy(), N.clamp01(blood) * 0.8)

    mold = N.clamp01((N.fbm(res, 10, 5, seed=seed + 4) - 0.66) * 4.5)
    col = N.mix_rgb(col, np.broadcast_to(np.array([0.16, 0.17, 0.12], np.float32),
                                         (res, res, 3)).copy(), mold * 0.6)
    col *= (0.7 + 0.45 * N.fbm(res, 5, 4, seed=seed + 5))[..., None]

    h = 0.5 + weave * 0.2 + weave_f * 0.1
    return dict(albedo=N.clamp01(col), height=N.normalize(h),
                rough=N.clamp01(0.90 - blood * 0.2), metal=np.zeros((res, res), np.float32),
                normal_strength=1.0)


def paper_aged(res=1024, seed=121):
    """Papier jauni pour les notes et dossiers médicaux."""
    fib = N.fbm(res, 150, 3, seed=seed + 1)
    tone = N.fbm(res, 5, 5, seed=seed + 2)
    col = _solid(res, "paper") * (0.82 + 0.3 * tone + 0.12 * fib)[..., None]
    fox = N.clamp01((N.worley(res, 30, seed=seed + 3, mode="F1") - 0.55) * 3.5)
    col = N.mix_rgb(col, _solid(res, "rust_dark") * 1.2, fox * 0.45)
    edge_burn = N.clamp01((N.fbm(res, 3, 5, seed=seed + 4) - 0.55) * 3.0)
    col = N.mix_rgb(col, _solid(res, "water_stain") * 0.8, edge_burn * 0.4)
    return dict(albedo=N.clamp01(col), height=N.normalize(0.5 + fib * 0.2),
                rough=np.full((res, res), 0.92, np.float32),
                metal=np.zeros((res, res), np.float32), normal_strength=0.6)


def glass_dirty(res=512, seed=131):
    """Verre sale pour les fenêtres et les portes vitrées."""
    grime = N.clamp01((N.fbm(res, 4, 6, seed=seed + 1) - 0.40) * 2.2)
    streaks = N.drips(res, 30, seed + 2, drop=0.6) * 0.6
    dust = N.fbm(res, 60, 3, seed=seed + 3)
    m = N.clamp01(grime * 0.7 + streaks + dust * 0.25)
    col = N.mix_rgb(np.full((res, res, 3), 0.62, np.float32), _solid(res, "grime"), m * 0.8)
    return dict(albedo=N.clamp01(col), height=N.normalize(0.5 + m * 0.15),
                rough=N.clamp01(0.05 + m * 0.7), metal=np.zeros((res, res), np.float32),
                normal_strength=0.8)



def grime_dark(res=512, seed=141):
    """Noir organique : fond d'orbite, bouche, creux profonds."""
    n = N.fbm(res, 8, 5, seed=seed + 1)
    v = N.fbm(res, 30, 4, seed=seed + 2)
    col = N.mix_rgb(np.full((res, res, 3), 0.018, np.float32),
                    np.broadcast_to(np.array([0.075, 0.055, 0.050], np.float32),
                                    (res, res, 3)).copy(), N.clamp01(n * 1.3))
    col *= (0.6 + 0.7 * v)[..., None]
    return dict(albedo=N.clamp01(col), height=N.normalize(0.5 + n * 0.3),
                rough=N.clamp01(0.55 + v * 0.3), metal=np.zeros((res, res), np.float32),
                normal_strength=1.4)


def hair_dark(res=512, seed=151):
    """Cheveux collés, gras, presque noirs."""
    lin = np.linspace(0, 1, res, endpoint=False, dtype=np.float32)
    gy, gx = np.meshgrid(lin, lin, indexing="ij")
    strand = np.abs(np.sin(gx * np.pi * 90 + N.fbm(res, 4, 4, seed=seed + 1) * 9.0))
    clump = N.fbm(res, 7, 5, seed=seed + 2)
    base = np.broadcast_to(np.array([0.055, 0.045, 0.040], np.float32), (res, res, 3)).copy()
    col = base * (0.45 + 1.1 * strand * (0.5 + clump))[..., None]
    return dict(albedo=N.clamp01(col), height=N.normalize(strand * 0.6 + clump * 0.4),
                rough=N.clamp01(0.40 + clump * 0.35), metal=np.zeros((res, res), np.float32),
                normal_strength=1.8)


RECIPES = {
    "wall_tile": wall_tile,
    "wall_plaster": wall_plaster,
    "floor_concrete": floor_concrete,
    "floor_lino": floor_lino,
    "wood_old": wood_old,
    "metal_painted": metal_painted,
    "metal_rust": metal_rust,
    "fabric_mattress": fabric_mattress,
    "ceiling_plaster": ceiling_plaster,
    "skin_pale": skin_pale,
    "cloth_gown": cloth_gown,
    "paper_aged": paper_aged,
    "glass_dirty": glass_dirty,
    "grime_dark": grime_dark,
    "hair_dark": hair_dark,
}


# ==========================================================================
#  Écriture disque
# ==========================================================================
def _u8(a):
    return (np.clip(a, 0, 1) * 255.0 + 0.5).astype(np.uint8)


def write_material(name, data, outdir):
    import os
    os.makedirs(outdir, exist_ok=True)
    h = data["height"]
    normal = N.height_to_normal(h, data.get("normal_strength", 2.0))
    ao = data.get("ao")
    if ao is None:
        ao = N.ao_from_height(h, radius=5, strength=0.9)
    orm = np.stack([ao, data["rough"], data["metal"]], axis=-1)

    Image.fromarray(_u8(data["albedo"])).save(f"{outdir}/{name}_albedo.png", optimize=True)
    Image.fromarray(_u8(normal)).save(f"{outdir}/{name}_normal.png", optimize=True)
    Image.fromarray(_u8(orm)).save(f"{outdir}/{name}_orm.png", optimize=True)
    return normal, orm
