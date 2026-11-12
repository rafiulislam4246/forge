#!/bin/sh
# Forge SessionStart hook.
# Stdout on SessionStart is added to the session context, so this states the
# engineering contract and the project's current phase state. Silent in a
# project that has not run `forge init`, so it is safe to install globally.

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

# Walk up for .forge, the same way the CLI does.
dir=$ROOT
while [ "$dir" != "/" ] && [ ! -d "$dir/.forge" ]; do dir=$(dirname "$dir"); done
if [ ! -d "$dir/.forge" ]; then
  # Not a forge project. Mention it only where it is relevant: a directory that
  # holds a real codebase. Everywhere else, stay silent rather than add noise to
  # every session on the machine.
  for m in package.json pyproject.toml go.mod Cargo.toml composer.json Gemfile pom.xml build.gradle; do
    if [ -f "$ROOT/$m" ]; then
      printf 'FORGE: this codebase has no engineering gates yet. If this session will write product code, run `forge init`, then `forge new "<what you are building>"` so research, architecture, plan and tests exist before the code does.\n'
      exit 0
    fi
  done
  exit 0
fi

strict=$(FORGE_PROJECT="$dir" "$CLI" strict 2>/dev/null | sed 's/strict: //')

cat <<EOF
=== FORGE ENGINEERING CONTRACT (strict=${strict:-false}) ===
This project runs a gated engineering process. The rules below are the process,
not advice, and the gates are checked by hooks rather than by memory.

1. No product code before a plan exists. Order is research -> architecture ->
   plan -> tests -> implementation. \`forge new "<title>"\` scaffolds the files;
   fill them in that order.
2. Tests come before the implementation they cover. A test you have not watched
   fail proves nothing.
3. Nothing is "done", "fixed" or "working" without evidence: a command that ran
   and output that was read. Record it with \`forge verify\` (preferred) or
   \`forge evidence add <kind> pass "<cmd>" "<what you saw>"\`.
4. Any change a user can see is verified in a real browser before any claim
   about it. Screenshot or drive the actual page, then record browser evidence.
5. A small, genuinely trivial fix may bypass the plan gate with
   \`forge waive 30 "<reason>"\`. Bypassing it silently is not an option.
6. Report failures as failures, with the output quoted. Never describe intended
   behaviour as observed behaviour.

EOF

# The brief carries the active workstream, the current task, the out-of-scope
# list, gate state and recent evidence. It is re-injected after compaction
# because this hook also matches source=compact.
FORGE_PROJECT="$dir" "$CLI" brief 2>/dev/null

cat <<'EOF'

Skills to load for each phase (they are installed and auto-trigger):
  research       source-driven-development, spec-driven-development
  architecture   api-and-interface-design, documentation-and-adrs
  plan           planning-and-task-breakdown, incremental-implementation
  implement      test-driven-development
  review         code-review-and-quality, doubt-driven-development
  UI             frontend-ui-engineering, browser-testing-with-devtools
  debugging      debugging-and-error-recovery
  shipping       shipping-and-launch
=== END CONTRACT ===
EOF
