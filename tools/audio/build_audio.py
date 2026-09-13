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
    f = S.env_curve(dur, [(0, f0 * 2.3), (0.10, f0), (1, f0 * 0.72)])
    x = S.sine(dur, f) * S.env_curve(dur, [(0, 0), (0.012, 1), (0.35, 0.42), (1, 0)])
    x += S.lowpass(S.white(dur, 55) * 0.20, 180) * S.env_curve(dur, [(0, 1), (0.15, 0.1), (1, 0)])
    return S.saturate(x * punch, 1.6)


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
    return S.normalize(S.loopable(x, 0.04), 0.80)


# ==========================================================================
#  Pas
# ==========================================================================
def step(kind, seed):
    """Un pas = transient large bande + corps résonant + traînée de gravier."""
    dur = 0.34
    n = int(dur * SR)
    r = np.random.default_rng(seed)
    if kind == "lino":
        body_f, body_d, bright, grit = 190 + r.random() * 60, 0.030, 2600, 0.16
    elif kind == "concrete":
        body_f, body_d, bright, grit = 130 + r.random() * 45, 0.022, 4200, 0.42
    else:  # entité : pas lourd, traînant, humide
        body_f, body_d, bright, grit = 68 + r.random() * 22, 0.075, 1500, 0.55
    imp = S.white(dur, seed) * S.env_curve(dur, [(0, 1), (0.010, 0.30), (0.09, 0.04), (1, 0)])
    x = S.resonator(imp, body_f, body_d, 1.0)
    x += S.resonator(imp, body_f * 2.7, body_d * 0.5, 0.34)
    x += S.resonator(imp, body_f * 5.1, body_d * 0.25, 0.14)
    # l'attaque garde un peu de tranchant, sans dominer le corps
    x += S.lowpass(S.highpass(imp, 900), bright) * 0.16
    # frottement de la semelle
    drag = S.bandpass(S.pink(dur, seed + 100), 1500, 1.0)
    drag *= S.env_curve(dur, [(0, 0.0), (0.05, grit * 0.45), (0.45, grit * 0.16), (1, 0)])
    x = S.fit(x, n) + S.fit(drag, n)
    if kind == "entity":
        # traînement : un second frottement décalé, plus grave
        sl = S.bandpass(S.pink(dur, seed + 200), 620, 1.0)
        sl *= S.env_curve(dur, [(0, 0), (0.35, 0.5), (1, 0)])
        x += S.fit(sl, n) * 0.8
    return S.normalize(S.reverb(x, 0.45, 0.26, seed), 0.80)


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
    """Craquement de charpente : frottement bois/bois par saccades."""
    dur = 1.5 + (seed % 3) * 0.5
    n = int(dur * SR)
    r = np.random.default_rng(seed)
    x = np.zeros(n, np.float32)
    f0 = 180 + r.random() * 260
    # stick-slip : une série d'impulsions de plus en plus espacées
    t, i = 0.05, 0
    while t < dur * 0.8:
        p = int(t * SR)
        g = S.resonator(S.white(0.14, seed + i) * 0.30, f0 * (1 + i * 0.045), 0.045, 1.0)
        seg = x[p:p + len(g)]
        x[p:p + len(seg)] += S.fit(g, len(seg)) * (0.9 - i * 0.05)
        t += 0.035 + r.random() * 0.055 + i * 0.006
        i += 1
    return S.normalize(S.reverb(x, 0.8, 0.38, seed + 5), 0.62)


def drip(seed):
    """Goutte d'eau dans une cave — résonance montante caractéristique."""
    dur = 0.9
    f = S.env_curve(0.10, [(0, 620), (1, 1450)])
    x = S.fit(S.sine(0.10, f) * S.env_curve(0.10, [(0, 1), (1, 0)]), int(dur * SR))
    x += S.fit(S.highpass(S.white(0.02, seed), 3000) * 0.3, int(dur * SR))
    return S.normalize(S.reverb(x, 1.1, 0.55, seed), 0.55)


