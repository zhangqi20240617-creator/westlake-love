import os
from PIL import Image

SRC = "D:/zkgame/scratch/holiday_cg"
DST = "D:/zkgame/assets/backgrounds"

# (source png, target jpg, season label)
JOBS = [
    ("Painterly_Chinese_landscape_il_2026-07-29T08-29-53.png", "holiday_winter.jpg",            "winter"),
    ("Painterly_Chinese_landscape_il_2026-07-29T08-29-01.png", "holiday_spring_outing.jpg",      "spring"),
    ("Painterly_Chinese_landscape_il_2026-07-29T08-29-00.png", "holiday_summer_trip.jpg",        "summer"),
    ("Painterly_Chinese_landscape_il_2026-07-29T08-30-27.png", "holiday_autumn_osmanthus.jpg",   "autumn"),
]

os.makedirs(DST, exist_ok=True)
for png, jpg, season in JOBS:
    src = os.path.join(SRC, png)
    dst = os.path.join(DST, jpg)
    if not os.path.exists(src):
        raise SystemExit(f"MISSING source for {season}: {src}")
    im = Image.open(src)
    print(f"[{season}] source={png} mode={im.mode} size={im.size}")
    if im.size != (1280, 720):
        print(f"  WARNING: expected 1280x720, got {im.size} (resizing to fit)")
        im = im.resize((1280, 720), Image.LANCZOS)
    if im.mode in ("RGBA", "P", "LA"):
        im = im.convert("RGB")
    im.save(dst, "JPEG", quality=92, optimize=True, progressive=False)
    print(f"  -> wrote {dst}  ({os.path.getsize(dst)} bytes)")
print("ALL DONE")
