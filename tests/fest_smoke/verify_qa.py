# -*- coding: utf-8 -*-
"""
QA-FEST-01 — 节日事件 triggerDay 门控修复 独立质量门禁
Owner: 严守真 (quality-lead)

独立于工程侧自验 scripts/_verify_fest_triggerday.py：断言重新设计、独立编号。
工程自验只看「4 个 fest 事件的 5 个字段 + 总数」；本门禁从第二视角把修复放回
**运行时语义**里复演，并锁死三份文件之间的一致性三角。

核心方法论差异（本门禁刻意覆盖工程自验的盲区）：
  1. 工程自验断言 triggerDay ∈ {10,30,120,310} 是**硬编码期望值**。若当初抄错
     SPECIAL_DATES，自验会「自洽地通过」。本门禁改为**从 DailyCycleManager.gd
     真源解析 SPECIAL_DATES**，再从 MainGame.gd 真源解析 fest_narrative_map，
     三方交叉推导出期望值 —— 期望值不再由人手写。
  2. 工程自验完全没看 MainGame.gd L368–379：节日事件其实有**两条触发路径**，
     直发路径 get_event_by_id() 绕过 triggerDay 与消费检查。该路径决定了
     「triggerDay 必须 == 节日当天」这一比「triggerDay > 1」强得多的不变量。
  3. 工程自验只看 4 个 fest_ 事件；实际 SPECIAL_DATES 有 **5** 个 effect:festival
     （day 95 春节 → eco_lucky_money）。本门禁把第 5 个一并纳入门控。
  4. 本门禁额外做「根因同类清零」全池扫描（245 条），确保不只治了这 4 条。

方法：纯静态断言（JSON 解析 + GDScript 字面量解析 + get_available_event 语义
      复演），不依赖 Godot runtime。对游戏源码**只读**。

分组：
  Q0  门禁自检（源文件可达 + 事件池加载）
  Q1  修复核心：triggerDay 精确落位（期望值由真源推导）
  Q2  零回归：字段未被误改（键集 + 指纹 + 总数）
  Q3  JSON 合法性
  Q4  零代码改动（Autoload / SPECIAL_DATES / DataManager 门控逻辑）
  Q5  NG+ 周目重置
  Q6  【QA 扩展】三文件一致性三角（含第 5 个节日 spring_festival）
  Q7  【QA 扩展】根因同类清零：全池无「day1 即可被消费」的一次性全局事件
  Q8  【QA 扩展】双触发路径语义 + 回落可达性

环境变量 FEST_QA_ROOT 可覆盖工程根目录 —— 供反向变异测试指向沙箱副本，
从而在**不触碰真源码**的前提下验证断言不是永远 PASS 的死断言。

退出码：0 = PASS / PASS-with-concerns，1 = FAIL。
"""
import ast
import hashlib
import io
import json
import os
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(os.environ.get("FEST_QA_ROOT", Path(__file__).resolve().parents[2]))
SCRIPTS = ROOT / "scripts"

DAILY   = SCRIPTS / "DailyCycleManager.gd"
MAIN    = SCRIPTS / "MainGame.gd"
DATAMGR = SCRIPTS / "DataManager.gd"
ENDING  = SCRIPTS / "EndingScreen.gd"
EVL     = SCRIPTS / "events_life.json"
PROJECT = ROOT / "project.godot"

# ── 基线常量（改动即回归）─────────────────────────────────────
AUTOLOAD_EXPECTED = 15
LIFE_TOTAL_EXPECTED = 92    # DS-RN-05b rebaseline：+20 club_chain_*（2026-08-03）
FEST_COUNT_EXPECTED = 4
FEST_PRIORITY_EXPECTED = 300
# DailyCycleManager.SPECIAL_DATES 实测条目数（day 1..570 共 24 个特殊日期）。
# 相比原来 22 个，新增了：
#   day 1  → effect: "opening"（初一开学第一天）
#   day 14 → effect: "training_end"（军训结束联欢晚会）
SPECIAL_DATES_TOTAL_EXPECTED = 24

# 4 个 fest 事件修复后的**完整键集**。修复只允许「加 triggerDay」这一个动作：
# 若少键 = 字段被删；若多键 = 夹带了别的改动。比逐字段点检更严。
FEST_KEYS_EXPECTED = {
    "charId", "id", "location", "priority", "repeatable",
    "scenes", "slotId", "title", "triggerDay",
}

