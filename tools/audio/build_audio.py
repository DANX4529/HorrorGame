#!/usr/bin/env python3
"""
build_audio — sound design complet de RESPIRE, entièrement synthétisé.

Principe de mixage : la respiration du joueur est TOUJOURS au premier plan.
Tout le reste (ambiance, pas, créature) est mixé autour d'elle.
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import synth as S

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "audio")
SR = S.SR
rng = np.random.default_rng(4242)


# ==========================================================================
#  Respiration — le coeur du jeu
# ==========================================================================
def _breath(dur, f_lo, f_hi, q, amp_pts, seed, voiced=0.0, rasp=0.0):
    """
    Un souffle : bruit filtré par un passe-bande dont la fréquence suit le
    passage de l'air. `voiced` ajoute une composante glottale (cordes vocales),
    `rasp` une saturation qui donne le côté râpeux de l'essoufflement.
    """
    n = int(dur * SR)
    src = S.pink(dur, seed) * 0.7 + S.white(dur, seed + 1) * 0.3
    sweep = S.env_curve(dur, [(0.0, f_lo), (0.45, f_hi), (1.0, f_lo * 0.8)])
    x = S.bandpass(src, sweep, q)
    # deuxième formant : donne l'impression d'une gorge, pas d'un tuyau
    x += S.bandpass(src, sweep * 2.6, q * 1.4) * 0.35
    if voiced > 0:
        f0 = S.env_curve(dur, [(0, 88), (0.5, 96), (1, 84)])
        g = S.sine(dur, f0) * 0.5 + S.sine(dur, f0 * 2) * 0.22 + S.sine(dur, f0 * 3) * 0.1
        x += S.lowpass(g, 900) * voiced
    env = S.env_curve(dur, amp_pts)
    x = S.fit(x, n) * S.fit(env, n)
    if rasp > 0:
        x = S.saturate(x, 1.0 + rasp * 3.0)
    return x


def breath_calm():
    """Respiration au repos : 4 s, inspiration + expiration lentes."""
    inh = _breath(1.55, 340, 1050, 2.6, [(0, 0), (0.28, 0.55), (0.7, 0.72), (1, 0.05)], 11)
    gap1 = np.zeros(int(0.22 * SR), np.float32)
    exh = _breath(1.85, 300, 780, 2.2, [(0, 0.06), (0.18, 0.60), (0.65, 0.38), (1, 0)], 12)
    gap2 = np.zeros(int(0.42 * SR), np.float32)
    x = np.concatenate([inh, gap1, exh, gap2])
    return S.normalize(S.loopable(S.reverb(x, 0.35, 0.16, 3), 0.10), 0.52)


def breath_winded():
    """Essoufflement : cycle court, râpeux, audible de loin."""
    parts = []
    for i in range(3):
        parts.append(_breath(0.44, 380, 1750, 2.0,
                             [(0, 0), (0.22, 0.95), (0.6, 0.8), (1, 0.08)],
                             20 + i * 3, voiced=0.14, rasp=0.55))
        parts.append(np.zeros(int(0.045 * SR), np.float32))
        parts.append(_breath(0.52, 320, 1300, 1.8,
                             [(0, 0.1), (0.16, 0.9), (0.6, 0.55), (1, 0)],
                             21 + i * 3, voiced=0.20, rasp=0.65))
        parts.append(np.zeros(int(0.08 * SR), np.float32))
    x = np.concatenate(parts)
    return S.normalize(S.loopable(S.reverb(x, 0.30, 0.14, 5), 0.07), 0.82)


def breath_hold():
    """
    Apnée : plus de flux d'air, seulement la pression interne — un grondement
    étouffé dans la gorge, des micro-craquements, et une tension qui monte.
    """
    dur = 3.2
    n = int(dur * SR)
    body = S.lowpass(S.brown(dur, 31), 220) * S.env_curve(dur, [(0, 0.25), (1, 0.95)])
    throat = S.resonator(S.white(dur, 32) * 0.02, 130, 0.09, 1.0)
    throat *= S.env_curve(dur, [(0, 0.1), (0.6, 0.5), (1, 1.0)])
    # micro-clics de déglutition
    clicks = np.zeros(n, np.float32)
    for _ in range(7):
        p = int(rng.random() * (n - 3000))
        c = S.resonator(S.white(0.05, int(rng.random() * 999)) * 0.5, 900 + rng.random() * 700, 0.012)
        clicks[p:p + len(c)] += S.fit(c, len(clicks[p:p + len(c)])) * 0.35
    # acouphène qui monte avec le manque d'oxygène
    ring = S.sine(dur, 3100) * S.env_curve(dur, [(0, 0.0), (0.55, 0.0), (1, 0.06)])
    x = S.fit(body, n) * 0.9 + S.fit(throat, n) * 0.8 + clicks + S.fit(ring, n)
    return S.normalize(S.loopable(x, 0.25), 0.62)


def gasp():
    """Halètement forcé : le pic sonore le plus fort du jeu."""
    inh = _breath(0.42, 500, 3200, 1.5, [(0, 0), (0.10, 1.0), (0.45, 0.85), (1, 0.1)],
                  41, voiced=0.10, rasp=0.9)
    exh = _breath(0.70, 280, 1500, 1.6, [(0, 0.3), (0.10, 1.0), (0.5, 0.6), (1, 0)],
                  42, voiced=0.35, rasp=1.0)
    x = np.concatenate([inh, np.zeros(int(0.03 * SR), np.float32), exh])
    return S.normalize(S.reverb(x, 0.55, 0.30, 7), 0.97)


# ==========================================================================
#  Rythme cardiaque
# ==========================================================================
def _thump(f0, dur, punch):
    """Un battement : muscle et sang, pas une sinusoïde nue."""
    n = int(dur * SR)
    f = S.env_curve(dur, [(0, f0 * 2.4), (0.09, f0), (1, f0 * 0.68)])
    tone = S.sine(dur, f) * S.env_curve(dur, [(0, 0), (0.010, 1), (0.32, 0.38), (1, 0)])
    body = S.thud(dur, f0 * 1.9, 0.050, int(f0 * 7) % 9999, slope=2.0)
    body += S.thud(dur, f0 * 1.05, 0.090, int(f0 * 13) % 9999, slope=2.0) * 0.9
    body += S.noise_burst(dur, f0 * 1.1, 0.7, 0.045, int(f0 * 17) % 9999) * 0.30
    slap = S.lowpass(S.lowpass(S.white(dur, int(f0 * 3) % 9999), 170), 170)
    slap *= S.env_curve(dur, [(0, 1), (0.05, 0.25), (0.25, 0.03), (1, 0)])
    x = S.fit(tone, n) * 0.34 + S.fit(body, n) * 1.00 + S.fit(slap, n) * 0.42
    return S.saturate(x * punch, 1.5)


def heartbeat(bpm, punch=1.0, seed=0):
    period = 60.0 / bpm
    n = int(period * SR)
    x = np.zeros(n + int(0.6 * SR), np.float32)
    lub = _thump(52, 0.30, punch)
    dub = _thump(43, 0.26, punch * 0.68)
    x[:len(lub)] += lub
    off = int(0.175 * period * SR)
    x[off:off + len(dub)] += S.fit(dub, len(x[off:off + len(dub)]))
    x = S.reverb(x, 0.28, 0.12, 9)[:n]
    # un battement perçu à travers la cage thoracique est très sourd : la
    # queue de réverbération le rendait trop clair.
    x = S.lowpass(S.lowpass(x, 190, 0.7), 260, 0.7)
    return S.normalize(S.loopable(x, 0.04), 0.80)


# ==========================================================================
#  Pas
# ==========================================================================
def step(kind, seed):
    """
    Un pas.

    Structure d'un impact réel : attaque large bande, puis un CORPS BRUITÉ
    (bruit filtré amorti) qui porte le poids, puis seulement quelques modes
    inharmoniques de matériau en appoint, et enfin le frottement de semelle.
    Un résonateur seul donnerait une sinusoïde amortie — le bip des jeux 8 bits.
    """
    dur = 0.42
    n = int(dur * SR)
    r = np.random.default_rng(seed)

    if kind == "lino":          # semelle sur linoléum : mat, feutré
        f0, dec, bright, grit, modal, drag_f = 215, 0.030, 1900, 0.30, 0.08, 1700
    elif kind == "concrete":    # béton nu : plus sec, plus de grain
        f0, dec, bright, grit, modal, drag_f = 148, 0.026, 3400, 0.58, 0.07, 2200
    else:                       # la Veilleuse : lourd, humide, traînant
        f0, dec, bright, grit, modal, drag_f = 88, 0.060, 1300, 0.50, 0.05, 820

    f0 *= 0.88 + 0.24 * r.random()

    tr = S.transient(dur, bright, seed, 1.0)                       # le contact

    # Le poids vient d'un choc PASSE-BAS, sans hauteur. Les bandes passantes
    # étroites que j'utilisais d'abord restaient périodiques : elles
    # s'entendaient comme une note, d'où l'impression de percussion 8 bits.
    body = S.thud(dur, f0 * 2.6, dec, seed + 11, slope=2.0)
    body += S.thud(dur, f0 * 1.15, dec * 1.7, seed + 12, slope=2.0) * 0.90
    body += S.noise_burst(dur, f0 * 1.1, 0.6, dec * 0.8, seed + 13) * 0.35

    modes = S.material_modes(tr, f0 * 1.15, dec * 0.45, n=5, seed=seed + 21, tilt=0.42)
    grains = S.crackle(dur, 260 + 620 * grit, seed + 31, 1200, 9000, 0.070) * grit

    drag = S.bandpass(S.pink(dur, seed + 41), drag_f, 0.9)
    drag *= S.env_curve(dur, [(0, 0.0), (0.05, 0.55), (0.35, 0.18), (1, 0)])

    x = (S.fit(tr, n) * 0.16 + S.fit(body, n) * 1.30
         + S.fit(modes, n) * modal + S.fit(grains, n) * 0.22
         + S.fit(drag, n) * 0.26)

    if kind == "entity":
        sl = S.bandpass(S.pink(dur, seed + 51), 520, 0.8)
        sl *= S.env_curve(dur, [(0, 0), (0.28, 0.6), (0.75, 0.2), (1, 0)])
        x += S.fit(sl, n) * 0.55
        x = S.lowpass(x, 3200, 0.8)

    return S.normalize(S.reverb(S.saturate(x, 1.25), 0.45, 0.24, seed), 0.80)


# ==========================================================================
#  Ambiances
# ==========================================================================
def amb_drone(dur=18.0):
    """Nappe de fond : infra-grave, souffle d'air, plaintes métalliques lointaines."""
    n = int(dur * SR)
    sub = S.lowpass(S.brown(dur, 61), 55) * 0.9
    lfo = 0.65 + 0.35 * (S.sine(dur, 0.055) * 0.5 + 0.5)
    sub *= S.fit(lfo, len(sub))
    air = S.bandpass(S.pink(dur, 62), 480, 0.8) * 0.16
    air *= S.fit(0.6 + 0.4 * (S.sine(dur, 0.031, 1.1) * 0.5 + 0.5), len(air))
    x = S.fit(sub, n) + S.fit(air, n)
    # plaintes de la structure : résonances lentes, désaccordées
    for k, (f, at) in enumerate(((77.0, 2.4), (116.5, 7.9), (61.3, 12.8), (154.0, 15.1))):
        d = 3.4
        g = S.resonator(S.white(d, 70 + k) * 0.012, f, 0.9, 1.0)
        g *= S.env_curve(d, [(0, 0), (0.25, 1.0), (1, 0)])
        p = int(at * SR)
        seg = x[p:p + len(g)]
        x[p:p + len(seg)] += S.fit(g, len(seg)) * 0.55
    return S.normalize(S.loopable(S.reverb(x, 0.9, 0.30, 13), 0.9), 0.55)


