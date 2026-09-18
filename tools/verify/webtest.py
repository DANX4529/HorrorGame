#!/usr/bin/env python3
"""
Vérifie le build web : sert le dossier en local, le charge dans Chromium et
capture l'écran une fois le jeu démarré. Sans ça, publier une version
navigateur revient à promettre quelque chose qu'on n'a jamais vu tourner.
"""
import http.server, os, socketserver, sys, threading, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
WEB = os.path.join(ROOT, "build", "web")
PORT = 8765


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=WEB, **kw)

    def end_headers(self):
        # Godot sans threads n'en a pas besoin, mais ça ne coûte rien
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def log_message(self, *a):
        pass


def serve():
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        httpd.serve_forever()


def main(out, wait_s=90, titre="/tmp/web_titre.png"):
    threading.Thread(target=serve, daemon=True).start()
    time.sleep(1.0)
    from playwright.sync_api import sync_playwright
    logs = []
    with sync_playwright() as pw:
        # on utilise le Chromium déjà présent dans l'environnement : la
        # version de playwright installée par pip en attend un autre.
        exe = "/opt/pw-browsers/chromium-1194/chrome-linux/chrome"
        br = pw.chromium.launch(executable_path=exe if os.path.exists(exe) else None, args=[
            "--use-gl=angle", "--use-angle=swiftshader",
            "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist",
            "--no-sandbox", "--disable-dev-shm-usage",
        ])
        pg = br.new_page(viewport={"width": 1280, "height": 720})
        pg.on("console", lambda m: logs.append(f"[{m.type}] {m.text}"))
        pg.on("pageerror", lambda e: logs.append(f"[pageerror] {e}"))
        pg.goto(f"http://127.0.0.1:{PORT}/index.html", timeout=120000)
        t0 = time.time()
        started = False
        while time.time() - t0 < wait_s:
            pg.wait_for_timeout(2000)
            # le canvas Godot passe en plein écran une fois le moteur démarré
            try:
                ok = pg.evaluate(
                    "() => { const c = document.getElementById('canvas');"
                    " return !!c && c.width > 100 && c.height > 100; }")
            except Exception:
                ok = False
            if ok and time.time() - t0 > 12:
                started = True
                break
        pg.wait_for_timeout(4000)
        pg.screenshot(path=titre)
        # Le bouton « Descendre » est à ~y=429 sur un canvas 1280x720 ; le clic
        # au centre (y=360) tombait juste au-dessus et ne lançait RIEN. Le test
        # se contentait alors de l'écran-titre en croyant vérifier une partie.
        pg.mouse.click(640, 429)
        pg.wait_for_timeout(5000)
        # Une sauvegarde neuve passe par le prologue au typewriter : sans le
        # sauter on capture un écran de texte sur fond noir, et on croirait
        # avoir vérifié une partie.
        pg.keyboard.press("Escape")
        pg.wait_for_timeout(9000)
        pg.screenshot(path=out)
        # Une descente lancée, c'est un rendu 3D : beaucoup de teintes
        # distinctes. Un écran-titre, ou un écran figé, en a très peu.
        try:
            en_jeu = pg.evaluate("""() => {
                const c = document.getElementById('canvas');
                const g = document.createElement('canvas');
                g.width = 160; g.height = 90;
                g.getContext('2d').drawImage(c, 0, 0, 160, 90);
                const d = g.getContext('2d').getImageData(0, 0, 160, 90).data;
                const s = new Set();
                for (let i = 0; i < d.length; i += 4)
                    s.add((d[i] >> 3) + '_' + (d[i+1] >> 3) + '_' + (d[i+2] >> 3));
                return s.size;
            }""")
        except Exception:
            en_jeu = -1
        br.close()
    print("teintes distinctes apres clic :", en_jeu)
    print("canvas demarre :", started)
    for l in logs[-25:]:
        print("  ", l[:160])
    print("captures ->", titre, "et", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/web.png")
