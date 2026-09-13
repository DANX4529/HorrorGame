#!/usr/bin/env python3
"""
Prépare le build web pour l'hébergement statique.

Retouche le gabarit HTML généré par Godot (textes en français, avertissement
sur le premier chargement) et pose le .nojekyll exigé par GitHub Pages pour
servir les fichiers tels quels.
"""
import os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WEB = os.path.join(ROOT, "build", "web")

NOTE = """
		<div id="respire-note">
			<div id="respire-title">RESPIRE</div>
			<div id="respire-sub">Sanatorium du Mont-Cendre — 1961</div>
			<div id="respire-hint">
				Premier chargement : environ 80&nbsp;Mo.<br>
				Comptez une à deux minutes — ensuite le navigateur garde tout en cache.<br><br>
				<b>Jouez au casque</b>, et dans le noir.
			</div>
		</div>
"""

CSS = """
#respire-note {
	position: absolute; inset: 0; display: flex; flex-direction: column;
	align-items: center; justify-content: center; gap: 14px;
	font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
	color: #b9b3a4; text-align: center; pointer-events: none; z-index: 5;
}
#respire-title { font-size: 46px; letter-spacing: 10px; color: #ddd6c6; }
#respire-sub { font-size: 15px; opacity: .75; }
#respire-hint { font-size: 13px; opacity: .6; line-height: 1.7; margin-top: 18px; }
"""


def main():
    idx = os.path.join(WEB, "index.html")
    with open(idx, encoding="utf-8") as f:
        s = f.read()
    s = s.replace('<html lang="en">', '<html lang="fr">')
    if "respire-note" not in s:
        s = s.replace("</style>", CSS + "\n</style>", 1)
        s = s.replace('<div id="status">', NOTE + '\t\t<div id="status">', 1)
        # on retire l'habillage une fois le moteur prêt
        s = s.replace("setStatusMode('hidden');",
                      "setStatusMode('hidden');\n\t\t"
                      "{ const n = document.getElementById('respire-note');"
                      " if (n) n.remove(); }", 1)
    with open(idx, "w", encoding="utf-8") as f:
        f.write(s)
    open(os.path.join(WEB, ".nojekyll"), "w").close()
    total = sum(os.path.getsize(os.path.join(WEB, f)) for f in os.listdir(WEB))
    print(f"  build web prêt : {total/1024/1024:.1f} Mo dans {WEB}")


if __name__ == "__main__":
    main()
