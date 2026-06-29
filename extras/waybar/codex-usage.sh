#!/usr/bin/env bash
# Waybar custom module: Codex 5-hour rate limit — LIVE from the API.
# Calls https://chatgpt.com/backend-api/wham/usage with the OAuth access token
# from ~/.codex/auth.json. Refreshes the token on 401 (rotating it, written back
# atomically). Account-wide usage, so it reflects other machines (e.g. a VPS).
# On any unrecoverable error it shows a visible ⚠ — never a silent stale value.
#
# Output: Waybar JSON {text, tooltip, class}

creds="$HOME/.codex/auth.json"
cache_dir="$HOME/.cache/codex"; cache="$cache_dir/usage.json"
out_cache="$cache_dir/output.json"
mkdir -p "$cache_dir" 2>/dev/null
THROTTLE=45   # s mínimos entre llamadas reales a la API (clicks usan cache)
BRAND="#6b8cff"
NAME="<span size='small' alpha='75%' color='${BRAND}'>CODEX</span>"
WARN="<span color='#cc6666'>⚠</span>"

# Servir el último resultado real (éxito o error) si es reciente: evita spam
# de requests (refresh + usage = varios segundos) al togglear/clickear.
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
CID="app_EMoamEEZ73f0CkXaXp7hrann"
TOKEN_URL="https://auth.openai.com/oauth/token"
USAGE_URL="https://chatgpt.com/backend-api/wham/usage"

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
  emit "$NAME $WARN" "Codex — error: $1$extra" "critical"
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
             "Codex — $reason · mostrando último dato (hace ${mins}m)" "$cls"
      fi
    fi
  fi
  emit_error "$reason"
}

command -v jq >/dev/null || { echo '{"text":"CODEX ⚠","tooltip":"falta jq","class":"critical"}'; exit 0; }
[ -s "$creds" ] || emit_error "no hay credenciales (~/.codex/auth.json)"

ACCESS=$(jq -r '.tokens.access_token // empty' "$creds")
ACCID=$(jq -r '.tokens.account_id // empty' "$creds")
[ -n "$ACCESS" ] || emit_error "sin access token (corré: codex login)"

# Refresh the OAuth token (rotating). Writes back merged + atomic. Sets $ACCESS.
refresh_token() {
  local rt resp at newrt idt tmp
  rt=$(jq -r '.tokens.refresh_token // empty' "$creds")
  [ -n "$rt" ] || return 1
  resp=$(curl -sS --max-time 10 -X POST "$TOKEN_URL" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg rt "$rt" --arg cid "$CID" \
          '{grant_type:"refresh_token",refresh_token:$rt,client_id:$cid,scope:"openid profile email"}')" 2>/dev/null)
  at=$(echo "$resp" | jq -r '.access_token // empty' 2>/dev/null)
  [ -n "$at" ] || { REFRESH_ERR=$(echo "$resp" | jq -r '.error.code // .error // "fallo desconocido"' 2>/dev/null); return 1; }
  newrt=$(echo "$resp" | jq -r '.refresh_token // empty' 2>/dev/null)
  idt=$(echo "$resp" | jq -r '.id_token // empty' 2>/dev/null)
  [ -f "$creds.bak" ] || cp -p "$creds" "$creds.bak" 2>/dev/null
  tmp=$(mktemp)
  if jq --arg at "$at" --arg rt "${newrt:-$rt}" --arg idt "$idt" --arg lr "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.tokens.access_token=$at | .tokens.refresh_token=$rt
        | (if $idt!="" then .tokens.id_token=$idt else . end) | .last_refresh=$lr' \
       "$creds" > "$tmp" 2>/dev/null; then
    chmod 600 "$tmp" 2>/dev/null; mv "$tmp" "$creds"
    ACCESS="$at"; return 0
  fi
  rm -f "$tmp"; return 1
}

call_usage() {
  curl -sS --max-time 6 -w $'\n%{http_code}' \
    -H "Authorization: Bearer $ACCESS" \
    -H "ChatGPT-Account-Id: $ACCID" \
    "$USAGE_URL" 2>/dev/null
}

resp=$(call_usage); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')

if [ "$code" = "401" ]; then
  if refresh_token; then
    resp=$(call_usage); code=$(printf '%s' "$resp" | tail -n1); body=$(printf '%s' "$resp" | sed '$d')
  else
    emit_error "token expirado, refresh ${REFRESH_ERR:-falló} → corré: codex login"
  fi
fi

[ "$code" = "200" ] || emit_cached_or_error "HTTP $code (rate-limited?)"

# Defensive parsing — wham/usage shape may vary; try several paths.
pct=$(echo "$body" | jq -r '
  (.primary.used_percent // .rate_limits.primary.used_percent //
   .primary_window.used_percent // .usage.primary.used_percent // empty)' 2>/dev/null)
reset=$(echo "$body" | jq -r '
  (.primary.resets_at // .rate_limits.primary.resets_at //
   .primary_window.resets_at // .primary.reset_at // empty)' 2>/dev/null)
wpct=$(echo "$body" | jq -r '
  (.secondary.used_percent // .rate_limits.secondary.used_percent //
   .secondary_window.used_percent // empty)' 2>/dev/null)
wreset=$(echo "$body" | jq -r '
  (.secondary.resets_at // .rate_limits.secondary.resets_at //
   .secondary_window.resets_at // empty)' 2>/dev/null)

[ -n "$pct" ] || emit_error "respuesta no reconocida (revisar formato de wham/usage)"

pct_int=${pct%.*}; [ -z "$pct_int" ] && pct_int=0
if   [ "$pct_int" -ge 85 ]; then cls="critical"
elif [ "$pct_int" -ge 60 ]; then cls="warning"
else                              cls="ok"; fi

# reset may be epoch seconds or ISO string
fmt_time() {
  local v="$1" f="$2"
  [ -z "$v" ] && { echo "?"; return; }
  if [[ "$v" =~ ^[0-9]+$ ]]; then date -d "@${v}" +"$f" 2>/dev/null || echo "?"
  else date -d "$v" +"$f" 2>/dev/null || echo "?"; fi
}
reset_hm=$(fmt_time "$reset" "%H:%M")

jq -nc --arg pct "$pct_int" --arg ts "$(date +%s)" '{pct:$pct,ts:$ts}' > "$cache" 2>/dev/null

tip="Codex · 5h: ${pct_int}% usado"
[ "$reset_hm" != "?" ] && tip="${tip} · reset ${reset_hm}"
if [ -n "$wpct" ]; then
  wpct_int=${wpct%.*}
  tip="${tip}"$'\n'"semanal: ${wpct_int}% usado"
  wr=$(fmt_time "$wreset" "%d %b %H:%M"); [ "$wr" != "?" ] && tip="${tip} · reset ${wr}"
fi

bar=$(bar5 "$pct_int")
emit "$NAME <span size='small' alpha='90%' color='${BRAND}'>${bar}</span> <span size='small'>${pct_int}%</span>" "$tip" "$cls"
