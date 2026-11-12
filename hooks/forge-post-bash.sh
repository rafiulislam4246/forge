#!/bin/sh
# Forge PostToolUse hook for Bash.
# Every test, build, lint or browser command the session runs is classified and
# written to the evidence ledger automatically, with pass or fail taken from the
# exit code when the harness provides one and inferred from the output when it
# does not. This is what makes "the tests pass" checkable later instead of
# merely assertable.
#
# The classifier is a separate temp script on purpose: the payload arrives on
# stdin, so the script cannot also be fed to python on stdin as a heredoc.

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

SCRIPT=$(mktemp "${TMPDIR:-/tmp}/forge-classify.XXXXXX") || exit 0
trap 'rm -f "$SCRIPT"' EXIT INT TERM

cat > "$SCRIPT" <<'PY'
import json, os, re, subprocess, sys

cli = sys.argv[1]
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

cmd = ((d.get("tool_input") or {}).get("command") or "").strip()
if not cmd:
    sys.exit(0)

low = cmd.lower()

# forge's own commands already write evidence; do not double count.
if re.search(r'\bforge\b', low):
    sys.exit(0)

KINDS = [
    ("browser", r'playwright|puppeteer|cypress|selenium|chrome --headless|screenshot'),
    ("test",    r'\b(pytest|jest|vitest|mocha|ava|phpunit|rspec)\b|go test|cargo test|(npm|pnpm|yarn|bun)( run)? test'),
    ("build",   r'\b(tsc|webpack|make)\b|next build|vite build|cargo build|go build|(npm|pnpm|yarn|bun)( run)? build'),
    ("lint",    r'\b(eslint|ruff|flake8|clippy|biome|mypy|pyright)\b|prettier --check|(npm|pnpm|yarn|bun)( run)? (lint|typecheck)'),
    ("api",     r'\bcurl\b|\bhttpie\b|\bwget\b'),
]
kind = next((k for k, pat in KINDS if re.search(pat, low)), None)
if not kind:
    sys.exit(0)

resp = d.get("tool_response")
text = ""
code = None
if isinstance(resp, dict):
    for f in ("stdout", "output", "stderr", "content"):
        v = resp.get(f)
        if isinstance(v, str):
            text += "\n" + v
    for f in ("exit_code", "exitCode", "returnCode", "code"):
        v = resp.get(f)
        if isinstance(v, int):
            code = v
            break
    if resp.get("interrupted"):
        sys.exit(0)
elif isinstance(resp, str):
    text = resp

# A command that could not start is an environment problem, not evidence about
# the project. Recording it would put a false failure on the record, which is
# exactly what this ledger exists to prevent.
if re.search(r'command not found|: not found|no such file or directory|is not recognized', text.lower()):
    sys.exit(0)

if code is not None:
    status = "pass" if code == 0 else "fail"
else:
    t = text.lower()
    bad = re.search(r'\d+ failed|failed:|failing|error:|exception|traceback|assertionerror|exit code [1-9]', t)
    good = re.search(r'\d+ pass|all tests pass|passed|success|built in|compiled successfully|0 problems', t)
    if bad and not good:
        status = "fail"
    elif good and not bad:
        status = "pass"
    else:
        sys.exit(0)  # ambiguous: record nothing rather than a wrong claim

# A one line summary: the most informative line of the output.
summary = ""
for ln in reversed([l.strip() for l in text.splitlines() if l.strip()]):
    if re.search(r'pass|fail|error|test|built|compiled|\d+', ln, re.I):
        summary = ln[:200]
        break
if not summary:
    summary = "inferred " + status

try:
    subprocess.run(
        [cli, "evidence", "add", kind, status, cmd, summary],
        cwd=d.get("cwd") or os.getcwd(),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10,
    )
except Exception:
    sys.exit(0)

if status == "fail":
    print(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": (
            f"Forge recorded this {kind} run as FAILING in the evidence ledger. "
            "Treat it as the current state of the project: do not describe this area as working, "
            "and fix the failure before moving on. Root cause first, per debugging-and-error-recovery."
        )}}))
PY

printf '%s' "$payload" | python3 "$SCRIPT" "$CLI" 2>/dev/null || true
exit 0