def creak(seed):
    """Craquement de charpente : friction bois sur bois, par saccades."""
    dur = 1.6 + (seed % 3) * 0.5
    n = int(dur * SR)
    r = np.random.default_rng(seed)
    f0 = 220 + r.random() * 320
    sweep = S.env_curve(dur, [(0, f0), (0.5, f0 * 1.5), (1, f0 * 1.2)])
    fric = S.bandpass(S.pink(dur, seed), sweep, 2.0)
    fric += S.bandpass(S.pink(dur, seed + 1), sweep * 2.2, 2.6) * 0.45
    fric += S.highpass(S.pink(dur, seed + 2), 2200) * 0.12
    mod = np.zeros(n, np.float32)
    t, i = 0.05, 0
    while t < dur * 0.82:
        a = int(t * SR)
        w = int((0.010 + r.random() * 0.026) * SR)
        seg = mod[a:a + w]
        if len(seg) > 1:
            mod[a:a + len(seg)] = np.hanning(len(seg)).astype(np.float32) * (0.5 + 0.5 * r.random())
        t += 0.030 + r.random() * 0.055 + i * 0.005
        i += 1
    mod = S.blur_env(mod, 0.005)
    shape = S.env_curve(dur, [(0, 0.3), (0.25, 1.0), (1, 0)])
    x = S.fit(fric, n) * S.fit(mod, n) * S.fit(shape, n)
    x += S.fit(S.noise_burst(dur, 95, 1.5, 0.55, seed + 3), n) * 0.18
    return S.normalize(S.reverb(x, 0.8, 0.36, seed + 5), 0.62)


