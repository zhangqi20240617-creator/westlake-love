# -*- coding: utf-8 -*-
"""
QA-RN-04 — 西湖风物志（DS-RN-04）独立逻辑级烟雾测试 / 质量门
Owner: 严守真 (quality-lead)

独立于 scratch/verify_fengwu.py：断言重新设计、独立编号、聚焦「主理人最该担心的风险」，
刻意**不**复制 engineering 的 140 条覆盖式断言。每条断言合并同族子检查，失败时由 detail
定位到具体子项。

方法：纯静态断言（GDScript 字面量求值 + 结构解析 + 语义 mock 复演），不依赖 Godot runtime。
      对游戏源码**只读**。

⚠️ 门控作用域（关键设计）：
    CollectionManager.gd 是多特性共居文件（画廊 / 十景集章 / 风物志 / 记忆回响 四区）。
    凡「本区不得出现 XX」类反向断言，一律先用 fengwu_area() 把范围收窄到
    [风物志区起点, 记忆回响区哨兵)，再扫描 —— 否则会误伤邻区
    （参见 tests/west_lake_stamps_smoke/verify_qa.py 中 A136 的作用域事故复盘）。

覆盖维度（任务点 a–k + QA 独立扩展 L / M）：
  0  门控作用域自检          A  注册表结构 (a)        B  手作渠道已接入 (b)
  C  拾得不阻断/不耗时段 (c·g) D  与记忆回响互斥 (d)   E  grant 幂等 (e)
  F  满 24 才授称号 (f)      G  ITEM_DB 购得 6 件 (h) H  大成 CG 零新美术 (i)
  I  零新 Autoload (j)       J  NG+ 进度清零 (k)      K  单向数据流 + 缩进
  L  【QA 扩展】拾得可达性：硬门槛合法 + 软加权真够得着
  M  【DS-RN-04b】手作渠道：纯 flag 白嫖防护 + 消耗语义 + grantFengwu 触发集满

环境变量 FENGWU_QA_ROOT 可覆盖工程根目录 —— 供反向变异测试指向沙箱副本，
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

ROOT = Path(os.environ.get("FENGWU_QA_ROOT", Path(__file__).resolve().parents[2]))
SCRIPTS = ROOT / "scripts"

COLL    = SCRIPTS / "CollectionManager.gd"
GM      = SCRIPTS / "GameManager.gd"
MAIN    = SCRIPTS / "MainGame.gd"
FWUI    = SCRIPTS / "FengwuBookUI.gd"
LOCMGR  = SCRIPTS / "LocationManager.gd"
ENDING  = SCRIPTS / "EndingScreen.gd"
SAVESYS = SCRIPTS / "SaveSystem.gd"
DLG     = SCRIPTS / "DialogueUI.gd"
EVENTS_LIFE = SCRIPTS / "events_life.json"
PROJECT = ROOT / "project.godot"

AUTOLOAD_EXPECTED = 15
FENGWU_TOTAL_EXPECTED = 24
CRAFT_COST_TOTAL_EXPECTED = 95          # DS-RN-04b：6 条手作材料费合计
CRAFT_MATERIAL = "handmade_gift"        # 手作唯一原料（int_craft_make 产出，repeatable）
OBTAIN_DIST_EXPECTED = {"拾得": 12, "购得": 6, "手作": 6}
CATEGORY_ALLOWED = {"味", "物", "草木", "声景"}
SEASON_ALLOWED = {"", "spring", "summer", "autumn", "winter"}
WEATHER_ALLOWED = {"", "sunny", "cloudy", "rainy", "snowy"}
SLOT_ALLOWED = {"", "morning", "noon", "after", "evening"}

# ─────────────────────────────────────────────────────────────────
# 断言框架
# ─────────────────────────────────────────────────────────────────
_n = 0
failures, concerns, notes = [], [], []


def check(cond, desc, detail=""):
    global _n
    _n += 1
    tag = f"Q{_n:02d}"
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


def section(title):
    print(f"\n--- {title} ---")


# ─────────────────────────────────────────────────────────────────
# GDScript 文本工具（字符串感知）
# ─────────────────────────────────────────────────────────────────
def extract_block(src: str, anchor: str) -> str:
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
    text = re.sub(r'Color\(\s*("([^"\\]|\\.)*")\s*\)', r"\1", text)
    return text


def load_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_to_py(extract_block(path.read_text(encoding="utf-8"), anchor)))


def src_of(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def code_only(text: str) -> str:
    """字符串感知地剥掉整行注释与行尾注释。

    用于所有「本区不得出现 XX」类反向断言 —— 注释里出现 advance_time / grant_fengwu
    等词属正常文档说明，不应触发 FAIL；反过来也防止注释掩护真实代码。
    Color("#334155") 这类字符串内的 # 会被正确保留。
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
    m = re.search(r"^func %s\(.*?\).*?:\n(.*?)(?=^func |\Z)" % re.escape(name), src, re.S | re.M)
    return m.group(1) if m else ""


# ─────────────────────────────────────────────────────────────────
# 作用域收窄：切出 CollectionManager.gd 的「风物志」区
#   起点：风物志区块横幅；终点：记忆回响区块横幅（哨兵注释）
# 起点/终点缺失一律安全失败（扩大范围，宁可误报不可漏检），并记录降级。
# ─────────────────────────────────────────────────────────────────
FENGWU_AREA_START = "# ── 西湖风物志（DS-RN-04）"
FENGWU_AREA_END_MARKERS = (
    "# ── 记忆回响 · 情境回响",
    "# ── 记忆回响",
    "const ECHO_MATURE_DAYS",
)
_scope_degraded = []


def fengwu_area(text: str):
    start = text.find(FENGWU_AREA_START)
    if start < 0:
        _scope_degraded.append("起点标记缺失→从文件头开扫")
        start = 0
    end = -1
    for marker in FENGWU_AREA_END_MARKERS:
        idx = text.find(marker, start)
        if idx >= 0:
            end = idx
            break
    if end < 0:
        _scope_degraded.append("终点哨兵缺失→扫到文件尾")
        end = len(text)
    return text[start:end], text.count("\n", 0, start) + 1, text.count("\n", 0, end) + 1


# ═════════════════════════════════════════════════════════════════
print("=" * 78)
print("QA-RN-04  西湖风物志 · 独立逻辑级烟雾测试 / 质量门")
print(f"root = {ROOT}")
print("=" * 78)

coll_src   = src_of(COLL)
gm_src     = src_of(GM)
main_src   = src_of(MAIN)
fwui_src   = src_of(FWUI) if FWUI.exists() else ""
loc_src    = src_of(LOCMGR)
ending_src = src_of(ENDING)
dlg_src    = src_of(DLG)
events_raw = src_of(EVENTS_LIFE)
EVENTS     = json.loads(events_raw)

AREA, AREA_L0, AREA_L1 = fengwu_area(coll_src)

FENGWU  = load_literal(COLL, "const FENGWU_ITEMS = ")
ITEM_DB = load_literal(GM, "const ITEM_DB = ")
GALLERY = load_literal(GM, "GALLERY_ITEMS = ")
LOCS    = load_literal(GM, "var locations = ")

print(f"\n[parse] FENGWU_ITEMS={len(FENGWU)}  ITEM_DB={len(ITEM_DB)}  "
      f"GALLERY_ITEMS={len(GALLERY)}  locations={len(LOCS)}  events_life={len(EVENTS)}")
print(f"[scope] 风物志区 = CollectionManager.gd L{AREA_L0}–L{AREA_L1}（{AREA_L1 - AREA_L0} 行）")

