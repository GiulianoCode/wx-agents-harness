#!/usr/bin/env bash
# Flip the agents module between claude and codex, then force Waybar to refresh
# the custom/agents module (signal RTMIN+11).

f="$HOME/.cache/agents-toggle"
mkdir -p "$HOME/.cache" 2>/dev/null
cur=$(cat "$f" 2>/dev/null)
if [ "$cur" = "codex" ]; then echo claude > "$f"; else echo codex > "$f"; fi
pkill -RTMIN+11 waybar
