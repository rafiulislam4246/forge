#!/bin/sh
# Remove Forge.
#
#   ./uninstall.sh --global              hooks and skills, project artifacts kept
#   ./uninstall.sh --global --purge      artifacts too, in the current project
#   ./uninstall.sh /path/to/project      that project only
#
# Hook entries are stripped from settings.json; everything else in that file is
# left exactly as it was. Restored discipline skills are left in place, since
# they are useful with or without Forge.

set -eu

GLOBAL=0; PURGE=0; TARGET=""
for a in "$@"; do
  case $a in
    --global) GLOBAL=1 ;;
    --purge) PURGE=1 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET=$a ;;
  esac
done
[ "$GLOBAL" = "1" ] || [ -n "$TARGET" ] || GLOBAL=1

strip_hooks() {
  s=$1
  [ -f "$s" ] || return 0
  command -v python3 >/dev/null 2>&1 || { printf '  !!  remove the forge hook entries from %s by hand\n' "$s"; return 0; }
  cp "$s" "$s.forge-backup-$(date +%Y%m%d-%H%M%S)"
  python3 - "$s" <<'PY'
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception as e:
    sys.stderr.write("  kept     %s (unreadable: %s)\n" % (p, e))
    sys.exit(0)
hooks = d.get("hooks", {})
for ev in list(hooks):
    kept = [g for g in hooks[ev] if "forge-" not in json.dumps(g)]
    if kept: hooks[ev] = kept
    else: del hooks[ev]
if "hooks" in d and not d["hooks"]:
    del d["hooks"]
json.dump(d, open(p, "w"), indent=2)
open(p, "a").write("\n")
print("  cleaned  " + p)
PY
}

if [ "$GLOBAL" = "1" ]; then
  rm -rf "$HOME/.claude/forge"
  printf '  removed  ~/.claude/forge/\n'
  for s in forge forge-intake forge-build forge-audit forge-verify; do
    rm -rf "$HOME/.claude/skills/$s"
  done
  printf '  removed  ~/.claude/skills/forge*\n'
  rm -f "$HOME/.local/bin/forge"
  strip_hooks "$HOME/.claude/settings.json"
  printf '  kept     the restored discipline skills (useful without Forge)\n'
fi

if [ -n "$TARGET" ]; then
  TARGET=$(cd "$TARGET" && pwd)
  rm -f "$TARGET"/.claude/hooks/forge-*.sh
  for s in forge forge-intake forge-build forge-audit forge-verify; do
    rm -rf "$TARGET/.claude/skills/$s"
  done
  rm -rf "$TARGET/.forge/.templates" "$TARGET/.forge/forge"
  strip_hooks "$TARGET/.claude/settings.json"
  printf '  removed  %s/.claude/hooks/forge-*\n' "$TARGET"
fi

if [ "$PURGE" = "1" ]; then
  d=${TARGET:-$(pwd)}
  rm -rf "$d/.forge"
  printf '  removed  %s/.forge (evidence ledger gone)\n' "$d"
  printf '  kept     %s/docs/engineering (the written record, delete it yourself if you mean to)\n' "$d"
fi
