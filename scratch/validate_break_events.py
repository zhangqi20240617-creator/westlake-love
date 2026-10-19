import json, sys

PATH = r"D:\zkgame\scripts\events_break.json"
VALID_HOLIDAYS = {"winter", "spring", "summer", "autumn"}
VALID_CHARS = {"yutong","jingjing","wanqing","xiaoxia","keke",
               "yifei","zicheng","beichen","jingjing_m","zijun"}
KNOWN_SCENES = {"community","home","lakeside","amusement_park","classroom",
                "library","playground","music_room","art_room","school_gate",
                "cinema","off_campus_shop",""}
EXPECTED_KICKOFFS = {"holiday_kickoff_winter","holiday_kickoff_summer",
                     "holiday_kickoff_spring","holiday_kickoff_autumn"}

errs, warns = [], []
with open(PATH, encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data, list):
    print("FATAL: root not array"); sys.exit(1)
print("event_count =", len(data))

ids = [e.get("id") for e in data]
dup = {i for i in ids if ids.count(i) > 1}
if dup: errs.append(f"duplicate ids: {dup}")
if len(ids) != len(set(ids)): errs.append("id count mismatch")

kickoffs = {i for i in ids if i.startswith("holiday_kickoff_")}
missing = EXPECTED_KICKOFFS - kickoffs
if missing: errs.append(f"missing kickoffs: {missing}")

for e in data:
    eid = e.get("id","<no-id>")
    rh = e.get("requireHoliday","")
    if rh not in VALID_HOLIDAYS: errs.append(f"{eid}: bad requireHoliday={rh!r}")
    cid = e.get("charId", None)
    if cid is not None and cid not in VALID_CHARS: errs.append(f"{eid}: bad charId={cid!r}")
    loc = e.get("location","")
    if loc not in KNOWN_SCENES: warns.append(f"{eid}: location {loc!r} not in known set")
    if "priority" not in e or not isinstance(e["priority"], int): errs.append(f"{eid}: priority missing/non-int")
    if "scenes" not in e or not isinstance(e["scenes"], list): errs.append(f"{eid}: scenes missing")
    for sc in e.get("scenes", []):
        if "text" not in sc: errs.append(f"{eid}: scene missing text")
        for ch in sc.get("choices", []):
            if "text" not in ch: errs.append(f"{eid}: choice missing text")
            if "next" not in ch: warns.append(f"{eid}: choice missing next")
    # kickoff must set a flag on each choice
    if eid in EXPECTED_KICKOFFS:
        for sc in e.get("scenes", []):
            for ch in sc.get("choices", []):
                if "setFlag" not in ch: errs.append(f"{eid}: kickoff choice missing setFlag")

# holiday coverage report
from collections import Counter
cov = Counter(e.get("requireHoliday") for e in data)
print("holiday coverage:", dict(cov))
char_routed = [e["id"] for e in data if e.get("charId")]
print("char-routed events:", char_routed)
print("warnings:", warns)
print("ERRORS:", errs if errs else "none")
sys.exit(1 if errs else 0)
