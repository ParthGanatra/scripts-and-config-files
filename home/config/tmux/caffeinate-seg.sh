#!/usr/bin/env bash
# tmux status segment: a coffee glyph, bright while Parth's own caffeinate runs and dim
# while none does. A click on it, or M-c, toggles it (caffeinate-toggle.sh). The argument
# is @caffeinate_gen, there only so a toggle re-runs this at once.
if ~/.config/tmux/caffeinate-toggle.sh status >/dev/null; then
  printf ' #[fg=#f9e2af]󰅶#[default] '   # Catppuccin Mocha yellow: on
else
  printf ' #[fg=#585b70]󰅶#[default] '   # Catppuccin Mocha surface2: off
fi
