#!/usr/bin/env bash
# Print a tmux status segment ONLY when on battery power and at/below the low
# threshold. Silent otherwise, so the bar stays clean until it matters.
# Threshold override: BATT_LOW_THRESHOLD (default 20).
set -uo pipefail

threshold="${BATT_LOW_THRESHOLD:-20}"

info="$(pmset -g batt 2>/dev/null)" || exit 0
pct="$(printf '%s\n' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')"

# No battery (desktop) or unparseable -> show nothing.
[ -n "$pct" ] || exit 0
# Only warn while discharging; if it's charging/charged, Parth's already on it.
printf '%s\n' "$info" | grep -q 'discharging' || exit 0

if [ "$pct" -le "$threshold" ]; then
  # Catppuccin Mocha red; nerd-font low-battery glyph.
  printf ' #[fg=#f38ba8,bold]󰂃 %s%%#[nobold,default] ' "$pct"
fi
