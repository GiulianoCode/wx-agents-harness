# Indicador visual del rate limit (statusline + waybar)

El harness te avisa del rate limit de 5h por dos canales:
- **Al agente** → vía hooks (texto inyectado en su contexto; vos NO lo ves).
- **A vos** → vía un **indicador visual**. Esto es esa parte.

> El statusline no es solo cosmético: es la **fuente primaria sin red** del harness.
> Escribe `~/.cache/claude/ratelimit.json` en cada render, que es lo que lee
> `.harness/bin/usage.sh` (costo cero, sin tocar la API). Sin statusline, el harness
> cae al fallback de API: funciona, pero gasta una request. Por eso se recomienda
> tenerlo.

## Statusline de Claude Code (recomendado)

Muestra una fila: `proyecto · rama · contexto · 5h ▰▰▰ 84% reset HH:MM`.

### Instalación (la hace el agente en `/onboard` y `/adopt`, o vos a mano)
```bash
bash .harness/bin/setup-statusline.sh
```
Es **no-destructivo**:
- Si **no** tenés statusLine configurado → instala el del harness
  (`.harness/statusline/statusline.sh` → `~/.claude/statusline-command.sh`) y setea
  `statusLine` en `~/.claude/settings.json` con `refreshInterval: 60`.
- Si **ya** tenés uno → **no lo pisa**; te da el snippet para que el tuyo cachee el
  rate limit:
  ```bash
  rl=$(echo "$input" | jq -c ".rate_limits // empty"); [ -n "$rl" ] && mkdir -p ~/.cache/claude && printf "%s\n" "$rl" > ~/.cache/claude/ratelimit.json
  ```
  (El statusline recibe el payload de Claude Code por stdin como `$input`; ese
  snippet es lo único imprescindible para alimentar al harness.)

Reabrí Claude Code para verlo.

## Waybar (opcional — Hyprland/waybar)

Si usás **waybar** (típico en Hyprland/Omarchy), podés tener el % de 5h en la barra,
con toggle Claude↔Codex en vivo desde la API. Es **opcional** y específico de ese
entorno, por eso no viene bundleado. Si lo querés, pedíselo al agente: puede armarte
los módulos custom de waybar (`exec` a un script que pega a la API de usage de
Claude/Codex y emite JSON `{text,tooltip,class}`) siguiendo el mismo patrón del
statusline. La fuente de datos del harness no depende de waybar.

## Resumen

| Indicador | Para qué | ¿Requerido? |
|---|---|---|
| **statusline** | tu vista del 5h **+ fuente de datos del harness** | Recomendado (si no, fallback API) |
| **waybar** | el 5h en la barra del sistema | Opcional (Hyprland/waybar) |
