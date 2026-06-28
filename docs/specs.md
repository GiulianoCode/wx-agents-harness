# Proceso SDD (Spec-Driven Development)

La spec se escribe **antes** del código. El estado vive en disco (`specs/`,
`feature_list.json`, `progress/`) para sobrevivir resets de contexto y cambios de
agente.

## Ciclo

```
pending ──(spec)──► spec_ready ──(aprobación humana)──► in_progress ──(verify)──► done
```

1. **pending** — la feature existe en `feature_list.json`, sin spec.
2. **spec_ready** — existe `specs/<id>/{requirements,design,tasks}.md`. El
   **spec-author** la produjo. → **Gate: el humano aprueba antes de codear.**
3. **in_progress** — el **implementer** ejecuta `tasks.md`. Una sola feature acá.
4. **done** — `bash init.sh` pasa, el **reviewer** validó trazabilidad y checkpoints.

## requirements.md — notación EARS

| Patrón | Forma |
|---|---|
| Ubiquitous | "El sistema SIEMPRE debe …" |
| Event-driven | "CUANDO \<evento\>, el sistema debe …" |
| State-driven | "MIENTRAS \<estado\>, el sistema debe …" |
| Optional | "DONDE \<condición\>, el sistema debe …" |

Numerá `R1, R2, …`. Cada requisito: testeable, sin ambigüedad, una sola obligación.

## tasks.md — atómico y trazable

Cada task es un paso chico, verificable de forma aislada, anotado con los
requirements que cubre: `- [ ] T2 — … (R2, R3)`. La atomicidad es clave para el
handoff: si el rate limit corta, lo que se pierde es a lo sumo un paso chico.

## Roles

`docs/` y `AGENTS.md` definen Leader / Spec Author / Implementer / Reviewer. En
Claude son subagentes (`.claude/agents/`); en Codex, el rol según la fase.

## Anti-telephone-tag

Los agentes se comunican por **archivos**, no por chat. Resultados, decisiones y
estado se escriben en `specs/` y `progress/`. Nunca asumas que el próximo agente
leyó la conversación.