# scenes 内容指纹（sha256[:16] of json.dumps(scenes, sort_keys, ensure_ascii=False)）
# 修复为「纯加键」，scenes 不得有任何字符变动。
FEST_SCENES_SHA = {
    "fest_teacherday": "8393aad4829a02b6",
    "fest_newyear":    "e706e48f274cb3ec",
    "fest_dragonboat": "254323009851edf9",
    "fest_midautumn":  "f8748c72a6d55c82",
}
FEST_SCENE_COUNT_EXPECTED = 2

# DataManager.get_available_event 的门控键（用于「无门控」判定）
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


def _emergency(exc_type, exc, tb):
    """兜底：门禁自身崩溃时，仍必须给出判定并以 1 阻断。

    一个「静默崩溃」的质量门禁比没有门禁更危险 —— CI 若只看有无输出，
    会把崩溃误读成通过。故任何未捕获异常一律折算为 FAIL。
    """
    import traceback
    print("\n" + "=" * 78)
    print("[FATAL] 门禁自身抛出未捕获异常，断言集未跑完 —— 判定强制 FAIL：")
    traceback.print_exception(exc_type, exc, tb)
    print(f"\nassertions={_total}（未跑完）  通过 {_total - len(failures)} 项，"
          f"失败 {len(failures)} 项，concerns={len(concerns)}")
    print("VERDICT: FAIL")
    sys.stdout.flush()
    os._exit(1)


sys.excepthook = _emergency


# ─────────────────────────────────────────────────────────────────
# 解析工具（GDScript 字面量 → Python）
# ─────────────────────────────────────────────────────────────────
def src_of(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def code_only(text: str) -> str:
    """字符串感知地剥掉整行/行尾注释，避免注释文本干扰反向断言。"""
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
    return "".join(out)


def load_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_to_py(extract_block(src_of(path), anchor)))


def nz(v, default=""):
    """JSON null 归一。"""
    return default if v is None else v


def is_ungated(e):
    return not any(e.get(k) not in (None, "", 0, [], {}) for k in GATE_KEYS)


def scenes_sha(ev):
    blob = json.dumps(ev.get("scenes"), ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]


def selectable(ev, day, location_id, slot, consumed):
    """复演 DataManager.get_available_event (L190–208) 的前四道门。

    仅覆盖 location / slotId / triggerDay / repeatable-consumed 四门 —— 对
    「无门控」的 fest 事件而言这四门即全部判定条件。
    """
    ev_location = nz(ev.get("location"), "")
    if ev_location != "" and ev_location != location_id:
        return False
    slot_id = nz(ev.get("slotId"), "")
    if slot_id != "" and slot_id != slot:
        return False
    trigger_day = int(ev.get("triggerDay") or 0)
    if trigger_day > 0 and day < trigger_day:
        return False
    if not ev.get("repeatable", False) and ev.get("id") in consumed:
        return False
    return True


# ─────────────────────────────────────────────────────────────────
print("=" * 78)
print("QA-FEST-01 · 节日事件 triggerDay 门控修复 独立质量门禁 (quality-lead 严守真)")
print(f"ROOT = {ROOT}")
print("=" * 78)

# ── Q0 门禁自检 ──────────────────────────────────────────────
section("Q0", "门禁自检（源文件可达，避免空扫描假 PASS）")
_required = {"events_life.json": EVL, "DailyCycleManager.gd": DAILY,
             "MainGame.gd": MAIN, "DataManager.gd": DATAMGR,
             "EndingScreen.gd": ENDING, "project.godot": PROJECT}
_missing = [n for n, p in _required.items() if not p.exists()]
if not check(not _missing, "6 个受检源文件全部可达", f"缺失 {_missing}"):
    print("\nVERDICT: FAIL（源文件缺失，后续断言无意义）")
    sys.exit(1)

dm_src = src_of(DATAMGR)
daily_src = src_of(DAILY)
main_src = src_of(MAIN)

# 全事件池（EVENT_FILES 从 DataManager 真源解析，杜绝手抄漏文件）
EVENT_FILES = re.findall(r'"res://scripts/(events_[a-z_]+\.json)"', dm_src)
check(len(EVENT_FILES) == 10, "DataManager.EVENT_FILES 注册 10 个事件文件",
      f"实际 {len(EVENT_FILES)}: {EVENT_FILES}")

ALL_EVENTS, _load_err = [], []
for fn in EVENT_FILES:
    p = SCRIPTS / fn
    try:
        for e in json.loads(p.read_text(encoding="utf-8")):
            e["_src"] = fn
            ALL_EVENTS.append(e)
    except Exception as ex:      # noqa: BLE001
        _load_err.append(f"{fn}: {ex}")
