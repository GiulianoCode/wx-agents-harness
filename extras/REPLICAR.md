# Replicar: Status line de Claude Code + métrica de rate limit en Waybar

Guía para reproducir **exactamente** en otra máquina (Arch + Hyprland + Omarchy)
dos cosas armadas en esta sesión:

1. **Status line de Claude Code** — una sola fila con proyecto, rama git, ventana
   de contexto y rate limit de 5h (este último alineado a la derecha).
2. **Módulo de Waybar "agents"** — muestra el % de rate limit de 5h **en vivo
   desde la API** (Claude por defecto; click para alternar a Codex y volver).
   Refleja el uso a nivel cuenta, así que cuenta también lo consumido en otra
   máquina (p.ej. un VPS).

Los scripts ya están en este repo, listos para copiar verbatim:

```
docs/waybar-ai-usage/
├── claude/
│   └── statusline-command.sh
└── waybar/
    ├── claude-usage.sh      # módulo Claude (API en vivo + refresh + cache)
    ├── codex-usage.sh       # módulo Codex  (API en vivo + refresh + cache)
    ├── agents-usage.sh      # dispatcher: elige claude/codex según el toggle
    └── agents-toggle.sh     # invierte el toggle y refresca Waybar (señal)
```

> En esta guía, `REPO` = la ruta donde clonaste este repo en la máquina nueva.

---

## 0. Prerrequisitos

```bash
# jq y curl (casi seguro ya están en Omarchy)
sudo pacman -S --needed jq curl
```

- **Nerd Font** en Waybar (Omarchy usa `JetBrainsMono Nerd Font`). Necesaria para
  los glyphs `▰▱` (barras) y `⚠`.
- Estar logueado en **Claude Code** en esa máquina (crea
  `~/.claude/.credentials.json`).
- Para Codex: correr **`codex login`** en esa máquina (crea `~/.codex/auth.json`).
  Sin esto, el módulo de Codex muestra `CODEX ⚠` con el motivo en el tooltip
  (no es un bug: es el aviso de error visible).

> **Importante sobre credenciales:** los tokens viven en
> `~/.claude/.credentials.json` y `~/.codex/auth.json` y son **por máquina**.
> No se copian del repo ni de la otra PC: se generan iniciando sesión localmente.

---

## 1. Status line de Claude Code

### 1.1 Copiar el script

```bash
cp REPO/docs/waybar-ai-usage/claude/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

### 1.2 Activarlo en `~/.claude/settings.json`

Agregá el bloque `statusLine` (y `refreshInterval` para que el reloj del reset se
actualice). Si el archivo ya tiene otras claves (theme, model…), solo sumá
`statusLine`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "refreshInterval": 60
  }
}
```

### 1.3 Qué muestra

```
wx-harness-template  main  ·  4% │ 53.0k/1M                     5h ▰▰▱▱▱▱▱▱ 23% reset 17:00
```

- **Izquierda**: nombre de la carpeta del proyecto · rama git (`*` si hay cambios)
  · contexto `pct% │ tokens/max` (1M se muestra como `1M`, no `1000k`).
- **Derecha (pegada al borde)**: `5h [barra] pct% reset HH:MM`.
- Colores por umbral: contexto verde/amarillo/rojo en 50/80; rate limit en 60/85.

### 1.4 Detalles de implementación (por si hay que ajustar)

- La alineación derecha usa la variable `COLUMNS` que Claude Code expone
  (v2.1.153+). El `MARGIN=3` dentro del script evita que el texto se trunque
  contra el borde — si en tu pantalla se corta, subilo; si queda muy separado,
  bajalo.
- El script **además cachea** el rate limit a `~/.cache/claude/ratelimit.json` en
  cada ejecución. Eso era para una versión vieja del módulo de Waybar; el módulo
  actual usa la API y ya **no** depende de ese archivo. Es inofensivo dejarlo.

---

## 2. Módulo de Waybar: rate limit de los agentes

### 2.1 Copiar los scripts

