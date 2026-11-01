#!/usr/bin/env bash
# Second tmux status line: what the Claude agents in OTHER sessions are doing.
#
#   convai-bench…[💬 Review Workmux setup 8m ✅ 2🤖] │ bootup-time[✅ fix ci 12m] │ data-tools
#
# Sessions in most-recently-attached order, current one excluded (it already owns the
# accent pill in the bar above), 4 slots. Anything waiting that falls outside the 4
# slots is rolled into an overflow chip so it can never go invisible.
#
# Each chip names ONE window: the agent that has been wanting Parth longest (waiting
# before done). Working agents stay anonymous as a bare count — they need nothing, so
# a name would be noise. Any remaining waiting/done agents trail as counts too, which
# is why a chip can show 💬 twice: the leading one is the named window, the trailing
# one is "and another".
#
# Session names are project dirs and repeat a lot, so they get truncated hard; window
# names are what Claude renames itself to (the task) and carry the actual signal, so
# they get the room.
#
# Arg: the calling client's #{session_id} (passed from status-format[1]; a bare
# `display-message -p` would be ambiguous when several clients are attached).
# State files are written by ~/bin/claude-state.
set -uo pipefail

cur="${1:-}"
dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-agents"
TAB=$'\t'
BG='#181825'          # Mocha mantle: one step darker than the bar above, reads as secondary

# Trailing style fills the rest of the line, so set the background once and only ever
# change fg after this — emitting #[default] anywhere would tear a hole in the bar.
printf '#[bg=%s] ' "$BG"

# pane_title, not window_name: `automatic-rename` names a window after its ACTIVE pane's
# command, so a window holding Claude + a focused vim reports itself as "vim". The pane
# title is per-pane and is what Claude Code sets to the task. window_name is the fallback
# for panes with no title (and it is what manually-named windows like `ivr-docs` carry).
panes="$(tmux list-panes -a -F "#{pane_id}${TAB}#{session_id}${TAB}#{pane_title}${TAB}#{window_name}" 2>/dev/null)"
[ -n "$panes" ] || exit 0

{
  printf '%s\n' "$panes" | sed "s/^/P${TAB}/"
  tmux list-sessions -F "S${TAB}#{session_last_attached}${TAB}#{session_id}${TAB}#{session_name}" 2>/dev/null

  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    pane="%${f##*/}"
    # Reap state left behind by a pane that's gone (agent quit, window closed).
    case "$panes" in
      *"${pane}${TAB}"*) ;;
      *) rm -f "$f"; continue ;;
    esac
    read -r st ts < "$f" || continue
    [ -n "${ts:-}" ] || continue
    printf 'F%s%s%s%s%s%s\n' "$TAB" "$pane" "$TAB" "$st" "$TAB" "$ts"
  done
} | awk -F"$TAB" -v now="$(date +%s)" -v cur="$cur" -v bg="$BG" \
        -v smax=12 -v wmax=28 '
function age(t,   d) {
  d = now - t
  if (d < 60)   return int(d) "s"
  if (d < 3600) return int(d / 60) "m"
  return int(d / 3600) "h"
}
function trunc(s, n) { return length(s) > n ? substr(s, 1, n - 1) "…" : s }

$1 == "P" {
  sess[$2] = $3
  t = $4
  # Claude prefixes its pane title with a live activity glyph (✳ / ⠂ / ✓). Strip any
  # leading run of non-alphanumerics so the bar shows the task, not the spinner.
  sub(/^[^a-zA-Z0-9]+/, "", t)
  win[$2] = (t != "" ? t : $5)
  next
}
$1 == "S" { last[$3] = $2; name[$3] = $4; ids[++n] = $3; next }
$1 == "F" {
  s = sess[$2]
  if (s == "") next
  cnt[s, $3]++
  # Per state, remember the agent that entered it earliest — that is the one whose
  # window gets named, since it has been ignored longest.
  if ($3 != "working") {
    k = s SUBSEP $3
    if (!(k in oldest) || $4 + 0 < oldest[k] + 0) {
      oldest[k] = $4
      oldwin[k] = win[$2]
    }
  }
  next
}

END {
  # Selection sort by last-attached, descending. n is single digits; readability wins.
  for (i = 1; i <= n; i++) {
    for (j = i + 1; j <= n; j++) {
      if (last[ids[j]] + 0 > last[ids[i]] + 0) { t = ids[i]; ids[i] = ids[j]; ids[j] = t }
    }
  }

  slots = 4
  shown = 0
  out = ""
  over_wait = 0
  over_done = 0

  for (i = 1; i <= n; i++) {
    id = ids[i]
    if (id == cur) continue

    w = cnt[id, "waiting"] + 0
    d = cnt[id, "done"] + 0
    k = cnt[id, "working"] + 0

    if (shown >= slots) { over_wait += w; over_done += d; continue }

    # Urgency picks the name colour: waiting (blocked on Parth) > done (unread) >
    # working (fine on its own) > no agents at all (just a recent session).
    if (w)      col = "#fab387"   # peach
    else if (d) col = "#a6e3a1"   # green
    else if (k) col = "#89b4fa"   # blue
    else        col = "#585b70"   # surface1, barely there

    chip = sprintf("#[fg=%s]%s", col, trunc(name[id], smax))

    # The named agent: whichever of waiting/done is more urgent AND present. Its
    # window name and age lead the chip; everything else trails as bare counts.
    named = ""
    if (w)      named = "waiting"
    else if (d) named = "done"

    body = ""
    if (named != "") {
      key = id SUBSEP named
      body = sprintf("%s #[fg=#f9e2af]%s#[fg=#cdd6f4] %s",
                     (named == "waiting" ? "💬" : "✅"),
                     trunc(oldwin[key], wmax), age(oldest[key]))
      # Discount the one already named so the counts do not double-report it.
      if (named == "waiting") w--; else d--
    }

    if (w) body = body sep(body) atom(w, "💬")
    if (d) body = body sep(body) atom(d, "✅")
    if (k) body = body sep(body) atom(k, "🤖")
    if (body != "")
      chip = chip sprintf("#[fg=#585b70][#[fg=#cdd6f4]%s#[fg=#585b70]]", body)

    out = out (shown ? "#[fg=#45475a] │ " : "") chip
    shown++
  }

  if (over_wait || over_done) {
    tail = ""
    if (over_wait) tail = tail sprintf("+%d💬", over_wait)
    if (over_done) tail = tail (tail ? " " : "") sprintf("+%d✅", over_done)
    out = out sprintf("#[fg=#45475a]  ·  #[fg=#f9e2af]%s", tail)
  }

  print out
}

function sep(s) { return s == "" ? "" : " " }
function atom(c, icon) { return (c > 1 ? c icon : icon) }
'
