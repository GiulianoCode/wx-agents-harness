# Subsistema rate-limit-aware + handoff

El agente sabe, de forma automática, cuándo se está acercando al **límite de 5h**
de Claude Code, y antes de cortarse deja un **handoff** para que otro agente
(típicamente Codex) continúe el trabajo sin pérdida. Objetivo: exprimir la cuota
al máximo (~94%) **sin** que el corte abrupto del 100% te haga perder trabajo.

## La idea central (por qué funciona)

> ❌ Frágil: trabajar hasta el 98% y *ahí* escribir el handoff. Si el corte llega
> mientras lo escribís, perdés todo.
>
> ✅ Robusto: al **entrar en zona de peligro (~85%)**, el agente **mantiene el
> handoff actualizado después de cada paso atómico.** El documento siempre está
> completo en disco. Entonces podés llegar al borde (~94%): si toca 100% y corta
> en seco, el handoff ya estaba escrito desde el paso anterior. El siguiente
> agente retoma sin pérdida.

Esto **desacopla** "qué tan cerca del 100% llego" de "pierdo trabajo o no".

## Fuente de datos

| | Fuente | Costo | Frescura |
|---|---|---|---|
| **Primaria** | `~/.cache/claude/ratelimit.json` | cero (sin red) | el statusline de Claude Code la reescribe en cada render + cada 60s (`refreshInterval`) |
| **Fallback** | API OAuth `api.anthropic.com/api/oauth/usage` | 1 request | solo si el cache falta o tiene > `cache_max_age_seconds` (180s) |

**Dependencia:** el statusline de Claude Code debe estar instalado en
`~/.claude/statusline-command.sh` con `refreshInterval: 60` — es lo que escribe el
cache. (Los scripts de referencia y la guía `REPLICAR.md` se mantienen aparte, fuera
de este repo, en `~/Dev/Projects/waybar-ai-usage/`, porque son config de sistema, no
del harness.) Sin ese statusline, el sistema cae siempre al fallback de API
(funciona, pero gasta red).

Comando único de consulta: `bash .harness/bin/usage.sh` (`--human` para legible).
Salida: `{zone, window, pct, resets_in_min, five_hour:{…}, seven_day:{…}, stale, source}`.
El top-level (`zone`/`window`/`pct`) refleja la ventana **binding** = la peor de las dos.

## Dos ventanas: 5h y SEMANAL

El harness vigila **dos** cuotas y actúa según la peor:
- **5h** (`five_hour`) — la ventana corta; se recupera en horas.
- **Semanal** (`seven_day`) — **más estricta**: si se agota, Claude queda sin cuota por
  **días**. Por eso, en zona semanal, dejar el handoff y pasar a Codex es aún más crítico
  (esperar no alcanza). Los nudges lo dicen explícitamente.

## Umbrales y zonas

Definidos en `.harness/config.json` (`ratelimit.thresholds` para 5h,
`ratelimit.weekly_thresholds` para semanal):

| Zona | % 5h | % semanal | Comportamiento inducido |
|---|---|---|---|
| `ok` | <75 | <80 | Normal. Silencio. |
| `warn` | ≥75 | ≥80 | Asegurar que `progress/current.md` exista para la tarea activa. |
| `danger` | ≥85 | ≥90 | Pasos chicos, sin refactors grandes; **refrescar el handoff tras cada paso atómico.** |
| `hard` | ≥94 | ≥96 | Terminar SOLO el paso actual, confirmar handoff completo, **parar** y emitir el prompt de continuación para Codex. |

## Cómo "sabe cuándo" (sin depender de su disciplina): hooks

Registrados en `.claude/settings.json`:

- **`UserPromptSubmit` → `prompt-usage.sh`**: en cada mensaje tuyo, si la zona ≠ ok,
  inyecta el % y el nudge de la zona como contexto. Barato (1 vez por turno).
- **`PostToolUse` → `ratelimit-guard.sh`**: el guardián de las corridas autónomas
  (muchas tool calls sin turnos tuyos). Inyecta el nudge al **cruzar** a una zona
  más alta, y como **recordatorio periódico** (throttle `throttle_seconds`, 75s)
  mientras esté en danger/hard. Estado en `~/.cache/claude/harness-guard.state`.
- **`SessionStart` → `session-resume.sh`**: al abrir/resumir, si hay un handoff
  abierto en `progress/current.md` (`status: open`), lo inyecta como contexto.
  Cierra el ciclo Claude↔Codex y la recuperación tras un corte.

El agente no "decide" chequear: el entorno le mete el aviso en contexto en el
momento justo.

## El handoff

- Plantilla: `.harness/bin/handoff-template.md`.
- Se genera/refresca con el comando **`/handoff`** (`.claude/commands/handoff.md`).
- Vive en `progress/current.md` (= el `progress/current.md` del patrón SDD).
- Incluye: objetivo, spec, Hecho/En progreso/Próximos pasos, archivos tocados,
  cómo verificar, decisiones/gotchas, y un **prompt de continuación pegable en Codex**.
- Append de una línea por handoff a `progress/history.md`.

## Cómo se escribe el handoff (no tipeás `/handoff`)

El handoff es **automático guiado por el agente**, no un comando que el runtime
dispara solo:

1. El hook inyecta una **instrucción** en el contexto del agente ("estás en zona
   danger/hard, dejá el handoff").
2. El **agente** escribe/actualiza `progress/current.md` **él mismo** con sus tools.
   (Los hooks no pueden invocar un slash command; `/handoff` es la misma rutina
   disponible para uso manual, pero en el flujo normal no hace falta tipearla.)

### Red de seguridad mecánica (auto-snapshot)
Como (2) depende de que el agente obedezca, hay un respaldo **mecánico** que no
depende de él: en zona danger/hard, `ratelimit-guard.sh` escribe por script
`progress/auto-snapshot.md` (timestamp, % de 5h, feature activa, `git status`,
`git diff --stat`, últimos commits). No tiene la riqueza del handoff del agente,
pero garantiza que **siempre** quede una pista en disco aunque el corte sea brutal.
Al reabrir, si no hay handoff abierto, `session-resume.sh` inyecta ese snapshot si
es reciente (<6h). El archivo es transitorio y está en `.gitignore`.

## Codex (prioridad 2)

Codex no tiene statusline que cachee el dato, así que su autochequeo es más manual:
- `bash .harness/bin/usage-codex.sh` devuelve el **mismo formato** (vía API wham/usage).
- El `AGENTS.md` instruye a Codex a consultarlo y a producir/consumir el mismo
  formato de handoff. Así el ping-pong Claude↔Codex es simétrico.

## Verificación

Sin esperar a estar realmente al límite, simulá el cache:

```bash
export CLAUDE_PROJECT_DIR="$PWD"
CACHE=~/.cache/claude/ratelimit.json
cp "$CACHE" "$CACHE.bak"                                   # backup del real
printf '{"five_hour":{"used_percentage":88,"resets_at":%s}}\n' $(($(date +%s)+3600)) > "$CACHE"
echo '{}' | bash .claude/hooks/prompt-usage.sh | jq -r '.hookSpecificOutput.additionalContext'
rm -f ~/.cache/claude/harness-guard.state
echo '{}' | bash .claude/hooks/ratelimit-guard.sh | jq -r '.hookSpecificOutput.additionalContext'
mv "$CACHE.bak" "$CACHE"                                   # restore
```
