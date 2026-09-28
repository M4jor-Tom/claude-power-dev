# Claude Code profile app flakes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `nix run github:M4jor-Tom/claude-power-dev.app` and `nix run github:M4jor-Tom/claude-game-dev.app` launch Claude Code against their profile with every CLI its skills need, the way the pi apps already do.

**Architecture:** Two new single-package flakes wrapping `nixpkgs#claude-code` in a `writeShellApplication` that clones the profile repo over HTTPS, fast-forwards it when clean, exports `CLAUDE_CONFIG_DIR` and `exec`s `claude`. The two profile repos get the minimum changes a bare clone needs to be usable, and the live runtime dirs are re-pointed at HTTPS so the wrapper's auto-pull works there.

**Tech Stack:** Nix flakes (`writeShellApplication`, `nix-systems/default`), POSIX shell, git submodules, `jq`, Claude Code 2.1.283 from nixpkgs-unstable.

**Spec:** `docs/superpowers/specs/2026-09-29-claude-app-flakes-design.md` (this repo)

## Global Constraints

- `configRepo` is always the **HTTPS** URL `https://github.com/M4jor-Tom/<profile>.git`. Anonymous `nix run` cannot clone over SSH.
- Dev checkouts (`~/repos/claude-*-dev`, `~/repos/claude-*-dev.app`) keep **SSH** remotes. Runtime dirs (`~/.claude-*-dev`) get **HTTPS** remotes.
- Every profile-repo change lands on `feature/nix-app-parity`, merged with `git merge --no-ff`. Never a fast-forward merge. The `.app` repos' initial commit lands directly on `master`.
- Conventional Commits: `<type>[(scope)]: <description>`. Every commit body ends with `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.
- The flake MUST pass `config.allowUnfree = true` to its own `import nixpkgs`. `claude-code` is unfree; without it evaluation fails for every user.
- Verify with `nix build .#`, never `nix flake check` — the latter evaluates `x86_64-darwin`, which `claude-code` does not support.
- Never touch `~/.claude-power-dev` or `~/.claude-game-dev` before Task 5. `~/.claude-power-dev` is the live config dir of the executing session.
- `~/.claude-game-dev/skills/ontology-resume-router-slice/` stays untracked and is never ported into the dev checkout.
- Scratch dirs go under `/tmp/claude-1000/-home-theta/0d0dee84-bad0-4b0b-a181-381f2c166556/scratchpad/`, referred to below as `$SCRATCH`.

---

### Task 1: claude-power-dev profile — declarative plugins, clean tree

**Files:**
- Modify: `~/repos/claude-power-dev/settings.json`
- Modify: `~/repos/claude-power-dev/.gitignore`
- Delete: `~/repos/claude-power-dev/.gitmodules`
- Remove from index (keep no working tree, they are submodule gitlinks): `plugins/marketplaces/{claude-plugins-official,ponytail,thedotmack,ui-ux-pro-max-skill,understand-anything}`
- Remove from index (keep nothing): `.ponytail-active`
- Modify: `~/repos/claude-power-dev/README.md`
- Branch: `feature/nix-app-parity` (already exists, holds the spec commit)

**Interfaces:**
- Consumes: nothing.
- Produces: a `master` on `github.com/M4jor-Tom/claude-power-dev` whose bare clone has a clean `git status`, no submodules, and `settings.json` declaring 4 `extraKnownMarketplaces` + 9 `enabledPlugins`. Tasks 3 and 6 clone it.

- [ ] **Step 1: Write the failing check**

Create `$SCRATCH/check-power-profile.sh`:

```bash
#!/usr/bin/env bash
# Asserts what a bare clone of claude-power-dev must satisfy for the app to work.
set -euo pipefail
C="$1"   # path to a fresh clone

fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -z "$(git -C "$C" status --porcelain)" ] || note "clone is dirty: $(git -C "$C" status --porcelain | head -3)"
[ ! -e "$C/.gitmodules" ] || note ".gitmodules still present"
[ -z "$(git -C "$C" submodule status 2>/dev/null)" ] || note "submodules still registered"
if git -C "$C" ls-files --error-unmatch .ponytail-active >/dev/null 2>&1; then
  note ".ponytail-active is still tracked"
fi

jq -e '(.extraKnownMarketplaces // {}) | keys | sort == ["ponytail","thedotmack","ui-ux-pro-max-skill","understand-anything"]' \
  "$C/settings.json" >/dev/null 2>&1 || note "extraKnownMarketplaces is not the expected 4 entries"
jq -e '(.enabledPlugins // {}) | keys | length == 9' "$C/settings.json" >/dev/null 2>&1 || note "enabledPlugins is not 9 entries"
jq -e '.model == "opus[1m]"' "$C/settings.json" >/dev/null || note "model not carried over"
jq -e '.agentPushNotifEnabled == true' "$C/settings.json" >/dev/null || note "agentPushNotifEnabled not carried over"
jq -e '.modelSettings["claude-fable-5-1"].effortLevel == "xhigh"' "$C/settings.json" >/dev/null || note "modelSettings not carried over"

# Every marketplace named by an enabledPlugins suffix must be declarable:
# either the built-in official one, or declared in extraKnownMarketplaces.
for mp in $(jq -r '.enabledPlugins | keys[] | split("@")[1]' "$C/settings.json" | sort -u); do
  [ "$mp" = "claude-plugins-official" ] && continue
  jq -e --arg m "$mp" '(.extraKnownMarketplaces // {}) | has($m)' "$C/settings.json" >/dev/null 2>&1 \
    || note "enabled plugin references undeclared marketplace: $mp"
done

# Runtime noise must be ignored, not merely absent.
for p in plugins/known_marketplaces.json plugins/x.bak-123 daemon.log .ponytail-active .credentials.json; do
  git -C "$C" check-ignore -q "$p" || note "not ignored: $p"
done

# ...and the ignore rules must be anchored, so they do not also swallow real
# content nested under a same-named directory.
for p in docs/superpowers/plans/x.md skills/foo/cache/y.md docs/tasks/z.md; do
  if git -C "$C" check-ignore -q "$p"; then note "over-broad ignore swallows: $p"; fi
done
[ -f "$C/docs/superpowers/plans/2026-09-29-claude-app-flakes.md" ] || note "the plan is not in the clone"

if [ "$fail" -eq 0 ]; then echo "OK: power-dev profile clone is app-ready"; fi
exit "$fail"
```

