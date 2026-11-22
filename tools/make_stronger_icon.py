"""Build the Stronger leap perk icon from two of the game's perk icons:
"In Charge" with its bullet replaced by the middle fist of "Kinetic
Absorption".

    py -3.10 tools/make_stronger_icon.py <in_charge.png> <kinetic_absorption.png> <out folder>

The inputs are cut from the game's own atlas
(base\\gameplay\\gui\\common\\icons\\perks\\perks_icons.xbm), both 125 x 116 px:
    in_charge.png            part "engineering_area_07_perk1"
    kinetic_absorption.png   part "brawling_area_02_perk2"
They are game art and are not kept in this repository; extract them from your
own copy of the game.

Step 1 takes the bullet out of In Charge (the BULLET outline: the capsule only;
the lightning and the white trail behind it stay).
Step 2 cuts the middle fist out of Kinetic Absorption (the connected shape
through FIST_SEED, cut at the wrist), mirrors it left to right so it points the
way the bullet did, moves it by MOVE, and puts it in front with a thin dark rim.
At its back end there is no rim, so the trail runs straight into the wrist.

Pixels are only copied, mirrored and moved by whole pixels. Nothing is resized
or turned, so every pixel is one of the game's own.

Out folder gets stronger-leap-icon.png (the icon at the game's size, same pixel
format as the game's: the brightness in all four channels) and
stronger-leap-icon-preview.png (4x on dark).

Needs numpy and Pillow.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BG = (16, 18, 26)

# In Charge: the bullet (the capsule, without the white trail behind it)
BULLET = [(52.5, 57.5), (57, 53.5), (64, 53), (73, 55), (85, 61.5), (98, 73.5), (107, 86), (111.5, 100),
          (101, 101), (88, 99), (75, 95), (65, 89.5), (58, 83.5), (53.5, 75), (51.5, 66)]

# Kinetic Absorption: a pixel inside the middle fist, and its arm's direction
FIST_SEED = (40, 85)
ARM_TO = (108, 25)          # towards the elbow
WRIST = 32.0                # the wrist cut, in pixels from the seed along the arm
OVERLAP = 9.5               # the back end of the fist, where the trail shows through
GAP = 1                     # dark rim around the fist where it crosses other lines
MOVE = (-12, -3)            # where the mirrored fist goes, in whole pixels


def load(path):
    return np.asarray(Image.open(path).convert("RGBA"))[..., 3].astype(np.float32)


def polygon_mask(points, shape):
    h, w = shape
    ss = 4
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).polygon([(x * ss, y * ss) for x, y in points], fill=255)
    return np.asarray(im.resize((w, h), Image.BOX), dtype=np.float32) / 255.0 >= 0.5


def grow(mask, radius):
    if radius <= 0:
        return mask
    im = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(radius * 2 + 1))
    return np.asarray(im) > 127


def shrink(mask, radius):
    im = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(radius * 2 + 1))
    return np.asarray(im) > 127


def flood(passable, seeds):
    """Pixels reachable from the seeds through passable pixels (4 neighbours)."""
    h, w = passable.shape
    seen = np.zeros((h, w), dtype=bool)
    stack = [s for s in seeds if passable[s[1], s[0]]]
    for x, y in stack:
        seen[y, x] = True
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and passable[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((nx, ny))
    return seen


def filled(mask):
    """The mask with every hole in it closed (its silhouette)."""
    h, w = mask.shape
    border = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    return ~flood(~mask, border)


def shifted(a, dx, dy):
    out = np.zeros_like(a)
    h, w = a.shape
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = a[ys0:ys1, xs0:xs1]
    return out


def to_icon(alpha):
    """The game's pixel format: the brightness in all four channels."""
    a = np.clip(np.rint(alpha), 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([a, a, a, a]), mode="RGBA")


def on_dark(alpha, scale):
    h, w = alpha.shape
    a = Image.fromarray(np.clip(np.rint(alpha), 0, 255).astype(np.uint8)).resize((w * scale, h * scale), Image.LANCZOS)
    out = Image.new("RGB", a.size, BG)
    out.paste(Image.new("RGB", a.size, (255, 255, 255)), (0, 0), a)
    return out


def build(charge_path, kinetic_path, out_dir):
    charge, kinetic = load(charge_path), load(kinetic_path)
    if charge.shape != kinetic.shape:
        sys.exit("the two icons differ in size: %s and %s" % (charge.shape, kinetic.shape))
    h, w = charge.shape

    # Step 1: In Charge without its bullet.
    bullet = polygon_mask(BULLET, charge.shape)
    base = np.where(bullet, 0.0, charge)

    # Step 2: the middle fist of Kinetic Absorption, cut at the wrist.
    arm_core = flood(kinetic >= 60, [FIST_SEED])
    others = (kinetic >= 60) & ~arm_core
    arm = (kinetic > 0) & grow(arm_core, 2) & ~grow(others, 1)
    yy, xx = np.mgrid[0:h, 0:w]
    ax, ay = ARM_TO[0] - FIST_SEED[0], ARM_TO[1] - FIST_SEED[1]
    along = ((xx - FIST_SEED[0]) * ax + (yy - FIST_SEED[1]) * ay) / (ax * ax + ay * ay) ** 0.5
    fist = arm & (along <= WRIST)

    # Mirrored, moved, and in front: a dark rim around it, except at its back
    # end, where the trail is left as it is and runs into the wrist.
    pixels = shifted(np.where(fist, kinetic, 0.0)[:, ::-1], *MOVE)
    shape = shifted(filled(shrink(grow(fist, 3), 3))[:, ::-1], *MOVE)
    behind = shifted((along > WRIST - OVERLAP)[:, ::-1], *MOVE)
    rim = (shape | grow(shape, GAP)) & ~behind
    final = np.maximum(np.where(rim, 0.0, base), pixels)

    print("step 1: %d pixels of the bullet taken out" % int((bullet & (charge > 0)).sum()))
    print("step 2: %d pixels of the fist put in" % int((pixels > 0).sum()))

    os.makedirs(out_dir, exist_ok=True)
    to_icon(final).save(os.path.join(out_dir, "stronger-leap-icon.png"))
    on_dark(final, 4).save(os.path.join(out_dir, "stronger-leap-icon-preview.png"), optimize=True)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2], sys.argv[3])