# ==========================================================================
#  Interactions
# ==========================================================================
def door(kind, seed=80):
    if kind == "slam":
        dur = 1.1
        imp = S.white(dur, seed) * S.env_curve(dur, [(0, 1), (0.006, 0.2), (0.05, 0.02), (1, 0)])
        x = S.resonator(imp, 78, 0.10, 1.0) * 1.6 + S.resonator(imp, 165, 0.05, 0.7)
        x += S.lowpass(imp, 300) * 0.8
        return S.normalize(S.reverb(x, 0.9, 0.42, seed), 0.95)
    # grincement de gond : stick-slip lent, hauteur qui monte
    dur = 1.8 if kind == "open" else 1.35
    n = int(dur * SR)
    r = np.random.default_rng(seed)
    x = np.zeros(n, np.float32)
    t, i = 0.02, 0
    while t < dur * 0.72:
        p = int(t * SR)
        f = 420 + i * 38 + r.random() * 60
        g = S.resonator(S.white(0.18, seed + i) * 0.22, f, 0.055, 1.0)
        g += S.resonator(S.white(0.18, seed + i + 50) * 0.10, f * 2.4, 0.03, 1.0)
        seg = x[p:p + len(g)]
        x[p:p + len(seg)] += S.fit(g, len(seg)) * (0.55 + 0.45 * math.sin(i * 0.7))
        t += 0.030 + r.random() * 0.045
        i += 1
    # claquement final du pêne
    if kind == "close":
        p = int(dur * 0.80 * SR)
        cl = S.resonator(S.white(0.25, seed + 9) * 0.6, 210, 0.035, 1.0)
        seg = x[p:p + len(cl)]
        x[p:p + len(seg)] += S.fit(cl, len(seg)) * 1.2
    return S.normalize(S.reverb(x, 0.8, 0.36, seed + 2), 0.78)


def locker(kind, seed=90):
    dur = 0.85
    n = int(dur * SR)
    imp = S.white(dur, seed) * S.env_curve(dur, [(0, 1), (0.005, 0.25), (0.06, 0.03), (1, 0)])
    # tôle mince : plusieurs modes hauts et désaccordés
    x = np.zeros(n, np.float32)
    for f, d, g in ((310, 0.22, 1.0), (487, 0.18, 0.7), (763, 0.13, 0.5),
                    (1180, 0.09, 0.35), (1890, 0.06, 0.22)):
        x += S.fit(S.resonator(imp, f, d, g), n)
    if kind == "open":
        sq = S.bandpass(S.pink(0.5, seed + 3), S.env_curve(0.5, [(0, 700), (1, 1900)]), 6.0)
        x += S.fit(sq * S.env_curve(0.5, [(0, 0), (0.3, 0.5), (1, 0)]), n) * 0.7
    return S.normalize(S.reverb(x, 0.6, 0.34, seed), 0.80)


def pickup(kind, seed=100):
    dur = 0.5
    n = int(dur * SR)
    if kind == "fuse":      # porcelaine + laiton
        fs = ((1650, 0.13, 1.0), (2480, 0.10, 0.6), (3720, 0.07, 0.35))
    else:                   # pile : métal sourd
        fs = ((720, 0.09, 1.0), (1130, 0.06, 0.5), (1960, 0.04, 0.25))
    imp = S.white(dur, seed) * S.env_curve(dur, [(0, 1), (0.004, 0.2), (0.03, 0.02), (1, 0)])
    x = np.zeros(n, np.float32)
    for f, d, g in fs:
        x += S.fit(S.resonator(imp, f, d, g), n)
    # froissement du tissu de la poche
    x += S.fit(S.bandpass(S.pink(dur, seed + 1), 3600, 1.0)
               * S.env_curve(dur, [(0, 0), (0.25, 0.25), (1, 0)]), n)
    return S.normalize(S.reverb(x, 0.4, 0.22, seed), 0.72)


def click_flashlight():
    dur = 0.18
    n = int(dur * SR)
    imp = S.white(dur, 111) * S.env_curve(dur, [(0, 1), (0.0015, 0.1), (0.01, 0), (1, 0)])
    x = S.fit(S.resonator(imp, 2300, 0.020, 1.0), n)
    x += S.fit(S.resonator(imp, 4100, 0.012, 0.5), n)
    return S.normalize(S.reverb(x, 0.25, 0.18, 11), 0.62)


