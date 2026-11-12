#!/bin/sh
# Forge Stop hook.
# End of turn. Checks the two gates that catch the failures that hurt most:
# claiming done with no passing run, and shipping UI nobody looked at. Stop
# hooks reach the model through additionalContext, so this emits JSON, and a
# cooldown keeps it from repeating itself every turn.

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
F="$dir/.forge"

COOLDOWN_MIN=${FORGE_COOLDOWN_MIN:-10}
NOW=$(date -u +%s)
mtime() {
  [ -e "$1" ] || { printf '0'; return; }
  m=$(date -u -r "$1" +%s 2>/dev/null) && [ -n "$m" ] && { printf '%s' "$m"; return; }
  m=$(stat -f %m "$1" 2>/dev/null) && [ -n "$m" ] && { printf '%s' "$m"; return; }
  m=$(stat -c %Y "$1" 2>/dev/null) && [ -n "$m" ] && { printf '%s' "$m"; return; }
  printf '0'
}

# Nothing was edited this session: nothing to nag about.
le=$(mtime "$F/.last-edit")
[ "$le" = "0" ] && exit 0

n=$(mtime "$F/.stop-nudged")
[ "$n" != "0" ] && [ $(( (NOW - n) / 60 )) -lt "$COOLDOWN_MIN" ] && exit 0

msgs=""
if ! r=$(FORGE_PROJECT="$dir" "$CLI" gate done 2>&1); then
  msgs="$msgs
- Evidence gate: $r"
fi
if ! r=$(FORGE_PROJECT="$dir" "$CLI" gate ui 2>&1); then
  msgs="$msgs
- UI gate: $r"
fi

[ -n "$msgs" ] || exit 0
: > "$F/.stop-nudged"

MSG="Forge gates are failing on the current working tree:$msgs

Code has changed since the last proof. Before this work is described as done,
run \`forge verify\` and, for anything a user can see, drive the real UI and
record browser evidence. If something cannot be verified here, say which part is
unverified rather than leaving the claim open." \
python3 -c '
import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":os.environ["MSG"]}}))'
exit 0
