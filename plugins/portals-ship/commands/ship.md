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
1. Read `.portals-ship.json` in the working directory if present: `{ "game": "<name>", "gameId"?: "<id>", "multiplayer": false|{...}, "exclude"?: [...], "include"?: [...] }`.
   If absent, ask which game to target before doing anything else. `exclude` adds extra paths on top of
   the built-in export excludes (`.git .claude node_modules _tmp __pycache__ .DS_Store`); `include`, when
   present, exports ONLY those paths instead of the whole folder (excludes still apply inside them) —
   use it for a repo whose folder holds docs, tools, or notes that should not go public (see step 4).
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
   `.DS_Store` and other local noise). Run the plugin's export script and use the path it prints —
   it is the one source of truth for what an export excludes, applies `.portals-ship.json`'s
   `exclude`/`include`, and refuses to hand back anything that still has `.git`/`.claude` in it or
   is missing `index.html`:
     EXPORT="$("${CLAUDE_PLUGIN_ROOT}/scripts/export.sh")"
   Call `push_web_game_source` with `$EXPORT` and `tag` = the label if one was given, then
   `rm -rf` the directory `export.sh` printed (its parent temp dir) after the push (success or
   failure). A PreToolUse hook also independently refuses the push if the directory it's given
   still contains `.git` or `.claude` — treat that block as a bug in how `$EXPORT` was built, not
   something to work around.
   - Note what the export script printed to stderr (the manifest): everything in it becomes
     downloadable by any player from the game's origin the moment this push lands. If the folder
     holds docs, tools, or design notes alongside the game, that's a sign to add an `include` key
     to `.portals-ship.json` (step 1) rather than ship the whole tree.
   - If the tool returns build diagnostics or a rejection (e.g. UNSUPPORTED_THREE_ADDON), stop and
     report the diagnostic verbatim with the file it names. Do not proceed to publish.
   - Otherwise report the returned `share_url` (playable draft) and keep the `revision`.
5. If `--draft` was given, stop here: print the share_url and "draft only — not published".
6. Otherwise, if the folder has `tools/check-ship.mjs`, run `node tools/check-ship.mjs --publish`
   first and stop on a non-zero exit (its one line names the missing version tag — the last
   published version must be tagged before the next one ships). Then call `publish_web_game` with `expectedRevision` = that revision (and the tag only if the
   user wants the release named differently). If the server reports `PROJECT_CHANGED`, stop and explain
   that the remote moved and needs reconciling.
6b. Listing media (only when `--media` was given): if `.portals-ship.json` has `featuredImage`
   and/or `gallery` (paths relative to the working directory), call `update_web_game_settings` with
   `featuredImagePath` and `galleryPaths` (gallery REPLACES the whole gallery, in order — max 8 items,
   at most 1 video; images ≤10 MB, video ≤100 MB, JPEG/PNG/WebP/MP4/WebM). Report what was set.
7. Report: label, revision, draft share_url, and the published game link. After a successful
   publish, print the exact tag line with the real values — the published `version` from the
   publish result, the shipped commit (`git rev-parse --short HEAD` of the folder you pushed) and
   the label — and say the creator runs it (a publish is not done until the version is tagged and
   pushed; never run it yourself, tags are a creator's action):
     git tag -a v<version> <sha> -m "<label>" && git push origin v<version> If `update_web_game_settings`
   reports missing publishing requirements (e.g. player support not declared), state them; set
   `multiplayer` from `.portals-ship.json` only when the user confirms.

Never call `update_web_game_settings` for anything else, never delete a game, and never pull source
over the working directory during a ship.
