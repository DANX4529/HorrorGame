"""
synth — primitives DSP pour la synthèse des sons de RESPIRE.

Tout en numpy, sortie WAV PCM 16 bits. Aucune dépendance externe :
les sons du jeu sont fabriqués, pas téléchargés.
"""
import numpy as np
import struct, os

SR = 44100


# ==========================================================================
#  Sources
# ==========================================================================
def t_axis(dur):
    return np.arange(int(dur * SR), dtype=np.float32) / SR


def white(dur, seed=0):
    return np.random.default_rng(seed).standard_normal(int(dur * SR)).astype(np.float32)


def pink(dur, seed=0):
    """Bruit rose par filtrage 1/f dans le domaine fréquentiel."""
    n = int(dur * SR)
    spec = np.fft.rfft(white(dur, seed))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1] if len(f) > 1 else 1.0
    spec /= np.sqrt(f)
    out = np.fft.irfft(spec, n).astype(np.float32)
    return out / (np.abs(out).max() + 1e-9)


def brown(dur, seed=0):
    """Bruit brownien — grondement sourd."""
    n = int(dur * SR)
    spec = np.fft.rfft(white(dur, seed))
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = f[1] if len(f) > 1 else 1.0
    spec /= f
    out = np.fft.irfft(spec, n).astype(np.float32)
    return out / (np.abs(out).max() + 1e-9)


def sine(dur, freq, phase=0.0):
    t = t_axis(dur)
    if np.isscalar(freq):
        return np.sin(2 * np.pi * freq * t + phase).astype(np.float32)
    ph = np.cumsum(2 * np.pi * np.asarray(freq, np.float32) / SR)
    return np.sin(ph + phase).astype(np.float32)


# ==========================================================================
#  Filtres
# ==========================================================================
def _biquad(x, b0, b1, b2, a1, a2):
    y = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        xi = x[i]
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        y[i] = yi
        x2, x1 = x1, xi
        y2, y1 = y1, yi
    return y


