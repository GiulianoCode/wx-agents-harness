#!/usr/bin/env bash
# install.sh — instala/actualiza el harness en un proyecto (nuevo o EXISTENTE).
#
# Uso:
#   bash /ruta/al/wx-harness-template/install.sh <dir-del-proyecto>
#
# Idempotente y merge-aware:
#   - Maquinaria del harness (.claude/hooks|commands|agents|skills, .harness/bin|
#     profiles, specs/_TEMPLATE): se copia/actualiza (harness-owned).
#   - Datos del usuario (.harness/config.json, feature_list.json, progress/*):
#     se crean solo si NO existen (no se pisan).
#   - Colisiones que se FUSIONAN: .claude/settings.json (jq: hooks+permisos) y .gitignore.
#   - Narrativos que NO se pisan: CLAUDE.md, AGENTS.md → se dejan como *.harness al
#     lado y se marcan para mergear con /adopt. init.sh y docs colisionantes idem.
#
# Tras correrlo: abrí Claude Code en el proyecto, aprobá los hooks y corré /adopt.
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TGT="${1:-}"

c_ok="\033[32m"; c_warn="\033[33m"; c_info="\033[36m"; c_off="\033[0m"
ok()   { printf "  ${c_ok}✓${c_off} %s\n" "$1"; }
skip() { printf "  ${c_info}·${c_off} %s\n" "$1"; }
warn() { printf "  ${c_warn}!${c_off} %s\n" "$1"; WARNINGS=$((WARNINGS+1)); }
sec()  { printf "\n\033[1m%s\033[0m\n" "$1"; }
WARNINGS=0; TOMERGE=()

# ---- Validación ----
[ -n "$TGT" ] || { echo "Uso: bash install.sh <dir-del-proyecto>"; exit 2; }
mkdir -p "$TGT" 2>/dev/null
TGT="$(cd "$TGT" && pwd)" || { echo "No se pudo acceder a $1"; exit 2; }
[ "$SRC" != "$TGT" ] || { echo "El destino no puede ser el propio template ($SRC)."; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "Falta jq (necesario para fusionar settings.json)."; exit 1; }

echo "Instalando harness"
echo "  origen:  $SRC"
echo "  destino: $TGT"

# ---- Helpers ----
# Copia harness-owned (crea dir, sobreescribe el archivo: es del harness).
copy_owned() { # <relpath>
  local rel="$1" s="$SRC/$1" d="$TGT/$1"
  [ -e "$s" ] || return 0
  mkdir -p "$(dirname "$d")"
  if [ -d "$s" ]; then cp -r "$s/." "$d/"; else cp "$s" "$d"; fi
  ok "$rel"
}
# Copia solo si NO existe (datos del usuario).
copy_if_absent() { # <relpath>
  local rel="$1" s="$SRC/$1" d="$TGT/$1"
  [ -e "$s" ] || return 0
  if [ -e "$d" ]; then skip "$rel (ya existe, conservado)"; return 0; fi
  mkdir -p "$(dirname "$d")"; cp -r "$s" "$d"; ok "$rel (creado)"
}
# Narrativo: si existe en destino y difiere, dejar copia .harness al lado.
copy_narrative() { # <relpath>
  local rel="$1" s="$SRC/$1" d="$TGT/$1"
  [ -e "$s" ] || return 0
  if [ ! -e "$d" ]; then mkdir -p "$(dirname "$d")"; cp "$s" "$d"; ok "$rel (creado)"; return 0; fi
  if cmp -s "$s" "$d"; then skip "$rel (idéntico)"; return 0; fi
  cp "$s" "$d.harness"; warn "$rel ya existe → dejé '$rel.harness' para mergear"; TOMERGE+=("$rel")
}

# ---- Maquinaria del harness (harness-owned) ----
sec "Maquinaria del harness"
copy_owned ".claude/hooks"
copy_owned ".claude/commands"
copy_owned ".claude/agents"
copy_owned ".claude/skills"
copy_owned ".harness/bin"
copy_owned ".harness/profiles"
copy_owned ".harness/config.schema.json"
copy_owned "specs/_TEMPLATE"
copy_owned "CHECKPOINTS.md"

# ---- Datos del usuario (crear solo si faltan) ----
sec "Estado del proyecto (no se pisa)"
copy_if_absent ".harness/config.json"
copy_if_absent "feature_list.json"
copy_if_absent "progress/current.md"
copy_if_absent "progress/history.md"

