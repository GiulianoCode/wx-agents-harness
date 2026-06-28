#!/usr/bin/env bash
# Claude Code status line — single row
#  project  branch │ ctx [bar] used/max pct% │ 5h [bar] pct% reset HH:MM

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')

# Persist rate limits for external consumers (e.g. Waybar). Claude Code only
# exposes these live via this stdin payload, so we cache them on every run.
rl_json=$(echo "$input" | jq -c '.rate_limits // empty' 2>/dev/null)
if [ -n "$rl_json" ]; then
  mkdir -p "$HOME/.cache/claude" 2>/dev/null
  printf '%s\n' "$rl_json" > "$HOME/.cache/claude/ratelimit.json"
fi

DIM="\033[2m"
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"

# -- Render an 8-segment progress bar; arg1 = percentage (int) --
bar() {
  local pct=$1
  local total=8
  local filled=$(( (pct * total + 50) / 100 ))
  [ "$filled" -gt "$total" ] && filled=$total
  [ "$filled" -lt 0 ] && filled=0
  local out=""
  local i
  for ((i=0; i<total; i++)); do
    if [ "$i" -lt "$filled" ]; then out="${out}▰"; else out="${out}▱"; fi
  done
  printf '%s' "$out"
}

# -- Color by usage thresholds; arg1=pct, arg2=mid, arg3=high --
usage_color() {
  local pct=$1 mid=$2 high=$3
  if   [ "$pct" -ge "$high" ]; then printf '%b' "$RED"
  elif [ "$pct" -ge "$mid"  ]; then printf '%b' "$YELLOW"
  else                              printf '%b' "$GREEN"
  fi
}

# ---- Line 1: project + git ----
proj="${cwd:+${cwd##*/}}"
proj="${proj:-?}"

git_branch=""
if git -C "${cwd:-$PWD}" -c core.fsync=none rev-parse --git-dir &>/dev/null 2>&1; then
  git_branch=$(git -C "${cwd:-$PWD}" -c core.fsync=none symbolic-ref --short HEAD 2>/dev/null || \
               git -C "${cwd:-$PWD}" -c core.fsync=none rev-parse --short HEAD 2>/dev/null)

  dirty=""
  if [ -n "$(git -C "${cwd:-$PWD}" -c core.fsync=none status --porcelain=v1 2>/dev/null)" ]; then
    dirty="*"
  fi
fi

seg_proj="${DIM}${RESET}${proj}"
if [ -n "$git_branch" ]; then
  seg_proj="${seg_proj}  ${DIM}${git_branch}${dirty}${RESET}"
fi

# ---- Line 2: context window ----
ctx_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

seg_ctx=""
if [ -n "$ctx_tokens" ] && [ -n "$ctx_size" ] && [ -n "$ctx_pct" ]; then
  tokens_k=$(awk "BEGIN {printf \"%.1fk\", $ctx_tokens/1000}")
  size_k=$(awk "BEGIN {if ($ctx_size>=1000000) printf \"%gM\", $ctx_size/1000000; else printf \"%.0fk\", $ctx_size/1000}")
  pct_int=${ctx_pct%.*}
  col=$(usage_color "$pct_int" 50 80)
  seg_ctx="${col}${pct_int}%${RESET} ${DIM}│${RESET} ${DIM}${tokens_k}/${size_k}${RESET}"
fi

# ---- Line 3: 5h rate limit ----
rl_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

seg_rl=""
if [ -n "$rl_pct" ]; then
  pct_int=${rl_pct%.*}
  col=$(usage_color "$pct_int" 60 85)
  reset_time=""
  if [ -n "$rl_reset" ] && [ "$rl_reset" -gt 0 ] 2>/dev/null; then
    t=$(date -d "@${rl_reset}" +%H:%M 2>/dev/null || date -r "${rl_reset}" +%H:%M 2>/dev/null)
    [ -n "$t" ] && reset_time=" ${DIM}reset ${t}${RESET}"
  fi
  seg_rl="${DIM}5h${RESET} ${col}$(bar "$pct_int")${RESET} ${col}${pct_int}%${RESET}${reset_time}"
fi

# ---- Emit single row ----
SEP="  ${DIM}·${RESET}  "

# Left cluster: project + git + context
left="$seg_proj"
[ -n "$seg_ctx" ] && left="${left}${SEP}${seg_ctx}"

# Visible width (strip ANSI codes, count UTF-8 chars)
vlen() {
  local s
  s=$(printf '%b' "$1" | LC_ALL=C.UTF-8 sed $'s/\x1b\\[[0-9;]*m//g')
  LC_ALL=C.UTF-8 printf '%s' "${#s}"
}

if [ -n "$seg_rl" ] && [ -n "$COLUMNS" ]; then
  # Right-align the rate limit segment to the screen edge
  # Right margin: accounts for the status line's built-in left indent
  # plus columns Claude Code reserves on the right, to avoid truncation.
  MARGIN=3
  ll=$(vlen "$left")
  rl=$(vlen "$seg_rl")
  gap=$(( COLUMNS - ll - rl - MARGIN ))
  [ "$gap" -lt 2 ] && gap=2
  pad=$(printf '%*s' "$gap" '')
  printf "%b%s%b" "$left" "$pad" "$seg_rl"
else
  line="$left"
  [ -n "$seg_rl" ] && line="${line}${SEP}${seg_rl}"
  printf "%b" "$line"
fi
