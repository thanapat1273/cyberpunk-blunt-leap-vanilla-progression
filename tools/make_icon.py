"""Build the Blunt leap perk icon: the game's Flash and Thunderclap icon,
redrawn as vector outlines, with the katana replaced by a baseball bat.

    py -3.10 tools/make_icon.py <flash_thunderclap.png> <out.svg> [preview.png]

The input is the perk icon cut from the game's own atlas
(base\\gameplay\\gui\\common\\icons\\perks\\perks_icons.xbm, part
"kenjutsu_area_09_perk2", 125 x 116 px). It is game art and is not kept in
this repository; extract it from your own copy of the game.

How it works: the icon is enlarged, the katana is cut out with a hand-placed
outline, a bat is drawn along the same line from the same fist, and the
result is traced back into outlines (marching squares). All coordinates below
are in the source icon's pixels.

Needs numpy and Pillow.
"""
import math
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

K = 8  # working scale

# --- hand-placed geometry (source pixels) -----------------------------------

# Everything that belongs to the katana: both blade bands, the serrated edge
# and the faint ghost line along its lower side. The strokes at the hip, below
# the blade, go too: with the blade gone they are left hanging in the air.
KATANA = [
    (96, 54), (101.8, 54), (102, 58), (101.5, 60), (100.5, 62), (98.8, 64),
    (98.5, 66), (98, 68), (97, 70), (96, 72), (94, 76), (93, 80), (92, 86),
    (92.5, 100), (93, 113), (8, 113), (8, 104), (12, 106), (15, 104),
    (20, 102), (26, 100), (33, 98), (37, 96), (43, 94), (47, 92), (52, 90),
    (56, 88), (60, 86), (63, 84), (66, 82), (70, 80), (74, 78), (77, 76),
    (80, 74), (82, 72), (85, 70), (87, 68), (89, 66), (91, 64), (92, 62),
    (94, 60), (95, 58), (96, 56),
]

# The left hand (palm and fingers). It stays in front of the bat.
FRONT = [(38, 69), (75, 69), (75, 84.5), (38, 84.5)]

# The bat: a straight line through the middle of the gripping fist.
FIST = (101.0, 56.0)
DIRECTION = (-0.806, 0.592)   # towards the barrel, unit length
KNOB_BEHIND_FIST = 12.0       # the knob end sits this far behind the fist
BAT_LENGTH = 97.0
HIDDEN_BY_FIST = (4.6, 16.5)  # stretch of the bat (from the knob end) not drawn
GAP = 1.5                     # dark gap between overlapping shapes
SMOOTH = 0.17                 # blur of the source art before tracing
SOLID = 0.34                  # coverage from which a pixel counts as white
FAINT = 0.13                  # coverage from which it counts as faint


def bat_radius(s):
    """Half-width of the bat at distance s from the knob end."""
    if s < 0 or s > BAT_LENGTH:
        return 0.0
    if s < 3.3:                                   # knob, rounded
        return 3.3 * math.sqrt(max(0.0, 1 - ((3.3 - s) / 3.3) ** 2))
    if s < 4.2:
        return 3.3
    if s < 5.5:                                   # knob to handle
        return 3.3 + (1.75 - 3.3) * (s - 4.2) / 1.3
    if s < 40:                                    # handle
        return 1.75 + (2.1 - 1.75) * (s - 5.5) / 34.5
    if s < 72:                                    # taper
        u = (s - 40) / 32.0
        u = u * u * (3 - 2 * u)
        return 2.1 + (5.3 - 2.1) * u
    if s < 93:                                    # barrel
        return 5.3 + 0.2 * (s - 72) / 21.0
    return 5.5 * math.sqrt(max(0.0, 1 - ((s - 93) / 4.0) ** 2))   # end


def bat_outline(s0, s1, step=0.25):
    dx, dy = DIRECTION
    nx, ny = -dy, dx
    ox = FIST[0] - dx * KNOB_BEHIND_FIST
    oy = FIST[1] - dy * KNOB_BEHIND_FIST
    n = int(round((s1 - s0) / step))
    up, down = [], []
    for i in range(n + 1):
        s = s0 + (s1 - s0) * i / n
        r = bat_radius(s)
        cx, cy = ox + dx * s, oy + dy * s
        up.append((cx + nx * r, cy + ny * r))
        down.append((cx - nx * r, cy - ny * r))
    return up + down[::-1]


def bat_shadow_line(s0=47.0, s1=89.0, offset=0.42, width=0.55, step=0.5):
    """A thin dark line along the barrel, on its lower side."""
    dx, dy = DIRECTION
    nx, ny = -dy, dx
    ox = FIST[0] - dx * KNOB_BEHIND_FIST
    oy = FIST[1] - dy * KNOB_BEHIND_FIST
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


# --- raster helpers ----------------------------------------------------------

