#!/usr/bin/env python3
"""
build_audio — bande-son de RESPIRE.

Approche mixte, assumée :

* Les sons du monde physique — respiration, pas, portes, tôle, ambiance,
  cri — proviennent d'ENREGISTREMENTS sous CC0 (voir tools/audio/sources.py
  et docs/CREDITS_AUDIO.md). Une percussion synthétisée trahit toujours son
  origine : un impact réel porte des milliers de modes désaccordés qu'aucune
  recette raisonnable ne reproduit.
* Restent synthétisés les sons qui n'existent pas à l'état d'enregistrement
  (l'apnée : il n'y a par définition rien à capter) ou qui sont musicaux par
  nature (nappe de traque, sting, remise sous tension).

Tout ce qui est positionné dans le monde est rendu en MONO : un flux stéréo
confié à un AudioStreamPlayer3D ne se spatialise pas, et le joueur perdrait
la direction d'un bruit — ce qui casserait le jeu.
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import synth as S
import sfx
import sources

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "assets", "audio")
SR = S.SR
rng = np.random.default_rng(4242)


def P(key, *rest):
    return sources.path(key, *rest)


OW = lambda *r: P("owlish", *r)
WM = lambda f: P("woodmetal", f)
FZ = lambda f: P("fantozzi", "Fantozzi-footsteps", "flac", f + ".flac")
GH = lambda f: P("ghost", "qubodup-GhostMoans", "wav", f)


# ==========================================================================
#  Respiration — le son central du jeu
# ==========================================================================
def breath_calm():
    """Souffle au repos. Boucle longue, prise là où le fondu est inaudible."""
    x = sfx.trim(sfx.load(OW("Human", "breath-male.wav")))
    x = sfx.best_loop(x, 6.0, t_min=1.5, fade=0.30)
    x = sfx.tilt(x, low_db=+2.0, high_db=-3.0)      # plus près, moins sifflant
    return sfx.norm(sfx.room(x, 0.30, 0.10, 3), 0.60)


def breath_winded():
    """Essoufflement : c'est cette boucle qui trahit le joueur."""
    x = sfx.trim(sfx.load(OW("Human", "scared-breathing.wav")))
    x = sfx.best_loop(x, 4.2, t_min=1.0, fade=0.16)
    x = sfx.tilt(x, low_db=+1.5, high_db=-1.0)
    return sfx.norm(sfx.room(x, 0.28, 0.12, 5), 0.88)


def gasp():
    """Halètement forcé : le pic sonore le plus fort du jeu."""
    x = sfx.trim(sfx.load(OW("Human", "gasp1.wav")))
    x = sfx.fade(x[:int(1.9 * SR)], 3.0, 260.0)
    x = sfx.mix((x, 1.0),
                (sfx.fade(sfx.trim(sfx.load(OW("Human", "freakedbreath.wav"))), 4, 120), 0.55))
    return sfx.norm(sfx.room(x, 0.60, 0.30, 7), 0.97)


# ==========================================================================
#  Rythme cardiaque
# ==========================================================================
def heart(fast):
    f = "heartbeat_fast_0.wav" if fast else "heartbeat_slow_0.wav"
    x = sfx.load(os.path.join(sources.CACHE, f))
    # perçu à travers la cage thoracique : très sourd
    x = sfx.tilt(x, low_db=+4.0, high_db=-14.0, pivot=200.0)
    x = S.lowpass(x, 320, 0.7)
    # le sample d'origine est une sinusoïde de synthèse : on lui ajoute un
    # corps bruité pour qu'il sonne comme un muscle et non comme un bip
    d = len(x) / SR
    env = np.abs(S.lowpass(np.abs(x), 12, 0.7))
    env /= (env.max() + 1e-9)
    body = S.thud(d, 150, 0.055, 31, slope=2.0) * 0.0
    body = S.lowpass(S.white(d, 31), 210, 0.6)
    x = sfx.mix((x, 1.0), (S.fit(body, len(x)) * S.fit(env, len(x)), 0.55))
    return sfx.norm(S.loopable(x, 0.03), 0.80)


