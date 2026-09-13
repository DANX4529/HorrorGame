#!/usr/bin/env bash
# Produit les builds distribuables de RESPIRE.
#
#   ./tools/godot/build_release.sh            # Windows + Web
#   ./tools/godot/build_release.sh web        # Web seulement
#   ./tools/godot/build_release.sh deploy     # Web + publication sur gh-pages
#
# Prérequis : le binaire Godot 4.3 dans $GODOT (ou sur le PATH) et les
# modèles d'export installés dans ~/.local/share/godot/export_templates/4.3.stable
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"
WHAT="${1:-all}"

mkdir -p "$ROOT/build/web"

if [[ "$WHAT" == "all" || "$WHAT" == "windows" ]]; then
	echo "==> Windows"
	"$GODOT" --headless --path "$ROOT/game" --export-release "Windows Desktop" >/dev/null
	( cd "$ROOT/build" && rm -f RESPIRE-windows.zip && zip -9 -q RESPIRE-windows.zip RESPIRE-windows.exe )
	ls -lh "$ROOT/build/RESPIRE-windows.exe" "$ROOT/build/RESPIRE-windows.zip"
fi

if [[ "$WHAT" == "all" || "$WHAT" == "web" || "$WHAT" == "deploy" ]]; then
	echo "==> Web"
	"$GODOT" --headless --path "$ROOT/game" --export-release "Web" >/dev/null
	python3 "$ROOT/tools/godot/publish_web.py"
fi

if [[ "$WHAT" == "deploy" ]]; then
	echo "==> Publication sur gh-pages"
	TMP="$(mktemp -d)"
	git -C "$ROOT" worktree add --detach "$TMP" -q
	git -C "$TMP" switch --orphan gh-pages -q
	find "$TMP" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
	cp -r "$ROOT/build/web/." "$TMP/"
	git -C "$TMP" add -A
	git -C "$TMP" commit -q -m "Version jouable dans le navigateur ($(date -u +%Y-%m-%d\ %H:%M) UTC)"
	git -C "$TMP" push origin gh-pages --force
	git -C "$ROOT" worktree remove --force "$TMP"
	echo "    -> https://danx4529.github.io/HorrorGame/"
fi