def polygon_field(points, size, soften=0.0):
    """Anti-aliased 0..1 field of a polygon given in source pixels."""
    w, h = size
    ss = 3
    im = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(im).polygon([(x * K * ss, y * K * ss) for x, y in points], fill=255)
    im = im.resize((w, h), Image.LANCZOS)
    if soften:
        im = im.filter(ImageFilter.GaussianBlur(soften * K))
    return np.asarray(im, dtype=np.float32) / 255.0


def dilate(field, radius):
    """Grow the area where field >= 0.5 by radius source pixels."""
    im = Image.fromarray(((field >= 0.5) * 255).astype(np.uint8))
    size = int(round(radius * K)) * 2 + 1
    im = im.filter(ImageFilter.MaxFilter(size)).filter(ImageFilter.GaussianBlur(K * 0.15))
    return np.asarray(im, dtype=np.float32) / 255.0


# --- tracing (marching squares, then Douglas-Peucker) ------------------------

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
        # back from the padded grid to source pixels
        loops.append([((px - 1) / K, (py - 1) / K) for px, py in loop])
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


def to_path(field, level, eps=0.07, min_area=0.35):
    parts = []
    for loop in trace(field, level):
        loop = simplify(loop, eps)
        if len(loop) < 3 or area(loop) < min_area:
            continue
        parts.append(smooth(loop))
    return "".join(parts), len(parts)


# --- build -------------------------------------------------------------------

def build(src, out_svg, out_preview=None):
    icon = Image.open(src).convert("RGBA")
    w0, h0 = icon.size
    a = np.asarray(icon, dtype=np.float32) / 255.0
    coverage = a[..., 3] * a[..., :3].max(axis=2)
    size = (w0 * K, h0 * K)
    art = np.asarray(Image.fromarray(coverage, mode="F").resize(size, Image.BICUBIC)).clip(0, 1)

    art = art * (1 - polygon_field(KATANA, size, soften=0.12))
    # Take out the source's pixel wobble before tracing.
    art = Image.fromarray((art * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(SMOOTH * K))
    art = np.asarray(art, dtype=np.float32) / 255.0
    front_zone = polygon_field(FRONT, size)
    front = art * front_zone
    back = art * (1 - front_zone)

    bat = np.maximum(polygon_field(bat_outline(0.0, HIDDEN_BY_FIST[0]), size),
                     polygon_field(bat_outline(HIDDEN_BY_FIST[1], BAT_LENGTH), size))
    bat = bat * (1 - polygon_field(bat_shadow_line(), size))
    bat_cut = bat * (1 - dilate(front, GAP))
    back = back * (1 - dilate(bat, GAP))
    final = np.maximum(np.maximum(back, front), bat_cut)

    solid, n_solid = to_path(final, SOLID)
    # The faint layer holds only what is not part of a solid shape: fading
    # line ends, faint lines, the dotted outline of the fist.
    faint_field = final * (1 - dilate((final >= SOLID).astype(np.float32), 0.4))
    faint, n_faint = to_path(faint_field, FAINT, min_area=0.6)
    svg = (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="%d" height="%d">\n'
        '  <title>Blunt leap</title>\n'
        '  <!-- Redrawn from Cyberpunk 2077\'s Flash and Thunderclap perk icon (CD PROJEKT RED),\n'
        '       with the katana replaced by a baseball bat. Built by tools/make_icon.py. -->\n'
        '  <path fill="#fff" fill-opacity="0.38" fill-rule="evenodd" d="%s"/>\n'
        '  <path fill="#fff" fill-rule="evenodd" d="%s"/>\n'
        '</svg>\n' % (w0, h0, w0 * 4, h0 * 4, faint, solid)
    )
    with open(out_svg, "w", encoding="utf-8", newline="\n") as f:
        f.write(svg)
    print("svg: %d bytes, %d solid and %d faint outlines" % (len(svg), n_solid, n_faint))

    if out_preview:
        # Before and after, side by side, on the perk screen's dark tone.
        shade = np.clip(np.where(final >= SOLID, 1.0, np.where(faint_field >= FAINT, 0.38, 0.0)), 0, 1)
        after = Image.fromarray((shade * 255).astype(np.uint8)).resize((w0 * 4, h0 * 4), Image.LANCZOS)
        before = Image.fromarray((coverage * 255).astype(np.uint8)).resize((w0 * 4, h0 * 4), Image.LANCZOS)
        pad = 24
        sheet = Image.new("RGB", (w0 * 8 + pad * 3, h0 * 4 + pad * 2), (16, 18, 26))
        white = Image.new("RGB", (w0 * 4, h0 * 4), (255, 255, 255))
        sheet.paste(white, (pad, pad), before)
        sheet.paste(white, (pad * 2 + w0 * 4, pad), after)
        sheet.save(out_preview)
        print("preview:", out_preview)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
