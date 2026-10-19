"""
validate_life.py — 逻辑级校验 events_life.json（P0 三件套收尾）

风格参考 D:\\zkgame\\scratch\\validate_break_v2.py：
  - 纯 json 加载，不依赖 Godot 运行时
  - 逐条断言 PASS/FAIL + 末尾汇总（total / PASS / FAIL）
  - sys.exit(1) 当有 FAIL，否则 0

校验口径（来自主理人收尾任务）：
  A 注册与结构：events_life.json 被 EVENT_FILES 加载、含 24 事件、id 均 life_ 前缀、全局 id 唯一
  B statDelta key ⊆ {intellect,strength,social,art,charm,stress,addict,money}（无 study 死键）
  C 不写 requireRelState / excludeRelState（不碰恋爱状态机）
  D 全部 charId == null
  E flag 串联闭环（C 线 / F 线）+ 无"上游永不置位导致下游死锁"
  F requireHoliday 取值合法（winter/spring/summer/autumn/any）；F6(grandparent) 用 "any"

权威数据源：
  - EVENT_FILES 直接从 DataManager.gd 解析，确保"注册成功"本身被校验覆盖
  - res://scripts/*.json → 本机 D:\zkgame\scripts\*.json
"""

import json, re, os, sys

# Windows GBK 终端安全：强制 UTF-8 输出，防止 emoji/特殊符号打印崩溃
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

GD_PATH = r"D:\zkgame\scripts\DataManager.gd"
SCRIPTS_DIR = r"D:\zkgame\scripts"

RESULTS = []   # (name, ok, detail)
WARNINGS = []  # (name, detail)

def check(name, ok, detail=""):
    RESULTS.append((name, ok, detail))
    status = "PASS" if ok else "FAIL"
    line = f"[{status}] {name}"
    if detail:
        line += f" — {detail}"
    print(line)

def warn(name, detail):
    WARNINGS.append((name, detail))
    print(f"[WARN] {name} — {detail}")

def res_to_fs(p):
    """res://scripts/events_life.json -> D:\\zkgame\\scripts\\events_life.json"""
    rel = p.split("res://scripts/")[-1]
    return os.path.join(SCRIPTS_DIR, rel)

# ---------------------------------------------------------------------------
# 1) 解析 DataManager.gd 的 EVENT_FILES（权威注册列表）
# ---------------------------------------------------------------------------
with open(GD_PATH, encoding="utf-8") as f:
    gd = f.read()

m = re.search(r"const\s+EVENT_FILES\s*=\s*\[(.*?)\]", gd, re.S)
if not m:
    print("FATAL: EVENT_FILES not found in DataManager.gd"); sys.exit(1)
event_files = re.findall(r'"(res://scripts/[^"]+)"', m.group(1))
if not event_files:
    print("FATAL: EVENT_FILES parsed empty"); sys.exit(1)

# ---------------------------------------------------------------------------
# 2) 加载全部事件文件 + characters.json
# ---------------------------------------------------------------------------
all_events = []   # list of (source_file, event_dict)
for ef in event_files:
    fs = res_to_fs(ef)
    if not os.path.exists(fs):
        print(f"FATAL: missing event file {fs} (referenced by EVENT_FILES)"); sys.exit(1)
    with open(fs, encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, list):
        print(f"FATAL: {ef} root is not array"); sys.exit(1)
    for e in data:
        all_events.append((ef, e))

char_path = os.path.join(SCRIPTS_DIR, "characters.json")
with open(char_path, encoding="utf-8") as fh:
    char_list = json.load(fh)
char_ids = {c.get("id") for c in char_list}

# life 事件（按来源文件识别，避免前缀被改也仍能定位）
life_src = "res://scripts/events_life.json"
life = [(f, e) for (f, e) in all_events if f == life_src]

# ---------------------------------------------------------------------------
# 3) 断言 A — 注册与结构
# ---------------------------------------------------------------------------
check("A1 events_life.json 已注册进 EVENT_FILES",
      any(f == life_src for f in event_files),
      f"EVENT_FILES 共 {len(event_files)} 个文件")

# DS-RN-05c: 加入 6 个 olympiad_ 前缀奥赛事件后总数为 30
check("A2 events_life.json 含 30 个事件（24 life_ + 6 olympiad_）",
      len(life) == 30,
      f"实际 {len(life)} 个")

# DS-RN-05c: olympiad_ 前缀事件与 life_ 事件共存于 events_life.json
bad_prefix = [e.get("id") for (_, e) in life
              if not str(e.get("id", "")).startswith(("life_", "olympiad_"))]
