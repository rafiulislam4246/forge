#!/bin/sh
# Forge PreToolUse hook for Edit|Write|MultiEdit|NotebookEdit.
# The plan gate: product code must not be written before a plan with tasks
# exists. Advisory by default (additionalContext), blocking when strict is on
# (permissionDecision: deny).
#
# Exempt by design: tests, docs, config, the forge artifacts themselves, and
# anything outside the project's code directories. The gate is about product
# code, so writing the plan or the tests it demands is never blocked.

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

target=$(printf '%s' "$payload" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
ti=d.get("tool_input") or {}
print(ti.get("file_path") or ti.get("notebook_path") or "")
' 2>/dev/null || printf '')
cwd=$(printf '%s' "$payload" | python3 -c '
import json,sys
try: print((json.load(sys.stdin).get("cwd") or ""))
except Exception: pass
' 2>/dev/null || printf '')

[ -n "$target" ] || exit 0

dir=${cwd:-$(pwd)}
while [ "$dir" != "/" ] && [ ! -d "$dir/.forge" ]; do dir=$(dirname "$dir"); done
[ -d "$dir/.forge" ] || exit 0

rel=${target#"$dir/"}

# Not product code: never gated.
case $rel in
  *test*|*spec*|*__tests__*|*.test.*|*.spec.*) exit 0 ;;
  docs/*|*.md|*.mdx|*.txt|*.json|*.yaml|*.yml|*.toml|*.lock|*.env*) exit 0 ;;
  .forge/*|.continuum/*|.claude/*|.github/*|scripts/*|*.sh) exit 0 ;;
esac

# Product code only: must sit under a configured code directory.
globs=$(python3 - "$dir/.forge/config.json" <<'PY' 2>/dev/null || printf 'src/ app/ lib/'
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: d={}
print(d.get("code_globs","src/ app/ lib/"))
PY
)
in_code=0
for g in $globs; do
  case $rel in "$g"*) in_code=1; break ;; esac
done
[ "$in_code" = "1" ] || exit 0

if reason=$(FORGE_PROJECT="$dir" "$CLI" gate code 2>&1); then
  # Gate passed. Record the edit time so the done and ui gates can compare.
  : > "$dir/.forge/.last-edit"
  exit 0
fi

: > "$dir/.forge/.last-edit"
strict=$(FORGE_PROJECT="$dir" "$CLI" strict 2>/dev/null | sed 's/strict: //')

if [ "$strict" = "true" ]; then
  MSG="Forge plan gate: $reason

Writing $rel is blocked until a plan exists. Do one of:
  forge new \"<what you are building>\"   then fill research.md, architecture.md and plan.md
  forge waive 30 \"<why this is trivial>\"  for a genuinely small fix
The plan file itself, tests and docs are never blocked." \
  python3 -c '
import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":os.environ["MSG"]}}))'
else
  MSG="Forge plan gate (advisory): $reason

You are editing product code ($rel) with no plan on record. Prefer to stop and run
\`forge new \"<title>\"\`, then fill research.md and plan.md before continuing. If this
really is a one-line fix, run \`forge waive 30 \"<why>\"\` so the bypass is recorded." \
  python3 -c '
import json,os
print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":os.environ["MSG"]}}))'
fi
exit 0