# ==========================================================================
#  Pas
# ==========================================================================
LINO = ["hard-footstep1.wav", "hard-footstep2.wav", "hard-footstep3.wav", "hard-footstep4.wav"]
STONE = ["Fantozzi-StoneL1", "Fantozzi-StoneR1", "Fantozzi-StoneL2", "Fantozzi-StoneR2"]


def step_lino(i):
    """Semelle dure sur linoléum, dans un couloir carrelé."""
    x = sfx.trim(sfx.load(OW("Footsteps", LINO[i])), tail_ms=240)
    x = sfx.tilt(x, low_db=+2.5, high_db=-2.0)
    x = sfx.pitch(x, 0.97 + 0.03 * i)
    return sfx.norm(sfx.room(x, 0.52, 0.28, 500 + i), 0.80)


def step_concrete(i):
    """Pas sur pierre, aile technique."""
    x = sfx.trim(sfx.load(FZ(STONE[i])), tail_ms=240)
    x = sfx.tilt(x, low_db=+1.5, high_db=-0.5)
    x = sfx.pitch(x, 0.95 + 0.04 * i)
    return sfx.norm(sfx.room(x, 0.55, 0.30, 600 + i), 0.80)


def step_eau(i):
    """Pas dans l'eau stagnante.

    Le pas lui-même est ÉTOUFFÉ — l'eau amortit l'impact — et c'est
    l'éclaboussure qui porte. Faire l'inverse (un pas net plus une giclée)
    sonne comme deux sons superposés au lieu d'un seul geste.
    """
    sec = sfx.trim(sfx.load(OW("Footsteps", LINO[i])), tail_ms=200)
    sec = S.lowpass(sec, 900, 0.7)                       # noyé
    sec = sfx.pitch(sec, 0.94 + 0.03 * i)

    # gerbe : bande large qui s'effondre vers le grave
    n = len(sec)
    gerbe = S.bandpass(S.pink(n / SR, 300 + i * 7), 700, 0.9)
    gerbe *= S.env_curve(n / SR, [(0, 0), (0.02, 1.0), (0.18, 0.30), (0.55, 0.05), (1, 0)])
    # le « plouf » grave, qui donne la masse d'eau
    masse = S.thud(n / SR, 260, decay=0.06, seed=430 + i)
    # embruns : discrets. Mesure à l'appui — montés trop haut ils faisaient de
    # l'eau le son le PLUS brillant du jeu, plus que le verre brisé, ce qui est
    # l'inverse de ce qu'une flaque fait entendre.
    spray = S.bandpass(S.white(n / SR, 400 + i * 11), 3400, 2.4)
    spray *= S.env_curve(n / SR, [(0, 0), (0.05, 0.40), (0.30, 0.12), (1, 0)])

    x = sfx.mix((sec, 0.70), (gerbe, 0.95), (masse, 0.55), (spray, 0.14))
    x = sfx.tilt(x, low_db=+2.0, high_db=-4.0)
    return sfx.norm(sfx.room(x, 0.62, 0.34, 700 + i), 0.82)


def step_verre(i):
    """Pas sur verre brisé : l'impact, puis la centaine de petits éclats qui
    se replacent. C'est la QUEUE qui fait le bruit, pas le choc."""
    sec = sfx.trim(sfx.load(FZ(STONE[i])), tail_ms=220)
    sec = sfx.pitch(sec, 0.99 + 0.02 * i)
    n = len(sec)
    craq = S.crackle(n / SR, density=560 + i * 40, seed=800 + i, f_lo=3200, f_hi=12000,
                     decay=0.11)
    craq *= S.env_curve(n / SR, [(0, 0), (0.03, 1.0), (0.30, 0.45), (1, 0)])
    tinte = S.material_modes(S.transient(0.02, 6500, seed=810 + i), 3100, 0.22, n=5,
                             spread=1.9, seed=820 + i)
    tinte = S.fit(tinte, n)
    x = sfx.mix((sec, 0.55), (craq, 0.95), (tinte, 0.30))
    x = sfx.tilt(x, low_db=-5.0, high_db=+5.0)
    return sfx.norm(sfx.room(x, 0.58, 0.32, 760 + i), 0.86)


