#!/usr/bin/env bash
# Hook SessionStart — al abrir/resumir una sesión, si hay un handoff ABIERTO en
# progress/current.md lo inyecta como contexto. Cierra el ciclo Claude↔Codex y
# la recuperación tras un corte por rate limit: el agente que arranca retoma
# exactamente donde quedó el anterior.
set -uo pipefail
cat >/dev/null

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
have jq || exit 0

SNAP="$PROJECT_DIR/progress/auto-snapshot.md"

# Respaldo mecánico: si NO hay handoff rico abierto pero quedó un auto-snapshot
# reciente (<6h), inyectalo como pista (típico tras un corte por rate limit donde
# el agente no llegó a escribir current.md).
snapshot_fallback() {
  [ -s "$SNAP" ] || exit 0
  local age=$(( $(date +%s) - $(stat -c %Y "$SNAP" 2>/dev/null || echo 0) ))
  [ "$age" -lt 21600 ] || exit 0
  emit_context "SessionStart" "🧷 Sin handoff abierto, pero hay un AUTO-SNAPSHOT reciente (respaldo mecánico, posible corte previo por rate limit). Revisalo para ver en qué andaba el agente anterior:

$(head -c 4000 "$SNAP")"
  exit 0
}

[ -s "$HANDOFF" ] || snapshot_fallback   # sin current.md → probá el snapshot

# El handoff lleva una línea "status: open|done". Solo inyectamos si está abierto.
status=$(grep -iE '^status:' "$HANDOFF" 2>/dev/null | head -1 | sed -E 's/^[Ss]tatus:[[:space:]]*//')
case "${status,,}" in
  done|closed|completed) snapshot_fallback ;;   # handoff cerrado → probá el snapshot
esac

body=$(head -c 8000 "$HANDOFF")
ctx="📋 HANDOFF PENDIENTE detectado en \`progress/current.md\` (status: ${status:-open}). Antes de empezar, leelo entero y retomá desde 'Próximos pasos'. Si completás o invalidás el trabajo, actualizá su estado a 'done'.

--- progress/current.md ---
${body}
--- fin handoff ---"

emit_context "SessionStart" "$ctx"
exit 0
