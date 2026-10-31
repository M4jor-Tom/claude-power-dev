# claude-power-dev

A Claude Code config directory: general-purpose coding profile. `pi-power-dev`
is its pi port.

## Use it

Without Nix — this repo *is* the config dir:

```bash
git clone --recurse-submodules https://github.com/M4jor-Tom/claude-power-dev.git ~/.claude-power-dev
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
| `settings.json` | Settings; disables the old marketplace plugin installs |
| `skills/` | Six local skills + relative symlinks to ten vendored plugins |
| `vendor/` | Seven upstream Git submodules, pinned to exact commits |
| `scripts/check.sh` | Checks submodule pins, skill links and plugin manifests |
| `docs/superpowers/` | Specs and plans |

## Vendored skills and plugins

Like `../claude-game-dev`, upstream repositories are Git submodules under
`vendor/`, exposed through relative symlinks in Claude Code's normal `skills/`
directory. Keep `vendor/` with `skills/`; copying only the links breaks them.

Each link targets the **plugin root**, containing `.claude-plugin/plugin.json`.
Claude Code's [skills-directory plugin loading](https://code.claude.com/docs/en/plugins/loading#plugins-shared-through-a-repository)
loads it automatically as `<name>@skills-dir`, including its nested skills,
commands, agents, hooks and MCP servers. This keeps plugin-relative resources
and `${CLAUDE_PLUGIN_ROOT}` working, with no marketplace registration or download.
Skill commands retain their namespaces, such as `/superpowers:using-superpowers`
and `/ponytail:ponytail-review`. Verified with Claude Code 2.1.283;
managed settings must not block skills-directory plugins.

| Submodule | Plugins exposed in `skills/` |
|---|---|
| `claude-plugins-official` | `frontend-design`, `claude-md-management`, `github`, `playwright` |
| `superpowers` | `superpowers` |
| `ponytail` | `ponytail` |
| `claude-mem` | `claude-mem` |
| `ui-ux-pro-max-skill` | `ui-ux-pro-max` |
| `understand-anything` | `understand-anything` |
| `i-have-adhd` | `i-have-adhd` |

The old marketplace IDs remain explicitly disabled in `settings.json` so an
existing plugin cache cannot load duplicate copies. `plugins/` stays untracked
as runtime state; it is no longer the source of these plugins.

For an existing clone, initialize the submodules before starting Claude:

```bash
git submodule update --init --recursive
sh scripts/check.sh
```

CI runs that check after recursive checkout. Dependabot proposes weekly
submodule updates; review and rerun the check before accepting a new pin.

## Runtime state

Claude Code writes sessions, projects, caches, credentials and its plugin cache
into the config dir, which is this repo. All of it is ignored; see
`.gitignore`. Keeping that list complete matters: one untracked file makes
`claude-power-dev.app` skip its auto-pull, silently.