def step_entity(i):
    """
    La Veilleuse : le même pas descendu d'une octave, assombri, et traîné.
    Une démarche lourde se reconnaît à sa lenteur et à sa traîne, pas à son
    volume.
    """
    base = sfx.trim(sfx.load(FZ(STONE[i % len(STONE)])), tail_ms=300)
    low = sfx.pitch(base, 0.55 - 0.03 * i)          # plus grave ET plus long
    low = S.lowpass(low, 1400, 0.8)
    drag = S.bandpass(S.pink(len(low) / SR, 700 + i), 620, 0.9)
    drag *= S.env_curve(len(low) / SR, [(0, 0), (0.30, 0.45), (0.8, 0.15), (1, 0)])
    x = sfx.mix((low, 1.0), (drag, 0.42))
    return sfx.norm(sfx.room(x, 0.70, 0.34, 700 + i), 0.80)


# ==========================================================================
#  Ambiance
# ==========================================================================
def amb_drone():
    """Nappe souterraine, doublée d'une infra-basse de synthèse."""
    x = sfx.load(os.path.join(sources.CACHE, "dark_cavern_ambient_002.ogg"), mono=False)
    m = x.mean(1)
    m = sfx.best_loop(m, 24.0, t_min=6.0, t_max=80.0, fade=1.2)
    sub = S.lowpass(S.brown(len(m) / SR, 61), 48) * 0.55
    lfo = 0.6 + 0.4 * (S.sine(len(m) / SR, 0.047) * 0.5 + 0.5)
    x = sfx.mix((m, 1.0), (S.fit(sub, len(m)) * S.fit(lfo, len(m)), 0.8))
    return sfx.norm(S.loopable(x, 1.0), 0.58)


def creak(i):
    src = ["wood_squeak_01.ogg", "wood_cracking_02.ogg", "wood_squeak_02.ogg"][i]
    x = sfx.trim(sfx.load(WM(src)), tail_ms=400)
    x = sfx.pitch(x, 0.80 - 0.05 * i)               # une charpente, pas une chaise
    x = sfx.tilt(x, low_db=+2.0, high_db=-1.5, pivot=700.0)
    return sfx.norm(sfx.room(x, 0.85, 0.40, 800 + i), 0.62)


# ==========================================================================
#  Ouvrants et objets
# ==========================================================================
def door_open():
    a = sfx.trim(sfx.load(WM("door_open_01.ogg")), tail_ms=300)
    b = sfx.trim(sfx.load(WM("wood_squeak_02.ogg")), tail_ms=300)
    b = sfx.pitch(b, 0.72)
    x = sfx.mix((sfx.pitch(a, 0.88), 1.0), (b, 0.85))
    return sfx.norm(sfx.room(x, 0.80, 0.36, 81), 0.80)


def door_close():
    x = sfx.trim(sfx.load(WM("wood_close_02.ogg")), tail_ms=350)
    return sfx.norm(sfx.room(sfx.pitch(x, 0.90), 0.80, 0.36, 83), 0.80)


def door_slam():
    x = sfx.trim(sfx.load(WM("wood_slam_01.ogg")), tail_ms=400)
    # renfort grave sans hauteur : un choc passe-bas, pas une bande étroite
    x = sfx.mix((sfx.pitch(x, 0.93), 1.0),
                (S.thud(0.5, 420, 0.11, 85), 0.55),
                (S.crackle(0.5, 120, 86, 800, 5000, 0.16), 0.22))
    return sfx.norm(sfx.room(x, 0.95, 0.44, 85), 0.95)


def locker(open_):
    x = sfx.trim(sfx.load(WM("metal_open_01.ogg" if open_ else "metal_close_01.ogg")),
                 tail_ms=400)
    x = sfx.tilt(x, low_db=+2.0, high_db=-2.0)
    return sfx.norm(sfx.room(sfx.pitch(x, 0.93), 0.68, 0.34, 91), 0.82)


