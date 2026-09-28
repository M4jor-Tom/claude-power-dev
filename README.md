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