- [ ] **Step 2: Run it against the current master to watch it fail**

```bash
chmod +x $SCRATCH/check-power-profile.sh
rm -rf $SCRATCH/probe-power-before
git clone --quiet https://github.com/M4jor-Tom/claude-power-dev.git $SCRATCH/probe-power-before
$SCRATCH/check-power-profile.sh $SCRATCH/probe-power-before
```

Expected: FAIL, listing at minimum a missing `extraKnownMarketplaces`, present `.gitmodules`, registered submodules, tracked `.ponytail-active`, and `plugins/known_marketplaces.json`/`daemon.log` not ignored.

- [ ] **Step 3: Add the marketplace declarations and carry over the live settings edits**

In `~/repos/claude-power-dev/settings.json`, add `"model": "opus[1m]"` after the `permissions` block, and add these three keys (`modelSettings` after `effortLevel`, the others at the end of the object):

```json
  "modelSettings": {
    "claude-fable-5-1": {
      "effortLevel": "xhigh"
    }
  },
  "agentPushNotifEnabled": true,
  "extraKnownMarketplaces": {
    "thedotmack": {
      "source": {
        "source": "github",
        "repo": "thedotmack/claude-mem"
      }
    },
    "ponytail": {
      "source": {
        "source": "github",
        "repo": "DietrichGebert/ponytail"
      }
    },
    "ui-ux-pro-max-skill": {
      "source": {
        "source": "github",
        "repo": "nextlevelbuilder/ui-ux-pro-max-skill"
      }
    },
    "understand-anything": {
      "source": {
        "source": "github",
        "repo": "Egonex-AI/Understand-Anything"
      }
    }
  }
```

Then confirm it is still valid JSON:

```bash
jq -e . ~/repos/claude-power-dev/settings.json >/dev/null && echo "valid JSON"
```

- [ ] **Step 4: Drop the five marketplace submodules**

```bash
cd ~/repos/claude-power-dev
git rm -q --cached plugins/marketplaces/claude-plugins-official
git rm -q --cached plugins/marketplaces/ponytail
git rm -q --cached plugins/marketplaces/thedotmack
git rm -q --cached plugins/marketplaces/ui-ux-pro-max-skill
git rm -q --cached plugins/marketplaces/understand-anything
git rm -q .gitmodules
rm -rf plugins/marketplaces
git rm -q --cached .ponytail-active
```

`git rm --cached` on a gitlink removes the pointer only. `rm -rf plugins/marketplaces` then clears this dev checkout's copies — safe here, because the dev checkout is not a live config dir. Task 5 deliberately does NOT do this in the runtime dir.

- [ ] **Step 5: Verify `.gitignore` (already rewritten as a prerequisite)**

This step landed early, on this branch, because the unanchored `plans/` rule was
hiding `docs/superpowers/plans/` — so the plan document itself could not be
versioned until it was fixed. Every root-level state rule is now anchored with a
leading `/`; `plugins/` is ignored wholesale; `daemon.log` and `/.ponytail-*` are
covered; `*.bak` became `*.bak*` to catch `known_marketplaces.json.bak-1789077141`;
`.credentials.json` and `*.bak*` stay deliberately unanchored so they are ignored
at any depth.

Confirm rather than re-edit:

```bash
cd ~/repos/claude-power-dev
# --no-index, so the result does not depend on whether Step 4 has run yet:
# check-ignore silently skips paths that are still tracked.
git check-ignore -v --no-index plugins/known_marketplaces.json plugins/x.bak-123 \
  daemon.log .ponytail-active .credentials.json
# each of those must print a matching rule; these must print NOTHING:
git check-ignore -v --no-index docs/superpowers/plans/x.md skills/foo/cache/y.md docs/tasks/z.md
echo "exit=$? (1 = correctly not ignored)"
```

- [ ] **Step 6: Rewrite README.md**

```markdown
# claude-power-dev

A Claude Code config directory: general-purpose coding profile. `pi-power-dev`
is its pi port.

## Use it

Without Nix — this repo *is* the config dir:

```bash
git clone https://github.com/M4jor-Tom/claude-power-dev.git ~/.claude-power-dev
CLAUDE_CONFIG_DIR=~/.claude-power-dev claude
```

With Nix, which also supplies every CLI the skills shell out to:

```bash
nix run github:M4jor-Tom/claude-power-dev.app
```

`CLAUDE_CONFIG_DIR` makes this repo what `~/.claude` would normally be, so the
`settings.json` here is the user-level settings file.

## Layout

| Path | Role |
|---|---|
| `CLAUDE.md` | Global memory, loaded at every session start |
| `RTK.md`, `conventional-commits.md` | Imported by `CLAUDE.md` |
| `rules/` | Additional imported rules |
| `settings.json` | Settings, plugin marketplaces, enabled plugins |
| `skills/` | Locally authored skills |
| `docs/superpowers/` | Specs and plans |

## Plugins

`settings.json` declares every marketplace in `extraKnownMarketplaces` and
every plugin in `enabledPlugins`, so a bare clone needs no manual
registration: Claude Code clones a declared-but-missing marketplace and
downloads its enabled plugins in the background *after* the session starts.
The first session on a new machine therefore needs a login before the plugins
appear. To force the sync instead of waiting:

```bash
claude plugin marketplace update
```

`plugins/` is untracked — it is a cache, and its index files hardcode absolute
install paths.

## Runtime state

Claude Code writes sessions, projects, caches, credentials and its plugin cache
into the config dir, which is this repo. All of it is ignored; see
`.gitignore`. Keeping that list complete matters: one untracked file makes
`claude-power-dev.app` skip its auto-pull, silently.
```

- [ ] **Step 7: Commit**

```bash
cd ~/repos/claude-power-dev
git add -A
git commit -F - <<'MSG'
feat: declare plugin marketplaces in settings, drop marketplace submodules

A bare clone resolved only 1 of 9 enabled plugins, because
known_marketplaces.json is untracked (it hardcodes absolute paths) and nothing
declared the 4 non-official marketplaces. extraKnownMarketplaces does that
declaratively: Claude Code clones a declared-but-missing marketplace and
downloads its enabled plugins after session start.

The marketplace submodules go with it. FORCE_AUTOUPDATE_PLUGINS makes Claude
Code update those checkouts in place, so their gitlinks were permanently dirty
— which silently disabled claude-power-dev.app's clean-tree auto-pull. plugins/
is now ignored wholesale.

Also untracks .ponytail-active (hook-written state), widens *.bak to *.bak*,
and ignores daemon.log.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
```

