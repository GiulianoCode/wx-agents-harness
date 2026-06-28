#!/usr/bin/env bash
# .claude/hooks/_common.sh — helpers compartidos por los hooks del harness.
# Se sourcea desde cada hook. No ejecutar directo.

# Raíz del proyecto: Claude Code expone $CLAUDE_PROJECT_DIR a los hooks.
# Fallback: subir dos niveles desde .claude/hooks/.
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
USAGE_BIN="$PROJECT_DIR/.harness/bin/usage.sh"
CONFIG="$PROJECT_DIR/.harness/config.json"
HANDOFF="$PROJECT_DIR/progress/current.md"

have() { command -v "$1" >/dev/null 2>&1; }

# Devuelve el JSON de usage.sh (o vacío si no se puede).
# Pasá --cache-only para que NUNCA toque la red (hooks por tool call).
usage_json() {
  [ -x "$USAGE_BIN" ] || [ -f "$USAGE_BIN" ] || return 1
  have jq || return 1
  bash "$USAGE_BIN" "$@" 2>/dev/null
}

# jq sobre el JSON de usage: usage_field <json> <jq-path>
usage_field() { printf '%s' "$1" | jq -r "$2 // empty" 2>/dev/null; }

zone_rank() { # ok<warn<danger<hard
  case "$1" in ok) echo 0;; warn) echo 1;; danger) echo 2;; hard) echo 3;; *) echo -1;; esac
}

# Emite additionalContext para un hookEventName dado.
emit_context() { # args: <hookEventName> <text>
  jq -nc --arg ev "$1" --arg ctx "$2" \
    '{hookSpecificOutput:{hookEventName:$ev, additionalContext:$ctx}}'
}

# Texto del nudge según zona. args: <zone> <pct> <resets_in_min>
nudge_text() {
  local zone="$1" pct="$2" rmin="$3" reset_lbl=""
  [ -n "$rmin" ] && [ "$rmin" != "null" ] && reset_lbl=" (reset 5h en ${rmin} min)"
  case "$zone" in
    warn)
      printf '⚠ Rate limit de 5h al %s%%%s. Asegurate de que `progress/current.md` exista y refleje la tarea activa: es la base del handoff. Trabajá normal, pero mantené ese archivo vivo.' "$pct" "$reset_lbl" ;;
    danger)
      printf '🟠 Rate limit de 5h al %s%% — ZONA DE PELIGRO%s. A partir de ahora: (1) trabajá en pasos chicos y atómicos, nada de refactors grandes; (2) DESPUÉS de cada paso atómico, escribí/actualizá vos mismo el archivo `progress/current.md` con estado + próximos pasos (es el handoff; hacelo directo con tus tools de edición, no esperes que nadie dispare un comando). El objetivo es que el handoff esté siempre completo en disco por si el límite corta de golpe.' "$pct" "$reset_lbl" ;;
    hard)
      printf '🔴 Rate limit de 5h al %s%% — CRÍTICO%s. PARÁ acá: terminá SOLO el paso atómico actual y, vos mismo, dejá `progress/current.md` completo (estado + próximos pasos + un prompt de continuación para Codex). Escribí ese archivo directamente con tus tools; NO hace falta ningún comando. Avisale al usuario que pase a Codex con ese prompt y NO empieces trabajo nuevo.' "$pct" "$reset_lbl" ;;
    *) printf '' ;;
  esac
}

# Red de seguridad MECÁNICA: escribe un snapshot del estado a disco por script,
# sin depender de que el agente obedezca el nudge. Complementa (no reemplaza) al
# handoff rico que escribe el agente en progress/current.md.
# args: <pct> <zone>
write_snapshot() {
  local out="$PROJECT_DIR/progress/auto-snapshot.md" pct="$1" zone="$2" active=""
  mkdir -p "$PROJECT_DIR/progress" 2>/dev/null
  if [ -f "$PROJECT_DIR/feature_list.json" ] && have jq; then
    active=$(jq -r '(.active // ([.features[]? | select(.status=="in_progress") | .id] | first)) // "—"' \
            "$PROJECT_DIR/feature_list.json" 2>/dev/null)
  fi
  {
    echo "# AUTO-SNAPSHOT — respaldo mecánico (lo genera un hook; NO editar a mano)"
    echo "generado: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "rate_limit_5h: ${pct}% (zona ${zone})"
    echo "feature activa: ${active:-—}"
    echo
    echo "## git status (--short)"
    git -C "$PROJECT_DIR" status --short 2>/dev/null | head -60
    echo
    echo "## cambios sin commitear (diff --stat)"
    git -C "$PROJECT_DIR" diff --stat 2>/dev/null | head -60
    echo
    echo "## últimos commits"
    git -C "$PROJECT_DIR" log --oneline -5 2>/dev/null
    echo
    echo "> Respaldo automático por cercanía al rate limit. El handoff REAL es"
    echo "> progress/current.md (lo escribe el agente, con criterio). Leé ese primero;"
    echo "> usá este snapshot solo si current.md no alcanzó a actualizarse."
  } > "$out" 2>/dev/null
}
