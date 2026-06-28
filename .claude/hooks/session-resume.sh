#!/usr/bin/env bash
# Hook SessionStart — al abrir/resumir una sesión, si hay un handoff ABIERTO en
# progress/current.md lo inyecta como contexto. Cierra el ciclo Claude↔Codex y
# la recuperación tras un corte por rate limit: el agente que arranca retoma
# exactamente donde quedó el anterior.
set -uo pipefail
cat >/dev/null

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

[ -s "$HANDOFF" ] || exit 0
have jq || exit 0

# El handoff lleva una línea "status: open|done". Solo inyectamos si está abierto.
status=$(grep -iE '^status:' "$HANDOFF" 2>/dev/null | head -1 | sed -E 's/^[Ss]tatus:[[:space:]]*//')
case "${status,,}" in
  done|closed|completed) exit 0 ;;
esac

body=$(head -c 8000 "$HANDOFF")
ctx="📋 HANDOFF PENDIENTE detectado en \`progress/current.md\` (status: ${status:-open}). Antes de empezar, leelo entero y retomá desde 'Próximos pasos'. Si completás o invalidás el trabajo, actualizá su estado a 'done'.

--- progress/current.md ---
${body}
--- fin handoff ---"

emit_context "SessionStart" "$ctx"
exit 0