- [ ] **Step 8: Merge to master with --no-ff and push**

```bash
cd ~/repos/claude-power-dev
git checkout master
git merge --no-ff feature/nix-app-parity -m "Merge branch 'feature/nix-app-parity'"
git push origin master
```

- [ ] **Step 9: Run the check against a fresh clone of the pushed master**

```bash
rm -rf $SCRATCH/probe-power
git clone --quiet https://github.com/M4jor-Tom/claude-power-dev.git $SCRATCH/probe-power
$SCRATCH/check-power-profile.sh $SCRATCH/probe-power
```

Expected: `OK: power-dev profile clone is app-ready`

---

### Task 2: claude-game-dev profile — clean tree, nix route documented

**Files:**
- Modify: `~/repos/claude-game-dev/.gitignore`
- Modify: `~/repos/claude-game-dev/settings.json`
- Modify: `~/repos/claude-game-dev/README.md`
- Branch: `feature/nix-app-parity` (create from `master`)

**Interfaces:**
- Consumes: nothing.
- Produces: a `master` on `github.com/M4jor-Tom/claude-game-dev` whose `--recursive` clone has a clean `git status` and passes `scripts/check.sh`. Tasks 4 and 6 clone it.

- [ ] **Step 1: Write the failing check**

Create `$SCRATCH/check-game-profile.sh`:

```bash
#!/usr/bin/env bash
# Asserts what a bare --recursive clone of claude-game-dev must satisfy.
set -euo pipefail
C="$1"

fail=0
note() { echo "FAIL: $*"; fail=1; }

[ -z "$(git -C "$C" status --porcelain)" ] || note "clone is dirty: $(git -C "$C" status --porcelain | head -3)"
sh "$C/scripts/check.sh" >/dev/null || note "scripts/check.sh failed"

jq -e '(.extraKnownMarketplaces // {}) | keys | length == 4' "$C/settings.json" >/dev/null 2>&1 || note "extraKnownMarketplaces is not 4 entries"
jq -e '(.enabledPlugins // {}) | keys | length == 9' "$C/settings.json" >/dev/null 2>&1 || note "enabledPlugins is not 9 entries"
jq -e '.model == "opus[1m]"' "$C/settings.json" >/dev/null || note "model not carried over"
jq -e '.agentPushNotifEnabled == true' "$C/settings.json" >/dev/null || note "agentPushNotifEnabled not carried over"

for p in plugins/known_marketplaces.json plugins/x.bak-123 daemon.log .ponytail-active .ponytail-statusline-nudged .credentials.json; do
  git -C "$C" check-ignore -q "$p" || note "not ignored: $p"
done

# ...and the ignore rules must be anchored, so real content nested under a
# same-named directory survives.
for p in docs/adr/0001-ontology-first-game-development.md docs/superpowers/plans/x.md skills/foo/cache/y.md; do
  if git -C "$C" check-ignore -q "$p"; then note "over-broad ignore swallows: $p"; fi
done
[ -f "$C/docs/adr/0001-ontology-first-game-development.md" ] || note "docs/adr went missing"

# The README must not advertise the skill that is staying untracked.
if grep -q 'onthology-resume-router-slice' "$C/README.md"; then
  note "README advertises the untracked skill"
fi
grep -q 'nix run github:M4jor-Tom/claude-game-dev.app' "$C/README.md" || note "README does not document the nix route"

if [ "$fail" -eq 0 ]; then echo "OK: game-dev profile clone is app-ready"; fi
exit "$fail"
```

- [ ] **Step 2: Run it against the current master to watch it fail**

```bash
chmod +x $SCRATCH/check-game-profile.sh
rm -rf $SCRATCH/probe-game-before
git clone --quiet --recursive https://github.com/M4jor-Tom/claude-game-dev.git $SCRATCH/probe-game-before
$SCRATCH/check-game-profile.sh $SCRATCH/probe-game-before
```

Expected: FAIL on the missing `model`/`agentPushNotifEnabled`, the un-ignored `daemon.log`/`.ponytail-*`/`*.bak-*` paths, and the missing nix route in the README.

- [ ] **Step 3: Branch, and extend `.gitignore`**

```bash
cd ~/repos/claude-game-dev && git checkout -b feature/nix-app-parity
```

Replace the file's entire contents with the anchored form — same treatment claude-power-dev received, because the unanchored rules hide real content at any depth (`plans/` would swallow a `docs/superpowers/plans/`, `tasks/` any nested `tasks/`):

```gitignore
# Claude Code runtime state. This repo is used both as a project's .claude/ and
# as a standalone CLAUDE_CONFIG_DIR, so Claude Code writes its session and cache
# files next to the tracked config.
#
# Every rule below is anchored with a leading "/": these are root-level state
# names, and unanchored they also swallow real content at any depth.
/settings.local.json
# Machine-local state. Normally ~/.claude.json, but it moves *inside* the
# config dir when CLAUDE_CONFIG_DIR points here. Holds oauthAccount, userID,
# machineID, mcpServers and the path history of every project opened.
/.claude.json
/.claude.json.backup
/mcp-needs-auth-cache.json
/history.jsonl
/.last-cleanup
/sessions/
/session-env/
/projects/
/cache/
/paste-cache/
/file-history/
/shell-snapshots/
/tasks/
/todos/
/plans/
/telemetry/
/statsig/
/jobs/
/daemon/
/daemon.log
/ide/
/backups/

# Plugin state: a cache whose index files hardcode absolute install paths.
# Marketplaces and plugins are declared in settings.json instead.
/plugins/

# Hook-written markers. Keeping this list complete matters: one untracked file
# makes claude-game-dev.app skip its auto-pull, silently.
/.ponytail-*

# Secrets and editor backups, deliberately unanchored — ignore these at any
# depth. *.bak* rather than *.bak: Claude Code leaves suffixed backups such as
# known_marketplaces.json.bak-1789077141.
.credentials.json
*.bak*
```

Note what must NOT be ignored: `vendor/` and `skills/` are tracked, and `docs/adr/` must stay visible.

- [ ] **Step 4: Carry over the two live settings additions**

In `~/repos/claude-game-dev/settings.json`, add `"model": "opus[1m]"` as the first key and `"agentPushNotifEnabled": true` as the last. Leave `extraKnownMarketplaces` and `enabledPlugins` exactly as committed — the rest of the live diff is only Claude Code reformatting. Then:

