#!/usr/bin/env bash
# .harness/bin/usage.sh — Fuente UNIFICADA del rate limit de 5h de Claude Code.
#
# Estrategia (decidida en el plan del harness):
#   1) PRIMARIA  → lee ~/.cache/claude/ratelimit.json, que el statusline de
#      Claude Code escribe en cada render + cada refreshInterval (60s). Es el
#      MISMO dato vivo que Claude Code pasa por stdin al statusline. Costo cero,
#      sin red, fresco incluso a mitad de una corrida autónoma.
#   2) FALLBACK  → si el cache falta o está viejo (> cache_max_age_seconds),
#      pega a la API OAuth (api.anthropic.com/api/oauth/usage) refrescando el
#      token si hace falta. Mismo endpoint que usa el módulo de Waybar.
#
# Salida: JSON en una línea →
#   {"pct":87,"resets_at":1782658200,"resets_in_min":42,"zone":"danger",
#    "stale":false,"source":"cache"}
#
# zone ∈ ok|warn|danger|hard, según los umbrales de .harness/config.json.
# Uso: bash .harness/bin/usage.sh            (JSON)
#      bash .harness/bin/usage.sh --human    (línea legible)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG="$HARNESS_DIR/config.json"

command -v jq >/dev/null 2>&1 || { echo '{"error":"jq no instalado"}'; exit 1; }

# ---- Leer config en UNA sola pasada de jq (con defaults si falta) ----------
IFS=$'\t' read -r WARN DANGER HARD MAXAGE CACHE_RAW < <(jq -r \
  '[.ratelimit.thresholds.warn, .ratelimit.thresholds.danger, .ratelimit.thresholds.hard,
    .ratelimit.cache_max_age_seconds, .ratelimit.cache_path] | @tsv' "$CONFIG" 2>/dev/null)
WARN=${WARN:-75}; DANGER=${DANGER:-85}; HARD=${HARD:-94}; MAXAGE=${MAXAGE:-180}
CACHE_RAW=${CACHE_RAW:-~/.cache/claude/ratelimit.json}
CACHE="${CACHE_RAW/#\~/$HOME}"

now=$(date +%s)

zone_of() {  # arg: pct(int)
  local p=$1
  if   [ "$p" -ge "$HARD" ];   then echo "hard"
  elif [ "$p" -ge "$DANGER" ]; then echo "danger"
  elif [ "$p" -ge "$WARN" ];   then echo "warn"
  else echo "ok"; fi
}

emit() {  # args: pct resets_at stale source
  local pct="$1" reset="$2" stale="$3" source="$4" zone rmin
  zone=$(zone_of "$pct")
  rmin="null"
  if [ -n "$reset" ] && [ "$reset" != "null" ] && [ "$reset" -gt 0 ] 2>/dev/null; then
    rmin=$(( (reset - now) / 60 )); [ "$rmin" -lt 0 ] && rmin=0
  fi
  if [ "${HUMAN:-0}" = "1" ]; then
    local src_lbl="$source"; [ "$stale" = "true" ] && src_lbl="$source(stale)"
    printf '5h: %s%% · zona %s · reset en %s min · [%s]\n' "$pct" "$zone" "$rmin" "$src_lbl"
  else
    jq -nc --argjson pct "$pct" \
           --arg reset "${reset:-null}" \
           --argjson rmin "$rmin" \
           --arg zone "$zone" \
           --argjson stale "$stale" \
           --arg source "$source" \
           '{pct:$pct, resets_at:($reset|tonumber? // null), resets_in_min:$rmin,
             zone:$zone, stale:$stale, source:$source}'
  fi
  exit 0
}

# Flags: --human (salida legible) · --cache-only (NUNCA toca la red; para hooks
# que corren por cada tool call, donde un fallback a API sería caro/contraproducente).
for a in "$@"; do case "$a" in --human) HUMAN=1;; --cache-only) CACHE_ONLY=1;; esac; done