fids       = list(FENGWU.keys())
pickup_ids = [f for f in fids if FENGWU[f].get("obtain") == "拾得"]
buy_ids    = [f for f in fids if FENGWU[f].get("obtain") == "购得"]
craft_ids  = [f for f in fids if FENGWU[f].get("obtain") == "手作"]

# ── 0. 门控作用域自检 ──────────────────────────────────────────
section("0. 门控作用域自检（scope sanity —— 防误伤邻区 / 防死断言）")
check(not _scope_degraded and "const FENGWU_ITEMS" in AREA and "func pick_fengwu_pickup" in AREA,
      "风物志区起点+终点哨兵均命中，且区块内确含 FENGWU_ITEMS / pick_fengwu_pickup",
      str(_scope_degraded))
check("WEST_LAKE_STAMP_SCENES" not in AREA and "func grant_stamp" not in AREA
      and "ECHO_MATURE_DAYS" not in AREA and "pick_memory_echo" not in AREA,
      "区块**未**扫入十景集章区与记忆回响区（作用域未溢出）")

# ── A. 注册表结构 ───────────────────────────────────────────────
section("A. FENGWU_ITEMS 注册表结构  (任务点 a)")
check(len(FENGWU) == FENGWU_TOTAL_EXPECTED,
      f"FENGWU_ITEMS 恰含 {FENGWU_TOTAL_EXPECTED} 槽", f"实得 {len(FENGWU)}")
dist = Counter(FENGWU[f].get("obtain", "") for f in fids)
check(dict(dist) == OBTAIN_DIST_EXPECTED,
      "obtain 字段分布 == 拾得12 / 购得6 / 手作6", str(dict(dist)))
order = [FENGWU[f].get("obtain") for f in fids]
check(len(set(fids)) == len(fids) and order == ["拾得"] * 12 + ["购得"] * 6 + ["手作"] * 6,
      "fid 无重复，且插入顺序按 拾得→购得→手作 分组连续（= 图鉴 6×4 格子顺序）", str(order))
REQ = ("name", "category", "obtain", "loc", "season", "weather", "slot", "hint")
schema_bad = {}
for f in fids:
    errs = [k for k in REQ if k not in FENGWU[f]]
    if FENGWU[f].get("category") not in CATEGORY_ALLOWED:
        errs.append("category=" + str(FENGWU[f].get("category")))
    if not str(FENGWU[f].get("hint", "")).strip():
        errs.append("hint 空")
    if errs:
        schema_bad[f] = errs
names = [FENGWU[f].get("name") for f in fids]
check(not schema_bad and len(set(names)) == 24,
      "每槽字段齐全(8 字段) + category ∈ {味,物,草木,声景} + hint 非空 + 24 风物名唯一",
      str(schema_bad or [n for n, c in Counter(names).items() if c > 1]))
m_total = re.search(r"const FENGWU_TOTAL\s*:?=\s*(\d+)", coll_src)
defs = [p.name for p in SCRIPTS.rglob("*.gd")
        if re.search(r"FENGWU_ITEMS\s*=\s*\{", p.read_text(encoding="utf-8"))]
check(m_total and int(m_total.group(1)) == len(FENGWU) and defs == ["CollectionManager.gd"],
      f"FENGWU_TOTAL 常量 == 注册表实长 {len(FENGWU)}，且全工程仅一处定义 FENGWU_ITEMS（唯一真源）",
      f"TOTAL={m_total.group(1) if m_total else '缺失'} defs={defs}")

# ── B. 手作 6 槽已接入（DS-RN-04b 补完）─────────────────────────
section("B. 手作 6 槽 —— 已接入、且授予通道唯一  (任务点 b · DS-RN-04b)")
dirty = {f: {k: FENGWU[f][k] for k in ("loc", "season", "weather", "slot") if FENGWU[f].get(k) != ""}
         for f in craft_ids}
dirty = {k: v for k, v in dirty.items() if v}
check(len(craft_ids) == 6 and not dirty,
      "6 个 obtain==\"手作\" 槽的 loc/season/weather/slot 全为空串（手作不受地点/季节/天气/时段约束）",
      f"count={len(craft_ids)} dirty={dirty}")
hard_grant = [f"{p.name}:{f}" for p in SCRIPTS.rglob("*.gd")
              for f in craft_ids
              if re.search(r'(grant_fengwu\(\s*"%s"|set_flag\(\s*"fengwu_%s")' % (re.escape(f), re.escape(f)),
                           code_only(p.read_text(encoding="utf-8")))]
in_db = [f for f in craft_ids if f in ITEM_DB]
check(not in_db and not hard_grant,
      "手作 fid 既不进 ITEM_DB（纯 flag：杜绝 price 缺省被 ShopUI 白嫖 / 杜绝购得钩子旁路），"
      "全工程 .gd 亦无硬编码 grant/set_flag —— 授予只能来自数据驱动的 fw_craft_* 事件",
      f"in_ITEM_DB={in_db} hardcoded={hard_grant}")
pick_body = code_only(func_body(coll_src, "pick_fengwu_pickup"))
retro_body = code_only(func_body(coll_src, "_retroactive_fengwu_check"))
check('!= "拾得": continue' in pick_body and '!= "购得": continue' in retro_body,
      "拾得池显式只收「拾得」、补偿扫描显式只收「购得」→ 手作被这两条旧通道双重排除，"
      "只能经 fw_craft_* 授予（通道唯一，不会被误授）")
craft_evs = [e for e in EVENTS if str(e.get("id", "")).startswith("fw_craft_")]
granted = {}
for e in craft_evs:
    for sc in e.get("scenes", []):
        g = sc.get("grantFengwu")
        if g:
            granted.setdefault(g, []).append(e["id"])
uncovered = [f for f in craft_ids if f not in granted]
multi = {g: v for g, v in granted.items() if len(v) > 1}
alien = [g for g in granted if g not in craft_ids]
check(len(craft_evs) == 6 and not uncovered and not multi and not alien,
      "6 个手作槽 ↔ 6 条 fw_craft_* 事件**一一映射**（每槽恰 1 个 grantFengwu 来源，"
      "无漏槽 / 无双事件抢同一槽 / 无指向非手作槽）",
      f"events={len(craft_evs)} uncovered={uncovered} multi={multi} alien={alien}")
reach = list(fids)
reach_body = code_only(func_body(coll_src, "get_fengwu_reachable_total"))
reach_ok = (re.fullmatch(r"\s*return FENGWU_TOTAL\s*", reach_body) is not None)
check(len(reach) == FENGWU_TOTAL_EXPECTED and reach_ok,
      f"全部 {FENGWU_TOTAL_EXPECTED} 件静态可达（12 拾得 + 6 购得 + 6 手作，手作渠道已补完）；"
      f"且 get_fengwu_reachable_total() 直接 return FENGWU_TOTAL —— 不得再按 obtain 排除手作，"
      f"否则 FengwuBookUI 会向玩家谎报「本章可达 18 件，余下为手作，将在后续章节开放」",
      f"实得 {len(reach)} reachable_body={reach_body.strip()!r}")

# ── C. 拾得路径：不阻断探索、只加权、不耗时段 ──────────────────
section("C. 拾得路径 —— 软条件只加权 / 不阻断探索 / 不耗时段  (任务点 c·g)")
soft_gate_hits = [l.strip() for l in pick_body.splitlines()
                  if re.search(r"\b(season|weather|slot)\b", l) and re.search(r"\b(continue|return)\b", l)]
bonus_lines = re.findall(r"if \w+ != \"\" and \w+ == (season|weather|slot):\s*chance \+= FENGWU_PICK_BONUS",
                         pick_body)
