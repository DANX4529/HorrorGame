#!/usr/bin/env python3
"""
sources — récupération des banques de sons libres utilisées par RESPIRE.

Toutes les sources sont sous **CC0 1.0** (domaine public) : redistribuables
dans ce dépôt sans restriction ni obligation d'attribution. L'attribution est
tout de même consignée dans docs/CREDITS_AUDIO.md, par honnêteté.

    python3 tools/audio/sources.py          # télécharge et décompresse
    python3 tools/audio/sources.py --list   # affiche seulement le manifeste
"""
import os, subprocess, sys, urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CACHE = os.environ.get("RESPIRE_SFX_CACHE", "/tmp/respire-sfx")

PACKS = [
    dict(
        key="owlish",
        name="Sound Effects Pack — Owlish Media (owlstorm)",
        page="https://opengameart.org/content/sound-effects-pack",
        url="https://opengameart.org/sites/default/files/Owlish%20Media%20Sound%20Effects.zip",
        file="owlish.zip", archive=True,
        license="CC0 1.0",
        gives="respiration humaine, halètement, cri, pas sur sol dur, impacts, papier, tissu",
    ),
    dict(
        key="woodmetal",
        name="100 CC0 metal and wood SFX — rubberduck",
        page="https://opengameart.org/content/100-cc0-metal-and-wood-sfx",
        url="https://opengameart.org/sites/default/files/100-CC0-wood-metal-SFX.zip",
        file="woodmetal.zip", archive=True,
        license="CC0 1.0",
        gives="portes, serrures, tôle, grincements, claquements",
    ),
    dict(
        key="fantozzi",
        name="Fantozzi's Footsteps (Grass/Sand & Stone) — Fantozzi",
        page="https://opengameart.org/content/fantozzis-footsteps-grasssand-stone",
        url="https://opengameart.org/sites/default/files/Fantozzi-footsteps.7z",
        file="fantozzi.7z", archive=True,
        license="CC0 1.0",
        gives="pas sur pierre",
    ),
    dict(
        key="ghost",
        name="Ghost Monster Voice Moaning & Growling — qubodup",
        page="https://opengameart.org/content/ghost-monster-voice-moaning-growling",
        url="https://opengameart.org/sites/default/files/qubodup-GhostMoans.zip",
        file="ghost.zip", archive=True,
        license="CC0 1.0",
        gives="râles et grognements de la Veilleuse",
    ),
    dict(
        key="cavern",
        name="Dark Cavern Ambient — Spring Spring",
        page="https://opengameart.org/content/dark-cavern-ambient",
        url="https://opengameart.org/sites/default/files/dark_cavern_ambient_002.ogg",
        file="dark_cavern_ambient_002.ogg", archive=False,
        license="CC0 1.0",
        gives="nappe d'ambiance souterraine (2 min, bouclable)",
    ),
    dict(
        key="heart_slow",
        name="Heartbeat sounds — Ogrebane",
        page="https://opengameart.org/content/heartbeat-sounds",
        url="https://opengameart.org/sites/default/files/heartbeat_slow_0.wav",
        file="heartbeat_slow_0.wav", archive=False,
        license="CC0 1.0", gives="battement de coeur lent",
    ),
    dict(
        key="heart_fast",
        name="Heartbeat sounds — Ogrebane",
        page="https://opengameart.org/content/heartbeat-sounds",
        url="https://opengameart.org/sites/default/files/heartbeat_fast_0.wav",
        file="heartbeat_fast_0.wav", archive=False,
        license="CC0 1.0", gives="battement de coeur rapide",
    ),
]


def path(key, *rest):
    """Chemin d'un fichier dans le cache des sources."""
    p = PACKS_BY_KEY[key]
    base = os.path.join(CACHE, key) if p["archive"] else os.path.join(CACHE, p["file"])
    return os.path.join(base, *rest) if rest else base


PACKS_BY_KEY = {p["key"]: p for p in PACKS}


def fetch(force=False):
    os.makedirs(CACHE, exist_ok=True)
    for p in PACKS:
        dst = os.path.join(CACHE, p["file"])
        if not os.path.exists(dst) or force:
            print(f"  téléchargement  {p['file']}")
            urllib.request.urlretrieve(p["url"], dst)
        if p["archive"]:
            out = os.path.join(CACHE, p["key"])
            if not os.path.isdir(out) or force:
                os.makedirs(out, exist_ok=True)
                subprocess.run(["7z", "x", "-y", f"-o{out}", dst],
                               check=True, stdout=subprocess.DEVNULL)
                print(f"  décompression   {p['key']}")
    print(f"  sources prêtes dans {CACHE}")


def write_credits():
    out = os.path.join(ROOT, "docs", "CREDITS_AUDIO.md")
    L = ["# Crédits audio", "",
         "Les enregistrements utilisés par RESPIRE proviennent tous de banques",
         "sous **CC0 1.0** (domaine public) : leur redistribution dans ce dépôt",
         "est libre et sans obligation. L'attribution ci-dessous est donnée par",
         "honnêteté, pas par obligation légale.", "",
         "Le reste de la bande-son (apnée, nappe de traque, remise sous tension,",
         "stings) est synthétisé par `tools/audio/build_audio.py` — voir",
         "`tools/audio/synth.py`.", "",
         "| Banque | Auteur / page | Licence | Ce qui en est tiré |", "|---|---|---|---|"]
    seen = set()
    for p in PACKS:
        if p["page"] in seen:
            continue
        seen.add(p["page"])
        L.append(f"| {p['name'].split('—')[0].strip()} | [{p['name'].split('—')[-1].strip()}]({p['page']}) "
                 f"| {p['license']} | {p['gives']} |")
    L += ["", "Récupération reproductible :", "",
          "```bash", "python3 tools/audio/sources.py", "```", ""]
    with open(out, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print(f"  crédits écrits  {out}")


if __name__ == "__main__":
    if "--list" in sys.argv:
        for p in PACKS:
            print(f"  {p['key']:<12} {p['license']:<9} {p['name']}")
    else:
        fetch("--force" in sys.argv)
    write_credits()
