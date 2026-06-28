---
description: Adoptar el harness en un proyecto EXISTENTE — fusiona contratos, detecta stack/tests y verifica
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion, Glob, Grep
---

Estás incorporando el harness a un proyecto que **ya tiene código** (lo trajo
`install.sh`). Tu trabajo es integrarlo **sin romper ni pisar** lo que ya existe.

## 1. Relevá el proyecto existente
- Detectá el stack y el comando de tests reales: mirá `package.json` (scripts),
  `pyproject.toml`/`pytest.ini`, `Cargo.toml`, `go.mod`, `Makefile`, CI configs.
- Identificá el tipo de proyecto → mapealo a un perfil (`saas-web`, `api-service`,
  `cli`, `library`). Si es web, recordá el aviso de agent-browser.

## 2. Fusioná los contratos (lo delicado)
Buscá archivos `*.harness` que dejó el installer (no se pisó nada):
- **`CLAUDE.md.harness` / `AGENTS.md.harness`**: si existen, el proyecto YA tenía los
  suyos. Fusioná: conservá las instrucciones propias del proyecto y **sumá** las
  secciones del harness (flujo SDD, rate-limit/handoff, subagentes, agent-browser).
  No dupliques; integrá con criterio. Luego borrá los `.harness`.
  - Si NO había `CLAUDE.md`/`AGENTS.md`, el installer ya los creó: revisalos.
- **`.claude/settings.json.harness`** (solo si el merge automático falló): fusioná los
  `hooks` y `permissions` a mano respetando lo existente; luego borrá el `.harness`.
- **`docs/*.md.harness` / `init.harness.sh`**: resolvé colisiones (renombrá o integrá).

## 3. Configurá
- Actualizá `.harness/config.json`: `profile`, `project.{name,description,stack,
  verify_cmd}` (con el comando de tests REAL detectado), `project.onboarded=true`,
  `agent_browser.enabled` según el perfil. Confirmá umbrales de rate limit (defaults
  warn 75 / danger 85 / hard 94) o ajustalos con el usuario.
- (Opcional) Sembrá `feature_list.json` con features que surjan del código/roadmap
  existente; si no, dejá el placeholder y borralo cuando definas la primera real.

## 4. agent-browser (si el perfil lo habilita)
Chequeá `agent-browser --version`. Si falta, **avisá que hay que instalarlo** y ofrecé
`npm install -g agent-browser && agent-browser install` (ver `docs/agent-browser.md`).

## 5. Verificá y cerrá
- Corré `bash init.sh` (o `init.harness.sh` si hubo colisión) y mostrá el resultado.
  Ajustá `project.verify_cmd` hasta que los tests del proyecto pasen por el harness.
- Confirmá que no quedó ningún archivo `*.harness` sin resolver.
- Resumí qué se integró y sugerí el primer `/spec <feature>`.

$ARGUMENTS
