#!/usr/bin/env python3
"""
Mesure la « tonalité » d'un son : est-ce un bip ou de la matière ?

On prend le maximum de l'autocorrélation normalisée sur les retards
correspondant à 60–2000 Hz. Une sinusoïde pure donne ~1,0 ; du bruit donne
moins de 0,2. Contrairement à la platitude spectrale, la mesure ne pénalise
pas un son légitimement grave (un choc l'est toujours).
"""
import sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spectro import read_wav


def periodicity(x, sr):
    e = np.convolve(x ** 2, np.ones(1024) / 1024, mode="same")
    i0 = int(np.argmax(e))
    n = 8192
    seg = x[max(0, i0 - n // 8): max(0, i0 - n // 8) + n]
    if len(seg) < n:
        seg = np.pad(seg, (0, n - len(seg)))
    seg = seg - seg.mean()
    if np.abs(seg).max() < 1e-6:
        return 0.0
    ac = np.correlate(seg, seg, mode="full")[n - 1:]
    ac /= ac[0] + 1e-12
    # On saute le lobe central : sans cela, tout signal passe-bas obtient un
    # score élevé (il est fortement corrélé à court terme) alors qu'il n'a
    # aucune hauteur. C'est la même précaution que dans un détecteur de
    # fondamentale : on cherche un pic APRÈS le premier minimum local.
    i = 1
    while i < len(ac) - 1 and ac[i] > ac[i + 1]:
        i += 1
    lo, hi = max(i, int(sr / 2000)), int(sr / 60)
    if hi <= lo:
        return 0.0
    return float(ac[lo:hi].max())


if __name__ == "__main__":
    names = sys.argv[1:]
    print(f"   {'son':<20} {'periodicite':>12}   verdict")
    for f in names:
        x, sr = read_wav(f)
        p = periodicity(x, sr)
        v = "BIP" if p > 0.55 else ("limite" if p > 0.38 else "matiere")
        print(f"   {os.path.basename(f)[:-4]:<20} {p:>12.3f}   {v}")
