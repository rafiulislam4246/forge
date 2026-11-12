#!/bin/sh
# Forge installer.
#
#   ./install.sh --global              install for every project (recommended)
#   ./install.sh /path/to/project      install into one project only
#   ./install.sh --global --skills     also restore the engineering skill set
#                                      into ~/.claude/skills so it auto-triggers
#
# Global install puts the CLI, the hooks and the skills in ~/.claude, and wires
# the hooks into ~/.claude/settings.json. Every project then gets the gates,
# while each project still opts in to the artifacts by running `forge init`.
#
# Re-running is safe. settings.json is backed up and merged, never replaced.

set -eu

SRC=$(cd "$(dirname "$0")" && pwd)
GLOBAL=0
SKILLS=0
TARGET=""

for a in "$@"; do
  case $a in
    --global) GLOBAL=1 ;;
    --skills) SKILLS=1 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET=$a ;;
  esac
done
[ "$GLOBAL" = "1" ] || [ -n "$TARGET" ] || GLOBAL=1

for d in bin hooks templates skills; do
  [ -d "$SRC/$d" ] || { printf 'install: %s/%s missing. Run install.sh from inside the cloned repo.\n' "$SRC" "$d" >&2; exit 1; }
done

HOOK_LIST="forge-session-start forge-pre-edit forge-post-bash forge-reanchor forge-stop forge-task-complete forge-prompt"

merge_settings() {
  settings=$1; hookdir=$2
  [ -f "$settings" ] && cp "$settings" "$settings.forge-backup-$(date +%Y%m%d-%H%M%S)"
  HOOKDIR="$hookdir" python3 - "$settings" <<'PY'
import json, os, sys

path = sys.argv[1]
hd = os.environ["HOOKDIR"]
data = {}
if os.path.exists(path):
    txt = open(path).read().strip()
    if txt:
        try:
            data = json.loads(txt)
        except json.JSONDecodeError as e:
            sys.stderr.write("install: %s is not valid JSON (%s). Not touching it.\n" % (path, e))
            sys.exit(2)

hooks = data.setdefault("hooks", {})

WANTED = [
    ("SessionStart",  "startup|resume|clear|compact|fork", "forge-session-start.sh", "Loading engineering contract..."),
    ("UserPromptSubmit", None,                             "forge-prompt.sh",        None),
    ("PreToolUse",    "Edit|Write|MultiEdit|NotebookEdit", "forge-pre-edit.sh",      None),
    ("PostToolUse",   "Bash",                              "forge-post-bash.sh",     None),
    ("PostToolUse",   "Edit|Write|MultiEdit",              "forge-reanchor.sh",      None),
    ("Stop",          None,                                "forge-stop.sh",          None),
    ("TaskCompleted", None,                                "forge-task-complete.sh", None),
]

added = []
for event, matcher, script, status in WANTED:
    cmd = os.path.join(hd, script)
    groups = hooks.setdefault(event, [])
    if any(script in json.dumps(g) for g in groups):
        continue
    handler = {"type": "command", "command": cmd, "timeout": 20}
    if status:
        handler["statusMessage"] = status
    group = {"hooks": [handler]}
    if matcher:
        group["matcher"] = matcher
    groups.append(group)
    added.append(f"{event}:{script.replace('forge-','').replace('.sh','')}")

os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

print("  ok  %s  (+%s)" % (path.replace(os.path.expanduser("~"), "~"),
                           ", ".join(added) if added else "already wired"))
PY
}