def pickup(fuse):
    x = sfx.trim(sfx.load(WM("metal_hit_05.ogg" if fuse else "misc_14.ogg")), tail_ms=260)
    cloth = sfx.trim(sfx.load(OW("Cloth, Rustle", "320138__owlstorm__blanket-movement-2.wav")))
    cloth = sfx.fade(cloth[:int(0.35 * SR)], 8, 160)
    x = sfx.mix((x, 1.0), (cloth, 0.28))
    return sfx.norm(sfx.room(x, 0.42, 0.22, 101), 0.74)


def click_flashlight():
    x = sfx.trim(sfx.load(WM("metal_hit_01.ogg")), tail_ms=90)
    x = sfx.fade(sfx.pitch(x[:int(0.16 * SR)], 1.25), 1.0, 70.0)
    return sfx.norm(sfx.room(x, 0.26, 0.16, 11), 0.60)


def fuse_insert():
    x = sfx.trim(sfx.load(WM("lock_open_01.ogg")), tail_ms=300)
    return sfx.norm(sfx.room(sfx.pitch(x, 0.94), 0.50, 0.26, 12), 0.82)


def ui(select):
    src = "320141__owlstorm__blanket-movement-3.wav" if select else "320144__owlstorm__blanket-movement-6.wav"
    x = sfx.trim(sfx.load(OW("Cloth, Rustle", src)))
    x = sfx.fade(x[:int(0.30 * SR)], 4, 140)
    x = sfx.tilt(x, low_db=+1.0, high_db=-4.0)
    return sfx.norm(sfx.room(x, 0.30, 0.18, 33), 0.50)


# ==========================================================================
#  La Veilleuse
# ==========================================================================
def entity_rasp():
    """Râle bouclé : signal de proximité. Descendu bien en dessous d'une voix."""
    parts = []
    for i, f in enumerate(["qubodup-GhostMoan01.wav", "qubodup-GhostMoan03.wav",
                           "qubodup-GhostMoan05.wav"]):
        y = sfx.trim(sfx.load(GH(f)), tail_ms=260)
        parts.append(sfx.pitch(y, 0.70 - 0.04 * i))
        parts.append(np.zeros(int(0.35 * SR), np.float32))
    x = np.concatenate(parts)
    x = S.lowpass(x, 1700, 0.8)
    return sfx.norm(S.loopable(sfx.room(x, 0.80, 0.34, 17), 0.30), 0.76)


def entity_scream():
    """Cri de détection : cri humain descendu, doublé d'un râle."""
    a = sfx.pitch(sfx.trim(sfx.load(OW("Human", "SCREAM.wav"))), 0.74)
    a = sfx.fade(a[:int(2.4 * SR)], 2.0, 300.0)
    b = sfx.pitch(sfx.trim(sfx.load(GH("qubodup-GhostMoan02.wav"))), 0.62)
    b = sfx.fade(b[:int(2.6 * SR)], 60.0, 500.0)
    x = sfx.mix((a, 1.0), (b, 0.55))
    x = S.lowpass(x, 3600, 0.7)
    return sfx.norm(sfx.room(x, 1.20, 0.44, 19), 0.98)


def jumpscare():
    """Mort du joueur : cri au premier plan sur un impact de synthèse."""
    a = sfx.pitch(sfx.trim(sfx.load(OW("Human", "SCREAM.wav"))), 0.66)
    n = max(len(a), int(2.6 * SR))
    imp = S.transient(2.6, 12000, 221, 1.8) * 0.5
    imp += S.thud(2.6, 150, 0.30, 222, slope=2.0) * 1.2
    imp += S.crackle(2.6, 240, 225, 1500, 11000, 0.18) * 0.30
    x = sfx.mix((a, 1.0), (imp, 0.85))
    return sfx.norm(sfx.room(S.saturate(x, 1.5), 1.0, 0.40, 23), 0.99)
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



