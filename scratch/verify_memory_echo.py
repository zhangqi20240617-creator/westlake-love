# -*- coding: utf-8 -*-
"""
DS-RN-02 记忆回响 · 情境回响 —— 工程侧逻辑级验证（无 Godot runtime）
Owner: 程基岩 (engineering-lead)

方法：纯静态断言（解析 .gd 文本 / json.load / 常量验算 / 缩进扫描），对游戏代码只读。
参考写法：tests/west_lake_stamps_smoke/verify_qa.py（独立断言 + GDScript 字面量解析）。

覆盖用户验收清单 ①~⑧ + GDD §7-③ 的关键静态断言：
  A  MEMORY_ECHO_CONTEXTS 真源（①，T-1/T-2/T-5）
  B  与 GALLERY_ITEMS / events_break.json 双源交叉（①，T-3/T-4）
  C  CollectionManager 函数齐备（②）
  D  DialogueUI noTimeCost 短路分支 + 零回归面（③，T-8/T-9）
  E  MainGame 接线闭合（④，T-10/S-5）
  F  vignette dict 硬约束（⑤，T-6/T-7）
  G  mem_echo_* 命名规范 + 单一写入源 + set_flag（⑥，T-14/T-15）
  H  零新 Autoload / 零新脚本（⑦，T-13/S-1）
  I  缩进一致性（⑧，防 GDScript mixed tabs and spaces）
  J  常量算术与可达性（T-11/T-12/S-3）
  K  只读边界：不碰画廊/集章/toast（S-8/§3.5）

退出码：0 = 全过，1 = 有失败断言。
"""
import ast
import io
import json
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"

COLL = SCRIPTS / "CollectionManager.gd"
GM = SCRIPTS / "GameManager.gd"
DLG = SCRIPTS / "DialogueUI.gd"
MAIN = SCRIPTS / "MainGame.gd"
DAILY = SCRIPTS / "DailyCycleManager.gd"
ENDING = SCRIPTS / "EndingScreen.gd"
EV_BREAK = SCRIPTS / "events_break.json"
PROJECT = ROOT / "project.godot"

# GDD §1.2 —— sid 全集与顺序（插入顺序 = 表格顺序，不可排序）
EXPECTED_SIDS = [
    "winter_yutong", "winter_jingjing", "winter_yifei",
    "spring_wanqing", "spring_xiaoxia", "spring_beichen",
    "summer_keke", "summer_zijun",
    "autumn_zicheng", "autumn_jingjing_m",
]
# GDD §1.2 —— loc / slot 真源（应与 events_break.json chapter 逐字一致）
EXPECTED_CTX = {
    "winter_yutong": ("lakeside", "evening"),
    "winter_jingjing": ("off_campus_shop", "after"),
    "winter_yifei": ("cinema", "noon"),
    "spring_wanqing": ("lakeside", "evening"),
    "spring_xiaoxia": ("community", "after"),
    "spring_beichen": ("cinema", "noon"),
    "summer_keke": ("lakeside", "evening"),
    "summer_zijun": ("community", "after"),
    "autumn_zicheng": ("lakeside", "evening"),
    "autumn_jingjing_m": ("community", "after"),
}
AUTOLOAD_EXPECTED = 15          # 改动前基线（零新 Autoload）
ECHO_SECTION_MARKER = "# ── 记忆回响 · 情境回响（DS-RN-02）"

# ─────────────────────────────────────────────────────────────────
_n = 0
failures = []


def check(cond, desc, detail=""):
    global _n
    _n += 1
    tag = f"E{_n:02d}"
    if cond:
        print(f"  [PASS] {tag}  {desc}")
    else:
        msg = f"{tag}  {desc}" + (f"  →  {detail}" if detail else "")
        failures.append(msg)
        print(f"  [FAIL] {msg}")
    return bool(cond)


def section(title):
    print(f"\n--- {title} ---")


# ── GDScript 字面量提取（字符串感知；# 注释仅在字符串外生效）──────
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
    return "".join(out)


def load_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_to_py(extract_block(path.read_text(encoding="utf-8"), anchor)))