# ---- init.sh ----
sec "Verificación"
if [ ! -e "$TGT/init.sh" ]; then cp "$SRC/init.sh" "$TGT/init.sh"; chmod +x "$TGT/init.sh"; ok "init.sh (creado)"
elif cmp -s "$SRC/init.sh" "$TGT/init.sh"; then skip "init.sh (idéntico)"
else cp "$SRC/init.sh" "$TGT/init.harness.sh"; chmod +x "$TGT/init.harness.sh"; warn "init.sh ya existe → dejé 'init.harness.sh'"; fi

# ---- docs del harness (no pisar los del proyecto) ----
sec "Docs del harness"
mkdir -p "$TGT/docs"
for f in architecture conventions specs verification rate-limit-handoff agent-browser; do
  s="$SRC/docs/$f.md"; d="$TGT/docs/$f.md"
  [ -e "$s" ] || continue
  if [ ! -e "$d" ]; then cp "$s" "$d"; ok "docs/$f.md"
  elif cmp -s "$s" "$d"; then skip "docs/$f.md (idéntico)"
  else cp "$s" "$d.harness"; warn "docs/$f.md ya existe → dejé 'docs/$f.md.harness'"; fi
done

# ---- Narrativos ----
sec "Contratos de agente"
copy_narrative "CLAUDE.md"
copy_narrative "AGENTS.md"

# ---- Merge: .claude/settings.json ----
sec "Fusión de settings.json (hooks + permisos)"
HS="$SRC/.claude/settings.json"; TS="$TGT/.claude/settings.json"
mkdir -p "$TGT/.claude"
if [ ! -e "$TS" ]; then
  cp "$HS" "$TS"; ok ".claude/settings.json (creado)"
else
  tmp="$(mktemp)"
  if jq -s '
    .[0] as $e | .[1] as $h |
    $e
    | .["$schema"]          = ($e["$schema"] // $h["$schema"])
    | .includeCoAuthoredBy  = ($e.includeCoAuthoredBy // $h.includeCoAuthoredBy)
    | .permissions          = (($e.permissions // {}) | .allow = ((((.allow // []) + ($h.permissions.allow // []))) | unique))
    | .hooks = (
        ( ($e.hooks // {}) | with_entries(.value |= map(
            select( ((.hooks // []) | map(.command // "")
                     | any(test("\\.claude/hooks/(session-resume|prompt-usage|ratelimit-guard)\\.sh"))) | not )
          )) ) as $clean
        | reduce (($h.hooks // {}) | keys[]) as $k ($clean; .[$k] = ((.[$k] // []) + $h.hooks[$k]))
      )
  ' "$TS" "$HS" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
    mv "$tmp" "$TS"; ok ".claude/settings.json (hooks+permisos fusionados, idempotente)"
  else
    rm -f "$tmp"; cp "$HS" "$TS.harness"; warn "no pude fusionar settings.json → dejé '.claude/settings.json.harness'"; TOMERGE+=(".claude/settings.json")
  fi
fi

# ---- Merge: .gitignore ----
sec "Fusión de .gitignore"
HG="$SRC/.gitignore"; TG="$TGT/.gitignore"
if [ -e "$HG" ]; then
  if [ ! -e "$TG" ]; then cp "$HG" "$TG"; ok ".gitignore (creado)"
  else
    added=0
    while IFS= read -r line; do
      [ -z "$line" ] && continue; case "$line" in \#*) continue;; esac
      grep -qxF "$line" "$TG" 2>/dev/null || { printf '%s\n' "$line" >> "$TG"; added=$((added+1)); }
    done < "$HG"
    [ "$added" -gt 0 ] && ok ".gitignore (+$added líneas)" || skip ".gitignore (sin cambios)"
  fi
fi

# ---- Reporte ----
sec "Listo"
echo "  Próximos pasos:"
echo "   1. Abrí Claude Code en el proyecto y APROBÁ los hooks cuando lo pida."
echo "   2. Corré  /adopt  para fusionar contratos, detectar stack/tests y verificar."
if [ "${#TOMERGE[@]}" -gt 0 ]; then
  echo
  warn "Archivos que requieren merge manual o vía /adopt:"
  for f in "${TOMERGE[@]}"; do echo "     - $f  (comparar con $f.harness)"; done
fi
[ "$WARNINGS" -eq 0 ] && echo "  Sin advertencias." || true
exit 0
