# Nix app flakes for the Claude Code profiles

Date: 2026-09-29

## Goal

`nix run github:M4jor-Tom/claude-power-dev.app` and
`nix run github:M4jor-Tom/claude-game-dev.app` behave the way
`nix run github:M4jor-Tom/pi-power-dev.app` and
`nix run github:M4jor-Tom/pi-game-dev.app` already do: clone the matching
profile, point the agent at it, and supply every CLI that profile's skills
shell out to.

The pi repos are the reference implementation — they were themselves ported
*from* these Claude profiles. This is the return trip: the profiles keep their
content, they gain the packaging.

## Repo topology

| Path | Remote | Role |
|---|---|---|
| `~/repos/claude-power-dev.app` | `git@github.com:M4jor-Tom/claude-power-dev.app` | new — the Nix app |
| `~/repos/claude-game-dev.app` | `git@github.com:M4jor-Tom/claude-game-dev.app` | new — the Nix app |
| `~/repos/claude-power-dev` | `git@…:M4jor-Tom/claude-power-dev` (SSH) | dev checkout: every edit, commit and push happens here |
| `~/repos/claude-game-dev` | `git@…:M4jor-Tom/claude-game-dev` (SSH) | dev checkout |
| `~/.claude-power-dev` | `https://github.com/M4jor-Tom/claude-power-dev.git` | runtime profile dir, app-managed |
| `~/.claude-game-dev` | `https://github.com/M4jor-Tom/claude-game-dev.git` | runtime profile dir, app-managed |

The SSH/HTTPS split is load-bearing. The wrapper's auto-pull fires only when
`origin` equals its own `configRepo`, which must be HTTPS so an anonymous
`nix run` can clone at all. Giving the runtime dirs HTTPS remotes makes the
auto-pull work there; keeping the dev checkouts on SSH keeps pushing
frictionless. The runtime dirs become read-only consumers — nothing is ever
committed in them again.

`$HOME/.<profileName>` is already the default `DIR` the wrapper computes, so
the existing profile directories need no move.

## 1. The `.app` repos

Files: `flake.nix`, `package.nix`, `README.md`, `.gitignore` (`result`,
`result-*`), `flake.lock`. Two inputs, `nixpkgs-unstable` and
`nix-systems/default`. Same overlay / `packages` / `apps` / `devShells` shape
as the pi flakes. `package.nix` is byte-identical between the two repos:
`profileName` / `configRepo` / `dirEnvVar` default to the power-dev values and
game-dev's `flake.nix` overrides all three — exactly pi's arrangement.

### One deliberate divergence from pi

The flake instantiates nixpkgs with `config.allowUnfree = true`:

```nix
pkgs = import nixpkgs {
  inherit system;
  config.allowUnfree = true;
  overlays = [ overlay ];
};
```

nixpkgs `claude-code` carries `license = lib.licenses.unfree`. Verified
empirically: without this line, evaluation of the package fails with the
`allowUnfree` error, so `nix run github:…` would hard-fail for every user
including the author; with it, evaluation resolves to `claude-code-2.1.283`.
pi never needed it because `pi-coding-agent` is free-licensed. Because the
flake builds its own `pkgs`, this does not depend on the user's nixpkgs
config.

`claude-code`'s `meta.platforms` omits `x86_64-darwin`, which `nix-systems/default`
enumerates. Nix's laziness means only the invoked system is evaluated, so
`nix run` is unaffected; `nix flake show --all-systems` would fail on that
one system. Accepted.

### Wrapper

pi's wrapper text, with three changes:

1. `export CLAUDE_CONFIG_DIR="$DIR"` and `exec claude "$@"`.
2. `git clone --recursive`. claude-game-dev's `skills/` is 69 symlinks into
   `vendor/` submodules; a non-recursive clone yields 69 dangling links.
   Verified: a fresh `--recursive` clone passes `scripts/check.sh` with
   "OK: 70 skills resolve".
3. `git submodule update --init --recursive --quiet` after a successful pull,
   so `vendor/` follows the gitlink.

Unchanged from pi: `$HOME/.<profileName>` default, `$CLAUDE_POWER_DEV_DIR` /
`$CLAUDE_GAME_DEV_DIR` override, clone-if-absent, `pull --ff-only` gated on
*both* a clean tree and `origin == configRepo`, the `meta` block.

### runtimeInputs

pi's closure minus `pi-coding-agent`, plus six. The additions come from a full
sweep of both profiles' skills, plugin hooks and MCP servers:

| Add | Why |
|---|---|
| `claude-code` | the agent |
| `pnpm` | understand-anything's `understand-dashboard` / `understand-figma` build a pnpm workspace (`--filter`, frozen lockfile); `npm` is not a substitute |
| `sqlite` | claude-mem `timeline-report` queries `claude-mem.db` with `sqlite3` |
| `curl` | claude-mem skills call the local worker over HTTP |
| `chromium` | playwright MCP, claude-mem `wowerpoint`, ui-ux-pro-max PNG export |
| `imagemagick` | ui-ux-pro-max palette extraction (`magick`) |

