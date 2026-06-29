#!/usr/bin/env bash
# Hook UserPromptSubmit — en cada mensaje del usuario, si el rate limit de 5h
# está en zona warn/danger/hard, inyecta el % y el nudge correspondiente como
# contexto. Barato: corre una vez por turno del usuario y lee el cache (sin red).
set -uo pipefail
cat >/dev/null  # consumir el payload de stdin (no lo necesitamos)

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

j=$(usage_json) || exit 0
[ -n "$j" ] || exit 0
zone=$(usage_field "$j" '.zone')
[ "$zone" = "ok" ] || [ -z "$zone" ] && exit 0
[ "$zone" = "unknown" ] && exit 0

pct=$(usage_field "$j" '.pct')
rmin=$(usage_field "$j" '.resets_in_min')
window=$(usage_field "$j" '.window')
txt=$(nudge_text "$zone" "$pct" "$rmin" "$window")
[ -n "$txt" ] && emit_context "UserPromptSubmit" "$txt"
exit 0