check(re.search(r'if String\(data\.get\("loc", ""\)\) != loc_id: continue', pick_body) is not None
      and not soft_gate_hits and sorted(bonus_lines) == ["season", "slot", "weather"],
      "loc 是唯一硬门槛；季节/天气/时段三项各自只做 chance += BONUS 加权，"
      "绝不出现在任何 continue/return 分支",
      f"soft_gates={soft_gate_hits} bonus={sorted(bonus_lines)}")
forbidden = [t for t in ("advance_time", "slot_index", "start_event", "build_", "add_favor", "statDelta")
             if t in pick_body]
check(not forbidden,
      "拾得路径不出现 advance_time / slot_index / start_event / build_* / add_favor / statDelta"
      "（不耗时段、不改状态、不播演出）", str(forbidden))
slot_fn = code_only(func_body(gm_src, "_get_slot_id"))
check("GameManager._get_slot_id()" in pick_body
      and re.fullmatch(r'\s*var slots = \["morning", "noon", "after", "evening"\]\s*'
                       r'return slots\[slot_index\] if slot_index < slots\.size\(\) else "morning"\s*',
                       slot_fn) is not None,
      "拾得调用 _get_slot_id() 仅为**读取**当前时段做软加权 —— 该函数是纯读（无赋值、不推进时间）",
      slot_fn.strip()[:140])
mg_lines = [l.strip() for l in code_only(func_body(main_src, "_on_location_selected")).splitlines() if l.strip()]
i_pick = next((i for i, l in enumerate(mg_lines) if "pick_fengwu_pickup" in l), -1)
check(i_pick >= 0 and mg_lines[i_pick] == "CollectionManager.pick_fengwu_pickup(loc_id)"
      and i_pick + 1 < len(mg_lines)
      and mg_lines[i_pick + 1] == "hotspot_ui.on_location_selected(loc_id)",
      "MainGame 中拾得调用是**裸语句**（无 if 包裹、无 return、返回值丢弃），"
      "其后紧接 hotspot_ui.on_location_selected → 探索流程必然继续，不被阻断",
      str(mg_lines[max(0, i_pick):i_pick + 2]) if i_pick >= 0 else "未找到调用")

# ── D. 与记忆回响互斥 ───────────────────────────────────────────
section("D. 与记忆回响的互斥结构  (任务点 d)")
i_echo = next((i for i, l in enumerate(mg_lines) if "_try_memory_echo(loc_id)" in l), -1)
check(i_echo >= 0 and re.fullmatch(r"if _try_memory_echo\(loc_id\): return", mg_lines[i_echo]) is not None,
      "回响 step 0 的形态是 `if _try_memory_echo(loc_id): return` —— 命中即 return，互斥的技术根据",
      mg_lines[i_echo] if i_echo >= 0 else "未找到")
check(0 <= i_echo < i_pick,
      f"回响 step 0 位于拾得 step 0.5 **之前**（源码语句序 echo@{i_echo} < pick@{i_pick}）")
check("pick_fengwu_pickup" not in code_only(func_body(main_src, "_try_memory_echo")),
      "_try_memory_echo() 内部不调用拾得（回响分支完全不触碰风物志，二者不可能同屏）")
abs_echo = main_src[:main_src.index("if _try_memory_echo(loc_id): return")].count("\n") + 1
abs_pick = main_src[:main_src.index("CollectionManager.pick_fengwu_pickup(loc_id)")].count("\n") + 1
note(f"互斥两点实测绝对行号：记忆回响 return @ MainGame.gd L{abs_echo}，风物拾得 @ L{abs_pick}"
     f"（任务书所述 L220 为近似值；本门禁按**语句相对顺序**断言，不依赖行号，重构后仍有效）")

# ── E. grant_fengwu 幂等（结构 + mock 复演）───────────────────
section("E. grant_fengwu 幂等性  (任务点 e · mock 复演)")
grant_code = code_only(func_body(coll_src, "grant_fengwu"))
check(re.search(r"if not FENGWU_ITEMS\.has\(fid\): return false", grant_code) is not None
      and re.search(r"if GameManager\.flags\.has\(flag\): return false", grant_code) is not None
      and "GameManager.set_flag(flag, true)" in grant_code
      and 'set_flag(flag + "_day", GameManager.day)' in grant_code,
      "结构守卫齐备：未知 fid → false；已入册 → false（幂等）；授予写 fengwu_<fid> + _day")


class Sim:
    """按 GDScript 源码语义复刻的最小模型（上面的结构断言保证模型与实现同构）。"""

    def __init__(self):
        self.flags, self.day, self.toasts, self.gallery = {}, 100, [], []

    def grant(self, fid):
        if fid not in FENGWU:
            return False
        flag = "fengwu_" + fid
        if flag in self.flags:
            return False
        self.flags[flag] = True
        self.flags[flag + "_day"] = self.day
        if self.completion():
            return True
        self.toasts.append("入册:" + fid)
        return True

    def completion(self):
        if "west_lake_fengwu_complete" in self.flags:
            return False
        if any(("fengwu_" + f) not in self.flags for f in FENGWU):
            return False
        self.flags["west_lake_fengwu_complete"] = True
        self.flags["title_西湖风物通"] = True
        self.gallery.append("west_lake_fengwu_complete")
        self.toasts.append("集满")
        return True


s = Sim()
dummy = fids[0]  # 从存活注册表取首个 fid 作 mock 桩，避免回归测试耦合具体 fid
r = [s.grant(dummy) for _ in range(3)]
check(r == [True, False, False] and s.toasts.count("入册:" + dummy) == 1,
      "mock：同一 fid 连调 3 次 → 只有首次返回 true，且入册 toast 只发 1 条（不重复刷屏）",
      f"returns={r} toasts={s.toasts}")
s.day = 200
s.grant(dummy)
check(s.flags.get("fengwu_" + dummy + "_day") == 100 and s.grant("no_such_fid") is False
      and "fengwu_no_such_fid" not in s.flags,
      "mock：重复调用不覆盖首次入册日（_day 稳定）；未知 fid 不落任何 flag",
      f"day={s.flags.get('fengwu_' + dummy + '_day')}")

# ── F. 满 24 才授称号（mock 复演 23 vs 24）─────────────────────
section("F. _check_fengwu_completion —— 满 24 才授称号  (任务点 f · mock 复演)")
comp_code = code_only(func_body(coll_src, "_check_fengwu_completion"))
atoms = [t for t in ("set_flag(FENGWU_COMPLETE_FLAG, true)", "set_flag(FENGWU_TITLE_FLAG, true)",
                     "unlock_gallery(FENGWU_COMPLETE_FLAG)", "show_toast.emit") if t not in comp_code]
check(re.search(r"for fid in FENGWU_ITEMS\.keys\(\):\s*\n\s*if not is_fengwu_owned\(fid\): return false",
                comp_code) is not None
      and re.search(r"if GameManager\.flags\.has\(FENGWU_COMPLETE_FLAG\): return false", comp_code) is not None
      and not atoms,
      "遍历注册表全键判定（不硬编码计数）+ 已完成即 false（不重复发奖）+ 集满四件原子动作齐备"
      "（complete flag / 称号 flag / 解锁画廊 / toast）", f"缺失原子动作={atoms}")
s23 = Sim()
for f in fids[:23]:
    s23.grant(f)
owned23 = len([k for k in s23.flags if k.startswith("fengwu_") and not k.endswith("_day")])
check(owned23 == 23 and s23.completion() is False
      and "title_西湖风物通" not in s23.flags and "west_lake_fengwu_complete" not in s23.flags,
      "mock：**23/24 → 不授称号、不置 complete、不解锁画廊**（差一件也不放行）",
      f"owned={owned23}")