Final list: `claude-code git gh glab nodejs bun pnpm ripgrep fd jq yq-go uv
python3 sqlite curl chromium imagemagick rtk graphify markitdown pandoc
poppler-utils yt-dlp`.

`glab` and `yq-go` stay although no skill invokes them: `CLAUDE.md` mandates
both as the preferred tool, so the closure honours the instruction. Both apps
ship the identical closure, as pi's two do — one `package.nix`, no per-profile
divergence, even though the doc-conversion group is power-dev-only.

nixpkgs `claude-code` already sets `DISABLE_AUTOUPDATER=1`,
`DISABLE_INSTALLATION_CHECKS=1`, `USE_BUILTIN_RIPGREP=0`, defaults
`FORCE_AUTOUPDATE_PLUGINS=1`, and puts `ripgrep`, `procps`, `bubblewrap` and
`socat` on claude's own PATH.

## 2. Profile parity fixes

### claude-power-dev

A bare clone today resolves 1 of its 9 enabled plugins, and its tree can never
be clean.

- `settings.json`: add `extraKnownMarketplaces` for `thedotmack`, `ponytail`,
  `ui-ux-pro-max-skill` and `understand-anything`, copied from claude-game-dev,
  so the 9 `enabledPlugins` resolve from a bare clone.
- Drop the five `plugins/marketplaces/*` submodules — `.gitmodules` plus the
  gitlinks. Claude Code refetches them from the declarations above.
  **Why:** `FORCE_AUTOUPDATE_PLUGINS=1` makes Claude Code update those
  checkouts in place, so the gitlinks are permanently dirty — two are dirty
  right now — which silently disables the wrapper's clean-tree auto-pull.
- `.gitignore`: ignore `plugins/` wholesale; add `*.bak*` (the existing
  `known_marketplaces.json.bak-1789077141` escapes `*.bak`), `daemon.log`,
  `.ponytail-*`.
- Untrack `.ponytail-active`. It is hook-written runtime state that is
  currently committed.
- `README.md`: replace the `/plugin marketplace add` × 5 plus
  `/plugin install` × 9 restore ritual with `git clone` and launch; add the
  `nix run github:M4jor-Tom/claude-power-dev.app` route and a layout table,
  mirroring pi-power-dev's README.

### claude-game-dev

- `.gitignore`: add `plugins/`, `daemon.log`, `.ponytail-active`,
  `.ponytail-statusline-nudged`, `*.bak*`.
- `README.md`: add the `nix run github:M4jor-Tom/claude-game-dev.app` route
  alongside the existing `.claude/` submodule usage.

### Local state carried over from the runtime dirs

The runtime dirs hold uncommitted edits Claude Code wrote. Each is triaged,
not blindly replayed:

| Change | Disposition |
|---|---|
| power-dev `settings.json`: `+model: opus[1m]`, `+modelSettings.claude-fable-5-1.effortLevel`, `+agentPushNotifEnabled` | carry over |
| game-dev `settings.json`: `+model: opus[1m]`, `+agentPushNotifEnabled` (the rest of the diff is Claude Code reformatting an `extraKnownMarketplaces` block that is already committed) | carry over the two additions only |
| power-dev dirty submodule gitlinks | moot — the submodules are being dropped |
| power-dev `plugins/*.bak-*` files | ignored by the new `*.bak*` rule |
| game-dev `README.md` local edit | **dropped.** It advertises a skill that is staying untracked, and it clobbered list item 3 (the `ontology/` sync rule) leaving a bare `.` that renders as a broken list. The committed text — "70 skills: 69 symlinks into vendor/ + game-from-ontology (ours)" — is correct without the new skill, confirmed by `check.sh`. |
| game-dev `skills/ontology-resume-router-slice/` | **stays untracked and local**, by explicit decision. It is a clone of the public `M4jor-Tom/ontology-resume-router-slice` repo; the owner will reconcile it by hand with `git pull --rebase`. Added to `~/.claude-game-dev/.git/info/exclude` — a local, unpublished ignore — so the runtime tree still reads clean and the wrapper's auto-pull is not silently disabled. |

### Runtime dir migration

Per runtime dir, after the dev-checkout work is pushed:

1. `git remote set-url origin https://github.com/M4jor-Tom/<repo>.git`
2. `git checkout -- settings.json` — those edits are upstream by now, so
   discarding them loses nothing. Same for game-dev's `README.md`, whose local
   edit is dropped by decision.
