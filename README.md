# portals-ship — one-command Portals deploys from Claude Code

Portals' web uploader makes updates painful ("delete the game and redo it"). The official
Portals MCP does not: it pushes a folder as a new draft revision, reports build diagnostics,
and publishes that exact revision. This plugin wraps that into one guarded command for any
Claude Code project, plus a script for the local git/CI leg.

    /portals-ship:ship "1.4.0"            # tests -> commit/push -> CI -> draft -> diagnostics -> publish
    /portals-ship:ship "1.4.0" --draft    # stop at the playable draft link

## Requirements

- A **git repository** for the game (the command commits and pushes the release; `--no-git` opts out).
- **Claude Code** with the **official Portals plugin** installed, and its `portals-web-games` MCP
  server **authenticated as the account that owns the game** (`list_web_games` must show it).
- `index.html` at the root of the folder you ship (for a bundler project that is `dist/` or
  `build/` after the build — run it from there or point the command at it).
- Optional: Node 18+ when the project has an `npm test` script (it is honored automatically), and
  the `gh` CLI when the repo runs GitHub Actions (the ship waits for the run of the pushed commit).

## Install (each teammate, once)

    claude plugin marketplace add portals-labs/portals-plugin-claude
    claude plugin install portals-plugin-claude@portals          # the official Portals tools + MCP
    claude plugin marketplace add moonlitegames/portals-ship     # this repo (or a local path to a clone)
    claude plugin install portals-ship@moonlite

Then, in the game folder, tell Claude Code to `authenticate` with Portals once (browser login) and
check that `list_web_games` lists the game. Validate a local clone before publishing changes to the
marketplace with `claude plugin validate .` from the repo root.

## Per project (once): `.portals-ship.json`

Put `.portals-ship.json` in the folder you ship from:

    {
      "game": "My Game",                                   // listing title, matched case-insensitively
      "gameId": "g921ecf5bdb3fd9fb62bcdcc0",               // optional: the exact id from list_web_games (wins over the name)
      "multiplayer": false,                                // or { "maxPlayers": 8, "mode": "coop" } — set only when you confirm
      "featuredImage": "assets/marketing/cover_1600x900.jpg",
      "gallery": ["assets/marketing/shots/01.jpg", "assets/marketing/shots/trailer.mp4"],
      "exclude": ["docs/ledger"],
      "include": ["index.html", "js", "styles.css", "assets"]
    }

| key | meaning |
| --- | --- |
| `game` | The game's title on Portals. Required unless `gameId` is given; the command stops and lists what it found if nothing matches. |
| `gameId` | Optional. The `game_id` from `list_web_games`. Use it when two games share a title or you rename the listing. |
| `multiplayer` | `false` for single-player, or an object with `maxPlayers` and `mode`. Only applied to the listing when you confirm during a ship. |
| `featuredImage` | Path (relative to the folder) to the cover: JPEG/PNG/WebP up to 10 MB. Portals cards are landscape, so ~16:9 fits every surface. |
| `gallery` | Up to 8 paths, at most 1 video: images ≤10 MB, video (MP4/WebM) ≤100 MB. Replaces the whole gallery, in order. |
| `exclude` | Extra paths to leave out of the export, on top of the built-in `.git .claude node_modules _tmp __pycache__ .DS_Store`. |
| `include` | When present, the export contains ONLY these paths (structure preserved) instead of the whole folder — see "What ships is public", below. |

Media is uploaded only when a ship passes `--media`, so covers are not re-sent on every build.
Without the file, the command asks which game to target before doing anything else.

### What ships is public

**Every file in the export is downloadable by any player from the game's origin** — this isn't
theoretical: a stray docs `.md` file has been fetched with a plain 200 from a live game's URL.
Portals hosts exactly what `push_web_game_source` uploads; there is no server-side allowlist of
"the parts players should see." If your repo's folder holds design docs, internal tools, model
sources, or notes alongside the shippable game, add an `include` key to `.portals-ship.json`
listing only the runtime paths (e.g. `["index.html", "js", "styles.css", "assets"]`) so the export
never contains them in the first place — `exclude` alone only helps for noise you're certain has no
sibling worth publishing.

