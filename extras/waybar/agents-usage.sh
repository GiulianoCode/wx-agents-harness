#!/usr/bin/env bash
# Waybar: single "agents" module. Shows Claude by default; click toggles to
# Codex and back (state in ~/.cache/agents-toggle). Delegates to the per-agent
# script so all the live-API / refresh / error logic lives in one place.

state=$(cat "$HOME/.cache/agents-toggle" 2>/dev/null)
case "$state" in
  codex) exec bash "$HOME/.config/waybar/codex-usage.sh" ;;
  *)     exec bash "$HOME/.config/waybar/claude-usage.sh" ;;
esac