def drip(seed):
    """Goutte : éclaboussure large bande, puis résonance de la flaque."""
    dur = 1.0
    n = int(dur * SR)
    x = S.fit(S.transient(0.03, 12000, seed, 0.8), n) * 0.45
    x += S.fit(S.noise_burst(0.08, 2600, 1.2, 0.012, seed + 1), n) * 0.55
    f = S.env_curve(0.13, [(0, 700), (1, 1600)])
    ring = S.sine(0.13, f) * S.env_curve(0.13, [(0, 0), (0.06, 1), (1, 0)])
    x += S.fit(ring, n) * 0.60
    return S.normalize(S.reverb(x, 1.1, 0.52, seed), 0.55)


# ==========================================================================
#  Interactions
# ==========================================================================
def door(kind, seed=80):
    if kind == "slam":
        dur = 1.2
        n = int(dur * SR)
        tr = S.transient(dur, 6000, seed, 1.4)
        body = S.thud(dur, 210, 0.12, seed + 1)
        body += S.thud(dur, 95, 0.19, seed + 2) * 0.85
        body += S.noise_burst(dur, 120, 0.7, 0.07, seed + 3) * 0.35
        modes = S.material_modes(tr, 96, 0.055, n=5, seed=seed + 4, tilt=0.40)
        rattle = S.crackle(dur, 90, seed + 4, 900, 4500, 0.22)
        x = (S.fit(tr, n) * 0.40 + S.fit(body, n) * 1.0
             + S.fit(modes, n) * 0.12 + S.fit(rattle, n) * 0.40)
        return S.normalize(S.reverb(S.saturate(x, 1.4), 0.9, 0.40, seed), 0.95)

    # --- grincement de gond : de la FRICTION, pas une glissade de notes ---
    # Le stick-slip module l'amplitude d'un bruit filtré dont la bande monte.
    # Une série de résonateurs produirait des sinusoïdes successives, ce qui
    # sonne synthétique.
    dur = 1.9 if kind == "open" else 1.45
    n = int(dur * SR)
    r = np.random.default_rng(seed)
    sweep = S.env_curve(dur, [(0, 380), (0.45, 780), (0.8, 1250), (1, 1150)])
    fric = S.bandpass(S.pink(dur, seed), sweep, 2.2)
    fric += S.bandpass(S.pink(dur, seed + 1), sweep * 2.55, 2.8) * 0.50
    fric += S.bandpass(S.pink(dur, seed + 2), sweep * 0.52, 1.6) * 0.35
    fric += S.highpass(S.pink(dur, seed + 3), 2600) * 0.14
    mod = np.zeros(n, np.float32)
    t = 0.02
    while t < dur * 0.80:
        a = int(t * SR)
        w = int((0.012 + r.random() * 0.020) * SR)
        seg = mod[a:a + w]
        if len(seg) > 1:
            mod[a:a + len(seg)] = np.hanning(len(seg)).astype(np.float32) * (0.55 + 0.45 * r.random())
        t += 0.028 + r.random() * 0.045
    mod = S.blur_env(mod, 0.004)
    shape = S.env_curve(dur, [(0, 0.5), (0.2, 1.0), (0.85, 0.5), (1, 0)])
    x = S.fit(fric, n) * S.fit(mod, n) * S.fit(shape, n)
    x += S.fit(S.noise_burst(dur, 140, 1.6, 0.5, seed + 7), n) * 0.16

    if kind == "close":
        p = int(dur * 0.82 * SR)
        tr = S.transient(0.35, 5000, seed + 9, 1.2)
        clack = S.fit(tr, int(0.35 * SR)) * 0.5 + S.noise_burst(0.35, 190, 1.3, 0.06, seed + 10)
        seg = x[p:p + len(clack)]
        x[p:p + len(seg)] += S.fit(clack, len(seg)) * 1.1
    return S.normalize(S.reverb(x, 0.8, 0.34, seed + 2), 0.78)