def src_of(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def func_body(src: str, name: str) -> str:
    """取 func <name> 的函数体（到下一个顶层 func / 顶层注释块 / EOF）。
    尾部的顶层注释块属于下一个函数的文档，需剔除，避免误判。"""
    m = re.search(r"^func %s\(.*?\).*?:\n(.*?)(?=^func |^# ═|\Z)" % re.escape(name),
                  src, re.S | re.M)
    if not m:
        return ""
    lines = m.group(1).split("\n")
    while lines and (not lines[-1].strip() or lines[-1].lstrip().startswith("#")) \
            and not lines[-1].startswith(("\t", " ")):
        lines.pop()
    return "\n".join(lines)


def strip_comments(src: str) -> str:
    """删除 GDScript 注释（字符串感知），用于"代码级"出现次数统计。"""
    out, i, in_str, esc = [], 0, False, False
    while i < len(src):
        c = src[i]
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
            nl = src.find("\n", i)
            i = nl if nl != -1 else len(src)
            continue
        out.append(c)
        i += 1
    return "".join(out)


def gd_const_int(src: str, name: str) -> int:
    m = re.search(r"^const\s+%s\s*:?=\s*(-?\d+)" % re.escape(name), src, re.M)
    assert m, f"常量未找到: {name}"
    return int(m.group(1))


# ═════════════════════════════════════════════════════════════════
print("=" * 78)
print("DS-RN-02  记忆回响 · 情境回响 —— 工程侧逻辑级验证")
print(f"root = {ROOT}")
print("=" * 78)

coll_src = src_of(COLL)
dlg_src = src_of(DLG)
main_src = src_of(MAIN)
gm_src = src_of(GM)
ending_src = src_of(ENDING)

CTX = load_literal(COLL, "const MEMORY_ECHO_CONTEXTS = ")
GALLERY = load_literal(GM, "GALLERY_ITEMS = ")
BREAKS = load_literal(DAILY, "const BREAK_PERIODS = ")
BREAK_EVENTS = json.loads(EV_BREAK.read_text(encoding="utf-8"))
ECHO_SRC = coll_src[coll_src.index(ECHO_SECTION_MARKER):]      # 记忆回响区（到 EOF）

print(f"\n[parse] MEMORY_ECHO_CONTEXTS={len(CTX)}  GALLERY_ITEMS={len(GALLERY)}"
      f"  BREAK_PERIODS={len(BREAKS)}  events_break={len(BREAK_EVENTS)}"
      f"  记忆回响区={len(ECHO_SRC.splitlines())} 行")

# ── A. MEMORY_ECHO_CONTEXTS 真源（①）────────────────────────────
section("A. MEMORY_ECHO_CONTEXTS —— 本层唯一真源  (①/T-1/T-2/T-5)")
sids = list(CTX.keys())
check(len(CTX) == 10, "MEMORY_ECHO_CONTEXTS 恰含 10 条", f"实得 {len(CTX)}")
check(sids == EXPECTED_SIDS, "键顺序 == GDD §1.2 表格顺序（插入顺序即遍历顺序）", f"实得 {sids}")
check(len(set(sids)) == len(sids), "sid 无重复")

bad_fields = {s: sorted(set(CTX[s].keys()) - {"loc", "slot", "lines", "finale_line"}) for s in sids}
bad_fields = {k: v for k, v in bad_fields.items() if v}
check(not bad_fields, "字段仅 loc/slot/lines/finale_line（不重复 char/bg/label/born，S-6）", str(bad_fields))

missing = {s: [f for f in ("loc", "slot", "lines", "finale_line") if f not in CTX[s]] for s in sids}
missing = {k: v for k, v in missing.items() if v}
check(not missing, "每条 4 个字段齐全", str(missing))

bad_lines = {s: len(CTX[s]["lines"]) for s in sids if len(CTX[s]["lines"]) != 3}
check(not bad_lines, "每条 lines 恰 3 句（触景/闪回/独白）", str(bad_lines))
empty_line = {s: CTX[s]["lines"] for s in sids if any(not str(x).strip() for x in CTX[s]["lines"])}
check(not empty_line, "lines 无空串", str(list(empty_line)))
empty_fin = [s for s in sids if not str(CTX[s]["finale_line"]).strip()]
check(not empty_fin, "finale_line 均非空", str(empty_fin))
dup_text = [s for s in sids if len(set(CTX[s]["lines"])) != 3]
check(not dup_text, "同条 3 句互不重复（防复制粘贴漂移）", str(dup_text))

# ── B. 双源交叉：GALLERY_ITEMS + events_break.json（①）──────────
section("B. 双源交叉 —— GALLERY_ITEMS / events_break.json  (①/T-3/T-4)")
gallery_sids = [str(it["flag"])[len("holiday_memory_"):] for it in GALLERY
                if str(it.get("flag", "")).startswith("holiday_memory_")]
check(set(sids) == set(gallery_sids),
      "sid 集合 == GALLERY_ITEMS 中 holiday_memory_* 的 sid 全集",
      f"ctx-only={sorted(set(sids) - set(gallery_sids))} gallery-only={sorted(set(gallery_sids) - set(sids))}")
check(len(gallery_sids) == 10, "GALLERY_ITEMS 中 holiday_memory_* 恰 10 条", f"实得 {len(gallery_sids)}")

gallery_by_sid = {str(it["flag"])[len("holiday_memory_"):]: it for it in GALLERY
                  if str(it.get("flag", "")).startswith("holiday_memory_")}
no_bg = [s for s in sids if not str(gallery_by_sid.get(s, {}).get("bg", ""))]
check(not no_bg, "每条 sid 可从 GALLERY_ITEMS 反查到 bg（CG 反查真源）", str(no_bg))
no_char = [s for s in sids if not str(gallery_by_sid.get(s, {}).get("char", ""))]
check(not no_char, "每条 sid 可反查到 char（G9 冷战判定所需）", str(no_char))

ev_by_id = {e.get("id", ""): e for e in BREAK_EVENTS}
mismatch = {}
for s in sids:
    season, char = s.split("_", 1)
    ev = ev_by_id.get(f"break_{season}_chapter_{char}", {})
    got = (str(ev.get("location", "")), str(ev.get("slotId", "")))
    want = (CTX[s]["loc"], CTX[s]["slot"])
    if got != want:
        mismatch[s] = {"ctx": want, "events_break": got}
check(not mismatch, "每条 loc/slot 与 events_break.json chapter 的 location/slotId 逐字一致", str(mismatch))
check({s: (CTX[s]["loc"], CTX[s]["slot"]) for s in sids} == EXPECTED_CTX,
      "loc/slot 与 GDD §1.2 表格逐字一致")

# ── C. CollectionManager 函数齐备（②）──────────────────────────
section("C. CollectionManager 记忆回响函数齐备  (②)")
for fn, sig in [
    ("pick_memory_echo", r"func pick_memory_echo\(loc_id: String\) -> Dictionary:"),
    ("build_memory_echo_vignette", r"func build_memory_echo_vignette\(sid: String\) -> Dictionary:"),
    ("commit_memory_echo", r"func commit_memory_echo\(sid: String\) -> void:"),
    ("_memory_gallery_item", r"func _memory_gallery_item\(sid: String\) -> Dictionary:"),
    ("_memory_born_day", r"func _memory_born_day\(sid: String\) -> int:"),
]:
    check(re.search(sig, coll_src) is not None, f"{fn}() 存在且签名符合 GDD §5.5", sig)

pick_body = func_body(coll_src, "pick_memory_echo")
guards = {
    "G0 非结局日": "ECHO_END_DAY",
    "G1 已解锁": 'flags.has("holiday_memory_" + sid)',
    "G2 地点匹配": 'ctx.get("loc", "")) != loc_id',
    "G3 非长假": "current_holiday",
    "G4 成熟期": "_memory_born_day(sid) + ECHO_MATURE_DAYS",
    "G5 单条冷却": "ECHO_MEM_COOLDOWN_DAYS",
    "G6 全局冷却": "mem_echo_last_day",
    "G7 单条上限": "ECHO_PER_MEM_CAP",
    "G8 全局上限": "ECHO_TOTAL_CAP",
    "G9 排除冷战": 'get_rel_state(cid) == "cold"',
}
for label, needle in guards.items():
    check(needle in pick_body, f"pick_memory_echo 含守卫 {label}", needle)
check("ECHO_LAST_NIGHT_DAY" in pick_body, "pick_memory_echo 含毕业前夜特例（GDD §2.5）")
check(re.search(r"\bset_flag\b|\bflags\[", pick_body) is None,
      "pick_memory_echo 为纯判定：不写任何 flag（GDD §2.2）")
check("_memory_gallery_item" in func_body(coll_src, "build_memory_echo_vignette")
      and "_memory_gallery_item" in pick_body,
      "char/bg/label 统一经 _memory_gallery_item 反查（S-6）")

born_body = func_body(coll_src, "_memory_born_day")
check("DailyCycleManager.BREAK_PERIODS" in born_body and "99999" in born_body,
      "_memory_born_day 由 BREAK_PERIODS 推导且含安全失败值 99999")

# ── D. DialogueUI noTimeCost 短路（③）──────────────────────────
section("D. DialogueUI —— noTimeCost 短路分支  (③/T-8/T-9)")
finish_body = func_body(dlg_src, "finish_event")
check('elif not current_event.get("noTimeCost", false):' in finish_body,
      "finish_event 含 noTimeCost 短路分支（替代原 else）")
m = re.search(r'elif not current_event\.get\("noTimeCost", false\):\s*\n\s*GameManager\.advance_time\(\)',
              finish_body)
check(m is not None, "短路分支体恰为 GameManager.advance_time()（语义等价原 else）")
check(finish_body.count("GameManager.advance_time()") == 1,
      "finish_event 中 advance_time 调用点仍为 1 处（零回归）",
      str(finish_body.count("GameManager.advance_time()")))
check("event_finished.emit()" in finish_body and "hide()" in finish_body,
      "短路后仍做收尾：hide() + event_finished.emit()")
# 短路分支必须在 emit 之前、hide 之后（收尾顺序不变）
i_hide = finish_body.index("hide()")
i_elif = finish_body.index('elif not current_event.get("noTimeCost", false):')
i_emit = finish_body.index("event_finished.emit()")
check(i_hide < i_elif < i_emit, "收尾顺序不变：hide() → 时段分支 → event_finished.emit()")

dlg_code = strip_comments(dlg_src)
check(dlg_code.count("noTimeCost") == 1,
      "DialogueUI 中 noTimeCost 代码级出现有且仅有 1 处", str(dlg_code.count("noTimeCost")))
check("current_event = event_data" in dlg_src,
      "start_event() 整份保存 event dict 供 finish_event 读取 noTimeCost")
json_hits = {p.name: p.read_text(encoding="utf-8").count("noTimeCost")
             for p in sorted(SCRIPTS.glob("events*.json"))}
check(sum(json_hits.values()) == 0,
      "全部 events*.json 均不含 noTimeCost（零回归面，T-9）", str(json_hits))
writers = sorted(p.name for p in SCRIPTS.glob("*.gd")
                 if "noTimeCost" in strip_comments(p.read_text(encoding="utf-8")))
check(writers == ["CollectionManager.gd", "DialogueUI.gd"],
      "noTimeCost 仅出现在 CollectionManager（写）与 DialogueUI（读）", str(writers))

# ── E. MainGame 接线闭合（④）──────────────────────────────────
section("E. MainGame —— step 0 接线闭合  (④/T-10/S-5)")
check(re.search(r"func _try_memory_echo\(loc_id: String\) -> bool:", main_src) is not None,
      "_try_memory_echo(loc_id) -> bool 存在")
sel_body = func_body(main_src, "_on_location_selected")
check("if _try_memory_echo(loc_id): return" in sel_body,
      "_on_location_selected 调用 _try_memory_echo 并在命中时 return")
check(sel_body.index("if _try_memory_echo(loc_id): return")
      < sel_body.index("hotspot_ui.on_location_selected(loc_id)"),
      "step 0 位于 hotspot_ui.on_location_selected 之前（进地点之前播放）")
try_body = func_body(main_src, "_try_memory_echo")
order_keys = ["CollectionManager.pick_memory_echo", "CollectionManager.build_memory_echo_vignette",
              "CollectionManager.commit_memory_echo", "location_explore_ui.hide()",
              "dialogue_ui.show()", "CONNECT_ONE_SHOT", "dialogue_ui.start_event(vignette)"]
idxs = [try_body.find(k) for k in order_keys]
check(all(i >= 0 for i in idxs), "_try_memory_echo 含完整调用链", str(dict(zip(order_keys, idxs))))
check(idxs == sorted(idxs), "调用顺序 = pick → build → commit → hide/show → 一次性连接 → start_event",
      str(dict(zip(order_keys, idxs))))
check(try_body.index("CollectionManager.commit_memory_echo")
      < try_body.index("dialogue_ui.start_event(vignette)"),
      "commit 早于 start_event（防重入，GDD §4.1）")
check(try_body.count("return false") == 2,
      "两处空判断兜底：pick 空 / build 空 均 return false", str(try_body.count("return false")))
check("event_finished.connect(" in try_body and "CONNECT_ONE_SHOT" in try_body,
      "一次性回调用 CONNECT_ONE_SHOT（引擎自动断开，防泄漏）")
check("_on_event_finished" in func_body(main_src, "_ready"),
      "_ready 仍先连 _on_event_finished（信号派发顺序：先恢复看板，后重入探索层）")

all_gd = {p.name: strip_comments(p.read_text(encoding="utf-8")) for p in SCRIPTS.glob("*.gd")}
for api in ("pick_memory_echo", "build_memory_echo_vignette", "commit_memory_echo"):
    callers = {n: s.count(f"CollectionManager.{api}") for n, s in all_gd.items()
               if f"CollectionManager.{api}" in s}
    check(callers == {"MainGame.gd": 1}, f"{api} 全工程调用点有且仅有 1 处（MainGame）", str(callers))

# ── F. vignette dict 硬约束（⑤）───────────────────────────────
section("F. vignette dict 硬约束  (⑤/T-6/T-7)")
vig_body = func_body(coll_src, "build_memory_echo_vignette")
for banned in ("pose", "setFlag", "setFlags", "addItem", "affDelta",
               "statDelta", "statsDelta", "choices", "charId"):
    check(f'"{banned}"' not in vig_body, f"vignette 不写 {banned} 字段（GDD §5.4）")
check('"location":   ""' in vig_body or re.search(r'"location":\s*""', vig_body) is not None,
      "location 为空串（跳过地点增益重复发放 + 天气 toast）")
check(re.search(r'"repeatable":\s*true', vig_body) is not None,
      "repeatable: true（避免写出 mem_echo_<sid> 布尔键）")
check(re.search(r'"noTimeCost":\s*true', vig_body) is not None, "noTimeCost: true（不消耗时段）")
check(re.search(r'"isSpecial":\s*false', vig_body) is not None, "isSpecial: false（不进 special 队列）")
check(vig_body.count('"next"') == 1 and re.search(r'\["next"\]\s*=\s*99', vig_body) is not None,
      "仅最后一句写 next:99")
check('"speaker": null' in vig_body and vig_body.count('"speaker": null') >= 1,
      "全部 scene 使用 speaker: null（全屏 CG + 纯旁白，GDD §3.2）")
check('"bg":' in vig_body and 'item.get("bg"' in vig_body,
      "bg 由 GALLERY_ITEMS 反查，不硬编码路径")
check("ECHO_FINALE_DAY" in vig_body and "finale_line" in vig_body,
      "day >= ECHO_FINALE_DAY 时追加 finale_line 第 4 句")
check("hint" in vig_body, "lines 为空时降级为画廊 hint 单句（GDD §1.5 兜底）")
check(re.search(r"\bset_flag\b|\bflags\[", vig_body) is None,
      "build_memory_echo_vignette 不写任何 flag")

# ── G. mem_echo_* 命名规范 + 单一写入源（⑥）────────────────────
section("G. mem_echo_* flag 规范 / 单一写入源  (⑥/T-14/T-15)")
commit_body = func_body(coll_src, "commit_memory_echo")
for key in ('"mem_echo_%s_last" % sid', '"mem_echo_%s_count" % sid',
            '"mem_echo_last_day"', '"mem_echo_total"'):
    check(key in commit_body or key.replace('"', "") in commit_body.replace('"', ""),
          f"commit_memory_echo 写入 {key}")
check(commit_body.count("GameManager.set_flag(") == 4,
      "4 个键全部经 GameManager.set_flag 写入", str(commit_body.count("GameManager.set_flag(")))
check("GameManager.flags[" not in commit_body,
      "commit 不直接改 flags[key]（保持单一写入 API，GDD §5.3 注）")
# flag 键 = 出现在 set_flag(...) / flags.get(...) / flags.has(...) 中的 mem_echo_* 字面量
# （vignette 的事件 id "mem_echo_" + sid 不是 flag 键，repeatable:true 保证它不落盘）
flag_ctx = re.findall(r'(?:set_flag|flags\.get|flags\.has)\(\s*"(mem_echo_[a-z_%]*)"', ECHO_SRC)
flag_ctx += re.findall(r'(?:key_last|key_count): String = "(mem_echo_[a-z_%]*)"', ECHO_SRC)
echo_keys = set(flag_ctx)
check(echo_keys and all(k.startswith("mem_echo_") for k in echo_keys),
      "全部新增键以 mem_echo_ 前缀命名（便于 grep 与 NG+ 审计）", str(sorted(echo_keys)))
check(echo_keys == {"mem_echo_%s_last", "mem_echo_%s_count", "mem_echo_last_day", "mem_echo_total"},
      "键种类恰为 GDD §5.3 的 4 类", str(sorted(echo_keys)))
check(re.search(r'"id":\s*"mem_echo_" \+ sid', ECHO_SRC) is not None
      and re.search(r'"repeatable":\s*true', ECHO_SRC) is not None,
      "事件 id mem_echo_<sid> 由 repeatable:true 保证不写成布尔 flag（GDD §5.4）")
writer_files = {n: len(re.findall(r'set_flag\(\s*(?:key_last|key_count|"mem_echo)', s))
                for n, s in all_gd.items() if "mem_echo" in s}
check(set(writer_files) == {"CollectionManager.gd"},
      "mem_echo_ 写入点仅在 CollectionManager", str(sorted(writer_files)))
other_writers = [n for n, s in all_gd.items()
                 if n != "CollectionManager.gd" and "mem_echo" in s]
check(not other_writers, "其它脚本不出现 mem_echo 字面量", str(other_writers))
ng_inherit = re.search(r"for\s+\w+\s+in\s+\[([^\]]*)\]", ending_src)
check("mem_echo" not in ending_src,
      "EndingScreen.gd 不含 mem_echo（NG+ 随 flags={} 自动清零，S-7）")

# ── H. 零新 Autoload / 零新脚本（⑦）───────────────────────────
section("H. 零新 Autoload / 零新脚本  (⑦/T-13/S-1)")
proj = PROJECT.read_text(encoding="utf-8")
seg = proj.split("[autoload]", 1)[1].split("[", 1)[0]
autoloads = [l.split("=")[0].strip() for l in seg.strip().splitlines() if "=" in l]
check(len(autoloads) == AUTOLOAD_EXPECTED,
      f"project.godot autoload 仍为 {AUTOLOAD_EXPECTED} 条", f"实得 {len(autoloads)}: {autoloads}")
check(not any("echo" in a.lower() or "memory" in a.lower() for a in autoloads),
      "无 MemoryEcho 类新 Autoload", str(autoloads))
check(not list(SCRIPTS.glob("*Echo*.gd")) and not list(SCRIPTS.glob("*Memory*.gd")),
      "scripts/ 无新增记忆回响脚本文件（逻辑寄居 CollectionManager）")

# ── I. 缩进一致性（⑧）─────────────────────────────────────────
section("I. 缩进一致性  (⑧ 防 GDScript mixed tabs and spaces)")
for path, style in [(COLL, "tab"), (MAIN, "space"), (DLG, "space")]:
    lines = path.read_text(encoding="utf-8").split("\n")
    tab_l = [i + 1 for i, l in enumerate(lines) if l.startswith("\t")]
    sp_l = [i + 1 for i, l in enumerate(lines) if l.startswith(" ")]
    if style == "tab":
        check(not sp_l, f"{path.name} 全 tab 缩进，无空格缩进行", f"空格行 {sp_l[:8]}")
    else:
        check(not tab_l, f"{path.name} 全空格缩进，无 tab 缩进行", f"tab 行 {tab_l[:8]}")
        bad4 = [i + 1 for i, l in enumerate(lines)
                if l.startswith(" ") and (len(l) - len(l.lstrip(" "))) % 4 != 0]
        check(not bad4, f"{path.name} 缩进均为 4 的倍数", f"异常行 {bad4[:8]}")
    mixed = [i + 1 for i, l in enumerate(lines) if re.match(r"^[ ]+\t|^\t+ ", l)]
    check(not mixed, f"{path.name} 无 tab/空格混用行", str(mixed[:8]))

# ── J. 常量算术与可达性（T-11 / T-12 / S-3）────────────────────
section("J. 常量算术与可达性  (T-11/T-12/S-3)")
C = {k: gd_const_int(coll_src, k) for k in [
    "ECHO_MATURE_DAYS", "ECHO_MEM_COOLDOWN_DAYS", "ECHO_GLOBAL_GAP_DAYS",
    "ECHO_GLOBAL_GAP_FINALE", "ECHO_PER_MEM_CAP", "ECHO_TOTAL_CAP",
    "ECHO_FINALE_BONUS", "ECHO_FINALE_DAY", "ECHO_LAST_NIGHT_DAY"]}
print(f"  [info] {C}")
expected_consts = {"ECHO_MATURE_DAYS": 30, "ECHO_MEM_COOLDOWN_DAYS": 60, "ECHO_GLOBAL_GAP_DAYS": 14,
                   "ECHO_GLOBAL_GAP_FINALE": 5, "ECHO_PER_MEM_CAP": 2, "ECHO_TOTAL_CAP": 8,
                   "ECHO_FINALE_BONUS": 2, "ECHO_FINALE_DAY": 540, "ECHO_LAST_NIGHT_DAY": 569}
check(C == expected_consts, "9 个调参常量取值 == GDD §5.1", str({k: v for k, v in C.items()
                                                                if expected_consts[k] != v}))
check(re.search(r"^const ECHO_BG_TINT", coll_src, re.M) is not None,
      "ECHO_BG_TINT 常量已定义备用（P1 未接线）")
check(C["ECHO_TOTAL_CAP"] + C["ECHO_FINALE_BONUS"] <= 10, "TOTAL_CAP + FINALE_BONUS <= 10（S-3 硬顶）")
check(C["ECHO_GLOBAL_GAP_FINALE"] >= 5, "终章全局间隔 >= 5 天")
check(C["ECHO_MEM_COOLDOWN_DAYS"] >= 2 * C["ECHO_GLOBAL_GAP_DAYS"], "单条冷却 >= 2 × 全局冷却")
unreachable = {s: int(BREAKS[s][1]) + C["ECHO_MATURE_DAYS"] for s in BREAKS
               if int(BREAKS[s][1]) + C["ECHO_MATURE_DAYS"] >= C["ECHO_LAST_NIGHT_DAY"]}
check(not unreachable, "四季记忆均可成熟：born + 30 < 569（T-12，无死分支）", str(unreachable))
# 单周目回响次数上限：常态窗口 + 终章窗口 + 毕业前夜特例
normal = (C["ECHO_FINALE_DAY"] - 1 - (min(int(b[1]) for b in BREAKS.values()) + C["ECHO_MATURE_DAYS"])) \
    // C["ECHO_GLOBAL_GAP_DAYS"]
finale_slots = (C["ECHO_LAST_NIGHT_DAY"] - 1 - C["ECHO_FINALE_DAY"]) // C["ECHO_GLOBAL_GAP_FINALE"]
cap_bound = C["ECHO_TOTAL_CAP"] + C["ECHO_FINALE_BONUS"] + 1
check(cap_bound <= 11, f"单周目回响次数上限 = {cap_bound} <= 11（含毕业前夜特例 1 次）")
print(f"  [info] 冷却窗口机会数：常态 {normal} 次 / 终章 {finale_slots} 次 → 实际被配额 {cap_bound} 封顶")

# ── K. 只读边界（S-8 / §3.5）──────────────────────────────────
section("K. 只读边界 —— 不碰画廊 / 集章 / toast  (S-8/§3.5)")
echo_code = strip_comments(ECHO_SRC)
check("unlock_gallery" not in echo_code, "记忆回响区不调用 unlock_gallery（画廊只读）")
check("show_toast" not in echo_code, "记忆回响区不 emit show_toast（GDD §3.5：全屏 CG 已是最强通知）")
check("stamp_" not in echo_code, "记忆回响区不读写任何 stamp_* 键")
check("night_chat" not in echo_code, "记忆回响区不碰 night_chat_* 键")
check(re.search(r'set_flag\(\s*"holiday_memory', echo_code) is None
      and re.search(r'set_flag\(\s*"seen_', echo_code) is None,
      "不写 holiday_memory_* / seen_* 键（仅 flags.has 只读）")
check("add_favor" not in echo_code and "add_stat" not in echo_code and "add_item" not in echo_code,
      "零机制产出：不加好感 / 不加属性 / 不给物品（GDD §3.5）")
check("add_log" in echo_code and "add_diary_entry" in echo_code,
      "保留 GDD §3.5 的两条纯记录痕迹：add_log + add_diary_entry")

# ═════════════════════════════════════════════════════════════════
print("\n" + "=" * 78)
if failures:
    print(f"结果：FAIL —— {len(failures)}/{_n} 条断言未通过")
    for f in failures:
        print("  - " + f)
    sys.exit(1)
print(f"结果：PASS —— {_n}/{_n} 条断言全部通过")
sys.exit(0)
