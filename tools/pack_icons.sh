#!/usr/bin/env bash
# Packs the perk icon into archive/pc/mod/BluntLeap.archive.
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
#   1. Pads art/blunt-leap-icon.png to a width and height divisible by 4
#      (the texture compression needs that).
#   2. Imports it over a copy of the game's perk texture ("import --keep"),
#      so the new texture has the game's own settings.
#   3. Writes an atlas with one part, "blunt_leap", for all three resolution
#      slots, pointing at bluntleap\gui\icons\blunt_leap_icons.xbm.
#   4. Packs both into the archive.
#
# The game data names the icon in r6/tweaks/BluntLeap/BluntLeap.yaml
# (UIIcon.BluntLeap_Leap).
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

ICON="$(cygpath -w "$HERE/art/blunt-leap-icon.png")" \
TEMPLATE_JSON="$(cygpath -w "$TEMPLATE/perks_icons.inkatlas.json")" \
OUT_DIR="$(cygpath -w "$SRC")" \
py -3.10 - <<PY
import copy, json, os
from PIL import Image

icon = Image.open(os.environ["ICON"]).convert("RGBA")
width = (icon.width + 3) // 4 * 4
height = (icon.height + 3) // 4 * 4
padded = Image.new("RGBA", (width, height), (0, 0, 0, 0))
padded.paste(icon, (0, 0))
padded.save(os.path.join(os.environ["OUT_DIR"], "blunt_leap_icons.png"))

atlas = json.load(open(os.environ["TEMPLATE_JSON"], encoding="utf-8"))
# Built from pieces: a shell can turn a backslash followed by a letter into a
# control character, which silently breaks the path.
texture = chr(92).join(["bluntleap", "gui", "icons", "blunt_leap_icons.xbm"])
slots = atlas["Data"]["RootChunk"]["slots"]["Elements"]
part = copy.deepcopy(slots[0]["parts"][0])
part["partName"]["\$value"] = "blunt_leap"
part["clippingRectInUVCoords"].update({"Left": 0.0, "Top": 0.0, "Right": icon.width / width, "Bottom": icon.height / height})
for slot in slots:
    slot["texture"]["DepotPath"]["\$value"] = texture
    slot["parts"] = [copy.deepcopy(part)]
json.dump(atlas, open(os.path.join(os.environ["OUT_DIR"], "blunt_leap_icons.inkatlas.json"), "w", encoding="utf-8"), indent=2)
print("icon", icon.size, "padded to", (width, height))
PY

"$WK" import "$(cygpath -w "$SRC/blunt_leap_icons.png")" -o "$(cygpath -w "$SRC")" --keep
"$WK" convert d "$(cygpath -w "$SRC/blunt_leap_icons.inkatlas.json")"
cp "$SRC/blunt_leap_icons.xbm" "$SRC/blunt_leap_icons.inkatlas" "$PACK/"
"$WK" pack "$(cygpath -w "$WORK/pack/BluntLeap")" -o "$(cygpath -w "$WORK/out")"

mkdir -p "$HERE/archive/pc/mod"
cp "$WORK/out/BluntLeap.archive" "$HERE/archive/pc/mod/BluntLeap.archive"
echo "written: archive/pc/mod/BluntLeap.archive"
