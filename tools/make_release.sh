#!/usr/bin/env bash
# Builds the zip to upload to Nexus Mods: the mod's game files only, laid out
# from the game folder down, so Vortex, Mod Organizer 2 or a manual install
# (unzip into the game folder) put them in the right place.
#
#   tools/make_release.sh <version>      e.g. tools/make_release.sh 1.0.0
#
# The files come from the last commit (git archive), not from the working
# folder, so the zip matches what is pushed. It is written to dist/ (not kept
# in the repository).
#
# Contents:
#   archive/pc/mod/BluntLeap.archive     perk icons and perk-card videos
#   r6/scripts/BluntLeap/*.reds          the scripts
#   r6/tweaks/BluntLeap/BluntLeap.yaml   the game data
set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "usage: make_release.sh <version>" >&2
  exit 2
fi
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"
if [ -n "$(git status --porcelain -- archive r6)" ]; then
  echo "archive/ or r6/ has uncommitted changes; commit them first" >&2
  exit 1
fi
mkdir -p dist
OUT="dist/BluntLeap-$VERSION.zip"
git archive --format=zip -9 -o "$OUT" HEAD archive/pc/mod/BluntLeap.archive r6/scripts/BluntLeap r6/tweaks/BluntLeap
echo "written: $OUT ($(du -k "$OUT" | cut -f1) KB) from commit $(git rev-parse --short HEAD)"
py -3.10 -I - "$OUT" <<'PY'
import hashlib, sys, zipfile
path = sys.argv[1]
with zipfile.ZipFile(path) as z:
    for info in z.infolist():
        if not info.is_dir():
            print("  %-44s %10d bytes" % (info.filename, info.file_size))
print("sha256", hashlib.sha256(open(path, "rb").read()).hexdigest())
PY