```bash
mkdir -p ~/.config/waybar
cp REPO/docs/waybar-ai-usage/waybar/claude-usage.sh  ~/.config/waybar/
cp REPO/docs/waybar-ai-usage/waybar/codex-usage.sh   ~/.config/waybar/
cp REPO/docs/waybar-ai-usage/waybar/agents-usage.sh  ~/.config/waybar/
cp REPO/docs/waybar-ai-usage/waybar/agents-toggle.sh ~/.config/waybar/
chmod +x ~/.config/waybar/{claude,codex,agents}-usage.sh ~/.config/waybar/agents-toggle.sh
```

### 2.2 Agregar el módulo a `~/.config/waybar/config.jsonc`

**a) Sumá `custom/agents` (y un separador) a una zona de la barra.** Por ejemplo,
a la derecha de los workspaces:

```jsonc
"modules-left": ["hyprland/workspaces", "custom/separator", "custom/agents"],
```

**b) Definí los dos módulos** (en cualquier parte del objeto raíz):

```jsonc
"custom/separator": {
  "format": "•",
  "tooltip": false
},
"custom/agents": {
  "exec": "$HOME/.config/waybar/agents-usage.sh",
  "return-type": "json",
  "interval": 180,
  "signal": 11,
  "on-click": "$HOME/.config/waybar/agents-toggle.sh"
}
```

> **`signal: 11`** debe ser un número libre (Omarchy ya usa 7/8/9/10 para
> update/screenrecording/idle/notification). El click invierte el toggle y manda
> `pkill -RTMIN+11 waybar` para refrescar al instante. Si en tu config 11 está
> ocupado, cambiá el número en **ambos** lugares: el `"signal"` del módulo y el
> `pkill -RTMIN+N` dentro de `agents-toggle.sh`.

### 2.3 Estilos en `~/.config/waybar/style.css`

```css
/* Separador */
#custom-separator {
  opacity: 0.25;
  margin: 0 8px;
}

/* Módulo de agentes (Claude / Codex toggle) */
#custom-agents {
  margin-left: 4px;
  margin-right: 9px;
}
#custom-agents.warning  { color: #d6a85a; }
#custom-agents.critical { color: #a55555; }
```

### 2.4 Aplicar

```bash
omarchy restart waybar
```

### 2.5 Qué muestra

```
ᴄʟᴀᴜᴅᴇ ▰▰▰▱▱ 64%      (click)→      ᴄᴏᴅᴇx ▰▱▱▱▱ 12%
```

- Nombre chico y tenue en color de marca (Claude `#d97757`, Codex `#6b8cff`).
- Mini barra de 5 segmentos + `%`. El `%` se colorea por umbral (60/85).
- **Click** alterna Claude↔Codex (estado en `~/.cache/agents-toggle`; default Claude).
- **Errores visibles**: si algo no se puede arreglar (auth muerta, sin datos),
  muestra `NOMBRE ⚠` con el detalle en el tooltip. Nunca un valor viejo disfrazado.

---

## 3. Cómo funciona (resumen técnico)

### Endpoints (no oficiales — pueden cambiar)

| | Usage (GET) | Refresh (POST) | Credenciales |
|---|---|---|---|
| **Claude** | `https://api.anthropic.com/api/oauth/usage` headers `Authorization: Bearer`, `anthropic-beta: oauth-2025-04-20`, `anthropic-version: 2023-06-01` | `https://console.anthropic.com/v1/oauth/token` · client_id `9d1c250a-e61b-44d9-88ed-5944d1962f5e` | `~/.claude/.credentials.json` → `claudeAiOauth.{accessToken,refreshToken,expiresAt}` |
| **Codex** | `https://chatgpt.com/backend-api/wham/usage` headers `Authorization: Bearer`, `ChatGPT-Account-Id` | `https://auth.openai.com/oauth/token` · client_id `app_EMoamEEZ73f0CkXaXp7hrann` | `~/.codex/auth.json` → `tokens.{access_token,refresh_token,account_id}` |

- Respuesta de Claude: `five_hour.utilization` (%) + `five_hour.resets_at` (ISO);
  `seven_day.*` para el tooltip semanal.
- Respuesta de Codex (`wham/usage`): el script parsea **defensivamente** varias
  rutas posibles (`primary.used_percent`, `rate_limits.primary…`, etc.) porque no
  se pudo confirmar el formato exacto. Si tras `codex login` aparece
  `CODEX ⚠ respuesta no reconocida`, ver §5.