check(not _load_err, f"全部事件文件可解析（事件池 {len(ALL_EVENTS)} 条）", str(_load_err))
BY_ID = {e.get("id"): e for e in ALL_EVENTS}

# ── Q3 JSON 合法性（前置，其余组依赖它）──────────────────────
section("Q3", "JSON 合法性（前置执行：后续组依赖解析结果）")
try:
    life_events = json.loads(EVL.read_text(encoding="utf-8"))
    _ok = check(True, "events_life.json 可被 json.load 解析")
except Exception as ex:      # noqa: BLE001
    check(False, "events_life.json 可被 json.load 解析", str(ex))
    print("\nVERDICT: FAIL（JSON 不可解析，后续断言无意义）")
    sys.exit(1)
check(isinstance(life_events, list), "events_life.json 顶层为 list",
      f"实际 {type(life_events).__name__}")

fest_events = [e for e in life_events if str(e.get("id", "")).startswith("fest_")]
FEST = {e["id"]: e for e in fest_events}
check(len(fest_events) == FEST_COUNT_EXPECTED,
      f"events_life.json 内 fest_ 前缀事件恰 {FEST_COUNT_EXPECTED} 条",
      f"实际 {len(fest_events)}: {sorted(FEST)}")

# ── SPECIAL_DATES 真源解析（Q1 期望值的唯一来源）──────────────
try:
    SPECIAL_DATES = load_literal(DAILY, "const SPECIAL_DATES = ")
except Exception as ex:      # noqa: BLE001
    print(f"\n[FATAL] SPECIAL_DATES 解析失败: {ex}")
    print("VERDICT: FAIL")
    sys.exit(1)

# banner -> day（仅 effect == festival）
FESTIVAL_DAYS = {v["banner"]: k for k, v in SPECIAL_DATES.items()
                 if v.get("effect") == "festival" and v.get("banner")}

# MainGame 的「节日 banner → 叙事事件 id」映射（真源解析）
try:
    FEST_NARRATIVE_MAP = load_literal(MAIN, "var fest_narrative_map = ")
except Exception as ex:      # noqa: BLE001
    FEST_NARRATIVE_MAP = {}
    concern(f"MainGame.fest_narrative_map 解析失败（Q6 将退化）: {ex}")

# 由真源推导出的期望值：event_id -> 节日当天
DERIVED_EXPECT = {}
for _banner, _eid in FEST_NARRATIVE_MAP.items():
    if _banner in FESTIVAL_DAYS:
        DERIVED_EXPECT[_eid] = FESTIVAL_DAYS[_banner]

note(f"SPECIAL_DATES 解析出 {len(SPECIAL_DATES)} 个特殊日期，其中 effect=festival 共 "
     f"{len(FESTIVAL_DAYS)} 个：{dict(sorted(FESTIVAL_DAYS.items(), key=lambda x: x[1]))}")
note(f"由「MainGame.fest_narrative_map × SPECIAL_DATES」推导出的 triggerDay 期望值："
     f"{dict(sorted(DERIVED_EXPECT.items(), key=lambda x: x[1]))} —— 本门禁不硬编码该期望。")

# ── Q1 修复核心 ──────────────────────────────────────────────
section("Q1", "修复核心：triggerDay 精确落位（期望值由 SPECIAL_DATES 真源推导）")

_fest_ids = ["fest_teacherday", "fest_newyear", "fest_dragonboat", "fest_midautumn"]
_absent = [i for i in _fest_ids if i not in FEST]
if not check(not _absent, "4 个 fest 事件全部存在于 events_life.json", f"缺失 {_absent}"):
    print("\nVERDICT: FAIL（目标事件缺失，后续断言无意义）")
    sys.exit(1)

# Q1.2 —— SPECIAL_DATES 证据：4 个天数确实是 effect:festival
_day_evidence = {"fest_teacherday": 10, "fest_newyear": 30,
                 "fest_dragonboat": 120, "fest_midautumn": 310}
_bad_evidence = []
for _eid, _d in _day_evidence.items():
    _entry = SPECIAL_DATES.get(_d, {})
    if _entry.get("effect") != "festival":
        _bad_evidence.append(f"day {_d} → effect={_entry.get('effect')!r}(非 festival)")
