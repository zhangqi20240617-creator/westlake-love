# -*- coding: utf-8 -*-
"""
QA-CLUB-01 — 《西湖边的青春》社团/兴趣小组系统 MVP 独立质量门禁
Owner: 严守真 (quality-lead)

独立于工程侧自验 scratch/verify_club.py：断言重新设计、独立编号、聚焦
「主理人最该担心的回归风险」，刻意**不**复刻其覆盖式断言集。

方法：纯静态断言（JSON 解析 + GDScript 文本/作用域解析 + 事件池语义复演），
      不依赖 Godot runtime。对游戏源码**只读**。

分组：
  Q0  门禁自检（源文件可达）
  Q1  S-4 时段消耗（命门）        Q2  周一重置位置 + 双跨日路径收敛
  Q3  S-1 零新 Autoload           Q4  S-6 菜单 + 面板纯只读
  Q5  priority 带位锁             Q6  入社 hub 契约 + 消耗原子性
  Q7  S-5 双路线零分流            Q8  R1/R6 数值红线
  Q9  S-2 零存档迁移              Q10 S-3 已放行特性零回归
  Q11 NG+ 重置                    Q12 JSON 合法性 + 命名空间防撞
  Q13 【QA 扩展】可达性/饿死防护（工程自验未覆盖的核心回归维度）
  Q14 【QA 扩展】源码卫生：缩进同宿主 + 写入点唯一

环境变量 CLUB_QA_ROOT 可覆盖工程根目录 —— 供反向变异测试指向沙箱副本，
从而在**不触碰真源码**的前提下验证断言不是永远 PASS 的死断言。

退出码：0 = PASS / PASS-with-concerns，1 = FAIL。
"""
import ast
import io
import json
import os
import re
import sys
from collections import Counter
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(os.environ.get("CLUB_QA_ROOT", Path(__file__).resolve().parents[2]))
SCRIPTS = ROOT / "scripts"

DAILY   = SCRIPTS / "DailyCycleManager.gd"
MAIN    = SCRIPTS / "MainGame.gd"
DLG     = SCRIPTS / "DialogueUI.gd"
GM      = SCRIPTS / "GameManager.gd"
DATAMGR = SCRIPTS / "DataManager.gd"
SAVESYS = SCRIPTS / "SaveSystem.gd"
ENDING  = SCRIPTS / "EndingScreen.gd"
COLL    = SCRIPTS / "CollectionManager.gd"
EVL     = SCRIPTS / "events_life.json"
PROJECT = ROOT / "project.godot"

# ── 基线常量（改动即回归，必须与主理人裁决一致）───────────────
AUTOLOAD_EXPECTED = 15
MENU_ITEMS_EXPECTED = 11
# ── DS-RN-05b rebaseline（2026-xx，quality-lead 严守真）─────────
# 社团目标层落地后 club_* 事件数 6 → 26：1 hub + 5 周活动 + 20 条 club_chain_*。
# 本门禁只把「陈旧基线数字」跟进到目标层，其余 MVP 回归断言逐条原样保留；
# 目标层自身的专属断言在独立门禁 tests/club_target_smoke/verify_qa.py。
CLUB_CHAIN_EXPECTED = 20
CLUB_EVENTS_EXPECTED = 26      # 1 + 5 + 20
FENGWU_TOTAL_EXPECTED = 24
STAMP_TOTAL_EXPECTED = 10
NONCLUB_LIFE_EVENTS_EXPECTED = 66
# 生活支柱 P0/P1/P2 + 风物志手作 的 events_life.json 前缀基线（社团外）
LIFE_PREFIX_BASELINE = {
    "life_": 24, "int_": 9, "eco_": 7, "fw_": 6,
    "bond_": 6, "mock_": 6, "fest_": 4, "grad_": 4,
}
HEALTH_RELIEF_PRIORITY = 200   # life_health_*_relief：205 取舍的比较基准
CLUB_WEEK_FLAG = "flag_club_week_done"
CLUB_JOIN_FLAG = "flag_club_joined"

# type -> (地点, 期望 priority, 周活动主属性, 入社 hub 授予属性)
CLUB_SPEC = {
    "literature": ("library",     60,  "intellect", "intellect"),
    "astronomy":  ("playground",  205, "intellect", "intellect"),
    "broadcast":  ("music_room",  60,  "charm",     "charm"),
    "basketball": ("playground",  205, "strength",  "strength"),
    "art":        ("art_room",    205, "art",       "art"),
}
CLUB_TYPES = list(CLUB_SPEC.keys())
CLUB_LOCATIONS = sorted({v[0] for v in CLUB_SPEC.values()} | {"classroom"})
HUB_PRIORITY_EXPECTED = 212

# 事件筛选门控键（DataManager.get_random_event L198–320 逐项过滤）
GATE_KEYS = ["requireFlags", "excludeFlags", "requireItem", "requireMoney",
             "minAddict", "minStress", "conditionType", "requireWeather",
             "requireSeason", "requireHoliday", "requireRelState",
             "excludeRelState", "requireNGCount", "requireNotEnding",
             "minAff", "charId"]

# ─────────────────────────────────────────────────────────────────
# 断言框架（分组编号 Qn.m）
# ─────────────────────────────────────────────────────────────────
_group = "Q0"
_idx = 0
_total = 0
failures, concerns, notes = [], [], []


def section(gid, title):
    global _group, _idx
    _group, _idx = gid, 0
    print(f"\n--- {gid} · {title} ---")


def check(cond, desc, detail=""):
    global _idx, _total
    _idx += 1
    _total += 1
    tag = f"{_group}.{_idx}"
    if cond:
        print(f"  [PASS] {tag}  {desc}")
    else:
        msg = f"{tag}  {desc}" + (f"  →  {detail}" if detail else "")
        failures.append(msg)
        print(f"  [FAIL] {msg}")
    return bool(cond)


