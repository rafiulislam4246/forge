#!/bin/sh
# Forge end-to-end gate matrix.
set -u
SRC=/Users/rafiulislam/Work/n8n/smooth/forge
R=/private/tmp/claude-501/-Users-rafiulislam-Work-n8n/e9a43d71-815e-4a6c-a9c6-238893a6d798/scratchpad/forge-sandbox
FORGE="$SRC/bin/forge"
PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n       got: %s\n' "$1" "$2"; }
check(){ # desc expected_substring actual
  case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "$(printf '%s' "$3" | head -3 | tr '\n' '|')" ;; esac
}

rm -rf "$R"; mkdir -p "$R/src/components"
cd "$R" || exit 1
git init -q .
cat > package.json <<'EOF'
{ "name": "sandbox", "version": "1.0.0",
  "scripts": {
    "test": "node -e \"console.log('Tests:  3 passed, 0 failed')\"",
    "build": "node -e \"console.log('compiled successfully')\""
  } }
EOF
printf 'export const x = 1\n' > src/app.ts
git add -A >/dev/null 2>&1; git -c user.email=t@t -c user.name=t commit -qm init

echo "=== 1. init + kickoff (intake must create NOTHING else)"
out=$("$FORGE" init 2>&1); check "init works" "initialised" "$out"
out=$("$FORGE" kickoff "Sandbox App" 2>&1); check "kickoff opens intake" "intake opened" "$out"
created=$(ls docs/engineering/000-intake/ | tr '\n' ' ')
check "intake has brief+intake only" "brief.md intake.md" "$created"
[ -f README.md ] && bad "kickoff must not create README" "README.md exists" || ok "kickoff created no README (approval gate holds)"
n=$(ls docs/engineering | grep -c '^[0-9][0-9][0-9]-' )
[ "$n" = "1" ] && ok "no workstream scaffolded before approval" || bad "workstreams before approval" "$n"

echo "=== 2. plan gate (code) before any plan"
out=$("$FORGE" gate code 2>&1); rc=$?
check "gate code fails with no plan" "fail" "$out"
[ $rc = 1 ] && ok "gate code exit 1" || bad "gate code exit code" "$rc"

echo "=== 3. PreToolUse hook: advisory mode"
payload='{"cwd":"'$R'","tool_name":"Write","tool_input":{"file_path":"'$R'/src/app.ts","content":"x"}}'
out=$(printf '%s' "$payload" | "$SRC/hooks/forge-pre-edit.sh" 2>&1)
check "advisory additionalContext on product code" "additionalContext" "$out"
check "advisory does not deny" "advisory" "$out"
case "$out" in *'"deny"'*) bad "advisory must not deny" "$out" ;; *) ok "no deny while strict=off" ;; esac

echo "=== 4. exemptions: tests, docs, plan file itself"
for f in src/app.test.ts docs/engineering/000-intake/plan.md README.md .forge/config.json; do
  p='{"cwd":"'$R'","tool_name":"Write","tool_input":{"file_path":"'$R'/'$f'"}}'
  o=$(printf '%s' "$p" | "$SRC/hooks/forge-pre-edit.sh" 2>&1)
  [ -z "$o" ] && ok "exempt: $f" || bad "exempt: $f" "$o"
done

echo "=== 5. strict mode denies"
"$FORGE" strict on >/dev/null
out=$(printf '%s' "$payload" | "$SRC/hooks/forge-pre-edit.sh" 2>&1)
check "strict emits deny" '"permissionDecision": "deny"' "$out"
check "deny reason names the fix" "forge new" "$out"
python3 -c 'import json,sys; json.load(sys.stdin)' <<EOF >/dev/null 2>&1 && ok "deny payload is valid JSON" || bad "deny JSON invalid" "$out"
$out
EOF

