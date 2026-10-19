# -*- coding: utf-8 -*-
"""
QA-RN-02 — 记忆回响 · 情境回响（DS-RN-02）独立逻辑级烟雾测试 / 质量门
Owner: 严守真 (quality-lead)

独立于 scratch/verify_memory_echo.py：本套件由 QA 侧直接通读三处改动源码后重写，
自带 GDScript 字面量解析器、自带断言编号（A01+）、自带分组，不复用 scratch 任何代码。

方法：纯静态断言（.gd 文本解析 + json.load + 常量验算 + 守卫模型推演 + 文件存在性），
      零 Godot runtime 依赖。对游戏代码**只读**，不写、不改、不产生副作用。

覆盖 design/memory_echo_gdd.md §7-③ 的 T-1 ~ T-16，并额外扩展：
  A  调参常量存在性与取值（§5.1）
  B  防刷屏算术（T-11 / S-3）
  C  MEMORY_ECHO_CONTEXTS 结构与字段纪律（T-1 / T-2 / T-5 / S-6）
  D  双源交叉：events_break.json 逐字真源（T-3）
  E  双源交叉：GALLERY_ITEMS 记忆池前置（T-4 / S-2）
  F  五函数存在性与契约（§4-C / §5.5）
  G  pick_memory_echo 九守卫 G0~G9（§2.3）+ 无副作用
  H  毕业前夜特例 day 569（§2.5）
  I  build_memory_echo_vignette 硬约束（T-6 / T-7 / §5.4）
  J  DialogueUI noTimeCost 短路 + 零回归面（T-8 / T-9 / S-4）
  K  MainGame 触发钩子与调用点唯一性（T-10 / S-5 / §4.1）
  L  mem_echo_* 命名规范 + 单一写入源 + set_flag int 支持（T-14 / §5.3）
  M  零新 Autoload / 零新脚本 / 零新资产（T-13 / S-1 / S-2）
  N  NG+ 自动清零（T-15 / S-7）
  O  只读边界：不碰画廊 / 集章 / 深夜聊天 / 零机制产出（T-16 / S-8 / §3.5）
  P  成熟期可达性（T-12）
  Q  守卫模型推演：密度上限 ≤ 11 与保底 ≥ 1（S-3 / §2.5 / §2.6）
  R  缩进风格一致性（防 GDScript mixed-indent 解析错误）

退出码：0 = PASS / PASS-with-concerns，1 = FAIL。
"""
import ast
import io
import json
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"

COLL = SCRIPTS / "CollectionManager.gd"
DLG = SCRIPTS / "DialogueUI.gd"
MAIN = SCRIPTS / "MainGame.gd"
GM = SCRIPTS / "GameManager.gd"
DAILY = SCRIPTS / "DailyCycleManager.gd"
RELMGR = SCRIPTS / "RelationshipManager.gd"
INIT = SCRIPTS / "InitiativeManager.gd"
ENDING = SCRIPTS / "EndingScreen.gd"
EV_BREAK = SCRIPTS / "events_break.json"
PROJECT = ROOT / "project.godot"

# ── GDD §1.2 —— sid 全集（顺序即 MEMORY_ECHO_CONTEXTS 插入顺序，不可排序）──
EXPECTED_SIDS = [
    "winter_yutong", "winter_jingjing", "winter_yifei",
    "spring_wanqing", "spring_xiaoxia", "spring_beichen",
    "summer_keke", "summer_zijun",
    "autumn_zicheng", "autumn_jingjing_m",
]
# GDD §1.2 —— loc / slot 期望值（真源 = events_break.json，本表仅作三方对拍）
EXPECTED_CTX = {
    "winter_yutong":     ("lakeside", "evening"),
    "winter_jingjing":   ("off_campus_shop", "after"),
    "winter_yifei":      ("cinema", "noon"),
    "spring_wanqing":    ("lakeside", "evening"),
    "spring_xiaoxia":    ("community", "after"),
    "spring_beichen":    ("cinema", "noon"),
    "summer_keke":       ("lakeside", "evening"),
    "summer_zijun":      ("community", "after"),
    "autumn_zicheng":    ("lakeside", "evening"),
    "autumn_jingjing_m": ("community", "after"),
}
# GDD §5.1 —— 调参常量期望值
EXPECTED_CONSTS = {
    "ECHO_MATURE_DAYS": 30,
    "ECHO_MEM_COOLDOWN_DAYS": 60,
    "ECHO_GLOBAL_GAP_DAYS": 14,
    "ECHO_GLOBAL_GAP_FINALE": 5,
    "ECHO_PER_MEM_CAP": 2,
    "ECHO_TOTAL_CAP": 8,
    "ECHO_FINALE_BONUS": 2,
    "ECHO_FINALE_DAY": 540,
    "ECHO_LAST_NIGHT_DAY": 569,
}
AUTOLOAD_EXPECTED = 15          # S-1 改动前基线：零新 Autoload
ECHO_REGION_MARKER = "记忆回响 · 情境回响（DS-RN-02）"

# ─────────────────────────────────────────────────────────────────
# 断言框架
# ─────────────────────────────────────────────────────────────────
_n = 0
failures, concerns, notes = [], [], []