```bash
jq -e . ~/repos/claude-game-dev/settings.json >/dev/null && echo "valid JSON"
```

- [ ] **Step 5: Document the nix route in README.md**

Immediately after the existing fenced `git submodule add …` usage block and its parenthetical, insert:

```markdown
### Or as a standalone config dir

```bash
nix run github:M4jor-Tom/claude-game-dev.app
```

Clones this repo to `~/.claude-game-dev`, points `CLAUDE_CONFIG_DIR` at it, and
supplies every CLI the skills shell out to. Override the location with
`CLAUDE_GAME_DEV_DIR`. Without Nix:

```bash
git clone --recursive https://github.com/M4jor-Tom/claude-game-dev.git ~/.claude-game-dev
CLAUDE_CONFIG_DIR=~/.claude-game-dev claude
```

Used this way, Claude Code writes sessions, caches, credentials and its plugin
cache into the clone. All of it is ignored — see `.gitignore`. One untracked
file makes the app skip its auto-pull, silently.
```

Do **not** touch the `## Structure` skill count or the numbered "How it works" list: the local edit that changed them is being dropped, since `ontology-resume-router-slice` stays untracked and `scripts/check.sh` confirms 70 skills without it.

- [ ] **Step 6: Commit, merge --no-ff, push**

```bash
cd ~/repos/claude-game-dev
git add -A
git commit -F - <<'MSG'
chore: ignore runtime state, document the nix app route

Claude Code writes plugins/, daemon.log and the ponytail hook markers into the
config dir, which is this repo. Untracked, they make claude-game-dev.app skip
its clean-tree auto-pull without saying so, so ignore them; *.bak becomes
*.bak* to catch the suffixed backups Claude Code leaves.

Carries over the model and agentPushNotifEnabled settings, and documents using
the repo as a standalone CLAUDE_CONFIG_DIR via nix run.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
git checkout master
git merge --no-ff feature/nix-app-parity -m "Merge branch 'feature/nix-app-parity'"
git push origin master
```

- [ ] **Step 7: Run the check against a fresh clone of the pushed master**

```bash
rm -rf $SCRATCH/probe-game2
git clone --quiet --recursive https://github.com/M4jor-Tom/claude-game-dev.git $SCRATCH/probe-game2
$SCRATCH/check-game-profile.sh $SCRATCH/probe-game2
```

Expected: `OK: game-dev profile clone is app-ready`

---

### Task 3: claude-power-dev.app

**Files:**
- Create: `~/repos/claude-power-dev.app/flake.nix`
- Create: `~/repos/claude-power-dev.app/package.nix`
- Create: `~/repos/claude-power-dev.app/README.md`
- Create: `~/repos/claude-power-dev.app/.gitignore`
- Generated: `~/repos/claude-power-dev.app/flake.lock`

**Interfaces:**
- Consumes: the pushed `claude-power-dev` master from Task 1.
- Produces: `package.nix` with args `profileName` / `configRepo` / `dirEnvVar` (all with power-dev defaults) — Task 4 copies this file verbatim and overrides all three from its own `flake.nix`. Produces the binary `result/bin/claude-power-dev`.

- [ ] **Step 1: Write the failing check**

Create `$SCRATCH/check-app.sh` — used by Tasks 3 and 4 both:

```bash
#!/usr/bin/env bash
# Asserts a built profile wrapper behaves like the pi ones.
set -euo pipefail
APP="$1"          # repo dir, already `nix build`-ed
NAME="$2"         # claude-power-dev | claude-game-dev
ENVVAR="$3"       # CLAUDE_POWER_DEV_DIR | CLAUDE_GAME_DEV_DIR
REPO="https://github.com/M4jor-Tom/$NAME.git"
BIN="$APP/result/bin/$NAME"

fail=0
note() { echo "FAIL: $*"; fail=1; }
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT

[ -x "$BIN" ] || { echo "FAIL: no $BIN"; exit 1; }

# The wrapper must put its whole closure on PATH and export CLAUDE_CONFIG_DIR.
grep -q 'export PATH=' "$BIN" || note "wrapper does not set PATH"
grep -q 'export CLAUDE_CONFIG_DIR=' "$BIN" || note "wrapper does not export CLAUDE_CONFIG_DIR"
grep -q 'exec claude ' "$BIN" || note "wrapper does not exec claude"
grep -q 'git clone --recursive' "$BIN" || note "clone is not --recursive"

# The submodule update must be reachable only from the successful-pull branch
# of the if/else below, never unconditional and never past the else — the
# whole reason this wrapper diverges from the pi-*.app originals.
PULL_LINE="$(grep -n 'pull --ff-only' "$BIN" | head -1 | cut -d: -f1 || true)"
SUBMOD_LINE="$(grep -n 'submodule update --init --recursive' "$BIN" | head -1 | cut -d: -f1 || true)"
ELSE_LINE="$(grep -n '^[[:space:]]*else$' "$BIN" | head -1 | cut -d: -f1 || true)"
if [ -z "$PULL_LINE" ] || [ -z "$SUBMOD_LINE" ] || [ -z "$ELSE_LINE" ]; then
  note "could not locate pull/submodule-update/else lines to check gating"
elif [ "$SUBMOD_LINE" -le "$PULL_LINE" ] || [ "$SUBMOD_LINE" -ge "$ELSE_LINE" ]; then
  note "submodule update is not gated inside the successful-pull branch"
fi

# Resolve each expected binary inside the wrapper's own PATH, rather than the
# caller's. writeShellApplication emits one line, with $PATH INSIDE the quotes:
#   export PATH="/nix/store/...-a/bin:/nix/store/...-b/bin:$PATH"
WPATH="$(sed -n 's/^export PATH="\(.*\):\$PATH"$/\1/p' "$BIN" | head -1)"
# Guard the extraction itself: an empty WPATH would make every check below
# pass vacuously.
[ -n "$WPATH" ] || { echo "FAIL: could not extract the wrapper's PATH from $BIN"; exit 1; }
IFS=: read -r -a wdirs <<< "$WPATH"
for t in claude git gh glab node bun pnpm rg fd jq yq uv python3 sqlite3 curl chromium magick rtk graphify markitdown pandoc pdftotext yt-dlp; do
  found=0
  for d in "${wdirs[@]}"; do
    if [ -x "$d/$t" ]; then found=1; break; fi
  done
  [ "$found" -eq 1 ] || note "not on the wrapper's PATH: $t"
done

# Clone path: absent dir -> clone, with submodules, and CLAUDE_CONFIG_DIR set to it.
env "$ENVVAR=$D/fresh" "$BIN" --version >"$D/v1" 2>"$D/e1" || note "first run failed: $(head -2 "$D/e1")"
grep -qE '^[0-9]+\.[0-9]+\.[0-9]+ \(Claude Code\)' "$D/v1" || note "no version from first run: $(head -2 "$D/v1")"
[ -d "$D/fresh/.git" ] || note "profile was not cloned"
[ "$(git -C "$D/fresh" remote get-url origin)" = "$REPO" ] || note "cloned wrong origin"
[ -z "$(git -C "$D/fresh" status --porcelain)" ] || note "fresh clone is dirty"
if [ -f "$D/fresh/.gitmodules" ]; then
  # A leading '-' in submodule status means "not initialized".
  if git -C "$D/fresh" submodule status | grep -q '^-'; then
    note "submodules not initialized by --recursive"
  fi
fi

# Second run: clean tree + matching origin -> fast-forward, still clean, still works.
env "$ENVVAR=$D/fresh" "$BIN" --version >/dev/null 2>"$D/e2" || note "second run failed: $(head -2 "$D/e2")"
[ -z "$(git -C "$D/fresh" status --porcelain)" ] || note "tree dirtied by the pull path"

# Guard 1: a dirty tree must be left alone, never clobbered.
echo "local edit" >> "$D/fresh/README.md"
env "$ENVVAR=$D/fresh" "$BIN" --version >/dev/null 2>&1 || note "run failed on a dirty tree"
grep -q 'local edit' "$D/fresh/README.md" || note "dirty tree was clobbered"
git -C "$D/fresh" checkout -- README.md

# Guard 2: a foreign origin must get no pulls.
git -C "$D/fresh" remote set-url origin https://example.invalid/nope.git
env "$ENVVAR=$D/fresh" "$BIN" --version >/dev/null 2>"$D/e3" || note "run failed on a foreign origin"
if grep -qi 'example.invalid' "$D/e3"; then note "tried to pull from a foreign origin"; fi

if [ "$fail" -eq 0 ]; then echo "OK: $NAME wrapper behaves"; fi
exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x $SCRATCH/check-app.sh
$SCRATCH/check-app.sh ~/repos/claude-power-dev.app claude-power-dev CLAUDE_POWER_DEV_DIR
```

