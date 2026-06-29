---
description: Onboarding guiado — entrevista al usuario, identifica el proyecto/agente a construir y adapta el template
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

Sos el guía de onboarding del harness. Tu objetivo: entender qué quiere construir el
usuario y **adaptar el template** a ese proyecto. **Conversá en lenguaje natural; no
encajones al usuario en un menú.**

## 1. Entrevistá CONVERSANDO (no con menús rígidos)
Hacelo como una charla, una pregunta a la vez, en texto:
1. **Pedile que describa el proyecto con sus palabras** ("¿qué es y qué hace?").
   No le presentes una lista cerrada de tipos. Puede ser cualquier cosa: una app
   web, una API, un CLI, una librería, un bot, etc.
2. **Inferí vos el perfil más cercano** de `.harness/profiles/` y **proponéselo para
   confirmar**, explicando por qué. Los perfiles son **defaults, no cajas**:
   - Cualquier cosa con interfaz web → `saas-web` (activa agent-browser). El caso más común.
   - Servicio sin UI → `api-service`. Comando de terminal → `cli`. Paquete → `library`.
   - Si no encaja limpio, **elegí el más cercano y adaptá libremente** la config (no
     fuerces un perfil que no corresponde, como `cli` para algo web).
   - Solo si querés ofrecer opciones discretas, podés usar AskUserQuestion, pero
     **siempre** dejando claro que puede describir en libertad ("Otro").
3. **Nombre y descripción**, **stack** (ofrecé el `suggested_stack` como base),
   **comando de verificación** (tests/lint/build → `project.verify_cmd`).
4. **Umbrales de rate limit**: confirmá los defaults (5h: warn 75 / danger 85 / hard 94 ·
   semanal: warn 80 / danger 90 / hard 96) o ajustalos.

## 2. Aplicá la configuración
- Leé el perfil elegido en `.harness/profiles/<id>.json` (como punto de partida).
- Actualizá `.harness/config.json`:
  - `profile`, `project.{name,description,stack,verify_cmd}`, `project.onboarded=true`
  - `agent_browser.enabled` según corresponda al proyecto real (no solo al perfil)
  - `ratelimit.thresholds` / `ratelimit.weekly_thresholds` si el usuario los cambió
- Poblá `feature_list.json` con features reales que surjan de la charla (o las
  `starter_features` del perfil como semilla), todas en `pending`.
- Completá las secciones "Capa proyecto" de `docs/architecture.md`.

## 3. Activá lo relevante
- **Si el perfil habilita agent-browser (`agent_browser.enabled: true`): SIEMPRE
  chequeá si está instalado** corriendo `agent-browser --version`.
  - Si NO está instalado, **avisá explícitamente al usuario que se tiene que
    instalar** para poder tocar/probar la web, y ofrecé hacerlo ahora:
    `npm install -g agent-browser && agent-browser install` (baja Chrome for Testing).
    Ver `docs/agent-browser.md`. Es un aviso obligatorio en todo proyecto nuevo web.
- Si NO es web, recordá que la skill `web-work` queda inactiva (no molesta).

## 3b. Indicador visual del rate limit (statusline)
El statusline es el indicador visual del 5h **y** la fuente sin red del harness.
- Comprobá si el usuario ya tiene uno: `jq -r '.statusLine.command // empty' ~/.claude/settings.json`.
- **Ofrecé instalarlo** (pedí confirmación, toca config global): `bash .harness/bin/setup-statusline.sh`.
  Es no-destructivo: si ya tiene statusLine no lo pisa, solo le da el snippet para
  cachear el rate limit. Ver `docs/visual-indicator.md`.

## 4. Cerrá
- Corré `bash init.sh` y mostrá el resultado.
- Resumí lo configurado y sugerí el próximo paso: `/spec <primera-feature>`.
- Borrá la feature `example-feature` placeholder de `feature_list.json`.

$ARGUMENTS
