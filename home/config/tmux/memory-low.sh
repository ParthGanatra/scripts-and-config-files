#!/usr/bin/env bash
# Print a tmux status segment ONLY when macOS reports memory pressure. Silent
# otherwise, so the bar stays clean until it matters. Same idea as
# battery-low.sh.
#
# The trigger is the kernel's pressure level, the signal behind Activity
# Monitor's memory graph: 1 = normal (green), 2 = warn (yellow), 4 = critical
# (red). Warn prints in peach, critical in red.
# Test override: MEM_PRESSURE_LEVEL=2 or 4.
set -uo pipefail

level="${MEM_PRESSURE_LEVEL:-$(sysctl -n kern.memorystatus_vm_pressure_level 2>/dev/null)}"
case "$level" in
  2) color='#fab387' ;; # Catppuccin Mocha peach
  4) color='#f38ba8' ;; # Catppuccin Mocha red
  *) exit 0 ;;
esac

# "Used" as Activity Monitor counts it: app memory (anonymous pages that are
# not purgeable) + wired + compressed, over physical RAM.
total="$(sysctl -n hw.memsize)"
used_pct="$(vm_stat | awk -v total="$total" '
  /page size of/ { page = $8 }
  /^Anonymous pages/ { anon = $3 }
  /^Pages purgeable/ { purge = $3 }
  /^Pages wired down/ { wired = $4 }
  /^Pages occupied by compressor/ { comp = $5 }
  END { printf "%d", (anon - purge + wired + comp) * page * 100 / total }
')"

# vm.swapusage reads "total = 3072.00M  used = 1483.44M  free = ...".
swap_mb="$(sysctl -n vm.swapusage | awk '{ for (i = 1; i < NF; i++) if ($i == "used") { sub("M", "", $(i + 2)); print $(i + 2) } }')"
swap="$(awk -v mb="${swap_mb:-0}" 'BEGIN { if (mb >= 1024) printf "%.1fG", mb / 1024; else printf "%dM", mb }')"

# Nerd-font memory-chip glyph.
printf ' #[fg=%s,bold]󰍛 RAM %s%% · swap %s#[nobold,default] ' "$color" "$used_pct" "$swap"
