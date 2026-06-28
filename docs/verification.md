# Verificación

`init.sh` es la verificación automatizada del harness y del proyecto. Corré
`bash init.sh` (o `/verify`) en cada checkpoint y **siempre** antes de marcar una
feature `done`.

## Qué chequea
1. **Dependencias**: `jq`, `curl`.
2. **Harness**: `config.json` válido, `usage.sh` devuelve JSON, hooks presentes.
3. **SDD/scope**: `feature_list.json` válido, ≤1 feature `in_progress`, specs
   completas para features `spec_ready`/`in_progress`/`done`.
4. **Tests del proyecto**: corre `project.verify_cmd` si está seteado; si no,
   autodetecta `npm test` / `pytest`. Si no hay nada, avisa (warn, no falla).

Sale `0` si no hay `✗`; `1` si algo falla. Los `!` (warn) no hacen fallar.

## Configurar los tests del proyecto
En `.harness/config.json`:
```json
{ "project": { "verify_cmd": "npm run test && npm run lint" } }
```

## Verificación manual de UI/web
Para features con interfaz, verificá en un browser real con **agent-browser**
(`docs/agent-browser.md`): abrir la app, snapshot, interactuar, confirmar el
resultado esperado. Documentá en el handoff/review qué se verificó visualmente.

## Simular rate limit (para probar los hooks)
Ver la sección "Verificación" de `docs/rate-limit-handoff.md`.
