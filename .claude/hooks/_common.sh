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
      printf '🟠 Rate limit de 5h al %s%% — ZONA DE PELIGRO%s. A partir de ahora: (1) trabajá en pasos chicos y atómicos, nada de refactors grandes; (2) DESPUÉS de cada paso atómico, refrescá el handoff con `/handoff` (o actualizando `progress/current.md`). El objetivo es que el handoff esté siempre completo en disco por si el límite corta de golpe.' "$pct" "$reset_lbl" ;;
    hard)
      printf '🔴 Rate limit de 5h al %s%% — CRÍTICO%s. PARÁ acá: terminá SOLO el paso atómico actual, confirmá que `progress/current.md` esté completo (estado + próximos pasos + prompt de continuación para Codex con `/handoff`), avisale al usuario que pase a Codex con ese prompt, y NO empieces trabajo nuevo.' "$pct" "$reset_lbl" ;;
    *) printf '' ;;
  esac
}
