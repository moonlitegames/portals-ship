---
description: Ship this game to Portals — optionally mirror a delivered zip + commit/push first, then push the folder as a draft, verify the build, publish (unless --draft). Usage: /portals-ship:ship [label] [--zip path] [--draft]
---

You are shipping the browser game in the current working directory to Portals using the
`portals-web-games` MCP tools (from the official Portals plugin). Follow these steps exactly
and stop at the first failure — never "fix" the game silently.

Arguments: $ARGUMENTS — an optional release label (e.g. "Build 36"), optional `--zip <path>`,
optional `--draft`, optional `--skip-tests`, optional `--no-git`, optional `--no-ci` (skip the GitHub Actions wait), optional `--media` (upload the cover + gallery declared in .portals-ship.json).

0. Local leg (only when `--zip <path>` is given): mirror the delivered zip into this folder, then
   commit and push. Use the shell, one step at a time, showing each command:
     rm -rf /tmp/ship-src && mkdir -p /tmp/ship-src && unzip -q "<path>" -d /tmp/ship-src
     rsync -a --delete --exclude .git --exclude .claude "<the extracted folder that contains index.html>/" ./
   (`.claude/` may hold live git worktrees and local settings — deleting it corrupts them.)
   If the repo has `./sync-build.sh`, prefer running it with the build number instead (it mirrors,
   runs the tests, commits and pushes in one go, and refuses to commit on a red suite). Otherwise, after the mirror and tests: `git add -A`,
   `git commit -m "<label>"`, `git push` (skip all git steps with `--no-git`). If the `gh` CLI is
   available (and `--no-ci` was not given), wait for CI — but NEVER watch "the latest run" blindly: immediately after a push,
   `gh run list --limit 1` can return the PREVIOUS commit's completed run (a false green). Resolve
   the run for THIS commit (`gh run list --commit "$(git rev-parse HEAD)"`, polling briefly until it
   appears), then `gh run watch <that id> --exit-status`, and stop if it is red.
1. Read `.portals-ship.json` in the working directory if present: `{ "game": "<name>", "gameId"?: "<id>", "multiplayer": false|{...} }`.
   If absent, ask which game to target before doing anything else.
2. Preflight: the folder must contain `index.html` at its root. If `package.json` has a `test`
   script and `--skip-tests` was not given (and it was not already run by sync-build.sh), run
   `npm test` and abort on failure, quoting the failing lines.
3. Call `list_web_games`; if `.portals-ship.json` has `gameId`, select that id; otherwise select the
   game whose name matches `game` (case-insensitive). If none matches, stop and list the names you found. If it returns ZERO games, that is an account
   mismatch (the saved credential is not the account that owns the game): explain it, point the user
   at re-authenticating (the `authenticate` tool with the owning account's access key, or
   `PORTALS_ACCESS_KEY`), and never create a game to work around it.
4. Stage a clean export and push THAT — never the live working directory (it carries `.claude/`
   worktrees whose nested `.git` pointer files trip Portals' secret/credential scanner, plus
   `.DS_Store` and other local noise):
     EXPORT="$(mktemp -d)/game"
     rsync -a --exclude .git --exclude .claude --exclude node_modules --exclude _tmp --exclude __pycache__ --exclude .DS_Store ./ "$EXPORT/"
   Call `push_web_game_source` with that export directory and `tag` = the label if one was given,
   then remove the temp directory after the push (success or failure).
   - If the tool returns build diagnostics or a rejection (e.g. UNSUPPORTED_THREE_ADDON), stop and
     report the diagnostic verbatim with the file it names. Do not proceed to publish.
   - Otherwise report the returned `share_url` (playable draft) and keep the `revision`.
5. If `--draft` was given, stop here: print the share_url and "draft only — not published".
6. Otherwise call `publish_web_game` with `expectedRevision` = that revision (and the tag only if the
   user wants the release named differently). If the server reports `PROJECT_CHANGED`, stop and explain
   that the remote moved and needs reconciling.
6b. Listing media (only when `--media` was given): if `.portals-ship.json` has `featuredImage`
   and/or `gallery` (paths relative to the working directory), call `update_web_game_settings` with
   `featuredImagePath` and `galleryPaths` (gallery REPLACES the whole gallery, in order — max 8 items,
   at most 1 video; images ≤10 MB, video ≤100 MB, JPEG/PNG/WebP/MP4/WebM). Report what was set.
7. Report: label, revision, draft share_url, and the published game link. If `update_web_game_settings`
   reports missing publishing requirements (e.g. player support not declared), state them; set
   `multiplayer` from `.portals-ship.json` only when the user confirms.

Never call `update_web_game_settings` for anything else, never delete a game, and never pull source
over the working directory during a ship.
