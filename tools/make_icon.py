"""Build the Blunt leap perk icon from the game's Flash and Thunderclap icon:
the katana is taken out and a baseball bat is put in. Nothing else changes.

    py -3.10 tools/make_icon.py <flash_thunderclap.png> <out folder> [work folder]

The input is the perk icon cut from the game's own atlas
(base\\gameplay\\gui\\common\\icons\\perks\\perks_icons.xbm, part
"kenjutsu_area_09_perk2", 125 x 116 px). It is game art and is not kept in
this repository; extract it from your own copy of the game.

Step 1, remove the katana. KATANA_ROWS lists, for every pixel row, the span
of pixels that belong to the katana: the blade, the faint line trailing its
lower side, and the round guard at the hand. Every pixel outside those spans
is copied from the game's icon untouched.

Step 2, add the bat. It is drawn as a shape, with a dark gap where the open
hand lies over it, and merged into the icon.

Out folder gets blunt-leap-icon.png (the icon at the game's size, same pixel
format as the game's), blunt-leap-icon.svg (the same picture as outlines) and
blunt-leap-icon-preview.png. With a work folder, the in-between pictures are
written there too (they contain unchanged game art, so keep them out of the
repository).

Needs numpy and Pillow.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

K = 8  # working scale for the bat and for tracing

# --- step 1: the katana, row by row (first pixel, last pixel) ----------------

KATANA_ROWS = {
    # the guard: an oval around the blade's root, below the end of the forearm
    47: (98, 100),
    **{y: (88, 106) for y in range(48, 64)},
    64: (88, 104), 65: (87, 102), 66: (87, 99), 67: (86, 99),
    # the blade with the faint line along its lower side
    68: (84, 97), 69: (83, 96), 70: (82, 95), 71: (81, 95), 72: (80, 94),
    73: (79, 93), 74: (78, 92), 75: (76, 92), 76: (75, 91), 77: (73, 90),
    78: (72, 89), 79: (70, 88), 80: (66, 87), 81: (66, 86), 82: (66, 85),
    83: (65, 84), 84: (63, 83), 85: (61, 82), 86: (59, 81), 87: (57, 79),
    88: (55, 79), 89: (53, 77), 90: (51, 77), 91: (49, 77), 92: (46, 75),
    93: (44, 75), 94: (42, 75), 95: (39, 75), 96: (30, 70), 97: (30, 68),
    98: (30, 67), 99: (27, 66), 100: (24, 63), 101: (22, 62), 102: (18, 60),
    103: (17, 59), 104: (10, 57), 105: (10, 55), 106: (10, 52), 107: (10, 50),
    108: (20, 46),
}

# --- step 2: the bat ----------------------------------------------------------

KNOB = (102.0, 52.5)          # centre of the knob, just under the forearm's end
DIRECTION = (-0.8045, 0.594)  # towards the barrel, unit length
BAT_LENGTH = 95.0             # from the knob's outer end to the barrel's end
KNOB_RADIUS = 3.3
# The open left hand (palm and fingers) lies over the bat.
FRONT = [(36, 69), (76, 69), (76, 84.5), (36, 84.5)]
GAP = 1.3                     # dark gap between the hand and the bat


def bat_radius(s):
    """Half-width of the bat at distance s from the knob's outer end."""
    length, knob = BAT_LENGTH, KNOB_RADIUS
    if s < 0 or s > length:
        return 0.0
    if s < knob:                                   # knob, rounded
        return knob * math.sqrt(max(0.0, 1 - ((knob - s) / knob) ** 2))
    if s < knob + 0.9:
        return knob
    if s < knob + 2.2:                             # knob to handle
        return knob + (1.75 - knob) * (s - knob - 0.9) / 1.3
    taper0, taper1, cap = length - 57, length - 25, length - 4
    if s < taper0:                                 # handle
        return 1.75 + 0.35 * (s - knob - 2.2) / (taper0 - knob - 2.2)
    if s < taper1:                                 # taper
        u = (s - taper0) / (taper1 - taper0)
        u = u * u * (3 - 2 * u)
        return 2.1 + (5.3 - 2.1) * u
    if s < cap:                                    # barrel
        return 5.3 + 0.2 * (s - taper1) / (cap - taper1)
    return 5.5 * math.sqrt(max(0.0, 1 - ((s - cap) / 4.0) ** 2))   # end