def locker(kind, seed=90):
    """Tôle mince : dense et inharmonique, portée par un corps bruité."""
    dur = 0.95
    n = int(dur * SR)
    tr = S.transient(dur, 9000, seed, 1.1)
    body = S.noise_burst(dur, 330, 1.2, 0.10, seed + 1)
    body += S.noise_burst(dur, 1150, 0.9, 0.06, seed + 2) * 0.55
    body += S.noise_burst(dur, 2600, 0.8, 0.035, seed + 3) * 0.32
    modes = S.material_modes(tr, 305, 0.16, n=7, seed=seed + 4, tilt=0.68)
    x = S.fit(tr, n) * 0.32 + S.fit(body, n) * 1.0 + S.fit(modes, n) * 0.38
    if kind == "open":
        sq = S.bandpass(S.pink(0.55, seed + 5),
                        S.env_curve(0.55, [(0, 760), (1, 2100)]), 8.0)
        sq *= S.env_curve(0.55, [(0, 0), (0.3, 0.45), (1, 0)])
        x += S.fit(sq, n) * 0.55
    return S.normalize(S.reverb(S.saturate(x, 1.2), 0.6, 0.32, seed), 0.80)


def pickup(kind, seed=100):
    dur = 0.55
    n = int(dur * SR)
    tr = S.transient(dur, 11000, seed, 0.9)
    if kind == "fuse":          # porcelaine et laiton : bref et clair
        body = S.noise_burst(dur, 1750, 1.1, 0.055, seed + 1)
        body += S.noise_burst(dur, 3600, 0.9, 0.030, seed + 2) * 0.5
        modes = S.material_modes(tr, 1680, 0.075, n=4, seed=seed + 3, tilt=0.5)
        mg = 0.34
    else:                       # pile : métal sourd
        body = S.noise_burst(dur, 700, 1.3, 0.045, seed + 1)
        body += S.noise_burst(dur, 1500, 1.0, 0.025, seed + 2) * 0.4
        modes = S.material_modes(tr, 690, 0.05, n=4, seed=seed + 3, tilt=0.45)
        mg = 0.22
    cloth = S.bandpass(S.pink(dur, seed + 4), 3800, 0.9)
    cloth *= S.env_curve(dur, [(0, 0), (0.22, 0.30), (0.8, 0.08), (1, 0)])
    x = S.fit(tr, n) * 0.30 + S.fit(body, n) * 1.0 + S.fit(modes, n) * mg + S.fit(cloth, n) * 0.40
    return S.normalize(S.reverb(x, 0.4, 0.20, seed), 0.72)


