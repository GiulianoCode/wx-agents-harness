# AGENTS.md — contrato del harness (canónico, compartido)

Este archivo es el **mapa de comportamiento** para cualquier agente que trabaje en
este repo (Claude Code y Codex). Claude además lee `CLAUDE.md`, que importa éste y
agrega la parte específica de Claude. Codex lee **este** archivo.

> Si todavía no se corrió el onboarding, empezá por ahí: `/onboard` (Claude) o leé
> `.harness/profiles/` y completá `.harness/config.json` a mano (Codex).

## Principios

1. **Estado en disco, no en el chat** (anti-telephone-tag). Specs, progreso y
   handoffs viven en archivos (`specs/`, `progress/`). Nunca asumas que el próximo
   agente vio la conversación: si importa, escribilo.
2. **Una feature a la vez.** El scope se gestiona en `feature_list.json`. No
   empieces una feature nueva si hay una `in_progress`.
3. **Spec antes de código** (SDD). Ver `docs/specs.md`.
4. **Verificá, no asumas.** Toda feature termina pasando `bash init.sh`. Ver
   `docs/verification.md`.
5. **Consciencia de rate limit.** Mantené el handoff vivo cuando te acercás al
   límite de 5h (ver abajo). Es preferible parar y entregar un handoff completo a
   que el límite te corte en seco.

## Roles (SDD)

El SDD define cuatro roles: **Spec Author** (escribe requirements/design/tasks),
**Implementer** (ejecuta tasks, escribe código), **Reviewer** (valida trazabilidad
y completitud) y **Leader** (orquesta, no edita código).

**Por defecto, un mismo agente asume todos los roles inline** — es más barato y más
coherente (no re-deriva contexto entre fases). Los roles son una forma de pensar el
flujo, no un mandato de spawnear un agente por fase.

### Cuándo delegar a un subagente (opt-in)
Delegá **solo** si:
- **(a)** la feature es grande / requiere mucha exploración → conviene aislar ese
  ruido del hilo principal (spec-author o implementer en su propio contexto), o
- **(b)** querés un **review independiente** → el `reviewer` con mirada fresca es el
  de mejor relación costo/beneficio y es el delegado **recomendado** antes de `done`.

Para features chicas/medianas: trabajá inline, sin spawnear. Spawnear por inercia
quema tokens (cada subagente arranca en frío). En Claude los roles existen como
subagentes (`.claude/agents/`); en Codex asumís el rol según la fase
(lo dice `progress/current.md`).

## Flujo de una feature

```
pending → spec_ready → in_progress → done
```

1. Elegí/creá la feature en `feature_list.json` (status `pending`).
2. **Spec**: generá `specs/<feature>/{requirements.md,design.md,tasks.md}`.
   → status `spec_ready`. **Gate: aprobación humana antes de codear.**
3. **Implementación**: seguí `tasks.md`, marcando `[x]`. → status `in_progress`.
4. **Verificación**: `bash init.sh` pasa + spec completa. → status `done`.

Detalle del proceso: `docs/specs.md`. Criterios de correctitud: `CHECKPOINTS.md`.

## Rate limit y handoff

El harness vigila **dos** cuotas y actúa según la peor: la de **5h** y la **SEMANAL**.
La semanal es más estricta: si se agota, Claude queda sin cuota por **días** → ahí el
handoff y el pase a Codex son aún más críticos. Comportamiento esperado:

| Zona | % 5h | % semanal | Qué hacer |
|---|---|---|---|
| ok | <75 | <80 | Normal. |
| warn | ≥75 | ≥80 | Asegurá que `progress/current.md` exista para la tarea activa. |
| danger | ≥85 | ≥90 | Pasos chicos; refrescá el handoff **después de cada paso atómico**. |
| hard | ≥94 | ≥96 | Terminá solo el paso actual, dejá el handoff completo, **pará** y entregá el prompt de continuación. |

- **Consultar el uso:**
  - Claude: automático (hooks). Manual: `bash .harness/bin/usage.sh --human`.
  - Codex: `bash .harness/bin/usage-codex.sh` (mismo formato JSON).
- **Generar/refrescar el handoff:** Claude usa `/handoff`. Codex replica la
  plantilla `.harness/bin/handoff-template.md` en `progress/current.md` a mano.
- **Retomar un handoff:** si `progress/current.md` tiene `status: open`, leelo
  entero y seguí desde "Próximos pasos". Marcá `status: done` al terminar.

Diseño completo: `docs/rate-limit-handoff.md`.

## Trabajo en web (proyectos SaaS)

Para tocar/probar la app en un browser real usá **agent-browser**
(`open → snapshot -i → click/fill → re-snapshot`). Ver `docs/agent-browser.md`.

## Mapa de archivos

| Ruta | Qué es |
|---|---|
| `.harness/config.json` | Config única (perfil, umbrales, handoff). |
| `.harness/bin/` | `usage.sh`, `usage-codex.sh`, `handoff-template.md`. |
| `.claude/` | Hooks, commands, subagentes, skills (Claude). |
| `feature_list.json` | Scope: features y su estado. |
| `specs/<feature>/` | requirements / design / tasks. |
| `progress/current.md` | Handoff vivo / estado de sesión. |
| `progress/history.md` | Log append-only. |
| `init.sh` | Verificación. |
| `docs/` | architecture, conventions, specs, verification, rate-limit-handoff, agent-browser. |
