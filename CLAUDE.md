# CLAUDE.md — instrucciones para Claude Code

Este harness está optimizado para **exprimir Claude al máximo**. El contrato base
(principios, roles SDD, flujo de features, rate-limit, handoff) es el canónico:

@AGENTS.md

Lo de abajo es lo **específico de Claude** — la maquinaria que ya está cableada
para vos. Usala.

## Lo que ya corre solo (no tenés que acordarte)

- **Rate limit (hooks):** el entorno inyecta avisos automáticamente al acercarte
  al límite de 5h (`UserPromptSubmit`, `PostToolUse`, `SessionStart`). Cuando
  veas un aviso 🟠/🔴, actuá según la zona (ver `@AGENTS.md`). No necesitás
  consultar el uso a mano, pero podés: `bash .harness/bin/usage.sh --human`.
- **Resume de handoff:** al abrir la sesión, si hay un handoff abierto se te
  inyecta solo. Leelo y retomá.

## Comandos (slash) disponibles

- `/onboard` — entrevista guiada que adapta el template a tu proyecto.
- `/spec <feature>` — crea la spec SDD de una feature.
- `/handoff` — vuelca el estado actual + prompt de continuación a `progress/current.md`.
- `/verify` — corre `init.sh` y reporta.

## Subagentes (`.claude/agents/`) — bisturí, no flujo por defecto

Disponibles: **spec-author**, **implementer**, **reviewer**. Tener estas
definiciones **no cuesta tokens** (se cargan a demanda); el costo aparece **solo al
spawnear**, y cada spawn arranca en frío (re-deriva contexto).

**Default: trabajá inline** (vos hacés spec → implement en el mismo contexto). Es
más barato y coherente. **Delegá solo cuando vale la pena:**

- **Feature grande / mucha exploración** → spawneá `spec-author` o `implementer`
  para aislar ese ruido de tu hilo principal (ahí *ganás* tokens y coherencia).
- **Review independiente** → spawneá `reviewer` antes de `done` (mirada fresca, sin
  sesgo de confirmación). Es el de mejor ROI y el **recomendado**.

No spawnees por inercia para features chicas/medianas: el arranque en frío cuesta
más que el beneficio. Para fan-out de exploración pura, podés usar el agente
`Explore`.

## Cómo exprimir Claude acá

- **Paralelizá** tool calls independientes en un mismo mensaje.
- **Usá los subagentes** para fan-out (explorar, especificar, revisar) sin quemar
  tu ventana de contexto principal.
- **Checkpoint agresivo en zona danger/hard**: pasos chicos + `/handoff` tras cada
  uno. Así llegás al ~94% sin riesgo de perder trabajo.
- **Skills**: el trabajo web usa la skill de agent-browser (`docs/agent-browser.md`).

## Estilo

Escribí código que se lea como el código que lo rodea (naming, comentarios,
idioms). Verificá con `init.sh` antes de marcar una feature `done`. Sé honesto en
el handoff: lo que quedó a medias, decilo.