def click_flashlight():
    """Interrupteur : deux claquements secs, large bande. Aucune note."""
    dur = 0.22
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    for off, g, br in ((0.000, 1.0, 12000), (0.013, 0.45, 7000)):
        c = S.transient(0.08, br, 111 + int(off * 1000), 1.0)
        c = c + S.noise_burst(0.08, 2400, 1.0, 0.008, 112 + int(off * 1000)) * 0.6
        a = int(off * SR)
        seg = x[a:a + len(c)]
        x[a:a + len(seg)] += S.fit(c, len(seg)) * g
    x += S.fit(S.noise_burst(dur, 620, 1.4, 0.020, 113), n) * 0.35
    return S.normalize(S.reverb(x, 0.25, 0.16, 11), 0.62)


def fuse_insert():
    """Frottement de la porcelaine dans les griffes, puis verrouillage."""
    dur = 1.0
    n = int(dur * SR)
    sc = S.bandpass(S.pink(0.38, 121), S.env_curve(0.38, [(0, 1100), (1, 3000)]), 3.5)
    sc *= S.env_curve(0.38, [(0, 0), (0.25, 0.55), (1, 0.08)])
    x = S.fit(sc, n)
    x += S.fit(S.crackle(0.38, 220, 122, 2000, 9000, 0.30), n) * 0.25
    p = int(0.40 * SR)
    tr = S.transient(0.45, 7000, 123, 1.1)
    lock = S.fit(tr, int(0.45 * SR)) * 0.45 + S.noise_burst(0.45, 640, 1.2, 0.045, 124)
    lock += S.material_modes(tr, 620, 0.05, n=4, seed=125, tilt=0.45) * 0.28
    seg = x[p:p + len(lock)]
    x[p:p + len(seg)] += S.fit(lock, len(seg)) * 1.15
    return S.normalize(S.reverb(x, 0.5, 0.26, 12), 0.82)


