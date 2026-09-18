#!/usr/bin/env bash
# Fabrique le correctif qui mène de <base> à HEAD.
#
#   faire_correctif.sh <tag-de-base> [sortie.pck]
#
# Ne contient QUE ce qui a changé. Un correctif de scripts pèse quelques
# centaines de kilo-octets là où l'exécutable entier en fait 148 millions.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"
BASE="$1"
OUT="${2:-$ROOT/build/correctif.pck}"
LISTE="$(mktemp)"
# Godot ne sait charger un script que DANS le projet : « res://.. » ne sort pas
# de la racine. On y dépose l'emballeur le temps de la construction.
EMBAL="$ROOT/game/_faire_correctif.gd"
trap 'rm -f "$LISTE" "$EMBAL"' EXIT
cp "$ROOT/tools/correctif/faire_correctif.gd" "$EMBAL"

cd "$ROOT"
mkdir -p "$(dirname "$OUT")"

# 1. les fichiers du jeu modifiés depuis la base
# Comparaison avec l'ARBRE DE TRAVAIL et non avec HEAD : on veut pouvoir
# fabriquer un correctif de ce qu'on vient de corriger, sans commit obligatoire.
CHANGES=$(git diff --name-only "$BASE" -- game/ | grep -v '^game/\.godot/' || true)
if [ -z "$CHANGES" ]; then
    echo "rien n'a changé dans game/ depuis $BASE"; exit 1
fi

# 2. traduction en chemins res://, plus les ressources IMPORTÉES
#
# Une texture ou un son ne se joue pas depuis son .png ou son .wav mais depuis
# la version importée rangée dans .godot/imported/. Remplacer la source ne
# remplacerait donc rien du tout : il faut embarquer la sortie d'import, dont
# le nom est écrit dans le .import correspondant.
: > "$LISTE"
while IFS= read -r f; do
    [ -z "$f" ] && continue
    rel="${f#game/}"
    case "$rel" in
        .godot/*|export_presets.cfg) continue ;;
        *.import)
            src="${rel%.import}"
            echo "res://$rel" >> "$LISTE"
            rel="$src"
            ;;
    esac
    [ -f "game/$rel" ] && echo "res://$rel" >> "$LISTE"
    if [ -f "game/$rel.import" ]; then
        echo "res://$rel.import" >> "$LISTE"
        # dest_files=["res://.godot/imported/xxx.ctex"]
        grep -o 'res://\.godot/imported/[^"]*' "game/$rel.import" >> "$LISTE" || true
    fi
done <<< "$CHANGES"

sort -u "$LISTE" -o "$LISTE"
echo "== $(wc -l < "$LISTE") fichier(s) dans le correctif $BASE -> HEAD"

"$GODOT" --headless --path game \
    --script res://_faire_correctif.gd -- "$OUT" "$LISTE"

ls -l "$OUT" | awk '{printf "   %s  %.2f Mo\n", $9, $5/1048576}'
