#!/usr/bin/env bash
# Hook PostToolUse — el guardián durante corridas autónomas (muchas tool calls
# sin turnos del usuario, donde prompt-usage.sh no dispara).
#
# Lógica:
#   - Lee el rate limit (cache, sin red).
#   - Notifica (inyecta nudge) cuando:
#       (a) se CRUZA a una zona más alta que la última vista, o
#       (b) se está en danger/hard y pasó el throttle desde el último aviso
#           (recordatorio periódico para mantener el handoff fresco / parar).
#   - En zona ok: silencioso.
# Estado en ~/.cache/claude/harness-guard.state  →  "<zone> <last_notify_ts>"
set -uo pipefail
cat >/dev/null

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

# --cache-only: este hook corre en CADA tool call → nunca debe tocar la red.
j=$(usage_json --cache-only) || exit 0
[ -n "$j" ] || exit 0
zone=$(usage_field "$j" '.zone')
[ -z "$zone" ] && exit 0
[ "$zone" = "unknown" ] && exit 0

THROTTLE=$(jq -r '.ratelimit.throttle_seconds // 75' "$CONFIG" 2>/dev/null); THROTTLE=${THROTTLE:-75}
STATE_DIR="$HOME/.cache/claude"; mkdir -p "$STATE_DIR" 2>/dev/null
STATE="$STATE_DIR/harness-guard.state"
now=$(date +%s)

last_zone="ok"; last_ts=0
if [ -s "$STATE" ]; then read -r last_zone last_ts <"$STATE" 2>/dev/null; fi
last_zone=${last_zone:-ok}; last_ts=${last_ts:-0}

rank=$(zone_rank "$zone"); lrank=$(zone_rank "$last_zone")

# Zona ok: solo persistir y salir silencioso.
if [ "$zone" = "ok" ]; then
  printf '%s %s\n' "$zone" "$last_ts" >"$STATE" 2>/dev/null
  exit 0
fi

notify=0
if [ "$rank" -gt "$lrank" ]; then
  notify=1                                   # (a) cruce hacia arriba
elif [ "$rank" -ge 2 ] && [ $(( now - last_ts )) -ge "$THROTTLE" ]; then
  notify=1                                   # (b) recordatorio periódico en danger/hard
fi

if [ "$notify" = "1" ]; then
  printf '%s %s\n' "$zone" "$now" >"$STATE" 2>/dev/null
  pct=$(usage_field "$j" '.pct'); rmin=$(usage_field "$j" '.resets_in_min')
  # Red de seguridad mecánica: en danger/hard, snapshot a disco por script
  # (no depende de que el agente escriba el handoff).
  [ "$rank" -ge 2 ] && write_snapshot "$pct" "$zone"
  txt=$(nudge_text "$zone" "$pct" "$rmin")
  [ -n "$txt" ] && emit_context "PostToolUse" "$txt"
else
  printf '%s %s\n' "$zone" "$last_ts" >"$STATE" 2>/dev/null
fi
exit 0