s24 = Sim()
for f in fids:
    s24.grant(f)
check(s24.flags.get("title_西湖风物通") is True and s24.flags.get("west_lake_fengwu_complete") is True
      and s24.gallery == ["west_lake_fengwu_complete"]
      and s24.toasts.count("集满") == 1 and s24.toasts[-1] == "集满"
      and ("入册:" + fids[-1]) not in s24.toasts
      and s24.completion() is False,
      "mock：**24/24 → 称号+complete+画廊三者原子达成**；集满当次只发「集满」一条（跳过该件普通 toast）；"
      "再次调用返回 false（奖励不重复）", str(s24.toasts[-2:]))
m_title = re.search(r'const FENGWU_TITLE_FLAG\s*:?=\s*"([^"]+)"', coll_src)
check(m_title and m_title.group(1) == "title_西湖风物通" and m_title.group(1).startswith("title_"),
      'FENGWU_TITLE_FLAG == "title_西湖风物通" 且带 title_ 前缀（EndingScreen 自动消费/跨周目继承）',
      m_title.group(1) if m_title else "未定义")
s_reach = Sim()
for f in pickup_ids + buy_ids:
    s_reach.grant(f)
locked18 = ("title_西湖风物通" not in s_reach.flags
            and "west_lake_fengwu_complete" not in s_reach.flags)
for f in craft_ids:
    s_reach.grant(f)
check(locked18 and s_reach.flags.get("title_西湖风物通") is True
      and s_reach.flags.get("west_lake_fengwu_complete") is True
      and s_reach.toasts.count("集满") == 1,
      "mock：拾得 12 + 购得 6 = 18 件拿满**仍不授称号**（手作 6 件是必经通道，不是可选装饰）；"
      "补齐 6 件手作后称号 + 大成 CG 同时点亮，「集满」toast 恰发 1 次",
      f"18件时仍锁={locked18} "
      f"24件后 titles={sorted(k for k in s_reach.flags if k.startswith('title_'))} "
      f"toasts尾={s_reach.toasts[-1:]}")

# ── G. ITEM_DB 购得 6 件 ────────────────────────────────────────
section("G. ITEM_DB 购得 6 件契约  (任务点 h)")
db_fengwu = {k: v for k, v in ITEM_DB.items() if v.get("category") == "fengwu"}
check(len(db_fengwu) == 6 and set(db_fengwu) == set(buy_ids),
      "ITEM_DB 恰 6 条 category==\"fengwu\"，且 key 集合与 FENGWU_ITEMS 购得 6 fid 逐字相同"
      "（购得钩子以 item_id 当 fid 落账，错一个字即静默不入册）",
      f"db={sorted(db_fengwu)} reg={sorted(buy_ids)}")
bad_price = {k: v.get("price") for k, v in db_fengwu.items()
             if not isinstance(v.get("price"), int) or v["price"] <= 0}
name_drift = {k: (db_fengwu[k].get("name"), FENGWU[k].get("name"))
              for k in db_fengwu if db_fengwu[k].get("name") != FENGWU[k].get("name")}
check(not bad_price and not name_drift,
      "6 条购得物 price 均为正整数（非白嫖），且 ITEM_DB.name 与 FENGWU_ITEMS.name 逐条一致（无双真源漂移）",
      f"price={bad_price} drift={name_drift}")
hook = code_only(func_body(coll_src, "_try_grant_fengwu_item"))
check('!= "fengwu": return' in hook and "grant_fengwu(item_id)" in hook
      and "_try_grant_fengwu_item(item_id)" in code_only(func_body(coll_src, "add_item"))
      and "CollectionManager.add_item(item_id, amount)" in func_body(gm_src, "add_item"),
      "购得链路闭合：ShopUI → GameManager.add_item → CollectionManager.add_item 尾部钩子 → "
      "category==\"fengwu\" → grant_fengwu(item_id)")

# ── H. 画廊大成 CG + 零新美术 ──────────────────────────────────
section("H. GALLERY_ITEMS 大成 CG · 专属美术资源  (任务点 i)")
gal = [g for g in GALLERY if g.get("flag") == "west_lake_fengwu_complete"]
gal_flags = [x.get("flag") for x in GALLERY if x.get("flag")]
check(len(gal) == 1 and all(k in gal[0] for k in ("char", "pose", "label", "hint", "flag", "bg"))
      and len(gal_flags) == len(set(gal_flags)),
      "GALLERY_ITEMS 恰含 1 条「西湖风物·大成」(flag==west_lake_fengwu_complete)，字段齐全，具名 flag 无重复",
      f"count={len(gal)} dup={[f for f, c in Counter(gal_flags).items() if c > 1]}")
if gal:
    bg = str(gal[0].get("bg", ""))
    bg_path = ROOT / bg.replace("res://", "")
    reuse = [x.get("label") for x in GALLERY if x.get("bg") == bg and x is not gal[0]]
    m_comp = re.search(r'const FENGWU_COMPLETE_FLAG\s*:?=\s*"([^"]+)"', coll_src)
    check(bg_path.name == "west_lake_fengwu_complete.jpg" and bg_path.exists()
          and bg_path.stat().st_size > 20_000 and not reuse
          and m_comp and m_comp.group(1) == gal[0].get("flag"),
          f"大成 CG 用**专属**已落盘 jpg（{bg_path.name}"
          f"{'，' + str(bg_path.stat().st_size) + ' B' if bg_path.exists() else '，缺失'}），"
          f"且不与任何其他画廊条目共用底图 —— 原与「毕业纪念册」同图会让画廊出现两格相同背景，"
          f"art-director 已补专属图；且 FENGWU_COMPLETE_FLAG 常量与画廊 flag 字面量一致",
          f"exists={bg_path.exists()} reuse={reuse}")

# ── I. 零新 Autoload / 零新场景 ────────────────────────────────
section("I. 零新 Autoload / 零新场景文件  (任务点 j)")
m = re.search(r"\[autoload\]\n(.*?)(?=\n\[|\Z)", src_of(PROJECT), re.S)
autoloads = re.findall(r"^(\w+)=", m.group(1), re.M) if m else []
check(len(autoloads) == AUTOLOAD_EXPECTED and not any("engwu" in a for a in autoloads),
      f"project.godot [autoload] 恰 {AUTOLOAD_EXPECTED} 项且无 Fengwu* —— 零新 Autoload",
      f"count={len(autoloads)} list={autoloads}")
tscn = [p.name for p in ROOT.rglob("*Fengwu*.tscn")]
check(not tscn and FWUI.exists() and 'load("res://scripts/FengwuBookUI.gd")' in main_src,
      "无 Fengwu*.tscn；FengwuBookUI.gd 存在且由 MainGame 运行时 load() 按需实例化（不常驻内存）",
      f"tscn={tscn} exists={FWUI.exists()}")
check('{"text": "🍃 风物志"' in main_src and '"fn": _show_fengwubook_popup' in main_src
      and "if not scr: return" in func_body(main_src, "_show_fengwubook_popup"),
      "更多菜单含「🍃 风物志」按钮 → _show_fengwubook_popup，且 load 失败早退（防空引用崩溃）")

