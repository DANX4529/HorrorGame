#!/usr/bin/env python3
"""
playtest — lance RESPIRE en headless (Xvfb + OpenGL logiciel) et capture des
images. C'est l'outil de vérification visuelle du jeu.

usage: playtest.py NOM [--tp X Z] [--yaw D] [--pitch D] [--light E]
                       [--frames N] [--torch 0|1] [--noent] [--overview S]
"""
import os, subprocess, sys, shutil, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCRATCH = "/tmp/claude-0/-home-user-HorrorGame/df4feaab-5f6b-57ae-aafd-5ff6c1c97215/scratchpad"
GODOT = os.path.join(SCRATCH, "Godot_v4.3-stable_linux.x86_64")
SHOTS = os.path.join(SCRATCH, "shots")


def run(name, extra=(), frames=90, res="1280x720", timeout=240, autoplay=True):
    os.makedirs(SHOTS, exist_ok=True)
    out = os.path.join(SHOTS, name + ".png")
    if os.path.exists(out):
        os.remove(out)
    cmd = ["xvfb-run", "-a", "-s", f"-screen 0 {res}x24", GODOT,
           "--path", os.path.join(ROOT, "game"),
           "--rendering-driver", "opengl3", "--resolution", res,
           "--", "--shot", out, str(frames)] + (["--autoplay"] if autoplay else []) + list(extra)
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    log = p.stdout + p.stderr
    bad = [l for l in log.splitlines()
           if ("ERROR" in l or "SCRIPT ERROR" in l or "Parse Error" in l)
           and "audio" not in l.lower() and "ERR_CANT_OPEN" not in l]
    return out, bad, log


if __name__ == "__main__":
    a = sys.argv[1:]
    name = a[0]
    extra, frames = [], 90
    i = 1
    while i < len(a):
        if a[i] == "--frames":
            frames = int(a[i + 1]); i += 2
        elif a[i] == "--tp":
            extra += ["--tp", a[i + 1], a[i + 2]]; i += 3
        elif a[i] in ("--yaw", "--pitch", "--light", "--torch", "--overview"):
            extra += [a[i], a[i + 1]]; i += 2
        elif a[i] == "--title":
            i += 1                      # traité plus bas (désactive --autoplay)
        elif a[i].startswith("--"):
            # Tout autre drapeau est transmis tel quel au jeu, AVEC sa valeur
            # si la suite n'est pas elle-même un drapeau. Sans ça une option
            # inconnue — ou pire, sa valeur seule — serait silencieusement
            # avalée, et le test mesurerait autre chose que ce qu'on croit.
            extra.append(a[i])
            i += 1
            while i < len(a) and not a[i].startswith("--"):
                extra.append(a[i])
                i += 1
        else:
            i += 1
    out, bad, log = run(name, extra, frames, autoplay=("--title" not in a))
    for l in bad[:20]:
        print("  !", l)
    print(("OK   " if os.path.exists(out) else "ECHEC ") + out)