def stinger_lost():
    """Sting de perte de trace : la dissonance se dénoue.

    C'est le pendant exact de `stinger_detect`, et il manquait. Le sting de
    détection empile une seconde mineure sale (146.8 / 155.6 Hz) qui « serre » ;
    celui-ci part du même intervalle et le laisse GLISSER vers une quinte à vide
    (146.8 / 220.0), puis s'éteint. L'oreille entend une résolution, pas une
    nouvelle information : c'est le signal que l'on peut respirer.

    Volontairement plus long et plus sombre que la détection — un relâchement
    n'a pas à être saillant, il a à être reconnaissable.
    """
    dur = 2.6
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    # la note tenue ne bouge pas : c'est l'autre qui se dénoue autour d'elle
    for f0, f1, g in ((146.8, 146.8, 1.00),      # D3, pivot
                      (155.6, 146.8, 0.72),      # la seconde mineure se résorbe
                      (207.7, 220.0, 0.38),      # le triton glisse vers la quinte
                      (311.1, 293.7, 0.20)):
        env_f = S.env_curve(dur, [(0, f0), (0.45, f0 * 0.5 + f1 * 0.5), (1, f1)])
        v = S.sine(dur, S.fit(env_f, n))
        x += S.fit(v, n) * g
    # enveloppe d'expiration : attaque molle, longue traîne
    x *= S.env_curve(dur, [(0, 0), (0.10, 0.85), (0.34, 0.50), (1, 0)])
    # un souffle d'air qui retombe, par-dessus
    air = S.bandpass(S.pink(dur, 771), 620, 1.1)
    air *= S.env_curve(dur, [(0, 0), (0.07, 0.42), (0.5, 0.14), (1, 0)])
    x += S.fit(air, n) * 0.40
    # on ferme les aigus : la menace s'éloigne
    x = S.lowpass(x, 1750, 0.72)
    return S.normalize(S.reverb(x, 0.95, 0.44, 61), 0.72)



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




def _thump(f0, dur, punch):
    """Battement grave synthétisé, utilisé par la pulsation de la traque."""
    n = int(dur * SR)
    f = S.env_curve(dur, [(0, f0 * 2.4), (0.09, f0), (1, f0 * 0.68)])
    tone = S.sine(dur, f) * S.env_curve(dur, [(0, 0), (0.010, 1), (0.32, 0.38), (1, 0)])
    body = S.thud(dur, f0 * 1.9, 0.050, int(f0 * 7) % 9999, slope=2.0)
    body += S.thud(dur, f0 * 1.05, 0.090, int(f0 * 13) % 9999, slope=2.0) * 0.9
    x = S.fit(tone, n) * 0.34 + S.fit(body, n) * 1.0
    return S.saturate(x * punch, 1.5)



# ==========================================================================
#  Ambiance : ce que le sanatorium fait tout seul
# ==========================================================================
#  Le sous-sol n'avait qu'une seule nappe, et les gouttes et grincements déjà
#  construits n'étaient branchés nulle part. Un lieu silencieux n'est pas
#  inquiétant : il est vide. On lui donne donc trois couches — une nappe de
#  fond, des bruits isolés qui semblent venir d'ailleurs, et de rares nappes
#  musicales.
#
#  Rien de tout cela ne passe par NoiseBus : ces sons n'existent pas pour la
#  Veilleuse. Les faire entendre par elle voudrait dire qu'un grincement de
#  tuyau la dérange autant qu'un pas du joueur, et toute l'équité de la
#  mécanique s'effondrerait.

def amb_souffle():
    """Souffle du bâtiment : très grave, presque sous le seuil d'audition."""
    x = sfx.load(OW("Ambience", "earthquake.wav"))
    x = sfx.pitch(x, 0.55)                      # ralenti : le grondement s'étale
    x = sfx.best_loop(x, 12.0, t_min=1.0, fade=0.9)
    x = S.lowpass(x, 150.0, 0.6)
    return sfx.norm(sfx.room(x, 0.85, 0.30, 71), 0.55)


def amb_horloge():
    """Une horloge tourne encore, quelque part. Personne ne l'a remontée."""
    x = sfx.load(OW("Ambience", "loopable-ticking-clock.wav"))
    x = sfx.best_loop(x, 8.0, t_min=0.5, fade=0.25)
    x = sfx.tilt(x, low_db=-3.0, high_db=-11.0)  # étouffée par les cloisons
    return sfx.norm(sfx.room(x, 0.92, 0.55, 73), 0.42)