check(not _bad_evidence,
      "SPECIAL_DATES 中 day 10/30/120/310 均标记 effect:\"festival\"（修复依据成立）",
      f"证据不成立: {_bad_evidence}")

# Q1.3–Q1.6 —— 逐条精确断言 triggerDay
for _eid in _fest_ids:
    ev = FEST[_eid]
    want = DERIVED_EXPECT.get(_eid, _day_evidence[_eid])
    got = ev.get("triggerDay", "<缺失>")
    _entry = SPECIAL_DATES.get(want, {})
    check("triggerDay" in ev and got == want,
          f"{_eid}.triggerDay == {want}"
          f"（{_entry.get('label', '?')} / banner={_entry.get('banner', '?')}）",
          f"实际 {got!r}")

# Q1.7 —— 每个 triggerDay > 1：根因（day1 即被消费）已治
_le1 = [f"{i}={FEST[i].get('triggerDay')}" for i in _fest_ids
        if int(FEST[i].get("triggerDay") or 0) <= 1]
check(not _le1, "4 个 fest 事件 triggerDay 均 > 1（节前绝不触发，根因已治）",
      f"越界: {_le1}")

# Q1.8 —— 行为复演：day 1 首次探索时 4 个 fest 事件均不可选
_day1_leak = []
for _eid in _fest_ids:
    for _loc in ("classroom", "home", "lakeside", "library", "playground"):
        for _slot in ("morning", "noon", "after", "evening", "night"):
            if selectable(FEST[_eid], 1, _loc, _slot, set()):
                _day1_leak.append(f"{_eid}@{_loc}/{_slot}")
check(not _day1_leak,
      "语义复演：day=1 × 5 地点 × 5 时段共 25 种组合下，4 个 fest 事件全部不可选"
      "（原 Bug 的确凿反向验证）",
      f"泄漏: {_day1_leak[:5]}")

# Q1.9 —— 行为复演：节日当天起可选（回落路径确实开门）
_no_open = []
for _eid in _fest_ids:
    d = int(FEST[_eid].get("triggerDay") or 0)
    if not selectable(FEST[_eid], d, "classroom", "after", set()):
        _no_open.append(f"{_eid}@day{d}")
check(not _no_open,
      "语义复演：各自 triggerDay 当天，4 个 fest 事件均转为可选（回落路径开门）",
      f"未开门: {_no_open}")

# Q1.10 —— 前一天仍关门（边界精确性）
# 注意：此处必须用安全取值。triggerDay 缺失正是本门禁要捕获的缺陷形态，
# 若用 FEST[i]["triggerDay"] 直取会 KeyError 崩溃，导致 Q2–Q9 全部不执行、
# 汇总与判定行丢失 —— 门禁必须「报全所有失败」，而不是死在第一个。
_early = []
for _i in _fest_ids:
    _td = FEST[_i].get("triggerDay")
    if not isinstance(_td, int):
        continue          # 缺失/类型异常已由 Q1.3–Q1.7 判负，此处不重复计数
    if selectable(FEST[_i], _td - 1, "classroom", "after", set()):
        _early.append(f"{_i}@day{_td - 1}")
check(not _early, "语义复演：triggerDay 前一天仍不可选（边界 off-by-one 防护）",
      f"提前开门: {_early}")

# ── Q2 零回归 ────────────────────────────────────────────────
section("Q2", "零回归：字段未被误改（键集 + 值 + scenes 指纹 + 总数）")

# Q2.1 —— 键集完全一致：证明「只加了 triggerDay，没夹带别的改动」
_key_bad = []
for _eid in _fest_ids:
    got = set(FEST[_eid].keys())
    if got != FEST_KEYS_EXPECTED:
        _key_bad.append(f"{_eid}: 多={sorted(got - FEST_KEYS_EXPECTED)} "
                        f"少={sorted(FEST_KEYS_EXPECTED - got)}")
check(not _key_bad,
      f"4 个 fest 事件键集恰为 {len(FEST_KEYS_EXPECTED)} 键（= 原 8 键 + triggerDay，"
      f"证明修复是纯加键、无夹带）", f"越界: {_key_bad}")

# Q2.2–Q2.5 —— 逐字段值锁定
for _field, _want, _desc in (("priority", FEST_PRIORITY_EXPECTED, "== 300"),
                             ("repeatable", False, "== false（一次性消费）"),
                             ("location", None, "== null（全局事件）"),
                             ("slotId", None, "== null（任意时段）")):
    _bad = [f"{i}={FEST[i].get(_field)!r}" for i in _fest_ids
            if FEST[i].get(_field) is not _want and FEST[i].get(_field) != _want]
    check(not _bad, f"4 个 fest 事件 {_field} 仍 {_desc}", f"越界: {_bad}")

