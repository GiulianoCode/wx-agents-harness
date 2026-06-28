<h1 align="center">🦾 wx-agents-harness</h1>

<p align="center">
  <strong>El harness de agentes de <a href="#-sobre-waranix">Waranix</a></strong> — un entorno que hace que tu agente de código se comporte de forma <em>predecible, eficiente y a prueba de cortes</em>.
</p>

<p align="center">
  Claude-first · Codex-ready · pensado para SaaS web · listo en un prompt
</p>

---

Los agentes de código son potentes pero inconsistentes: se desvían del flujo, gastan
tokens de más, **chocan contra el rate limit y pierden el trabajo a la mitad**, y cada
proyecto los configura distinto. `wx-agents-harness` es una base reusable que resuelve
todo eso de una, para que el agente **rinda al máximo sin sorpresas**.

```
Creá una carpeta → abrí Claude Code → pegá un prompt → el agente arma todo solo.
```

## ✨ Qué lo hace distinto

- ⛽ **Rate-limit-aware + handoff** — el agente **sabe** cuándo se acerca al límite de
  5h (sin gastar red), y antes de cortarse deja un *handoff* completo para que otro
  agente (p.ej. Codex) siga sin perder nada. Exprimís la cuota hasta ~94% **sin riesgo**.
- 🧠 **SDD (Spec-Driven Development)** — specs en disco, roles (spec→implement→review),
  estado persistente y gates de verificación. El agente sobrevive a resets de contexto.
- 🌐 **agent-browser** — el agente abre un browser real y prueba la web él mismo.
- 🚀 **Onboarding/adopción guiada** — se instala solo en proyectos nuevos *y existentes*,
  **sin pisar nada** y migrando cualquier harness previo sin perder datos.
- 🪶 **Liviano en tokens** — ~1.8k tokens siempre-en-contexto (cacheados); todo lo
  pesado se carga a demanda. Los hooks no cuestan tokens cuando estás tranquilo.
- 🔌 **Claude-first, Codex-ready** — exprime Claude al máximo y deja a Codex operativo.

## 🚀 Empezar en 30 segundos

Creá la carpeta del proyecto (**vacía o con tu código ya existente**), abrí Claude Code
adentro y pegá este prompt:

> Instalá y configurá el harness de este proyecto a partir de este repo:
> `https://github.com/GiulianoCode/wx-agents-harness`
>
> 1. Cloná ese repo con git a una carpeta temporal (si es una ruta local, copialo).
> 2. Leé su `README.md`, sección **"Para el agente"**, y seguila al pie de la letra.
> 3. Corré su `install.sh` apuntando a ESTE proyecto.
> 4. Según el estado de este proyecto, instalá del modo correcto: si está vacío,
>    seguí `.claude/commands/onboard.md`; si ya tiene código (o un harness previo),
>    seguí `.claude/commands/adopt.md`, **migrando sin perder datos**.
> 5. Verificá con `bash init.sh` y decime que apruebe los hooks al reabrir.

El agente solo necesita saber **clonar con git**. Él detecta si tiene que **crear desde
cero** o **adaptar/migrar** lo existente. Eso es todo.

¿Preferís terminal sin chat?
```bash
curl -fsSL https://raw.githubusercontent.com/GiulianoCode/wx-agents-harness/main/bootstrap.sh | bash
```

## 🧭 Los dos caminos (manual)

<details>
<summary><strong>Proyecto nuevo</strong></summary>

```bash
git clone https://github.com/GiulianoCode/wx-agents-harness mi-proyecto
cd mi-proyecto && rm -rf .git && git init -q
```
Abrí Claude Code → aprobá los hooks → corré **`/onboard`** (te entrevista y configura
perfil, stack, tests y umbrales) → trabajá con `/spec` → `/verify`.
</details>

<details>
<summary><strong>Proyecto existente</strong> (ya tiene código / git / otro harness)</summary>

