#!/usr/bin/env python3
"""
Compresse les sons longs à l'import.

Les nappes et les musiques sont de loin les plus gros fichiers du jeu : à
elles seules, les trois nappes de dread pèsent 8 Mo en PCM 16 bits. Sur un
jeu joué dans le navigateur, où le premier chargement est déjà le principal
frein, c'est le poste qui coûte le plus cher.

Godot sait les stocker en QOA (compress/mode=2), qui divise par trois ou
quatre pour un matériau grave et soutenu comme celui-ci — c'est exactement
le cas favorable de ce codec. On laisse en PCM les sons COURTS et
percussifs (pas, impacts, stings) : le gain y serait dérisoire et les
transitoires sont ce que QOA rend le moins bien.

Idempotent : relancer ne change rien de plus.
"""
import os, sys, wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
AUDIO = os.path.join(ROOT, "game", "assets", "audio")

## Au-delà de cette durée, un son est une nappe, pas un bruit.
SEUIL_SECONDES = 5.0
QOA = 2


def duree(path):
    with wave.open(path) as w:
        return w.getnframes() / float(w.getframerate())


def main():
    change = 0
    total_avant = 0
    longs = []
    for nom in sorted(os.listdir(AUDIO)):
        if not nom.endswith(".wav"):
            continue
        chemin = os.path.join(AUDIO, nom)
        d = duree(chemin)
        total_avant += os.path.getsize(chemin)
        if d < SEUIL_SECONDES:
            continue
        longs.append((nom, d, os.path.getsize(chemin)))
        imp = chemin + ".import"
        if not os.path.exists(imp):
            print(f"  ! {nom} : pas de .import (lancer Godot --import d'abord)")
            continue
        with open(imp, encoding="utf-8") as f:
            s = f.read()
        if f"compress/mode={QOA}" in s:
            continue
        s2 = s.replace("compress/mode=0", f"compress/mode={QOA}")
        if s2 == s:
            continue
        with open(imp, "w", encoding="utf-8") as f:
            f.write(s2)
        change += 1

    poids = sum(t for _, _, t in longs)
    print(f"  {len(longs)} sons de plus de {SEUIL_SECONDES:.0f}s "
          f"({poids/1024/1024:.1f} Mo sur {total_avant/1024/1024:.1f} Mo au total)")
    for nom, d, t in sorted(longs, key=lambda x: -x[2])[:8]:
        print(f"      {nom:<20} {d:5.1f}s  {t/1024:7.0f} Ko")
    print(f"  {change} fichiers .import passés en QOA")
    return 0


if __name__ == "__main__":
    sys.exit(main())