def power_on():
    """Le courant revient : claquement de contacteur, puis ronflement 50 Hz."""
    dur = 3.5
    n = int(dur * SR)
    tr = S.transient(dur, 8000, 131, 1.5)
    x = S.fit(tr, n) * 0.5
    x += S.fit(S.noise_burst(dur, 110, 1.3, 0.11, 132), n) * 1.0
    x += S.fit(S.material_modes(tr, 132, 0.09, n=5, seed=133, tilt=0.5), n) * 0.25
    hum = (S.sine(dur, 50) * 0.55 + S.sine(dur, 100) * 0.26 + S.sine(dur, 150) * 0.13
           + S.sine(dur, 250) * 0.06)
    hum *= S.env_curve(dur, [(0, 0), (0.06, 0.0), (0.13, 0.9), (0.3, 0.6), (1, 0.5)])
    hum += S.bandpass(S.pink(dur, 134), 1200, 1.2) * 0.10       # souffle du ballast
    for at in (0.30, 0.44, 0.52, 0.78, 0.95, 1.35):             # amorçage des tubes
        p = int(at * SR)
        z = S.crackle(0.12, 700, int(at * 1000), 2500, 12000, 0.035) * 0.8
        seg = x[p:p + len(z)]
        x[p:p + len(seg)] += S.fit(z, len(seg))
    x += S.fit(hum, n) * 0.45
    return S.normalize(S.reverb(S.saturate(x, 1.3), 0.8, 0.28, 13), 0.85)


# ==========================================================================
#  La Veilleuse
# ==========================================================================
def entity_rasp(dur=6.0):
    """Sa respiration : un râle humide, irrégulier. Signal de proximité."""
    parts = []
    for i in range(5):
        d = 0.55 + (i % 3) * 0.14
        b = _breath(d, 130, 620, 1.4,
                    [(0, 0), (0.18, 0.9), (0.55, 0.7), (1, 0.05)],
                    200 + i * 5, voiced=0.45, rasp=1.2)
        # glaires : modulation par un bruit lent
        mod = S.fit(0.55 + 0.45 * S.lowpass(S.white(d, 300 + i), 28), len(b))
        parts.append(b * mod)
        parts.append(np.zeros(int((0.16 + (i % 2) * 0.13) * SR), np.float32))
    x = np.concatenate(parts)
    x = S.pitch_shift_naive(x, 0.82)          # descendu : plus grand que nature
    x = S.lowpass(x, 1500, 0.8)               # la saturation avait rendu le râle sifflant
    return S.normalize(S.loopable(S.reverb(x, 0.75, 0.34, 17), 0.18), 0.78)