## Every release

From the game folder in Claude Code:

    /portals-ship:ship "<label>" [--zip <path>] [--draft] [--media] [--skip-tests] [--no-git] [--no-ci]

| flag | effect |
| --- | --- |
| `--zip <path>` | Mirror a delivered zip into the folder first (`rsync --delete`, keeping `.git` and `.claude`), then commit and push. If the repo has `./sync-build.sh`, it is used instead. |
| `--draft` | Push the playable draft and stop; nothing is published. |
| `--media` | Upload the cover and gallery declared in `.portals-ship.json`. |
| `--skip-tests` | Do not run `npm test` (the default runs it whenever `package.json` has a `test` script). |
| `--no-git` | Skip the commit/push leg entirely (a folder that is not a repo, or a release already pushed). |
| `--no-ci` | Skip waiting for GitHub Actions (no CI on the repo, or `gh` unavailable). |

The command runs the tests, commits and pushes, waits for the CI run of **that commit** (never
"the latest run", which can be the previous commit's green), pushes the folder to Portals as a
draft, reports any build diagnostic verbatim and stops on it, then publishes exactly that
revision. The label becomes the draft tag and the release tag.

Projects without tests or CI: pass `--skip-tests` and `--no-ci`, or simply have no `test` script
and no Actions workflow — both legs are skipped automatically when absent.

### After a publish: tag the version

A publish is not done until the version is tagged and pushed. After a successful publish the
command prints the exact line with the real values and stops — tags are a creator's action:

    git tag -a v<version> <sha> -m "<label>" && git push origin v<version>

If the project ships a `tools/check-ship.mjs` (moonlite-grove does), the command runs
`node tools/check-ship.mjs --publish` before publishing and stops when the last published
version is untagged or its tag is not reachable from HEAD. Drafts are never blocked.

### No Claude Code on the machine?

`scripts/ship.sh "<label>" [--zip path] [--draft] [--skip-tests] [--no-git] [--no-ci]` does the
local leg (mirror an optional zip, `npm test`, commit, push, wait for CI) and then invokes the
command headlessly when `claude` is on the PATH, or prints the command to run.

## Notes from live runs

- A local-path marketplace references the clone in place (it is not copied), so edits are live at
  source immediately — run `/reload-plugins` to refresh the wording mid-session.
- Ship from a **clean export**, always, when the repo holds Claude Code worktrees under `.claude/`:
  the bundler's credential scanner rejects a nested `.git` pointer file. `scripts/export.sh` is the
  one place this exclude list lives — the ship command runs it and pushes only the path it prints,
  and a plugin `PreToolUse` hook independently refuses `push_web_game_source` for any directory
  that still contains `.git` or `.claude`, so a working-directory push can't slip through even if a
  session skips the step. Use `.portals-ship.json`'s `exclude`/`include` (above) for anything
  project-specific — don't hand-roll a substitute rsync call.
- CI must be resolved by commit SHA. `gh run list --limit 1` right after a push can return the
  previous commit's completed run.
- If the auto-permission classifier blocks a project script such as `./sync-build.sh`, let Claude
  run its steps explicitly or add a permission rule for it (e.g. allow `Bash(./sync-build.sh:*)`).
- `list_web_games` returning zero games is an account mismatch, not an empty account: see the
  skill's field notes on Portals auth precedence.

## Versioning

`plugins/portals-ship/.claude-plugin/plugin.json` carries the plugin version (semver). Bump the
minor version when the command's steps or output change (teammates see it on `/reload-plugins`),
the patch version for wording. Tag the repo `v<version>` to match.

## Cowork

The same command runs in Claude Cowork once the Portals MCP server is added to Claude Desktop's
MCP config; schedule "ship the game" as a task and it follows the identical guarded steps.