echo "=== 6. plan gate opens only when plan has real tasks"
ws=$("$FORGE" new "Add retry to the webhook" 2>/dev/null)
out=$("$FORGE" gate code 2>&1); check "still fails while plan is _pending_" "fail" "$out"
PLAN="docs/engineering/$ws/plan.md"
python3 - "$PLAN" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read().replace("_pending_","")
real="- [ ] **T1** - cap the backoff at 30s\n  - Files: src/app.ts\n  - Verify: npm test\n"
s=s.replace("## Tasks\n", "## Tasks\n\n"+real, 1)
open(p,"w").write(s)
PY
out=$("$FORGE" gate code 2>&1); check "gate opens with a real task" "pass" "$out"
out=$(printf '%s' "$payload" | "$SRC/hooks/forge-pre-edit.sh" 2>&1)
[ -z "$out" ] && ok "hook silent once plan exists" || bad "hook should be silent" "$out"

echo "=== 7. waiver path"
"$FORGE" strict off >/dev/null; rm -f .forge/active; printf '' > .forge/active
out=$("$FORGE" gate code 2>&1); check "no active workstream fails" "no active workstream" "$out"
"$FORGE" waive 30 "one line typo fix" >/dev/null
out=$("$FORGE" gate code 2>&1); check "waiver opens the gate" "waiver active" "$out"
rm -f .forge/.waiver; printf '%s' "$ws" > .forge/active

echo "=== 8. forge verify records real evidence"
out=$("$FORGE" verify 2>&1)
check "verify runs npm test" "3 passed" "$out"
check "verify reports 0 failed" "0 failed" "$out"
ev=$("$FORGE" evidence list 2>&1)
check "test evidence recorded as pass" "test	pass" "$ev"

echo "=== 9. done gate honours edit-after-proof"
out=$("$FORGE" gate done 2>&1); check "done passes right after verify" "pass" "$out"
sleep 1; : > .forge/.last-edit
out=$("$FORGE" gate done 2>&1); check "done fails after a later edit" "code changed after" "$out"

echo "=== 10. PostToolUse bash hook classifies a FAILING test run"
p='{"cwd":"'$R'","tool_name":"Bash","tool_input":{"command":"pnpm test src/app"},"tool_response":{"stdout":"Tests: 2 failed, 1 passed","exit_code":1}}'
out=$(printf '%s' "$p" | "$SRC/hooks/forge-post-bash.sh" 2>&1)
check "failing run injects context" "FAILING" "$out"
ev=$("$FORGE" evidence list); check "failure written to ledger" "test	fail" "$ev"
p='{"cwd":"'$R'","tool_name":"Bash","tool_input":{"command":"npm run build"},"tool_response":{"stdout":"compiled successfully","exit_code":0}}'
out=$(printf '%s' "$p" | "$SRC/hooks/forge-post-bash.sh" 2>&1)
[ -z "$out" ] && ok "passing build stays silent" || bad "passing build should be silent" "$out"
ev=$("$FORGE" evidence list); check "build pass recorded" "build	pass" "$ev"
p='{"cwd":"'$R'","tool_name":"Bash","tool_input":{"command":"ls -la"},"tool_response":{"stdout":"x","exit_code":0}}'
out=$(printf '%s' "$p" | "$SRC/hooks/forge-post-bash.sh" 2>&1)
[ -z "$out" ] && ok "unrelated command ignored" || bad "should ignore ls" "$out"

echo "=== 11. UI gate"
out=$("$FORGE" gate ui 2>&1); check "no UI change = pass" "pass" "$out"
printf 'export const Btn = () => null\n' > src/components/Btn.tsx
out=$("$FORGE" gate ui 2>&1); check "UI change with no browser proof fails" "no browser verification" "$out"
"$FORGE" evidence add browser pass "drove /dashboard in Chrome" "filters work, no console errors" >/dev/null
out=$("$FORGE" gate ui 2>&1); check "browser evidence opens UI gate" "pass" "$out"

echo "=== 12. Stop hook"
sleep 1; : > .forge/.last-edit; rm -f .forge/.stop-nudged
out=$(CLAUDE_PROJECT_DIR="$R" "$SRC/hooks/forge-stop.sh" 2>&1)
check "stop nudges on failing gates" "Forge gates are failing" "$out"
out2=$(CLAUDE_PROJECT_DIR="$R" "$SRC/hooks/forge-stop.sh" 2>&1)
[ -z "$out2" ] && ok "stop cooldown suppresses repeat" || bad "cooldown broken" "$out2"

