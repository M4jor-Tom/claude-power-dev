# Claude Code config

Versioned `~/.claude`: user config, custom skills, rules, and the plugin
marketplaces as git submodules.

Runtime state Claude Code regenerates (`sessions/`, `projects/`, `cache/`,
`plugins/cache/`, `telemetry/`, …) is ignored — see `.gitignore`.

## Restore on a new machine

```bash
git clone --recursive <this-repo> ~/.claude
```

Already cloned without `--recursive`:

```bash
git -C ~/.claude submodule update --init
```

That restores every marketplace at its pinned commit. Claude Code does not
know they are registered yet, because `known_marketplaces.json` and
`installed_plugins.json` hardcode absolute install paths and are therefore
not tracked. Register them once, in Claude Code:

```
/plugin marketplace add anthropics/claude-plugins-official
/plugin marketplace add DietrichGebert/ponytail
/plugin marketplace add thedotmack/claude-mem
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin marketplace add Egonex-AI/Understand-Anything
```

Then reinstall the plugins:

```
/plugin install superpowers@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
/plugin install claude-md-management@claude-plugins-official
/plugin install github@claude-plugins-official
/plugin install playwright@claude-plugins-official
/plugin install ponytail@ponytail
/plugin install claude-mem@thedotmack
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
/plugin install understand-anything@understand-anything
```

## Updating a marketplace

Claude Code updates the checkout in place; the submodule then points at a new
commit. Record it:

```bash
git -C ~/.claude add plugins/marketplaces/<name>
git -C ~/.claude commit -m "chore(plugins): bump <name>"
```

`claude-plugins-official` is the exception — Claude Code refreshes it from a
tarball rather than by `git pull`, so after an update reconcile it against the
SHA in its `.gcs-sha` file:

```bash
cd ~/.claude/plugins/marketplaces/claude-plugins-official
git fetch && git checkout "$(cat .gcs-sha)"
```