check("A3 全部事件 id 以 'life_' 或 'olympiad_' 前缀",
      not bad_prefix,
      f"异常前缀: {bad_prefix}")

all_ids = [e.get("id") for (_, e) in all_events]
dup = sorted({i for i in all_ids if all_ids.count(i) > 1})
check("A4 全局事件 id 唯一（不与现有约 262 事件重名）",
      not dup,
      f"重复: {dup}" if dup else f"全局共 {len(all_ids)} 个事件，无重复")

# ---------------------------------------------------------------------------
# 4) 断言 B — statDelta key 合法性（无 study 死键）
# ---------------------------------------------------------------------------
ALLOWED_STATS = {"intellect", "strength", "social", "art",
                 "charm", "stress", "addict", "money"}
bad_stat_keys = set()

def scan_stat_keys(node):
    if isinstance(node, dict):
        if "statDelta" in node and isinstance(node["statDelta"], dict):
            bad_stat_keys.update(set(node["statDelta"].keys()) - ALLOWED_STATS)
        for v in node.values():
            scan_stat_keys(v)
    elif isinstance(node, list):
        for v in node:
            scan_stat_keys(v)

for (_, e) in life:
    scan_stat_keys(e)

check("B 全部 life statDelta key ⊆ 合法集合（无 'study' 死键）",
      not bad_stat_keys,
      f"非法 key: {sorted(bad_stat_keys)}" if bad_stat_keys else "均为合法 key")

# ---------------------------------------------------------------------------
# 5) 断言 C — 不碰恋爱状态机
# ---------------------------------------------------------------------------
def touches_rel_state(node):
    if isinstance(node, dict):
        if "requireRelState" in node or "excludeRelState" in node:
            return True
        return any(touches_rel_state(v) for v in node.values())
    if isinstance(node, list):
        return any(touches_rel_state(v) for v in node)
    return False

rel_violators = [e.get("id") for (_, e) in life if touches_rel_state(e)]
check("C 无 life 事件写 requireRelState/excludeRelState",
      not rel_violators,
      f"违规: {rel_violators}" if rel_violators else "未触碰恋爱状态机")

# ---------------------------------------------------------------------------
# 6) 断言 D — 全部 charId == null
# ---------------------------------------------------------------------------
bad_char = [(e.get("id"), e.get("charId")) for (_, e) in life
            if e.get("charId") is not None]
check("D 全部 life 事件 charId == null",
      not bad_char,
      f"非 null: {bad_char}" if bad_char else "全部为 null")

# ---------------------------------------------------------------------------
# 7) 断言 E — flag 串联闭环 + 无死锁
# ---------------------------------------------------------------------------
def collect_flags(node, sf=None, rf=None, ef=None):
    """递归收集 setFlag / requireFlags / excludeFlags（任意层级）"""
    if sf is None: sf, rf, ef = set(), set(), set()
    if isinstance(node, dict):
        if node.get("setFlag"):
            sf.add(node["setFlag"])
        if node.get("requireFlags"):
            rf.update(node["requireFlags"])
        if node.get("excludeFlags"):
            ef.update(node["excludeFlags"])
        for v in node.values():
            collect_flags(v, sf, rf, ef)
    elif isinstance(node, list):
        for v in node:
            collect_flags(v, sf, rf, ef)
    return sf, rf, ef

life_flags = {}          # id -> (sf, rf, ef)
glob_set, glob_req, glob_exc = set(), set(), set()
for (_, e) in all_events:
    sf, rf, ef = collect_flags(e)
    glob_set |= sf; glob_req |= rf; glob_exc |= ef
    if e.get("id", "").startswith("life_"):
        life_flags[e.get("id")] = (sf, rf, ef)

def setters_of(flag):
    return {i for i, (sf, _, _) in life_flags.items() if flag in sf}

def requirers_of(flag):
    return {i for i, (_, rf, _) in life_flags.items() if flag in rf}

def excluders_of(flag):
    return {i for i, (_, _, ef) in life_flags.items() if flag in ef}

# E1: flag_conflict_active 由 C1/C2 置位、被 C3/C4 消费
fca_set = setters_of("flag_conflict_active")
fca_req = requirers_of("flag_conflict_active")
check("E1 flag_conflict_active: C1/C2 setFlag，C3/C4 requireFlags",
      fca_set == {"life_conflict_excluded", "life_conflict_rumor"}
      and fca_req == {"life_conflict_bystander", "life_conflict_reconcile"},
      f"setters={sorted(fca_set)} requirers={sorted(fca_req)}")

