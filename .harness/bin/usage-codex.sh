#!/usr/bin/env bash
# .harness/bin/usage-codex.sh — rate limit de 5h de Codex, formato UNIFICADO
# (mismo shape que usage.sh) para que el AGENTS.md pueda instruir a Codex a
# autoconsultarse "a su manera".
#
# Codex no tiene un statusline que cachee el dato (como Claude), así que la
# fuente es la API wham/usage con refresh de token. Se cachea localmente la
# última lectura buena (cache_max_age_seconds) para no pegarle a cada rato.
#
# Salida JSON: {"pct":..,"resets_at":..,"resets_in_min":..,"zone":..,"stale":..,"source":"api|cache"}
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$(cd "$SCRIPT_DIR/.." && pwd)/config.json"
command -v jq >/dev/null 2>&1 || { echo '{"error":"jq no instalado"}'; exit 1; }

cfg() { jq -r "$1 // empty" "$CONFIG" 2>/dev/null; }
WARN=$(cfg '.ratelimit.thresholds.warn');     WARN=${WARN:-75}
DANGER=$(cfg '.ratelimit.thresholds.danger'); DANGER=${DANGER:-85}
HARD=$(cfg '.ratelimit.thresholds.hard');     HARD=${HARD:-94}
MAXAGE=$(cfg '.ratelimit.cache_max_age_seconds'); MAXAGE=${MAXAGE:-180}

now=$(date +%s)
CACHE_DIR="$HOME/.cache/codex"; mkdir -p "$CACHE_DIR" 2>/dev/null
HCACHE="$CACHE_DIR/harness-usage.json"
CREDS="$HOME/.codex/auth.json"
CID="app_EMoamEEZ73f0CkXaXp7hrann"
TOKEN_URL="https://auth.openai.com/oauth/token"
USAGE_URL="https://chatgpt.com/backend-api/wham/usage"

zone_of() { local p=$1
  if [ "$p" -ge "$HARD" ]; then echo hard; elif [ "$p" -ge "$DANGER" ]; then echo danger
  elif [ "$p" -ge "$WARN" ]; then echo warn; else echo ok; fi; }

emit() { local pct="$1" reset="$2" stale="$3" source="$4" zone rmin
  zone=$(zone_of "$pct"); rmin="null"
  if [ -n "$reset" ] && [ "$reset" != "null" ] && [ "$reset" -gt 0 ] 2>/dev/null; then
    rmin=$(( (reset - now)/60 )); [ "$rmin" -lt 0 ] && rmin=0; fi
  jq -nc --argjson pct "$pct" --arg reset "${reset:-null}" --argjson rmin "$rmin" \
         --arg zone "$zone" --argjson stale "$stale" --arg source "$source" \
    '{pct:$pct,resets_at:($reset|tonumber? // null),resets_in_min:$rmin,zone:$zone,stale:$stale,source:$source}'
  exit 0; }

# Cache local fresco
if [ -s "$HCACHE" ]; then
  cp=$(jq -r '.pct // empty' "$HCACHE" 2>/dev/null)
  cr=$(jq -r '.resets_at // empty' "$HCACHE" 2>/dev/null)
  mt=$(stat -c %Y "$HCACHE" 2>/dev/null || echo 0)
  if [ -n "$cp" ] && [ $(( now - mt )) -le "$MAXAGE" ]; then emit "$cp" "${cr:-null}" false cache; fi
fi

[ -s "$CREDS" ] || { echo '{"pct":null,"zone":"unknown","stale":true,"source":"none","error":"sin ~/.codex/auth.json (corré: codex login)"}'; exit 0; }
command -v curl >/dev/null 2>&1 || { echo '{"pct":null,"zone":"unknown","stale":true,"source":"none","error":"sin curl"}'; exit 0; }

ACCESS=$(jq -r '.tokens.access_token // empty' "$CREDS")
ACCID=$(jq -r '.tokens.account_id // empty' "$CREDS")
call() { curl -sS --max-time 6 -w $'\n%{http_code}' -H "Authorization: Bearer $ACCESS" -H "ChatGPT-Account-Id: $ACCID" "$USAGE_URL" 2>/dev/null; }
resp=$(call); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')

if [ "$code" = "401" ]; then
  rt=$(jq -r '.tokens.refresh_token // empty' "$CREDS")
  if [ -n "$rt" ]; then
    rr=$(curl -sS --max-time 10 -X POST "$TOKEN_URL" -H 'Content-Type: application/json' \
      -d "$(jq -nc --arg rt "$rt" --arg cid "$CID" '{grant_type:"refresh_token",refresh_token:$rt,client_id:$cid,scope:"openid profile email"}')" 2>/dev/null)
    at=$(echo "$rr" | jq -r '.access_token // empty')
    if [ -n "$at" ]; then
      newrt=$(echo "$rr" | jq -r '.refresh_token // empty'); tmp=$(mktemp)
      jq --arg at "$at" --arg rt "${newrt:-$rt}" '.tokens.access_token=$at|.tokens.refresh_token=$rt' "$CREDS" >"$tmp" 2>/dev/null \
        && { chmod 600 "$tmp"; mv "$tmp" "$CREDS"; ACCESS="$at"; } || rm -f "$tmp"
      resp=$(call); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')
    fi
  fi
fi

[ "$code" = "200" ] || { echo "{\"pct\":null,\"zone\":\"unknown\",\"stale\":true,\"source\":\"none\",\"error\":\"HTTP $code\"}"; exit 0; }

pct=$(echo "$body" | jq -r '(.primary.used_percent // .rate_limits.primary.used_percent // .primary_window.used_percent // .usage.primary.used_percent // empty)' 2>/dev/null)
reset=$(echo "$body" | jq -r '(.primary.resets_at // .rate_limits.primary.resets_at // .primary_window.resets_at // .primary.reset_at // empty)' 2>/dev/null)
[ -n "$pct" ] || { echo '{"pct":null,"zone":"unknown","stale":true,"source":"none","error":"formato wham/usage no reconocido"}'; exit 0; }
pct=${pct%.*}
reset_epoch="null"
if [ -n "$reset" ]; then
  if [[ "$reset" =~ ^[0-9]+$ ]]; then reset_epoch="$reset"; else reset_epoch=$(date -d "$reset" +%s 2>/dev/null || echo null); fi
fi
jq -nc --argjson pct "$pct" --arg reset "$reset_epoch" '{pct:$pct,resets_at:($reset|tonumber? // null)}' >"$HCACHE" 2>/dev/null
emit "$pct" "$reset_epoch" false api