# ── J. NG+ 风物进度清零 ────────────────────────────────────────
section("J. NG+ 语义 —— 风物进度清零重来  (任务点 k)")
ng_block = ending_src[ending_src.index("GameManager.flags = {}"):]
restored = re.findall(r'GameManager\.flags\[("(?:[^"]+)"|\s*"title_" \+ t)\]', ng_block)
restored_keys = sorted(set(x.strip().strip('"') for x in restored))
check(re.search(r"GameManager\.flags = \{\}", ending_src) is not None
      and restored_keys == ['ng_count', 'seen_endings', 'title_" + t'],
      "EndingScreen NG+ 整体清空 flags，清空后回写的白名单**只有** ng_count / seen_endings / title_*",
      str(restored_keys))
check(not re.search(r'flags\[\s*"(fengwu_|west_lake_fengwu_complete)', ng_block)
      and "fengwu" not in src_of(SAVESYS).lower(),
      "白名单不含 fengwu_* / west_lake_fengwu_complete → 新周目进度清零重来；"
      "SaveSystem 亦无 fengwu 特判（随 flags 整体序列化，零存档迁移）")

# ── K. 单向数据流 + 缩进风格 ───────────────────────────────────
section("K. FengwuBookUI 单向数据流 + 缩进风格")
writes = [f"L{n}: {l.strip()}" for n, l in enumerate(fwui_src.splitlines(), 1)
          if re.search(r"set_flag\(|GameManager\.flags\s*\[|unlock_gallery\(|grant_fengwu\(", l)
          and not l.lstrip().startswith("#")]
check(not writes and "signal closed" in fwui_src and code_only(fwui_src).count("CollectionManager.") >= 5,
      "FengwuBookUI 零写操作（无 set_flag/flags[]/unlock_gallery/grant_fengwu），暴露 signal closed，"
      "数据全部经 CollectionManager 只读 API —— 单向数据流成立", str(writes))
INDENT_EXPECT = {"CollectionManager.gd": "tab", "GameManager.gd": "space",
                 "MainGame.gd": "space", "FengwuBookUI.gd": "space"}
indent_bad = {}
for fname, want in INDENT_EXPECT.items():
    text = (SCRIPTS / fname).read_text(encoding="utf-8")
    lines = [l for l in text.splitlines() if l.strip()]
    tabs = sum(1 for l in lines if l.startswith("\t"))
    spcs = sum(1 for l in lines if l.startswith(" "))
    mixed = [n for n, l in enumerate(text.splitlines(), 1) if re.match(r"^(\t+ | +\t)", l)]
    ok = ((tabs > 0 and spcs == 0) if want == "tab" else (spcs > 0 and tabs == 0)) and not mixed
    if not ok:
        indent_bad[fname] = f"want={want} tab={tabs} space={spcs} mixed={mixed[:3]}"
check(not indent_bad,
      "4 个改动文件缩进风格各自纯净（CollectionManager=tab，GameManager/MainGame/FengwuBookUI=space，"
      "且无行内混用）—— 防 GDScript mixed-indent 解析错误", str(indent_bad))

# ── L. 【QA 独立扩展】拾得可达性 ───────────────────────────────
section("L. 【QA 独立扩展】拾得可达性 —— 硬门槛合法 + 软加权真够得着")
bad_loc = {f: FENGWU[f]["loc"] for f in pickup_ids if FENGWU[f].get("loc") not in LOCS}
check(not bad_loc,
      "12 件拾得的 loc 硬门槛全部是 GameManager.locations 中的合法地点 id"
      "（指向不存在的地点 = 该槽永久锁死，称号永锁）", str(bad_loc))
bad_enum = {f: (FENGWU[f].get("season"), FENGWU[f].get("weather"), FENGWU[f].get("slot"))
            for f in fids
            if FENGWU[f].get("season") not in SEASON_ALLOWED
            or FENGWU[f].get("weather") not in WEATHER_ALLOWED
            or FENGWU[f].get("slot") not in SLOT_ALLOWED}
check(not bad_enum,
      "全部 season/weather/slot 取值落在引擎真源枚举内（拼错即静默失去加权，静态测不出、线上难查）",
      str(bad_enum))


def reachable_slots(loc_id: str) -> set:
    s = set(LOCS.get(loc_id, {}).get("slots", []))
    if loc_id == "lakeside":
        s |= {"morning", "noon", "after", "evening"}   # LocationManager 周末覆盖
    return s


dead_bonus = {f: (FENGWU[f]["loc"], FENGWU[f]["slot"], sorted(reachable_slots(FENGWU[f]["loc"])))
              for f in pickup_ids
              if FENGWU[f].get("slot") and FENGWU[f]["slot"] not in reachable_slots(FENGWU[f]["loc"])}
check(re.search(r'if loc_id == "lakeside" and weekend:\s*\n\s*loc_slots = '
                r'\["morning", "noon", "after", "evening"\]', loc_src) is not None
      and not dead_bonus,
      "每件拾得的软 slot 都落在该地点**真的能去**的时段内（否则 +0.12 永不触发，"
      "且图鉴会向玩家显示够不着的提示）；lakeside 周末全时段覆盖仍在",
      str(dead_bonus))
weekend_only = [FENGWU[f]["name"] for f in pickup_ids
                if FENGWU[f].get("slot") and FENGWU[f]["loc"] == "lakeside"
                and FENGWU[f]["slot"] not in set(LOCS["lakeside"].get("slots", []))]
if weekend_only:
    note(f"西湖边 {weekend_only} 的时段加权依赖 LocationManager「周末 lakeside 全时段」那一行"
         f"（工作日上午/中午 lakeside 不可见）→ 该 +0.12 实际只在周末生效，约 2/7 天。"
         f"仍是软条件，不影响可得性；若后续有人删掉那行覆盖，本门禁上一条会立即转 FAIL。")

# ── M. 【DS-RN-04b】手作渠道 ───────────────────────────────────
section("M. 【DS-RN-04b】手作渠道 —— 白嫖防护 / 真消耗 / 触发集满 / 抢得到")
craft_pair = {}                     # fid -> (event, 授予场景)
for e in craft_evs:
    for sc in e.get("scenes", []):
        if sc.get("grantFengwu"):
            craft_pair[sc["grantFengwu"]] = (e, sc)

dm_gate = code_only(func_body(src_of(SCRIPTS / "DataManager.gd"), "get_available_event"))
gate_readonly = ("GameManager.has_item(req_item, req_item_amt)" in dm_gate
                 and "remove_item" not in dm_gate
                 and "GameManager.money < req_money" in dm_gate)
econ_bad = {}
for fid, (e, sc) in craft_pair.items():
    need = int(e.get("requireMoney", 0))
    paid = int((sc.get("statDelta") or {}).get("money", 0))
    errs = []
    if e.get("requireItem") != CRAFT_MATERIAL or int(e.get("requireItemAmt", 1)) != 1:
        errs.append(f"门控原料={e.get('requireItem')}×{e.get('requireItemAmt')}")
    if sc.get("removeItem") != CRAFT_MATERIAL:
        errs.append(f"未真扣原料 removeItem={sc.get('removeItem')}")
    if need <= 0 or paid != -need:
        errs.append(f"门控{need}元/实扣{-paid}元 不配对")
    if errs:
        econ_bad[e["id"]] = errs
craft_cost_total = sum(int(e.get("requireMoney", 0)) for e in craft_evs)
check(gate_readonly and not econ_bad and craft_cost_total == CRAFT_COST_TOTAL_EXPECTED,
      f"经济语义闭合：DataManager 的 requireItem/requireMoney 是**只读门控**（全函数无 remove_item），"
      f"故 6 条事件各自 removeItem 真扣 1 个 {CRAFT_MATERIAL}（否则 1 个礼物能做 6 件）；"
      f"门控金额与 statDelta.money 逐条等额反号（不多扣不白做），合计 {CRAFT_COST_TOTAL_EXPECTED} 元",
      f"gate_readonly={gate_readonly} total={craft_cost_total} bad={econ_bad}")