# E2: flag_conflict_resolved 由 C4 置位、被 C2/C4 excludeFlags
fcr_set = setters_of("flag_conflict_resolved")
fcr_exc = excluders_of("flag_conflict_resolved")
check("E2 flag_conflict_resolved: C4 setFlag，C2/C4 excludeFlags",
      fcr_set == {"life_conflict_reconcile"}
      and fcr_exc == {"life_conflict_rumor", "life_conflict_reconcile"},
      f"setters={sorted(fcr_set)} excluders={sorted(fcr_exc)}")

# E3: flag_family_quarrel 由 F1 置位、被 F2 requireFlags
ffq_set = setters_of("flag_family_quarrel")
ffq_req = requirers_of("flag_family_quarrel")
check("E3 flag_family_quarrel: F1 setFlag，F2 requireFlags",
      ffq_set == {"life_family_quarrel"}
      and ffq_req == {"life_family_reconcile"},
      f"setters={sorted(ffq_set)} requirers={sorted(ffq_req)}")

# E4: flag_family_ok 由 F2 置位
ffo_set = setters_of("flag_family_ok")
check("E4 flag_family_ok: F2 setFlag",
      ffo_set == {"life_family_reconcile"},
      f"setters={sorted(ffo_set)}")

# E5: 无死锁 —— life 事件消费的 flag（requireFlags/excludeFlags）必有上游置位。
#     范围限定在 life 事件自身引用的 flag，避免与"其他文件/代码置位"的 flag 混淆
#     （如 exam_week 由考试调度在代码中置位，不在此处校验；其他人物线 flag 同理不在本任务范围）。
life_consumed = set()
for (sf, rf, ef) in life_flags.values():
    life_consumed |= (rf | ef)
# 上游置位在全局范围内查找（允许 life 依赖其他文件置位的 flag）
unset_consumed = sorted(life_consumed - glob_set)
check("E5 无死锁：life 事件消费的 flag 均有上游 setFlag",
      not unset_consumed,
      f"永不置位却被子项消费: {unset_consumed}" if unset_consumed else "life 消费端 flag 均有上游置位")

# ---------------------------------------------------------------------------
# 8) 断言 F — requireHoliday 合法性；F6 用 any
# ---------------------------------------------------------------------------
VALID_HOLIDAYS = {"winter", "spring", "summer", "autumn", "any"}
bad_hol = [(e.get("id"), e.get("requireHoliday"))
           for (_, e) in life
           if e.get("requireHoliday") is not None
           and e.get("requireHoliday") not in VALID_HOLIDAYS]
check("F1 requireHoliday 取值合法 (winter/spring/summer/autumn/any)",
      not bad_hol,
      f"非法取值: {bad_hol}" if bad_hol else "全部合法")

f6 = next((e for (_, e) in life if e.get("id") == "life_family_grandparent"), None)
f6_ok = f6 is not None and f6.get("requireHoliday") == "any"
check("F2 F6(life_family_grandparent) requireHoliday == 'any'（长假探亲语义）",
      f6_ok,
      f"实际: {f6.get('requireHoliday') if f6 else 'MISSING'}" if not f6_ok else "any 正确")

# ---------------------------------------------------------------------------
# 9) 软校验（仅 WARN，不计入 FAIL）—— 可选质量观察
# ---------------------------------------------------------------------------
LOCATION_GAINS = {
    "classroom", "library", "playground", "music_room", "art_room",
    "off_campus_shop", "school_gate", "lakeside", "community", "home",
    "cinema", "amusement_park",
}
unknown_loc = sorted({(e.get("id"), e.get("location"))
                      for (_, e) in life
                      if e.get("location") not in LOCATION_GAINS})
if unknown_loc:
    warn("location 取值不在 LOCATION_STAT_GAINS 已知集合", str(unknown_loc))
else:
    print("[INFO] 所有 life 事件 location 均为已知地点（无 WARN）")

# ---------------------------------------------------------------------------
# 10) 汇总
# ---------------------------------------------------------------------------
total = len(RESULTS)
passed = sum(1 for _, ok, _ in RESULTS if ok)
failed = total - passed

print("\n" + "=" * 60)
print(f"SUMMARY  total={total}  PASS={passed}  FAIL={failed}"
      + (f"  WARN={len(WARNINGS)}" if WARNINGS else ""))
print("=" * 60)
for name, ok, detail in RESULTS:
    mark = "ok " if ok else "XX "
    print(f"  {mark} {name}")
if WARNINGS:
    print("-- warnings --")
    for name, detail in WARNINGS:
        print(f"  ?? {name}: {detail}")

if failed:
    gate = "FAIL"
elif WARNINGS:
    gate = "CONCERNS"
else:
    gate = "PASS"
print(f"\nQUALITY GATE: {gate}")

sys.exit(1 if failed else 0)
