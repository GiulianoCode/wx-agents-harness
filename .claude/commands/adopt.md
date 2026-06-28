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

## 1b. Migrá el estado de un harness PREVIO (si lo hay) — sin perder datos
El installer reporta "Estado/harness PREVIO detectado" y **nunca pisa** esos datos.
Tu trabajo es **migrarlos** a la estructura de este harness con criterio:

- **Regla de oro: cero pérdida.** No borres nada hasta haber migrado y verificado.
  Archivá los originales del harness viejo en `.harness/migrated/<fecha>/` (movelos
  ahí) en vez de eliminarlos; dejá una nota en `progress/history.md`.
- **`feature_list.json` previo**:
  - Si ya tiene el esquema de este harness (`{active, features:[{id,title,status,
    spec_dir,notes}]}`), **conservalo tal cual** (no lo reemplaces por el placeholder).
  - Si viene de otro harness / otro esquema, **mapealo**: cada feature → un item con
    `id` (kebab-case), `title`, `status` equivalente (pending/spec_ready/in_progress/
    done) y `notes`. Preservá toda info que no encaje en un campo `notes`.
- **specs / tasks previas**: mapealas a `specs/<id>/{requirements,design,tasks}.md`.
  Si el harness viejo guardaba specs en otra carpeta/forma, traducí preservando contenido.
- **progress / handoff / decisiones previas**: integralas en `progress/current.md`
  (estado activo) e `progress/history.md` (log). Decisiones de arquitectura → `docs/`.
- **Otros marcadores** (`.sdd/`, `tasks.md`, `harness.json`, etc.): leelos, migrá lo
  útil, archivá el resto en `.harness/migrated/`.
- Mostrale al usuario un **resumen de la migración** (qué se mapeó y a dónde) y pedí
  confirmación antes de archivar/mover los originales.

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

## 4b. Indicador visual del rate limit (statusline)
Es la fuente sin red del harness + el indicador visual del 5h. Comprobá si el usuario
ya tiene statusLine (`jq -r '.statusLine.command // empty' ~/.claude/settings.json`) y
**ofrecé** (pedí confirmación, toca config global): `bash .harness/bin/setup-statusline.sh`
(no-destructivo; ver `docs/visual-indicator.md`).

## 5. Verificá y cerrá
- Corré `bash init.sh` (o `init.harness.sh` si hubo colisión) y mostrá el resultado.
  Ajustá `project.verify_cmd` hasta que los tests del proyecto pasen por el harness.
- Confirmá que no quedó ningún archivo `*.harness` sin resolver.
- Resumí qué se integró y sugerí el primer `/spec <feature>`.

$ARGUMENTS