_char_bad = [f"{i}={FEST[i].get('charId')!r}" for i in _fest_ids
             if FEST[i].get("charId") is not None]
check(not _char_bad, "4 个 fest 事件 charId 仍为 null（男女双路线均可见）", f"越界: {_char_bad}")

# Q2.7 —— scenes 数量未变
_sc_cnt = [f"{i}={len(FEST[i].get('scenes', []))}" for i in _fest_ids
           if len(FEST[i].get("scenes", [])) != FEST_SCENE_COUNT_EXPECTED]
check(not _sc_cnt, f"4 个 fest 事件 scenes 数量仍为 {FEST_SCENE_COUNT_EXPECTED}",
      f"越界: {_sc_cnt}")

# Q2.8 —— scenes 内容指纹：文案/statDelta/next 一个字符都不许动
_sha_bad = []
for _eid in _fest_ids:
    got = scenes_sha(FEST[_eid])
    if got != FEST_SCENES_SHA[_eid]:
        _sha_bad.append(f"{_eid}: {got} != {FEST_SCENES_SHA[_eid]}")
check(not _sha_bad,
      "4 个 fest 事件 scenes 内容指纹(sha256[:16]) 与基线逐条一致"
      "（文案 / statDelta / next 零改动）", f"漂移: {_sha_bad}")

# Q2.9 —— 事件总数
check(len(life_events) == LIFE_TOTAL_EXPECTED,
      f"events_life.json 事件总数仍为 {LIFE_TOTAL_EXPECTED}（只加键，未加/删事件）",
      f"实际 {len(life_events)}")

# Q2.10 —— 全池 id 唯一（防止「加键」误操作复制出重复条目）
_ids = [str(e.get("id", "")) for e in ALL_EVENTS]
_dups = sorted({i for i in _ids if _ids.count(i) > 1})
check(not _dups, f"全事件池 {len(_ids)} 条 id 全局唯一", f"重复: {_dups}")

# ── Q4 零代码改动 ────────────────────────────────────────────
section("Q4", "零代码改动：修复是纯 JSON，未动引擎")
proj = src_of(PROJECT)
_al_sec = proj.split("[autoload]", 1)[1].split("\n[", 1)[0] if "[autoload]" in proj else ""
_autoloads = re.findall(r'^(\w+)\s*=\s*"\*res://', _al_sec, re.M)
check(len(_autoloads) == AUTOLOAD_EXPECTED,
      f"project.godot [autoload] 段仍为 {AUTOLOAD_EXPECTED} 项（未新增 Autoload）",
      f"实际 {len(_autoloads)}: {_autoloads}")
check(not [a for a in _autoloads if "fest" in a.lower()],
      "无任何 fest 命名的 Autoload（修复全在数据层）")

# SPECIAL_DATES 4 个节日条目未被改动（label / effect / banner 三元组锁定）
_SD_BASELINE = {
    10:  ("📚 教师节",       "festival", "teacher_day"),
    30:  ("🎉 元旦快乐！",   "festival", "new_year"),
    120: ("🎋 端午节到了！", "festival", "dragon_boat"),
    310: ("🥮 中秋佳节！",   "festival", "mid_autumn"),
}
_sd_bad = []
for _d, (_lb, _ef, _bn) in _SD_BASELINE.items():
    _e = SPECIAL_DATES.get(_d)
    if _e is None:
        _sd_bad.append(f"day {_d} 条目消失")
    elif (_e.get("label"), _e.get("effect"), _e.get("banner")) != (_lb, _ef, _bn):
        _sd_bad.append(f"day {_d}: {(_e.get('label'), _e.get('effect'), _e.get('banner'))}")
check(not _sd_bad,
      "DailyCycleManager.SPECIAL_DATES 的 4 个节日条目 (label/effect/banner) 未被改动",
      f"漂移: {_sd_bad}")
check(len(SPECIAL_DATES) == SPECIAL_DATES_TOTAL_EXPECTED,
      f"SPECIAL_DATES 条目总数仍为 {SPECIAL_DATES_TOTAL_EXPECTED}（未增删特殊日期）",
      f"实际 {len(SPECIAL_DATES)}")