install_skills_dir() {
  dest=$1
  mkdir -p "$dest"
  for s in "$SRC"/skills/*/; do
    [ -d "$s" ] || continue
    name=$(basename "$s")
    mkdir -p "$dest/$name"
    cp "$s"/*.md "$dest/$name/" 2>/dev/null || true
  done
  printf '  ok  %s/forge*\n' "$(printf '%s' "$dest" | sed "s|$HOME|~|")"
}

# Restores the engineering discipline skills into the auto-discoverable dir.
# These are the skills whose absence shows up as "it just starts coding".
restore_discipline_skills() {
  dest="$HOME/.claude/skills"
  mkdir -p "$dest"
  SET="spec-driven-development source-driven-development planning-and-task-breakdown \
api-and-interface-design documentation-and-adrs test-driven-development \
incremental-implementation code-review-and-quality doubt-driven-development \
debugging-and-error-recovery browser-testing-with-devtools frontend-ui-engineering \
shipping-and-launch code-simplification context-engineering interview-me"
  moved=0; missing=""
  for s in $SET; do
    [ -d "$dest/$s" ] && continue
    for src in "$HOME/.claude/skills_DELETED_2026-11-01/$s" \
               "$HOME/.claude/_disabled_skills/$s" \
               "$HOME/.claude/skills_FULLBACKUP_2026-11-01/$s" \
               "$HOME/.claude/skills-library/$s"; do
      if [ -d "$src" ]; then
        cp -R "$src" "$dest/$s"
        moved=$((moved + 1))
        break
      fi
    done
    [ -d "$dest/$s" ] || missing="$missing $s"
  done
  printf '  ok  ~/.claude/skills: %s discipline skill(s) restored\n' "$moved"
  [ -n "$missing" ] && printf '  !!  not found anywhere:%s\n' "$missing"
  # The router must be callable by the model, not only by the user.
  stack="$HOME/.claude/skills/stack/SKILL.md"
  if [ -f "$stack" ] && grep -q 'disable-model-invocation: *true' "$stack"; then
    cp "$stack" "$stack.forge-backup"
    sed -i '' 's/^disable-model-invocation: *true/disable-model-invocation: false/' "$stack" 2>/dev/null \
      || sed -i 's/^disable-model-invocation: *true/disable-model-invocation: false/' "$stack"
    printf '  ok  /stack is now model-invocable (was user-only, so nothing loaded by itself)\n'
  fi
}

if [ "$GLOBAL" = "1" ]; then
  printf 'Forge -> ~/.claude (all projects)\n'
  mkdir -p "$HOME/.claude/forge/bin" "$HOME/.claude/forge/hooks" "$HOME/.claude/forge/templates"
  cp "$SRC/bin/forge" "$HOME/.claude/forge/bin/forge"
  chmod +x "$HOME/.claude/forge/bin/forge"
  cp -R "$SRC/templates/." "$HOME/.claude/forge/templates/"
  printf '  ok  ~/.claude/forge/bin/forge\n'
  for h in $HOOK_LIST; do
    cp "$SRC/hooks/$h.sh" "$HOME/.claude/forge/hooks/$h.sh"
    chmod +x "$HOME/.claude/forge/hooks/$h.sh"
  done
  printf '  ok  ~/.claude/forge/hooks/ (7 hooks)\n'
  install_skills_dir "$HOME/.claude/skills"
  [ "$SKILLS" = "1" ] && restore_discipline_skills
  merge_settings "$HOME/.claude/settings.json" "$HOME/.claude/forge/hooks"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.claude/forge/bin/forge" "$HOME/.local/bin/forge"
  printf '  ok  ~/.local/bin/forge -> symlink (ensure ~/.local/bin is on PATH)\n'
fi

if [ -n "$TARGET" ]; then
  TARGET=$(cd "$TARGET" && pwd)
  printf '\nForge -> %s (this project)\n' "$TARGET"
  mkdir -p "$TARGET/.claude/hooks"
  for h in $HOOK_LIST; do
    cp "$SRC/hooks/$h.sh" "$TARGET/.claude/hooks/$h.sh"
    chmod +x "$TARGET/.claude/hooks/$h.sh"
  done
  printf '  ok  .claude/hooks/ (7 hooks)\n'
  install_skills_dir "$TARGET/.claude/skills"
  mkdir -p "$TARGET/.forge/.templates"
  cp -R "$SRC/templates/." "$TARGET/.forge/.templates/"
  cp "$SRC/bin/forge" "$TARGET/.forge/forge"; chmod +x "$TARGET/.forge/forge"
  merge_settings "$TARGET/.claude/settings.json" '${CLAUDE_PROJECT_DIR}/.claude/hooks'
  ( cd "$TARGET" && "$SRC/bin/forge" init | sed 's/^forge: /  ok  /' )
fi

cat <<'EOF'

Done. In any project:
  forge init                     turn on the artifacts for this project
  forge new "<what you build>"   research -> architecture -> plan -> tests
  forge verify                   run the checks, record the evidence
  forge strict on                make the gates block instead of advise
  forge doctor                   check the wiring

Gates are ADVISORY until you run `forge strict on` in a project.
EOF