def lowpass(x, fc, q=0.707):
    """Passe-bas 2 pôles. fc peut être un scalaire ou une enveloppe."""
    if np.isscalar(fc):
        w = 2 * np.pi * fc / SR
        al = np.sin(w) / (2 * q)
        c = np.cos(w)
        a0 = 1 + al
        return _biquad(x, (1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0,
                       -2 * c / a0, (1 - al) / a0)
    return _sweep(x, fc, q, "lp")


def highpass(x, fc, q=0.707):
    w = 2 * np.pi * fc / SR
    al = np.sin(w) / (2 * q)
    c = np.cos(w)
    a0 = 1 + al
    return _biquad(x, (1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0,
                   -2 * c / a0, (1 - al) / a0)


def bandpass(x, fc, q=4.0):
    if np.isscalar(fc):
        w = 2 * np.pi * fc / SR
        al = np.sin(w) / (2 * q)
        c = np.cos(w)
        a0 = 1 + al
        return _biquad(x, al / a0, 0.0, -al / a0, -2 * c / a0, (1 - al) / a0)
    return _sweep(x, fc, q, "bp")


def _sweep(x, fc_env, q, kind):
    """Filtre à fréquence de coupure variable — coefficients recalculés par blocs."""
    fc_env = np.asarray(fc_env, np.float32)
    if len(fc_env) != len(x):
        fc_env = np.interp(np.linspace(0, 1, len(x)),
                           np.linspace(0, 1, len(fc_env)), fc_env).astype(np.float32)
    out = np.empty_like(x)
    BLK = 256
    x1 = x2 = y1 = y2 = 0.0
    for s in range(0, len(x), BLK):
        e = min(s + BLK, len(x))
        fc = float(np.clip(fc_env[s:e].mean(), 20.0, SR * 0.45))
        w = 2 * np.pi * fc / SR
        al = np.sin(w) / (2 * q)
        c = np.cos(w)
        a0 = 1 + al
        if kind == "lp":
            b0, b1, b2 = (1 - c) / 2 / a0, (1 - c) / a0, (1 - c) / 2 / a0
        else:
            b0, b1, b2 = al / a0, 0.0, -al / a0
        a1, a2 = -2 * c / a0, (1 - al) / a0
        for i in range(s, e):
            xi = x[i]
            yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            out[i] = yi
            x2, x1 = x1, xi
            y2, y1 = y1, yi
    return out


def resonator(x, freq, decay=0.25, gain=1.0):
    """
    Résonateur à deux pôles — donne un corps et une hauteur à du bruit.

    La sortie est normalisée au gain demandé. Sans cette normalisation le
    gain brut d'un pôle très résonant vaut (1-r) ~ 1e-3 : le corps du son
    devient inaudible et il ne reste que le bruit aigu de l'attaque.
    """
    r = np.exp(-1.0 / (decay * SR))
    w = 2 * np.pi * freq / SR
    y = _biquad(x, 1.0, 0.0, 0.0, -2 * r * np.cos(w), r * r)
    m = float(np.abs(y).max())
    return (y * (gain / m)).astype(np.float32) if m > 1e-9 else y.astype(np.float32)


# ==========================================================================
#  Enveloppes
# ==========================================================================
def env_adsr(dur, a=0.01, d=0.1, s=0.6, r=0.2):
    n = int(dur * SR)
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    ns = max(0, n - na - nd - nr)
    return np.concatenate([
        np.linspace(0, 1, na, dtype=np.float32),
        np.linspace(1, s, nd, dtype=np.float32),
        np.full(ns, s, dtype=np.float32),
        np.linspace(s, 0, nr, dtype=np.float32),
    ])[:n]


def env_curve(dur, points):
    """Enveloppe par points (t_normalisé, valeur), interpolation linéaire."""
    n = int(dur * SR)
    xs = np.array([p[0] for p in points], np.float32)
    ys = np.array([p[1] for p in points], np.float32)
    return np.interp(np.linspace(0, 1, n), xs, ys).astype(np.float32)


def fit(a, n):
    """Ajuste un tableau à n échantillons (troncature ou remplissage à zéro)."""
    if len(a) == n:
        return a
    if len(a) > n:
        return a[:n]
    return np.concatenate([a, np.zeros(n - len(a), np.float32)])


# ==========================================================================
#  Effets
# ==========================================================================
def reverb(x, room=0.6, wet=0.3, seed=1):
    """Réverbération par convolution avec une queue de bruit décroissante."""
    n_ir = int(room * SR)
    rng = np.random.default_rng(seed)
    ir = rng.standard_normal(n_ir).astype(np.float32)
    ir *= np.exp(-np.linspace(0, 7.0, n_ir)).astype(np.float32)
    ir[:int(0.004 * SR)] *= 0.15           # pré-délai
    ir = lowpass(ir, 3200)                 # absorption des aigus par les murs
    ir /= np.abs(ir).sum() + 1e-9
    n = len(x) + n_ir - 1
    nfft = 1 << int(np.ceil(np.log2(n)))
    y = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:len(x)]
    return ((1 - wet) * x + wet * y.astype(np.float32) * 6.0).astype(np.float32)


def saturate(x, amount=2.0):
    return np.tanh(x * amount).astype(np.float32) / np.tanh(amount)


def pitch_shift_naive(x, ratio):
    """Rééchantillonnage — change hauteur et durée (suffisant pour des variantes)."""
    n = int(len(x) / ratio)
    return np.interp(np.linspace(0, len(x) - 1, n),
                     np.arange(len(x)), x).astype(np.float32)


def loopable(x, fade=0.12):
    """Rend une boucle raccordable : fondu croisé de la fin sur le début."""
    nf = int(fade * SR)
    if nf * 2 >= len(x):
        return x
    head, tail = x[:nf].copy(), x[-nf:].copy()
    ramp = np.linspace(0, 1, nf, dtype=np.float32)
    x = x[:-nf].copy()
    x[:nf] = head * ramp + tail * (1 - ramp)
    return x


def normalize(x, peak=0.89):
    m = np.abs(x).max()
    return (x * (peak / m)).astype(np.float32) if m > 1e-9 else x


def stereo(l, r=None, width=1.0):
    if r is None:
        r = l.copy()
    n = max(len(l), len(r))
    return np.stack([fit(l, n), fit(r, n)], axis=1)


# ==========================================================================
#  Écriture WAV
# ==========================================================================
def write_wav(path, data, sr=SR):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.asarray(data, np.float32)
    if a.ndim == 1:
        a = a[:, None]
    ch = a.shape[1]
    pcm = np.clip(a, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2").tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 36 + len(pcm)) + b"WAVE")
        f.write(b"fmt " + struct.pack("<IHHIIHH", 16, 1, ch, sr,
                                      sr * ch * 2, ch * 2, 16))
        f.write(b"data" + struct.pack("<I", len(pcm)) + pcm)
    return path


# ==========================================================================
#  Impacts — la matière, pas la note
# ==========================================================================
def blur_env(e, sec=0.004):
    """Lisse une enveloppe (adoucit les fronts des saccades de friction)."""
    w = max(3, int(sec * SR) | 1)
    k = np.hanning(w).astype(np.float32)
    k /= k.sum()
    return np.convolve(e, k, mode="same").astype(np.float32)


def noise_burst(dur, freq, q=1.6, decay=0.05, seed=0, source="pink"):
    """
    Bruit passe-bande à décroissance exponentielle.

    C'est le corps de tout impact réel : il donne le poids et une hauteur
    perçue SANS donner de note. Un résonateur seul sur une impulsion produit
    une sinusoïde amortie, c'est-à-dire un bip — la signature sonore des jeux
    8 bits, et exactement ce qu'il faut éviter ici.
    """
    x = pink(dur, seed) if source == "pink" else white(dur, seed)
    x = bandpass(x, float(freq), q)
    t = np.arange(len(x), dtype=np.float32)
    x *= np.exp(-t / max(decay * SR, 1.0))
    m = np.abs(x).max()
    return (x / m).astype(np.float32) if m > 1e-9 else x


def thud(dur, cutoff, decay=0.03, seed=0, slope=1.0):
    """
    Choc large bande : bruit passe-bas à décroissance rapide.

    Contrairement à un bruit à bande étroite (qui reste quasi périodique et
    s'entend donc comme une note), un bruit passe-bas n'a AUCUNE hauteur : il
    ne porte que le poids. C'est la base d'un impact crédible.
    """
    x = white(dur, seed)
    x = lowpass(x, float(cutoff), 0.6)
    for _ in range(int(max(slope, 1.0)) - 1):
        x = lowpass(x, float(cutoff), 0.6)      # pente plus raide : -12 dB/oct de plus
    t = np.arange(len(x), dtype=np.float32)
    x *= np.exp(-t / max(decay * SR, 1.0))
    m = np.abs(x).max()
    return (x / m).astype(np.float32) if m > 1e-9 else x


def modal_bank(exc, freqs, decays, gains):
    """
    Banc de résonateurs. À n'utiliser qu'en APPOINT d'un corps bruité, et avec
    des fréquences INHARMONIQUES : des modes en rapports entiers se fondent en
    une hauteur unique et le son redevient un bip.
    """
    out = np.zeros_like(exc)
    for f, d, g in zip(freqs, decays, gains):
        out += resonator(exc, float(f), float(d), float(g))
    m = np.abs(out).max()
    return (out / m).astype(np.float32) if m > 1e-9 else out


# rapports inharmoniques (plaque/objet réel), volontairement non entiers
INHARM = (1.0, 1.47, 2.09, 2.71, 3.43, 4.28, 5.36, 6.71)


def material_modes(exc, base, decay, n=6, spread=1.0, seed=0, tilt=0.62):
    """Modes d'un matériau : rapports inharmoniques, légèrement désaccordés."""
    r = np.random.default_rng(seed)
    freqs, decays, gains = [], [], []
    for i in range(min(n, len(INHARM))):
        freqs.append(base * INHARM[i] * spread * (0.97 + 0.06 * r.random()))
        decays.append(decay * (tilt ** i) * (0.85 + 0.3 * r.random()))
        gains.append(tilt ** i)
    return modal_bank(exc, freqs, decays, gains)


def crackle(dur, density=250, seed=0, f_lo=1200, f_hi=7000, decay=0.10):
    """Crépitement : micro-impacts dispersés (gravier, plâtre, poussière)."""
    n = int(dur * SR)
    r = np.random.default_rng(seed)
    x = np.zeros(n, np.float32)
    k = int(density * dur)
    if k > 0:
        idx = r.integers(0, n, k)
        x[idx] = r.standard_normal(k).astype(np.float32)
    x = bandpass(x, (f_lo * f_hi) ** 0.5, 0.8)
    t = np.arange(n, dtype=np.float32)
    x *= np.exp(-t / max(decay * SR, 1.0))
    m = np.abs(x).max()
    return (x / m).astype(np.float32) if m > 1e-9 else x


def transient(dur, bright=4000, seed=0, hardness=1.0):
    """Attaque large bande : le contact lui-même, avant toute résonance."""
    x = white(dur, seed)
    x = lowpass(x, bright)
    e = env_curve(dur, [(0.0, 1.0), (0.004 / max(dur, 1e-6), 0.32),
                        (0.020 / max(dur, 1e-6), 0.07),
                        (0.075 / max(dur, 1e-6), 0.0), (1.0, 0.0)])
    x = x * fit(e, len(x))
    return saturate(x * hardness, 1.2)