# DataManager 的 triggerDay 门控逻辑本体未被改动
_dm_code = code_only(dm_src)
check(re.search(r'var\s+trigger_day\s*=\s*int\(\s*ev\.get\(\s*"triggerDay"\s*,\s*0\s*\)\s*\)',
                _dm_code) is not None,
      "DataManager 仍以 `int(ev.get(\"triggerDay\", 0))` 读取门控值（默认 0 = 不设限）")
check(re.search(r"if\s+trigger_day\s*>\s*0\s+and\s+current_day\s*<\s*trigger_day\s*:\s*continue",
                _dm_code) is not None,
      "DataManager 门控仍为 `trigger_day > 0 and current_day < trigger_day: continue`"
      "（「从该天起可用」语义未变）",
      "该行若被改成 `!=` 即变为「仅限当天」，4 个 fest 将在错过当天后永久不可达")

# ── Q5 NG+ 重置 ──────────────────────────────────────────────
section("Q5", "NG+ 周目重置：fest 事件随 flags 清空自然复活")
end_code = code_only(src_of(ENDING))
check(re.search(r"GameManager\.flags\s*=\s*\{\}", end_code) is not None,
      "EndingScreen NG+ 段整体清空 GameManager.flags")
check("fest" not in end_code.lower(),
      "EndingScreen.gd 零 fest 引用（无白名单豁免 / 无特判保留）",
      f"命中: {[l.strip() for l in end_code.splitlines() if 'fest' in l.lower()][:3]}")

_clear_pos = end_code.find("GameManager.flags = {}")
_after = end_code[_clear_pos:] if _clear_pos >= 0 else ""
_reinject = re.findall(r'GameManager\.flags\[\s*"([^"]+)"\s*\]\s*=', _after)
check(not [f for f in _reinject if "fest" in f.lower()],
      "清档后无 fest 相关 flag 回注（4 个事件的消耗标记确凿被清）",
      f"回注项: {_reinject[:8]}")

# 与消费机制互证：DataManager 以 flags.has(event_id) 判定一次性事件是否已消耗
check(re.search(r'if\s+not\s+ev\.get\(\s*"repeatable"\s*,\s*false\s*\)\s+and\s+'
                r"GameManager\.flags\.has\(\s*ev_id\s*\)\s*:\s*continue", _dm_code) is not None,
      "DataManager 仍以 `flags.has(ev_id)` 判定一次性事件已消耗"
      "（与上条互证：清 flags == 重新武装 4 个 fest）")
note(f"NG+ 清档后回注的 flag：{_reinject if _reinject else '无'} —— 均与 fest 无关。"
     f"NG+ 同时 day 归 1，triggerDay 门控在新周目重新生效，节日顺序完整复现。")

# ── Q6 【QA 扩展】三文件一致性三角 ───────────────────────────
section("Q6", "【QA 扩展】三文件一致性三角（工程自验完全未覆盖）")
note("工程自验只校验「events_life.json 单文件内的 4 个硬编码期望值」。但节日叙事实际由"
     "三份文件协同：MainGame.fest_narrative_map（banner→事件 id）× "
     "DailyCycleManager.SPECIAL_DATES（day→banner）× events_life.json（事件.triggerDay）。"
     "任一处漂移都会让节日错位，而单文件断言全部照常 PASS。")

check(len(FEST_NARRATIVE_MAP) == 5,
      "MainGame.fest_narrative_map 恰 5 项（4 个 fest_ + 1 个 spring_festival）",
      f"实际 {len(FEST_NARRATIVE_MAP)}: {FEST_NARRATIVE_MAP}")

# Q6.2 —— 每个映射 banner 都是真实的 festival banner
_bad_banner = [b for b in FEST_NARRATIVE_MAP if b not in FESTIVAL_DAYS]
check(not _bad_banner,
      "fest_narrative_map 的 5 个 banner 均可在 SPECIAL_DATES 中找到 effect:festival 条目",
      f"悬空 banner: {_bad_banner}")

# Q6.3 —— 反向：每个 festival banner 都有叙事事件（无遗漏节日）
_uncovered = [b for b in FESTIVAL_DAYS if b not in FEST_NARRATIVE_MAP]
check(not _uncovered,
      f"SPECIAL_DATES 的 {len(FESTIVAL_DAYS)} 个 festival banner 全部被 "
      f"fest_narrative_map 覆盖（无「有节日无叙事」的哑日）",
      f"未覆盖: {_uncovered}")