def entity_scream():
    """Cri de détection — le moment où elle vous localise."""
    dur = 2.0
    n = int(dur * SR)
    f0 = S.env_curve(dur, [(0, 150), (0.06, 780), (0.25, 620), (0.7, 410), (1, 190)])
    v = np.zeros(n, np.float32)
    for h, g in ((1, 1.0), (2, 0.62), (3, 0.45), (4, 0.28), (5, 0.2), (7, 0.12), (9, 0.08)):
        v += S.fit(S.sine(dur, f0 * h), n) * g
    v *= S.env_curve(dur, [(0, 0), (0.04, 1.0), (0.45, 0.75), (1, 0)])
    v = S.saturate(v * 1.3, 3.2)
    # composante bruitée : les cordes vocales déchirées
    nz = S.bandpass(S.white(dur, 211), S.env_curve(dur, [(0, 2600), (1, 900)]), 1.2)
    nz *= S.env_curve(dur, [(0, 0), (0.05, 0.8), (0.6, 0.35), (1, 0)])
    x = v * 0.7 + S.fit(nz, n) * 0.42
    x = S.lowpass(x, 3400, 0.7)               # garde la puissance, retire la stridence
    return S.normalize(S.reverb(x, 1.2, 0.45, 19), 0.98)


def jumpscare():
    """Mort du joueur : impact massif puis cluster dissonant."""
    dur = 2.8
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    for f in (58, 61.5, 87, 116, 123, 174, 233, 247):
        x += S.fit(S.sine(dur, f), n) * (0.85 / 8)
    x *= S.env_curve(dur, [(0, 1.0), (0.12, 0.8), (1, 0)])
    tr = S.transient(dur, 12000, 221, 1.8)
    x += S.fit(tr, n) * 0.55
    x += S.fit(S.noise_burst(dur, 62, 1.3, 0.30, 222), n) * 1.25
    x += S.fit(S.noise_burst(dur, 210, 1.0, 0.12, 223), n) * 0.55
    x += S.fit(S.material_modes(tr, 74, 0.22, n=6, seed=224, tilt=0.6), n) * 0.30
    x += S.fit(S.crackle(dur, 260, 225, 1500, 11000, 0.18), n) * 0.30
    return S.normalize(S.reverb(S.saturate(x, 2.0), 1.0, 0.40, 23), 0.99)


def stinger_detect():
    """Sting d'investigation : dissonance courte, mais texturée."""
    dur = 1.7
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    for fq, g in ((146.8, 1.0), (155.6, 0.85), (207.7, 0.5), (311.1, 0.28)):
        v = S.sine(dur, fq * (1.0 + 0.0022 * S.fit(S.lowpass(S.white(dur, int(fq)), 4), n)))
        x += S.fit(v, n) * g
    x *= S.env_curve(dur, [(0, 0), (0.015, 1.0), (0.25, 0.42), (1, 0)])
    bow = S.bandpass(S.pink(dur, 232), 2100, 2.2)
    bow *= S.env_curve(dur, [(0, 0), (0.04, 0.7), (0.4, 0.25), (1, 0)])
    x += S.fit(bow, n) * 0.45
    x += S.fit(S.noise_burst(dur, 90, 1.4, 0.22, 233), n) * 0.35
    x += S.fit(S.transient(dur, 9000, 234, 0.8), n) * 0.22
    return S.normalize(S.reverb(S.saturate(x, 1.2), 0.9, 0.36, 29), 0.88)


