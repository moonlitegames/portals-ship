# portals-ship — one-command Portals deploys for the whole team

Portals' web uploader makes updates painful ("delete the game and redo it"). Their official
MCP does not: it pushes a folder as a new draft revision, reports build diagnostics, and publishes
that exact revision. This plugin wraps that into one guarded command, plus a script for the git/CI leg.

## Validate before publishing the marketplace

    claude plugin validate tools/portals-ship      # from the game repo, or `.` from the marketplace root

## Install (each teammate, once)

    claude plugin marketplace add portals-labs/portals-plugin-claude
    claude plugin install portals-plugin-claude@portals          # the official Portals tools
    claude plugin marketplace add moonlitegames/portals-ship     # this repo (or a local path)
    claude plugin install portals-ship@moonlite

Requires Node 18+ and a Portals account signed in through the official plugin.

## Per game (once)

Put `.portals-ship.json` in the game folder:

    {
      "game": "The Search For the Moonlite Princess",
      "multiplayer": false,
      "featuredImage": "assets/marketing/cover_1600x900.jpg",
      "gallery": ["assets/marketing/shots/01.jpg", "assets/marketing/shots/trailer.mp4"]
    }

Featured image: JPEG/PNG/WebP up to 10 MB (Portals sets no pixel size; their cards are landscape,
so ~16:9 fits every surface). Gallery: up to 8 items, at most 1 video, images ≤10 MB, video ≤100 MB.
Add `--media` to a ship to upload them; they're skipped otherwise so covers aren't re-sent every build.

## Every release — one line in Claude Code, from the game folder

    /portals-ship:ship "Build 36" --zip ~/Downloads/moonlite-grove.zip

Claude mirrors the zip (via ./sync-build.sh when the repo has one), runs the tests, commits and
pushes, waits for GitHub Actions if `gh` is installed, pushes the folder to Portals as a draft,
reports any build diagnostic verbatim, and publishes that revision. Without `--zip` it ships the
folder as-is. `--draft` pushes a playable draft without publishing.

No Claude Code? `scripts/ship.sh "Build 36" --zip ~/Downloads/game.zip` does the local leg and
prints the command to run.

`ship.sh` mirrors an optional delivered zip, runs `npm test`, commits, pushes, waits for GitHub
Actions (needs the `gh` CLI), then invokes the Claude Code command headlessly. Add `--draft` to
push a playable draft without publishing. Any build diagnostic stops the ship and is reported verbatim.

## Notes from live runs

- A local-path marketplace references the repo in place (it is not copied), so plugin updates that
  arrive with a game build are live at source immediately — run `/reload-plugins` to refresh the
  wording mid-session.
- CI must be resolved by commit SHA, never `--limit 1` right after a push (false-green risk; the
  ship command now does this).
- If the auto-permission classifier blocks `./sync-build.sh`, either let Claude run its steps
  explicitly (documented alternative) or add a permission rule for it (e.g. allow
  `Bash(./sync-build.sh:*)` via /permissions) for unattended runs.

## Cowork

The same command runs in Claude Cowork once the Portals MCP server is added to Claude Desktop's
MCP config; schedule "ship the game" as a task and it follows the identical guarded steps.
