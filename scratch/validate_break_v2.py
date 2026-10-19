import json, sys

PATH = r"D:\zkgame\scripts\events_break.json"
VALID_HOLIDAYS = {"winter","spring","summer","autumn"}
VALID_CHARS = {"yutong","jingjing","wanqing","xiaoxia","keke",
               "yifei","zicheng","beichen","jingjing_m","zijun"}
EXPECTED_KICKOFFS = {"holiday_kickoff_winter","holiday_kickoff_summer",
                     "holiday_kickoff_spring","holiday_kickoff_autumn"}

errs, warns = [], []
with open(PATH, encoding="utf-8") as f:
    data = json.load(f)

if not isinstance(data, list):
    print("FATAL: root not array"); sys.exit(1)
print("event_count =", len(data))

ids = [e.get("id") for e in data]
if len(ids) != len(set(ids)):
    dup = {i for i in ids if ids.count(i) > 1}
    errs.append(f"duplicate ids: {dup}")

kickoffs = {i for i in ids if i.startswith("holiday_kickoff_")}
missing = EXPECTED_KICKOFFS - kickoffs
if missing: errs.append(f"missing kickoffs: {missing}")

chapters, fillers = [], []
for e in data:
    eid = e.get("id","<no-id>")
    rh = e.get("requireHoliday","")
    if rh not in VALID_HOLIDAYS: errs.append(f"{eid}: bad requireHoliday={rh!r}")
    cid = e.get("charId")
    if cid is not None and cid not in VALID_CHARS: errs.append(f"{eid}: bad charId={cid!r}")

    # chapter detection: has a holiday_memory setFlag
    mem_flags = []
    for sc in e.get("scenes", []):
        for ch in sc.get("choices", []):
            sf = ch.get("setFlag","")
            if sf.startswith("holiday_memory_"):
                mem_flags.append(sf)
        if sc.get("setFlag","").startswith("holiday_memory_"):
            mem_flags.append(sc["setFlag"])

    if mem_flags:
        chapters.append(eid)
        bg = e.get("bg","")
        if not bg.startswith("res://assets/backgrounds/holiday"):
            errs.append(f"{eid}: chapter bg not holiday path: {bg!r}")
        if not e.get("requireFlags"):
            errs.append(f"{eid}: chapter missing requireFlags (chain break)")
        if cid is None or cid not in VALID_CHARS:
            errs.append(f"{eid}: chapter missing/ bad charId")
        if not mem_flags:
            errs.append(f"{eid}: chapter missing holiday_memory setFlag")
    elif eid not in EXPECTED_KICKOFFS:
        fillers.append(eid)

# coverage of all 10 chars by chapters
chap_chars = {e.get("charId") for e in data if e.get("id") in chapters}
missing_chars = VALID_CHARS - chap_chars
if missing_chars: errs.append(f"chapter char coverage missing: {missing_chars}")

print("kickoffs =", sorted(kickoffs))
print("chapters =", len(chapters), chapters)
print("fillers  =", len(fillers), fillers)
print("chapter char coverage =", sorted(chap_chars))
print("warnings:", warns)
print("ERRORS:", errs if errs else "none")
sys.exit(1 if errs else 0)