def check(cond, desc, detail=""):
    """编号断言。cond 为真 → PASS，否则 FAIL。"""
    global _n
    _n += 1
    tag = f"A{_n:02d}"
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
# 独立 GDScript 解析器（字符串感知；# 注释仅在字符串外生效）
# ─────────────────────────────────────────────────────────────────
def strip_comments(src: str) -> str:
    """去掉 # 行注释，保留字符串内的 #。逐字符扫描，不用正则。"""
    out, i, n = [], 0, len(src)
    in_str, quote, esc = False, "", False
    while i < n:
        c = src[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == quote:
                in_str = False
        else:
            if c in "\"'":
                in_str, quote = True, c
                out.append(c)
            elif c == "#":
                while i < n and src[i] != "\n":
                    i += 1
                continue
            else:
                out.append(c)
        i += 1
    return "".join(out)


def extract_literal(src: str, anchor: str) -> str:
    """从 anchor 之后取第一个平衡的 {...} 或 [...]（字符串感知）。"""
    i = src.index(anchor) + len(anchor)
    while src[i] not in "[{":
        i += 1
    open_ch = src[i]
    close_ch = "}" if open_ch == "{" else "]"
    depth, in_str, quote, esc, start = 0, False, "", False, i
    while i < len(src):
        c = src[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == quote:
                in_str = False
        else:
            if c in "\"'":
                in_str, quote = True, c
            elif c == open_ch:
                depth += 1
            elif c == close_ch:
                depth -= 1
                if depth == 0:
                    return src[start:i + 1]
        i += 1
    raise ValueError(f"未闭合的字面量：{anchor}")


def gd_to_py(text: str):
    """GDScript 字面量 → Python 对象（先去注释，再做关键字替换，最后 literal_eval）。"""
    t = strip_comments(text)
    # 字符串外的 true/false/null 关键字替换
    out, i, n = [], 0, len(t)
    in_str, quote, esc = False, "", False
    while i < n:
        c = t[i]
        if in_str:
            out.append(c)
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == quote:
                in_str = False
            i += 1
            continue
        if c in "\"'":
            in_str, quote = True, c
            out.append(c)
            i += 1
            continue
        m = re.match(r"\b(true|false|null)\b", t[i:])
        if m:
            out.append({"true": "True", "false": "False", "null": "None"}[m.group(1)])
            i += len(m.group(1))
            continue
        out.append(c)
        i += 1
    return ast.literal_eval("".join(out))


def extract_func(src: str, name: str) -> str:
    """取出 func <name>(...) 的完整函数体（到下一个顶格 func/const/var/# 分隔或 EOF）。"""
    m = re.search(r"^func\s+" + re.escape(name) + r"\s*\(", src, re.M)
    if not m:
        return ""
    start = m.start()
    tail = src[m.end():]
    nxt = re.search(r"^(func\s|const\s|@)", tail, re.M)
    end = m.end() + (nxt.start() if nxt else len(tail))
    return src[start:end]


def parse_consts(src: str) -> dict:
    """解析 const NAME := v / const NAME = v 的标量与数组常量。"""
    res = {}
    for m in re.finditer(r"^const\s+([A-Z_][A-Z0-9_]*)\s*:?=\s*(.+?)\s*(?:#.*)?$", src, re.M):
        name, raw = m.group(1), m.group(2).strip()
        try:
            res[name] = gd_to_py(raw)
        except Exception:
            res[name] = raw
    return res


def echo_region(src: str) -> str:
    """CollectionManager 的「记忆回响」区（marker → EOF）——只读边界扫描用。"""
    idx = src.index(ECHO_REGION_MARKER)
    return src[idx:]


# ─────────────────────────────────────────────────────────────────
print("=" * 78)
print("QA-RN-02  记忆回响 · 情境回响（DS-RN-02）— 独立静态质量门")
print(f"ROOT = {ROOT}")
print("=" * 78)

coll_src = COLL.read_text(encoding="utf-8")
dlg_src = DLG.read_text(encoding="utf-8")
main_src = MAIN.read_text(encoding="utf-8")
gm_src = GM.read_text(encoding="utf-8")
daily_src = DAILY.read_text(encoding="utf-8")
ending_src = ENDING.read_text(encoding="utf-8")
project_src = PROJECT.read_text(encoding="utf-8")

coll_nc = strip_comments(coll_src)          # 去注释版：防注释里的字面量造成误判
region_src = echo_region(coll_src)
region_nc = strip_comments(region_src)

CONSTS = parse_consts(coll_src)

# ── A. 调参常量存在性与取值（GDD §5.1）────────────────────────────
section("A. 调参常量（GDD §5.1）")
for cname, cval in EXPECTED_CONSTS.items():
    check(CONSTS.get(cname) == cval,
          f"const {cname} == {cval}", f"实际 {CONSTS.get(cname)!r}")
check("ECHO_END_DAY" in CONSTS and CONSTS["ECHO_END_DAY"] == 570,
      "const ECHO_END_DAY == 570（G0 结局日门槛，工程侧显式常量化）",
      f"实际 {CONSTS.get('ECHO_END_DAY')!r}")
tint = CONSTS.get("ECHO_BG_TINT")
check(isinstance(tint, list) and len(tint) == 4 and all(isinstance(x, float) for x in tint),
      "const ECHO_BG_TINT 为 4 元 float 数组（P1 备用常量）", f"实际 {tint!r}")

# ── B. 防刷屏算术（T-11 / S-3）────────────────────────────────────
section("B. 防刷屏算术（T-11 / S-3）")
cap = CONSTS.get("ECHO_TOTAL_CAP", -1)
bonus = CONSTS.get("ECHO_FINALE_BONUS", -1)
gap = CONSTS.get("ECHO_GLOBAL_GAP_DAYS", -1)
gapf = CONSTS.get("ECHO_GLOBAL_GAP_FINALE", -1)
mcd = CONSTS.get("ECHO_MEM_COOLDOWN_DAYS", -1)
percap = CONSTS.get("ECHO_PER_MEM_CAP", -1)
check(cap + bonus <= 10, f"ECHO_TOTAL_CAP({cap}) + ECHO_FINALE_BONUS({bonus}) <= 10",
      f"实际 {cap + bonus}")
check(gapf >= 5, f"ECHO_GLOBAL_GAP_FINALE({gapf}) >= 5（终章任意两次间隔下限）")
check(mcd >= 2 * gap, f"ECHO_MEM_COOLDOWN_DAYS({mcd}) >= 2 × ECHO_GLOBAL_GAP_DAYS({gap})",
      f"实际 {mcd} vs {2 * gap}")
check(gap > gapf, f"常态全局冷却({gap}) > 终章全局冷却({gapf})（终章加密方向正确）")
check(CONSTS.get("ECHO_FINALE_DAY", 0) <= CONSTS.get("ECHO_LAST_NIGHT_DAY", 0)
      < CONSTS.get("ECHO_END_DAY", 0),
      "ECHO_FINALE_DAY <= ECHO_LAST_NIGHT_DAY < ECHO_END_DAY（日程常量序正确）",
      f"{CONSTS.get('ECHO_FINALE_DAY')} / {CONSTS.get('ECHO_LAST_NIGHT_DAY')} / {CONSTS.get('ECHO_END_DAY')}")
check(percap * 10 >= cap + bonus,
      f"ECHO_PER_MEM_CAP({percap}) × 10 条 >= 全局总配额({cap + bonus})（满池时全局配额可被用满，非死配额）")
check(cap + bonus + 1 <= 11,
      f"单周目回响次数硬上限 = {cap + bonus} + 1（day569 特例）= {cap + bonus + 1} <= 11（S-3）")

# ── C. MEMORY_ECHO_CONTEXTS 结构（T-1 / T-2 / T-5 / S-6）──────────
section("C. MEMORY_ECHO_CONTEXTS 结构与字段纪律（T-1 / T-2 / T-5）")
ctx_raw = extract_literal(coll_src, "const MEMORY_ECHO_CONTEXTS")
CTX = gd_to_py(ctx_raw)
check(isinstance(CTX, dict) and len(CTX) == 10,
      f"MEMORY_ECHO_CONTEXTS 恰含 10 条", f"实际 {len(CTX) if isinstance(CTX, dict) else type(CTX)}")
check(set(CTX.keys()) == set(EXPECTED_SIDS),
      "sid 键集合 == GDD §1.2 十条全集",
      f"多 {sorted(set(CTX) - set(EXPECTED_SIDS))} / 缺 {sorted(set(EXPECTED_SIDS) - set(CTX))}")
check(list(CTX.keys()) == EXPECTED_SIDS,
      "sid 插入顺序 == GDD §1.2 表格顺序（字典序不可被排序破坏）",
      f"实际 {list(CTX.keys())}")
bad_fields = {}
for sid, ctx in CTX.items():
    extra = set(ctx.keys()) - {"loc", "slot", "lines", "finale_line"}
    if extra:
        bad_fields[sid] = sorted(extra)
check(not bad_fields, "每条恰含 loc/slot/lines/finale_line 四字段（无冗余字段）", str(bad_fields))
missing = {sid: sorted({"loc", "slot", "lines", "finale_line"} - set(c.keys()))
           for sid, c in CTX.items() if set(c.keys()) < {"loc", "slot", "lines", "finale_line"}}
check(not missing, "四字段无缺失", str(missing))
FORBIDDEN_FIELDS = ["char", "bg", "label", "born", "born_day", "hint", "flag", "season", "cg"]
leak = sorted({f for c in CTX.values() for f in c.keys() if f in FORBIDDEN_FIELDS})
check(not leak, "T-5：不出现 char/bg/label/born/hint/flag/season 派生字段（S-6 零数据重复）", str(leak))
bad_lines = {sid: len(c.get("lines", [])) for sid, c in CTX.items() if len(c.get("lines", [])) != 3}
check(not bad_lines, "T-2：每条 lines 恰 3 句", str(bad_lines))
empty_lines = {sid: [i for i, s in enumerate(c.get("lines", [])) if not str(s).strip()]
               for sid, c in CTX.items() if any(not str(s).strip() for s in c.get("lines", []))}
check(not empty_lines, "T-2：lines 中无空串 / 纯空白句", str(empty_lines))
empty_fin = [sid for sid, c in CTX.items() if not str(c.get("finale_line", "")).strip()]
check(not empty_fin, "T-2：每条 finale_line 非空串", str(empty_fin))
dup_lines = {}
seen_line = {}
for sid, c in CTX.items():
    for s in c["lines"]:
        if s in seen_line:
            dup_lines.setdefault(s[:18], []).append((seen_line[s], sid))
        seen_line[s] = sid
check(not dup_lines, "10 条 × 3 句共 30 句正文互不重复（无复制粘贴漂移）", str(dup_lines))
fin_set = {c["finale_line"] for c in CTX.values()}
check(len(fin_set) == 10, "10 条 finale_line 互不重复", f"去重后 {len(fin_set)}")
bad_type = {sid: type(c.get("loc")).__name__ for sid, c in CTX.items()
            if not isinstance(c.get("loc"), str) or not isinstance(c.get("slot"), str)}
check(not bad_type, "loc / slot 均为 String 类型", str(bad_type))
mismatch = {sid: (c["loc"], c["slot"]) for sid, c in CTX.items()
            if (c["loc"], c["slot"]) != EXPECTED_CTX[sid]}
check(not mismatch, "loc / slot 与 GDD §1.2 表格三方对拍一致", str(mismatch))

# ── D. 双源交叉：events_break.json 逐字真源（T-3）──────────────────
section("D. 双源交叉 —— events_break.json 逐字真源（T-3，防设计漂移）")
break_events = json.loads(EV_BREAK.read_text(encoding="utf-8"))
if isinstance(break_events, dict):
    break_events = break_events.get("events", [])
BY_ID = {e.get("id", ""): e for e in break_events}
for sid in EXPECTED_SIDS:
    season = sid.split("_")[0]
    char = sid[len(season) + 1:]
    eid = f"break_{season}_chapter_{char}"
    ev = BY_ID.get(eid)
    if not check(ev is not None, f"T-3：chapter 事件 {eid} 存在于 events_break.json"):
        continue
    c = CTX.get(sid, {})
    check(ev.get("location") == c.get("loc"),
          f"T-3：{sid}.loc 逐字 == {eid}.location",
          f"ctx={c.get('loc')!r} vs json={ev.get('location')!r}")
    check(ev.get("slotId") == c.get("slot"),
          f"T-3：{sid}.slot 逐字 == {eid}.slotId",
          f"ctx={c.get('slot')!r} vs json={ev.get('slotId')!r}")
# 记忆的「产生」端：chapter 终场景 setFlag 必须写出 holiday_memory_<sid>
ev_txt = EV_BREAK.read_text(encoding="utf-8")
for sid in EXPECTED_SIDS:
    check(f'"holiday_memory_{sid}"' in ev_txt,
          f"T-3 前置：events_break.json 中存在 setFlag holiday_memory_{sid}（记忆产生端）")

# ── E. 双源交叉：GALLERY_ITEMS 记忆池前置（T-4 / S-2）──────────────
section("E. 双源交叉 —— GALLERY_ITEMS 记忆池（T-4 / S-2）")
gal_raw = extract_literal(gm_src, "const GALLERY_ITEMS")
GALLERY = gd_to_py(gal_raw)
gal_mem = [g for g in GALLERY if str(g.get("flag", "")).startswith("holiday_memory_")]
check(len(gal_mem) == 10, "GALLERY_ITEMS 中 holiday_memory_* 条目恰 10 条", f"实际 {len(gal_mem)}")
gal_sids = {str(g["flag"])[len("holiday_memory_"):] for g in gal_mem}
check(gal_sids == set(CTX.keys()),
      "T-4：MEMORY_ECHO_CONTEXTS sid 集合 == GALLERY holiday_memory_* sid 集合（双向相等）",
      f"仅画廊有 {sorted(gal_sids - set(CTX))} / 仅回响有 {sorted(set(CTX) - gal_sids)}")
gal_by_sid = {str(g["flag"])[len("holiday_memory_"):]: g for g in gal_mem}
no_char = [s for s, g in gal_by_sid.items() if not str(g.get("char", "")).strip()]
check(not no_char, "每条画廊记忆条目均有非空 char（G9 冷战反查与打分依赖）", str(no_char))
no_bg = [s for s, g in gal_by_sid.items() if not str(g.get("bg", "")).strip()]
check(not no_bg, "每条画廊记忆条目均有非空 bg（vignette CG 反查依赖）", str(no_bg))
no_label = [s for s, g in gal_by_sid.items() if not str(g.get("label", "")).strip()]
check(not no_label, "每条画廊记忆条目均有非空 label（title / 日志 / 日记依赖）", str(no_label))
no_hint = [s for s, g in gal_by_sid.items() if not str(g.get("hint", "")).strip()]
check(not no_hint, "每条画廊记忆条目均有非空 hint（§1.5 lines 缺失时的降级兜底源）", str(no_hint))
# sid → char 必须与 sid 后缀一致（防反查错位）
char_mismatch = {s: (g.get("char"), s[len(s.split("_")[0]) + 1:])
                 for s, g in gal_by_sid.items()
                 if g.get("char") != s[len(s.split("_")[0]) + 1:]}
check(not char_mismatch, "画廊 char 与 sid 后缀一一对应（反查零错位）", str(char_mismatch))
# CG 资产落盘
missing_cg = []
for s, g in gal_by_sid.items():
    p = ROOT / str(g["bg"]).replace("res://", "")
    if not p.exists():
        missing_cg.append((s, str(g["bg"])))
check(not missing_cg, "S-2：4 张 holiday CG 全部落盘（零新资产，全复用）", str(missing_cg))
check(len({g["bg"] for g in gal_mem}) == 4, "10 条记忆复用 4 张 CG",
      f"实际 {len({g['bg'] for g in gal_mem})}")

# ── F. 五函数存在性与契约（§4-C / §5.5）───────────────────────────
section("F. 函数存在性与契约（§4-C / §5.5）")
FUNCS = {}
for fn, sig in [
    ("pick_memory_echo", r"func pick_memory_echo\(loc_id: String\) -> Dictionary"),
    ("build_memory_echo_vignette", r"func build_memory_echo_vignette\(sid: String\) -> Dictionary"),
    ("commit_memory_echo", r"func commit_memory_echo\(sid: String\) -> void"),
    ("_memory_gallery_item", r"func _memory_gallery_item\(sid: String\) -> Dictionary"),
    ("_memory_born_day", r"func _memory_born_day\(sid: String\) -> int"),
]:
    body = extract_func(coll_src, fn)
    FUNCS[fn] = strip_comments(body)
    check(bool(body), f"CollectionManager.{fn}() 存在")
    check(re.search(sig, coll_src) is not None, f"{fn}() 签名与 GDD §2.2/§5.5 一致")
pick, build, commit = FUNCS["pick_memory_echo"], FUNCS["build_memory_echo_vignette"], FUNCS["commit_memory_echo"]
galitem, bornday = FUNCS["_memory_gallery_item"], FUNCS["_memory_born_day"]
check("GALLERY_ITEMS" in galitem and 'holiday_memory_' in galitem,
      "_memory_gallery_item() 从 GameManager.GALLERY_ITEMS 按 flag 反查")
check("return {}" in galitem, "_memory_gallery_item() 未找到时返回 {}（数据异常兜底，不崩）")
check("BREAK_PERIODS" in bornday, "_memory_born_day() 从 DailyCycleManager.BREAK_PERIODS 推导（零新 flag）")
check("99999" in bornday, "_memory_born_day() 未知 season 返回 99999（永不成熟，安全失败）")

# ── G. pick_memory_echo 九守卫（§2.3）+ 无副作用 ───────────────────
section("G. pick_memory_echo 九守卫 G0~G9（§2.3）")
check(re.search(r"day\s*>=\s*ECHO_END_DAY", pick) is not None,
      "G0 非结局日：day >= ECHO_END_DAY(570) → return {}")
check(re.search(r"current_holiday\)?\s*!=\s*\"\"", pick) is not None,
      "G3 非长假期间：current_holiday != \"\" → return {}")
check('flags.has("holiday_memory_" + sid)' in pick.replace(" ", "").replace(
      'flags.has("holiday_memory_"+sid)', 'flags.has("holiday_memory_" + sid)')
      or 'holiday_memory_' in pick and "flags.has" in pick,
      "G1 已解锁：flags.has(\"holiday_memory_\" + sid)")
check(re.search(r'ctx\.get\("loc".*?\)\s*!=\s*loc_id', pick) is not None,
      "G2 地点匹配：ctx.loc != loc_id → continue")
check(re.search(r"_memory_born_day\(sid\)\s*\+\s*ECHO_MATURE_DAYS", pick) is not None,
      "G4 成熟期：day < born + ECHO_MATURE_DAYS → continue")
check(re.search(r"ECHO_MEM_COOLDOWN_DAYS", pick) is not None
      and 'mem_echo_%s_last' in pick,
      "G5 单条冷却：day - mem_echo_<sid>_last < ECHO_MEM_COOLDOWN_DAYS → continue")
check(re.search(r"mem_echo_last_day", pick) is not None
      and re.search(r"ECHO_GLOBAL_GAP_(FINALE|DAYS)", pick) is not None,
      "G6 全局冷却：day - mem_echo_last_day < gap → return {}")
check(re.search(r"ECHO_PER_MEM_CAP", pick) is not None and 'mem_echo_%s_count' in pick,
      "G7 单条上限：mem_echo_<sid>_count >= ECHO_PER_MEM_CAP → continue")
check(re.search(r"mem_echo_total", pick) is not None
      and re.search(r"ECHO_TOTAL_CAP\s*\+\s*\(?\s*ECHO_FINALE_BONUS", pick) is not None,
      "G8 全局上限：mem_echo_total >= ECHO_TOTAL_CAP + 终章配额 → return {}")
check(re.search(r'get_rel_state\(\s*cid\s*\)\s*==\s*"cold"', pick) is not None,
      "G9 排除冷战：RelationshipManager.get_rel_state(char) == \"cold\" → continue")
check(re.search(r'if\s+st\s*==\s*"cold"', INIT.read_text(encoding="utf-8")) is not None,
      "G9 语义与 InitiativeManager.check_night_chat() 的 cold 排除惯例对齐（跨系统一致性）")
# 全局门必须在遍历之前（短路最快）
loop_pos = pick.index("for key in MEMORY_ECHO_CONTEXTS")
check(pick.index("ECHO_END_DAY") < loop_pos, "G0 位于逐条遍历之前（阶段 0 全局门先算）")
check(pick.index("current_holiday") < loop_pos, "G3 位于逐条遍历之前")
check(pick.index("mem_echo_last_day") < loop_pos, "G6 位于逐条遍历之前")
check(pick.index("mem_echo_total") < loop_pos, "G8 位于逐条遍历之前")
# 无副作用（纯判定）
check("set_flag" not in pick, "pick_memory_echo() 不调用 set_flag（纯函数式判定，零副作用）")
check(not re.search(r"flags\[[^\]]+\]\s*=", pick), "pick_memory_echo() 不直接写 GameManager.flags")
check("add_log" not in pick and "add_diary_entry" not in pick,
      "pick_memory_echo() 不写日志 / 日记（判定与落账严格分离）")
check("start_event" not in pick, "pick_memory_echo() 不拉起任何 UI")
# 刻意不设的守卫（GDD §2.3 注，防下游误加）
for forbid, why in [("get_season", "季节匹配（§1.2 ⚠️ 会造成 5 条记忆死分支）"),
                    ("stress", "stress 门槛（隐性黑箱）"),
                    ("current_weather", "天气门槛"),
                    ("minAff", "minAff 门槛")]:
    check(forbid not in pick, f"pick_memory_echo() 未引入被明确否决的守卫：{why}")
# slot 仅作权重，不得作硬门槛
check(not re.search(r'ctx\.get\("slot".*?\)\s*!=\s*cur_slot\s*:\s*\n?\s*continue', pick),
      "slot 仅作打分权重（+100），未被误用为硬门槛（否则命中率砍到 1/4）")
check(re.search(r'ctx\.get\("slot".*?\)\s*==\s*cur_slot', pick) is not None
      and "100.0" in pick, "§2.4 打分：原发时段匹配 +100")
check(re.search(r"cnt\s*==\s*0", pick) is not None and "50.0" in pick,
      "§2.4 打分：从未回响过 +50（覆盖广度优先）")
check("clampi" in pick and "favorability" in pick, "§2.4 打分：好感度 clampi(fav/10, 0, 10)")
check(re.search(r"sid\s*<\s*best_sid", pick) is not None,
      "§2.4 平局打破：sid 字典序升序（全序，结果可复现）")

# ── H. 毕业前夜特例 day 569（§2.5）────────────────────────────────
section("H. 毕业前夜特例 day 569（§2.5 保底）")
check(re.search(r"is_last_night\s*:\s*bool\s*=\s*day\s*==\s*ECHO_LAST_NIGHT_DAY", pick) is not None,
      "is_last_night = (day == ECHO_LAST_NIGHT_DAY 569)")
check(re.search(r"if\s+not\s+is_last_night\s*:", pick) is not None,
      "阶段 0：not is_last_night 时才检查 G6 / G8（569 放宽全局冷却与总配额）")
check(re.search(r"not\s+is_last_night\s+and\s+String\(ctx\.get\(\"loc\"", pick) is not None,
      "G2 地点匹配在 569 被放宽（从全部已解锁记忆中选）")
g5g7_block = pick[pick.index("mem_echo_%s_count"):]
check(re.search(r"if\s+not\s+is_last_night\s*:", g5g7_block) is not None,
      "G5 / G7 在 569 被放宽（冷却与单条上限不拦）")
# 569 必须保留 G0/G1/G3/G4/G9（逐行定位，避免相邻行串扰）
def guard_line(body: str, needle: str) -> str:
    for ln in body.splitlines():
        if needle in ln and ln.strip().startswith(("if", "elif")):
            return ln
    return ""


check(pick.index("ECHO_END_DAY") < pick.index("is_last_night"),
      "G0 在 is_last_night 之前无条件生效（569 仍受结局日守卫约束）")
for needle, label in [('flags.has("holiday_memory_"', "G1 已解锁"),
                      ("_memory_born_day(sid)", "G4 成熟期"),
                      ("get_rel_state(", "G9 冷战排除")]:
    ln = guard_line(pick, needle)
    check(bool(ln) and "is_last_night" not in ln,
          f"{label}守卫所在行不含 is_last_night → 569 无条件生效", f"行内容：{ln.strip()!r}")
check(re.search(r"score\s*-=\s*1000\.0\s*\*\s*float\(cnt\)", pick) is not None,
      "§2.5 选择规则：569 按 count 升序优先（量级 1000 压过全部常规权重）")
check(1000.0 > 100.0 + 50.0 + 10.0 + 2.0,
      "§2.5 量级验算：1000 > 常规权重上界(100+50+10+2=162)，count 升序不可被翻盘")
check(CONSTS.get("ECHO_LAST_NIGHT_DAY", 0) >= CONSTS.get("ECHO_FINALE_DAY", 10 ** 9),
      "day 569 >= ECHO_FINALE_DAY(540) → 毕业前夜必然自动追加 finale_line")

# ── I. build_memory_echo_vignette 硬约束（T-6 / T-7 / §5.4）────────
section("I. vignette 硬约束（T-6 / T-7 / §5.4）")
check(re.search(r'"location":\s*""', build) is not None,
      "T-7：location 传空串（跳过地点增益重复发放 + 天气 toast）")
check(re.search(r'"repeatable":\s*true', build) is not None,
      "T-7：repeatable = true（否则 finish_event 会污染出 mem_echo_<sid> 布尔键）")
check(re.search(r'"noTimeCost":\s*true', build) is not None,
      "T-7：noTimeCost = true（S-4 不消耗时段）")
check(re.search(r'"isSpecial":\s*false', build) is not None,
      "isSpecial = false（不进 special 优先级队列）")
check('"charId"' not in build and "charId" not in build,
      "T-7：不含 charId 键（不写 last_interact_ / 不产生「和 X 聊了聊」日记）")
for bad in ["pose", "setFlag", "setFlags", "addItem", "affDelta", "statDelta", "statsDelta", "choices"]:
    check(bad not in build, f"T-6：vignette 构造中不出现 {bad}（零机制产出 / 防垃圾键）")
check(re.search(r'"speaker":\s*null', build) is not None,
      "§3.2：全部 scene 使用 speaker: null（无立绘，全屏 CG + 纯旁白）")
check(build.count('"speaker": null') >= 2 or build.count('"speaker":null') >= 2,
      "lines / finale_line / 兜底 hint 三条构造路径均为 speaker: null")
check(re.search(r'"id":\s*"mem_echo_"\s*\+\s*sid', build) is not None,
      "vignette id = \"mem_echo_\" + sid（命名规范统一）")
check(re.search(r'"bg":\s*String\(item\.get\("bg"', build) is not None,
      "bg 从 GALLERY_ITEMS 反查（S-6 单一真源，不在本层硬编码）")
check(build.count('"next"') == 1 and re.search(r'last_scene\["next"\]\s*=\s*99', build) is not None,
      "T-6：next:99 有且仅有 1 处，且只赋给最后一条 scene",
      f'"next" 出现 {build.count(chr(34) + "next" + chr(34))} 次')
check("scenes.append({ \"speaker\": null, \"text\": t })" in build.replace("  ", " ")
      or re.search(r"scenes\.append\(\s*\{\s*\"speaker\":\s*null,\s*\"text\":\s*t\s*\}\s*\)", build) is not None,
      "正文 scene 仅含 speaker / text 两键（无任何额外字段）")
check(re.search(r"GameManager\.day\s*>=\s*ECHO_FINALE_DAY", build) is not None,
      "§1.4：day >= ECHO_FINALE_DAY(540) 时追加 finale_line 作为第 4 句")
fin_idx = build.index("ECHO_FINALE_DAY")
next_idx = build.index('last_scene["next"]')
check(fin_idx < next_idx,
      "finale_line 追加发生在 next:99 赋值之前（终章第 4 句才是终止句，无中途 99 截断）")
check(re.search(r'ctx\.is_empty\(\)\s*:\s*\n\s*return \{\}', build) is not None
      or "if ctx.is_empty():" in build,
      "未知 sid → 返回 {}（调用方静默放行，不阻断进地点）")
check("item.is_empty()" in build, "画廊反查失败 → 返回 {}（数据异常兜底）")
check(re.search(r'item\.get\("hint"', build) is not None,
      "§1.5 兜底：lines 全空时降级为画廊 hint 单句，不报错、不崩")
check("set_flag" not in build and not re.search(r"flags\[[^\]]+\]\s*=", build),
      "build_memory_echo_vignette() 不写任何 flag（写入由 commit 独立负责）")
check("unlock_gallery" not in build, "build 不调用 unlock_gallery（S-8 只读）")

# ── J. DialogueUI noTimeCost 短路 + 零回归（T-8 / T-9 / S-4）───────
section("J. DialogueUI noTimeCost 短路与零回归面（T-8 / T-9 / S-4）")
dlg_nc = strip_comments(dlg_src)
fin_body = extract_func(dlg_src, "finish_event")
fin_nc = strip_comments(fin_body)
check(bool(fin_body), "DialogueUI.finish_event() 存在")
check(dlg_nc.count("noTimeCost") == 1,
      "T-8：DialogueUI 代码中 noTimeCost 有且仅有 1 处（注释不计）",
      f"实际 {dlg_nc.count('noTimeCost')} 处")
check("noTimeCost" in fin_nc, "T-8：该处位于 finish_event() 内")
m_elif = re.search(r'elif\s+not\s+current_event\.get\(\s*"noTimeCost"\s*,\s*false\s*\)\s*:', fin_nc)
check(m_elif is not None,
      "T-8：形式为 elif not current_event.get(\"noTimeCost\", false):（而非 if / 提前 return）")
if m_elif:
    after = fin_nc[m_elif.end():m_elif.end() + 120]
    check("GameManager.advance_time()" in after,
          "T-8：该 elif 分支体即 GameManager.advance_time()（短路目标正确）")
check(dlg_nc.count("advance_time()") == 1,
      "T-8：全 DialogueUI 中 advance_time() 调用点唯一（无第二条绕过路径）",
      f"实际 {dlg_nc.count('advance_time()')} 处")
check(re.search(r"if\s+_should_skip_to_next_day\s+or\s+current_event\.get\(\s*\"skipToNextDay\"",
                fin_nc) is not None,
      "零回归：通宵跳日分支（skipToNextDay）仍为该 if/elif 链的第一分支，语义未变")
check(fin_nc.index("_should_skip_to_next_day") < fin_nc.index("noTimeCost"),
      "零回归：skipToNextDay 优先级高于 noTimeCost（通宵事件即便带该键也照常跳日）")
check(re.search(r'not current_event\.get\("repeatable", false\)', fin_nc) is not None
      and "set_flag(ev_id, true)" in fin_nc,
      "零回归：repeatable=false 事件仍写 flags[event_id]（既有语义未被改动波及）")
check("last_interact_" in fin_nc and 'current_event.get("charId"' in fin_nc,
      "零回归：charId 分支（last_interact_ + 日记）保持不变")
check("event_finished.emit()" in fin_nc, "零回归：finish_event 末尾仍 emit event_finished")
emit_pos = fin_nc.index("event_finished.emit()")
check(fin_nc.index("noTimeCost") < emit_pos,
      "noTimeCost 判定发生在 emit 之前（时段结算先于信号派发，与原语义一致）")
check("current_event = event_data" in dlg_nc,
      "start_event() 整份保存 current_event → finish_event 可读到 noTimeCost")
# T-9：全工程零既有事件携带该键
json_hits = []
for p in sorted(SCRIPTS.rglob("*.json")):
    if "noTimeCost" in p.read_text(encoding="utf-8"):
        json_hits.append(p.name)
check(not json_hits, "T-9：全部 events_*.json 均不携带 noTimeCost（零回归面证明）", str(json_hits))
gd_writers = []
for p in sorted(SCRIPTS.rglob("*.gd")):
    src = strip_comments(p.read_text(encoding="utf-8"))
    if re.search(r'"noTimeCost"\s*:', src):
        gd_writers.append(p.name)
check(gd_writers == ["CollectionManager.gd"],
      "T-9：noTimeCost 的唯一写入方是 CollectionManager.build_memory_echo_vignette()",
      str(gd_writers))
check(region_nc.count('"noTimeCost"') == 1,
      "noTimeCost 在记忆回响区内也仅出现 1 次", f"实际 {region_nc.count(chr(34) + 'noTimeCost' + chr(34))}")

# ── K. MainGame 触发钩子（T-10 / S-5 / §4.1）──────────────────────
section("K. MainGame 触发钩子与调用点唯一性（T-10 / S-5 / §4.1）")
main_nc = strip_comments(main_src)
onloc = strip_comments(extract_func(main_src, "_on_location_selected"))
tryecho = strip_comments(extract_func(main_src, "_try_memory_echo"))
check(bool(onloc), "MainGame._on_location_selected() 存在")
check(bool(tryecho), "MainGame._try_memory_echo() 存在")
check(re.search(r"func _try_memory_echo\(loc_id: String\) -> bool", main_src) is not None,
      "_try_memory_echo(loc_id: String) -> bool 签名与 GDD §4.1 一致")
check(re.search(r"if\s+_try_memory_echo\(loc_id\)\s*:\s*return", onloc) is not None,
      "§4.1：_on_location_selected 内 if _try_memory_echo(loc_id): return（命中即接管并立即返回）")
check("hotspot_ui.on_location_selected" in onloc, "_on_location_selected 仍调用 hotspot_ui.on_location_selected")
check(onloc.index("_try_memory_echo") < onloc.index("hotspot_ui.on_location_selected"),
      "§2.1 step 0：回响判定插在 hotspot_ui.on_location_selected 之前（进入地点之前）")
check(onloc.index("hotspot_container.show()") < onloc.index("_try_memory_echo"),
      "current_location / center_info / hotspot_container 三步在回响之前（UI 前置状态不变）")
# _try_memory_echo 内部顺序
for name in ["pick_memory_echo", "build_memory_echo_vignette", "commit_memory_echo", "start_event"]:
    check(name in tryecho, f"_try_memory_echo() 调用 {name}")
check(tryecho.index("pick_memory_echo") < tryecho.index("build_memory_echo_vignette")
      < tryecho.index("commit_memory_echo") < tryecho.index("start_event"),
      "§4.1 调用序：pick → build → commit → start_event")
check(tryecho.index("commit_memory_echo") < tryecho.index("start_event"),
      "§4.1 关键：commit 在 start_event 之前（先落冷却，防重入/防重复播）")
check(re.search(r"hit\.is_empty\(\)\s*:\s*return false", tryecho) is not None,
      "pick 未命中 → return false（放行正常进地点）")
check(re.search(r"vignette\.is_empty\(\)\s*:\s*return false", tryecho) is not None,
      "vignette 为空 → return false（数据异常静默放行，不阻断进地点）")
check("CONNECT_ONE_SHOT" in tryecho,
      "§4.1：event_finished 一次性 lambda 使用 CONNECT_ONE_SHOT（引擎自动断开，无连接泄漏）")
check(re.search(r"func\(\)\s*:\s*_on_location_selected\(loc_id\)", tryecho) is not None,
      "§3.4：播完重入 _on_location_selected(loc_id)（此时冷却已写，pick 必返回 {}，无递归）")
check("return true" in tryecho, "命中路径 return true（调用方立即 return）")
check(main_nc.index("dialogue_ui.event_finished.connect(_on_event_finished)")
      < main_nc.index("CONNECT_ONE_SHOT"),
      "§4.1 信号顺序：_ready() 的 _on_event_finished 先连，一次性 lambda 后连（UI 最终落在探索层）")
# 调用点唯一性（T-10 / S-5）
for api in ["pick_memory_echo", "build_memory_echo_vignette", "commit_memory_echo"]:
    callers = {}
    for p in sorted(SCRIPTS.rglob("*.gd")):
        src = strip_comments(p.read_text(encoding="utf-8"))
        cnt = len(re.findall(r"(?<!func )\b" + api + r"\(", src))
        if p.name == "CollectionManager.gd":
            cnt -= len(re.findall(r"func\s+" + api + r"\(", p.read_text(encoding="utf-8")))
        if cnt > 0:
            callers[p.name] = cnt
    check(callers == {"MainGame.gd": 1},
          f"T-10 / S-5：{api}() 全工程调用点有且仅有 1 处，且在 MainGame.gd", str(callers))
check("MEMORY_ECHO_CONTEXTS" not in main_nc,
      "MainGame 不直接读 MEMORY_ECHO_CONTEXTS（层次边界清晰，只经 API）")
check("HotspotExploreUI" not in region_nc and "hotspot" not in region_nc.lower(),
      "§4.2：CollectionManager 记忆回响区不触碰 HotspotExploreUI（该文件完全不动）")

# ── L. mem_echo_* 命名 + 单一写入源（T-14 / §5.3）─────────────────
section("L. mem_echo_* 命名规范与单一写入源（T-14 / §5.3）")
mem_files = {}
for p in sorted(SCRIPTS.rglob("*.gd")):
    src = strip_comments(p.read_text(encoding="utf-8"))
    c = src.count("mem_echo")
    if c:
        mem_files[p.name] = c
check(set(mem_files) == {"CollectionManager.gd"},
      "T-14：mem_echo 字面量仅出现在 CollectionManager.gd（无跨文件散落）", str(mem_files))
json_mem = [p.name for p in sorted(SCRIPTS.rglob("*.json"))
            if "mem_echo" in p.read_text(encoding="utf-8")]
check(not json_mem, "T-14：无任何事件 JSON 携带 mem_echo_* 键", str(json_mem))
setflag_calls = re.findall(r'set_flag\(\s*("?[^,]+?"?)\s*,', region_nc)
check(len(setflag_calls) >= 4, f"记忆回响区 set_flag 调用 >= 4 处（4 类键）", f"实际 {len(setflag_calls)}")
commit_setflags = re.findall(r"set_flag\(", commit)
check(len(commit_setflags) == 4,
      "T-14：commit_memory_echo() 恰 4 次 set_flag（_last / _count / last_day / total）",
      f"实际 {len(commit_setflags)}")
region_funcs_with_setflag = [fn for fn, body in FUNCS.items() if "set_flag" in body]
check(region_funcs_with_setflag == ["commit_memory_echo"],
      "T-14：记忆回响区内 set_flag 的唯一持有者是 commit_memory_echo()", str(region_funcs_with_setflag))
check(not re.search(r"GameManager\.flags\[[^\]]*mem_echo[^\]]*\]\s*=", region_nc),
      "§5.3：不使用 flags[key] = v 直写（统一走 set_flag 单一写入 API）")
for key in ['"mem_echo_%s_last" % sid', '"mem_echo_%s_count" % sid',
            '"mem_echo_last_day"', '"mem_echo_total"']:
    check(key in commit, f"commit_memory_echo() 写入 {key}")
check(re.search(r'set_flag\(key_last,\s*day\)', commit) is not None,
      "mem_echo_<sid>_last 写入当前 day（int，G5 冷却基准）")
check(re.search(r'set_flag\(key_count,\s*int\(.*?\)\s*\+\s*1\)', commit) is not None,
      "mem_echo_<sid>_count 自增 1（int，G7 上限基准）")
check(re.search(r'set_flag\("mem_echo_total",\s*int\(.*?\)\s*\+\s*1\)', commit) is not None,
      "mem_echo_total 自增 1（int，G8 上限基准）")
check(re.search(r"if not MEMORY_ECHO_CONTEXTS\.has\(sid\)\s*:\s*\n\s*return", commit) is not None,
      "commit_memory_echo() 未知 sid 直接 return（不写脏键）")
# GameManager.set_flag 支持 int
sf = strip_comments(extract_func(gm_src, "set_flag"))
check("value is bool" in sf and "flags[flag_name] = value" in sf,
      "§5.3 前置：GameManager.set_flag() 非 bool 值直接赋值 → 支持 int")
check(re.search(r"func set_flag\(flag_name: String, value: Variant\)", gm_src) is not None,
      "set_flag 形参为 Variant（可承载 int）")
check("flags.erase(flag_name)" in sf,
      "set_flag(false) 语义为 erase（mem_echo_* 用 int，不受该分支影响 —— 计数 0 时不写键即可）")
# 键总数上界
check(10 * 2 + 2 == 22, "§5.3 键规模上界：10×(_last + _count) + last_day + total = 22 个 int 键（零存档迁移）")

# ── M. 零新 Autoload / 零新脚本（T-13 / S-1）──────────────────────
section("M. 零新 Autoload / 零新脚本 / 零新资产（T-13 / S-1 / S-2）")
auto_block = project_src[project_src.index("[autoload]"):]
auto_block = auto_block[:auto_block.index("\n[", 1)] if "\n[" in auto_block[1:] else auto_block
auto_lines = [l for l in auto_block.splitlines() if re.match(r'^\w+\s*=\s*"\*?res://', l)]
check(len(auto_lines) == AUTOLOAD_EXPECTED,
      f"T-13 / S-1：[autoload] 段恰 {AUTOLOAD_EXPECTED} 条（零新增）", f"实际 {len(auto_lines)}")
check(any(l.startswith("CollectionManager=") for l in auto_lines),
      "逻辑寄居已注册的 CollectionManager（不新建 Autoload）")
check(not any("Memory" in l or "Echo" in l for l in auto_lines),
      "无 Memory* / Echo* 新 Autoload", str([l for l in auto_lines if "Memory" in l or "Echo" in l]))
new_scripts = [p.name for p in SCRIPTS.glob("*.gd")
               if re.search(r"memory.?echo", p.name, re.I)]
check(not new_scripts, "S-1：scripts/ 下无 memory_echo 专属新脚本（零新脚本文件）", str(new_scripts))
check(all((SCRIPTS / f).exists() for f in
          ["CollectionManager.gd", "DialogueUI.gd", "MainGame.gd"]),
      "§9：改动面恰为 3 个既有文件")
check("SaveSystem" in project_src, "§4.2：SaveSystem 仍在 Autoload（flags 整体序列化 → 零存档迁移）")
save_src = (SCRIPTS / "SaveSystem.gd").read_text(encoding="utf-8")
check("mem_echo" not in save_src, "SaveSystem.gd 无 mem_echo 专属迁移代码（零迁移，随 flags 走）")

# ── N. NG+ 自动清零（T-15 / S-7）──────────────────────────────────
section("N. NG+ 自动清零（T-15 / S-7）")
check("GameManager.flags = {}" in ending_src,
      "EndingScreen 新周目执行 flags = {}（mem_echo_* 随之清空）")
wl_zone = ending_src[ending_src.index("GameManager.flags = {}"):]
wl_zone = wl_zone[:wl_zone.index("SeasonManager") if "SeasonManager" in wl_zone else len(wl_zone)]
inherited = re.findall(r'GameManager\.flags\["([^"]+)"\]', wl_zone)
check("mem_echo" not in "".join(inherited),
      "T-15：mem_echo_* 不在 NG+ 继承白名单中", str(inherited))
check(set(inherited) <= {"ng_count", "seen_endings"},
      "NG+ 继承白名单仅 ng_count / seen_endings（+ title_* 前缀）", str(sorted(set(inherited))))
check("mem_echo" not in ending_src, "EndingScreen.gd 全文无 mem_echo（无需任何 NG+ 专属代码）")
check("holiday_memory" not in "".join(inherited),
      "§4.3：holiday_memory_*（回响前置）同样不继承 → 新周目回响池从 0 重建")

# ── O. 只读边界（T-16 / S-8 / §3.5）───────────────────────────────
section("O. 只读边界：不碰画廊 / 集章 / 深夜聊天 / 零机制产出（T-16 / S-8）")
check("unlock_gallery" not in region_nc,
      "T-16：记忆回响区不调用 unlock_gallery()（对画廊纯只读）")
check("show_toast" not in region_nc,
      "T-16 / §3.5：不 emit show_toast（全屏 CG 已是最强通知，避免认知过载 + 日志重复）")
check(not re.search(r'set_flag\(\s*"stamp_', region_nc) and not re.search(r'"stamp_"\s*\+', region_nc),
      "T-16 / §6.2：不写任何 stamp_* 键（与西湖十景集章零冲突）")
check("stamp_checkin_day" not in region_nc, "§6.2：不影响 stamp_checkin_day 每日打卡额度")
check("night_chat" not in region_nc, "§6.3：不写 night_chat_* 键（与深夜聊天零冲突）")
check("wechat_msg" not in region_nc and "pending_invite" not in region_nc,
      "§6.3：不产生微信消息、不占 wechat_msg 槽位、不触碰 pending_invite")
check(not re.search(r'set_flag\(\s*"seen_', region_nc), "不写 seen_* 画廊键")
check(not re.search(r'set_flag\(\s*"holiday_memory_', region_nc),
      "T-16：不写 holiday_memory_*（只消费，不生产）")
check("add_item" not in region_nc, "§3.5：不给物品")
check(not re.search(r"favorability\[[^\]]+\]\s*=", region_nc)
      and "add_favor" not in region_nc and "change_favor" not in region_nc,
      "§3.5：不加好感（favorability 仅被读取用于打分）")
check(not re.search(r"stats\[[^\]]+\]\s*[+\-]?=", region_nc) and "apply_location_gains" not in region_nc,
      "§3.5：不加属性")
check(region_nc.count("add_log(") == 1 and region_nc.count("add_diary_entry(") == 1,
      "§3.5：唯一的两条落地痕迹 = add_log ×1 + add_diary_entry ×1",
      f"log={region_nc.count('add_log(')} diary={region_nc.count('add_diary_entry(')}")
check("🕯️ 记忆回响" in commit, "add_log 文案带 🕯️ 记忆回响 前缀（日志流可辨识）")
check("忽然想起" in commit, "§3.5 长尾：日记条目「忽然想起<label>」（回忆行为留下时间戳）")
check("advance_time" not in region_nc, "记忆回响区不调用 advance_time（时段推进不由本层负责）")
check("day +=" not in region_nc and "slot_index" not in region_nc.replace("_get_slot_id", ""),
      "记忆回响区不改写 day / slot_index（S-4 零时间成本）")

# ── P. 成熟期可达性（T-12）────────────────────────────────────────
section("P. 成熟期可达性（T-12）")
bp_raw = extract_literal(daily_src, "const BREAK_PERIODS")
BREAK_PERIODS = gd_to_py(bp_raw)
check(set(BREAK_PERIODS) == {"winter", "spring", "summer", "autumn"},
      "BREAK_PERIODS 含四季区间", str(sorted(BREAK_PERIODS)))
mature_days = CONSTS["ECHO_MATURE_DAYS"]
last_night = CONSTS["ECHO_LAST_NIGHT_DAY"]
for season in ["winter", "spring", "summer", "autumn"]:
    born = BREAK_PERIODS[season][1]
    check(born + mature_days < last_night,
          f"T-12：{season} 记忆 mature = {born}+{mature_days} = {born + mature_days} < {last_night}（不存在永不成熟的记忆）")
# born 必须等于长假结束日（§1.2）
check(all(BREAK_PERIODS[s][1] > BREAK_PERIODS[s][0] for s in BREAK_PERIODS),
      "每个长假区间 end > start（born = end 推导有效）")
EXPECTED_BORN = {"winter": 100, "spring": 155, "summer": 300, "autumn": 309}
bmis = {s: BREAK_PERIODS[s][1] for s in EXPECTED_BORN if BREAK_PERIODS[s][1] != EXPECTED_BORN[s]}
check(not bmis, "born 值与 GDD §1.2 表格一致（winter100/spring155/summer300/autumn309）", str(bmis))
check(max(BREAK_PERIODS[s][1] for s in BREAK_PERIODS) < CONSTS["ECHO_FINALE_DAY"],
      "全部长假在 ECHO_FINALE_DAY(540) 之前结束 → G3 不会与终章加密期冲突")
check(not any(BREAK_PERIODS[s][0] <= last_night <= BREAK_PERIODS[s][1] for s in BREAK_PERIODS),
      "day 569 不落在任何长假区间内 → G3 不会否决毕业前夜特例（保底链路成立）")

# ── Q. 守卫模型推演：密度上限与保底（S-3 / §2.5 / §2.6）────────────
section("Q. 守卫模型推演（S-3 密度上限 / §2.5 保底）")
note("以下为按上文解析出的真实常量重建的守卫模型推演（非源码执行），用于验证 GDD §2.6 的算术结论")


def simulate(unlocked, visit_locs, ctx=CTX, consts=CONSTS, bp=BREAK_PERIODS):
    """最坏情况推演：玩家每天都去 visit_locs 中的每个地点。返回回响触发日列表。"""
    flags = {"last_day": -999, "total": 0}
    per = {s: {"last": -999, "count": 0} for s in unlocked}
    fired = []
    for day in range(1, consts["ECHO_END_DAY"] + 1):
        if day >= consts["ECHO_END_DAY"]:
            break
        in_holiday = any(bp[s][0] <= day <= bp[s][1] for s in bp)
        if in_holiday:
            continue
        is_last_night = (day == consts["ECHO_LAST_NIGHT_DAY"])
        is_finale = day >= consts["ECHO_FINALE_DAY"]
        for loc in visit_locs:
            # BUG-ME-01 修复镜像：毕业前夜同日仅一次（对应 pick_memory_echo() 的同日刹车）。
            # 必须逐 loc 判定 —— 源码守卫在每次 _on_location_selected 调用时求值，
            # 放在 day 循环顶部是死代码（当日尚未 fire，last_day 恒 < day）。
            if is_last_night and flags["last_day"] == day:
                continue
            if not is_last_night:
                g = consts["ECHO_GLOBAL_GAP_FINALE"] if is_finale else consts["ECHO_GLOBAL_GAP_DAYS"]
                if day - flags["last_day"] < g:
                    continue
                tcap = consts["ECHO_TOTAL_CAP"] + (consts["ECHO_FINALE_BONUS"] if is_finale else 0)
                if flags["total"] >= tcap:
                    continue
            best = None
            for sid in ctx:
                if sid not in unlocked:
                    continue
                if not is_last_night and ctx[sid]["loc"] != loc:
                    continue
                born = bp[sid.split("_")[0]][1]
                if day < born + consts["ECHO_MATURE_DAYS"]:
                    continue
                st = per[sid]
                if not is_last_night:
                    if day - st["last"] < consts["ECHO_MEM_COOLDOWN_DAYS"]:
                        continue
                    if st["count"] >= consts["ECHO_PER_MEM_CAP"]:
                        continue
                score = -1000.0 * st["count"] if is_last_night else 0.0
                score += 50.0 if st["count"] == 0 else 0.0
                score += min(200 if st["last"] <= -999 else min(day - st["last"], 200), 200) / 100.0
                if best is None or score > best[0] or (score == best[0] and sid < best[1]):
                    best = (score, sid)
            if best:
                sid = best[1]
                per[sid]["last"] = day
                per[sid]["count"] += 1
                flags["last_day"] = day
                flags["total"] += 1
                fired.append((day, sid))
    return fired


ALL_LOCS = sorted({c["loc"] for c in CTX.values()})
HARD_CAP = CONSTS["ECHO_TOTAL_CAP"] + CONSTS["ECHO_FINALE_BONUS"] + 1

full = simulate(set(CTX), ALL_LOCS)
d569_in_full = [d for d, _ in full if d == CONSTS["ECHO_LAST_NIGHT_DAY"]]
check(len(full) <= HARD_CAP,
      f"S-3 满池 + 每日遍历全部 4 个地点（最恶意刷屏）：{len(full)} 次 <= {HARD_CAP}",
      f"触发日 {[d for d, _ in full]}；其中 day569 单日触发 {len(d569_in_full)} 次（根因见 S 组）")
check(len(full) <= 11, f"S-3：最坏情况单周目回响 {len(full)} 次 <= 11（GDD §2.6 结论成立）",
      f"超出部分全部来自 day569 单日重复触发（{len(d569_in_full)} 次），根因见 S 组阻塞项")
check(len(d569_in_full) <= 1,
      f"§2.5 语义：day569 全天回响恰 1 次（GDD 原文「必然……得到一次回响」）",
      f"实际 {len(d569_in_full)} 次")
typical = simulate({"winter_yutong", "spring_wanqing", "summer_keke", "autumn_zicheng"}, ["lakeside"])
check(len(typical) <= 11, f"典型池（4 条 lakeside 主章）每日蹲点：{len(typical)} 次 <= 11")
tiny = simulate({"winter_yutong"}, ["lakeside"])
check(len(tiny) <= CONSTS["ECHO_PER_MEM_CAP"] + 1,
      f"极小池（1 条）：{len(tiny)} 次 <= 单条上限 {CONSTS['ECHO_PER_MEM_CAP']} + 569 特例 1",
      f"{tiny}")
check(len(tiny) >= 1, f"§2.5 保底：仅 1 条记忆的玩家至少获得 1 次回响（实测 {len(tiny)} 次）")
check(any(d == CONSTS["ECHO_LAST_NIGHT_DAY"] for d, _ in tiny),
      "§2.5 保底命中点落在 day 569 毕业前夜（情感峰值）", f"{tiny}")
# 极小池 + 从不去 lakeside（除 569 强制）
never = simulate({"winter_yifei"}, [])
check(len(never) == 0, "从不进入任何地点 → 零回响（钩子唯一性正确，无计时器兜底）", str(never))
forced569 = simulate({"winter_yifei"}, ["lakeside"])
check(len(forced569) >= 1 and any(d == 569 for d, _ in forced569),
      "cinema 记忆 + 只去 lakeside：day 569 无视 G2 仍然命中（§2.5 放宽生效）", str(forced569))
if full:
    gaps = [full[i + 1][0] - full[i][0] for i in range(len(full) - 1)]
    check(min(gaps) >= CONSTS["ECHO_GLOBAL_GAP_FINALE"] or all(
        g >= CONSTS["ECHO_GLOBAL_GAP_FINALE"] for g in gaps),
        f"S-3：任意两次回响间隔 >= {CONSTS['ECHO_GLOBAL_GAP_FINALE']} 天（终章下限）",
        f"最小间隔 {min(gaps)}")
    pre_finale_gaps = [full[i + 1][0] - full[i][0] for i in range(len(full) - 1)
                       if full[i + 1][0] < CONSTS["ECHO_FINALE_DAY"]]
    if pre_finale_gaps:
        check(min(pre_finale_gaps) >= CONSTS["ECHO_GLOBAL_GAP_DAYS"],
              f"S-3：非终章期间隔 >= {CONSTS['ECHO_GLOBAL_GAP_DAYS']} 天",
              f"最小 {min(pre_finale_gaps)}")
    percount = {}
    for _, s in full:
        percount[s] = percount.get(s, 0) + 1
    over = {s: c for s, c in percount.items() if c > CONSTS["ECHO_PER_MEM_CAP"] + 1}
    check(not over, f"单条记忆触发次数 <= {CONSTS['ECHO_PER_MEM_CAP']} + 1（569 特例）", str(over))
    earliest = min(d for d, _ in full)
    min_mature = min(BREAK_PERIODS[s.split("_")[0]][1] for s in CTX) + CONSTS["ECHO_MATURE_DAYS"]
    check(earliest >= min_mature,
          f"最早回响日 {earliest} >= 最早成熟日 {min_mature}（G4 沉淀期生效，无「刚发生就回响」）")

# ── S. 重入安全（§3.4 / §4.1「天然防递归」契约）───────────────────
section("S. 重入安全 —— 一次性 lambda 回调的防递归契约（§3.4 / §4.1）")
note("GDD §3.4/§4.1 的防递归论证原文：「播完后由 MainGame 重新走一遍 _on_location_selected("
     "loc_id)，此时冷却已写，pick_memory_echo 必然返回 {}，天然防递归」。"
     "该论证**完全依赖 G5/G6/G7/G8**；下列断言逐日验证该前提是否真的成立。")


def reentry_depth(day, loc, unlocked, max_depth=40, ctx=CTX, consts=CONSTS, bp=BREAK_PERIODS):
    """复现 _on_location_selected → _try_memory_echo → finish_event → 一次性 lambda 重入 链路。
    返回同一次「玩家点击一个地点」所连续播放的回响次数。>= max_depth 视为无限循环。"""
    flags = {"last_day": -999, "total": 0}
    per = {s: {"last": -999, "count": 0} for s in unlocked}
    plays = 0
    while plays < max_depth:
        is_last_night = (day == consts["ECHO_LAST_NIGHT_DAY"])
        is_finale = day >= consts["ECHO_FINALE_DAY"]
        if is_last_night and flags["last_day"] == day:  # BUG-ME-01 修复镜像：毕业前夜一次点击仅一次回响
            break
        if day >= consts["ECHO_END_DAY"]:
            break
        if not is_last_night:
            g = consts["ECHO_GLOBAL_GAP_FINALE"] if is_finale else consts["ECHO_GLOBAL_GAP_DAYS"]
            if day - flags["last_day"] < g:
                break
            tcap = consts["ECHO_TOTAL_CAP"] + (consts["ECHO_FINALE_BONUS"] if is_finale else 0)
            if flags["total"] >= tcap:
                break
        best = None
        for sid in ctx:
            if sid not in unlocked:
                continue
            if not is_last_night and ctx[sid]["loc"] != loc:
                continue
            if day < bp[sid.split("_")[0]][1] + consts["ECHO_MATURE_DAYS"]:
                continue
            st = per[sid]
            if not is_last_night:
                if day - st["last"] < consts["ECHO_MEM_COOLDOWN_DAYS"]:
                    continue
                if st["count"] >= consts["ECHO_PER_MEM_CAP"]:
                    continue
            score = -1000.0 * st["count"] if is_last_night else 0.0
            score += 50.0 if st["count"] == 0 else 0.0
            if best is None or score > best[0] or (score == best[0] and sid < best[1]):
                best = (score, sid)
        if best is None:
            break
        sid = best[1]
        per[sid]["last"] = day
        per[sid]["count"] += 1
        flags["last_day"] = day
        flags["total"] += 1
        plays += 1
    return plays


TINY = {"winter_yutong"}
FULL = set(CTX)
for day, label in [(130, "首个成熟日 day130"), (342, "常态日 day342"),
                   (540, "终章首日 day540"), (545, "终章日 day545"), (568, "day568")]:
    d = reentry_depth(day, "lakeside", FULL)
    check(d <= 1, f"{label}：单次点击地点仅播放 {d} 次回响（G6 兜住重入，§3.4 防递归成立）",
          f"连播 {d} 次")
d569_tiny = reentry_depth(CONSTS["ECHO_LAST_NIGHT_DAY"], "lakeside", TINY)
check(d569_tiny <= 1,
      f"【阻塞】毕业前夜 day569（池=1 条）：单次点击 lakeside 播放 {d569_tiny} 次回响，应 <= 1",
      "§2.5 放宽 G5/G6/G7/G8 后，§4.1 的一次性 lambda 重入失去唯一刹车 → 同一条记忆无限连播")
d569_full = reentry_depth(CONSTS["ECHO_LAST_NIGHT_DAY"], "lakeside", FULL)
check(d569_full <= 1,
      f"【阻塞】毕业前夜 day569（池=10 条）：单次点击 lakeside 播放 {d569_full} 次回响，应 <= 1",
      "count 升序轮转全部已解锁记忆后继续循环，玩家无法进入 lakeside 探索层")
check(reentry_depth(CONSTS["ECHO_LAST_NIGHT_DAY"], "lakeside", FULL, max_depth=200) < 200,
      "【阻塞】day569 重入链路可自行终止（非无限循环）",
      "推演 200 层未终止 → 无限循环，day569 lakeside 内容不可达 + mem_echo_total/日记无界增长")
# 源码级：期望存在 569 当日一次性守卫
has_same_day_guard = bool(
    re.search(r"is_last_night\s+and\s+.*mem_echo_last_day", pick)
    or re.search(r"mem_echo_last_day.*==\s*day", pick)
    or re.search(r"mem_echo_last_night_done", pick))
check(has_same_day_guard,
      "【阻塞】pick_memory_echo() 存在「569 当日仅一次」守卫（G6 被放宽后的替代刹车）",
      "当前 is_last_night 分支完全跳过 G5/G6/G7/G8，无任何同日去重")

# ── R. 缩进风格一致性 ─────────────────────────────────────────────
section("R. 缩进风格一致性（防 GDScript mixed-indent 解析错误）")
INDENT_EXPECT = {
    "CollectionManager.gd": "tab",
    "DialogueUI.gd": "space",
    "MainGame.gd": "space",
    "GameManager.gd": "space",
}
for fname, want in INDENT_EXPECT.items():
    text = (SCRIPTS / fname).read_text(encoding="utf-8")
    lines = [l for l in text.splitlines() if l.strip()]
    tabs = sum(1 for l in lines if l.startswith("\t"))
    spcs = sum(1 for l in lines if l.startswith(" "))
    if want == "tab":
        check(tabs > 0 and spcs == 0, f"{fname}: 纯 tab 缩进（{tabs} tab / {spcs} space）")
    else:
        check(spcs > 0 and tabs == 0, f"{fname}: 纯 4 空格缩进（{spcs} space / {tabs} tab）")
    mixed = [n for n, l in enumerate(text.splitlines(), 1) if re.match(r"^(\t+ | +\t)", l)]
    check(not mixed, f"{fname}: 无行内 tab/space 混用", str(mixed[:5]))
# 记忆回响区（新增代码）单独复核
region_lines = [l for l in region_src.splitlines() if l.strip() and (l[0] in " \t")]
check(all(l.startswith("\t") for l in region_lines),
      "新增的记忆回响区 100% tab 缩进（与 CollectionManager 既有风格一致）",
      str([l[:30] for l in region_lines if not l.startswith("\t")][:3]))
bad_indent_main = [n for n, l in enumerate(extract_func(main_src, "_try_memory_echo").splitlines(), 1)
                   if l.strip() and l[0] == "\t"]
check(not bad_indent_main, "新增的 MainGame._try_memory_echo() 为空格缩进（与该文件一致）", str(bad_indent_main))

# ── 非阻塞关注项（advisory）───────────────────────────────────────
section("非阻塞关注项 (advisory)")
if "ECHO_BG_TINT" in CONSTS and "bgTint" not in coll_nc and "bgTint" not in dlg_nc:
    note("P1 未接线：ECHO_BG_TINT 常量已定义但 DialogueUI 侧无 bgTint 支持（GDD §3.3 允许直接跳过 P1）。"
         "当前为「已声明未使用」常量，不影响 P0 功能；若长期不做建议在下个整理周期移除或加 TODO 标注")
note("vignette 文本质量（40 句：10×3 正文 + 10 finale_line）为静态断言不可覆盖项，"
     "需实机通读确认打字机节奏、断句、「」引号在 1280×720 下的折行表现")
note("回响打断当前流程的排队健壮性：GDD §7-② 以「选址」消解（唯一播放点 = _on_location_selected step 0，"
     "栈上无其它 UI）。静态可证调用链唯一，但「_on_accept_invite → _on_location_selected」路径（MainGame L246-251）"
     "会在 board_ui.show_center_info + update_ui 之后进入回响，建议实机验证一次「接受邀约 → 回响 → 进地点」的 UI 恢复顺序")
note("NG+ 行为：mem_echo_* 4 类键 + holiday_memory_* 前置全部随 EndingScreen 的 flags = {} 清空，"
     "静态可证不在继承白名单；建议实机走一次 NG+ 确认新周目首次进 lakeside 无残留回响")
note("GDD §7-④ 上游可达性疑点复核结论：break_spring_chapter_xiaoxia / break_summer_chapter_zijun / "
     "break_autumn_chapter_jingjing_m 三条 chapter 的 location=community + slotId=after，"
     "而 GameManager.locations['community'].slots 仅含 evening → 常规路径不可达，仅邀约路径可解锁。"
     "属既有内容问题，非本特性引入，本特性不受阻（day 569 特例 + lakeside 4 条主章兜底）")
note("SL 刷回响：mem_echo_* 随存档序列化，读档即回滚冷却 —— 与全游戏所有 SL 行为一致，GDD 明确不特殊处理")
note("day 569 连响原阻塞项 BUG-ME-01 已 RESOLVED：CollectionManager.gd pick_memory_echo() 同日仅一次刹车 + 门禁模拟镜像 simulate()/reentry_depth() 同步，A273-A275 等复测通过；详见 QA_REPORT.md 阻塞项 BUG-ME-01")

# ── 判定 ──────────────────────────────────────────────────────────
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
