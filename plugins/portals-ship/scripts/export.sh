#!/usr/bin/env bash
# export.sh — stage a clean, deploy-ready export of the current folder.
#
#   export.sh              export $PWD, print the export path on stdout
#
# Reads optional .portals-ship.json in the current folder:
#   "exclude": [...]   extra rsync excludes, added to the built-in defaults
#   "include": [...]   if present, export ONLY these paths (preserving their
#                       structure) instead of the whole folder; excludes still
#                       apply inside them. Fails if an include path is missing.
#
# Self-checks the result: refuses to hand back an export that still contains
# a .git or .claude entry anywhere, or that has no index.html at its root.
# Everything under the printed path ends up world-downloadable once pushed —
# the manifest on stderr is so every ship shows what is going public.
set -uo pipefail

SRC="$(pwd)"
CONFIG="$SRC/.portals-ship.json"
WORK="$(mktemp -d)"
DEST="$WORK/game"
mkdir -p "$DEST"

DEFAULT_EXCLUDES=(.git .claude node_modules _tmp __pycache__ .DS_Store)

fail() {
  echo "export.sh: $1" >&2
  rm -rf "$WORK"
  exit 1
}

# Reads a JSON array key ("exclude" or "include") from .portals-ship.json,
# one entry per line. Silent no-op if the file or key is absent/invalid.
read_array() {
  local key="$1"
  [ -f "$CONFIG" ] || return 0
  node -e '
    try {
      const fs = require("fs");
      const data = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
      const arr = Array.isArray(data[process.argv[1]]) ? data[process.argv[1]] : [];
      for (const v of arr) process.stdout.write(v + "\n");
    } catch (e) {}
  ' "$key" "$CONFIG" 2>/dev/null
}

EXTRA_EXCLUDES=()
while IFS= read -r line; do [ -n "$line" ] && EXTRA_EXCLUDES+=("$line"); done < <(read_array exclude)

INCLUDES=()
while IFS= read -r line; do [ -n "$line" ] && INCLUDES+=("$line"); done < <(read_array include)

RSYNC_EXCLUDES=()
for e in "${DEFAULT_EXCLUDES[@]}"; do
  RSYNC_EXCLUDES+=(--exclude "$e")
done
# Guard the expansion: bash < 4.4 (macOS's /bin/bash is 3.2) treats
# "${arr[@]}" on an EMPTY array as an unbound variable under `set -u`.
if [ "${#EXTRA_EXCLUDES[@]}" -gt 0 ]; then
  for e in "${EXTRA_EXCLUDES[@]}"; do
    RSYNC_EXCLUDES+=(--exclude "$e")
  done
fi

if [ "${#INCLUDES[@]}" -gt 0 ]; then
  for path in "${INCLUDES[@]}"; do
    SRC_PATH="$SRC/$path"
    [ -e "$SRC_PATH" ] || fail "include path missing: $path"
    DEST_PATH="$DEST/$path"
    mkdir -p "$(dirname "$DEST_PATH")"
    if [ -d "$SRC_PATH" ]; then
      mkdir -p "$DEST_PATH"
      rsync -a "${RSYNC_EXCLUDES[@]}" "$SRC_PATH/" "$DEST_PATH/" || fail "rsync failed on $path"
    else
      rsync -a "${RSYNC_EXCLUDES[@]}" "$SRC_PATH" "$DEST_PATH" || fail "rsync failed on $path"
    fi
  done
else
  rsync -a "${RSYNC_EXCLUDES[@]}" "$SRC/" "$DEST/" || fail "rsync failed"
fi

# Self-check: no .git or .claude anywhere in the export, regardless of
# whether excludes should have already caught it.
BAD="$(find "$DEST" \( -name .git -o -name .claude \) -print -quit 2>/dev/null)"
[ -z "$BAD" ] || fail "refusing to ship — found $BAD"

[ -f "$DEST/index.html" ] || fail "refusing to ship — index.html missing at export root"

# Manifest to stderr: top-level entries + total file count, so every ship
# shows what is about to become public (every exported file is downloadable
# by any player from the game's origin once pushed).
FILE_COUNT="$(find "$DEST" -type f | wc -l | tr -d ' ')"
{
  echo "export.sh: $FILE_COUNT files, top level:"
  ( cd "$DEST" && ls -A ) | sed 's/^/  /'
} >&2

echo "$DEST"
