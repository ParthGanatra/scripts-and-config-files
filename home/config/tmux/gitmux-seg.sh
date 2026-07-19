#!/usr/bin/env bash
# Catppuccin-styled gitmux status segment, emitted ONLY when the pane's directory
# is inside a git work tree. Silent (no icon, no segment) everywhere else.
# Arg: the pane's current path.  Styling mirrors the shipped catppuccin gitmux module.
set -uo pipefail

dir="${1:-$PWD}"
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

text="$(gitmux -cfg "$HOME/.gitmux.conf" "$dir" 2>/dev/null)"
[ -n "$text" ] || exit 0

# Mocha: teal #94e2d5 icon block on base #11111b; text on surface0 #313244.
printf '#[fg=#94e2d5]#[fg=#11111b,bg=#94e2d5]󰊢 #[fg=#cdd6f4,bg=#313244] %s #[fg=#313244]#[default] ' "$text"
