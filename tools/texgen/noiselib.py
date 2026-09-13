"""
noiselib — bruits procéduraux tuilables (seamless) pour la génération de textures.

Tout est vectorisé numpy. Toutes les fonctions retournent des tableaux float32
dans [0,1] de forme (res, res), et sont *tuilables* : le bord droit se raccorde
au bord gauche, le bas au haut.
"""
import numpy as np


# --------------------------------------------------------------------------
# Utilitaires
# --------------------------------------------------------------------------
def _smoothstep(t):
    return t * t * (3.0 - 2.0 * t)


def _quintic(t):
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


def normalize(a):
    """Remet un tableau dans [0,1]."""
    lo, hi = float(a.min()), float(a.max())
    if hi - lo < 1e-9:
        return np.zeros_like(a)
    return ((a - lo) / (hi - lo)).astype(np.float32)


def clamp01(a):
    return np.clip(a, 0.0, 1.0).astype(np.float32)


def lerp(a, b, t):
    return a + (b - a) * t


def smootherstep_range(x, edge0, edge1):
    t = clamp01((x - edge0) / max(edge1 - edge0, 1e-9))
    return _quintic(t)


# --------------------------------------------------------------------------
# Bruit de valeur tuilable
# --------------------------------------------------------------------------
def value_noise(res, period, seed=0):
    """Bruit de valeur tuilable : treillis `period`x`period` interpolé en quintique."""
    rng = np.random.default_rng(seed)
    period = max(1, int(period))
    lat = rng.random((period, period)).astype(np.float32)

    coord = np.linspace(0.0, period, res, endpoint=False, dtype=np.float32)
    i0 = np.floor(coord).astype(np.int32) % period
    i1 = (i0 + 1) % period
    f = _quintic(coord - np.floor(coord)).astype(np.float32)

    # interpolation sur X puis Y (broadcast : lignes = Y, colonnes = X)
    a = lat[np.ix_(i0, i0)]
    b = lat[np.ix_(i0, i1)]
    c = lat[np.ix_(i1, i0)]
    d = lat[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    top = lerp(a, b, fx)
    bot = lerp(c, d, fx)
    return lerp(top, bot, fy).astype(np.float32)


def fbm(res, period=4, octaves=6, persistence=0.5, lacunarity=2.0, seed=0):
    """Somme fractale de bruits de valeur tuilables."""
    total = np.zeros((res, res), dtype=np.float32)
    amp, norm, per = 1.0, 0.0, float(period)
    for o in range(octaves):
        p = max(1, int(round(per)))
        if p > res:  # au-delà, le treillis dépasse la résolution
            break
        total += value_noise(res, p, seed + o * 7919) * amp
        norm += amp
        amp *= persistence
        per *= lacunarity
    return (total / max(norm, 1e-9)).astype(np.float32)


def ridged(res, period=4, octaves=5, seed=0, persistence=0.5):
    """fBm « ridged » — crêtes nettes, idéal veines / craquelures / rouille."""
    total = np.zeros((res, res), dtype=np.float32)
    amp, norm, per = 1.0, 0.0, float(period)
    for o in range(octaves):
        p = max(1, int(round(per)))
        if p > res:
            break
        n = value_noise(res, p, seed + o * 6271)
        total += (1.0 - np.abs(n * 2.0 - 1.0)) ** 2 * amp
        norm += amp
        amp *= persistence
        per *= 2.0
    return normalize(total / max(norm, 1e-9))


# --------------------------------------------------------------------------
# Worley / cellulaire tuilable
# --------------------------------------------------------------------------
def _cell_points(cells, seed, jitter=1.0):
    """Points jitterés, un par cellule d'une grille `cells`x`cells`, en espace [0,1)."""
    rng = np.random.default_rng(seed)
    base = np.stack(np.meshgrid(np.arange(cells), np.arange(cells), indexing="ij"), -1).astype(np.float32)
    return ((base + rng.random((cells, cells, 2)).astype(np.float32) * jitter) / cells).astype(np.float32)


def _worley_core(res, cells, seed, jitter=1.0):
    """Noyau cellulaire tuilable. Ne teste que les 9 cellules voisines -> O(res^2 * 9).

    Retourne (F1, F2, id_cellule_la_plus_proche).
    """
    cells = max(1, int(cells))
    pts = _cell_points(cells, seed, jitter)          # (cells, cells, 2)

    lin = np.linspace(0, 1, res, endpoint=False, dtype=np.float32)
    gy, gx = np.meshgrid(lin, lin, indexing="ij")
    cy = np.floor(gy * cells).astype(np.int32)
    cx = np.floor(gx * cells).astype(np.int32)

    f1 = np.full((res, res), 10.0, dtype=np.float32)
    f2 = np.full((res, res), 10.0, dtype=np.float32)
    id1 = np.zeros((res, res), dtype=np.int32)

    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            ny = (cy + oy) % cells
            nx = (cx + ox) % cells
            p = pts[ny, nx]                           # (res, res, 2)
            dy = np.abs(gy - p[..., 0]); dy = np.minimum(dy, 1.0 - dy)
            dx = np.abs(gx - p[..., 1]); dx = np.minimum(dx, 1.0 - dx)
            d = np.sqrt(dx * dx + dy * dy)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            id1 = np.where(closer, ny * cells + nx, id1)
            f1 = np.where(closer, d, f1)
    return f1, f2, id1


def worley(res, cells=8, seed=0, mode="F1", jitter=1.0):
    """Bruit cellulaire tuilable. mode: 'F1', 'F2', 'F2-F1'."""
    f1, f2, _ = _worley_core(res, cells, seed, jitter)
    if mode == "F1":
        return normalize(f1)
    if mode == "F2":
        return normalize(f2)
    return normalize(f2 - f1)


def voronoi_cells(res, cells=8, seed=0, jitter=1.0):
    """Retourne (id_cellule, distance_au_bord normalisée) — carreaux irréguliers."""
    f1, f2, id1 = _worley_core(res, cells, seed, jitter)
    return id1, normalize(f2 - f1)


# --------------------------------------------------------------------------
# Motifs
# --------------------------------------------------------------------------
def brick_grid(res, cols=8, rows=8, offset=0.5, mortar=0.035):
    """Grille de briques/carreaux décalée. Retourne (masque_carreau, id_carreau, uv_local)."""
    gy, gx = np.meshgrid(np.linspace(0, 1, res, endpoint=False, dtype=np.float32),
                         np.linspace(0, 1, res, endpoint=False, dtype=np.float32),
                         indexing="ij")
    row = np.floor(gy * rows).astype(np.int32)
    shift = (row % 2).astype(np.float32) * offset
    xx = (gx * cols + shift) % cols
    col = np.floor(xx).astype(np.int32)
    fx, fy = xx - np.floor(xx), gy * rows - row

    m = max(mortar, 1e-4)
    edge = np.minimum.reduce([fx, 1 - fx, fy, 1 - fy])
    tile = smootherstep_range(edge, m * 0.35, m)
    tid = (row * (cols + 7) + col).astype(np.int32)
    return tile.astype(np.float32), tid, (fx.astype(np.float32), fy.astype(np.float32))


def per_tile_random(tid, seed=0, lo=0.0, hi=1.0):
    """Valeur aléatoire stable par identifiant de carreau."""
    h = (tid.astype(np.int64) * 2654435761) ^ (seed * 40503)
    h = (h ^ (h >> 13)) * 1274126177
    h = (h ^ (h >> 16)) & 0xFFFFFF
    return (lo + (hi - lo) * (h / float(0xFFFFFF))).astype(np.float32)


def scratches(res, count=140, seed=0, length=0.12, width=1.4):
    """Rayures fines orientées aléatoirement (tuilables par enroulement)."""
    rng = np.random.default_rng(seed)
    img = np.zeros((res, res), dtype=np.float32)
    for _ in range(count):
        x0, y0 = rng.random(2) * res
        ang = rng.random() * np.pi * 2
        ln = (0.35 + rng.random()) * length * res
        steps = int(max(2, ln))
        t = np.arange(steps, dtype=np.float32)
        # léger gauchissement pour éviter les traits parfaitement droits
        wob = np.cumsum(rng.normal(0, 0.22, steps)).astype(np.float32)
        xs = (x0 + np.cos(ang) * t + np.cos(ang + 1.57) * wob).astype(np.int32) % res
        ys = (y0 + np.sin(ang) * t + np.sin(ang + 1.57) * wob).astype(np.int32) % res
        img[ys, xs] = np.maximum(img[ys, xs], rng.random() * 0.6 + 0.4)
    if width > 0:
        img = blur(img, width)
    return normalize(img)


def drips(res, count=40, seed=0, drop=0.35, spread=2.0):
    """Coulures verticales (traces d'eau, rouille, sang)."""
    rng = np.random.default_rng(seed)
    img = np.zeros((res, res), dtype=np.float32)
    for _ in range(count):
        x = int(rng.random() * res)
        y0 = int(rng.random() * res)
        ln = int((0.1 + rng.random()) * drop * res)
        w = int(1 + rng.random() * spread)
        prof = np.linspace(1.0, 0.0, max(ln, 2), dtype=np.float32) ** 1.6
        for dx in range(-w, w + 1):
            fall = np.exp(-(dx * dx) / max(w * w * 0.6, 0.4))
            ys = (y0 + np.arange(len(prof))) % res
            xs = (x + dx) % res
            img[ys, xs] = np.maximum(img[ys, xs], prof * fall)
    return normalize(blur(img, 1.0))


# --------------------------------------------------------------------------
# Filtres
# --------------------------------------------------------------------------
def blur(a, sigma):
    """Flou gaussien circulaire via FFT — rapide et tuilable par construction."""
    if sigma <= 0:
        return a.astype(np.float32)
    n = a.shape[0]
    # noyau gaussien séparable construit en coordonnées enroulées
    x = np.minimum(np.arange(n), n - np.arange(n)).astype(np.float32)
    g = np.exp(-(x * x) / (2.0 * sigma * sigma))
    g /= g.sum()
    k = np.outer(g, g)
    out = np.fft.irfft2(np.fft.rfft2(a) * np.fft.rfft2(k), s=a.shape)
    return out.astype(np.float32)


def contrast(a, amount=1.0, pivot=0.5):
    return clamp01((a - pivot) * amount + pivot)


def overlay(base, top, amount=1.0):
    """Fusion 'overlay' classique."""
    lo = 2.0 * base * top
    hi = 1.0 - 2.0 * (1.0 - base) * (1.0 - top)
    r = np.where(base < 0.5, lo, hi)
    return clamp01(lerp(base, r, amount))


def height_to_normal(h, strength=2.0):
    """Convertit une carte de hauteur en carte de normales tangentes (RGB 0..1)."""
    # gradients par différences centrées avec enroulement (reste tuilable)
    gx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    gy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx = -gx * strength * h.shape[0] / 256.0
    ny = gy * strength * h.shape[0] / 256.0
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln * 0.5 + 0.5,
                     ny / ln * 0.5 + 0.5,
                     nz / ln * 0.5 + 0.5], axis=-1).astype(np.float32)


def ao_from_height(h, radius=6, strength=1.0):
    """Occlusion ambiante approchée : la hauteur locale comparée au voisinage flouté."""
    lowf = blur(h, radius)
    ao = clamp01(1.0 - (lowf - h) * strength * 4.0)
    return (ao ** 1.2).astype(np.float32)


def curvature(h, radius=2.0):
    """Courbure (>0.5 = arêtes saillantes, <0.5 = creux). Utile pour l'usure."""
    return normalize(h - blur(h, radius))


# --------------------------------------------------------------------------
# Couleur
# --------------------------------------------------------------------------
def tint(mask, c_lo, c_hi):
    """Rampe entre deux couleurs RGB (tuples 0..1) selon un masque scalaire."""
    c_lo = np.array(c_lo, dtype=np.float32)
    c_hi = np.array(c_hi, dtype=np.float32)
    return (c_lo[None, None, :] + (c_hi - c_lo)[None, None, :] * mask[..., None]).astype(np.float32)


def mix_rgb(a, b, mask):
    return (a + (b - a) * mask[..., None]).astype(np.float32)
