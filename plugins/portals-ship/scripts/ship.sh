#!/usr/bin/env bash
# ship.sh — local leg of a Portals deploy, then hand off to Claude Code.
#   ship.sh "Build 35"                      commit+push, wait for CI, ship
#   ship.sh "Build 35" --zip ~/Downloads/game.zip   first mirror a delivered zip into this folder
#   ship.sh "Build 35" --draft              push a draft only, do not publish
#   flags: --skip-tests  --no-git  --no-ci
set -euo pipefail
LABEL="${1:-}"; shift || true
ZIP=""; DRAFT=""; SKIP_TESTS=""; NO_GIT=""; NO_CI=""
while [ $# -gt 0 ]; do case "$1" in
  --zip) ZIP="$2"; shift 2;; --draft) DRAFT="--draft"; shift;; --skip-tests) SKIP_TESTS=1; shift;;
  --no-git) NO_GIT=1; shift;; --no-ci) NO_CI=1; shift;; *) echo "unknown flag $1"; exit 2;; esac; done
[ -f index.html ] || { echo "run this from the game folder (index.html at root)"; exit 1; }

if [ -n "$ZIP" ]; then
  [ -f "$ZIP" ] || { echo "no zip at $ZIP"; exit 1; }
  TMP="$(mktemp -d)"; unzip -q "$ZIP" -d "$TMP"
  SRC="$(find "$TMP" -maxdepth 2 -name index.html -exec dirname {} \; | head -1)"
  [ -n "$SRC" ] || { echo "zip has no index.html"; exit 1; }
  rsync -a --delete --exclude .git --exclude .claude "$SRC/" ./
  rm -rf "$TMP"; echo "mirrored $ZIP"
fi

if [ -z "$SKIP_TESTS" ] && [ -f package.json ] && grep -q '"test"' package.json; then
  echo "== npm test"; npm test >/tmp/ship-test.log 2>&1 || { tail -30 /tmp/ship-test.log; echo "tests failed — not shipping"; exit 1; }
  tail -3 /tmp/ship-test.log
fi

if [ -z "$NO_GIT" ] && [ -d .git ]; then
  git add -A; git commit -qm "${LABEL:-ship}" || true; git push
  if [ -z "$NO_CI" ] && command -v gh >/dev/null 2>&1; then
    echo "== waiting for CI"; sleep 8
    RUN="$(gh run list --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
    if [ -n "$RUN" ]; then gh run watch "$RUN" --exit-status || { echo "CI red — not shipping"; exit 1; }; fi
  fi
fi

if command -v claude >/dev/null 2>&1; then
  echo "== shipping to Portals via Claude Code"
  claude -p "/portals-ship:ship ${LABEL} ${DRAFT}" --allowedTools "mcp__portals-web-games__*,Bash(npm test)"
else
  echo "Claude Code not found. Open this folder in Claude Code and run:  /portals-ship:ship ${LABEL} ${DRAFT}"
fi
