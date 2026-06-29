#!/usr/bin/env bash
# .harness/bin/usage.sh — Fuente UNIFICADA del rate limit de Claude Code.
# Evalúa DOS ventanas: 5h (five_hour) y SEMANAL (seven_day). La semanal es más
# estricta: si se agota, Claude queda sin cuota por DÍAS, no horas.
#
# Estrategia:
#   1) PRIMARIA  → ~/.cache/claude/ratelimit.json (lo escribe el statusline en cada
#      render). Costo cero, sin red. Trae five_hour Y seven_day.
#   2) FALLBACK  → API OAuth si el cache falta o está viejo (> cache_max_age_seconds).
#
# Salida JSON (la ventana "binding" = la peor de las dos en top-level):
#   {"zone":"danger","window":"seven_day","pct":90,"resets_in_min":4321,
#    "five_hour":{"pct":84,"zone":"warn","resets_in_min":12},
#    "seven_day":{"pct":90,"zone":"danger","resets_in_min":4321},
#    "stale":false,"source":"cache"}
#
# Flags: --human (legible) · --cache-only (NUNCA toca la red; para hooks por tool call)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$(cd "$SCRIPT_DIR/.." && pwd)/config.json"
command -v jq >/dev/null 2>&1 || { echo '{"error":"jq no instalado"}'; exit 1; }

IFS=$'\t' read -r W5 D5 H5 WW DW HW MAXAGE CACHE_RAW < <(jq -r '[
  .ratelimit.thresholds.warn, .ratelimit.thresholds.danger, .ratelimit.thresholds.hard,
  .ratelimit.weekly_thresholds.warn, .ratelimit.weekly_thresholds.danger, .ratelimit.weekly_thresholds.hard,
  .ratelimit.cache_max_age_seconds, .ratelimit.cache_path] | @tsv' "$CONFIG" 2>/dev/null)
W5=${W5:-75}; D5=${D5:-85}; H5=${H5:-94}
WW=${WW:-80}; DW=${DW:-90}; HW=${HW:-96}
MAXAGE=${MAXAGE:-180}
CACHE_RAW=${CACHE_RAW:-~/.cache/claude/ratelimit.json}
CACHE="${CACHE_RAW/#\~/$HOME}"
now=$(date +%s)

for a in "$@"; do case "$a" in --human) HUMAN=1;; --cache-only) CACHE_ONLY=1;; esac; done

zone_of() { # pct warn danger hard
  local p=$1 w=$2 d=$3 h=$4
  [ -z "$p" ] && { echo unknown; return; }
  if   [ "$p" -ge "$h" ]; then echo hard
  elif [ "$p" -ge "$d" ]; then echo danger
  elif [ "$p" -ge "$w" ]; then echo warn
  else echo ok; fi
}
rank() { case "$1" in ok)echo 0;; warn)echo 1;; danger)echo 2;; hard)echo 3;; *)echo -1;; esac; }
rmin_of() { local r=$1; { [ -n "$r" ] && [ "$r" != "null" ] && [ "$r" -gt 0 ] 2>/dev/null; } \
  && { local m=$(( (r-now)/60 )); [ "$m" -lt 0 ] && m=0; echo "$m"; } || echo null; }
# Una ventana cuyo resets_at ya pasó "rodó": el % cacheado es del período viejo y no
# es de fiar (la ventana real arranca casi en 0). No alarmar con ese dato.
rolled_over() { local r=$1; [ -n "$r" ] && [ "$r" != "null" ] && [ "$r" -le "$now" ] 2>/dev/null; }

emit() { # five_pct five_reset week_pct week_reset stale source
  local fp="$1" fr="$2" wp="$3" wr="$4" stale="$5" source="$6"
  local fz wz frm wrm bind bz bp brm
  fz=$(zone_of "$fp" "$W5" "$D5" "$H5"); wz=$(zone_of "$wp" "$WW" "$DW" "$HW")
  # Si la ventana ya rodó (resets_at en el pasado), su % es viejo → no alarmar.
  rolled_over "$fr" && fz=ok
  rolled_over "$wr" && wz=ok
  frm=$(rmin_of "$fr"); wrm=$(rmin_of "$wr")
  # binding = peor zona; en empate gana la semanal (consecuencia más dura)
  if [ -n "$wp" ] && [ "$(rank "$wz")" -ge "$(rank "$fz")" ]; then
    bind=seven_day; bz="$wz"; bp="$wp"; brm="$wrm"
  else
    bind=five_hour; bz="$fz"; bp="$fp"; brm="$frm"
  fi
  if [ "${HUMAN:-0}" = "1" ]; then
    local src="$source"; [ "$stale" = "true" ] && src="$source(stale)"
    printf '5h: %s%% (%s) · semanal: %s%% (%s) · binding: %s · [%s]\n' \
      "${fp:-?}" "$fz" "${wp:-?}" "$wz" "$bind" "$src"
  else
    jq -nc \
      --arg bz "$bz" --arg bind "$bind" --argjson bp "${bp:-null}" --argjson brm "${brm:-null}" \
      --argjson fp "${fp:-null}" --arg fz "$fz" --argjson frm "${frm:-null}" \
      --argjson wp "${wp:-null}" --arg wz "$wz" --argjson wrm "${wrm:-null}" \
      --argjson stale "$stale" --arg source "$source" \
      '{zone:$bz, window:$bind, pct:$bp, resets_in_min:$brm,
        five_hour:{pct:$fp, zone:$fz, resets_in_min:$frm},
        seven_day:{pct:$wp, zone:$wz, resets_in_min:$wrm},
        stale:$stale, source:$source}'
  fi
  exit 0
}

