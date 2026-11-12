#!/bin/sh
# Forge TaskCompleted hook.
# Exit 2 prevents completion. In strict mode a task cannot be marked complete
# while the evidence gate is failing, which is the difference between a process
# that is followed and one that is merely written down. Advisory otherwise.

set -eu

ROOT=${CLAUDE_PROJECT_DIR:-$(pwd)}
# Resolve the CLI: env override, PATH, global install, project install, or a
# repo checkout. A hook that cannot find it exits quietly rather than failing.
HOOK_DIR=$(cd "$(dirname "$0")" && pwd)
CLI=""
for c in "${FORGE_CLI:-}" "$(command -v forge 2>/dev/null || true)" \
         "$HOME/.claude/forge/bin/forge" "$HOOK_DIR/../bin/forge" \
         "$HOOK_DIR/../../.forge/forge" "$HOOK_DIR/../.forge/forge"; do
  if [ -n "$c" ] && [ -x "$c" ]; then CLI=$c; break; fi
done
[ -n "$CLI" ] || exit 0

dir=$ROOT
while [ "$dir" != "/" ] && [ ! -d "$dir/.forge" ]; do dir=$(dirname "$dir"); done
[ -d "$dir/.forge" ] || exit 0

# Nothing edited: a planning or research task, nothing to prove.
[ -f "$dir/.forge/.last-edit" ] || exit 0

if r=$(FORGE_PROJECT="$dir" "$CLI" gate done 2>&1); then
  exit 0
fi

strict=$(FORGE_PROJECT="$dir" "$CLI" strict 2>/dev/null | sed 's/strict: //')
if [ "$strict" = "true" ]; then
  printf 'Forge evidence gate: %s\nRun `forge verify` and let it pass before completing this task.\n' "$r" >&2
  exit 2
fi

MSG="Forge evidence gate (advisory): $r
This task is being completed without a passing run on record. Run \`forge verify\`." \
python3 -c '
import json,os
print(json.dumps({"systemMessage":os.environ["MSG"]}))' 2>/dev/null || true
exit 0