echo "=== 13. TaskCompleted blocks in strict mode"
"$FORGE" strict on >/dev/null
out=$(CLAUDE_PROJECT_DIR="$R" "$SRC/hooks/forge-task-complete.sh" 2>&1); rc=$?
[ $rc = 2 ] && ok "TaskCompleted exit 2 blocks completion" || bad "TaskCompleted exit code" "$rc"
check "block reason names the fix" "forge verify" "$out"
"$FORGE" verify >/dev/null 2>&1
out=$(CLAUDE_PROJECT_DIR="$R" "$SRC/hooks/forge-task-complete.sh" 2>&1); rc=$?
[ $rc = 0 ] && ok "TaskCompleted allows once evidence is fresh" || bad "should allow after verify" "rc=$rc $out"
"$FORGE" strict off >/dev/null

echo "=== 14. re-anchor hook (mid-session drift fix)"
rm -f .forge/.edits
p='{"cwd":"'$R'","tool_name":"Edit","tool_input":{"file_path":"'$R'/src/app.ts"}}'
i=1; last=""
while [ $i -le 8 ]; do last=$(printf '%s' "$p" | "$SRC/hooks/forge-reanchor.sh" 2>&1); i=$((i+1)); done
check "anchor fires on the 8th edit" "FORGE ANCHOR" "$last"
check "anchor carries the current task" "T1" "$last"
out=$(printf '%s' "$p" | "$SRC/hooks/forge-reanchor.sh" 2>&1)
[ -z "$out" ] && ok "anchor silent on other edits" || bad "anchor too chatty" "$out"

echo "=== 15. UserPromptSubmit hook"
rm -f .forge/active; printf '' > .forge/active
p='{"cwd":"'$R'","prompt":"build me a dashboard with charts"}'
out=$(printf '%s' "$p" | "$SRC/hooks/forge-prompt.sh" 2>&1)
check "build request gets research-first" "research" "$out"
p='{"cwd":"'$R'","prompt":"why does the webhook fail"}'
out=$(printf '%s' "$p" | "$SRC/hooks/forge-prompt.sh" 2>&1)
[ -z "$out" ] && ok "question is not treated as a build request" || bad "false positive on question" "$out"
printf '%s' "$ws" > .forge/active
p='{"cwd":"'$R'","prompt":"implement the retry cap"}'
out=$(printf '%s' "$p" | "$SRC/hooks/forge-prompt.sh" 2>&1)
[ -z "$out" ] && ok "silent when a plan is already open" || bad "should be silent" "$out"

echo "=== 16. SessionStart brief"
out=$(CLAUDE_PROJECT_DIR="$R" "$SRC/hooks/forge-session-start.sh" 2>&1)
check "contract injected" "FORGE ENGINEERING CONTRACT" "$out"
check "brief names the active workstream" "$ws" "$out"
check "brief shows the current task" "T1" "$out"
check "brief lists gate state" "GATES" "$out"
printf '  brief size: %s bytes\n' "$(printf '%s' "$out" | wc -c | tr -d ' ')"

echo "=== 17. adr / audit / list / status / doctor"
f=$("$FORGE" adr "Use Postgres for the retry queue" 2>&1); check "adr numbered" "adr/0001-" "$f"
out=$("$FORGE" audit 2>&1); check "audit scaffolded" "audit-" "$out"
a=$(ls docs/engineering | grep '^audit-' | head -1)
created=$(ls "docs/engineering/$a" | tr '\n' ' ')
check "audit has 3 artifacts" "findings.md remediation.md scope.md" "$created"
printf '%s' "$ws" > .forge/active
out=$("$FORGE" list 2>&1); check "list shows real-task progress (placeholders excluded)" "plan: 0/1 tasks" "$out"
out=$("$FORGE" status 2>&1); check "status shows phases" "plan.md" "$out"
out=$("$FORGE" doctor 2>&1); check "doctor sees the global hook wiring" "hooks wired in" "$out"

echo
printf 'RESULT: %s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" = "0" ] || exit 1
