# CHECKPOINTS — criterios de correctitud

Un agente puede marcar una feature `done` **solo si todos estos checkpoints pasan**.
`init.sh` automatiza los que se pueden automatizar.

## Por feature

- [ ] Existe `specs/<id>/` con `requirements.md`, `design.md`, `tasks.md`.
- [ ] Todos los items de `tasks.md` están en `[x]` (o movidos a una feature futura, justificado).
- [ ] Cada requirement (R1, R2, …) es trazable a código y/o test.
- [ ] Los tests del proyecto pasan (`bash init.sh`).
- [ ] No hay TODOs/colgados sin registrar en `progress/` o en una feature `pending`.
- [ ] `feature_list.json`: la feature quedó en `done` y `active` se actualizó.

## Por sesión

- [ ] `progress/current.md` refleja el estado real (o `status: done` si no hay trabajo abierto).
- [ ] Si se tocó UI/web, se verificó en browser real (agent-browser) o se documentó por qué no.
- [ ] Si la sesión paró por rate limit, el handoff quedó completo con prompt de continuación.

## Globales (harness sano)

- [ ] `bash .harness/bin/usage.sh` devuelve JSON válido (no `source: none`).
- [ ] Los hooks de `.claude/settings.json` apuntan a scripts existentes y ejecutables.
