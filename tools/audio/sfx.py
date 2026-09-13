"""
sfx — chargement et mise en forme des enregistrements sources.

Le décodage passe par ffmpeg (WAV 16/24 bits, float, OGG, FLAC) et rend
directement du float32 à 44,1 kHz. Tout le reste du traitement est en numpy,
comme le volet synthèse.

Règle de mixage importante : **tout son positionné dans le monde doit être
mono**. Un flux stéréo confié à un AudioStreamPlayer3D ne se spatialise pas
correctement — le joueur ne saurait plus d'où vient un pas.
"""
import os, shutil, subprocess
import numpy as np
import synth as S

SR = S.SR
FFMPEG = shutil.which("ffmpeg") or "ffmpeg"


# ==========================================================================
#  Chargement
# ==========================================================================
def load(path, mono=True, sr=SR):
    """Décode n'importe quel format audio en float32 [-1,1]."""
    if not os.path.exists(path):
        raise FileNotFoundError(path)
    ch = 1 if mono else 2
    out = subprocess.run(
        [FFMPEG, "-v", "error", "-i", path, "-ar", str(sr), "-ac", str(ch),
         "-f", "f32le", "-"],
        capture_output=True, check=True).stdout
    a = np.frombuffer(out, dtype=np.float32).copy()
    return a.reshape(-1, 2) if ch == 2 else a


# ==========================================================================
#  Découpe
# ==========================================================================
def _env(x, win=512):
    m = np.abs(x if x.ndim == 1 else x.mean(1))
    return np.convolve(m, np.ones(win) / win, mode="same")


def trim(x, thresh_db=-46.0, pad_ms=8.0, tail_ms=120.0):
    """Retire le silence de tête et de queue, en gardant un peu de marge."""
    e = _env(x)
    if e.max() < 1e-6:
        return x
    thr = e.max() * (10.0 ** (thresh_db / 20.0))
    idx = np.where(e > thr)[0]
    if len(idx) == 0:
        return x
    a = max(0, idx[0] - int(pad_ms * SR / 1000))
    b = min(len(x), idx[-1] + int(tail_ms * SR / 1000))
    return x[a:b]


def seg(x, t0, dur):
    """Extrait une tranche, exprimée en secondes."""
    a = int(t0 * SR)
    return x[a:a + int(dur * SR)]


def best_loop(x, dur, t_min=0.0, t_max=None, fade=0.12, tries=140):
    """
    Découpe une boucle propre.

    On cherche la fenêtre dont les extrémités ont des niveaux proches ET bas :
    le fondu croisé y devient inaudible. Couper au hasard dans une respiration
    produit sinon un clic ou un demi-souffle à chaque tour de boucle.
    """
    n = int(dur * SR)
    if len(x) <= n + 10:
        return S.loopable(x, fade)
    e = _env(x, 1024)
    hi = len(x) - n - 1 if t_max is None else min(int(t_max * SR), len(x) - n - 1)
    lo = int(t_min * SR)
    if hi <= lo:
        lo, hi = 0, len(x) - n - 1
    best, best_score = lo, 1e9
    w = int(0.05 * SR)
    for k in range(tries):
        s = lo + (hi - lo) * k // max(tries - 1, 1)
        a = e[s:s + w].mean()
        b = e[s + n - w:s + n].mean()
        score = abs(a - b) * 3.0 + (a + b) * 0.5      # bords proches ET calmes
        if score < best_score:
            best_score, best = score, s
    return S.loopable(x[best:best + n], fade)


# ==========================================================================
#  Mise en forme
# ==========================================================================
def gain(x, db):
    return (x * (10.0 ** (db / 20.0))).astype(np.float32)


def pitch(x, ratio):
    """Rééchantillonnage : <1 descend et allonge, >1 monte et raccourcit."""
    return S.pitch_shift_naive(x, ratio)


def fade(x, in_ms=6.0, out_ms=30.0):
    y = x.astype(np.float32).copy()
    a, b = int(in_ms * SR / 1000), int(out_ms * SR / 1000)
    if a > 0 and a < len(y):
        y[:a] *= np.linspace(0, 1, a, dtype=np.float32)
    if b > 0 and b < len(y):
        y[-b:] *= np.linspace(1, 0, b, dtype=np.float32)
    return y


def mix(*layers):
    """Somme des couches (tableau, gain). La longueur est celle de la plus longue."""
    n = max(len(a) for a, _ in layers)
    out = np.zeros(n, np.float32)
    for a, g in layers:
        out[:len(a)] += a[:n] * g
    return out


def tilt(x, low_db=0.0, high_db=0.0, pivot=900.0):
    """
    Bascule de timbre : gain dans le grave, gain dans l'aigu, transition
    douce autour du pivot.

    Fait en domaine fréquentiel, donc à phase linéaire. La version naïve
    (`aigu = x - passe_bas(x)`) est fausse : le déphasage du biquad fait que
    la somme se recombine en peigne autour du pivot, ce qui creuse des
    encoches régulières — le son y gagne une hauteur qu'il n'avait pas.
    Mesuré : une bascule de 4 dB faisait passer un grincement de bois d'une
    périodicité de 0,14 à 0,54.
    """
    if abs(low_db) < 1e-3 and abs(high_db) < 1e-3:
        return x.astype(np.float32)
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    t = 1.0 / (1.0 + (pivot / np.maximum(f, 1.0)) ** 2)      # 0 grave -> 1 aigu
    g = 10.0 ** ((low_db * (1.0 - t) + high_db * t) / 20.0)
    return np.fft.irfft(X * g, n).astype(np.float32)


def room(x, size=0.5, wet=0.25, seed=1):
    """Place le son dans le bâtiment (couloirs carrelés, très réverbérants)."""
    return S.reverb(x, size, wet, seed)


def norm(x, peak=0.85):
    return S.normalize(x, peak)
