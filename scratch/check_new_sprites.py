from pathlib import Path
from PIL import Image

paths = [
    "assets/sprites/keke/default.png",
    "assets/sprites/keke/shy.png",
    "assets/sprites/keke/upset.png",
    "assets/sprites/beichen/default.png",
    "assets/sprites/beichen/serious.png",
    "assets/sprites/beichen/shy.png",
    "assets/sprites/jingjing_m/default.png",
    "assets/sprites/jingjing_m/shy.png",
    "assets/sprites/jingjing_m/upset.png",
    "assets/sprites/zijun/default.png",
    "assets/sprites/zijun/serious.png",
    "assets/sprites/zijun/shy.png",
]
errors = []
for p in paths:
    full = Path(p)
    if not full.exists():
        errors.append(f"MISSING: {p}")
        continue
    im = Image.open(full)
    mode = im.mode
    w, h = im.size
    has_alpha = mode in ("RGBA", "LA") or (mode == "P" and "transparency" in im.info)
    alpha_ok = False
    if mode == "RGBA":
        alpha = im.convert("RGBA").split()[-1]
        alpha_ok = min(alpha.getextrema()) < 255
    elif mode == "P" and "transparency" in im.info:
        alpha_ok = True
    print(f"{p}: {w}x{h} mode={mode} alpha_ok={alpha_ok} size={full.stat().st_size/1024:.1f}KB")
    if (w, h) != (2048, 2048):
        errors.append(f"BAD SIZE {w}x{h}: {p}")
    if not has_alpha or not alpha_ok:
        errors.append(f"ALPHA ISSUE: {p}")

if errors:
    print("ERRORS:")
    for e in errors:
        print("  " + e)
    exit(1)
else:
    print("ALL 12 ASSETS OK: 2048x2048 with usable alpha transparency.")