### Tokens y refresh

- El access token expira (~1h Claude, ~más en Codex). Cuando la API responde
  **401**, el script **refresca** con el refresh token y **reescribe** el archivo
  de credenciales (merge con `jq`, escritura atómica `mktemp`+`mv`, backup `.bak`
  la primera vez, permisos `600`). Igual que hacen los CLIs.
- El refresh token **rota** (de un solo uso). Riesgo mínimo de colisión si el CLI
  local y el script refrescan en el mismo instante → uno recibe "token already
  used" y se recupera al ciclo siguiente leyendo el token nuevo.

### Throttle (clave para no autogenerar rate limit)

Cada click forzaría un request. Para evitar spam (y el **429 agresivo** del
endpoint de Claude), cada script cachea su **última salida real** en
`~/.cache/{claude,codex}/output.json` y, si tiene menos de `THROTTLE` segundos
(Claude 90, Codex 45), la sirve **al instante sin tocar la red**. Así clickear
para alternar es instantáneo y nunca dispara rate limit.

- Un **429** se trata como error **transitorio**: muestra el último % conocido
  **atenuado** (si tiene <30 min) en vez de `⚠`. El `⚠` queda para errores que
  no se arreglan solos.

---

## 4. Verificación

```bash
# Salida JSON válida de cada módulo
bash ~/.config/waybar/claude-usage.sh | jq .
bash ~/.config/waybar/codex-usage.sh  | jq .

# El throttle: 1ra llamada real, 2da instantánea (cache)
time bash ~/.config/waybar/agents-usage.sh >/dev/null   # ~0.2–6s
time bash ~/.config/waybar/agents-usage.sh >/dev/null   # ~0.03s

# Ver la barra renderizada (franja superior)
grim -g "0,0 1440x32" /tmp/bar.png && xdg-open /tmp/bar.png
```

- El `%` de Claude debe coincidir con el indicador de uso de Claude Code.
- El de Codex, con `/status` dentro del TUI de Codex.
- Tras un refresh del script, abrir Claude Code / `codex` **no** debe pedir
  re-login (las credenciales siguen válidas).

---

## 5. Problemas comunes

| Síntoma | Causa / Solución |
|---|---|
| `CODEX ⚠ … corré: codex login` | El refresh token local está muerto. Correr `codex login`. |
| `CODEX ⚠ respuesta no reconocida` | El formato de `wham/usage` no matchea. Correr el comando de abajo y ajustar las rutas `jq` en `codex-usage.sh`. |
| `CLAUDE ⚠ HTTP 429` un rato | Rate limit transitorio (a veces por clickear de más). Se recupera solo; el throttle lo previene. |
| La barra aparece **vacía** (sin nada) | NO uses el módulo `image` de Waybar — en v0.15.0 blanquea toda la barra. Por eso usamos texto/glyphs. |
| Glyphs como tofu (cuadros) | Falta Nerd Font o codepoint inexistente en tu versión. Los `▰▱`/`⚠` usados son seguros con JetBrainsMono Nerd Font. |

Inspeccionar el formato real de Codex (tras `codex login`):

```bash
at=$(jq -r .tokens.access_token ~/.codex/auth.json)
acc=$(jq -r .tokens.account_id ~/.codex/auth.json)
curl -s -H "Authorization: Bearer $at" -H "ChatGPT-Account-Id: $acc" \
  https://chatgpt.com/backend-api/wham/usage | jq .
```

Buscar dónde está el `used_percent`/`resets_at` de la ventana de 5h y, si difiere,
agregar esa ruta a los `jq` de parseo en `codex-usage.sh` (sección
"Defensive parsing").

---

## 6. (Opcional) Limpieza de layout que también hicimos

No son parte de "los dos cambios", pero por si querés el mismo look:

- **Reloj** solo la hora; al click muestra día/fecha/mes/año:
  ```jsonc
  "clock": { "format": "{:L%H:%M}", "format-alt": "{:L%A %d %B %Y}" }
  ```
- Sacar del array de módulos: `custom/omarchy` (botón Omarchy de la izquierda),
  `custom/update` (icono de actualización) y `custom/weather` (nube del centro).
- `#clock { margin-left: 0; }` en `style.css` para centrar el reloj.