```bash
bash /ruta/al/wx-agents-harness/install.sh /ruta/a/mi-proyecto-existente
```
Idempotente y **no pisa nada**: fusiona `.claude/settings.json` y `.gitignore`, deja
los contratos que ya existan como `*.harness`, y conserva el estado previo. Después
abrí Claude Code → aprobá los hooks → corré **`/adopt`** (fusiona contratos, detecta
tu stack/tests y **migra cualquier harness anterior sin perder datos**).
</details>

## ⛽ La joya: rate-limit + handoff

> El problema no es predecir el corte del 100% — es **no perder trabajo cuando ocurre**.

Al entrar en **zona de peligro (~85%)**, el agente mantiene el *handoff* actualizado
después de **cada paso atómico**. El documento siempre está completo en disco. Entonces
podés llegar al borde (~94%): si el límite corta en seco, el siguiente agente retoma
desde el handoff, sin pérdida.

| Zona | % 5h | Comportamiento |
|---|---|---|
| `ok` | <75 | Normal. |
| `warn` | ≥75 | Asegura que el handoff exista para la tarea activa. |
| `danger` | ≥85 | Pasos chicos; refresca el handoff tras cada paso atómico. |
| `hard` | ≥94 | Termina el paso actual, deja el handoff completo, para y entrega el prompt de continuación. |

Fuente de datos sin red (cache del statusline), avisos automáticos vía hooks. Detalle
en [`docs/rate-limit-handoff.md`](docs/rate-limit-handoff.md).

## ⌨️ Comandos

| Comando | Qué hace |
|---|---|
| `/onboard` | Entrevista guiada que adapta el harness a un proyecto nuevo. |
| `/adopt` | Integra el harness en un proyecto existente (fusiona contratos, migra harness previo). |
| `/spec <feature>` | Crea la spec SDD (requirements/design/tasks). |
| `/handoff` | Vuelca estado + prompt de continuación a `progress/current.md`. |
| `/verify` | Corre `init.sh` y reporta. |

## 📦 Requisitos

- **Claude Code** ≥ 2.1.x (hooks `SessionStart`/`UserPromptSubmit`/`PostToolUse`).
- **jq** y **curl** (`sudo pacman -S --needed jq curl` / `apt install jq curl`).
- Un **statusline** que cachee el rate limit de 5h (fuente sin red del harness **y**
  tu indicador visual). **Viene incluido**: el agente lo instala en `/onboard` /
  `/adopt`, o corrés `bash .harness/bin/setup-statusline.sh` (no pisa el tuyo si ya
  tenés). Sin statusline, cae a la API (funciona, gasta una request). Ver
  [`docs/visual-indicator.md`](docs/visual-indicator.md).
- **node/npm** para agent-browser (opcional según perfil).
- **Codex** (opcional): `codex login` para que `usage-codex.sh` funcione.

## 🗂️ Estructura

```
.harness/          config + bin (usage, handoff) + perfiles
.claude/           hooks + commands + subagentes + skills + settings.json
specs/             specs SDD por feature (+ _TEMPLATE)
progress/          current.md (handoff vivo) + history.md
feature_list.json  scope · init.sh verificación · AGENTS.md/CLAUDE.md contratos
docs/              architecture · conventions · specs · verification ·
                   rate-limit-handoff · agent-browser · visual-indicator
install.sh         instalador merge-aware · bootstrap.sh arranque en un comando
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

---

## 🏢 Sobre Waranix

`wx-agents-harness` es el harness de agentes de **Waranix** (el prefijo `wx` viene de
*Waranix*). Lo liberamos público para que cualquiera pueda darle a sus agentes el mismo
entorno: predecible, eficiente y a prueba de cortes. Si lo usás y lo mejorás, los PRs
son bienvenidos.

<p align="center"><sub>Hecho con 🦾 por Waranix · MIT License</sub></p>