def _lointain(x, ampleur=0.95, humide=0.62, coupe=1500.0, seed=11):
    """Éloigne un son : la distance mange les aigus et ajoute la pièce."""
    x = S.lowpass(x, coupe, 0.7)
    return sfx.norm(sfx.room(x, ampleur, humide, seed), 0.80)


def peur_tole():
    """La tôle d'une gaine qui travaille. Long, grave, sans cause visible."""
    x = sfx.trim(sfx.load(WM("metal_sheet_03.ogg")))
    x = sfx.pitch(x, 0.42)
    return _lointain(x, 0.95, 0.58, 2200.0, 21)


def peur_claque():
    """Une porte claque, loin. Le joueur n'en a ouvert aucune."""
    x = sfx.trim(sfx.load(WM("wood_slam_02.ogg")))
    x = sfx.pitch(x, 0.78)
    return _lointain(x, 0.97, 0.70, 900.0, 22)


def peur_chute():
    """Quelque chose de métallique tombe, deux pièces plus loin."""
    x = sfx.trim(sfx.load(WM("metal_falling_01.ogg")))
    x = sfx.pitch(x, 0.68)
    return _lointain(x, 0.95, 0.60, 2600.0, 23)


def peur_toux():
    """Une toux dans le noir. Il n'y a personne d'autre que vous, ici."""
    x = sfx.trim(sfx.load(OW("Human", "cough2.wav")))
    x = sfx.pitch(x, 0.86)
    x = sfx.gain(x, -4.0)
    return _lointain(x, 0.93, 0.66, 2000.0, 24)


def peur_souffle():
    """Une respiration qui n'est pas la vôtre, et qui est près."""
    x = sfx.trim(sfx.load(OW("Human", "breath-female2.wav")))
    x = sfx.pitch(x, 0.74)
    x = sfx.tilt(x, low_db=+2.0, high_db=-6.0)
    return sfx.norm(sfx.room(x, 0.35, 0.16, 25), 0.62)


def peur_plainte():
    """Une plainte très lointaine. Peut-être elle. Peut-être pas."""
    x = sfx.trim(sfx.load(GH("qubodup-GhostMoan04.wav")))
    x = sfx.pitch(x, 0.80)
    x = sfx.gain(x, -6.0)
    return _lointain(x, 0.98, 0.74, 1100.0, 26)


def peur_grincement():
    """Une latte grince au-dessus. Il n'y a pas d'étage au-dessus."""
    x = sfx.trim(sfx.load(WM("wood_squeak_01.ogg")))
    x = sfx.pitch(x, 0.62)
    return _lointain(x, 0.90, 0.52, 3000.0, 27)


def peur_ressort():
    """Le sommier d'un lit se détend. Quelqu'un vient de se lever."""
    x = sfx.trim(sfx.load(WM("metal_spring_01.ogg")))
    x = sfx.pitch(x, 0.72)
    return _lointain(x, 0.92, 0.56, 2800.0, 28)


def _nappe(dur, base, intervalles, seed, brillance=0.35):
    """Nappe de dread : une fondamentale tenue, quelques partiels désaccordés.

    Volontairement pauvre en notes. Une mélodie se retient et devient une
    compagne ; une nappe immobile reste un malaise.
    """
    n = int(dur * SR)
    x = np.zeros(n, np.float32)
    rng2 = np.random.default_rng(seed)
    for k, (ratio, g, entree) in enumerate(intervalles):
        f = base * ratio
        # battement lent : deux voix très légèrement désaccordées
        for detune in (1.0, 1.0 + rng2.uniform(0.0016, 0.0042)):
            v = S.sine(dur, f * detune)
            env = S.env_curve(dur, [(0, 0), (entree, 0), (entree + 0.22, g),
                                    (0.80, g * 0.85), (1, 0)])
            x += S.fit(v * env, n) * 0.5
    # souffle d'air par-dessus, qui donne le lieu
    air = S.bandpass(S.pink(dur, seed + 5), 900, 0.8)
    air *= S.env_curve(dur, [(0, 0), (0.12, brillance), (0.7, brillance * 0.6), (1, 0)])
    x += S.fit(air, n) * 0.5
    x = S.lowpass(x, 2600.0, 0.7)
    return S.normalize(S.reverb(x, 0.93, 0.42, seed + 9), 0.70)