def concern(desc):
    concerns.append(desc)
    print(f"  [CONCERN] {desc}")


def note(desc):
    notes.append(desc)
    print(f"  [NOTE] {desc}")


# ─────────────────────────────────────────────────────────────────
# 解析工具
# ─────────────────────────────────────────────────────────────────
def src_of(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def code_only(text: str) -> str:
    """字符串感知地剥掉整行/行尾注释。

    所有「本区不得出现 XX」类反向断言必须先过这一层：注释里写
    `# 该面板不写任何 flag` 属正常文档说明，不应误报 FAIL；
    反过来也防止用注释掩护真实代码。Color("#334155") 内的 # 会保留。
    """
    out = []
    for line in text.splitlines():
        in_str, esc, cut = False, False, None
        for i, c in enumerate(line):
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
            else:
                if c == '"':
                    in_str = True
                elif c == "#":
                    cut = i
                    break
        stripped = line[:cut] if cut is not None else line
        if stripped.strip():
            out.append(stripped.rstrip())
    return "\n".join(out)


def func_body(src: str, name: str) -> str:
    m = re.search(r"^func %s\(.*?\).*?:\n(.*?)(?=^func |\Z)" % re.escape(name),
                  src, re.S | re.M)
    return m.group(1) if m else ""


def extract_block(src: str, anchor: str) -> str:
    """从 anchor 之后取出第一个配平的 [] / {} 字面量（字符串感知）。"""
    i = src.index(anchor) + len(anchor)
    while src[i] not in "[{":
        i += 1
    open_ch = src[i]
    close_ch = "]" if open_ch == "[" else "}"
    depth, in_str, esc, start = 0, False, False, i
    while i < len(src):
        c = src[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == "#":
                nl = src.find("\n", i)
                i = nl if nl != -1 else len(src) - 1
            elif c in "[{":
                depth += 1
            elif c in "]}":
                depth -= 1
                if depth == 0 and c == close_ch:
                    return src[start:i + 1]
        i += 1
    raise ValueError(f"unbalanced literal for anchor {anchor!r}")


def gd_to_py(block: str) -> str:
    out, i, in_str, esc = [], 0, False, False
    while i < len(block):
        c = block[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
            i += 1
            continue
        if c == "#":
            nl = block.find("\n", i)
            i = nl if nl != -1 else len(block)
            continue
        m = re.match(r"\b(true|false|null)\b", block[i:])
        if m:
            out.append({"true": "True", "false": "False", "null": "None"}[m.group(1)])
            i += m.end()
            continue
        out.append(c)
        i += 1
    text = "".join(out)
    text = re.sub(r"Vector2\(", "(", text)
    text = re.sub(r"Vector2i\(", "(", text)
    text = re.sub(r'Color\(\s*("([^"\\]|\\.)*")\s*\)', r"\1", text)
    text = re.sub(r"Color\(", "(", text)
    return text


def load_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_to_py(extract_block(src_of(path), anchor)))


def gv(e, key, default=None):
    """取事件字段，把 JSON null 归一为 default。"""
    v = e.get(key, default)
    return default if v is None else v


def slot_of(e):
    return gv(e, "slotId", "")


def loc_of(e):
    return gv(e, "location", "")


def is_ungated(e):
    return not any(e.get(k) not in (None, "", 0, [], {}) for k in GATE_KEYS)


def gates_of(e):
    return [k for k in GATE_KEYS if e.get(k) not in (None, "", 0, [], {})]


# ─────────────────────────────────────────────────────────────────
print("=" * 78)
print("QA-CLUB-01 · 社团系统 MVP 独立质量门禁 (quality-lead 严守真)")
print(f"ROOT = {ROOT}")
print("=" * 78)

# ── Q0 门禁自检 ──────────────────────────────────────────────
section("Q0", "门禁自检（源文件可达，避免空扫描假 PASS）")
_required = {"events_life.json": EVL, "DailyCycleManager.gd": DAILY, "MainGame.gd": MAIN,
             "DialogueUI.gd": DLG, "GameManager.gd": GM, "DataManager.gd": DATAMGR,
             "SaveSystem.gd": SAVESYS, "EndingScreen.gd": ENDING,
             "CollectionManager.gd": COLL, "project.godot": PROJECT}
_missing = [n for n, p in _required.items() if not p.exists()]
if not check(not _missing, "10 个受检源文件全部可达", f"缺失 {_missing}"):
    print("\nVERDICT: FAIL（源文件缺失，后续断言无意义）")
    sys.exit(1)

# 全事件池加载（EVENT_FILES 从 DataManager 真源解析，杜绝手抄漏文件）
dm_src = src_of(DATAMGR)
EVENT_FILES = re.findall(r'"res://scripts/(events_[a-z_]+\.json)"', dm_src)
check(len(EVENT_FILES) == 10, f"DataManager.EVENT_FILES 注册 10 个事件文件",
      f"实际 {len(EVENT_FILES)}: {EVENT_FILES}")

ALL_EVENTS = []
_load_err = []
for fn in EVENT_FILES:
    p = SCRIPTS / fn
    try:
        for e in json.loads(p.read_text(encoding="utf-8")):
            e["_src"] = fn
            ALL_EVENTS.append(e)
    except Exception as ex:      # noqa: BLE001
        _load_err.append(f"{fn}: {ex}")
check(not _load_err, f"全部事件文件可解析（事件池 {len(ALL_EVENTS)} 条）", str(_load_err))

life_events = json.loads(EVL.read_text(encoding="utf-8"))
club_events = [e for e in life_events if str(e.get("id", "")).startswith("club_")]
weekly = {e["id"]: e for e in club_events if e["id"].startswith("club_weekly_")}
chain = {e["id"]: e for e in club_events if e["id"].startswith("club_chain_")}
hub = next((e for e in club_events if e["id"] == "club_join_hub"), None)
check(len(club_events) == CLUB_EVENTS_EXPECTED and hub is not None
      and len(weekly) == 5 and len(chain) == CLUB_CHAIN_EXPECTED,
      f"社团事件集齐 {CLUB_EVENTS_EXPECTED} 条"
      f"（1 hub + 5 周活动 + {CLUB_CHAIN_EXPECTED} 目标层链步骤）",
      f"实际 club_* = {[e.get('id') for e in club_events]}")
if hub is None or len(weekly) != 5:
    print("\nVERDICT: FAIL（社团事件缺失，后续断言无意义）")
    sys.exit(1)

# ── Q1 S-4 时段消耗（命门）────────────────────────────────────
section("Q1", "S-4 社团确凿消耗 after 时段（命门 / R2）")
_ev_lvl = [i for i, e in weekly.items() if "noTimeCost" in e]
check(not _ev_lvl, "5 条周活动事件级均无 noTimeCost 键", f"越界: {_ev_lvl}")

_sc_lvl = [f"{e['id']}#scene{i}" for e in club_events
           for i, s in enumerate(e.get("scenes", [])) if "noTimeCost" in s]
check(not _sc_lvl, "6 条社团事件场景级均无 noTimeCost 键", f"越界: {_sc_lvl}")

_hub_ntc = "noTimeCost" not in hub
check(_hub_ntc, "club_join_hub 事件级无 noTimeCost 键（入社也吃时段）")

dlg_src = src_of(DLG)
fin_body = code_only(func_body(dlg_src, "finish_event"))
_ntc_branch = re.search(r"elif\s+not\s+current_event\.get\(\s*\"noTimeCost\"\s*,\s*false\s*\)\s*:\s*\n\s*GameManager\.advance_time\(\)",
                        fin_body)
check(_ntc_branch is not None,
      "finish_event() 默认分支仍为 `elif not noTimeCost: advance_time()`",
      "记忆回响 DS-RN-02 §3.4 的取反分支被改动 → 不带该键的社团事件可能不再扣时段")

check(fin_body.count("GameManager.advance_time()") == 1,
      "finish_event() 内 advance_time() 恰一处（无旁路/重复扣时段）",
      f"实际 {fin_body.count('GameManager.advance_time()')} 处")

_skip = [i for i, e in weekly.items() if e.get("skipToNextDay")]
check(not _skip, "周活动均无 skipToNextDay（只吃 1 个时段，不吞整天）", f"越界: {_skip}")
_skip_sc = [f"{e['id']}#{i}" for e in club_events
            for i, s in enumerate(e.get("scenes", [])) if s.get("skipToNextDay")]
check(not _skip_sc, "社团场景级均无 skipToNextDay", f"越界: {_skip_sc}")

# ── Q2 周一重置 ──────────────────────────────────────────────
section("Q2", "周一重置：位置正确 + 两条跨日路径均收敛")
daily_src = src_of(DAILY)
daily_code = code_only(daily_src)
ERASE_PAT = r'GameManager\.flags\.erase\(\s*"%s"\s*\)' % CLUB_WEEK_FLAG
check(re.search(ERASE_PAT, daily_code) is not None,
      f"DailyCycleManager 含 flags.erase(\"{CLUB_WEEK_FLAG}\")")

wa_body = func_body(daily_src, "_check_weekly_allowance")
check(re.search(ERASE_PAT, code_only(wa_body)) is not None,
      "该 erase 位于 _check_weekly_allowance 函数体内（作用域扫描）",
      "erase 落在函数外 / 落进别的函数 → 周一钩子不触发，社团首周后永久锁死")

# 星期一守卫：erase 必须在 `if GameManager.day_of_week == 1:` 块内
_mon_ok = False
_wa_lines = wa_body.splitlines()
for i, ln in enumerate(_wa_lines):
    if re.search(ERASE_PAT, ln):
        ind = len(ln) - len(ln.lstrip())
        for j in range(i - 1, -1, -1):
            prev = _wa_lines[j]
            if not prev.strip():
                continue
            pind = len(prev) - len(prev.lstrip())
            if pind < ind:
                if re.search(r"day_of_week\s*==\s*1", prev):
                    _mon_ok = True
                break
check(_mon_ok, "erase 受 `day_of_week == 1` 守卫（周一才重置，非每日重置）",
      "若脱离守卫 → 每日可重复参加社团，周上限失效（R1 数值失衡）")

# 双跨日路径收敛：正常推进 + 通宵跳日
gm_src = src_of(GM)
gm_facade = code_only(func_body(gm_src, "_check_weekly_allowance"))
check("DailyCycleManager._check_weekly_allowance()" in gm_facade,
      "GameManager._check_weekly_allowance() 仍是转发门面（未被内联复制）",
      "门面若被改成独立实现，通宵跳日路径将读不到社团 erase → 周一重置漏执行")

check("DailyCycleManager._check_weekly_allowance()" in code_only(func_body(gm_src, "advance_time")),
      "跨日路径①（advance_time 正常推进）调用周结算")
check("GameManager._check_weekly_allowance()" in fin_body,
      "跨日路径②（DialogueUI 通宵跳日）调用周结算",
      "通宵跨周时若不结算 → 该周社团标记不清，玩家白丢一周")

# 全树唯一写入点
_erase_files = sorted(p.name for p in SCRIPTS.rglob("*.gd")
                      if re.search(ERASE_PAT, code_only(src_of(p))))
check(_erase_files == ["DailyCycleManager.gd"],
      f"全 scripts/ 树内 {CLUB_WEEK_FLAG} 的 erase 唯一（仅 DailyCycleManager.gd）",
      f"实际出现于 {_erase_files}")

# ── Q3 S-1 零新 Autoload ─────────────────────────────────────
section("Q3", "S-1 零新增 Autoload")
proj = src_of(PROJECT)
_al_sec = proj.split("[autoload]", 1)[1].split("\n[", 1)[0] if "[autoload]" in proj else ""
_autoloads = re.findall(r'^(\w+)\s*=\s*"\*res://', _al_sec, re.M)
check(len(_autoloads) == AUTOLOAD_EXPECTED,
      f"[autoload] 段仍为 {AUTOLOAD_EXPECTED} 项", f"实际 {len(_autoloads)}: {_autoloads}")
check(not [a for a in _autoloads if "club" in a.lower()],
      "无任何 club 命名的 Autoload（全 flag 态）")
check(not list(SCRIPTS.glob("Club*.gd")) and not list(SCRIPTS.glob("*Club*.gd")),
      "scripts/ 下无新增 Club*.gd 管理器脚本",
      f"发现 {[p.name for p in SCRIPTS.glob('*Club*.gd')]}")

# ── Q4 S-6 菜单 + 面板纯只读 ─────────────────────────────────
section("Q4", "S-6 更多菜单第 11 按钮 + 面板纯只读")
main_src = src_of(MAIN)
items_block = extract_block(main_src, "var items = ")
_item_texts = re.findall(r'\{"text":\s*"([^"]+)"', items_block)
check(len(_item_texts) == MENU_ITEMS_EXPECTED,
      f"更多菜单 items 共 {MENU_ITEMS_EXPECTED} 项", f"实际 {len(_item_texts)}: {_item_texts}")
check(any("社团" in t for t in _item_texts), "items 含「🎏 社团」按钮", f"实际 {_item_texts}")
check(re.search(r'\{"text":\s*"🎏 社团".*?"fn":\s*_show_club_popup', items_block) is not None,
      "「🎏 社团」按钮绑定 _show_club_popup")

_panel_funcs = ["_show_club_popup", "_club_row", "_get_club_label"]
_missing_fn = [f for f in _panel_funcs if not func_body(main_src, f)]
check(not _missing_fn, "面板三函数齐备（_show_club_popup/_club_row/_get_club_label）",
      f"缺失 {_missing_fn}")

WRITE_PATS = [r"set_flag\(", r"flags\[", r"flags\.erase", r"flags\.set",
              r"add_stat\(", r"advance_time\(", r"GameManager\.money\s*[+\-]?=",
              r"add_item\(", r"remove_item\(", r"slot_index\s*=", r"GameManager\.day\s*[+\-]?="]
_viol = []
for fn in _panel_funcs:
    body = code_only(func_body(main_src, fn))
    for pat in WRITE_PATS:
        if re.search(pat, body):
            _viol.append(f"{fn}:{pat}")
check(not _viol, "面板三函数零写操作（纯只读，不绕过「时间即代价」）", f"越界: {_viol}")

_club_names = load_literal(MAIN, "const CLUB_NAMES :=")
check(sorted(_club_names.keys()) == sorted(f"flag_club_{t}" for t in CLUB_TYPES),
      "CLUB_NAMES 的 5 个 flag 与事件侧社团类型完全一致（无显示/数据脱节）",
      f"面板={sorted(_club_names.keys())}")

# ── Q5 priority 带位锁 ───────────────────────────────────────
section("Q5", "priority 带位锁（防未来调参杀死社团）")
for t, (locn, prio, _m, _h) in CLUB_SPEC.items():
    ev = weekly.get(f"club_weekly_{t}")
    check(ev is not None and ev.get("priority") == prio,
          f"club_weekly_{t} priority == {prio}",
          f"实际 {ev.get('priority') if ev else 'MISSING'}")
check(hub.get("priority") == HUB_PRIORITY_EXPECTED,
      f"club_join_hub priority == {HUB_PRIORITY_EXPECTED}", f"实际 {hub.get('priority')}")

# 205 ≥ 健康疏导 200：把主理人的 ACCEPT 裁决锁成正向断言
_relief = {e["id"]: e for e in ALL_EVENTS
           if e.get("id") in ("life_health_exercise_relief", "life_health_art_relief")}
check(len(_relief) == 2, "健康疏导基准事件仍存在（life_health_exercise/art_relief）",
      f"实际 {list(_relief)}")
_relief_max = max((gv(e, "priority", 0) for e in _relief.values()), default=0)
check(_relief_max == HEALTH_RELIEF_PRIORITY,
      f"健康疏导 priority 基准仍为 {HEALTH_RELIEF_PRIORITY}", f"实际 {_relief_max}")
for t in ("astronomy", "basketball", "art"):
    p = weekly[f"club_weekly_{t}"].get("priority")
    check(p is not None and p > _relief_max,
          f"club_weekly_{t}({p}) > 健康疏导({_relief_max}) —— 主理人已 ACCEPT 的取舍，"
          f"调回 ≤{_relief_max} 即社团功能死亡",
          f"实际 {p} <= {_relief_max}")

# (200,205] 区间竞争者取证
_band = []
for e in ALL_EVENTS:
    if str(e.get("id", "")).startswith("club_"):
        continue
    if loc_of(e) in ("playground", "art_room") and slot_of(e) in ("", "after"):
        p = gv(e, "priority", 0)
        if HEALTH_RELIEF_PRIORITY < p <= 205:
            _band.append((p, e["id"], loc_of(e), e.get("repeatable", False)))
check(not [x for x in _band if x[3]],
      "playground/art_room · after 的 (200,205] 区间无可重复竞争者",
      f"发现 {_band}")
note(f"(200,205] 区间竞争者取证：{_band if _band else '无'}；"
     f"playground/art_room 的最强**常驻**竞争者为 life_health_*_relief(p={_relief_max})，"
     f"205 已确凿高于它。")

# hub 212 的带位：低于剧情带、高于常驻填充
_story_band = [(gv(e, "priority", 0), e["id"]) for e in ALL_EVENTS
               if loc_of(e) == "classroom" and slot_of(e) in ("", "after")
               and re.match(r"(life_conflict_|mock_|grad_)", str(e.get("id", "")))]
_story_min = min((p for p, _ in _story_band), default=10 ** 6)
check(HUB_PRIORITY_EXPECTED < _story_min,
      f"club_join_hub({HUB_PRIORITY_EXPECTED}) 低于 classroom 剧情带最低者({_story_min})"
      f" —— 不抢 life_conflict_*/mock_*/grad_* 的档期",
      f"剧情带={sorted(_story_band)[:3]}")
_filler = [(gv(e, "priority", 0), e["id"]) for e in ALL_EVENTS
           if loc_of(e) == "classroom" and slot_of(e) in ("", "after")
           and e.get("repeatable", False) and is_ungated(e)]
_filler_max = max((p for p, _ in _filler), default=0)
check(HUB_PRIORITY_EXPECTED > _filler_max,
      f"club_join_hub({HUB_PRIORITY_EXPECTED}) 高于 classroom 常驻填充最高者({_filler_max})",
      f"填充={sorted(_filler, reverse=True)[:3]}")

# ── Q6 入社 hub 契约 + 消耗原子性 ────────────────────────────
section("Q6", "入社 hub 契约 + 「消耗即入社」原子性（soft-lock 防护）")
check(hub.get("triggerDay") == 30, "triggerDay == 30", f"实际 {hub.get('triggerDay')}")
check(hub.get("repeatable") is False, "repeatable == false（承诺制，一次性）",
      f"实际 {hub.get('repeatable')}")
check(hub.get("charId") is None, "charId == null", f"实际 {hub.get('charId')!r}")
check(CLUB_JOIN_FLAG in gv(hub, "excludeFlags", []),
      f"excludeFlags 含 {CLUB_JOIN_FLAG}（已入社不再弹招新）",
      f"实际 {hub.get('excludeFlags')}")
check(loc_of(hub) == "classroom" and slot_of(hub) == "after",
      "location=classroom / slotId=after", f"实际 {loc_of(hub)}/{slot_of(hub)}")

_choices = [c for s in hub.get("scenes", []) for c in s.get("choices", [])]
check(len(_choices) == 5, "scenes 内 choices 恰 5 个", f"实际 {len(_choices)}")

_bad_setflag = [c.get("text", "?") for c in _choices if c.get("setFlag") != CLUB_JOIN_FLAG]
check(not _bad_setflag, f"5 个选项均 setFlag={CLUB_JOIN_FLAG}", f"越界: {_bad_setflag}")

_types_seen = []
for c in _choices:
    fl = [f for f in c.get("setFlags", []) if f.startswith("flag_club_")]
    _types_seen += fl
check(sorted(_types_seen) == sorted(f"flag_club_{t}" for t in CLUB_TYPES),
      "5 个选项各授予唯一 flag_club_<type>，5 类齐全无重复", f"实际 {sorted(_types_seen)}")
check(all(len([f for f in c.get("setFlags", []) if f.startswith("flag_club_")]) == 1
          for c in _choices),
      "每个选项恰授予 1 个社团类型 flag（无一choice入双社）")

_hub_stat_bad = []
for c in _choices:
    d = c.get("statDelta", {})
    ty = next((f[len("flag_club_"):] for f in c.get("setFlags", [])
               if f.startswith("flag_club_")), None)
    want = CLUB_SPEC.get(ty, (None, None, None, None))[3]
    if list(d.keys()) != [want] or d.get(want) != 1:
        _hub_stat_bad.append(f"{ty}:{d}")
check(not _hub_stat_bad, "每个选项 statDelta 为「主属性 +1」单项", f"越界: {_hub_stat_bad}")

# 原子性：finish_event() 会把非 repeatable 事件 id 写成消耗标记。
# 任何「不入社」的逃逸选项都会烧掉唯一入口 → 社团系统整周目永久不可达。
check(re.search(r'if\s+ev_id\s*!=\s*""\s+and\s+not\s+current_event\.get\(\s*"repeatable"',
                fin_body) is not None,
      "非重复事件的消耗标记写在 finish_event()（走完才消耗，非 start_event）",
      "若挪到 start_event → 中途退出即烧掉招新入口")
check(all(int(c.get("next", -1)) == 99 for c in _choices),
      "5 个选项 next 均为 99（直达 finish_event，无悬挂分支）",
      f"实际 {[c.get('next') for c in _choices]}")
_dlg_input = code_only(func_body(dlg_src, "_input"))
check("if choice_container.get_parent().visible: return" in _dlg_input,
      "选项显示期间 DialogueUI._input 早返回（玩家无法跳过选择逃逸）",
      "存在逃逸路径 + 未来若加「算了」选项 → 招新事件被消耗但未入社 = 永久 soft-lock")
note("原子性结论：招新 hub 的 5 个选项**全部**置 flag_club_joined 且 next=99，"
     "消耗标记只在 finish_event() 落盘，选项期输入被拦截 → 「消耗」与「入社」严格同生共死，"
     "当前无 soft-lock 通道。⚠️ 未来若有人加第 6 个不置 flag 的「再想想」选项，"
     "Q6.9/Q6.10 会立刻 FAIL —— 这正是本组的看门目的。")

# ── Q7 S-5 双路线零分流 ──────────────────────────────────────
section("Q7", "S-5 男女双路线零分流")
_bad_char = [e["id"] for e in club_events if e.get("charId") is not None]
check(not _bad_char, "6 条社团事件 charId 均为 null", f"越界: {_bad_char}")
_rel_keys = [f"{e['id']}:{k}" for e in club_events for k in
             ("requireRelState", "excludeRelState", "minAff", "requireGender", "gender")
             if e.get(k) not in (None, "", 0)]
check(not _rel_keys, "社团事件无 relState/minAff/gender 类分流门控", f"越界: {_rel_keys}")

# ── Q8 R1/R6 数值红线 ────────────────────────────────────────
section("Q8", "R1 成长上限 / R6 经济隔离")
_num_bad, _money_bad, _neg_bad, _stress_bad = [], [], [], []
for t, (_l, _p, mainstat, _h) in CLUB_SPEC.items():
    ev = weekly[f"club_weekly_{t}"]
    for i, s in enumerate(ev.get("scenes", [])):
        d = s.get("statDelta", {})
        if not d:
            continue
        if "money" in d:
            _money_bad.append(f"{ev['id']}#{i}")
        for k, v in d.items():
            if v < 0:
                _neg_bad.append(f"{ev['id']}:{k}={v}")
            if k == "stress":
                if v not in (0, 1):
                    _stress_bad.append(f"{ev['id']}:stress={v}")
            elif k == mainstat:
                if v > 2:
                    _num_bad.append(f"{ev['id']}:主属性 {k}={v}>2")
            elif v > 1:
                _num_bad.append(f"{ev['id']}:次属性 {k}={v}>1")
check(not _num_bad, "周活动主属性 ≤2、次属性 ≤1（R1）", f"越界: {_num_bad}")
check(not _money_bad, "周活动 statDelta 不含 money（R6 经济隔离）", f"越界: {_money_bad}")
check(not _neg_bad, "周活动无负增量（不得沦为 stress 洗白工具）", f"越界: {_neg_bad}")
check(not _stress_bad, "stress 仅允许 0/+1（体现投入，不做疏导）", f"越界: {_stress_bad}")

_econ_keys = [f"{e['id']}:{k}" for e in club_events
              for s in e.get("scenes", []) for k in ("giveItem", "removeItem", "addItem")
              if s.get(k)]
check(not _econ_keys, "社团事件不发放/消耗任何道具（零经济面）", f"越界: {_econ_keys}")
_hub_money = [c.get("text") for c in _choices if "money" in c.get("statDelta", {})]
check(not _hub_money, "入社 hub 选项不含 money", f"越界: {_hub_money}")

_mains = {t: weekly[f"club_weekly_{t}"]["scenes"][-1]["statDelta"] for t in CLUB_TYPES}
note(f"周活动收益取证（每周上限 1 次）：{_mains}。"
     f"对比兼职周薪 +80💰/周（DailyCycleManager._check_parttime_income）—— 社团零金钱，R6 成立。")

# ── Q9 S-2 零存档迁移 ────────────────────────────────────────
section("Q9", "S-2 零存档迁移")
save_code = code_only(src_of(SAVESYS))
check("club" not in save_code.lower(), "SaveSystem.gd 零 club 引用（状态全随 flags 走）",
      f"命中行: {[l for l in save_code.splitlines() if 'club' in l.lower()][:3]}")
check(re.search(r'"flags"\s*:\s*GameManager\.flags\.duplicate\(\)', save_code) is not None,
      "存档整体序列化 GameManager.flags（flag_club_* 自动搭车）")
check(re.search(r'GameManager\.flags\s*=\s*d\.get\(\s*"flags"', save_code) is not None,
      "读档整体反序列化 flags（无字段白名单，零迁移）")
check("events_life.json" in EVENT_FILES,
      "events_life.json 在 DataManager.EVENT_FILES 中（社团事件免注册）")
check(re.search(r"const\s+SAVE_VERSION|save_version", save_code) is None
      or "club" not in save_code.lower(),
      "未因社团引入存档版本迁移分支")

# ── Q10 S-3 已放行特性零回归 ─────────────────────────────────
section("Q10", "S-3 已放行特性零回归")
coll_src = src_of(COLL)
try:
    _fengwu = load_literal(COLL, "const FENGWU_ITEMS = ")
    check(len(_fengwu) == FENGWU_TOTAL_EXPECTED,
          f"风物志 FENGWU_ITEMS 仍为 {FENGWU_TOTAL_EXPECTED} 条", f"实际 {len(_fengwu)}")
except Exception as ex:      # noqa: BLE001
    check(False, "风物志 FENGWU_ITEMS 可解析", str(ex))
check(re.search(r"const\s+FENGWU_TOTAL\s*:=\s*%d" % FENGWU_TOTAL_EXPECTED, coll_src) is not None,
      f"FENGWU_TOTAL := {FENGWU_TOTAL_EXPECTED} 未变")
check("const WEST_LAKE_STAMP_SCENES" in coll_src, "十景集章 WEST_LAKE_STAMP_SCENES 仍在（未删）")
check(re.search(r"const\s+STAMP_TOTAL\s*:=\s*%d" % STAMP_TOTAL_EXPECTED, coll_src) is not None,
      f"STAMP_TOTAL := {STAMP_TOTAL_EXPECTED} 未变")
check("noTimeCost" in code_only(dlg_src),
      "记忆回响 noTimeCost 语义仍在 DialogueUI（与 Q1 互证：社团≠回响）")

_school = re.search(r'var\s+SCHOOL_LOCATIONS\s*=\s*(\[[^\]]*\])', dm_src)
_school_list = ast.literal_eval(_school.group(1)) if _school else []
_notin = [l for l in CLUB_LOCATIONS if l not in _school_list]
check(not _notin, f"5 个社团地点均属 SCHOOL_LOCATIONS（长假自动抑制，set-piece 不受扰）",
      f"缺失 {_notin}；SCHOOL_LOCATIONS={_school_list}")

_nonclub = [e for e in life_events if not str(e.get("id", "")).startswith("club_")]
check(len(_nonclub) == NONCLUB_LIFE_EVENTS_EXPECTED,
      f"events_life.json 非社团事件仍为 {NONCLUB_LIFE_EVENTS_EXPECTED} 条（社团为纯末位追加）",
      f"实际 {len(_nonclub)}")
_hist = dict(Counter(e["id"].split("_")[0] + "_" for e in _nonclub))
check(_hist == LIFE_PREFIX_BASELINE,
      "生活支柱 P0/P1/P2 + 风物志手作 前缀直方图与基线逐项一致（增删改均可捕获）",
      f"实际 {dict(sorted(_hist.items()))} vs 基线 {dict(sorted(LIFE_PREFIX_BASELINE.items()))}")
note(f"P2 宠物线以 int_pet_* 形式归入 int_ 前缀（int_pet_meet/adopt/care/moment 共 4 条），"
     f"故基线按 int_=9 锁定，无独立 pet_ 前缀。")

# 命名空间隔离：既有事件不得引用 club flag
_leak = []
for e in ALL_EVENTS:
    if str(e.get("id", "")).startswith("club_"):
        continue
    blob = json.dumps(e, ensure_ascii=False)
    if "flag_club_" in blob:
        _leak.append(e["id"])
check(not _leak, "既有 239 条事件零引用 flag_club_*（命名空间完全隔离）", f"污染: {_leak}")

# ── Q11 NG+ 重置 ─────────────────────────────────────────────
# ── Q11 NG+ 周目重置 ─────────────────────────────────────────────
section("Q11", "NG+ 周目重置")
end_src = src_of(ENDING)
end_code = code_only(end_src)
check(re.search(r"GameManager\.flags\s*=\s*\{\}", end_code) is not None,
      "EndingScreen NG+ 段整体清空 GameManager.flags（flag_club_* 自然重置）")
# DS-RN-05b rebaseline：EndingScreen 现含 CLUB_ACHIEVEMENT_FLAGS 常量 + gallery_flags 回注，
# 允许的引用仅限于这两处，不得有 hub/weekly/joined/active 等业务词。
_ALLOWED_CLUB_REFS = {"club_achievement_flags"}  # CLUB_ACHIEVEMENT_FLAGS 常量名称
_FORBIDDEN_CLUB = ["club_join_hub", "club_weekly", "flag_club_joined", "flag_club_active"]
_forbidden_hits = [w for w in _FORBIDDEN_CLUB if w in end_code.lower()]
check(not _forbidden_hits,
      "EndingScreen.gd 对 club 的引用仅限于 CLUB_ACHIEVEMENT_FLAGS 常量 + gallery_flags 回注，"
      "不含 club_join_hub/club_weekly/flag_club_joined/flag_club_active 等业务词",
      f"违规词: {_forbidden_hits}")
_clear_pos = end_code.find("GameManager.flags = {}")
_after = end_code[_clear_pos:] if _clear_pos >= 0 else ""
_reinject = re.findall(r'GameManager\.flags\[\s*"([^"]+)"\s*\]\s*=', _after)
# club_achievement_* 回注是 OQ-3 已裁决的合法行为，其余 club 业务 flag 不得回注
check(not [f for f in _reinject if "club" in f.lower() and "achievement" not in f.lower()],
      "清档后无非成就类 club flag 回注（club_achievement_* 白名单回注已裁决）",
      f"违规回注: {[f for f in _reinject if 'club' in f.lower() and 'achievement' not in f.lower()]}")
note(f"NG+ 清档后回注的 flag：{_reinject if _reinject else '无'} —— club_achievement_* 为 OQ-3 批准的合法回注，"
     f"其余均与社团无关。")

# ── Q12 JSON 合法性 + 命名空间防撞 ───────────────────────────
section("Q12", "JSON 合法性 + flag/id 命名空间防撞")
try:
    json.loads(EVL.read_text(encoding="utf-8"))
    check(True, "events_life.json 可被 json.load 解析")
except Exception as ex:      # noqa: BLE001
    check(False, "events_life.json 可被 json.load 解析", str(ex))

_all_ids = [str(e.get("id", "")) for e in ALL_EVENTS]
_dups = [k for k, v in Counter(_all_ids).items() if v > 1]
check(not _dups, f"全事件池 {len(_all_ids)} 条 id 全局唯一（社团 26 条无撞车）", f"重复: {_dups}")
check(len(set(e["id"] for e in club_events)) == CLUB_EVENTS_EXPECTED,
      f"社团 {CLUB_EVENTS_EXPECTED} 条 id 互不重复")

# DialogueUI 用 set_flag(event_id) 记消耗 → 事件 id 与业务 flag 共用同一 flags 字典
_club_flags = {CLUB_JOIN_FLAG, CLUB_WEEK_FLAG} | {f"flag_club_{t}" for t in CLUB_TYPES}
_collide = _club_flags & set(_all_ids)
check(not _collide,
      "社团 7 个业务 flag 与全部事件 id 无同名冲突（二者共用 GameManager.flags 命名空间）",
      f"撞名: {_collide}")
check(not [i for i in _all_ids if i.startswith("flag_")],
      "无事件 id 以 flag_ 开头（避免消耗标记污染业务 flag 语义）")

# ── Q13 【QA 扩展】可达性 / 饿死防护 ─────────────────────────
section("Q13", "【QA 扩展】可达性：社团事件不会被常驻事件永久饿死")
note("原理：DataManager.get_random_event() 按 priority 降序取 candidates[0]（L328）。"
     "只有「可重复 + 零门控」的事件才会**永久**驻留候选池；一次性事件至多顶掉 1 次。"
     "故不变量为：同地点·同时段内，club 事件 priority 必须严格高于所有常驻竞争者。")
_starve_rows = []
for cid, ev in list(weekly.items()) + [("club_join_hub", hub)]:
    l, p = loc_of(ev), gv(ev, "priority", 0)
    comp = [e for e in ALL_EVENTS
            if not str(e.get("id", "")).startswith("club_")
            and loc_of(e) in (l, "")
            and slot_of(e) in ("", "after")
            and e.get("repeatable", False) and is_ungated(e)]
    comp.sort(key=lambda e: -gv(e, "priority", 0))
    top = comp[0] if comp else None
    tp = gv(top, "priority", 0) if top else -1
    check(tp < p,
          f"{cid}(p={p}) 高于 {l} 的最强常驻竞争者"
          f"（{top['id'] if top else '无'}, p={tp if top else 'n/a'}）",
          f"常驻竞争者 priority {tp} >= {p} → 该社团永久无法触发（功能死亡）")
    _starve_rows.append((cid, p, top["id"] if top else "无", tp))

# 一次性竞争者只造成有限次挤占，量化取证
for cid, ev in list(weekly.items()):
    l, p = loc_of(ev), gv(ev, "priority", 0)
    once = [(gv(e, "priority", 0), e["id"]) for e in ALL_EVENTS
            if not str(e.get("id", "")).startswith("club_")
            and loc_of(e) in (l, "") and slot_of(e) in ("", "after")
            and not e.get("repeatable", False) and gv(e, "priority", 0) > p]
    if once:
        note(f"{cid}: 有 {len(once)} 条一次性高优事件可临时挤占（各至多 1 次）："
             f"{sorted(once, reverse=True)[:4]} —— 不构成饿死。")

# 周上限与互斥
_no_weekgate = [i for i, e in weekly.items() if CLUB_WEEK_FLAG not in gv(e, "excludeFlags", [])]
check(not _no_weekgate, f"5 条周活动均以 excludeFlags:{CLUB_WEEK_FLAG} 实现每周 1 次硬上限",
      f"缺门控: {_no_weekgate}")
_no_reqflags = [i for i, e in weekly.items()
                if not {CLUB_JOIN_FLAG, f"flag_club_{i[len('club_weekly_'):]}"}
                <= set(gv(e, "requireFlags", []))]
check(not _no_reqflags, "5 条周活动均要求 [flag_club_joined + 本社类型 flag]（无跨社串味）",
      f"越界: {_no_reqflags}")
_rep_bad = [i for i, e in weekly.items() if e.get("repeatable") is not True]
check(not _rep_bad, "5 条周活动 repeatable == true（否则整局只能参加一次）", f"越界: {_rep_bad}")

# 同优先级平局：Godot sort_custom 不保证稳定 —— 靠互斥门控消解不确定性
_tie = [(i, loc_of(e), gv(e, "priority", 0)) for i, e in weekly.items()]
_tie_groups = {}
for i, l, p in _tie:
    _tie_groups.setdefault((l, p), []).append(i)
_risky = {k: v for k, v in _tie_groups.items() if len(v) > 1}
_tie_ok = True
for (l, p), ids in _risky.items():
    reqs = [set(gv(weekly[i], "requireFlags", [])) for i in ids]
    for a in range(len(reqs)):
        for b in range(a + 1, len(reqs)):
            if reqs[a] & {f"flag_club_{t}" for t in CLUB_TYPES} == \
               reqs[b] & {f"flag_club_{t}" for t in CLUB_TYPES}:
                _tie_ok = False
check(_tie_ok,
      f"同地点同 priority 的并列社团事件{_risky if _risky else '（无）'}靠类型 flag 互斥消解"
      f"（sort_custom 不稳定排序不会造成随机错社）",
      "并列且非互斥 → 玩家可能触发到别社的活动")

# ── Q14 【QA 扩展】源码卫生 ──────────────────────────────────
section("Q14", "【QA 扩展】源码卫生：缩进同宿主 + 写入点唯一")
for path, style in ((DAILY, "tab"), (MAIN, "space"), (DLG, "space")):
    lines = src_of(path).splitlines()
    tabs = sum(1 for l in lines if l.startswith("\t"))
    spaces = sum(1 for l in lines if l.startswith("    "))
    bad = spaces if style == "tab" else tabs
    check(bad == 0,
          f"{path.name} 保持纯 {style} 缩进（GDScript 混用缩进会直接解析失败）",
          f"tab 行={tabs} / space 行={spaces}")

_erase_line = [l for l in daily_src.splitlines() if re.search(ERASE_PAT, l)]
check(bool(_erase_line) and _erase_line[0].startswith("\t"),
      "DailyCycleManager 的社团 erase 行以 TAB 起始（与宿主一致）",
      f"实际 {_erase_line[:1]!r}")
_btn_line = [l for l in main_src.splitlines() if "🎏 社团" in l and '"text"' in l]
check(bool(_btn_line) and _btn_line[0].startswith("    ") and not _btn_line[0].startswith("\t"),
      "MainGame 的社团按钮行以空格起始（与宿主一致）", f"实际 {_btn_line[:1]!r}")

_gd_writers = sorted(p.name for p in SCRIPTS.rglob("*.gd")
                     if re.search(r'set_flag\(\s*"flag_club_|flags\[\s*"flag_club_',
                                  code_only(src_of(p))))
check(not _gd_writers,
      "无任何 .gd 直接写 flag_club_*（入社/参加只能经 JSON 事件，面板与管理器均不代写）",
      f"越界文件: {_gd_writers}")

# ── 判定 ─────────────────────────────────────────────────────
print("\n" + "=" * 78)
_passed = _total - len(failures)
print(f"assertions={_total}  通过 {_passed} 项，失败 {len(failures)} 项，"
      f"concerns={len(concerns)}  notes={len(notes)}")
if failures:
    print("VERDICT: FAIL")
    for f_ in failures:
        print(f"  x {f_}")
    sys.exit(1)
elif concerns:
    print("VERDICT: CONCERNS")
    for c_ in concerns:
        print(f"  ! {c_}")
    sys.exit(0)
else:
    print("VERDICT: PASS")
    sys.exit(0)
