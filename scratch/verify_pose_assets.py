import json, os, glob

ROOT = "D:/zkgame"
SPRITE_ROOT = os.path.join(ROOT, "assets", "sprites")
EVENT_FILES = [
    "events_yutong.json", "events_jingjing.json", "events_wanqing.json",
    "events_xiaoxia.json", "events_keke.json", "events_male.json",
    "events_special.json", "events_break.json", "events_daily.json",
    "events_life.json",
]
EVENT_PATHS = [os.path.join(ROOT, "scripts", f) for f in EVENT_FILES]

def asset_exists(char, pose):
    base = os.path.join(SPRITE_ROOT, str(char).lower(), str(pose).lower())
    for ext in (".png", ".jpg", ".ogv"):
        if os.path.isfile(base + ext):
            return True
    return False

def walk(obj, acc):
    if isinstance(obj, dict):
        if "speaker" in obj:
            sp = obj.get("speaker", "")
            if sp not in ("", "player", "narrator", None):
                pose = obj.get("pose", "default") or "default"
                acc.append((sp, pose, obj.get("id", "?")))
        for v in obj.values():
            walk(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            walk(v, acc)

all_refs = []
for p in EVENT_PATHS:
    if not os.path.isfile(p):
        print("MISSING FILE:", p); continue
    with open(p, encoding="utf-8") as f:
        data = json.load(f)
    walk(data, all_refs)

missing = []
ok = []
for char, pose, eid in all_refs:
    if asset_exists(char, pose):
        ok.append((char, pose, eid))
    else:
        missing.append((char, pose, eid))

print("=== POSE REFERENCE x ASSET CROSS-CHECK ===")
print("total (speaker,pose) refs:", len(all_refs))
print("RESOLVED (asset exists):", len(ok))
print("MISSING (no asset):", len(missing))
print()
if missing:
    print("--- MISSING (grouped by char) ---")
    by_char = {}
    for char, pose, eid in missing:
        by_char.setdefault(char, set()).add(pose)
    for char in sorted(by_char):
        print(f"  {char}: {sorted(by_char[char])}")
else:
    print("NO BROKEN POSE REFS REMAIN.")

# Also flag any 'upset' usage (legacy bad pose)
upsets = [(c,p,e) for c,p,e in all_refs if p == "upset"]
print()
print("'upset' refs remaining:", len(upsets))
