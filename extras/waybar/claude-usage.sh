#!/usr/bin/env bash
# Waybar custom module: Claude Code 5-hour rate limit — LIVE from the API.
# Calls https://api.anthropic.com/api/oauth/usage with the OAuth access token
# from ~/.claude/.credentials.json. Refreshes the token on 401 (rotating it,
# written back atomically). Account-wide usage, so it reflects other machines
# (e.g. a VPS) too. On any unrecoverable error it shows a visible ⚠ — never a
# silent stale value.
#
# Output: Waybar JSON {text, tooltip, class}

creds="$HOME/.claude/.credentials.json"
cache_dir="$HOME/.cache/claude"; cache="$cache_dir/usage.json"
out_cache="$cache_dir/output.json"
mkdir -p "$cache_dir" 2>/dev/null
THROTTLE=90   # s mínimos entre llamadas reales a la API (clicks usan cache)
BRAND="#d97757"
NAME="<span size='small' alpha='75%' color='${BRAND}'>CLAUDE</span>"
WARN="<span color='#cc6666'>⚠</span>"

# Servir el último resultado real (éxito o error) si es reciente: evita spam
# de requests al togglear/clickear y respeta el rate limit agresivo del endpoint.
if [ -f "$out_cache" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$out_cache" 2>/dev/null || echo 0) ))
  [ "$age" -lt "$THROTTLE" ] && { cat "$out_cache"; exit 0; }
fi

# 5-segment mini progress bar for a 0-100 percentage.
bar5() {
  local p=$1 filled i out=""
  filled=$(( (p + 10) / 20 )); [ "$filled" -gt 5 ] && filled=5; [ "$filled" -lt 0 ] && filled=0
  for ((i=0;i<5;i++)); do [ "$i" -lt "$filled" ] && out="${out}▰" || out="${out}▱"; done
  printf '%s' "$out"
}
CID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
TOKEN_URL="https://console.anthropic.com/v1/oauth/token"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"

emit() { jq -nc --arg t "$1" --arg tip "$2" --arg c "$3" \
         '{text:$t,tooltip:$tip,class:$c}' | tee "$out_cache"; exit 0; }

emit_error() {
  local extra=""
  if [ -s "$cache" ]; then
    local cp ct
    cp=$(jq -r '.pct // empty' "$cache" 2>/dev/null)
    ct=$(jq -r '.ts // empty' "$cache" 2>/dev/null)
    [ -n "$cp" ] && extra=$'\n'"último dato OK: ${cp}% ($(date -d "@${ct}" '+%d %b %H:%M' 2>/dev/null))"
  fi
  emit "$NAME $WARN" "Claude — error: $1$extra" "critical"
}

# Para errores transitorios (p.ej. 429): mostrar el último % conocido atenuado
# si es reciente (<30 min); si no hay dato usable, caer al ⚠.
emit_cached_or_error() {
  local reason="$1" cp ct age cls bar mins
  if [ -s "$cache" ]; then
    cp=$(jq -r '.pct // empty' "$cache" 2>/dev/null)
    ct=$(jq -r '.ts // empty' "$cache" 2>/dev/null)
    if [ -n "$cp" ] && [ -n "$ct" ]; then
      age=$(( $(date +%s) - ct ))
      if [ "$age" -lt 1800 ]; then
        if   [ "$cp" -ge 85 ]; then cls="critical"
        elif [ "$cp" -ge 60 ]; then cls="warning"
        else                        cls="ok"; fi
        bar=$(bar5 "$cp"); mins=$(( age / 60 ))
        emit "$NAME <span size='small' alpha='35%' color='${BRAND}'>${bar}</span> <span size='small' alpha='35%'>${cp}%</span>" \
             "Claude — $reason · mostrando último dato (hace ${mins}m)" "$cls"
      fi
    fi
  fi
  emit_error "$reason"
}

command -v jq >/dev/null || { echo '{"text":"CLAUDE ⚠","tooltip":"falta jq","class":"critical"}'; exit 0; }
[ -s "$creds" ] || emit_error "no hay credenciales (~/.claude/.credentials.json)"

ACCESS=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds")
[ -n "$ACCESS" ] || emit_error "sin access token (iniciá sesión en Claude Code)"

# Refresh the OAuth token (rotating). Writes back merged + atomic. Sets $ACCESS.
refresh_token() {
  local rt resp at newrt expin exp_ms tmp
  rt=$(jq -r '.claudeAiOauth.refreshToken // empty' "$creds")
  [ -n "$rt" ] || return 1
  resp=$(curl -sS --max-time 10 -X POST "$TOKEN_URL" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg rt "$rt" --arg cid "$CID" \
          '{grant_type:"refresh_token",refresh_token:$rt,client_id:$cid}')" 2>/dev/null)
  at=$(echo "$resp" | jq -r '.access_token // empty' 2>/dev/null)
  [ -n "$at" ] || return 1
  newrt=$(echo "$resp" | jq -r '.refresh_token // empty' 2>/dev/null)
  expin=$(echo "$resp" | jq -r '.expires_in // 3600' 2>/dev/null)
  exp_ms=$(( ($(date +%s) + expin) * 1000 ))
  [ -f "$creds.bak" ] || cp -p "$creds" "$creds.bak" 2>/dev/null
  tmp=$(mktemp)
  if jq --arg at "$at" --arg rt "${newrt:-$rt}" --argjson exp "$exp_ms" \
       '.claudeAiOauth.accessToken=$at | .claudeAiOauth.refreshToken=$rt | .claudeAiOauth.expiresAt=$exp' \
       "$creds" > "$tmp" 2>/dev/null; then
    chmod 600 "$tmp" 2>/dev/null; mv "$tmp" "$creds"
    ACCESS="$at"; return 0
  fi
  rm -f "$tmp"; return 1
}

# GET usage; echoes "BODY<newline>HTTPCODE"
call_usage() {
  curl -sS --max-time 6 -w $'\n%{http_code}' \
    -H "Authorization: Bearer $ACCESS" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "anthropic-version: 2023-06-01" \
    "$USAGE_URL" 2>/dev/null
}

resp=$(call_usage); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')

if [ "$code" = "401" ]; then
  refresh_token && { resp=$(call_usage); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d'); } \
                || emit_error "token expirado y no se pudo refrescar (re-login)"
fi

[ "$code" = "200" ] || emit_cached_or_error "HTTP $code (rate-limited?)"

pct=$(echo "$body" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
reset_iso=$(echo "$body" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
wpct=$(echo "$body" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
wreset_iso=$(echo "$body" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

[ -n "$pct" ] || emit_error "respuesta sin five_hour.utilization"

pct_int=${pct%.*}; [ -z "$pct_int" ] && pct_int=0
if   [ "$pct_int" -ge 85 ]; then cls="critical"
elif [ "$pct_int" -ge 60 ]; then cls="warning"
else                              cls="ok"; fi

reset_hm="?"; [ -n "$reset_iso" ] && reset_hm=$(date -d "$reset_iso" +%H:%M 2>/dev/null || echo "?")

# cache last good value
jq -nc --arg pct "$pct_int" --arg ts "$(date +%s)" '{pct:$pct,ts:$ts}' > "$cache" 2>/dev/null

tip="Claude Code · 5h: ${pct_int}% usado"
[ "$reset_hm" != "?" ] && tip="${tip} · reset ${reset_hm}"
if [ -n "$wpct" ]; then
  wpct_int=${wpct%.*}
  tip="${tip}"$'\n'"semanal: ${wpct_int}% usado"
  [ -n "$wreset_iso" ] && tip="${tip} · reset $(date -d "$wreset_iso" '+%d %b %H:%M' 2>/dev/null)"
fi

bar=$(bar5 "$pct_int")
emit "$NAME <span size='small' alpha='90%' color='${BRAND}'>${bar}</span> <span size='small'>${pct_int}%</span>" "$tip" "$cls"
