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


def main(out, wait_s=90):
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
        pg.mouse.click(640, 360)        # démarre le jeu (écran-titre)
        pg.wait_for_timeout(6000)
        pg.screenshot(path=out)
        br.close()
    print("canvas demarre :", started)
    for l in logs[-25:]:
        print("  ", l[:160])
    print("capture ->", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/web.png")
