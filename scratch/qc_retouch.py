"""Art QC + retouch pass for the 12 green-screen character sprites.

- analyze(): technical defect metrics (green-fringe count, alpha edge quality,
  foreground bbox / centering / clipping).
- despill(): pull down green spill in semi-transparent edge pixels so the
  character no longer carries a green halo over the game background.
Backs up each sprite to <pose>.png.bak before overwriting.
"""
import json
import numpy as np
from PIL import Image
from pathlib import Path

SPRITES = [
    ("keke", "default"), ("keke", "shy"), ("keke", "upset"),
    ("beichen", "default"), ("beichen", "serious"), ("beichen", "shy"),
    ("jingjing_m", "default"), ("jingjing_m", "shy"), ("jingjing_m", "upset"),
    ("zijun", "default"), ("zijun", "serious"), ("zijun", "shy"),
]


def analyze(arr):
    h, w = arr.shape[:2]
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    a = arr[:, :, 3]
    total = h * w
    fg = int((a > 10).sum())
    edge = int(((a > 2) & (a < 250)).sum())
    green_edge = int(((a > 2) & (a < 250) & (g > r + 8) & (g > b + 8)).sum())
    ys, xs = np.where(a > 10)
    bbox = None
    if len(xs):
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        bw, bh = int(x1 - x0 + 1), int(y1 - y0 + 1)
        cx = round(float((x0 + x1) / 2 / w - 0.5), 3)
        cy = round(float((y0 + y1) / 2 / h - 0.5), 3)
        clipped = bool(x0 <= 2 or y0 <= 2 or x1 >= w - 3 or y1 >= h - 3)
        bbox = dict(bw=bw, bh=bh, cx=cx, cy=cy, clipped=clipped)
    return dict(fg_pct=round(100 * fg / total, 1), edge_px=edge,
                green_edge_px=green_edge, bbox=bbox)


def despill(src, dst):
    im = Image.open(src).convert("RGBA")
    arr = np.array(im)
    r = arr[:, :, 0].astype(int)
    g = arr[:, :, 1].astype(int)
    b = arr[:, :, 2].astype(int)
    a = arr[:, :, 3]
    mask = (a > 0) & (a < 255)
    greenish = mask & (g > r) & (g > b)
    gnew = np.where(greenish, np.minimum(g, np.maximum(r, b)), g).astype(np.uint8)
    arr[:, :, 1] = gnew
    Image.fromarray(arr, "RGBA").save(dst)


if __name__ == "__main__":
    base = "assets/sprites"
    report = []
    for ch, pose in SPRITES:
        p = Path(f"{base}/{ch}/{pose}.png")
        if not p.exists():
            report.append(dict(char=ch, pose=pose, error="missing"))
            continue
        before = analyze(np.array(Image.open(p).convert("RGBA")))
        p.with_suffix(".png.bak").write_bytes(p.read_bytes())
        despill(str(p), str(p))
        after = analyze(np.array(Image.open(p).convert("RGBA")))
        report.append(dict(char=ch, pose=pose, before=before, after=after))
    print(json.dumps(report, ensure_ascii=False, indent=2))