# ---- 1) Cache (primaria) ----
if [ -s "$CACHE" ]; then
  IFS=$'\t' read -r FP FR WP WR < <(jq -r '[
    .five_hour.used_percentage, .five_hour.resets_at,
    .seven_day.used_percentage, .seven_day.resets_at] | @tsv' "$CACHE" 2>/dev/null)
  FP=${FP%.*}; WP=${WP%.*}
  if [ -n "$FP" ]; then
    age=$(( now - $(stat -c %Y "$CACHE" 2>/dev/null || echo 0) ))
    [ "$age" -le "$MAXAGE" ] && emit "$FP" "${FR:-null}" "$WP" "${WR:-null}" false cache
    SFP="$FP"; SFR="${FR:-null}"; SWP="$WP"; SWR="${WR:-null}"   # guardar por si la API falla
  fi
fi

# ---- 2) Fallback API ----
CREDS="$HOME/.claude/.credentials.json"
CID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
TOKEN_URL="https://console.anthropic.com/v1/oauth/token"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
api_fallback() {
  [ "${CACHE_ONLY:-0}" = "1" ] && return 1
  [ -s "$CREDS" ] || return 1; command -v curl >/dev/null 2>&1 || return 1
  local ACCESS resp code body
  ACCESS=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
  [ -n "$ACCESS" ] || return 1
  call() { curl -sS --max-time 6 -w $'\n%{http_code}' -H "Authorization: Bearer $ACCESS" \
    -H "anthropic-beta: oauth-2025-04-20" -H "anthropic-version: 2023-06-01" "$USAGE_URL" 2>/dev/null; }
  resp=$(call); code=$(printf '%s' "$resp"|tail -n1); body=$(printf '%s' "$resp"|sed '$d')
  if [ "$code" = "401" ]; then
    local rt at; rt=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS" 2>/dev/null)
    [ -n "$rt" ] || return 1
    local rr; rr=$(curl -sS --max-time 10 -X POST "$TOKEN_URL" -H 'Content-Type: application/json' \
      -d "$(jq -nc --arg rt "$rt" --arg cid "$CID" '{grant_type:"refresh_token",refresh_token:$rt,client_id:$cid}')" 2>/dev/null)
    at=$(echo "$rr"|jq -r '.access_token // empty'); [ -n "$at" ] || return 1
    local nrt; nrt=$(echo "$rr"|jq -r '.refresh_token // empty'); local tmp; tmp=$(mktemp)
    jq --arg at "$at" --arg rt "${nrt:-$rt}" '.claudeAiOauth.accessToken=$at|.claudeAiOauth.refreshToken=$rt' \
      "$CREDS" >"$tmp" 2>/dev/null && { chmod 600 "$tmp"; mv "$tmp" "$CREDS"; ACCESS="$at"; } || rm -f "$tmp"
    resp=$(call); code=$(printf '%s' "$resp"|tail -n1); body=$(printf '%s' "$resp"|sed '$d')
  fi
  [ "$code" = "200" ] || return 1
  local fp wp fr wr
  fp=$(echo "$body"|jq -r '.five_hour.utilization // empty'); [ -n "$fp" ] || return 1
  wp=$(echo "$body"|jq -r '.seven_day.utilization // empty')
  fr=$(echo "$body"|jq -r '.five_hour.resets_at // empty'); wr=$(echo "$body"|jq -r '.seven_day.resets_at // empty')
  AFP=${fp%.*}; AWP=${wp%.*}
  AFR=null; [ -n "$fr" ] && AFR=$(date -d "$fr" +%s 2>/dev/null || echo null)
  AWR=null; [ -n "$wr" ] && AWR=$(date -d "$wr" +%s 2>/dev/null || echo null)
  return 0
}
if api_fallback; then emit "$AFP" "$AFR" "$AWP" "$AWR" false api; fi

# ---- 3) Degradado: cache viejo, o nada ----
[ -n "${SFP:-}" ] && emit "$SFP" "$SFR" "$SWP" "$SWR" true cache
if [ "${HUMAN:-0}" = "1" ]; then echo "5h/semanal: desconocido (sin cache ni API)"; \
else echo '{"zone":"unknown","window":"none","pct":null,"resets_in_min":null,"five_hour":{"pct":null,"zone":"unknown"},"seven_day":{"pct":null,"zone":"unknown"},"stale":true,"source":"none"}'; fi
exit 0
