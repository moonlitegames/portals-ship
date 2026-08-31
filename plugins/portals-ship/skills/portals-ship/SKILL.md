---
name: portals-ship
description: Deploying browser games to Portals from a local folder — push as draft, read build diagnostics, publish a specific revision. Use when someone asks to ship, deploy, push, publish, or update a Portals web game, or complains they "have to delete and re-upload the zip".
---

# Shipping to Portals without the web uploader

The Portals MCP (`portals-web-games`, from `portals-plugin-claude`) updates a game **in place**:

- `list_web_games` → find the game and its current `revision`
- `push_web_game_source(directory, tag?, expectedRevision?)` → uploads the folder whose root has
  `index.html`, runs the platform build/scanner, returns diagnostics + a draft `share_url` + `revision`
- `publish_web_game(expectedRevision, tag?)` → promotes exactly that draft revision
- `get_web_game_share_link` → the draft link again, any time

So the "delete the game and redo it with a new zip" workaround is unnecessary: push the new folder,
read the diagnostics, publish. GitHub sync is optional (keep it for CI and history), not required.

Use the `/portals-ship:ship` command for the guarded, step-by-step version of this flow. The companion
`scripts/ship.sh` handles the local leg (apply a delivered zip, run tests, commit, push, wait for CI)
and then hands off to this command.

Common diagnostics: `UNSUPPORTED_THREE_ADDON` — the repo references a managed-runtime add-on module
(the three add-ons import path) that Portals does not host; their scanner reads comments and vendored
files too. Remove the reference or vendor the file under a different path. Always report diagnostics verbatim; never edit game code to "make it pass"
unless the user asks.
