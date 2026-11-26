#!/usr/bin/env bash
# Print a tmux status segment ONLY when the newest tmux-resurrect save is over
# 30 minutes old. Silent otherwise, like memory-low.sh and battery-low.sh.
#
# tmux-continuum saves every 15 minutes, so an older save means auto-save has
# stopped and a reboot would restore an old layout. prefix + Ctrl-s saves by hand.
# Peach over 30 minutes, red over 2 hours.
#
# The save time is the newer mtime of pane_contents.tar.gz (rewritten on every
# save, because @resurrect-capture-pane-contents is on) and of `last` (changes
# only when the layout changed). The server's start time counts as a save, so a
# fresh server isn't flagged before continuum's first save is due.
#
# Overrides: RESURRECT_STALE_MIN (default 30); RESURRECT_AGE_MIN fakes the age.
set -uo pipefail

stale_min="${RESURRECT_STALE_MIN:-30}"
dir="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"
custom="$(tmux show -gqv @resurrect-dir 2>/dev/null)"
[ -n "$custom" ] && dir="$(eval echo "$custom")"

now="$(date +%s)"
newest="$(tmux display -p '#{start_time}' 2>/dev/null)"
newest="${newest:-0}"
for f in "$dir/pane_contents.tar.gz" "$dir/last"; do
  [ -e "$f" ] || continue
  m="$(stat -L -f %m "$f" 2>/dev/null)" || continue
  [ "$m" -gt "$newest" ] && newest="$m"
done

if [ -n "${RESURRECT_AGE_MIN:-}" ]; then
  age_min="$RESURRECT_AGE_MIN"
else
  age_min=$(( (now - newest) / 60 ))
fi
[ "$age_min" -gt "$stale_min" ] || exit 0

if [ "$age_min" -ge 2880 ]; then
  age="$(( age_min / 1440 ))d"
elif [ "$age_min" -ge 60 ]; then
  age="$(( age_min / 60 ))h"
else
  age="${age_min}m"
fi

if [ "$age_min" -gt 120 ]; then
  color='#f38ba8'   # Catppuccin Mocha red
else
  color='#fab387'   # Catppuccin Mocha peach
fi

# Nerd-font floppy (content-save) glyph.
printf ' #[fg=%s,bold]󰆓 saved %s ago#[nobold,default] ' "$color" "$age"