Expected: `FAIL: no ~/repos/claude-power-dev.app/result/bin/claude-power-dev`

- [ ] **Step 3: Create `package.nix`**

```nix
{ lib
, writeShellApplication
, claude-code
, git
, gh
, glab
, nodejs
, bun
, pnpm
, ripgrep
, fd
, jq
, yq-go
, uv
, python3
, sqlite
, curl
, chromium
, imagemagick
, rtk
, graphify
, markitdown
, pandoc
, poppler-utils
, yt-dlp
  # Which profile this wrapper runs. claude-game-dev.app reuses this file with
  # the game-dev values.
, profileName ? "claude-power-dev"
, configRepo ? "https://github.com/M4jor-Tom/claude-power-dev.git"
, dirEnvVar ? "CLAUDE_POWER_DEV_DIR"
}:

writeShellApplication {
  name = profileName;

  runtimeInputs = [
    claude-code
    git
    gh
    glab
    nodejs
    bun
    pnpm
    ripgrep
    fd
    jq
    yq-go
    uv
    python3
    sqlite
    curl
    chromium
    imagemagick
    rtk
    graphify
    markitdown
    pandoc
    poppler-utils
    yt-dlp
  ];

  # The config repo is a git working tree, never a store symlink: Claude Code
  # writes settings.local.json, sessions and the plugin cache next to the
  # tracked config, so that directory has to stay writable.
  text = ''
    DIR="''${${dirEnvVar}:-$HOME/.${profileName}}"

    if [ ! -e "$DIR" ]; then
      echo "${profileName}: cloning ${configRepo} -> $DIR" >&2
      # --recursive: claude-game-dev's skills/ are symlinks into vendor/
      # submodules, and a flat clone leaves 69 of them dangling.
      git clone --recursive "${configRepo}" "$DIR"
    elif [ -d "$DIR/.git" ] \
      && [ "$(git -C "$DIR" remote get-url origin 2>/dev/null)" = "${configRepo}" ] \
      && [ -z "$(git -C "$DIR" status --porcelain)" ]; then
      # Clean tree, and only a checkout of this profile's own repo. A dirty
      # tree keeps its local edits, always; an unrelated checkout is never
      # touched.
      if git -C "$DIR" pull --ff-only --quiet; then
        git -C "$DIR" submodule update --init --recursive --quiet \
          || echo "${profileName}: submodule update failed" >&2
      else
        echo "${profileName}: pull failed, using the local checkout" >&2
      fi
    fi

    export CLAUDE_CONFIG_DIR="$DIR"
    exec claude "$@"
  '';

  meta = {
    description = "Claude Code running the ${profileName} profile";
    homepage = "https://github.com/M4jor-Tom/${profileName}.app";
    mainProgram = profileName;
    platforms = lib.platforms.unix;
  };
}
```

- [ ] **Step 4: Create `flake.nix`**

```nix
{
  description = "Claude Code, pre-loaded with the claude-power-dev profile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self
    , nixpkgs
    , systems
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem = f: lib.foldl' lib.recursiveUpdate { } (map f (import systems));

      overlay = final: prev: {
        claude-power-dev = final.callPackage ./package.nix { };
      };
    in
    eachSystem
      (system:
      let
        # claude-code is unfree, so this flake allows it for its own nixpkgs.
        # Without this, `nix run github:...` fails at evaluation for everyone.
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages.${system} = {
          default = pkgs.claude-power-dev;
          claude-power-dev = pkgs.claude-power-dev;
        };

        apps.${system} = {
          default = {
            type = "app";
            program = "${pkgs.claude-power-dev}/bin/claude-power-dev";
            meta.description = "Claude Code running the claude-power-dev profile";
          };
          claude-power-dev = {
            type = "app";
            program = "${pkgs.claude-power-dev}/bin/claude-power-dev";
            meta.description = "Claude Code running the claude-power-dev profile";
          };
        };

        devShells.${system}.default = pkgs.mkShell {
          buildInputs = with pkgs; [ nixpkgs-fmt ];
        };
      }) // {
      overlays.default = overlay;
    };
}
```

