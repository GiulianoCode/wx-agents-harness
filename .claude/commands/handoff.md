---
description: Generar/refrescar el handoff (progress/current.md) para continuar el trabajo en otro agente
allowed-tools: Read, Write, Edit, Bash
---

Generá o **refrescá** el handoff de la sesión actual. El handoff es el mecanismo
anti-pérdida del harness: un documento en disco que permite que otro agente
(típicamente Codex) retome el trabajo exactamente donde quedó, sin pérdida ni
re-investigación.

## Pasos

1. Leé el estado del rate limit para registrarlo en el handoff:
   `bash .harness/bin/usage.sh`
2. Leé la plantilla `.harness/bin/handoff-template.md`.
3. Leé el handoff anterior si existe (`progress/current.md`) para no perder contexto.
4. Completá la plantilla con el estado REAL y honesto de la sesión:
   - **Hecho / En progreso / Próximos pasos** deben ser concretos y accionables.
   - En "En progreso" describí el paso atómico exacto donde estás, con el detalle
     suficiente para que otro agente lo retome sin volver a investigar.
   - El **prompt de continuación** debe ser auto-suficiente y pegable tal cual en Codex.
   - `status: open`, `updated:` con fecha/hora actual, `5h_at:` con el % de uso.
5. Escribí el resultado en `progress/current.md` (sobrescribiendo).
6. Agregá UNA línea a `progress/history.md`:
   `- <YYYY-MM-DD HH:MM> · handoff @<pct>% · <título corto>`
   (creá el archivo si no existe).
7. Mostrale al usuario un resumen de 3-4 líneas y, si estamos en zona danger/hard,
   recordale que puede pasar el "prompt de continuación" a Codex.

## Importante
- Si ya hay un `progress/current.md` abierto para la MISMA tarea, **actualizalo**
  (no dupliques): refrescá Hecho/En progreso/Próximos pasos.
- Cuando una tarea se da por terminada, marcá `status: done` en lugar de borrar.
- Sé honesto: si algo quedó a medias o sin verificar, decilo explícitamente.

$ARGUMENTS