def music_chase(dur=12.0):
    """Boucle de traque : pulsation grave + cordes dissonantes qui montent."""
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    # pulsation à 138 bpm
    per = 60.0 / 138.0
    t = 0.0
    i = 0
    while t < dur:
        p = int(t * SR)
        h = _thump(41 if i % 4 else 36, 0.26, 1.0 if i % 2 == 0 else 0.62)
        seg = x[p:p + len(h)]
        x[p:p + len(seg)] += S.fit(h, len(seg)) * 0.85
        t += per
        i += 1
    # nappe : seconde mineure, la dissonance la plus anxiogène
    for f, g in ((87.3, 0.55), (92.5, 0.50), (174.6, 0.28), (185.0, 0.24)):
        v = S.fit(S.sine(dur, f * (1.0 + 0.0016 * S.fit(S.lowpass(S.white(dur, int(f)), 3), n))), n)
        x += v * g * 0.42
    # archet : bruit filtré qui enfle
    bow = S.bandpass(S.pink(dur, 241), 1400, 3.0)
    bow *= S.fit(0.25 + 0.75 * (S.sine(dur, 1.0 / 6.0) * 0.5 + 0.5), n)
    x += S.fit(bow, n) * 0.22
    return S.normalize(S.loopable(S.reverb(x, 0.8, 0.28, 31), 0.5), 0.72)


def ui_sound(kind):
    """Interface : des claquements feutrés, jamais des notes."""
    dur = 0.28
    n = int(dur * SR)
    f = 480 if kind == "move" else 300
    tr = S.transient(dur, 6000 if kind == "move" else 3500, 251, 0.7)
    x = S.fit(tr, n) * 0.35
    x += S.fit(S.thud(dur, f * 3.0, 0.030, 252), n) * 1.0
    x += S.fit(S.noise_burst(dur, f * 1.6, 0.7, 0.016, 253), n) * 0.45
    if kind == "select":
        x += S.fit(S.thud(dur, f * 1.4, 0.060, 254), n) * 0.60
    return S.normalize(S.reverb(x, 0.35, 0.22, 33), 0.55)


# ==========================================================================
BANK = {
    "breath_calm":      breath_calm,
    "breath_winded":    breath_winded,
    "breath_hold":      breath_hold,
    "gasp":             gasp,
    "heart_slow":       lambda: heartbeat(58, 0.85),
    "heart_fast":       lambda: heartbeat(126, 1.15),
    "amb_drone":        amb_drone,
    "entity_rasp":      entity_rasp,
    "entity_scream":    entity_scream,
    "jumpscare":        jumpscare,
    "stinger_detect":   stinger_detect,
    "music_chase":      music_chase,
    "door_open":        lambda: door("open", 81),
    "door_close":       lambda: door("close", 83),
    "door_slam":        lambda: door("slam", 85),
    "locker_open":      lambda: locker("open", 91),
    "locker_close":     lambda: locker("close", 93),
    "pickup_fuse":      lambda: pickup("fuse", 101),
    "pickup_battery":   lambda: pickup("battery", 103),
    "flashlight_click": click_flashlight,
    "fuse_insert":      fuse_insert,
    "power_on":         power_on,
    "ui_move":          lambda: ui_sound("move"),
    "ui_select":        lambda: ui_sound("select"),
}
for _i in range(4):
    BANK[f"step_lino_{_i+1}"] = (lambda i: (lambda: step("lino", 500 + i * 7)))(_i)
    BANK[f"step_concrete_{_i+1}"] = (lambda i: (lambda: step("concrete", 600 + i * 7)))(_i)
for _i in range(3):
    BANK[f"step_entity_{_i+1}"] = (lambda i: (lambda: step("entity", 700 + i * 11)))(_i)
    BANK[f"creak_{_i+1}"] = (lambda i: (lambda: creak(800 + i * 13)))(_i)
    BANK[f"drip_{_i+1}"] = (lambda i: (lambda: drip(900 + i * 17)))(_i)


def main():
    import time
    only = sys.argv[1:] or None
    os.makedirs(OUT, exist_ok=True)
    tot = 0
    for name, fn in BANK.items():
        if only and name not in only:
            continue
        t = time.time()
        x = fn()
        p = S.write_wav(os.path.join(OUT, name + ".wav"), x)
        sz = os.path.getsize(p)
        tot += sz
        print(f"  {name:<18} {len(x)/SR:5.2f}s  {sz/1024:7.1f} KB  "
              f"pic={float(np.abs(x).max()):.2f}  ({time.time()-t:.1f}s)")
    print(f"  total {tot/1024/1024:.1f} MB")


if __name__ == "__main__":
    main()
