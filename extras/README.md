# extras/ — config de sistema (opcional, temporal)

Esto **no es parte del harness en sí**. Son configs de sistema (Hyprland/waybar +
statusline) que se incluyen **temporalmente** para poder replicar el entorno completo
en otra máquina (p.ej. pasar todo a una PC desktop nueva sin tener que copiarlas aparte).

## Qué hay

- `waybar/` — módulos de Waybar que muestran el rate limit de 5h **en vivo** (Claude
  por defecto, click para alternar a Codex):
  - `claude-usage.sh`, `codex-usage.sh` — leen la API de usage de cada agente.
  - `agents-usage.sh` — dispatcher según el toggle. `agents-toggle.sh` — alterna.
- `REPLICAR.md` — guía paso a paso para reproducir en otra máquina **el statusline de
  Claude Code + los módulos de Waybar** (Arch + Hyprland + Omarchy).

> El **statusline** del harness vive en `.harness/statusline/statusline.sh` y se
> instala con `.harness/bin/setup-statusline.sh`. Waybar es puramente visual y
> específico de Hyprland: si no usás waybar, ignorá esta carpeta.

## Migrar a otra máquina (resumen)

1. Cloná este repo en la máquina nueva.
2. Statusline (fuente del harness + indicador): `bash .harness/bin/setup-statusline.sh`.
3. Waybar (opcional): seguí `extras/REPLICAR.md` (copia los `.sh` a `~/.config/waybar/`
   y agrega el módulo `custom/agents`).
