#!/usr/bin/env bash
# guard-clean-export.sh — PreToolUse hook for *push_web_game_source.
#
# Reads the PreToolUse JSON payload from stdin, pulls tool_input.directory,
# and refuses the push (exit 2) if that directory still contains a .git
# entry (file or dir — a worktree pointer counts) or a .claude dir anywhere
# inside it. A directory staged by scripts/export.sh always passes.
#
# Fails open (exit 0) on anything it can't read, so a bug here never blocks
# a legitimate push — only a positively dirty directory does.
set -uo pipefail

DIR="$(node -e '
  try {
    const input = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const dir = input.tool_input && input.tool_input.directory;
    if (dir) process.stdout.write(dir);
  } catch (e) {}
' 2>/dev/null)"

[ -n "$DIR" ] && [ -e "$DIR" ] || exit 0

BAD="$(find "$DIR" \( -name .git -o -name .claude \) -print -quit 2>/dev/null)"
if [ -n "$BAD" ]; then
  echo "portals-ship: blocked push — $DIR still has $BAD; stage a clean export with scripts/export.sh first" >&2
  exit 2
fi

exit 0
