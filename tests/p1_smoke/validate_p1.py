# -*- coding: utf-8 -*-
"""
validate_p1.py — 《西湖边的青春》P1 内容补强（四支柱）整合校验 + 质量门判定

风格继承 D:\\zkgame\\tests\\life_smoke\\validate_life.py：
  - 纯 json / 正则加载，不依赖 Godot 运行时（无 Godot 环境）
  - 逐条断言 PASS/FAIL + 末尾汇总（total / PASS / FAIL / WARN）
  - FAIL 时 sys.exit(1)，否则 0
  - 仅读盘 + 静态解析，不修改任何游戏源码 / 事件 JSON

校验范围（P1 四支柱：节日补全 / 社交圈 / 考试节奏 / 毕业仪式感）：
  1) 事件文件加载（合法 JSON / 44 事件 / id 全局唯一，含与 events_daily exam_result_* 不撞）
  2) statDelta 合法性（key ⊆ 合法 8 维，无 "study" 死键）
  3) 性别对称（全部 charId == null）
  4) 不碰恋爱状态机（无 requireRelState/excludeRelState/favors/affDelta）
  5) flag 串联闭环（flag_conflict_resolved / bond_misunderstood / grad_* 的 scene 级 setFlag）
  6) 节日叙事接线（fest_narrative_map 四键 + 四 fest 事件存在）
  7) SPECIAL_DATES 无冲突（无重复 day / 240·330=special / P1 新增考日均在 / 无同日 exam×special）
  8) 画廊映射一致（GALLERY_ITEMS grad_photo·grad_yearbook + bg 文件存在 + flag 同名）
  9) EVENT_FILES 注册（含 events_life.json）

权威数据源：
  - EVENT_FILES 直接解析自 DataManager.gd（覆盖"注册成功"本身）
  - res://scripts/*.json -> D:\\zkgame\\scripts\\*.json
  - res://assets/*       -> D:\\zkgame\\assets\\*
"""

import json
import re
import os
import sys

# ── 路径 ────────────────────────────────────────────────────────────
SCRIPTS_DIR = r"D:\zkgame\scripts"
ASSETS_DIR = r"D:\zkgame\assets"
PY_GD = r"D:\zkgame\scripts\GameManager.gd"
DC_GD = r"D:\zkgame\scripts\DailyCycleManager.gd"
MG_GD = r"D:\zkgame\scripts\MainGame.gd"
DM_GD = r"D:\zkgame\scripts\DataManager.gd"
DU_GD = r"D:\zkgame\scripts\DialogueUI.gd"

RESULTS = []   # (name, ok, detail)
WARNINGS = []  # (name, detail)

ALLOWED_STATS = {"intellect", "strength", "social", "art",
                 "charm", "stress", "addict", "money"}


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


def bg_to_fs(p):
    """res://assets/backgrounds/grad_photo.jpg -> D:\\zkgame\\assets\\backgrounds\\grad_photo.jpg"""
    rel = p.split("res://")[-1]
    return os.path.join(r"D:\zkgame", rel)


# ===========================================================================
# 0) 读取 Godot 脚本源（用于正则解析 EVENT_FILES / SPECIAL_DATES / fest_narrative_map / GALLERY_ITEMS）
# ===========================================================================
for path, label in [(DM_GD, "DataManager.gd"), (DC_GD, "DailyCycleManager.gd"),
                    (MG_GD, "MainGame.gd"), (PY_GD, "GameManager.gd"),
                    (DU_GD, "DialogueUI.gd")]:
    if not os.path.exists(path):
        print(f"FATAL: 找不到 {label} @ {path}"); sys.exit(1)

with open(DM_GD, encoding="utf-8") as f:
    dm_src = f.read()
with open(DC_GD, encoding="utf-8") as f:
    dc_src = f.read()
with open(MG_GD, encoding="utf-8") as f:
    mg_src = f.read()
with open(PY_GD, encoding="utf-8") as f:
    py_src = f.read()
with open(DU_GD, encoding="utf-8") as f:
    du_src = f.read()


# ===========================================================================
# 1) 解析 EVENT_FILES（权威注册列表）
# ===========================================================================
m = re.search(r"const\s+EVENT_FILES\s*=\s*\[(.*?)\]", dm_src, re.S)
if not m:
    print("FATAL: EVENT_FILES not found in DataManager.gd"); sys.exit(1)
