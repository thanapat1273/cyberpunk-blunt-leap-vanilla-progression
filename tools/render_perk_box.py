"""Renders a perk box as the Body page shows it, at high resolution, from the
game's own UI textures and style values.

    py -3.10 -I tools/render_perk_box.py <perks_new.png> <perks_new.inkatlas.json> <icon.png> <out folder> [name] [scale]

  perks_new.png             the game's 4K perk-screen texture
                            (base\\gameplay\\gui\\fullscreen\\perks\\perks_new.xbm,
                            exported to PNG with WolvenKit), 3848 x 2928
  perks_new.inkatlas.json   its atlas, converted to JSON with WolvenKit
  icon.png                  the perk icon at the game's size (125 x 116), for
                            example art/blunt-leap-icon.png
  name                      file name start (default "perk")
  scale                     times the game's 4K size (default 8)

What the game does, and this script copies (base\\gameplay\\gui\\fullscreen\\
perks\\new_perks.inkwidget and new_perks_style.inkstyle):

  - A perk box is a 133 x 142 canvas. Back to front: cell_outer_bg,
    cell_outer_fg, cell_inner_bg, the icon (125 x 116, centred, 2 lower),
    cell_inner_fg. Each picture is its atlas part at its own size, centred,
    with white texture colour tinted by the style.
  - A bought perk of the "simple" kind (ours) is in the style state "Bought":
      outer_bg  rgb(0.498, 0.380, 0.176)
      outer_fg  Gold at 30%
      inner_bg  rgb(0.173, 0.141, 0.106)
      icon      Gold
      inner_fg  Gold at 50%
      glow      off (GlowOpacity 0)
    Gold is HDR (1.119, 0.844, 0.257); the screen clamps it, as screenshots
    of the game show (brightest gold 255, 217, 67).
  - A bridge wire is the atlas part wire_CPerk1_1_to_CPerk1_3 (60 x 26),
    nine-sliced 16 px at each end, spanning the 161.5 between two boxes,
    centred on the boxes' middle, in PerkWire "Bought" rgb(0.724, 0.518, 0.151).

How it gets sharp at many times the game's size: every texture is enlarged
smoothly, then its edges are made crisp again by thresholding (with 4 x 4
supersampling for smooth edges):
  - box parts are solid shapes: one threshold at half;
  - the icon and the wire (fine strokes, faint jogs and shading): a smooth
    contrast curve (0.12 to 0.62) instead of a threshold, which keeps thin
    and faint strokes whole.
No shape is drawn by hand; every edge comes from the game's pixels.

Writes <name>-box.png, <name>-row.png (box with a wire on each side and the
wire down to the Dash box, as Battering Ram shows while Dash is required) and
<name>-row-no-dash.png, each also as -dark.png on the perk screen's
background colour. The textures are
game art: keep the outputs and the extracted textures out of the repository.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

SS = 4  # supersampling for anti-aliased edges

GOLD = (1.0, 0.844, 0.257)            # MainColors.Gold, clamped as the screen shows it
BOUGHT = {
    "outer_bg": ((0.498, 0.380, 0.176), 1.0),
    "outer_fg": (GOLD, 0.3),
    "inner_bg": ((0.173, 0.141, 0.106), 1.0),
    "icon": (GOLD, 1.0),
    "inner_fg": (GOLD, 0.5),
}
WIRE_BOUGHT = (0.724, 0.518, 0.151)
BACKGROUND = (7, 9, 15)               # the perk screen behind the boxes (sampled from a screenshot)

BOX_W, BOX_H = 133.0, 142.0
INNER_W, INNER_H = 125.0, 116.0
ICON_DROP = 2.0                       # ico_master's top margin
GAP = 161.5                           # between two boxes in a row, where a wire runs
WIRE_SLICE = 16                       # nine-slice ends of the wire
DASH_WIRE = 48.0                      # the wire down to the Dash box (the game's gap between stacked perks)


def parts_of(atlas_png, atlas_json):
    tex = Image.open(atlas_png).convert("RGBA")
    w, h = tex.size
    atlas = json.load(open(atlas_json, encoding="utf-8"))
    out = {}
    for p in atlas["Data"]["RootChunk"]["slots"]["Elements"][0]["parts"]:
        r = p["clippingRectInUVCoords"]
        box = (round(r["Left"] * w), round(r["Top"] * h), round(r["Right"] * w), round(r["Bottom"] * h))
        out[p["partName"]["$value"]] = np.asarray(tex.crop(box), dtype=np.float32)[..., 3] / 255.0
    return out


def enlarge(alpha, factor):
    h, w = alpha.shape
    im = Image.fromarray(alpha.astype(np.float32), mode="F")
    return np.asarray(im.resize((int(round(w * factor)), int(round(h * factor))), Image.BICUBIC)).clip(0, 1)


def shrink(field):
    """SS x SS box average: the supersampled picture back to the output size."""
    h, w = field.shape
    h2, w2 = h // SS, w // SS
    return field[:h2 * SS, :w2 * SS].reshape(h2, SS, w2, SS).mean(axis=(1, 3))


def crisp_solid(alpha, scale):
    big = enlarge(alpha, scale * SS)
    return shrink((big >= 0.5).astype(np.float32))


def crisp_soft(alpha, scale):
    """A smooth contrast curve over the enlarged picture: edges get sharp,
    thin and faint strokes stay whole (a hard threshold breaks them into
    blobs and drops the wire's faint jogs; brightness steps leave bands)."""
    big = enlarge(alpha, scale)
    t = np.clip((big - 0.12) / 0.5, 0, 1)
    return (t * t * (3 - 2 * t)).astype(np.float32)


class Canvas:
    """Premultiplied RGBA in 0..1, in output pixels."""

    def __init__(self, w, h):
        self.rgb = np.zeros((h, w, 3), dtype=np.float32)
        self.a = np.zeros((h, w), dtype=np.float32)

    def put(self, alpha, colour, opacity, x, y):
        """Lays a tinted alpha picture over the canvas, its top left at (x, y)."""
        h, w = alpha.shape
        x0, y0 = int(round(x)), int(round(y))
        cx0, cy0 = max(x0, 0), max(y0, 0)
        cx1, cy1 = min(x0 + w, self.a.shape[1]), min(y0 + h, self.a.shape[0])
        if cx1 <= cx0 or cy1 <= cy0:
            return
        src = alpha[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0] * opacity
        dst_a = self.a[cy0:cy1, cx0:cx1]
        dst_rgb = self.rgb[cy0:cy1, cx0:cx1]
        dst_rgb[:] = np.asarray(colour, dtype=np.float32) * src[..., None] + dst_rgb * (1 - src[..., None])
        dst_a[:] = src + dst_a * (1 - src)

    def image(self, background=None):
        if background is None:
            a = np.clip(self.a, 1e-6, 1)
            rgb = np.where(self.a[..., None] > 0, self.rgb / a[..., None], 0)
            out = np.dstack([rgb, self.a])
            return Image.fromarray(np.clip(np.rint(out * 255), 0, 255).astype(np.uint8), "RGBA")
        bg = np.asarray(background, dtype=np.float32) / 255.0
        rgb = self.rgb + bg * (1 - self.a[..., None])
        return Image.fromarray(np.clip(np.rint(rgb * 255), 0, 255).astype(np.uint8), "RGB")


def box_layers(parts, icon, scale):
    return [
        ("outer_bg", crisp_solid(parts["Perk_Cell_outer_bg"], scale), (0.0, 0.0)),
        ("outer_fg", crisp_solid(parts["Perk_Cell_outer_fg"], scale), (0.0, 0.0)),
        ("inner_bg", crisp_solid(parts["Perk_Cell_inner_bg"], scale), ((BOX_W - INNER_W) / 2, (BOX_H - INNER_H) / 2)),
        ("icon", crisp_soft(icon, scale), ((BOX_W - INNER_W) / 2, (BOX_H - INNER_H) / 2 + ICON_DROP)),
        ("inner_fg", crisp_solid(parts["Perk_Cell_inner_fg"], scale), ((BOX_W - INNER_W) / 2, (BOX_H - INNER_H) / 2)),
    ]


def wire(parts, scale, length):
    """The bridge wire, nine-sliced to the given length (in 4K units)."""
    big = crisp_soft(parts["wire_CPerk1_1_to_CPerk1_3"], scale)
    end = int(round(WIRE_SLICE * scale))
    left, middle, right = big[:, :end], big[:, end:big.shape[1] - end], big[:, big.shape[1] - end:]
    middle_w = int(round(length * scale)) - 2 * end
    stretched = np.asarray(Image.fromarray(middle, mode="F").resize((middle_w, middle.shape[0]), Image.BICUBIC)).clip(0, 1)
    return np.hstack([left, stretched, right])


def wire_down(parts, scale, length):
    """The wire down to the Dash box: wire_CPerk2_1_to_CPerk2_3 (28 x 59),
    nine-sliced 16 at each end, as the mod draws it (BluntLeap_PerkScreen.reds)."""
    big = crisp_soft(parts["wire_CPerk2_1_to_CPerk2_3"], scale)
    end = int(round(WIRE_SLICE * scale))
    top, middle, bottom = big[:end], big[end:big.shape[0] - end], big[big.shape[0] - end:]
    middle_h = max(1, int(round(length * scale)) - 2 * end)
    squeezed = np.asarray(Image.fromarray(middle, mode="F").resize((middle.shape[1], middle_h), Image.BICUBIC)).clip(0, 1)
    return np.vstack([top, squeezed, bottom])


def render(parts, icon, scale, margin_x, margin_y, with_wires, with_dash=False):
    w = BOX_W + 2 * margin_x + (2 * GAP if with_wires else 0)
    h = BOX_H + 2 * margin_y
    canvas = Canvas(int(round(w * scale)), int(round(h * scale)))
    box_x = margin_x + (GAP if with_wires else 0)
    box_y = margin_y
    if with_wires:
        line = wire(parts, scale, GAP)
        wy = box_y + BOX_H / 2 - parts["wire_CPerk1_1_to_CPerk1_3"].shape[0] / 2
        canvas.put(line, WIRE_BOUGHT, 1.0, (box_x - GAP) * scale, wy * scale)
        canvas.put(line, WIRE_BOUGHT, 1.0, (box_x + BOX_W) * scale, wy * scale)
    if with_dash:
        # 48 down from the box's bottom edge, centred under it (Dash bought: gold).
        down = wire_down(parts, scale, DASH_WIRE)
        canvas.put(down, WIRE_BOUGHT, 1.0, (box_x + BOX_W / 2 - parts["wire_CPerk2_1_to_CPerk2_3"].shape[1] / 2) * scale, (box_y + BOX_H) * scale)
    for name, alpha, (dx, dy) in box_layers(parts, icon, scale):
        colour, opacity = BOUGHT[name]
        canvas.put(alpha, colour, opacity, (box_x + dx) * scale, (box_y + dy) * scale)
    return canvas


def main():
    if len(sys.argv) < 5:
        sys.exit(__doc__)
    atlas_png, atlas_json, icon_png, out_dir = sys.argv[1:5]
    name = sys.argv[5] if len(sys.argv) > 5 else "perk"
    scale = float(sys.argv[6]) if len(sys.argv) > 6 else 8.0
    parts = parts_of(atlas_png, atlas_json)
    icon = np.asarray(Image.open(icon_png).convert("RGBA"), dtype=np.float32)[..., 3] / 255.0
    os.makedirs(out_dir, exist_ok=True)
    jobs = [("box", render(parts, icon, scale, 6.0, 6.0, False)),
            ("row", render(parts, icon, scale, 0.0, 49.0, True, True)),
            ("row-no-dash", render(parts, icon, scale, 0.0, 49.0, True))]
    for kind, canvas in jobs:
        for suffix, bg in (("", None), ("-dark", BACKGROUND)):
            path = os.path.join(out_dir, "%s-%s%s.png" % (name, kind, suffix))
            canvas.image(bg).save(path, optimize=True)
            print(path, canvas.a.shape[1], "x", canvas.a.shape[0])


main()
