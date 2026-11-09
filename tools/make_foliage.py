#!/usr/bin/env python3
"""Builds foliage card textures from CC0 ambientCG atlases (LeafSet024, Foliage001).

Usage: tools/make_foliage.py ACG_DIR OUT_DIR
ACG_DIR holds the unzipped 1K-JPG downloads. The outputs are CC0 like their sources.
"""
import math, random, sys
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

acg, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
rng = random.Random(7)


def rgba(name):
    c = Image.open(acg / name / f"{name}_1K-JPG_Color.jpg").convert("RGB")
    a = Image.open(acg / name / f"{name}_1K-JPG_Opacity.jpg").convert("L")
    c.putalpha(a)
    return c


def sprites(img, boxes):
    out = []
    for b in boxes:
        s = img.crop(b)
        bb = s.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        if bb:
            out.append(s.crop(bb))
    return out


def tint(s, mul):
    r, g, b, a = s.split()
    r = r.point(lambda v: min(255, int(v * mul[0])))
    g = g.point(lambda v: min(255, int(v * mul[1])))
    b = b.point(lambda v: min(255, int(v * mul[2])))
    return Image.merge("RGBA", (r, g, b, a))


def bleed(img):
    """Fill transparent pixels with the mean opaque colour so mipmaps don't get dark halos."""
    a = img.getchannel("A")
    rgb = img.convert("RGB")
    mask = a.point(lambda v: 255 if v > 128 else 0)
    stat = [int(sum(px * w for px, w in zip(range(256), rgb.getchannel(i).histogram(mask))) /
                max(1, sum(rgb.getchannel(i).histogram(mask)))) for i in range(3)]
    bg = Image.new("RGB", img.size, tuple(stat))
    bg.paste(rgb, (0, 0), mask.filter(ImageFilter.MaxFilter(5)))
    bg.putalpha(a)
    return bg


# Leaves: 3x3 grid on the atlas.
leaf_img = rgba("LeafSet024")
w, h = leaf_img.size
leaves = sprites(leaf_img, [(x * w // 3, y * h // 3, (x + 1) * w // 3, (y + 1) * h // 3) for y in range(3) for x in range(3)])
# Grass blades: 8 columns on Foliage001.
blade_img = rgba("Foliage001")
w, h = blade_img.size
blades = sprites(blade_img, [(x * w // 8, 0, (x + 1) * w // 8, h) for x in range(8)])

S = 512

# Broadleaf crown cluster: a soft blob of overlapping leaves.
cl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
for i in range(260):
    r = (rng.random() ** 0.6) * S * 0.42
    t = rng.random() * math.tau
    x, y = S / 2 + math.cos(t) * r, S / 2 + math.sin(t) * r * 0.9
    lf = rng.choice(leaves)
    sc = rng.uniform(0.11, 0.17) * S / max(lf.size)
    lf = lf.resize((max(1, int(lf.width * sc)), max(1, int(lf.height * sc))), Image.LANCZOS)
    lf = lf.rotate(rng.uniform(0, 360), expand=True, resample=Image.BICUBIC)
    shade = 0.62 + 0.38 * (1 - r / (S * 0.42)) * rng.uniform(0.8, 1.0)
    lf = tint(lf, (shade * 0.95, shade, shade * 0.85))
    cl.alpha_composite(lf, (int(x - lf.width / 2), int(y - lf.height / 2)))
bleed(cl).save(out / "broadleaf_cluster.png")

# Conifer branch: stem from the trunk (left) to the tip (right) with needles.
br = Image.new("RGBA", (S, S // 2), (0, 0, 0, 0))
d = ImageDraw.Draw(br)
cy = S // 4
d.line([(0, cy), (S - 10, cy)], fill=(92, 70, 52, 255), width=7)
for i in range(1100):
    u = rng.random() ** 0.8
    x = u * (S - 16)
    side = rng.choice([-1, 1])
    reach = (1 - u * 0.6) * S * 0.24
    bl = rng.choice(blades)
    ln = rng.uniform(0.55, 1.0) * reach
    sc = ln / bl.height
    bl = bl.resize((max(3, int(bl.width * sc * 2.4)), max(2, int(ln))), Image.LANCZOS)
    ang = side * rng.uniform(35, 70)
    bl = bl.rotate(ang + 180 * (side < 0) - 90 * 0, expand=True, resample=Image.BICUBIC)
    shade = rng.uniform(0.55, 0.85)
    bl = tint(bl, (shade * 0.55, shade * 0.75, shade * 0.6))
    oy = cy - bl.height if side < 0 else cy
    br.alpha_composite(bl, (int(x - bl.width / 2), int(oy)))
bleed(br).save(out / "conifer_branch.png")

# Grass clump: blades fanned up from the bottom centre.
gc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
for i in range(110):
    bl = rng.choice(blades)
    ln = rng.uniform(0.55, 0.98) * S
    sc = ln / bl.height
    bl = bl.resize((max(2, int(bl.width * sc * 1.4)), int(ln)), Image.LANCZOS)
    bl = bl.rotate(rng.uniform(-22, 22), expand=True, resample=Image.BICUBIC)
    k = rng.uniform(0.75, 1.1)
    bl = tint(bl, (k * rng.uniform(0.7, 0.9), k * 1.05, k * 0.7))
    x = S / 2 + rng.uniform(-0.3, 0.3) * S
    gc.alpha_composite(bl, (int(x - bl.width / 2), S - bl.height))
bleed(gc).save(out / "grass_clump.png")
print("ok", len(leaves), "leaves,", len(blades), "blades")
