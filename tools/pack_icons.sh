#!/usr/bin/env bash
# Packs the two perk icons and the two perk-card videos into
# archive/pc/mod/BluntLeap.archive.
#
#   tools/pack_icons.sh "<WolvenKit.CLI.exe>" "<template folder>" [work folder]
#
# The template folder holds two files unbundled from the game
# (basegame_1_engine.archive): perks_icons.xbm and perks_icons.inkatlas.json
# (the .inkatlas converted to JSON with "WolvenKit.CLI convert s"). They give
# the texture settings and the atlas layout the game itself uses; they are
# game files and are not kept in this repository.
#
# What it does:
#   1. Places the icons side by side on one texture, each in a cell whose
#      width and height are divisible by 4 (the texture compression works on
#      4 x 4 blocks, so no block is shared between two icons):
#        art/blunt-leap-icon.png     part "blunt_leap"
#        art/stronger-leap-icon.png  part "stronger_leap"
#   2. Imports it over a copy of the game's perk texture ("import --keep"),
#      so the new texture has the game's own settings.
#   3. Writes an atlas with those two parts, for all three resolution
#      slots, pointing at bluntleap\gui\icons\blunt_leap_icons.xbm.
#   4. Adds the videos in art/video/ (made by tools/make_videos.py) under
#      bluntleap\movies\.
#   5. Packs everything into the archive.
#
# The game data names the icons in r6/tweaks/BluntLeap/BluntLeap.yaml
# (UIIcon.BluntLeap_Leap, UIIcon.BluntLeap_Stronger), and the videos in the
# two perk records (binkPath).
#
# If WolvenKit needs a private .NET, set DOTNET_ROOT before running.
set -euo pipefail

WK="${1:-}"
TEMPLATE="${2:-}"
if [ ! -f "$WK" ] || [ ! -f "$TEMPLATE/perks_icons.xbm" ] || [ ! -f "$TEMPLATE/perks_icons.inkatlas.json" ]; then
  echo "usage: pack_icons.sh <WolvenKit.CLI.exe> <template folder> [work folder]" >&2
  exit 2
fi
HERE="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${3:-$(mktemp -d)}"
SRC="$WORK/src"
PACK="$WORK/pack/BluntLeap/bluntleap/gui/icons"
rm -rf "$SRC" "$WORK/pack" "$WORK/out"
mkdir -p "$SRC" "$PACK" "$WORK/out"

cp "$TEMPLATE/perks_icons.xbm" "$SRC/blunt_leap_icons.xbm"

ART="$(cygpath -w "$HERE/art")" \
TEMPLATE_JSON="$(cygpath -w "$TEMPLATE/perks_icons.inkatlas.json")" \
OUT_DIR="$(cygpath -w "$SRC")" \
py -3.10 - <<PY
import copy, json, os
from PIL import Image

icons = [
    ("blunt_leap", "blunt-leap-icon.png"),
    ("stronger_leap", "stronger-leap-icon.png"),
]

def up4(n):
    return (n + 3) // 4 * 4

images = [(part, Image.open(os.path.join(os.environ["ART"], name)).convert("RGBA")) for part, name in icons]
cells = [up4(im.width) for _, im in images]
width = sum(cells)
height = up4(max(im.height for _, im in images))
sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
rects = []
x = 0
for (part, im), cell in zip(images, cells):
    sheet.paste(im, (x, 0))
    rects.append((part, x / width, 0.0, (x + im.width) / width, im.height / height))
    x += cell
sheet.save(os.path.join(os.environ["OUT_DIR"], "blunt_leap_icons.png"))

atlas = json.load(open(os.environ["TEMPLATE_JSON"], encoding="utf-8"))
# Built from pieces: a shell can turn a backslash followed by a letter into a
# control character, which silently breaks the path.
texture = chr(92).join(["bluntleap", "gui", "icons", "blunt_leap_icons.xbm"])
slots = atlas["Data"]["RootChunk"]["slots"]["Elements"]
template_part = copy.deepcopy(slots[0]["parts"][0])
parts = []
for name, left, top, right, bottom in rects:
    part = copy.deepcopy(template_part)
    part["partName"]["\$value"] = name
    part["clippingRectInUVCoords"].update({"Left": left, "Top": top, "Right": right, "Bottom": bottom})
    parts.append(part)
for slot in slots:
    slot["texture"]["DepotPath"]["\$value"] = texture
    slot["parts"] = copy.deepcopy(parts)
json.dump(atlas, open(os.path.join(os.environ["OUT_DIR"], "blunt_leap_icons.inkatlas.json"), "w", encoding="utf-8"), indent=2)
print("texture", (width, height), "parts", [(r[0], round(r[1] * width), round(r[3] * width)) for r in rects])
PY

"$WK" import "$(cygpath -w "$SRC/blunt_leap_icons.png")" -o "$(cygpath -w "$SRC")" --keep
"$WK" convert d "$(cygpath -w "$SRC/blunt_leap_icons.inkatlas.json")"
cp "$SRC/blunt_leap_icons.xbm" "$SRC/blunt_leap_icons.inkatlas" "$PACK/"
mkdir -p "$WORK/pack/BluntLeap/bluntleap/movies"
cp "$HERE"/art/video/*.bk2 "$WORK/pack/BluntLeap/bluntleap/movies/"
"$WK" pack "$(cygpath -w "$WORK/pack/BluntLeap")" -o "$(cygpath -w "$WORK/out")"

mkdir -p "$HERE/archive/pc/mod"
cp "$WORK/out/BluntLeap.archive" "$HERE/archive/pc/mod/BluntLeap.archive"
echo "written: archive/pc/mod/BluntLeap.archive"