dup_bad = {}
for e in craft_evs:
    last = e.get("scenes", [{}])[-1]
    errs = []
    if e.get("repeatable", True) is not False:
        errs.append(f"repeatable={e.get('repeatable')}")
    if last.get("setFlag") != e.get("id"):
        errs.append(f"末句 setFlag={last.get('setFlag')}≠事件id")
    if e.get("id") in FENGWU or e.get("id").replace("fw_craft_", "fw_hm_") not in FENGWU:
        errs.append("事件 id 与 fid 命名撞键/失配")
    if e.get("triggerDay"):
        errs.append(f"triggerDay={e.get('triggerDay')}（额外时间门槛，spec 未要求）")
    if errs:
        dup_bad[e.get("id")] = errs
fin_body = code_only(func_body(dlg_src, "finish_event"))
dedupe_ok = (re.search(r'if not ev\.get\("repeatable", false\) and GameManager\.flags\.has\(ev_id\): continue',
                       dm_gate) is not None
             and re.search(r'if ev_id != "" and not current_event\.get\("repeatable", false\):\s*\n\s*'
                           r'GameManager\.set_flag\(ev_id, true\)', fin_body) is not None)
check(not dup_bad and dedupe_ok,
      "不可重刷三重保险：事件 repeatable==false + DialogueUI.finish_event 完成即写 flags[ev_id] + "
      "DataManager 见 flags[ev_id] 即 continue；末句 setFlag 与事件 id 同键（存档回滚也不重开）；"
      "事件 id(fw_craft_*) 与风物 fid(fw_hm_*) 命名分离，不与 fengwu_<fid> 撞键",
      f"dedupe_ok={dedupe_ok} bad={dup_bad}")

dlg_code = code_only(dlg_src)
grant_via_api = re.search(r'if scene\.has\("grantFengwu"\).*?\n\s*CollectionManager\.grant_fengwu\('
                          r'scene\["grantFengwu"\]\)', dlg_code, re.S) is not None
remove_via_api = re.search(r'if scene\.has\("removeItem"\).*?\n\s*CollectionManager\.remove_item\('
                           r'scene\["removeItem"\], 1\)', dlg_code, re.S) is not None
no_bypass = (not re.search(r'set_flag\(\s*"fengwu_" \+ scene', dlg_code)
             and not re.search(r'set_flag\(scene\["grantFengwu"\]', dlg_code)
             and not re.search(r'add_item\(scene\["grantFengwu"\]', dlg_code))
grant_callers = sorted({p.name for p in SCRIPTS.rglob("*.gd")
                        if re.search(r"(?<!func )grant_fengwu\(", code_only(p.read_text(encoding="utf-8")))})
check(grant_via_api and remove_via_api and no_bypass
      and grant_callers == ["CollectionManager.gd", "DialogueUI.gd"],
      "grantFengwu 走 CollectionManager.grant_fengwu()（**唯一**内含 _check_fengwu_completion 的入口）—— "
      "若旁路成 set_flag(\"fengwu_x\") 或 add_item，集满判定永不触发、称号永锁；"
      "removeItem 亦走 CollectionManager.remove_item()。全工程 grant_fengwu 调用点仅 2 处",
      f"grant={grant_via_api} remove={remove_via_api} no_bypass={no_bypass} callers={grant_callers}")

ALL_EVENTS = []
for p in sorted(SCRIPTS.glob("events*.json")):
    d = json.loads(p.read_text(encoding="utf-8"))
    if isinstance(d, list):
        ALL_EVENTS += [x for x in d if isinstance(x, dict)]
GATE_KEYS = ("minStress", "minAddict", "requireFlags", "excludeFlags", "requireHoliday",
             "requireWeather", "requireSeason", "conditionType", "requireNGCount",
             "requireNotEnding", "requireItem", "requireMoney", "charId", "slotId")
# 「永久驻留者」= home/全局 + repeatable(永不被 flags 消耗) + 无任何会退场的状态门控
#   → 一旦其 triggerDay 到达，它每天都在候选池里，priority 更高就永远压死手作事件
squatters = sorted(((int(x.get("priority", 0)), x.get("id"), int(x.get("triggerDay") or 0))
                    for x in ALL_EVENTS
                    if (x.get("location") or "") in ("", "home")
                    and x.get("repeatable", False)
                    and not any(x.get(k) not in (None, "", 0, [], False) for k in GATE_KEYS)),
                   reverse=True)
craft_prios = sorted(int(e.get("priority", 0)) for e in craft_evs)
icm_prio = next((int(x.get("priority", 0)) for x in ALL_EVENTS if x.get("id") == "int_craft_make"), -1)
early = [s for s in squatters if s[2] <= 80 and s[0] >= craft_prios[0]]
check(icm_prio == 190 and craft_prios[0] > icm_prio and len(set(craft_prios)) == 6 and not early,
      f"抢得到：6 条手作 priority {craft_prios} 全部 > 原料产出事件 int_craft_make({icm_prio}) 且互不相同 —— "
      f"int_craft_make 是 repeatable 永久驻留者，若不压过它，手作事件永远拿不到 candidates[0]；"
      f"且开局期（triggerDay≤80）无其他永久驻留者压制",
      f"craft={craft_prios} icm={icm_prio} squatters={squatters} early_blockers={early}")

# 【主理人裁决 · DS-RN-04b 收尾】手作优先级带位锁死。
#   上一轮曾把 fw_craft_* 抬到 291–296（压过全部健康危机事件）→ 判定为过度。
#   正确带位：高于家庭叙事 life_family_support_study(250)，低于最低健康事件 life_health_insomnia(260)。
#   语义：① 持有 handmade_gift 时手作 > 250 胜出可制作；无料时 requireItem 剔除 → 家庭叙事照常触发；
#         ② 4 条健康危机事件（260/270/280/290，均 minStress 门控）对手作保持**绝对优先**，永不被压制。
#   本断言把该裁决固化为门禁，任何人再抬高手作优先级即刻 FAIL。
_LIFE_EVENTS = [x for x in json.loads((SCRIPTS / "events_life.json").read_text(encoding="utf-8"))
                if isinstance(x, dict)]
_prio_of = lambda _eid: next((int(x.get("priority", 0)) for x in _LIFE_EVENTS
                              if x.get("id") == _eid), -1)
FLOOR_ID, CEIL_ID = "life_family_support_study", "life_health_insomnia"
floor_p, ceil_p = _prio_of(FLOOR_ID), _prio_of(CEIL_ID)
craft_life = {x["id"]: int(x.get("priority", 0)) for x in _LIFE_EVENTS
              if str(x.get("id", "")).startswith("fw_craft_")}
band_bad = {k: v for k, v in craft_life.items() if not (floor_p < v < ceil_p)}
# 与「全部 home 池事件」（跨 events*.json 全量）逐值查碰撞
home_others = [(x.get("id"), int(x.get("priority", 0))) for x in ALL_EVENTS
               if x.get("location") == "home" and not str(x.get("id", "")).startswith("fw_craft_")]
clash = sorted({(i, p) for i, p in home_others if p in set(craft_life.values())})
# 健康危机事件必须全部在手作之上
health_evs = sorted(((int(x.get("priority", 0)), x.get("id")) for x in _LIFE_EVENTS
                     if str(x.get("id", "")).startswith("life_health_")
                     and x.get("location") == "home"), reverse=True)
