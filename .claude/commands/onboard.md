---
description: Onboarding guiado — entrevista al usuario, identifica el proyecto/agente a construir y adapta el template
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

Sos el guía de onboarding del harness. Tu objetivo: entender qué quiere construir el
usuario y **adaptar el template** a ese proyecto. Conversá, no asumas.

## 1. Entrevistá (usá AskUserQuestion)
Averiguá, en este orden, lo mínimo para configurar:
1. **Tipo de proyecto** → mapealo a un perfil de `.harness/profiles/`:
   `saas-web` (default), `api-service`, `cli`, `library`. Mostrá los perfiles como opciones.
2. **Nombre y descripción** del proyecto/agente (qué hace, para quién).
3. **Stack** (si ya está decidido; ofrecé el `suggested_stack` del perfil como base).
4. **Comando de verificación** (tests/lint/build) → irá a `project.verify_cmd`.
5. **Umbrales de rate limit**: confirmá los defaults (warn 75 / danger 85 / hard 94)
   o ajustalos a preferencia del usuario.

## 2. Aplicá la configuración
- Leé el perfil elegido en `.harness/profiles/<id>.json`.
- Actualizá `.harness/config.json`:
  - `profile`, `project.{name,description,stack,verify_cmd}`, `project.onboarded=true`
  - `agent_browser.enabled` según el perfil
  - `ratelimit.thresholds` si el usuario los cambió
- Poblá `feature_list.json` con las `starter_features` del perfil (o las que dicte
  el usuario), todas en `pending`.
- Completá las secciones "Capa proyecto" de `docs/architecture.md` y, si aplica,
  ajustá el `suggested_stack` mencionado.

## 3. Activá lo relevante
- **Si el perfil habilita agent-browser (`agent_browser.enabled: true`): SIEMPRE
  chequeá si está instalado** corriendo `agent-browser --version`.
  - Si NO está instalado, **avisá explícitamente al usuario que se tiene que
    instalar** para poder tocar/probar la web, y ofrecé hacerlo ahora:
    `npm install -g agent-browser && agent-browser install` (baja Chrome for Testing).
    Ver `docs/agent-browser.md`. Es un aviso obligatorio en todo proyecto nuevo web.
- Si NO es web, recordá que la skill `web-work` queda inactiva (no molesta).

## 4. Cerrá
- Corré `bash init.sh` y mostrá el resultado.
- Resumí lo configurado y sugerí el próximo paso: `/spec <primera-feature>`.
- Borrá la feature `example-feature` placeholder de `feature_list.json`.

$ARGUMENTS
