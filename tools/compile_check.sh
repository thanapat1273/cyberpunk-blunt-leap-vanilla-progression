#!/usr/bin/env bash
# Offline compile check for Blunt Leap.
#
# Compiles the game scripts, every installed script mod and this mod together,
# in a scratch folder. Nothing is written to the game folder.
#
#   tools/compile_check.sh "<game folder>" [work folder]
#
# Exit code 0 and no WARN or ERROR lines means the scripts compile cleanly
# against the current game and mod list.
set -euo pipefail

GAME="${1:-${CP2077_DIR:-}}"
if [ -z "$GAME" ] || [ ! -f "$GAME/engine/tools/scc.exe" ]; then
  echo "usage: compile_check.sh <game folder> [work folder]" >&2
  exit 2
fi
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${2:-$(mktemp -d)}"

rm -rf "$WORK/r6"
mkdir -p "$WORK/r6/scripts" "$WORK/r6/cache"
cp "$GAME/r6/cache/final.redscripts" "$WORK/r6/cache/"
cp -r "$GAME/r6/scripts/." "$WORK/r6/scripts/"
# Always test the working copy, not an installed one.
rm -rf "$WORK/r6/scripts/BluntLeap"
cp -r "$HERE/r6/scripts/BluntLeap" "$WORK/r6/scripts/"

: > "$WORK/paths.txt"
for d in ArchiveXL/Scripts Codeware/Scripts TweakXL/Scripts mod_settings; do
  if [ -d "$GAME/red4ext/plugins/$d" ]; then
    cygpath -w "$GAME/red4ext/plugins/$d" >> "$WORK/paths.txt"
  fi
done

set +e
"$GAME/engine/tools/scc.exe" -compile "$(cygpath -w "$WORK/r6/scripts")" \
  -compilePathsFile "$(cygpath -w "$WORK/paths.txt")" > "$WORK/scc.log" 2>&1
code=$?
set -e

grep -E "ERROR|WARN" "$WORK/scc.log" || true
tail -n 3 "$WORK/scc.log"
echo "scc exit code: $code   (full log: $WORK/scc.log)"
exit $code
