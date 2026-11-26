#!/usr/bin/env python3
"""tmux-resurrect post-save-layout hook: save each pane's real command.

resurrect saves the command line a pane's process started with, found among
the children of the pane's shell. That goes wrong in two ways:

1. A Claude pane that changed conversation after it started (/resume, /clear,
   a continuation after compaction) still shows its first conversation's id,
   or plain `claude`. A restore then opens the wrong conversation.
2. A process that is the pane's own process, not a child of its shell (Claude
   started by a script, every ccmux sidebar), saves an empty command, and
   resurrect restores nothing in that pane.

This hook rewrites the save file before resurrect compares it with the last
save:

- A pane with a live Claude Code process gets `claude --resume <id>`, with the
  conversation id that process has now, read from ~/.claude/sessions/<pid>.json
  (Claude Code writes one per process, with its tmux pane). Other flags on the
  saved command are kept.
- A pane titled "ccmux-sidebar" gets `ccmux sidebar` (the "~ccmux sidebar"
  entry in @resurrect-processes restores it).

resurrect runs it as: resurrect-claude-ids.py <save file>.
"""
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

SESSIONS_DIR = Path.home() / ".claude" / "sessions"
SIDEBAR_TITLE = "ccmux-sidebar"
# Flags that pick a conversation; dropped before `--resume <id>` is added.
PICK_WITH_VALUE = {"--resume", "-r", "--session-id"}
PICK_ALONE = {"--continue", "-c"}


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def live_claude_by_pane():
    """Map (tmux session name, pane id) to the newest live Claude session."""
    found = {}
    for f in SESSIONS_DIR.glob("*.json"):
        try:
            d = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        where, sid, pid = d.get("tmux"), d.get("sessionId"), d.get("pid")
        if not where or not sid or not isinstance(pid, int) or not alive(pid):
            continue
        # "adhoc:@1.%2" -> session "adhoc", pane "%2"
        session, _, rest = where.rpartition(":")
        pane = rest.rpartition(".")[2]
        if not session or not pane.startswith("%"):
            continue
        key = (session, pane)
        updated = d.get("updatedAt") or 0
        if key not in found or updated > found[key][0]:
            found[key] = (updated, sid, pid)
    return {k: (v[1], v[2]) for k, v in found.items()}


def panes_now():
    """Map (session, window index, pane index) to (pane id, pane pid)."""
    out = subprocess.run(
        ["tmux", "list-panes", "-a", "-F",
         "#{session_name}\t#{window_index}\t#{pane_index}\t#{pane_id}\t#{pane_pid}"],
        capture_output=True, text=True, check=True,
    ).stdout
    result = {}
    for line in out.splitlines():
        s, w, p, pane_id, pid = line.split("\t")
        result[(s, w, p)] = (pane_id, pid)
    return result


def args_of(pid):
    out = subprocess.run(["ps", "-o", "args=", "-p", str(pid)],
                         capture_output=True, text=True).stdout
    return out.strip()


def resume_command(saved, claude_pid, sid):
    base = saved or args_of(claude_pid)
    try:
        words = shlex.split(base)
    except ValueError:
        words = base.split()
    if not words or "claude" not in os.path.basename(words[0]):
        words = ["claude"]
    keep, skip = [words[0]], False
    for w in words[1:]:
        if skip:
            skip = False
        elif w in PICK_WITH_VALUE:
            skip = True
        elif w in PICK_ALONE or w.startswith("--resume="):
            pass
        else:
            keep.append(w)
    return " ".join([keep[0], "--resume", sid] + [shlex.quote(w) for w in keep[1:]])


def main():
    path = Path(sys.argv[1])
    claude = live_claude_by_pane()
    panes = panes_now()
    lines = path.read_text().split("\n")
    for i, line in enumerate(lines):
        f = line.split("\t")
        # pane, session, window, active, :flags, pane index, :title, :dir,
        # active, command, :full command
        if len(f) != 11 or f[0] != "pane":
            continue
        session, window, index, title = f[1], f[2], f[5], f[6].lstrip(":")
        saved = f[10][1:] if f[10].startswith(":") else f[10]
        pane = panes.get((session, window, index))
        if not pane:
            continue
        hit = claude.get((session, pane[0]))
        if hit:
            f[10] = ":" + resume_command(saved, hit[1], hit[0])
        elif title == SIDEBAR_TITLE:
            f[10] = ":ccmux sidebar"
        else:
            continue
        lines[i] = "\t".join(f)
    path.write_text("\n".join(lines))


if __name__ == "__main__":
    main()