3. Nothing is staged or deleted: the `*.bak*`, `plugins/`, `.ponytail-*` and
   `daemon.log` noise becomes *ignored* by the incoming `.gitignore`.
4. game-dev only: append `skills/ontology-resume-router-slice/` to
   `.git/info/exclude`.
5. `git pull --ff-only`, then assert `git status --porcelain` is empty — that
   emptiness is exactly the wrapper's auto-pull precondition.

Both runtime dirs are currently level with `origin` (0 ahead, 0 behind), so once
the dev-checkout work is pushed they are purely behind and a fast-forward is
always available.

Dropping power-dev's marketplace submodules removes only the gitlinks. Git does
not delete a submodule's working tree when a checkout removes its gitlink, and
`plugins/` is ignored by then, so the `plugins/marketplaces/*` directories stay
in place and the live session's plugins keep loading. The stale `submodule.*`
sections in `.git/config` and the `.git/modules/` payload are harmless and are
left alone — `git submodule deinit` would delete those working trees and is
explicitly *not* run. If a git version does prune the directories anyway, the
recovery is Claude Code refetching them from `extraKnownMarketplaces`, which is
the point of that change.

### Branching

`CLAUDE.md` mandates Gitflow with `--no-ff` merges. None of these six repos has
a `develop` branch and all use `master`, not `main`; creating a `develop` in
each is scope the goal does not ask for. So the rule is honoured where it bites:

- Profile repos: work on `feature/nix-app-parity` cut from `master`, then
  `git merge --no-ff` into `master`. Never a fast-forward merge.
- `.app` repos: the initial commit *is* the repo, so it lands directly on
  `master` — the branch name every sibling repo uses, `pi-power-dev.app`
  included — because there is no parent commit to branch from.

## Out of scope — flagged, not fixed

- `RTK.md:26` claims a Claude Code hook rewrites every command through `rtk`.
  No such hook exists: neither profile's `settings.json` has a `hooks` key, and
  every hook in play comes from a plugin. Stale documentation, not an
  app-parity defect.
- The playwright MCP's NixOS-Chromium fix is an uncommitted edit *inside* the
  `claude-plugins-official` submodule pointing at
  `/home/theta/.local/bin/playwright-chromium`. It survives neither a fresh
  clone nor another machine. Shipping `chromium` puts a working browser on
  PATH; a profile-owned MCP override that passes `--executable-path` is a
  separate change. Playwright exposes no environment variable for a per-browser
  executable path, so the wrapper cannot do it.
- claude-mem's hooks prepend
  `~/.nvm/…:~/.local/bin:/usr/local/bin:/opt/homebrew/bin` to PATH, so a stray
  `~/.local/bin/node` outranks the Nix one. Upstream-owned; a wrapper cannot
  fix it. README note only.
- Structural parity extras for claude-power-dev — `scripts/check.sh`, GitHub
  Actions CI, Dependabot, `docs/adr` — declined in favour of the narrower
  scope. claude-game-dev already has all three.
- `ontology-resume-router-slice`'s `SKILL.md` frontmatter says
  `name: onthology-resume-router-slice` while its directory is
  `ontology-resume-router-slice`. Different repo, untouched here.

## Verification

Before any push:

- `nix build .#` in both `.app` repos. Not `nix flake check` — it evaluates
  every system in `nix-systems/default`, including the `x86_64-darwin` that
  `claude-code` does not support.
- Run each wrapper against a scratch `CLAUDE_POWER_DEV_DIR` /
  `CLAUDE_GAME_DEV_DIR` under the session scratchpad, never the live profiles:
  prove it clones with submodules, exports `CLAUDE_CONFIG_DIR`, and that
  `claude --version` plus a `claude -p` round-trip loads the profile's plugins.
- Second run against the same scratch dir: proves the `--ff-only` pull path and
  both guards (dirty tree, foreign origin).
- `sh scripts/check.sh` in the game-dev dev checkout.

After push:

- `nix run github:M4jor-Tom/claude-power-dev.app -- --version` and the game-dev
  equivalent, from a clean scratch `HOME`.
- Both runtime dirs: clean tree, HTTPS origin, `git pull --ff-only` succeeds.

Then `/simplify` and `/ponytail:ponytail-review`, per `CLAUDE.md`.

## Risks

- **Un-pinned marketplaces.** Dropping power-dev's five submodules means Claude
  Code tracks those marketplaces' tips; a bad upstream commit reaches the
  profile immediately with no pinned SHA to fall back to. This is the trade
  that buys a clean tree, and therefore a working auto-pull. The old SHAs stay
  recoverable in git history.
- **First run needs a login.** `.credentials.json` is gitignored, so a fresh
  clone authenticates from scratch. Same as pi.
- **Runtime dirs stop being push-capable** once `origin` is HTTPS without a
  credential helper. Intentional: the dev checkouts under `~/repos` are where
  work happens.
