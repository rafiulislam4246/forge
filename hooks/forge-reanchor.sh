#!/bin/sh
# Forge PostToolUse hook for Edit|Write|MultiEdit.
# The mid-session drift fix. A long session fills its context window and the
# plan written two hours ago stops being present in it; what follows looks like
# forgetting. Every Nth edit this re-injects the current task, the progress
# count and the out-of-scope list, so the plan is always close at hand rather
# than far back in the transcript.
#
# Cheap by design: a counter file, and a short block only when it trips.

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

payload=$(cat 2>/dev/null || printf '')
cwd=$(printf '%s' "$payload" | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("cwd") or "")
except Exception: pass
' 2>/dev/null || printf '')

dir=${cwd:-$ROOT}
while [ "$dir" != "/" ] && [ ! -d "$dir/.forge" ]; do dir=$(dirname "$dir"); done
[ -d "$dir/.forge" ] || exit 0
F="$dir/.forge"

EVERY=${FORGE_ANCHOR_EVERY:-8}

n=0
[ -f "$F/.edits" ] && n=$(tr -dc '0-9' < "$F/.edits")
[ -n "$n" ] || n=0
n=$((n + 1))
printf '%s' "$n" > "$F/.edits"

[ $((n % EVERY)) -eq 0 ] || exit 0

anchor=$(FORGE_PROJECT="$dir" "$CLI" anchor 2>/dev/null || printf '')
[ -n "$anchor" ] || exit 0

ANCHOR="$anchor" python3 -c '
import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":os.environ["ANCHOR"]}}))'
exit 0
