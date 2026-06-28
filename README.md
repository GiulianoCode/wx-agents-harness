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

1. **Cloná/copiá** este template a un proyecto nuevo.
2. Abrí Claude Code en la carpeta y corré **`/onboard`**. Te entrevista (tipo de
   proyecto, stack, comando de tests, umbrales) y configura todo.
3. Empezá a trabajar con el flujo SDD: `/spec <feature>` → aprobás → implementás →
   `/verify`.

## Comandos (Claude)

| Comando | Qué hace |
|---|---|
| `/onboard` | Entrevista guiada que adapta el template al proyecto. |
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
