# wx-harness-template

Template de **harness** para mis proyectos: un entorno que hace que el agente de
código se comporte de forma esperada y eficiente. Optimizado para **Claude Code**
(prioridad) y compatible con **Codex**. Pensado para proyectos **SaaS web**, pero
adaptable a otros tipos vía onboarding guiado.

## Qué trae

- **SDD (Spec-Driven Development)** — specs en disco, roles multi-agente, estado
  persistente, gates de verificación. (`AGENTS.md`, `docs/specs.md`)
- **Rate-limit-aware + handoff** — el agente sabe cuándo se acerca al límite de 5h
  y, antes de cortarse, deja un handoff para que otro agente (Codex) continúe sin
  pérdida. Exprime la cuota hasta ~94% sin riesgo. (`docs/rate-limit-handoff.md`)
- **agent-browser** — el agente toca/prueba la web él mismo. (`docs/agent-browser.md`)
- **Onboarding guiado por IA** — `/onboard` entrevista y adapta el template al
  proyecto. (`.claude/commands/onboard.md`)

## Cómo usarlo

### ✨ Arranque recomendado (un solo prompt — hace casi todo)
Creá la carpeta del proyecto (vacía **o** con tu código ya existente), abrí Claude
Code adentro y pegá este prompt, reemplazando la URL:

> Instalá y configurá el harness de este proyecto a partir de este repo:
> `<URL-del-repo-del-template>`
>
> 1. Cloná ese repo con git a una carpeta temporal (si es una ruta local, copialo).
> 2. Leé su `README.md`, sección **"Para el agente"**, y seguila al pie de la letra.
> 3. Corré su `install.sh` apuntando a ESTE proyecto.
> 4. Según el estado de este proyecto, instalá del modo correcto: si está vacío,
>    seguí `.claude/commands/onboard.md`; si ya tiene código (o un harness previo),
>    seguí `.claude/commands/adopt.md`, **migrando sin perder datos**.
> 5. Verificá con `bash init.sh` y decime que apruebe los hooks al reabrir.

El agente solo necesita saber **clonar con git** (lo típico). Él detecta si tiene que
**crear desde cero** o **adaptar/migrar** lo existente, y sigue los pasos detallados de
la sección [Para el agente](#para-el-agente-setup-automático).

> La URL puede ser un repo de GitHub, cualquier URL git, o **una ruta local** al
> template mientras no esté publicado. Sin chat, también vale:
> `bash <ruta-al-template>/bootstrap.sh <ruta-al-proyecto>`.

### Proyecto nuevo
1. **Cloná/copiá** este template a un proyecto nuevo.
2. Abrí Claude Code en la carpeta y corré **`/onboard`**. Te entrevista (tipo de
   proyecto, stack, comando de tests, umbrales) y configura todo.
3. Empezá a trabajar con el flujo SDD: `/spec <feature>` → aprobás → implementás →
   `/verify`.

### Proyecto EXISTENTE (con código y git ya presentes)
1. Desde el proyecto existente, corré el instalador apuntando a este template:
   ```bash
   bash /ruta/al/wx-harness-template/install.sh /ruta/a/mi-proyecto-existente
   ```
   Es **idempotente y no pisa nada**: copia la maquinaria del harness, **fusiona**
   `.claude/settings.json` (hooks + permisos) y `.gitignore`, y deja como `*.harness`
   los contratos que ya existan (`CLAUDE.md`/`AGENTS.md`) para no sobrescribirlos.
2. Abrí Claude Code en el proyecto y **aprobá los hooks** cuando los pida.
3. Corré **`/adopt`**: fusiona los contratos `*.harness` con criterio, detecta tu
   stack y comando de tests reales, configura `.harness/config.json` y verifica con
   `init.sh`.

## Comandos (Claude)

| Comando | Qué hace |
|---|---|
| `/onboard` | Entrevista guiada que adapta el template a un proyecto nuevo. |
| `/adopt` | Integra el harness en un proyecto existente (fusiona contratos, detecta stack/tests). |
| `/spec <feature>` | Crea la spec SDD (requirements/design/tasks). |
| `/handoff` | Vuelca estado + prompt de continuación a `progress/current.md`. |
| `/verify` | Corre `init.sh` y reporta. |

## Dependencias

- **Claude Code** ≥ 2.1.x (hooks `SessionStart`/`UserPromptSubmit`/`PostToolUse`).
- **jq**, **curl** (`sudo pacman -S --needed jq curl`).
- **Statusline de rate limit** instalada en `~/.claude/statusline-command.sh` con
  `refreshInterval: 60` — es la fuente primaria (sin red) del uso de 5h. Los scripts
  de referencia son config de sistema (no del harness) y viven aparte.
- **node/npm** (para agent-browser; opcional según perfil).
- **Codex** (opcional): `codex login` para que `usage-codex.sh` funcione.

## Estructura

```
.harness/          config + bin (usage, handoff) + perfiles
.claude/           hooks + commands + subagentes + skills
specs/             specs SDD por feature (+ _TEMPLATE)
progress/          current.md (handoff vivo) + history.md
feature_list.json  scope
init.sh            verificación  ·  AGENTS.md / CLAUDE.md  contratos
docs/              architecture, conventions, specs, verification,
                   rate-limit-handoff, agent-browser
```

Verificá la salud del harness en cualquier momento: `bash init.sh`.

---

## Para el agente (setup automático)

Si te pidieron *"configurar/instalar este harness en este proyecto"* a partir de
este repo, seguí estos pasos exactamente:

1. **Traé el template** a una carpeta temporal:
   `git clone --depth 1 <URL-de-este-repo> /tmp/harness-template`
2. **Instalá** sobre el proyecto actual (no pisa nada, es idempotente):
   `bash /tmp/harness-template/install.sh "$PWD"`
3. **Leé el reporte** del installer y **elegí el camino**:
   - Carpeta vacía / sin código → seguí los pasos de `.claude/commands/onboard.md`.
   - Ya hay código (o un harness/estado previo) → seguí `.claude/commands/adopt.md`
     (incluye migración sin pérdida de un harness anterior).
   > Los slash recién instalados **no** están activos en esta sesión: **leé esos
   > `.md` y ejecutá sus pasos directamente** (no esperes que `/onboard` o `/adopt`
   > funcionen como comando hasta reabrir Claude Code).
4. **Regla de oro**: cero pérdida de datos. `install.sh` no borra nada; lo previo se
   conserva o se archiva en `.harness/migrated/`. Verificá al final con `bash init.sh`.
5. Avisá al usuario que **apruebe los hooks** al reabrir Claude Code (se activan ahí).