event_files = re.findall(r'"(res://scripts/[^"]+)"', m.group(1))
if not event_files:
    print("FATAL: EVENT_FILES parsed empty"); sys.exit(1)


# ===========================================================================
# 2) 加载全部事件文件（真实读盘）
# ===========================================================================
all_events = []          # list of (source_file, event_dict)
for ef in event_files:
    fs = res_to_fs(ef)
    if not os.path.exists(fs):
        print(f"FATAL: 缺少事件文件 {fs}（被 EVENT_FILES 引用）"); sys.exit(1)
    try:
        with open(fs, encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception as e:
        print(f"FATAL: {ef} JSON 解析失败: {e}"); sys.exit(1)
    if not isinstance(data, list):
        print(f"FATAL: {ef} 根节点不是数组"); sys.exit(1)
    for e in data:
        all_events.append((ef, e))

life_src = "res://scripts/events_life.json"
life = [(f, e) for (f, e) in all_events if f == life_src]
life_events = [e for (_, e) in life]


# ===========================================================================
# 断言 1 — 事件文件加载
# ===========================================================================
check("1.1 events_life.json 已注册进 EVENT_FILES",
      any(f == life_src for f in event_files),
      f"EVENT_FILES 共 {len(event_files)} 个文件")

check("1.2 events_life.json 合法 JSON 且含 44 个事件",
      len(life) == 44,
      f"实际 {len(life)} 个（life {sum(1 for e in life_events if e.get('id','').startswith('life_'))}"
      f" / fest {sum(1 for e in life_events if e.get('id','').startswith('fest_'))}"
      f" / bond {sum(1 for e in life_events if e.get('id','').startswith('bond_'))}"
      f" / mock {sum(1 for e in life_events if e.get('id','').startswith('mock_'))}"
      f" / grad {sum(1 for e in life_events if e.get('id','').startswith('grad_'))}）")

# 全局 id 唯一性（跨所有 EVENT_FILES）
all_ids = [e.get("id") for (_, e) in all_events]
dup = sorted({i for i in all_ids if all_ids.count(i) > 1})
check("1.3 全局事件 id 唯一（含与 events_daily 的 exam_result_* 等不撞）",
      not dup,
      f"重复: {dup}" if dup else f"全局共 {len(all_ids)} 事件，无重复 id")

# 显式检查：life 事件的 id 不与 events_daily.json 的 exam_result_* 撞名
daily = next((e for (f, e) in all_events if f.endswith("events_daily.json")), None)
# daily 已并入 all_events；单独取 daily 的 id 集合
daily_ids = {e.get("id") for (f, e) in all_events if f.endswith("events_daily.json")}
life_ids = {e.get("id") for e in life_events}
collide = sorted(life_ids & daily_ids)
check("1.4 life 事件 id 不与 events_daily.json 撞名（exam_result_* 等）",
      not collide,
      f"撞名: {collide}" if collide else "life 与 daily 文件 id 零交集")


# ===========================================================================
# 断言 2 — statDelta 合法性
# ===========================================================================
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


for e in life_events:
    scan_stat_keys(e)

check("2 statDelta key ⊆ 合法 8 维（intellect/strength/social/art/charm/stress/addict/money），"
      "无 'study' 死键",
      not bad_stat_keys,
      f"非法 key: {sorted(bad_stat_keys)}" if bad_stat_keys else "全部合法")


# ===========================================================================
# 断言 3 — 性别对称（全部 charId == null）
# ===========================================================================
bad_char = [(e.get("id"), e.get("charId")) for e in life_events
            if e.get("charId") is not None]
check("3 全部 P1 事件 charId == null（性别对称）",
      not bad_char,
      f"非 null: {bad_char}" if bad_char else "全部为 null")


# ===========================================================================
# 断言 4 — 不碰恋爱状态机
# ===========================================================================
FORBIDDEN = {"requireRelState", "excludeRelState", "favors", "affDelta"}


def touches_forbidden(node):
    if isinstance(node, dict):
        if FORBIDDEN & set(node.keys()):
            return True
        return any(touches_forbidden(v) for v in node.values())
    if isinstance(node, list):
        return any(touches_forbidden(v) for v in node)
    return False


violators = [e.get("id") for e in life_events if touches_forbidden(e)]
check("4 无 P1 事件写 requireRelState/excludeRelState/favors/affDelta（不碰恋爱状态机）",
      not violators,
      f"违规: {violators}" if violators else "未触碰恋爱状态机")


# ===========================================================================
# 断言 5 — flag 串联闭环
# ===========================================================================
def collect_flags(node, sf=None, rf=None, ef=None):
    if sf is None:
        sf, rf, ef = set(), set(), set()
    if isinstance(node, dict):
        if node.get("setFlag"):
            sf.add(node["setFlag"])
        if node.get("setFlags"):  # 兼容数组形式
            sf.update(node["setFlags"])
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


# 全局 flag 视角（允许 life 依赖其它文件置位的 flag）
glob_set, glob_req, glob_exc = set(), set(), set()
def top_flags(e):
    sf, rf, ef = collect_flags(e)
    return sf, rf, ef

for (_, e) in all_events:
    sf, rf, ef = collect_flags(e)
    glob_set |= sf; glob_req |= rf; glob_exc |= ef

# 逐事件（life 内）视角，便于判断 setFlag 所在层级
ev_flags = {}
for e in life_events:
    ev_flags[e.get("id")] = collect_flags(e)


def setters_of(flag):
    return {e.get("id") for e in life_events if flag in ev_flags[e.get("id")][0]}

def requirers_of(flag):
    return {e.get("id") for e in life_events if flag in ev_flags[e.get("id")][1]}

def excluders_of(flag):
    return {e.get("id") for e in life_events if flag in ev_flags[e.get("id")][2]}


# 5.1 flag_conflict_resolved 被 bond_accept 的 requireFlags 消费
fcr_req = requirers_of("flag_conflict_resolved")
fcr_set = setters_of("flag_conflict_resolved")
check("5.1 flag_conflict_resolved: 由 life_conflict_reconcile 置位，被 bond_accept 消费(requireFlags)",
      fcr_set == {"life_conflict_reconcile"} and fcr_req == {"bond_accept"},
      f"setters={sorted(fcr_set)} requirers={sorted(fcr_req)}")

# 5.2 bond_misunderstood：被 bond_misunderstanding 引用 + 事件内 choice 置位 + 无死锁
bm = next((e for e in life_events if e.get("id") == "bond_misunderstanding"), None)
bm_refs = bm is not None and ("bond_misunderstood" in ev_flags["bond_misunderstanding"][1]
                              or "bond_misunderstood" in ev_flags["bond_misunderstanding"][2])
# 查找 bond_misunderstanding 内 choice 是否含 setFlag "bond_misunderstood"
def find_choice_setflag(node, target):
    if isinstance(node, dict):
        if node.get("setFlag") == target:
            return True
        if target in (node.get("setFlags") or []):
            return True
        return any(find_choice_setflag(v, target) for v in node.values())
    if isinstance(node, list):
        return any(find_choice_setflag(v, target) for v in node)
    return False

bm_choice_sets = bm is not None and find_choice_setflag(bm, "bond_misunderstood")
bm_setter_global = "bond_misunderstood" in glob_set  # 全局范围是否有任意置位者
check("5.2 bond_misunderstood: bond_misunderstanding 引用(require/exclude) + 内部 choice 置位 + 无死锁",
      bool(bm and bm_refs and bm_choice_sets and bm_setter_global),
      f"ref={bm_refs} choice_set={bm_choice_sets} global_setter={bm_setter_global}")

# 5.3 grad_* 事件：setFlag 必须位于 scenes 内（scene 级），而非仅事件顶层 —— 关键
GRAD = ["grad_yearbook", "grad_photo", "grad_dinner", "grad_lastclass"]
grad_ok = True
grad_detail = []
for gid in GRAD:
    ge = next((e for e in life_events if e.get("id") == gid), None)
    if ge is None:
        grad_ok = False
        grad_detail.append(f"{gid}=MISSING")
        continue
    # 事件顶层 setFlag（若存在，引擎不读取 → 死置位）
    top_set = ge.get("setFlag")
    # scenes 内 setFlag
    scene_sets = set()
    for sc in ge.get("scenes", []):
        if isinstance(sc, dict) and sc.get("setFlag"):
            scene_sets.add(sc.get("setFlag"))
        if isinstance(sc, dict) and sc.get("setFlags"):
            scene_sets.update(sc.get("setFlags"))
    has_scene_self = gid in scene_sets          # scene 级置位且等于自身 id
    no_top_self = (top_set != gid)              # 事件顶层没有以自身 id 置位（避免误以为靠顶层）
    ok = has_scene_self and no_top_self
    if not ok:
        grad_ok = False
    grad_detail.append(f"{gid}: scene_set(gid)={has_scene_self} top_set={top_set!r}")

check("5.3 grad_* 事件 setFlag 确在 scene 级（引擎仅读 scene 级；非仅事件顶层）",
      grad_ok,
      "; ".join(grad_detail))

# 5.4 引擎确实读取 scene 级 setFlag（静态确认 DialogueUI.gd）
engine_reads_scene = 'if scene.has("setFlag")' in du_src and 'unlock_gallery(scene["setFlag"])' in du_src
check("5.4 引擎 DialogueUI.gd 读取 scene 级 setFlag 并触发画廊解锁",
      engine_reads_scene,
      "L197-200 scene.has(setFlag)->set_flag+unlock_gallery" if engine_reads_scene else "未识别到 scene 级读取逻辑")


# ===========================================================================
# 断言 6 — 节日叙事接线
# ===========================================================================
m = re.search(r"fest_narrative_map\s*=\s*\{(.*?)\}", mg_src, re.S)
if not m:
    print("FATAL: fest_narrative_map 未在 MainGame.gd 找到"); sys.exit(1)
pairs = dict(re.findall(r'"(\w+)":\s*"(\w+)"', m.group(1)))
expected_map = {"new_year": "fest_newyear",
                "dragon_boat": "fest_dragonboat",
                "mid_autumn": "fest_midautumn",
                "teacher_day": "fest_teacherday"}
check("6.1 MainGame.gd fest_narrative_map 含 new_year/dragon_boat/mid_autumn/teacher_day 四键正确映射",
      pairs == expected_map,
      f"实际={pairs}" if pairs != expected_map else "四键映射正确")

life_id_set = {e.get("id") for e in life_events}
missing_fest = [fid for fid in expected_map.values() if fid not in life_id_set]
check("6.2 四 fest 事件(fest_newyear/fest_dragonboat/fest_midautumn/fest_teacherday) 存在于 events_life.json",
      not missing_fest,
      f"缺失: {missing_fest}" if missing_fest else "get_event_by_id 均可检索")


# ===========================================================================
# 断言 7 — SPECIAL_DATES 无冲突
# ===========================================================================
m = re.search(r"const\s+SPECIAL_DATES\s*=\s*\{(.*?)\n\s*\}", dc_src, re.S)
if not m:
    print("FATAL: SPECIAL_DATES 未在 DailyCycleManager.gd 找到"); sys.exit(1)
block = m.group(1)
day_map = {}        # day -> effect
day_banner = {}     # day -> banner
day_dup = []
for line in block.splitlines():
    mm = re.match(r'\s*(\d+):\s*\{(.*)\},?\s*$', line)
    if not mm:
        continue
    day = int(mm.group(1))
    inner = mm.group(2)
    eff = re.search(r'"effect":\s*"([^"]+)"', inner)
    ban = re.search(r'"banner":\s*"([^"]*)"', inner)
    if day in day_map:
        day_dup.append(day)
    day_map[day] = eff.group(1) if eff else ""
    day_banner[day] = ban.group(1) if ban else ""

check("7.1 SPECIAL_DATES 无重复 day key",
      not day_dup,
      f"重复 day: {day_dup}" if day_dup else f"共 {len(day_map)} 个特殊日期，day 唯一")

check("7.2 day240 effect == 'special'（文化节已恢复）",
      day_map.get(240) == "special",
      f"实际 day240 effect={day_map.get(240)!r}")

check("7.3 day330 effect == 'special'（白色情人节已恢复）",
      day_map.get(330) == "special",
      f"实际 day330 effect={day_map.get(330)!r}")

# exam 日集合（含 exam_sport）
exam_days = sorted(d for d, e in day_map.items() if e in ("exam", "exam_sport"))
p1_new_exam = {110, 210, 360}
missing_exam = sorted(p1_new_exam - set(exam_days))
check("7.4 P1 新增考日 {110,210,360} 均存在于 SPECIAL_DATES exam 集合",
      not missing_exam,
      f"exam 日集合={exam_days}; 缺失={missing_exam}" if missing_exam else f"exam 日集合={exam_days}")

# 同日冲突：exam × special/festival/break(free_day 视作 break 类)
cat_exam = set(exam_days)
cat_special = {d for d, e in day_map.items() if e == "special"}
cat_fest = {d for d, e in day_map.items() if e == "festival"}
cat_break = {d for d, e in day_map.items() if e in ("break", "free_day")}
conflict = (cat_exam & cat_special) | (cat_exam & cat_fest) | (cat_exam & cat_break) | \
          (cat_special & cat_fest) | (cat_special & cat_break) | (cat_fest & cat_break)
check("7.5 无 day 同时是 exam × special/festival/break（无同日冲突）",
      not conflict,
      f"冲突 day: {sorted(conflict)}" if conflict else "各分类 day 互不相交")


# ===========================================================================
# 断言 8 — 画廊映射一致
# ===========================================================================
def parse_gallery_entry(flag_name):
    """在 GameManager.gd 源中定位 GALLERY_ITEMS 内 flag==flag_name 的那一行，取 bg 与 flag。"""
    lines = py_src.splitlines()
    for ln in lines:
        if '"flag": "%s"' % flag_name in ln:
            f = re.search(r'"flag":\s*"([^"]+)"', ln)
            b = re.search(r'"bg":\s*"([^"]+)"', ln)
            return (f.group(1) if f else None, b.group(1) if b else None), ln
    return None, None

for gid, expect_bg in [("grad_photo", "res://assets/backgrounds/grad_photo.jpg"),
                       ("grad_yearbook", "res://assets/backgrounds/lakeside_evening.jpg")]:
    (flag_val, bg_val), raw = parse_gallery_entry(gid)
    exists = bg_val and os.path.exists(bg_to_fs(bg_val))
    ok = (flag_val == gid) and (bg_val == expect_bg) and exists
    check(f"8.{gid} GALLERY_ITEMS 含 flag='{gid}' 且 bg={expect_bg} 且文件存在",
          ok,
          f"flag={flag_val!r} bg={bg_val!r} file_exists={exists}"
          + ("" if exists else f" (缺失 {bg_to_fs(bg_val) if bg_val else 'N/A'})"))

# 8.3 画廊 flag 与 grad 事件 setFlag 同名（已在 5.3 验证置位；此处校验命名一致）
gal_flags = set()
for gid in ("grad_photo", "grad_yearbook"):
    (flag_val, _), _ = parse_gallery_entry(gid)
    if flag_val:
        gal_flags.add(flag_val)
same_name = gal_flags == set(GRAD[:2])
check("8.3 画廊 grad_photo/grad_yearbook 的 flag 与 grad 事件 setFlag 同名",
      same_name,
      f"画廊flag={sorted(gal_flags)} 期望={GRAD[:2]}")


# ===========================================================================
# 断言 9 — EVENT_FILES 注册（重复 1.1 的主断言，独立成条以便质量门单独计数）
# ===========================================================================
check("9 EVENT_FILES 含 'res://scripts/events_life.json'",
      "res://scripts/events_life.json" in event_files,
      "已注册" if "res://scripts/events_life.json" in event_files else "未注册")


# ===========================================================================
# 软校验（仅 WARN）
# ===========================================================================
# 所有 P1 事件都有 title（可读文案）
no_title = [e.get("id") for e in life_events if not e.get("title")]
if no_title:
    warn("存在 P1 事件缺少 title", str(no_title))
else:
    print("[INFO] 全部 P1 事件均含 title")

# grad 事件 triggerDay 落在毕业窗口（约 555-565），合理性观察
grad_days = {e.get("id"): e.get("triggerDay") for e in life_events if e.get("id") in GRAD}
print(f"[INFO] grad 事件 triggerDay: {grad_days}")


# ===========================================================================
# 汇总
# ===========================================================================
total = len(RESULTS)
passed = sum(1 for _, ok, _ in RESULTS if ok)
failed = total - passed

print("\n" + "=" * 64)
print(f"P1 SMOKE SUMMARY  total={total}  PASS={passed}  FAIL={failed}"
      + (f"  WARN={len(WARNINGS)}" if WARNINGS else ""))
print("=" * 64)
for name, ok, detail in RESULTS:
    mark = "ok " if ok else "XX "
    print(f"  {mark} {name}")
if WARNINGS:
    print("-- warnings --")
    for name, detail in WARNINGS:
        print(f"  ?? {name}: {detail}")

gate = "FAIL" if failed else ("CONCERNS" if WARNINGS else "PASS")
print(f"\nQUALITY GATE: {gate}")

sys.exit(1 if failed else 0)