# Q6.4 —— 映射目标事件必须真实存在
_dangling = [f"{b}→{i}" for b, i in FEST_NARRATIVE_MAP.items() if i not in BY_ID]
check(not _dangling, "fest_narrative_map 的 5 个目标事件 id 在事件池中均存在",
      f"悬空引用: {_dangling}")

# Q6.5 —— 核心不变量：triggerDay 必须 == 节日当天（精确相等，非 >=）
_mismatch = []
for _b, _eid in sorted(FEST_NARRATIVE_MAP.items(), key=lambda x: FESTIVAL_DAYS.get(x[0], 0)):
    if _eid not in BY_ID or _b not in FESTIVAL_DAYS:
        continue
    _want = FESTIVAL_DAYS[_b]
    _got = BY_ID[_eid].get("triggerDay")
    if _got != _want:
        _mismatch.append(f"{_b}({_eid}): triggerDay={_got!r} != 节日当天 {_want}")
check(not _mismatch,
      "5 个节日事件的 triggerDay 与其 SPECIAL_DATES 节日当天**精确相等**"
      "（含 spring_festival→eco_lucky_money=95）",
      f"错位: {_mismatch}")
note("为何必须「精确相等」而非「> 1」：见 Q8 —— 直发路径不校验消费状态，"
     "triggerDay < 节日当天会导致 vignette 被提前消费、且在节日当天二次重播。")

# Q6.6 —— 第 5 个节日（春节）单独点名：它不带 fest_ 前缀，最容易被漏
_lucky = BY_ID.get("eco_lucky_money")
check(_lucky is not None and _lucky.get("triggerDay") == 95,
      "eco_lucky_money（🧧 春节 day95，唯一不带 fest_ 前缀的节日叙事）triggerDay == 95",
      f"实际 {_lucky.get('triggerDay') if _lucky else 'MISSING'}")

# ── Q7 【QA 扩展】根因同类清零 ───────────────────────────────
section("Q7", "【QA 扩展】根因同类清零：全池扫描「day1 即可被消费」的一次性全局事件")
note("根因的**缺陷形状**是：location=null + slotId=null + 零门控 + repeatable=false "
     "+ 无 triggerDay → 在 day1 第一次探索就被 flags 记为已消耗，此后永久不可达。"
     "只修 4 条不等于治本；本组对全池 245 条做同形状扫描，确保无漏网之鱼。")
_same_shape = []
for e in ALL_EVENTS:
    if (nz(e.get("location"), "") == "" and is_ungated(e)
            and not e.get("repeatable", False)
            and int(e.get("triggerDay") or 0) <= 1):
        _same_shape.append(f"{e.get('id')}(p={e.get('priority')},{e['_src']})")
check(not _same_shape,
      f"全事件池 {len(ALL_EVENTS)} 条中，无「全局 + 零门控 + 一次性 + 无 triggerDay」"
      f"的 day1 可消费事件（根因形状彻底清零）",
      f"同类隐患 {len(_same_shape)} 条: {_same_shape[:6]}")

# Q7.2 —— 4 个 fest 事件确实处于「零门控」状态：它们的唯一防线就是 triggerDay
_gated = [f"{i}:{[k for k in GATE_KEYS if FEST[i].get(k) not in (None, '', 0, [], {})]}"
          for i in _fest_ids if not is_ungated(FEST[i])]
check(not _gated,
      "4 个 fest 事件确为零门控（triggerDay 是其唯一防线 —— 故 Q1 不可降级为软断言）",
      f"意外门控: {_gated}")

# ── Q8 【QA 扩展】双触发路径语义 + 回落可达性 ────────────────
section("Q8", "【QA 扩展】双触发路径语义 + 回落可达性")
note("节日 vignette 有**两条**触发路径，工程自验只知其一："
     "①【直发·精确当天】MainGame._apply_special_date 在节日当天以 "
     "get_event_by_id() 直接 start_event()；②【回落·从该天起】探索时经 "
     "get_available_event() 按 triggerDay 放行。①不校验 triggerDay 也不校验消费状态。")

_mg_code = code_only(main_src)
check(re.search(r"if\s+fest_narrative_map\.has\(\s*banner\s*\)\s*:", _mg_code) is not None,
      "MainGame 保留 `if fest_narrative_map.has(banner)` 直发分支（节日当天精确播放）")
check(re.search(r"DataManager\.get_event_by_id\(\s*fest_narrative_map\[\s*banner\s*\]\s*\)",
                _mg_code) is not None,
      "直发分支仍经 DataManager.get_event_by_id() 取事件")

