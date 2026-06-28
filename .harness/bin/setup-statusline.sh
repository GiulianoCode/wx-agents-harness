#!/usr/bin/env bash
# setup-statusline.sh — instala el statusline del harness en ~/.claude (NO-CLOBBER).
#
# Por qué importa: el statusline es (1) tu indicador visual del rate limit de 5h y
# (2) la FUENTE PRIMARIA sin red del harness — escribe ~/.cache/claude/ratelimit.json
# en cada render. Sin él, el harness cae al fallback de API (funciona, gasta red).
#
# Seguro: si YA tenés un statusLine configurado, NO lo pisa; te da el snippet para
# que el tuyo cachee el rate limit. Idempotente.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/../statusline/statusline.sh"
DEST="$HOME/.claude/statusline-command.sh"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "Falta jq."; exit 1; }
[ -f "$SRC" ] || { echo "No encuentro el statusline del harness ($SRC)."; exit 1; }
mkdir -p "$HOME/.claude" "$HOME/.cache/claude" 2>/dev/null

SNIPPET='rl=$(echo "$input" | jq -c ".rate_limits // empty"); [ -n "$rl" ] && mkdir -p ~/.cache/claude && printf "%s\n" "$rl" > ~/.cache/claude/ratelimit.json'

existing=""
[ -s "$SETTINGS" ] && existing=$(jq -r '.statusLine.command // empty' "$SETTINGS" 2>/dev/null)

if [ -n "$existing" ]; then
  cat <<EOF
Ya tenés un statusLine configurado:
  $existing

NO lo piso. Para que el harness tenga su fuente de rate limit SIN red, asegurate de
que tu statusline cachee el dato. Agregale esto (recibe el payload de Claude Code por
stdin como \$input):

  $SNIPPET

Si preferís usar el statusline del harness en su lugar, borrá tu statusLine de
$SETTINGS y volvé a correr este script.
EOF
  exit 0
fi

# No hay statusLine → instalar el del harness (backup si había un archivo suelto).
[ -e "$DEST" ] && cp "$DEST" "$DEST.bak.$(date +%s)" 2>/dev/null
cp "$SRC" "$DEST"; chmod +x "$DEST"

tmp="$(mktemp)"
base="$SETTINGS"; [ -s "$SETTINGS" ] || { echo '{}' > "$tmp.base"; base="$tmp.base"; }
if jq '.statusLine = {type:"command", command:"bash ~/.claude/statusline-command.sh", refreshInterval:60}' \
     "$base" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
  mv "$tmp" "$SETTINGS"; rm -f "$tmp.base"
  echo "✓ Statusline del harness instalado en $DEST"
  echo "✓ ~/.claude/settings.json → statusLine configurado (refreshInterval 60)"
  echo "  Reabrí Claude Code para verlo (proyecto · rama · contexto · 5h)."
else
  rm -f "$tmp" "$tmp.base"
  echo "No pude actualizar $SETTINGS automáticamente. Agregá a mano:"
  echo '  "statusLine": { "type":"command", "command":"bash ~/.claude/statusline-command.sh", "refreshInterval":60 }'
  exit 1
fi