def bat_axis():
    dx, dy = DIRECTION
    return KNOB[0] - dx * KNOB_RADIUS, KNOB[1] - dy * KNOB_RADIUS, dx, dy


def bat_outline(step=0.25):
    ox, oy, dx, dy = bat_axis()
    nx, ny = -dy, dx
    n = int(round(BAT_LENGTH / step))
    up, down = [], []
    for i in range(n + 1):
        s = BAT_LENGTH * i / n
        r = bat_radius(s)
        cx, cy = ox + dx * s, oy + dy * s
        up.append((cx + nx * r, cy + ny * r))
        down.append((cx - nx * r, cy - ny * r))
    return up + down[::-1]


def bat_shadow_line(offset=0.42, width=0.55, step=0.5):
    """A thin dark line along the barrel's lower side, so the bat is not one
    flat shape (the katana had its serrated line)."""
    ox, oy, dx, dy = bat_axis()
    nx, ny = -dy, dx
    s0, s1 = BAT_LENGTH - 50, BAT_LENGTH - 8
    n = int(round((s1 - s0) / step))
    up, down = [], []
    for i in range(n + 1):
        u = i / n
        s = s0 + (s1 - s0) * u
        half = width * math.sin(math.pi * u) ** 0.6     # pointed at both ends
        c = bat_radius(s) * offset
        cx, cy = ox + dx * s, oy + dy * s
        up.append((cx + nx * (c + half), cy + ny * (c + half)))
        down.append((cx + nx * (c - half), cy + ny * (c - half)))
    return up + down[::-1]


# --- raster helpers -----------------------------------------------------------

def polygon_field(points, size):
    """Anti-aliased 0..1 field of a polygon given in source pixels."""
    w, h = size
    ss = 3
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).polygon([(x * K * ss, y * K * ss) for x, y in points], fill=255)
    return np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.float32) / 255.0


def dilate(mask, radius):
    """Grow a true/false area by radius source pixels; returns a 0..1 field."""
    im = Image.fromarray((mask * 255).astype(np.uint8))
    size = int(round(radius * K)) * 2 + 1
    im = im.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.GaussianBlur(K * 0.15))
    return np.asarray(im, dtype=np.float32) / 255.0


def enlarge(alpha):
    """The icon at K times its size (0..1), smoothly interpolated."""
    h, w = alpha.shape
    im = Image.fromarray(alpha.astype(np.float32) / 255.0, mode="F")
    return np.asarray(im.resize((w * K, h * K), Image.BICUBIC)).clip(0, 1)


def to_icon(alpha):
    """The game's pixel format: the brightness in all four channels."""
    a = np.clip(np.rint(alpha), 0, 255).astype(np.uint8)
    return Image.fromarray(np.dstack([a, a, a, a]), mode="RGBA")


def on_dark(alpha, scale):
    h, w = alpha.shape
    a = Image.fromarray(np.clip(np.rint(alpha), 0, 255).astype(np.uint8)).resize((w * scale, h * scale), Image.LANCZOS)
    out = Image.new("RGB", a.size, (16, 18, 26))
    out.paste(Image.new("RGB", a.size, (255, 255, 255)), (0, 0), a)
    return out


# --- tracing (marching squares, then Douglas-Peucker, then curves) ------------

T, R, B, L = 0, 1, 2, 3
CASES = {
    1: [(L, B)], 2: [(B, R)], 3: [(L, R)], 4: [(T, R)], 6: [(T, B)], 7: [(T, L)],
    8: [(T, L)], 9: [(T, B)], 11: [(T, R)], 12: [(L, R)], 13: [(B, R)], 14: [(L, B)],
}