health_above = [h for h in health_evs if h[0] <= max(craft_life.values())] if craft_life else []
check(len(craft_life) == 6 and floor_p == 250 and ceil_p == 260
      and not band_bad and len(set(craft_life.values())) == 6
      and not clash and not health_above,
      f"手作优先级：高于家庭叙事、低于健康事件 —— 6 条 fw_craft_* priority "
      f"{sorted(craft_life.values())} 全部落在开区间 ({FLOOR_ID}={floor_p}, {CEIL_ID}={ceil_p}) 内、"
      f"6 值互异、且不与任何 home 池事件 priority 碰撞（含 {FLOOR_ID.split('_')[-1]} 邻位 "
      f"life_family_expectation=255）。语义锁：有料时手作胜出可制作，无料时 requireItem 剔除→家庭叙事照常；"
      f"{len(health_evs)} 条健康危机事件 {[h[0] for h in health_evs]} 对手作保持绝对优先，"
      f"「手作制作」永不压过健康危机叙事（主理人裁决，禁止回归）",
      f"craft={craft_life} band_bad={band_bad} clash={clash} "
      f"health={health_evs} health_not_above={health_above}")

# ── N. 热修回归看门狗（原关注①②，已根治 → 转正向断言）──────────
section("N. 【热修】拾得额度时序 / 送礼池纯净 —— 原 concern①② 的正向看门狗")

# 原关注①【拾得可重 roll】：FENGWU_PICKUP_DAY_FLAG 曾只在 roll **成功后** 才写，
#   失败不消耗当日额度 → 同段反复进出可无限重 roll，把 0.18~0.42 刷成「每天必得」。
#   根治口径：set_flag 必须排在 randf() 判定**之前**（消耗尝试，而非消耗成功）。
#   本断言用行序比较锁死该时序，任何人把 set_flag 挪回 randf 之后立即转 FAIL。
_pick_lines = pick_body.splitlines()
_i_flag = next((i for i, l in enumerate(_pick_lines)
                if "set_flag(FENGWU_PICKUP_DAY_FLAG, GameManager.day)" in l), -1)
_i_randf = next((i for i, l in enumerate(_pick_lines) if "randf() >= best_chance" in l), -1)
_i_used = next((i for i, l in enumerate(_pick_lines)
                if "is_fengwu_pickup_used_today()" in l), -1)
check(_i_flag >= 0 and _i_randf >= 0 and _i_flag < _i_randf,
      "★ 拾得额度「成败都计」：pick_fengwu_pickup 内 "
      "set_flag(FENGWU_PICKUP_DAY_FLAG, GameManager.day) 的行序 **早于** randf() 概率判定 —— "
      "roll 失败同样消耗当日额度，杜绝「同段反复进出重 roll 刷成每天必得」；"
      "若被挪回 randf 之后，概率感当场失守",
      f"set_flag@{_i_flag} randf@{_i_randf}（要求 set_flag < randf）")
check(_i_used >= 0 and _i_used < _i_flag,
      "同日重入仍被顶部 is_fengwu_pickup_used_today() 早返回拦截（额度写入点在其之后）—— "
      "「每日 1 件」限速与「成败都计」两道语义并存，pity(dry_streak) 跨日累积不受影响",
      f"used_today@{_i_used} set_flag@{_i_flag}")

# 原关注②【送礼池污染】：送礼面板曾无条件遍历 ITEM_DB，6 件购得风物被列为可赠礼物，
#   走兜底 +3 好感。根治口径：填装循环内、owned 判定**之前** skip category=="fengwu"。
_gift_body = code_only(func_body(dlg_src, "_on_gift_pressed"))
_g_lines = _gift_body.splitlines()
_g_loop = next((i for i, l in enumerate(_g_lines)
                if re.search(r"for\s+item_id\s+in\s+db\.keys\(\)\s*:", l)), -1)
_g_skip = next((i for i, l in enumerate(_g_lines)
                if re.search(r'==\s*"fengwu"\s*:\s*continue', l) and "category" in l), -1)
_g_owned = next((i for i, l in enumerate(_g_lines)
                 if re.search(r"inventory\.get\(item_id", l)), -1)
check(_g_loop >= 0 and _g_skip >= 0 and _g_owned >= 0 and _g_loop < _g_skip < _g_owned,
      "★ 送礼池纯净：_on_gift_pressed 填装循环内、owned 判定**之前** 以 "
      'category == "fengwu" → continue 跳过风物（收藏品不可赠）—— '
      "6 件购得风物不再进礼物列表、不再走兜底 +3 好感污染送礼体验",
      f"for@{_g_loop} skip@{_g_skip} owned@{_g_owned}（要求 for < skip < owned）")
_hm_cat = str(ITEM_DB.get(CRAFT_MATERIAL, {}).get("category", ""))
check(_hm_cat != "fengwu",
      f"skip 不误伤手作原料：{CRAFT_MATERIAL} 的 category=\"{_hm_cat}\"（非 fengwu）→ "
      f"仍可正常作为礼物赠送，手作渠道与送礼渠道互不干扰",
      f"category={_hm_cat!r}")

# ── 非阻塞关注项（advisory）────────────────────────────────────
section("非阻塞关注项 (advisory)")
late_squat = [s for s in squatters if s[0] > craft_prios[-1] and s[2] > 80]
# 关注③根治核验：6 条手作必须全部压过晚期永久驻留者 life_family_support_study，
#   否则 day 361 起（初三全程）手作窗口被它每日压死 → 大成 CG 永久不可达。
_lfss = next((int(x.get("priority", 0)) for x in ALL_EVENTS
              if x.get("id") == "life_family_support_study"), -1)
if _lfss > 0 and craft_prios[0] > _lfss and not late_squat:
    note(f"【手作窗口闭合期 · 已根治】6 条 fw_craft_* priority {craft_prios} 全部 > "
         f"life_family_support_study({_lfss}, repeatable, triggerDay=361, 无状态门控) —— "
         f"day 361 后手作窗口不再被压死，全程 570 天可做。"
         f"且「有料就做、无料叙事」自动交替：持有 {CRAFT_MATERIAL} 时手作胜出；"
         f"不持有时 fw_craft_* 被 requireItem 门控剔除（DataManager L249-250 continue），"
         f"life_family_support_study 照常触发，家庭叙事不被饿死。"
         f"home 池已无 priority 高于手作的永久驻留者（squatters={squatters}）。")
elif late_squat:
    _p, _id, _d = late_squat[0]
    concern(f"【手作窗口有闭合期 · 中】home 池存在晚期「永久驻留者」{_id}"
            f"（priority={_p}, repeatable=true, triggerDay={_d}, 无任何状态门控, 引擎无事件冷却机制）。"
            f"自 day {_d} 起它每天都在候选池且 {_p} > 手作最高 {craft_prios[-1]} > int_craft_make({icm_prio})，"
            f"→ **day {_d} 之后在家既做不出手作原料、也做不了 6 件手作风物**，"
            f"「西湖风物通」称号与大成 CG 随之永久不可达。"
            f"按 GameManager.get_grade_info() 真源（90 天/学期，全程 570 天）换算："
            f"手作可用窗口 = day 81–{_d - 1}（初一下～初二下，共 {_d - 81} 天，占全程 "
            f"{round((_d - 81) * 100 / 570)}%），初三全程（day {_d}–570）关闭。"
            f"集齐 6 件仅需 12 次在家事件（6 次产原料 + 6 次手作），窗口充裕，"
            f"不构成 soft-lock，且该压制对既有 int_craft_make 同样成立（非本次引入的回归）。"
            f"若要根治，二选一：① 给 {_id} 加 excludeFlags/冷却；② 把 fw_craft_* 抬到 {_p} 以上"
            f"（但会压过 life_family_* 叙事事件，属设计决策，须主理人裁决 —— 本次实现按 spec 未擅改）。")
