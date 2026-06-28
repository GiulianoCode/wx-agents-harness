#!/usr/bin/env bash
# init.sh — verificación del harness y del proyecto.
# Sale 0 si todo OK; ≠0 si algo falla. Pensado para correr en cada checkpoint
# y antes de marcar una feature 'done'.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PASS=0; FAIL=0; WARN=0
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
sec()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

sec "Dependencias"
command -v jq   >/dev/null 2>&1 && ok "jq"   || bad "jq no instalado"
command -v curl >/dev/null 2>&1 && ok "curl" || warn "curl no instalado (fallback de rate limit no andará)"

sec "Harness"
if [ -f .harness/config.json ] && jq empty .harness/config.json 2>/dev/null; then
  ok ".harness/config.json válido"
else
  bad ".harness/config.json ausente o JSON inválido"
fi
u=$(bash .harness/bin/usage.sh 2>/dev/null)
if printf '%s' "$u" | jq -e '.zone' >/dev/null 2>&1; then
  z=$(printf '%s' "$u" | jq -r '.zone')
  [ "$z" = "unknown" ] && warn "usage.sh devuelve zone=unknown (¿statusline instalado? ¿login?)" \
                       || ok "usage.sh OK (zona: $z)"
else
  bad "usage.sh no devuelve JSON válido"
fi
for h in session-resume prompt-usage ratelimit-guard; do
  f=".claude/hooks/$h.sh"
  [ -f "$f" ] && ok "hook $h presente" || bad "falta hook $f"
done

sec "SDD / scope"
if [ -f feature_list.json ] && jq empty feature_list.json 2>/dev/null; then
  ok "feature_list.json válido"
  # una sola feature in_progress
  nip=$(jq '[.features[] | select(.status=="in_progress")] | length' feature_list.json)
  [ "$nip" -le 1 ] && ok "≤1 feature in_progress ($nip)" || bad "$nip features in_progress (debe ser ≤1)"
  # specs presentes para spec_ready/in_progress/done
  while IFS= read -r row; do
    id=$(printf '%s' "$row" | jq -r '.id'); st=$(printf '%s' "$row" | jq -r '.status'); dir=$(printf '%s' "$row" | jq -r '.spec_dir // ("specs/"+.id)')
    case "$st" in
      spec_ready|in_progress|done)
        miss=""
        for f in requirements design tasks; do [ -f "$dir/$f.md" ] || miss="$miss $f.md"; done
        [ -z "$miss" ] && ok "spec '$id' ($st) completa" || bad "spec '$id' ($st) incompleta:$miss"
        ;;
      *) : ;;
    esac
  done < <(jq -c '.features[]' feature_list.json)
else
  bad "feature_list.json ausente o inválido"
fi

sec "Tests del proyecto"
VCMD=$(jq -r '.project.verify_cmd // empty' .harness/config.json 2>/dev/null)
if [ -n "$VCMD" ]; then
  echo "  → $VCMD"
  if bash -c "$VCMD"; then ok "verify_cmd pasó"; else bad "verify_cmd falló"; fi
elif [ -f package.json ] && jq -e '.scripts.test' package.json >/dev/null 2>&1; then
  echo "  → npm test"
  if npm test --silent; then ok "npm test pasó"; else bad "npm test falló"; fi
elif ls ./*pyproject.toml ./pytest.ini ./setup.cfg >/dev/null 2>&1 && command -v pytest >/dev/null 2>&1; then
  echo "  → pytest"
  if pytest -q; then ok "pytest pasó"; else bad "pytest falló"; fi
else
  warn "sin tests detectados (configurá project.verify_cmd en .harness/config.json)"
fi

sec "Resultado"
printf '  %s pass · %s warn · %s fail\n' "$PASS" "$WARN" "$FAIL"
[ "$FAIL" -eq 0 ] && { echo "  OK"; exit 0; } || { echo "  FALLÓ"; exit 1; }