# get_event_by_id 确实是「裸查」——不含任何门控
_gebi = re.search(r"func get_event_by_id\(.*?\).*?:\n(.*?)(?=\n^func |\Z)",
                  dm_src, re.S | re.M)
_gebi_body = _gebi.group(1) if _gebi else ""
check(_gebi_body != "" and "triggerDay" not in _gebi_body
      and "flags.has" not in _gebi_body,
      "get_event_by_id() 为裸查（不校验 triggerDay / 不校验已消费）"
      " —— 这正是「triggerDay 必须精确等于节日当天」的根据",
      f"函数体含门控关键字，双路径语义假设需重新评估: {_gebi_body[:120]!r}")

# Q8.4 —— 提前消费 + 二次重播的反向复演
_double_play = []
for _b, _eid in FEST_NARRATIVE_MAP.items():
    if _eid not in BY_ID or _b not in FESTIVAL_DAYS:
        continue
    _fday = FESTIVAL_DAYS[_b]
    _td = int(BY_ID[_eid].get("triggerDay") or 0)
    # 若 triggerDay < 节日当天，则存在 [triggerDay, 节日当天) 的窗口，
    # 回落路径会先消费掉它；到了节日当天直发路径无视消费状态再播一次。
    if 0 < _td < _fday:
        _double_play.append(f"{_eid}: triggerDay={_td} < 节日当天 {_fday}，"
                            f"存在 {_fday - _td} 天的提前消费窗口 → 节日当天二次重播")
check(not _double_play,
      "无「提前消费窗口」：任一节日事件的 triggerDay 均不早于其节日当天"
      "（否则回落路径先播、直发路径当天重播 = 同一 vignette 播两遍）",
      f"风险: {_double_play}")

# Q8.5 —— 回落路径可达性：fest 优先级须高于所有「可重复 + 零门控」常驻竞争者
_resident_max, _resident_top = 0, None
for e in ALL_EVENTS:
    if e.get("repeatable", False) and is_ungated(e):
        p = e.get("priority") or 0
        if p > _resident_max:
            _resident_max, _resident_top = p, e.get("id")
check(_resident_max < FEST_PRIORITY_EXPECTED,
      f"fest 优先级 {FEST_PRIORITY_EXPECTED} 高于全池最强常驻竞争者"
      f"（{_resident_top}, p={_resident_max}）—— 回落路径不会被永久饿死",
      f"常驻竞争者 p={_resident_max} >= {FEST_PRIORITY_EXPECTED}")

# Q8.6 —— 同优先级并列：4 个 fest 全为 p=300 全局事件，晚期可能同时在池
_late_pool = [i for i in _fest_ids if int(FEST[i].get("triggerDay") or 0) <= 310]
note(f"并列取证：4 个 fest 均为 p=300 全局事件，若玩家长期不探索，"
     f"day≥310 时最多 {len(_late_pool)} 条同时在候选池并列。Godot sort_custom 不保证"
     f"稳定排序 → 补播**顺序**不确定，但因均为一次性事件，最终 4 条都会播完，"
     f"不造成丢失。属可接受行为（与「节日当天没探索则顺延补播」同源）。")

# Q8.7 —— 直发路径与烹饪解锁互不干扰（festival effect 的另一半职责）
check(re.search(r'"new_year"\s*:\s*"new_year_cooking"', _mg_code) is not None
      and re.search(r'"mid_autumn"\s*:\s*"mid_autumn_cooking"', _mg_code) is not None,
      "MainGame 节日限定食谱解锁 map 仍在（triggerDay 修复未殃及烹饪解锁分支）")

# ── Q9 可选增强建议（note 级，不阻断）────────────────────────
section("Q9", "可选增强（note 级，不阻断门禁）")
_conv_ok = all(int(FEST[i].get("triggerDay") or 0) > 1 for i in _fest_ids)
if _conv_ok:
    note("约定固化建议：当前「fest 事件必须带 triggerDay」仅靠本门禁把守，源码侧无强制。"
         "建议在 DataManager.get_available_event 的 triggerDay 分支上方补一行注释，"
         "或在 docs 中登记该约定，避免日后新增节日事件时重蹈覆辙。"
         "本门禁 Q6.3（festival banner 全覆盖）+ Q7.1（根因形状清零）已构成自动化兜底。")
note("建议将本门禁接入 CI/提交前检查：Q6/Q7 两组是跨文件不变量，"
     "人工 review 极易漏看。")

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
