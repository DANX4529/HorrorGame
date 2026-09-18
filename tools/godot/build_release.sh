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

# Les nappes et musiques passent en QOA : elles pèsent les trois quarts de la
# bande-son, et ce jeu se télécharge avant de se jouer. Le réglage vit dans les
# .import, donc on réimporte derrière pour qu'il soit pris en compte.
python3 "$ROOT/tools/godot/fix_audio_imports.py"
"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true

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
	# la branche locale gh-pages peut déjà exister d'un déploiement précédent :
	# on repart d'un arbre détaché et on la recrée à chaque fois.
	git -C "$ROOT" worktree add --detach "$TMP" -q
	# « worktree remove » ne supprime pas la branche créée dans l'arbre : sans ce
	# nettoyage, le DEUXIÈME déploiement depuis un même clone échoue sur
	# « a branch named 'gh-pages-tmp' already exists ». Le premier passe, donc la
	# panne attend d'être en retard pour se manifester.
	git -C "$ROOT" branch -D gh-pages-tmp 2>/dev/null || true
	git -C "$TMP" checkout --orphan gh-pages-tmp -q
	git -C "$TMP" rm -rq --cached . 2>/dev/null || true
	find "$TMP" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
	cp -r "$ROOT/build/web/." "$TMP/"
	# le build Windows est servi depuis la même adresse : une seule URL à retenir
	if [[ -f "$ROOT/build/RESPIRE-windows.zip" ]]; then
		cp "$ROOT/build/RESPIRE-windows.zip" "$TMP/"
	fi
	git -C "$TMP" add -A
	git -C "$TMP" commit -q -m "Version jouable dans le navigateur ($(date -u +%Y-%m-%d\ %H:%M) UTC)"
	git -C "$TMP" push origin gh-pages-tmp:gh-pages --force
	git -C "$ROOT" worktree remove --force "$TMP"
	git -C "$ROOT" branch -D gh-pages-tmp 2>/dev/null || true
	echo "    -> https://danx4529.github.io/HorrorGame/"
fi