def trace(field, level):
    f = np.pad(field, 1)
    inside = f >= level
    code = (inside[:-1, :-1] * 8 + inside[:-1, 1:] * 4 + inside[1:, 1:] * 2 + inside[1:, :-1] * 1)
    ys, xs = np.nonzero((code != 0) & (code != 15))

    def point(x, y, edge):
        if edge == T:
            a, b = f[y, x], f[y, x + 1]
            return ("h", x, y), (x + (level - a) / (b - a), float(y))
        if edge == B:
            a, b = f[y + 1, x], f[y + 1, x + 1]
            return ("h", x, y + 1), (x + (level - a) / (b - a), float(y + 1))
        if edge == L:
            a, b = f[y, x], f[y + 1, x]
            return ("v", x, y), (float(x), y + (level - a) / (b - a))
        a, b = f[y, x + 1], f[y + 1, x + 1]
        return ("v", x + 1, y), (float(x + 1), y + (level - a) / (b - a))

    position, segments, at = {}, [], {}
    for x, y in zip(xs.tolist(), ys.tolist()):
        c = int(code[y, x])
        if c in (5, 10):
            centre = (f[y, x] + f[y, x + 1] + f[y + 1, x] + f[y + 1, x + 1]) / 4 >= level
            if c == 5:
                pairs = [(T, L), (B, R)] if centre else [(T, R), (L, B)]
            else:
                pairs = [(T, R), (L, B)] if centre else [(T, L), (B, R)]
        else:
            pairs = CASES[c]
        for e0, e1 in pairs:
            k0, p0 = point(x, y, e0)
            k1, p1 = point(x, y, e1)
            position[k0], position[k1] = p0, p1
            index = len(segments)
            segments.append((k0, k1))
            at.setdefault(k0, []).append(index)
            at.setdefault(k1, []).append(index)

    used, loops = [False] * len(segments), []
    for first in range(len(segments)):
        if used[first]:
            continue
        used[first] = True
        start, key = segments[first]
        loop = [position[start]]
        while key != start:
            loop.append(position[key])
            following = [i for i in at[key] if not used[i]]
            if not following:
                break
            used[following[0]] = True
            a, b = segments[following[0]]
            key = b if a == key else a
        # back from the padded, enlarged grid to source pixels; a sample at
        # enlarged pixel i sits at (i + 0.5) / K
        loops.append([((px - 0.5) / K, (py - 0.5) / K) for px, py in loop])
    return loops


def simplify(loop, eps):
    """Douglas-Peucker on a closed loop."""
    n = len(loop)
    if n < 8:
        return loop
    far = max(range(n), key=lambda i: (loop[i][0] - loop[0][0]) ** 2 + (loop[i][1] - loop[0][1]) ** 2)
    keep = [False] * n
    keep[0] = keep[far] = True
    stack = [(0, far), (far, n)]
    while stack:
        i0, i1 = stack.pop()
        ax, ay = loop[i0]
        bx, by = loop[i1 % n]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1e-9
        worst, at = 0.0, -1
        for i in range(i0 + 1, i1):
            px, py = loop[i]
            d = abs((px - ax) * dy - (py - ay) * dx) / length
            if d > worst:
                worst, at = d, i
        if worst > eps:
            keep[at] = True
            stack.append((i0, at))
            stack.append((at, i1))
    return [p for p, k in zip(loop, keep) if k]


def area(loop):
    return abs(sum(loop[i][0] * loop[(i + 1) % len(loop)][1] - loop[(i + 1) % len(loop)][0] * loop[i][1]
                   for i in range(len(loop)))) / 2


def smooth(loop, corner_degrees=58.0):
    """Path data for a closed loop: a curve through the midpoints of its
    sides, with real corners (sharp tips, cut ends) kept sharp."""
    n = len(loop)

    def mid(i):
        (ax, ay), (bx, by) = loop[i % n], loop[(i + 1) % n]
        return (ax + bx) / 2, (ay + by) / 2

    def is_corner(i):
        (ax, ay), (bx, by), (cx, cy) = loop[(i - 1) % n], loop[i % n], loop[(i + 1) % n]
        turn = math.atan2(cy - by, cx - bx) - math.atan2(by - ay, bx - ax)
        turn = abs((turn + math.pi) % (2 * math.pi) - math.pi)
        return math.degrees(turn) > corner_degrees

    out = ["M%.2f %.2f" % mid(0)]
    for i in range(1, n + 1):
        x, y = loop[i % n]
        mx, my = mid(i)
        if is_corner(i):
            out.append("L%.2f %.2f L%.2f %.2f" % (x, y, mx, my))
        else:
            out.append("Q%.2f %.2f %.2f %.2f" % (x, y, mx, my))
    return "".join(out) + "Z"


