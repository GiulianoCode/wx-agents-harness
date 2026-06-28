#!/usr/bin/env bash
# bootstrap.sh — arranque en UN comando: clona este template y lo instala en el
# proyecto actual (carpeta nueva o existente). install.sh decide el resto (no pisa nada).
#
# Uso (dentro de la carpeta del proyecto):
#   curl -fsSL https://raw.githubusercontent.com/GiulianoCode/wx-agents-harness/main/bootstrap.sh | bash
# o, si ya tenés el repo a mano:
#   bash bootstrap.sh [dir-destino]
#
# Variables:
#   TEMPLATE_REPO  URL del template (default abajo). Override si forkeás/renombrás.
set -euo pipefail

REPO="${TEMPLATE_REPO:-https://github.com/GiulianoCode/wx-agents-harness}"
TGT="${1:-$PWD}"
mkdir -p "$TGT"; TGT="$(cd "$TGT" && pwd)"

command -v git >/dev/null 2>&1 || { echo "Falta git."; exit 1; }
command -v jq  >/dev/null 2>&1 || echo "Aviso: falta jq (necesario para fusionar settings.json en proyectos existentes)."

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
echo "Clonando template: $REPO"
git clone --depth 1 "$REPO" "$TMP/template" >/dev/null 2>&1 \
  || { echo "No pude clonar $REPO (¿URL/visibilidad correctas? ¿repo público?)"; exit 1; }

bash "$TMP/template/install.sh" "$TGT"

echo
echo "════════════════════════════════════════════════════════════"
echo "Harness instalado en: $TGT"
echo "Ahora abrí Claude Code en esa carpeta, APROBÁ los hooks, y:"
echo "  • proyecto NUEVO / vacío  →  corré  /onboard"
echo "  • proyecto EXISTENTE      →  corré  /adopt"
echo "════════════════════════════════════════════════════════════"
