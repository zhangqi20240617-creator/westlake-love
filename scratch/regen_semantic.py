"""Semantic regen helper: matte a green-screen source -> RGBA, backup the
existing sprite, drop it in place, then despill the edge green halo.

Usage:
  python regen_semantic.py <char> <pose> <green_source.png>
"""
import sys
import numpy as np
from PIL import Image
from pathlib import Path

sys.path.insert(0, "scratch")
# reuse matte + despill implementations
import matte_sprite as M
import qc_retouch as Q


def main():
    char, pose, src = sys.argv[1], sys.argv[2], sys.argv[3]
    target = Path(f"assets/sprites/{char}/{pose}.png")
    tmp = Path(f".gen_tmp/{char}_{pose}_rgba.png")
    tmp.parent.mkdir(parents=True, exist_ok=True)

    # 1) matte green-screen -> RGBA (2048x2048)
    M.matte(Path(src), tmp, margin=35)

    # 2) backup current (if any) then overwrite
    if target.exists():
        target.with_suffix(".png.bak").write_bytes(target.read_bytes())
        print(f"[backup] {target} -> {target.with_suffix('.png.bak')}")
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp.replace(target)
    print(f"[deploy] {src} -> {target}")

    # 3) despill edge green halo in place
    Q.despill(str(target), str(target))

    # 4) report
    im = np.array(Image.open(target).convert("RGBA"))
    a = im[:, :, 3]
    r, g, b = im[:, :, 0].astype(int), im[:, :, 1].astype(int), im[:, :, 2].astype(int)
    green_edge = int(((a > 2) & (a < 250) & (g > r + 8) & (g > b + 8)).sum())
    print(f"[verify] {char}/{pose}: size={target.stat().st_size//1024}KB "
          f"alpha_min={int(a.min())} alpha_max={int(a.max())} green_edge_px={green_edge}")


if __name__ == "__main__":
    main()