# ---- 1) Cache (primaria) ----------------------------------------------------
read_cache() {  # echoes "pct reset age" o nada
  [ -s "$CACHE" ] || return 1
  local pct reset mtime age
  IFS=$'\t' read -r pct reset < <(jq -r '[.five_hour.used_percentage, .five_hour.resets_at] | @tsv' "$CACHE" 2>/dev/null)
  [ -n "$pct" ] || return 1
  mtime=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)
  age=$(( now - mtime ))
  echo "${pct%.*} ${reset:-null} $age"
}

if cache_data=$(read_cache); then
  read -r c_pct c_reset c_age <<<"$cache_data"
  if [ "$c_age" -le "$MAXAGE" ]; then
    emit "$c_pct" "$c_reset" false cache
  fi
  # cache viejo: intentamos fallback, pero lo guardamos por si la API falla
  STALE_PCT="$c_pct"; STALE_RESET="$c_reset"
fi

# ---- 2) Fallback: API OAuth -------------------------------------------------
CREDS="$HOME/.claude/.credentials.json"
CID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
TOKEN_URL="https://console.anthropic.com/v1/oauth/token"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"

api_fallback() {
  [ -s "$CREDS" ] || return 1
  command -v curl >/dev/null 2>&1 || return 1
  local ACCESS rt resp code body
  ACCESS=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
  [ -n "$ACCESS" ] || return 1

  call() {
    curl -sS --max-time 6 -w $'\n%{http_code}' \
      -H "Authorization: Bearer $ACCESS" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "anthropic-version: 2023-06-01" \
      "$USAGE_URL" 2>/dev/null
  }
  resp=$(call); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')

  if [ "$code" = "401" ]; then
    rt=$(jq -r '.claudeAiOauth.refreshToken // empty' "$CREDS" 2>/dev/null)
    [ -n "$rt" ] || return 1
    local rresp at newrt expin exp_ms tmp
    rresp=$(curl -sS --max-time 10 -X POST "$TOKEN_URL" -H 'Content-Type: application/json' \
      -d "$(jq -nc --arg rt "$rt" --arg cid "$CID" '{grant_type:"refresh_token",refresh_token:$rt,client_id:$cid}')" 2>/dev/null)
    at=$(echo "$rresp" | jq -r '.access_token // empty' 2>/dev/null)
    [ -n "$at" ] || return 1
    newrt=$(echo "$rresp" | jq -r '.refresh_token // empty' 2>/dev/null)
    expin=$(echo "$rresp" | jq -r '.expires_in // 3600' 2>/dev/null)
    exp_ms=$(( (now + expin) * 1000 ))
    tmp=$(mktemp)
    if jq --arg at "$at" --arg rt "${newrt:-$rt}" --argjson exp "$exp_ms" \
         '.claudeAiOauth.accessToken=$at | .claudeAiOauth.refreshToken=$rt | .claudeAiOauth.expiresAt=$exp' \
         "$CREDS" >"$tmp" 2>/dev/null; then
      chmod 600 "$tmp" 2>/dev/null; mv "$tmp" "$CREDS"; ACCESS="$at"
    else rm -f "$tmp"; fi
    resp=$(call); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')
  fi

  [ "$code" = "200" ] || return 1
  local pct reset
  pct=$(echo "$body" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  reset=$(echo "$body" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
  [ -n "$pct" ] || return 1
  # resets_at de la API es ISO → epoch
  local reset_epoch="null"
  [ -n "$reset" ] && reset_epoch=$(date -d "$reset" +%s 2>/dev/null || echo null)
  API_PCT="${pct%.*}"; API_RESET="$reset_epoch"; return 0
}

if [ "${CACHE_ONLY:-0}" != "1" ] && api_fallback; then
  emit "$API_PCT" "$API_RESET" false api
fi

# ---- 3) Degradación: cache viejo, o nada -----------------------------------
if [ -n "${STALE_PCT:-}" ]; then
  emit "$STALE_PCT" "${STALE_RESET:-null}" true cache
fi

# Sin ningún dato usable
if [ "${HUMAN:-0}" = "1" ]; then
  echo "5h: desconocido (sin cache ni API; ¿statusline instalado? ¿login?)"
else
  echo '{"pct":null,"resets_at":null,"resets_in_min":null,"zone":"unknown","stale":true,"source":"none"}'
fi
exit 0
