#!/usr/bin/env sh
# Check pinned submodules and the skills-directory plugins Claude discovers.
set -eu
cd "$(dirname "$0")/.."

fail=0
bad() { echo "FAIL: $*"; fail=1; }

[ -f .gitmodules ] || { echo 'FAIL: missing vendor submodules'; exit 1; }
status=$(git submodule status --recursive)
[ -n "$status" ] || bad 'no vendor submodules registered'
while IFS= read -r line; do
  case "$line" in
    [-+U]*) bad "submodule not at its initialized pin: $line (run: git submodule update --init --recursive)" ;;
  esac
done <<EOF
$status
EOF
# Deleted hook/MCP files (or other local edits) must not hide behind a valid pin.
git submodule foreach --quiet --recursive 'git diff --quiet HEAD --' >/dev/null 2>&1 || bad 'vendored submodules have tracked changes'

# Explicitly disable old marketplace installs so existing caches cannot duplicate
# the plugins now loaded automatically from skills/<name>/.claude-plugin/.
jq -e '(.enabledPlugins | length == 10) and all(.enabledPlugins[]; . == false) and ((.extraKnownMarketplaces // {}) | length == 0)' settings.json >/dev/null || bad 'all ten old marketplace copies must stay explicitly disabled'
for name in $(jq -r '.enabledPlugins | keys[] | split("@")[0]' settings.json); do
  [ -L "skills/$name" ] || bad "missing vendored plugin link: skills/$name"
done

count=0
plugins=0
for skill in skills/*; do
  if [ -L "$skill" ]; then
    case "$(readlink "$skill")" in
      ../vendor/*) ;;
      *) bad "skill link must be relative into vendor/: $skill" ;;
    esac
  fi
  if [ -f "$skill/SKILL.md" ]; then
    count=$((count + 1))
  elif [ -L "$skill" ] && [ -f "$skill/.claude-plugin/plugin.json" ]; then
    manifest="$skill/.claude-plugin/plugin.json"
    jq -e --arg name "${skill##*/}" '.name == $name' "$manifest" >/dev/null
    plugins=$((plugins + 1))
    roots=$(jq -r '.skills // "./skills" | if type == "array" then .[] else . end' "$manifest")
    for root in $roots; do
      if [ ! -d "$skill/$root" ]; then
        # MCP-only plugins need not have a skills directory.
        jq -e 'has("skills") | not' "$manifest" >/dev/null || bad "missing skill directory: $skill/$root"
        continue
      fi
      for nested in "$skill/$root"/*; do
        [ -d "$nested" ] || continue
        if [ -f "$nested/SKILL.md" ]; then count=$((count + 1)); else bad "broken skill: $nested"; fi
      done
    done
    for component in "$skill/.mcp.json" "$skill/hooks/hooks.json"; do
      [ ! -f "$component" ] || jq empty "$component"
    done
    hook=$(jq -r '.hooks // empty | select(type == "string")' "$manifest")
    [ -z "$hook" ] || { [ -f "$skill/$hook" ] && jq empty "$skill/$hook"; } || bad "missing hook: $skill/$hook"
  else
    bad "broken skill or plugin: $skill"
  fi
done

[ "$count" -ge 65 ] || bad "expected at least 65 skills, found $count"
[ "$plugins" -eq 10 ] || bad "expected ten vendored plugins, found $plugins"
[ "$fail" -eq 0 ] && echo "OK: $count skills and $plugins vendored plugins resolve; submodules match their pins"
exit "$fail"
