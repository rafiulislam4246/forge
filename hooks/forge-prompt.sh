#!/bin/sh
# Forge UserPromptSubmit hook.
# Catches the moment the problem actually starts: a build request answered by
# typing code. When the prompt asks for something to be built and no workstream
# is open, the research-first rule is restated next to the prompt. Stdout on
# this event reaches the context, and it stays quiet in every other case.

set -eu

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
[ -n "$payload" ] || exit 0

prompt=$(printf '%s' "$payload" | python3 -c '
import json,sys
try: print((json.load(sys.stdin).get("prompt") or "")[:2000])
except Exception: pass
' 2>/dev/null || printf '')
cwd=$(printf '%s' "$payload" | python3 -c '
import json,sys
try: print(json.load(sys.stdin).get("cwd") or "")
except Exception: pass
' 2>/dev/null || printf '')

[ -n "$prompt" ] || exit 0

dir=${cwd:-$(pwd)}
while [ "$dir" != "/" ] && [ ! -d "$dir/.forge" ]; do dir=$(dirname "$dir"); done
[ -d "$dir/.forge" ] || exit 0

# Is this a build request? Keep the test narrow: false positives are noise.
printf '%s' "$prompt" | grep -qiE '\b(build|implement|create|add|make|develop|set ?up|refactor|migrate|redesign|rewrite)\b' || exit 0
# A request to audit or investigate is handled by its own path.
printf '%s' "$prompt" | grep -qiE '\b(audit|review|investigate|explain|why|how does)\b' && exit 0

if FORGE_PROJECT="$dir" "$CLI" gate code >/dev/null 2>&1; then
  exit 0   # a plan is already open, nothing to say
fi

cat <<'EOF'
FORGE: this reads as a build request and no plan is open for it. Before writing
product code: research what already exists in this codebase and what the
constraints are, decide the architecture, then write the plan. Start with
`forge new "<title>"`, which creates research.md, architecture.md, plan.md,
test-plan.md and review.md, and fill them in that order. Tests precede the code
they cover. If this is genuinely a one-line fix, `forge waive 30 "<why>"`.
EOF
exit 0