def to_path(field, level, eps=0.06, min_area=0.12):
    parts = []
    for loop in trace(field, level):
        loop = simplify(loop, eps)
        if len(loop) >= 3 and area(loop) >= min_area:
            parts.append(smooth(loop))
    return "".join(parts)


# The game's icon has soft edges and half-bright lines. The outlines keep them
# as five brightness steps, each drawn over the one before.
STEPS = [(0.10, 0.20), (0.30, 0.40), (0.50, 0.60), (0.70, 0.80), (0.90, 1.00)]


def to_svg(field, w, h):
    layers, shown_before = [], 0.0
    for level, shown in STEPS:
        opacity = (shown - shown_before) / (1 - shown_before)
        shown_before = shown
        layers.append('  <path fill="#fff" fill-opacity="%.3f" fill-rule="evenodd" d="%s"/>\n'
                      % (opacity, to_path(field, level)))
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n'
        '  <title>Blunt leap</title>\n'
        '  <!-- Cyberpunk 2077\'s Flash and Thunderclap perk icon (CD PROJEKT RED) with the\n'
        '       katana replaced by a baseball bat. Built by tools/make_icon.py. -->\n'
        '%s</svg>\n' % (w, h, w * 4, h * 4, "".join(layers))
    )


# --- build --------------------------------------------------------------------

def build(src, out_dir, work_dir=None):
    original = np.asarray(Image.open(src).convert("RGBA"))[..., 3].astype(np.float32)
    h, w = original.shape
    size = (w * K, h * K)

    # Step 1: take the katana out. Every other pixel stays as the game has it.
    removed = np.zeros((h, w), dtype=bool)
    for y, (x0, x1) in KATANA_ROWS.items():
        removed[y, x0:x1 + 1] = True
    kept = np.where(removed, 0.0, original)
    print("step 1: %d pixels taken out, %d left unchanged" % (int((removed & (original > 0)).sum()),
                                                              int((~removed & (original > 0)).sum())))

    # Step 2: the bat, with a gap where the open hand lies over it.
    kept_big = enlarge(kept)
    front = kept_big * polygon_field(FRONT, size)
    bat_big = polygon_field(bat_outline(), size) * (1 - polygon_field(bat_shadow_line(), size))
    bat_big = bat_big * (1 - dilate(front >= 0.3, GAP))
    bat = bat_big.reshape(h, K, w, K).mean(axis=(1, 3)) * 255.0
    final = np.maximum(kept, bat)
    changed = (np.rint(final) != np.rint(original)) & ~removed
    print("step 2: the bat touches %d pixels outside the katana's place" % int(changed.sum()))

    os.makedirs(out_dir, exist_ok=True)
    to_icon(final).save(os.path.join(out_dir, "blunt-leap-icon.png"))
    on_dark(final, 4).save(os.path.join(out_dir, "blunt-leap-icon-preview.png"), optimize=True)
    svg = to_svg(np.maximum(kept_big, bat_big), w, h)
    with open(os.path.join(out_dir, "blunt-leap-icon.svg"), "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)
    print("svg: %d bytes" % len(svg))

    if work_dir:
        os.makedirs(work_dir, exist_ok=True)
        to_icon(kept).save(os.path.join(work_dir, "step1-katana-removed.png"))
        scale, pad = 5, 20
        marked = on_dark(original, scale).convert("RGB")
        red = Image.fromarray((removed * 150).astype(np.uint8)).resize(marked.size, Image.NEAREST)
        marked.paste(Image.new("RGB", marked.size, (255, 40, 40)), (0, 0), red)
        panels = [on_dark(original, scale), marked, on_dark(kept, scale), on_dark(final, scale)]
        sheet = Image.new("RGB", (pad + (w * scale + pad) * len(panels), h * scale + pad * 2), (16, 18, 26))
        for i, panel in enumerate(panels):
            sheet.paste(panel, (pad + (w * scale + pad) * i, pad))
        sheet.save(os.path.join(work_dir, "steps.png"))
        for name, panel in (("1-original", panels[0]), ("2-katana-marked", marked),
                            ("3-katana-removed", panels[2]), ("4-with-bat", panels[3])):
            panel.save(os.path.join(work_dir, name + ".png"))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
