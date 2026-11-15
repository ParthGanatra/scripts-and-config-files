#!/usr/bin/env bash
# Turns Parth's own caffeinate on or off, and reports whether it runs.
#
#   caffeinate-toggle.sh status   exit 0 when one runs, 1 when none; prints the pids
#   caffeinate-toggle.sh on       start `caffeinate -is`, detached from any pane
#   caffeinate-toggle.sh off      stop every one of Parth's caffeinates
#   caffeinate-toggle.sh toggle   on when none runs, off otherwise (M-c, or a status click)
#
# `-is` keeps the Mac awake while letting the display sleep: -i blocks idle sleep, -s
# blocks system sleep while on AC power. Sessions, background jobs and the VPN keep running.
#
# "Parth's own" leaves out the short ones Claude Code starts by itself: `caffeinate -i -t
# 300` around a turn, and `caffeinate -i -w <pid>` from ~/.claude/hooks/keep-awake-bg.sh.
# Those only keep the system awake for a while, come and go all the time, and would make
# the indicator flicker.
set -uo pipefail

mine() {
  local pid args
  for pid in $(pgrep -x caffeinate); do
    args=$(ps -o args= -p "$pid") || continue
    [[ $args =~ ^caffeinate\ -i\ -(t|w)\ [0-9]+$ ]] && continue
    echo "$pid"
  done
}

# Re-runs the status segment now instead of at the next status-interval: the segment's
# command line carries @caffeinate_gen, so a new value is a new job for tmux.
redraw() {
  tmux set -g @caffeinate_gen "$(date +%s)$RANDOM" 2>/dev/null || return 0
  tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r c; do tmux refresh-client -S -t "$c"; done
  [ -n "${1:-}" ] && tmux display-message "$1"
  return 0
}

on() {
  nohup caffeinate -is </dev/null >/dev/null 2>&1 &
  redraw "caffeinate on: idle sleep blocked, and system sleep on AC power"
}

off() {
  local pids
  pids=$(mine)
  [ -n "$pids" ] && kill $pids
  redraw "caffeinate off"
}

case "${1:-toggle}" in
  status) pids=$(mine); [ -n "$pids" ] && echo "$pids"; [ -n "$pids" ] ;;
  on) [ -n "$(mine)" ] && redraw "caffeinate already on" || on ;;
  off) off ;;
  toggle) if [ -n "$(mine)" ]; then off; else on; fi ;;
  *) echo "usage: $0 status|on|off|toggle" >&2; exit 64 ;;
esac