- [ ] **Step 5: Create `.gitignore`**

```gitignore
result
result-*
```

- [ ] **Step 6: Create `README.md`**

```markdown
# claude-power-dev.app

Runs [Claude Code](https://claude.com/product/claude-code) against the
[`claude-power-dev`](https://github.com/M4jor-Tom/claude-power-dev) profile, and
supplies every CLI that profile's skills shell out to.

```bash
nix run github:M4jor-Tom/claude-power-dev.app
```

On first run it clones the profile to `~/.claude-power-dev`. On later runs it
fast-forwards that clone, but only when the tree is clean — local edits are
never clobbered — and only when `origin` still points at this profile's own
repo, so pointing `CLAUDE_POWER_DEV_DIR` at a fork or an unrelated checkout
gets no pulls. Override the location with `CLAUDE_POWER_DEV_DIR`.

This app is a convenience, not a requirement. The profile works on its own:

```bash
CLAUDE_CONFIG_DIR=~/.claude-power-dev claude
```

## What it ships

`claude-code git gh glab nodejs bun pnpm ripgrep fd jq yq-go uv python3 sqlite
curl chromium imagemagick rtk graphify markitdown pandoc poppler-utils yt-dlp`

`nixpkgs#claude-code` already sets `DISABLE_AUTOUPDATER=1`,
`DISABLE_INSTALLATION_CHECKS=1` and `USE_BUILTIN_RIPGREP=0`, defaults
`FORCE_AUTOUPDATE_PLUGINS=1`, and puts `ripgrep`, `procps`, `bubblewrap` and
`socat` on Claude Code's own PATH. The flake allows unfree packages for its own
nixpkgs, because `claude-code` is unfree — without that, `nix run` would fail
before building anything.

## Plugins on a fresh clone

The profile declares its marketplaces in `settings.json`
(`extraKnownMarketplaces`) and its plugins in `enabledPlugins`. Claude Code
clones a declared-but-missing marketplace and downloads its enabled plugins in
the background *after* the session starts, so on a brand-new machine log in
first and the plugins follow. `claude plugin marketplace update` forces it.

## Deliberately absent

`playwright-driver` is not shipped: the `playwright-cli` skill installs
`@playwright/cli` through npm and manages its own browsers. `chromium` *is*
shipped, because the playwright MCP server, claude-mem's `wowerpoint` and
ui-ux-pro-max's image export all need a browser, and Playwright's own download
segfaults on NixOS.

One thing this wrapper cannot fix: `claude-mem`'s hooks prepend `~/.nvm/…`,
`~/.local/bin`, `/usr/local/bin` and `/opt/homebrew/bin` to PATH, so a stray
`node` or `bun` in one of those outranks the Nix one.
```

- [ ] **Step 7: Build, then run the check**

```bash
cd ~/repos/claude-power-dev.app
nix flake lock
nix build .#
$SCRATCH/check-app.sh ~/repos/claude-power-dev.app claude-power-dev CLAUDE_POWER_DEV_DIR
```

Expected: `OK: claude-power-dev wrapper behaves`

- [ ] **Step 8: Commit on master and push**

```bash
cd ~/repos/claude-power-dev.app
git init -q -b master 2>/dev/null || true
git remote get-url origin >/dev/null 2>&1 || git remote add origin git@github.com:M4jor-Tom/claude-power-dev.app.git
git add flake.nix flake.lock package.nix README.md .gitignore
git commit -F - <<'MSG'
feat: nix app running Claude Code against the claude-power-dev profile

Mirrors pi-power-dev.app: clones the profile over HTTPS on first run,
fast-forwards it when the tree is clean and origin matches, exports
CLAUDE_CONFIG_DIR and execs claude with the CLI closure the profile's skills
shell out to.

Two divergences from the pi wrapper. The flake sets config.allowUnfree for its
own nixpkgs, because claude-code is unfree and nix run would otherwise fail at
evaluation. The clone is --recursive, and a successful pull is followed by a
submodule update, so a profile whose skills are symlinks into submodules
resolves.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
git push -u origin master
```

---

### Task 4: claude-game-dev.app

**Files:**
- Create: `~/repos/claude-game-dev.app/package.nix` (byte-identical copy of Task 3's)
- Create: `~/repos/claude-game-dev.app/flake.nix`
- Create: `~/repos/claude-game-dev.app/README.md`
- Create: `~/repos/claude-game-dev.app/.gitignore`
- Generated: `~/repos/claude-game-dev.app/flake.lock`

**Interfaces:**
- Consumes: Task 3's `package.nix` verbatim, overriding `profileName = "claude-game-dev"`, `configRepo = "https://github.com/M4jor-Tom/claude-game-dev.git"`, `dirEnvVar = "CLAUDE_GAME_DEV_DIR"`. Consumes the pushed `claude-game-dev` master from Task 2.
- Produces: `result/bin/claude-game-dev`.

- [ ] **Step 1: Run the check to verify it fails**

```bash
$SCRATCH/check-app.sh ~/repos/claude-game-dev.app claude-game-dev CLAUDE_GAME_DEV_DIR
```

Expected: `FAIL: no ~/repos/claude-game-dev.app/result/bin/claude-game-dev`

- [ ] **Step 2: Copy `package.nix` and `.gitignore` unchanged**

```bash
cp ~/repos/claude-power-dev.app/package.nix ~/repos/claude-game-dev.app/package.nix
cp ~/repos/claude-power-dev.app/.gitignore ~/repos/claude-game-dev.app/.gitignore
diff ~/repos/claude-power-dev.app/package.nix ~/repos/claude-game-dev.app/package.nix && echo "identical, as in pi"
```

Keeping it byte-identical is deliberate: the pi pair does the same, and the
defaults stay power-dev's.

- [ ] **Step 3: Create `flake.nix` with the three overrides**

```nix
{
  description = "Claude Code, pre-loaded with the claude-game-dev profile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    { self
    , nixpkgs
    , systems
    }:
    let
      inherit (nixpkgs) lib;
      eachSystem = f: lib.foldl' lib.recursiveUpdate { } (map f (import systems));

      overlay = final: prev: {
        claude-game-dev = final.callPackage ./package.nix {
          profileName = "claude-game-dev";
          configRepo = "https://github.com/M4jor-Tom/claude-game-dev.git";
          dirEnvVar = "CLAUDE_GAME_DEV_DIR";
        };
      };
    in
    eachSystem
      (system:
      let
        # claude-code is unfree, so this flake allows it for its own nixpkgs.
        # Without this, `nix run github:...` fails at evaluation for everyone.
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlay ];
        };
      in
      {
        packages.${system} = {
          default = pkgs.claude-game-dev;
          claude-game-dev = pkgs.claude-game-dev;
        };

        apps.${system} = {
          default = {
            type = "app";
            program = "${pkgs.claude-game-dev}/bin/claude-game-dev";
            meta.description = "Claude Code running the claude-game-dev profile";
          };
          claude-game-dev = {
            type = "app";
            program = "${pkgs.claude-game-dev}/bin/claude-game-dev";
            meta.description = "Claude Code running the claude-game-dev profile";
          };
        };

        devShells.${system}.default = pkgs.mkShell {
          buildInputs = with pkgs; [ nixpkgs-fmt ];
        };
      }) // {
      overlays.default = overlay;
    };
}
```

- [ ] **Step 4: Create `README.md`**

```markdown
# claude-game-dev.app