adv_callers = sorted({p.name for p in SCRIPTS.rglob("*.gd")
                      if re.search(r"\badvance_time\(\)", code_only(p.read_text(encoding="utf-8")))})
if "LocationManager.gd" not in adv_callers and "HotspotExploreUI.gd" not in adv_callers:
    note("【拾得节奏 · 已根治】「进入地点」本身不调用 advance_time()"
         f"（advance_time 仅由 {adv_callers} 触发），故同一时段可反复进出同一地点。"
         "但 FENGWU_PICKUP_DAY_FLAG 现已在 randf() 判定**之前**写入（见 N 区断言），"
         "重入即被顶部 is_fengwu_pickup_used_today() 早返回拦下 —— "
         "「反复进出重 roll」通道已关闭，概率感恢复，故降级为 note 存档备查。")
# 「过期文案」扫描 —— 必须区分两类，否则会把「玩家永不可见的兜底文案」误报成阻塞项：
#   · 无条件渲染处（典型：_obtain_tip() 的未获得格 tooltip）：每次点开必然显示，
#     文案过期 = 当场误导玩家 → concern。
#   · 受 `if reachable < prog["total"]:` 守卫处（顶部「本章可达」提示）：DS-RN-04b 后
#     reachable==total（见 B 区 reachable 断言），整块 Label 根本不生成 → 玩家永不可见；
#     且这块是为「将来真开新章导致 reachable<total」保留的**正确**兜底，不该删 → note。
#   守卫一旦被移除、或旧串出现在守卫块之外（含 tooltip 回退），立即重新升回 concern
#   —— 本扫描不是死断言，仍是 L331 文案回归的实时探针。
STALE_PAT = ("尚未开放", "后续章节")


def _guard_range(src: str, header_re: str):
    """返回某 if 块（含 header 行）的 1-based 闭区间行号；未命中返回 (0, -1)。"""
    lines = src.splitlines()
    for i, l in enumerate(lines):
        if re.match(header_re, l):
            base = len(l) - len(l.lstrip())
            j = i + 1
            while j < len(lines) and (not lines[j].strip()
                                      or len(lines[j]) - len(lines[j].lstrip()) > base):
                j += 1
            return i + 1, j
    return 0, -1


_tip_m = re.search(r"^func _obtain_tip\(", fwui_src, re.M)
_tip_lo = (fwui_src.count("\n", 0, _tip_m.start()) + 1) if _tip_m else 0
_tip_hi = (_tip_lo + func_body(fwui_src, "_obtain_tip").count("\n")) if _tip_m else -1
_grd_lo, _grd_hi = _guard_range(fwui_src, r'\s*if reachable < prog\["total"\]:\s*$')

stale_live, stale_guarded = [], []
for _n_, _l_ in enumerate(fwui_src.splitlines(), 1):
    if _l_.lstrip().startswith("#") or not any(s in _l_ for s in STALE_PAT):
        continue
    tag = f"L{_n_}: {_l_.strip()}"
    (stale_guarded if _grd_lo <= _n_ <= _grd_hi else stale_live).append(tag)

if stale_live:
    in_tip = [x for x in stale_live if _tip_lo <= int(x[1:x.index(":")]) <= _tip_hi]
    concern(f"【图鉴文案已过期 · 高】DS-RN-04b 已把手作渠道接通（reachable 18→24），"
            f"但 FengwuBookUI.gd 仍有 {len(stale_live)} 处**无条件渲染**的过期文案："
            f"{stale_live}。"
            + (f"其中 {len(in_tip)} 处位于 _obtain_tip()（L{_tip_lo}–{_tip_hi}）—— "
               f"未获得的手作格 tooltip 每次点开都会显示「尚未开放 / 后续章节」，"
               f"玩家读到会直接放弃尝试，等于把已可达的 6 件在认知上锁死，称号形同不可达。"
               if in_tip else
               "这些位置不在 reachable 守卫块内，玩家可见 —— 请确认措辞是否仍成立。")
            + "修复口径：换成 CollectionManager 侧同源的可达成话术"
              "（「在家备一份手作礼物，加一点材料费，就能做出来。」+ 该槽 hint）。")
if stale_guarded:
    note(f"FengwuBookUI.gd 的「本章可达」提示（L{_grd_lo}–{_grd_hi}）仍含「后续章节」措辞："
         f"{stale_guarded}。该块整体包在 `if reachable < prog[\"total\"]:` 内，"
         f"DS-RN-04b 后 reachable==total==24 → Label 不生成，玩家永不可见，故**不计 concern**、"
         f"也不建议删除：它是将来真新增不可达风物（reachable<total）时的正确兜底。"
         f"若后续把手作以外的槽设为不可达，需回头复核这句措辞是否仍准确。")
if "谢谢你的礼物！我很喜欢。" in src_of(SCRIPTS / "DataManager.gd"):
    note("【送礼池污染 · 已根治】DataManager 仍保留兜底送礼台词「谢谢你的礼物！我很喜欢。」"
         "（其它无 GIFT_PREFERENCES 条目的道具仍走 +3 好感兜底，属既有设计）。"
         "6 件购得风物已在 DialogueUI._on_gift_pressed 填装循环内经 "
         "category==\"fengwu\" → continue 剔除（见 N 区断言），不再进礼物列表、"
         "不再吃兜底好感；风物志进度本就与送礼无关（购买时已永久落账）。")

note(f"门控实测作用域 CollectionManager.gd L{AREA_L0}–L{AREA_L1}，"
     f"以「记忆回响」哨兵注释收窄，未触碰十景集章区（L98–L343）与记忆回响区（L{AREA_L1}+）。")
note(f"【DS-RN-04b 后】称号「西湖风物通」静态**已可达**：24/24 全部有授予通道"
     f"（拾得 12 = pick_fengwu_pickup，购得 6 = ITEM_DB 钩子，手作 6 = fw_craft_* 事件 grantFengwu），"
     f"get_fengwu_reachable_total() 直接回 FENGWU_TOTAL。已用 mock 复演 18 件仍锁 / 补齐 24 件点亮。"
     f"手作总成本：6 个 handmade_gift（int_craft_make 可重复产出）+ {CRAFT_COST_TOTAL_EXPECTED} 元材料费。")
note("大成 CG 已换用专属图 west_lake_fengwu_complete.jpg（art-director 生成），"
     "不再与「毕业纪念册」共用 lakeside_evening.jpg —— 两条画廊项同周目点亮时不再重复同图。"
     "注意：新 jpg 尚无同名 .import 文件，需在 Godot 编辑器内打开一次完成导入，否则导出包不含该资源。")
note(f"ITEM_DB 由 7 条增至 {len(ITEM_DB)} 条，ShopUI 无条件全量上架（无地点/章节过滤）——"
     "与既有 movie_ticket / amusement_ticket 处理方式一致，非本 sprint 引入的回归；"
     "建议实机确认商店列表在 1280×720 下滚动正常。")

# ── 判定 ───────────────────────────────────────────────────────
print("\n" + "=" * 78)
print(f"assertions={_n}  passed={_n - len(failures)}  failed={len(failures)}  "
      f"concerns={len(concerns)}  notes={len(notes)}")
if failures:
    print("VERDICT: FAIL")
    for f_ in failures:
        print(f"  x {f_}")
    sys.exit(1)
elif concerns:
    print("VERDICT: PASS (with concerns)")
    for c_ in concerns:
        print(f"  ! {c_}")
    sys.exit(0)
else:
    print("VERDICT: PASS")
    sys.exit(0)
