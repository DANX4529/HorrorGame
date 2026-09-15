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
				<b>Jouez au casque</b>, et dans le noir.<br>
				Sur téléphone : en paysage, et de préférence en wifi.
			</div>
		</div>
"""

# --- mobile -------------------------------------------------------------
#
# Trois ennuis propres au navigateur mobile, qu'aucun réglage côté Godot ne
# règle parce qu'ils se jouent dans la page :
#
#   * la barre d'URL mange un quart de l'écran et réapparaît au moindre
#     glissement — on demande le plein écran au premier toucher ;
#   * un double-tap zoome et un glissement à deux doigts fait défiler la page,
#     ce qui rend la visée inutilisable — touch-action et overscroll le coupent ;
#   * en portrait, le jeu est injouable (les deux pouces se recouvrent) — on
#     ne peut pas forcer la rotation de façon fiable, alors on la demande.
CSS_MOBILE = """
html, body {
	position: fixed; width: 100%; height: 100%; margin: 0; overflow: hidden;
	overscroll-behavior: none; touch-action: none;
	-webkit-user-select: none; user-select: none;
	-webkit-tap-highlight-color: transparent;
}
canvas { touch-action: none; }
#respire-rotate {
	position: fixed; inset: 0; display: none; z-index: 20;
	background: #000; color: #b9b3a4; text-align: center;
	font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
	flex-direction: column; align-items: center; justify-content: center; gap: 18px;
}
#respire-rotate b { font-size: 21px; letter-spacing: 3px; color: #ddd6c6; }
#respire-rotate span { font-size: 14px; opacity: .65; line-height: 1.7; }
@media (orientation: portrait) and (pointer: coarse) {
	#respire-rotate { display: flex; }
}
"""

JS_MOBILE = """
<script>
(function () {
	var tactile = matchMedia('(pointer: coarse)').matches
		|| ('ontouchstart' in window);
	if (!tactile) return;
	// Plein écran au premier toucher : un navigateur n'accorde ce passage que
	// pendant un geste de l'utilisateur, jamais au chargement.
	function plein() {
		var e = document.documentElement;
		var f = e.requestFullscreen || e.webkitRequestFullscreen;
		if (f) { try { f.call(e); } catch (x) {} }
		window.removeEventListener('touchend', plein);
	}
	window.addEventListener('touchend', plein, { passive: true });
	// Le double-tap zoome sur iOS même avec user-scalable=no.
	var dernier = 0;
	document.addEventListener('touchend', function (ev) {
		var t = Date.now();
		if (t - dernier < 320) ev.preventDefault();
		dernier = t;
	}, { passive: false });
})();
</script>
"""

ROTATE = """
		<div id="respire-rotate">
			<b>TOURNEZ L'APPAREIL</b>
			<span>RESPIRE se joue en paysage.<br>
			Les deux pouces ont besoin de place.</span>
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
        s = s.replace("</style>", CSS + CSS_MOBILE + "\n</style>", 1)
        s = s.replace('<div id="status">', NOTE + ROTATE + '\t\t<div id="status">', 1)
        s = s.replace("</body>", JS_MOBILE + "</body>", 1)
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