Runs [Claude Code](https://claude.com/product/claude-code) against the
[`claude-game-dev`](https://github.com/M4jor-Tom/claude-game-dev) profile — the
ontology-first game development config — and supplies every CLI that profile's
skills shell out to.

```bash
nix run github:M4jor-Tom/claude-game-dev.app
```

On first run it clones the profile to `~/.claude-game-dev`, submodules included:
that profile's `skills/` are 69 symlinks into `vendor/`, so the clone has to be
recursive. On later runs it fast-forwards the clone and updates the submodules,
but only when the tree is clean — local edits are never clobbered — and only
when `origin` still points at this profile's own repo, so pointing
`CLAUDE_GAME_DEV_DIR` at a fork or an unrelated checkout gets no pulls.

This app is a convenience, not a requirement. The profile works on its own:

```bash
CLAUDE_CONFIG_DIR=~/.claude-game-dev claude
```

It is also usable as a project's `.claude/` submodule — see the profile's own
README.

## What it ships

`claude-code git gh glab nodejs bun pnpm ripgrep fd jq yq-go uv python3 sqlite
curl chromium imagemagick rtk graphify markitdown pandoc poppler-utils yt-dlp`

The same closure as `claude-power-dev.app`, from the same `package.nix`.
`nixpkgs#claude-code` already sets `DISABLE_AUTOUPDATER=1`,
`DISABLE_INSTALLATION_CHECKS=1` and `USE_BUILTIN_RIPGREP=0`, defaults
`FORCE_AUTOUPDATE_PLUGINS=1`, and puts `ripgrep`, `procps`, `bubblewrap` and
`socat` on Claude Code's own PATH. The flake allows unfree packages for its own
nixpkgs, because `claude-code` is unfree — without that, `nix run` would fail
before building anything.

## Not shipped

The engine toolchains this profile's skills drive — `godot`, `dotnet`, `love`,
`butler`, `steamcmd` — are per-project, not per-profile. Put them in the game
repo's own devShell.

## Plugins on a fresh clone

The profile declares its marketplaces in `settings.json`
(`extraKnownMarketplaces`) and its plugins in `enabledPlugins`. Claude Code
clones a declared-but-missing marketplace and downloads its enabled plugins in
the background *after* the session starts, so on a brand-new machine log in
first and the plugins follow. `claude plugin marketplace update` forces it.
```

- [ ] **Step 5: Build, then run the check**

```bash
cd ~/repos/claude-game-dev.app
nix flake lock
nix build .#
$SCRATCH/check-app.sh ~/repos/claude-game-dev.app claude-game-dev CLAUDE_GAME_DEV_DIR
```

Expected: `OK: claude-game-dev wrapper behaves` — including the submodule
assertion, which is only exercised here.

- [ ] **Step 6: Commit on master and push**

```bash
cd ~/repos/claude-game-dev.app
git init -q -b master 2>/dev/null || true
git remote get-url origin >/dev/null 2>&1 || git remote add origin git@github.com:M4jor-Tom/claude-game-dev.app.git
git add flake.nix flake.lock package.nix README.md .gitignore
git commit -F - <<'MSG'
feat: nix app running Claude Code against the claude-game-dev profile

Same wrapper as claude-power-dev.app, from a byte-identical package.nix with
profileName, configRepo and dirEnvVar overridden — the arrangement the pi pair
uses. The recursive clone matters most here: this profile's skills/ are 69
symlinks into vendor/ submodules.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
MSG
git push -u origin master
```

---

### Task 5: Re-point the live runtime dirs at HTTPS

**Files:**
- Modify: `~/.claude-power-dev/.git/config` (via `git remote set-url`)
- Modify: `~/.claude-game-dev/.git/config`, `~/.claude-game-dev/.git/info/exclude`
- Discard: the local `settings.json` edits in both, and `README.md` in game-dev

**Interfaces:**
- Consumes: the pushed masters from Tasks 1 and 2.
- Produces: two runtime dirs with HTTPS origins and empty `git status --porcelain` — the wrapper's auto-pull precondition, which Task 6 depends on.

`~/.claude-power-dev` is the live config dir of the executing session. Nothing here deletes a plugin checkout.

- [ ] **Step 1: Write the failing check**

Create `$SCRATCH/check-runtime.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
D="$1"; NAME="$2"
fail=0
note() { echo "FAIL: $*"; fail=1; }

[ "$(git -C "$D" remote get-url origin)" = "https://github.com/M4jor-Tom/$NAME.git" ] || note "origin is not the HTTPS URL: $(git -C "$D" remote get-url origin)"
[ -z "$(git -C "$D" status --porcelain)" ] || note "tree is dirty: $(git -C "$D" status --porcelain | head -5)"
[ "$(git -C "$D" rev-parse HEAD)" = "$(git -C "$D" rev-parse origin/master)" ] || note "not level with origin/master"
[ -d "$D/plugins/marketplaces" ] || note "plugin marketplace checkouts were removed"
[ -f "$D/.credentials.json" ] || note "credentials disappeared"
if [ "$fail" -eq 0 ]; then echo "OK: $NAME runtime dir is app-ready"; fi
exit "$fail"
```

- [ ] **Step 2: Run it to verify it fails**

```bash
chmod +x $SCRATCH/check-runtime.sh
$SCRATCH/check-runtime.sh ~/.claude-power-dev claude-power-dev
$SCRATCH/check-runtime.sh ~/.claude-game-dev claude-game-dev
```

Expected: both FAIL on the SSH origin and a dirty tree.

- [ ] **Step 3: Back up the two live settings files, so a bad merge is recoverable**

```bash
cp ~/.claude-power-dev/settings.json $SCRATCH/settings-power.live.json
cp ~/.claude-game-dev/settings.json $SCRATCH/settings-game.live.json
cp ~/.claude-game-dev/README.md $SCRATCH/README-game.live.md
```

- [ ] **Step 4: Confirm the local edits really are upstream before discarding them**

```bash
for k in '.model' '.agentPushNotifEnabled' '.modelSettings["claude-fable-5-1"].effortLevel'; do
  printf '%-48s live=%-12s upstream=%s\n' "$k" \
    "$(jq -c "$k" $SCRATCH/settings-power.live.json)" \
    "$(jq -c "$k" $SCRATCH/probe-power/settings.json)"
done
for k in '.model' '.agentPushNotifEnabled'; do
  printf '%-48s live=%-12s upstream=%s\n' "$k" \
    "$(jq -c "$k" $SCRATCH/settings-game.live.json)" \
    "$(jq -c "$k" $SCRATCH/probe-game2/settings.json)"
done
```

Expected: `live` and `upstream` match on every line. If any differ, stop and reconcile by hand — do not proceed.

- [ ] **Step 5: Re-point origin, discard the now-redundant local edits, exclude the untracked skill**

```bash
git -C ~/.claude-power-dev remote set-url origin https://github.com/M4jor-Tom/claude-power-dev.git
git -C ~/.claude-power-dev checkout -- settings.json

git -C ~/.claude-game-dev remote set-url origin https://github.com/M4jor-Tom/claude-game-dev.git
git -C ~/.claude-game-dev checkout -- settings.json README.md
grep -qxF 'skills/ontology-resume-router-slice/' ~/.claude-game-dev/.git/info/exclude \
  || echo 'skills/ontology-resume-router-slice/' >> ~/.claude-game-dev/.git/info/exclude
```

`.git/info/exclude` is local and unpublished: the skill stays untracked and out
of the repo, while `git status` reads clean so the wrapper still auto-pulls.

- [ ] **Step 6: Fast-forward both, and prove nothing was deleted**

```bash
git -C ~/.claude-power-dev pull --ff-only
git -C ~/.claude-game-dev pull --ff-only
ls -d ~/.claude-power-dev/plugins/marketplaces/* | wc -l   # expect 5
ls -d ~/.claude-game-dev/skills/ontology-resume-router-slice   # still there
```

The power-dev pull removes five gitlinks. Git does not delete a submodule's
working tree when a checkout drops its gitlink, and `plugins/` is ignored by
the incoming `.gitignore`, so the five marketplace checkouts survive and the
live session keeps its plugins. `git submodule deinit` would delete them and is
deliberately never run. If a git version prunes them anyway, the recovery is
`claude plugin marketplace update`, which is what the declarations are for.

- [ ] **Step 7: Run the check**

```bash
$SCRATCH/check-runtime.sh ~/.claude-power-dev claude-power-dev
$SCRATCH/check-runtime.sh ~/.claude-game-dev claude-game-dev
```

Expected: `OK` for both.

- [ ] **Step 8: Commit nothing**

There is nothing to commit — this task changes only git remotes, a local
exclude file, and discards edits that are already upstream. Confirm:

```bash
git -C ~/.claude-power-dev status --porcelain && git -C ~/.claude-game-dev status --porcelain && echo "(both clean)"
```

---

### Task 6: End-to-end acceptance from GitHub

**Files:** none — this task only runs things.

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: the evidence that the goal is met.

- [ ] **Step 1: Run both apps straight from GitHub, against the live profile dirs**

```bash
nix run github:M4jor-Tom/claude-power-dev.app -- --version
nix run github:M4jor-Tom/claude-game-dev.app -- --version
```

Expected: each prints a `<version> (Claude Code)` line. These use the existing,
already-authenticated `~/.claude-*-dev` dirs and exercise the auto-pull path on
a clean tree with a matching HTTPS origin.

- [ ] **Step 2: Compare against the pi apps, which is the stated bar**

```bash
nix run github:M4jor-Tom/pi-power-dev.app -- --version
nix run github:M4jor-Tom/pi-game-dev.app -- --version
```

Expected: the pi apps print their own version banner the same way. Note in the
report any behavioural difference beyond the agent binary itself.

- [ ] **Step 3: Prove the fresh-machine path, in an isolated HOME**

```bash
rm -rf $SCRATCH/fakehome && mkdir -p $SCRATCH/fakehome
HOME=$SCRATCH/fakehome nix run github:M4jor-Tom/claude-game-dev.app -- --version
git -C $SCRATCH/fakehome/.claude-game-dev status --porcelain && echo "(clean)"
sh $SCRATCH/fakehome/.claude-game-dev/scripts/check.sh
```

Expected: the clone lands at `$SCRATCH/fakehome/.claude-game-dev`, reads clean,
and `check.sh` reports `OK: 70 skills resolve` — proving `--recursive` worked
from a genuinely cold start.

Plugin *materialization* is not asserted here: Claude Code fetches declared
marketplaces in a background pass after a session starts, which needs a login
this scratch HOME does not have. Report it as "documented behaviour, exercised
on the live authenticated dirs in Step 1", not as verified-from-cold.

- [ ] **Step 4: Confirm the live profiles still work in anger**

```bash
CLAUDE_CONFIG_DIR=~/.claude-power-dev claude plugin list | head -30
CLAUDE_CONFIG_DIR=~/.claude-power-dev claude plugin marketplace list | head -20
```

Expected: 9 enabled plugins and 5 marketplaces, exactly as before Task 1 — the
change is declarative, so nothing should have regressed.

- [ ] **Step 5: Run the mandated closing review**

```
/simplify
/ponytail:ponytail-review
```

Apply any adjustments they surface, re-running the affected task's check script
afterwards.

- [ ] **Step 6: Report**

State for each of the six repos: branch, HEAD, whether pushed, and which check
script proves it. Name anything left unverified — in particular cold-start
plugin materialization — rather than implying it passed.