def fuse_insert():
    dur = 0.9
    n = int(dur * SR)
    sc = S.bandpass(S.pink(0.35, 121), S.env_curve(0.35, [(0, 900), (1, 2600)]), 3.0)
    sc *= S.env_curve(0.35, [(0, 0), (0.3, 0.6), (1, 0.1)])
    x = S.fit(sc, n)
    p = int(0.36 * SR)
    imp = S.white(0.4, 122) * S.env_curve(0.4, [(0, 1), (0.004, 0.2), (0.03, 0), (1, 0)])
    lock = S.resonator(imp, 640, 0.09, 1.0) + S.resonator(imp, 1290, 0.05, 0.5)
    seg = x[p:p + len(lock)]
    x[p:p + len(seg)] += S.fit(lock, len(seg)) * 1.2
    return S.normalize(S.reverb(x, 0.5, 0.28, 12), 0.82)


def power_on():
    """Le courant revient : claquement de contacteur puis ronflement 50 Hz."""
    dur = 3.4
    n = int(dur * SR)
    imp = S.white(dur, 131) * S.env_curve(dur, [(0, 1), (0.004, 0.25), (0.04, 0.02), (1, 0)])
    x = S.fit(S.resonator(imp, 95, 0.16, 1.0) * 1.4, n)
    hum = (S.sine(dur, 50) * 0.55 + S.sine(dur, 100) * 0.28 + S.sine(dur, 150) * 0.14)
    hum *= S.env_curve(dur, [(0, 0), (0.06, 0.0), (0.13, 0.9), (0.3, 0.6), (1, 0.5)])
    # amorçage des tubes fluorescents
    for at in (0.30, 0.44, 0.52, 0.78, 0.95, 1.35):
        p = int(at * SR)
        z = S.highpass(S.white(0.09, int(at * 1000)), 2200) * 0.55
        z *= S.env_curve(0.09, [(0, 1), (1, 0)])
        seg = x[p:p + len(z)]
        x[p:p + len(seg)] += S.fit(z, len(seg))
    x += S.fit(hum, n) * 0.45
    return S.normalize(S.reverb(x, 0.8, 0.30, 13), 0.85)


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
    """Mort du joueur : cluster dissonant + impact."""
    dur = 2.6
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    for f in (58, 61.5, 87, 116, 123, 174, 233, 247):
        x += S.fit(S.sine(dur, f), n) * (0.9 / 8)
    x *= S.env_curve(dur, [(0, 1.0), (0.12, 0.85), (1, 0)])
    imp = S.white(dur, 221) * S.env_curve(dur, [(0, 1), (0.008, 0.3), (0.06, 0.05), (1, 0)])
    x += S.fit(S.resonator(imp, 62, 0.22, 1.0), n) * 1.6
    x += S.fit(S.highpass(imp, 4000), n) * 0.5
    x = S.saturate(x, 2.2)
    return S.normalize(S.reverb(x, 1.0, 0.40, 23), 0.99)


def stinger_detect():
    """Sting court quand elle passe en investigation."""
    dur = 1.6
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    for f, g in ((146.8, 1.0), (155.6, 0.85), (207.7, 0.5), (311.1, 0.3)):
        x += S.fit(S.sine(dur, f), n) * g
    x *= S.env_curve(dur, [(0, 0), (0.015, 1.0), (0.25, 0.45), (1, 0)])
    x += S.fit(S.highpass(S.white(dur, 231), 5000)
               * S.env_curve(dur, [(0, 0.5), (0.08, 0), (1, 0)]), n) * 0.4
    return S.normalize(S.reverb(x, 0.9, 0.38, 29), 0.88)


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
    dur = 0.25
    n = int(dur * SR)
    f = 320 if kind == "move" else 220
    imp = S.white(dur, 251) * S.env_curve(dur, [(0, 1), (0.003, 0.15), (0.02, 0), (1, 0)])
    x = S.fit(S.resonator(imp, f, 0.10, 1.0), n)
    if kind == "select":
        x += S.fit(S.resonator(imp, f * 1.5, 0.14, 0.6), n)
    return S.normalize(S.reverb(x, 0.35, 0.24, 33), 0.55)


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