def musique_1():
    """« Le couloir » — quinte à vide qui se trouble."""
    return _nappe(26.0, 55.0, [(1.0, 1.0, 0.00), (1.5, 0.52, 0.18),
                               (2.0, 0.30, 0.42), (2.9966, 0.18, 0.62)], 101)


def musique_2():
    """« Elle passe » — seconde mineure, l'intervalle du sting de détection."""
    return _nappe(31.0, 48.0, [(1.0, 1.0, 0.00), (1.0595, 0.44, 0.24),
                               (2.0, 0.26, 0.50), (4.0, 0.12, 0.70)], 202, 0.28)


def musique_3():
    """« Le service de veille » — presque rien, très bas, très long."""
    return _nappe(38.0, 41.0, [(1.0, 1.0, 0.00), (2.0, 0.34, 0.30),
                               (3.0, 0.16, 0.55)], 303, 0.20)


# ==========================================================================
BANK = {
    # --- enregistrements CC0 ---
    "breath_calm":      breath_calm,
    "breath_winded":    breath_winded,
    "gasp":             gasp,
    "heart_slow":       lambda: heart(False),
    "heart_fast":       lambda: heart(True),
    "amb_drone":        amb_drone,
    "door_open":        door_open,
    "door_close":       door_close,
    "door_slam":        door_slam,
    "locker_open":      lambda: locker(True),
    "locker_close":     lambda: locker(False),
    "pickup_fuse":      lambda: pickup(True),
    "pickup_battery":   lambda: pickup(False),
    "flashlight_click": click_flashlight,
    "fuse_insert":      fuse_insert,
    "ui_move":          lambda: ui(False),
    "ui_select":        lambda: ui(True),
    "entity_rasp":      entity_rasp,
    "entity_scream":    entity_scream,
    "jumpscare":        jumpscare,
    # --- synthèse (rien à enregistrer, ou son musical) ---
    "breath_hold":      breath_hold,
    "power_on":         power_on,
    "music_chase":      music_chase,
    "stinger_detect":   stinger_detect,
    "stinger_lost":     stinger_lost,
    # --- ambiance : nappes, bruits isolés, nappes musicales ---
    "amb_souffle":      amb_souffle,
    "amb_horloge":      amb_horloge,
    "peur_tole":        peur_tole,
    "peur_claque":      peur_claque,
    "peur_chute":       peur_chute,
    "peur_toux":        peur_toux,
    "peur_souffle":     peur_souffle,
    "peur_plainte":     peur_plainte,
    "peur_grincement":  peur_grincement,
    "peur_ressort":     peur_ressort,
    "musique_1":        musique_1,
    "musique_2":        musique_2,
    "musique_3":        musique_3,
}
for _i in range(4):
    BANK[f"step_lino_{_i+1}"] = (lambda i: (lambda: step_lino(i)))(_i)
    BANK[f"step_concrete_{_i+1}"] = (lambda i: (lambda: step_concrete(i)))(_i)
    BANK[f"step_eau_{_i+1}"] = (lambda i: (lambda: step_eau(i)))(_i)
    BANK[f"step_verre_{_i+1}"] = (lambda i: (lambda: step_verre(i)))(_i)
for _i in range(3):
    BANK[f"step_entity_{_i+1}"] = (lambda i: (lambda: step_entity(i)))(_i)
    BANK[f"creak_{_i+1}"] = (lambda i: (lambda: creak(i)))(_i)
    BANK[f"drip_{_i+1}"] = (lambda i: (lambda: drip(900 + i * 17)))(_i)


def main():
    import time
    only = sys.argv[1:] or None
    if not os.path.isdir(sources.CACHE):
        print("  sources absentes — lancement de tools/audio/sources.py")
        sources.fetch()
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
