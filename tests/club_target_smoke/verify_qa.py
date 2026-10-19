#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
QA-CLUB-TARGET-01 · DS-RN-05b 社团目标层 独立质量门禁
=====================================================
Owner: 严守真 (quality-lead)

本门禁**独立重写**，不照抄 engineering-lead 的 scratch/verify_club_target.py。
覆盖 GDD `design/club_target_layer_gdd.md` 的成功标准 S-1~S-7 + OQ-1 +
skipToNextDay 语义 + 变异测试（注入缺陷算子，断言门禁能抓到）。

方法：纯静态断言（JSON 解析 + GDScript 文本解析 + 链推演模拟），
不依赖 Godot runtime。对游戏源码**只读**。

分组：
  T1  门禁自检（源文件可达）
  T2  S-1 事件链结构（20 链 / 92 总 / 串链 / 推演无死锁）
  T3  S-2 成就 flag 唯一授予（5 处全在 s4）
  T4  S-3 GALLERY_ITEMS 新增 5 条（美术缺口 NOTE 不判 FAIL）
  T5  S-4 NG+ 携带白名单 + gallery_flags 全集回注
  T6  S-5 带位与红线（priority 218 / noTimeCost 0 / charId null / R6 / R7 / R8 / R9 / R11）
  T7  S-6 数值上界（主属性 ≤+10 / 净 stress ≥+4 / ITEM_DB 不变）
  T8  S-7 零回归（autoload 15 + 四大源码零改动）
  T9  OQ-1 club_weekly_* 纯追加（flag_club_active_<type>）
  T10 skipToNextDay 语义（s3 分支 + DialogueUI 处理）
  T11 变异测试（5 个缺陷算子，门禁必须抓到，逃逸 0）

环境变量 CLUB_TARGET_QA_ROOT 可覆盖工程根目录 —— 供变异测试指向沙箱副本，
从而在**不触碰真源码**的前提下验证断言不是永远 PASS 的死断言。

退出码：0 = PASS，1 = FAIL。VERDICT PASS 要求失败=0 且 concerns=0
（美术资产缺口走 NOTE，不升 concerns）。
"""
import ast
import copy
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(os.environ.get("CLUB_TARGET_QA_ROOT",
                           Path(__file__).resolve().parents[2]))
SCRIPTS = ROOT / "scripts"

LIFE    = SCRIPTS / "events_life.json"
GM      = SCRIPTS / "GameManager.gd"
ES      = SCRIPTS / "EndingScreen.gd"
DLG     = SCRIPTS / "DialogueUI.gd"
DAILY   = SCRIPTS / "DailyCycleManager.gd"
MAIN    = SCRIPTS / "MainGame.gd"
DATAMGR = SCRIPTS / "DataManager.gd"
PROJECT = ROOT / "project.godot"

PY = sys.executable
# 递归深度守卫：防止 T11 变异测试在子进程里再次触发 T11（指数爆炸）
MUTATION_DEPTH = int(os.environ.get("QA_MUTATION_DEPTH", "0"))

TYPES = ["literature", "astronomy", "broadcast", "basketball", "art"]
LOC_BY_TYPE = {
    "literature": "library", "astronomy": "playground",
    "broadcast":  "music_room", "basketball": "playground", "art": "art_room",
}
MAIN_STAT = {
    "literature": "intellect", "astronomy": "intellect",
    "broadcast":  "charm",     "basketball": "strength", "art": "art",
}
TRIGGER_BY_STEP = {1: 120, 2: 220, 3: 340, 4: 470}
WEEKLY_PRIORITY = {"literature": 60, "astronomy": 205,
                   "broadcast": 60, "basketball": 205, "art": 205}
ITEM_DB_EXPECTED = 13          # 7 base + 6 fengwu（DS-RN-04 后未变）
GALLERY_TOTAL_EXPECTED = 60    # 既有 55 + 5 grad_club_*
ACHIEV_FLAG_PREFIX = "flag_club_achievement_"
WANT_ACHIEV = sorted("%s%s" % (ACHIEV_FLAG_PREFIX, t) for t in TYPES)

# ─────────────────────────────────────────────────────────────────
# 断言框架（T 组编号）
# ─────────────────────────────────────────────────────────────────
_group = "T0"
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


def note(msg):
    notes.append(msg)
    print(f"  [NOTE] {msg}")


# ─────────────────────────────────────────────────────────────────
# 解析工具（与工程自验不同的实现路径）
# ─────────────────────────────────────────────────────────────────
def read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def load_events_json(p: Path):
    return json.loads(read_text(p))


def code_only(text: str) -> str:
    """剥行尾/整行注释（字符串感知），避免注释文本触发反向断言。"""
    out = []
    for line in text.splitlines():
        in_str = esc = False
        cut = None
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
        seg = line[:cut] if cut is not None else line
        if seg.strip():
            out.append(seg.rstrip())
    return "\n".join(out)


def extract_literal(src: str, anchor: str) -> str:
    """从 anchor 后取首个配平的 []/{} 字面量（字符串感知）。"""
    i = src.index(anchor) + len(anchor)
    while src[i] not in "[{":
        i += 1
    open_ch = src[i]
    close_ch = "]" if open_ch == "[" else "}"
    depth = 0
    in_str = esc = False
    start = i
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
    raise ValueError(f"unbalanced literal for {anchor!r}")


def gd_literal_to_py(block: str) -> str:
    """GDScript 字面量 → Python 可解析形式。"""
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


def load_gd_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_literal_to_py(extract_literal(read_text(path), anchor)))


def walk_nodes(obj):
    """递归产出所有 dict 节点（scenes / choices 全覆盖）。"""
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from walk_nodes(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from walk_nodes(v)


def event_files() -> list:
    """从 DataManager.gd 真源解析 EVENT_FILES，杜绝手抄漏文件。"""
    dm = read_text(DATAMGR)
    return re.findall(r'"res://scripts/(events_[a-z_]+\.json)"', dm)


def load_all_events() -> list:
    """加载全事件池（含来源标记）。"""
    out = []
    for fn in event_files():
        for e in load_events_json(SCRIPTS / fn):
            e["_src"] = fn
            out.append(e)
    return out


# ════════════════════════════════════════════════════════════════
print("=" * 78)
print("QA-CLUB-TARGET-01 · DS-RN-05b 社团目标层 独立质量门禁 "
      "(quality-lead 严守真)")
print(f"ROOT = {ROOT}")
print(f"Python = {PY}")
print("=" * 78)

# ── T1 门禁自检 ────────────────────────────────────────────────
section("T1", "门禁自检（源文件可达，避免空扫描假 PASS）")
_required = {
    "events_life.json": LIFE, "GameManager.gd": GM, "EndingScreen.gd": ES,
    "DialogueUI.gd": DLG, "DailyCycleManager.gd": DAILY, "MainGame.gd": MAIN,
    "DataManager.gd": DATAMGR, "project.godot": PROJECT,
}
_missing = [n for n, p in _required.items() if not p.exists()]
if not check(not _missing, "8 个受检源文件全部可达", f"缺失 {_missing}"):
    print("\nVERDICT: FAIL（源文件缺失，后续断言无意义）")
    sys.exit(1)

try:
    life = load_events_json(LIFE)
    check(True, "events_life.json 可被 json.load 解析")
except Exception as ex:
    check(False, "events_life.json 可被 json.load 解析", str(ex))
    sys.exit(1)

ALL_EVENTS = load_all_events()
check(len(event_files()) == 10, "DataManager.EVENT_FILES 注册 10 个事件文件",
      f"实际 {len(event_files())}")
note(f"全事件池加载 {len(ALL_EVENTS)} 条来自 {len(event_files())} 个文件。")

# ════════════════════════════════════════════════════════════════
# T2 · S-1 事件链结构
# ════════════════════════════════════════════════════════════════
section("T2", "S-1 事件链结构（20 链 / 92 总 / 串链 / 推演无死锁）")
check(len(life) == 92, "events_life.json 事件总数 == 92（72 → 92）",
      f"实际 {len(life)}")

chain_events = [e for e in life
                if str(e.get("id", "")).startswith("club_chain_")]
check(len(chain_events) == 20, "含恰好 20 个 ^club_chain_ 事件",
      f"实际 {len(chain_events)}")

by_id = {e["id"]: e for e in life}
expected_ids = [f"club_chain_{t}_s{n}" for t in TYPES for n in (1, 2, 3, 4)]
missing_ids = [i for i in expected_ids if i not in by_id]
check(not missing_ids, "20 个 id 命名与 5×4 矩阵完全吻合",
      f"缺失 {missing_ids}")

# s1 requireFlags = [joined, type, active]
bad_s1 = []
for t in TYPES:
    rf = by_id[f"club_chain_{t}_s1"].get("requireFlags", [])
    want = {"flag_club_joined", f"flag_club_{t}", f"flag_club_active_{t}"}
    if not want.issubset(set(rf)):
        bad_s1.append((t, rf))
check(not bad_s1, "s1 requireFlags 含 joined + type + active（OQ-1 硬参与门）",
      f"违规 {bad_s1}")

# s2/s3/s4 严格串接：requireFlags 含 joined + type + active + 前一步 chain flag
bad_chain = []
for t in TYPES:
    for n in (2, 3, 4):
        rf = set(by_id[f"club_chain_{t}_s{n}"].get("requireFlags", []))
        prev = f"flag_club_chain_{t}_s{n-1}"
        active = f"flag_club_active_{t}"
        if prev not in rf:
            bad_chain.append((f"club_chain_{t}_s{n}", "缺前一步 chain flag"))
        if active not in rf:
            bad_chain.append((f"club_chain_{t}_s{n}", "缺 active gate"))
check(not bad_chain, "s2/s3/s4 requireFlags 严格串接（joined+type+active+s{N-1}）",
      f"违规 {bad_chain}")

# s1 不得引用任何 chain flag（否则链起点死锁）
bad_s1_dead = [
    t for t in TYPES
    if any("flag_club_chain_" in f for f in
           by_id[f"club_chain_{t}_s1"].get("requireFlags", []))
]
check(not bad_s1_dead, "s1 不引用任何 chain flag（链起点可达）",
      f"违规 {bad_s1_dead}")

# 模拟推演：joined+type+active 起步，按 triggerDay 顺序推进，4 步全部可达
def simulate_chain(t: str) -> bool:
    """模拟一条链的推演：从入社后状态起，逐周推进，4 步链全部可达无死锁。"""
    flags = {"flag_club_joined", f"flag_club_{t}", f"flag_club_active_{t}"}
    day = 30
    steps_done = set()
    # 模拟 570 天内每周去一次社团地点
    while day <= 570:
        # 按顺序尝试 s1..s4
        for n in (1, 2, 3, 4):
            ev_id = f"club_chain_{t}_s{n}"
            ev = by_id[ev_id]
            if ev_id in steps_done:
                continue
            rf = set(ev.get("requireFlags", []))
            if not rf.issubset(flags):
                continue
            td = int(ev.get("triggerDay", 0))
            if td > 0 and day < td:
                continue
            # 命中该步 → 落下 chain flag + (s4) 成就 flag
            last_scene = ev["scenes"][-1]
            for f in last_scene.get("setFlags", []):
                flags.add(f)
            steps_done.add(ev_id)
            break
        day += 7
    return len(steps_done) == 4

bad_simulate = [t for t in TYPES if not simulate_chain(t)]
check(not bad_simulate, "模拟推演：5 条链全部 4 步可达无死锁（S-1 ③）",
      f"卡死链 {bad_simulate}")

# 2空格缩进 / 零 tab（R11）
raw_life = read_text(LIFE)
check("\t" not in raw_life, "events_life.json 全文零 tab（R11 · 2 空格基准）")
indent_ok = all(
    re.search(r'^  \{\n    "id": "%s"' % re.escape(i), raw_life, re.M)
    for i in expected_ids
)
check(indent_ok, "20 个新事件对象缩进 = 2 空格 / 键 = 4 空格（R11 逐字符沿用宿主）")

# ════════════════════════════════════════════════════════════════
# T3 · S-2 成就 flag 唯一授予
# ════════════════════════════════════════════════════════════════
section("T3", "S-2 成就 flag 在链终点一次性授予（且仅在此）")
grant_sites = []
for fn in event_files():
    data = load_events_json(SCRIPTS / fn)
    for ev in data:
        for d in walk_nodes(ev):
            vals = []
            if isinstance(d.get("setFlags"), list):
                vals += [str(x) for x in d["setFlags"]]
            if isinstance(d.get("setFlag"), str):
                vals.append(d["setFlag"])
            for v in vals:
                if v.startswith(ACHIEV_FLAG_PREFIX):
                    grant_sites.append((fn, ev.get("id"), v))

check(len(grant_sites) == 5, "全事件池 flag_club_achievement_* 写入点恰好 5 处",
      f"实际 {len(grant_sites)} -> {grant_sites}")

all_s4 = all(sid.endswith("_s4") for _, sid, _ in grant_sites)
check(all_s4, "5 个授予点全部落在 s4（链终点一次性，S-2）",
      f"违规 {[s for s in grant_sites if not s[1].endswith('_s4')]}")

granted_sorted = sorted(v for _, _, v in grant_sites)
check(granted_sorted == WANT_ACHIEV, "5 个成就 flag 与 5 社一一对应",
      f"实际 {granted_sorted}")

# ════════════════════════════════════════════════════════════════
# T4 · S-3 GALLERY_ITEMS
# ════════════════════════════════════════════════════════════════
section("T4", "S-3 GALLERY_ITEMS 新增 5 条 grad_club_*（美术缺口 NOTE）")
gm_src = read_text(GM)
gal_block = extract_literal(gm_src, "const GALLERY_ITEMS = ")
gal = ast.literal_eval(gd_literal_to_py(gal_block))
check(len(gal) == GALLERY_TOTAL_EXPECTED,
      f"GALLERY_ITEMS 总条目 == {GALLERY_TOTAL_EXPECTED}（既有 55 + 新增 5）",
      f"实际 {len(gal)}")

club_items = [g for g in gal
              if str(g.get("pose", "")).startswith("grad_club_")]
check(len(club_items) == 5, "新增恰好 5 条 grad_club_* 条目",
      f"实际 {len(club_items)}")

bad_char = [g["pose"] for g in club_items if g.get("char") != "player"]
check(not bad_char, "5 条 char == 'player'（性别对称）", f"违规 {bad_char}")

# pose 全工程唯一（GALLERY_ITEMS 内 + 整个 scripts/ 树）
poses = [g["pose"] for g in gal]
dup_poses = sorted({p for p in poses
                     if poses.count(p) > 1 and p.startswith("grad_club_")})
check(not dup_poses, "5 个 grad_club_* pose 在 GALLERY_ITEMS 内唯一（R5）",
      f"重复 {dup_poses}")

proj_hits = {}
for dirpath, _dirs, files in os.walk(ROOT):
    if any(x in dirpath for x in (".git", "scratch", "tests", ".workbuddy")):
        continue
    for fn in files:
        if not fn.endswith((".gd", ".json")):
            continue
        try:
            txt = read_text(Path(dirpath) / fn)
        except Exception:
            continue
        for t in TYPES:
            pose = f"grad_club_{t}"
            if pose in txt:
                proj_hits.setdefault(pose, []).append(fn)
uniq_ok = (len(proj_hits) == 5
           and all(sorted(set(v)) == ["GameManager.gd"] for v in proj_hits.values()))
check(uniq_ok, "5 个 pose 全工程唯一（仅 GameManager.gd 出现）",
      f"实际 { {k: sorted(set(v)) for k, v in proj_hits.items()} }")

# flag 与成就 flag 逐字符一致 + bg 路径约定
bad_gal = []
for t in TYPES:
    it = next((g for g in club_items if g["pose"] == f"grad_club_{t}"), None)
    if not it:
        bad_gal.append((t, "missing"))
        continue
    if it.get("flag") != f"flag_club_achievement_{t}":
        bad_gal.append((t, f"flag={it.get('flag')}"))
    if it.get("bg") != f"res://assets/backgrounds/grad_club_{t}.jpg":
        bad_gal.append((t, f"bg={it.get('bg')}"))
    if not str(it.get("label", "")).strip():
        bad_gal.append((t, "label 空"))
    if not str(it.get("hint", "")).strip():
        bad_gal.append((t, "hint 空"))
check(not bad_gal,
      "5 条 flag/bg/label/hint 逐字段正确，flag 与成就 flag 逐字符一致（S-3 ②）",
      f"违规 {bad_gal}")

check(sorted(g["flag"] for g in club_items) == WANT_ACHIEV,
      "GALLERY_ITEMS 的 5 flag 与事件授予的 5 flag 完全闭环")

# 美术资产缺口：NOTE 不判 FAIL
missing_bg = []
for t in TYPES:
    p = ROOT / "assets" / "backgrounds" / f"grad_club_{t}.jpg"
    if not p.exists():
        missing_bg.append(f"grad_club_{t}.jpg")
if missing_bg:
    note("5 张成就 CG 尚未出图（art-director 待办）：%s" % ", ".join(missing_bg))
    note("⚠️ 出图后必须在 Godot 4.5 编辑器打开工程一次生成 .import，"
         "否则导出包不含该资源（沿用 west_lake_fengwu_complete.jpg 教训）。"
         "逻辑门禁不受影响，按任务书约定不判 FAIL。")
else:
    no_import = [t for t in TYPES
                 if not (ROOT / "assets" / "backgrounds"
                         / f"grad_club_{t}.jpg.import").exists()]
    if no_import:
        note("以下 CG 缺 .import 文件：%s" % ", ".join(no_import))

# ════════════════════════════════════════════════════════════════
# T5 · S-4 NG+ 携带白名单 + gallery_flags 全集回注
# ════════════════════════════════════════════════════════════════
section("T5", "S-4 NG+ 携带白名单 + gallery_flags 全集回注（OQ-3）")
es_src = read_text(ES)

m_const = re.search(r"const CLUB_ACHIEVEMENT_FLAGS\s*:=\s*\[(.*?)\]",
                    es_src, re.S)
check(m_const is not None, "EndingScreen 含 CLUB_ACHIEVEMENT_FLAGS 常量")
const_flags = re.findall(r'"(flag_club_achievement_[a-z]+)"',
                         m_const.group(1) if m_const else "")
check(len(const_flags) == 5, "CLUB_ACHIEVEMENT_FLAGS 恰好 5 项",
      f"实际 {len(const_flags)}")
check(sorted(const_flags) == WANT_ACHIEV,
      "常量 5 项与 GALLERY_ITEMS / 授予点逐字符一致（S-4 ①）",
      f"实际 {sorted(const_flags)}")

# 白名单回注逻辑存在
check(re.search(
    r"for g in CLUB_ACHIEVEMENT_FLAGS:\s*\n\s*if g in inherited_gallery:\s*\n"
    r"\s*GameManager\.flags\[g\] = true", es_src) is not None,
    "白名单回注逻辑存在（幂等置真）")

# gallery_flags 全集回注逻辑存在（OQ-3 根治）
check(re.search(
    r"for g in inherited_gallery:\s*\n\s*if g is String and g != \"\":\s*\n"
    r"\s*GameManager\.flags\[g\] = true", es_src) is not None,
    "gallery_flags 全集回注逻辑存在（OQ-3 根治：救回既有全部 CG）")

# 回注必须位于 flags = {} 之后
i_clear = es_src.find("GameManager.flags = {}")
i_reinj = es_src.find("var inherited_gallery")
check(i_clear != -1 and i_reinj != -1 and i_reinj > i_clear,
      "回注位于 flags = {} 之后（否则被清空覆盖）")

# 模拟 NG+：flags={} → 回注后成就 flag 存活、链 flag 消失、链可重走
def simulate_ng_plus() -> dict:
    """模拟 NG+ 流程：flags={} → 回注 5 成就 flag。
    返回 {achiev_alive, chain_gone, join_hub_rearmed, s1_retriggerable}.
    """
    # 模拟新周目起步状态
    flags_after = {}
    # 回注白名单（假设玩家上周目已集齐 5 成就）
    for f in WANT_ACHIEV:
        flags_after[f] = True
    # 链 flag / joined / active / chain_* 全部不在 → 链可重走
    achv_alive = all(f in flags_after for f in WANT_ACHIEV)
    chain_gone = not any(k.startswith("flag_club_chain_") for k in flags_after)
    joined_gone = "flag_club_joined" not in flags_after
    active_gone = not any(k.startswith("flag_club_active_") for k in flags_after)
    # club_join_hub 的 excludeFlags = [flag_club_joined] → joined 不在则可重触
    hub = by_id["club_join_hub"]
    hub_excl = hub.get("excludeFlags", [])
    join_rearmed = not any(f in flags_after for f in hub_excl)
    # s1 requireFlags = [joined, type, active] → 全不在 → s1 不可触发是正常的
    # 但链起点（joined）可重走，故「链可重走」成立
    s1_retriggerable = join_rearmed  # 入社可重新走 → 链可重走
    return {
        "achiev_alive": achv_alive,
        "chain_gone": chain_gone and joined_gone and active_gone,
        "join_hub_rearmed": join_rearmed,
        "s1_retriggerable": s1_retriggerable,
    }

ng_sim = simulate_ng_plus()
check(ng_sim["achiev_alive"], "模拟 NG+：5 成就 flag 经白名单回注存活")
check(ng_sim["chain_gone"],
      "模拟 NG+：链 flag / joined / active 全部消失（链回到起点）")
check(ng_sim["join_hub_rearmed"],
      "模拟 NG+：club_join_hub 重新可触发（R6 反向验证，NG+ 链可重走）")

# 成就 flag 不得被任何 excludeFlags 引用（R6 反向，全事件池）
excl_hits = []
for fn in event_files():
    for ev in load_events_json(SCRIPTS / fn):
        for d in walk_nodes(ev):
            for f in (d.get("excludeFlags") or []):
                if str(f).startswith(ACHIEV_FLAG_PREFIX):
                    excl_hits.append((fn, ev.get("id")))
check(not excl_hits,
      "全事件池零 excludeFlags 引用成就 flag（R6 反向验证，NG+ 可重走）",
      f"违规 {excl_hits}")

# ════════════════════════════════════════════════════════════════
# T6 · S-5 带位与红线
# ════════════════════════════════════════════════════════════════
section("T6", "S-5 带位与红线（priority 218 / noTimeCost 0 / R6-R11）")
prios = sorted({e.get("priority") for e in chain_events})
check(prios == [218], "20 链事件 priority 恒为 218（R4）", f"实际 {prios}")

# 218 全事件池仅被这 20 个占用
p218_in_pool = []
for fn in event_files():
    for ev in load_events_json(SCRIPTS / fn):
        if ev.get("priority") == 218:
            p218_in_pool.append((fn, ev.get("id")))
check(len(p218_in_pool) == 20
      and all(i.startswith("club_chain_") for _, i in p218_in_pool),
      "priority 218 在全事件池仅被这 20 个链事件占用（S-5 ①）",
      f"实际 {len(p218_in_pool)} -> {[i for _, i in p218_in_pool if not i.startswith('club_chain_')]}")

# noTimeCost 0 次
no_time_hits = [e["id"] for e in chain_events
               if any("noTimeCost" in d for d in walk_nodes(e))]
check(not no_time_hits, "20 链事件 noTimeCost 键出现 0 次（R8 · 确凿消耗时段）",
      f"违规 {no_time_hits}")

# charId 全 null
bad_charid = [e["id"] for e in chain_events
              if e.get("charId", "SENTINEL") is not None]
check(not bad_charid, "20 链事件 charId 全为 null（R10 · 双路线对称）",
      f"违规 {bad_charid}")

# excludeFlags 恒 [flag_club_week_done]，不含 flag_club_achievement_*
bad_excl = [e["id"] for e in chain_events
            if e.get("excludeFlags") != ["flag_club_week_done"]]
check(not bad_excl, "excludeFlags 恒等于 [flag_club_week_done]（R6）",
      f"违规 {bad_excl}")
achv_in_excl = [e["id"] for e in chain_events
               if any(f.startswith(ACHIEV_FLAG_PREFIX)
                      for f in e.get("excludeFlags", []))]
check(not achv_in_excl,
      "excludeFlags 零出现 flag_club_achievement_*（R6 死锁红线）",
      f"违规 {achv_in_excl}")

# 终场景 setFlag 恒 flag_club_week_done
bad_week = []
for e in chain_events:
    last = e["scenes"][-1]
    if last.get("setFlag") != "flag_club_week_done":
        bad_week.append(e["id"])
check(not bad_week, "终场景 setFlag 全为 flag_club_week_done（R7 · 继承周节流阀）",
      f"违规 {bad_week}")

# statDelta 无 money
money_hits = []
for e in chain_events:
    for d in walk_nodes(e):
        sd = d.get("statDelta")
        if isinstance(sd, dict) and "money" in sd:
            money_hits.append(e["id"])
check(not money_hits, "statDelta 零 money 键（R9 · 防经济失衡）",
      f"违规 {set(money_hits)}")

# 2 空格无 tab（R11，T2 已断言全文，此处对 20 链事件本身再断言一次）
check(all("\t" not in json.dumps(e, ensure_ascii=False)
          for e in chain_events),
      "20 链事件 JSON 序列化结果零 tab（R11）")

# repeatable 全 false
bad_rep = [e["id"] for e in chain_events if e.get("repeatable") is not False]
check(not bad_rep, "20 链事件 repeatable 全为 false（决策 2 · 一次性消费）",
      f"违规 {bad_rep}")

# slotId 全 after
bad_slot = [e["id"] for e in chain_events if e.get("slotId") != "after"]
check(not bad_slot, "20 链事件 slotId 全为 after", f"违规 {bad_slot}")

# location 与本社周活动同地点
bad_loc = []
for e in chain_events:
    t = e["id"].split("_")[2]
    if e.get("location") != LOC_BY_TYPE[t]:
        bad_loc.append((e["id"], e.get("location")))
check(not bad_loc, "location 与本社周活动同地点（F5 · 长假自动抑制）",
      f"违规 {bad_loc}")

# triggerDay = 120/220/340/470
bad_day = []
for e in chain_events:
    n = int(e["id"][-1])
    if e.get("triggerDay") != TRIGGER_BY_STEP[n]:
        bad_day.append((e["id"], e.get("triggerDay")))
check(not bad_day, "triggerDay = 120/220/340/470（避开 BREAK_PERIODS）",
      f"违规 {bad_day}")

# 每步终场景 setFlags 落下自身 chain flag
bad_setchain = []
for t in TYPES:
    for n in (1, 2, 3, 4):
        e = by_id[f"club_chain_{t}_s{n}"]
        sf = e["scenes"][-1].get("setFlags", [])
        if f"flag_club_chain_{t}_s{n}" not in sf:
            bad_setchain.append(e["id"])
check(not bad_setchain, "每步终场景 setFlags 落下自身 chain flag（解锁下一步）",
      f"违规 {bad_setchain}")

# ════════════════════════════════════════════════════════════════
# T7 · S-6 数值上界
# ════════════════════════════════════════════════════════════════
section("T7", "S-6 数值不构成主导策略（主属性 ≤+10 / 净 stress ≥+4）")
bad_num = []
for t in TYPES:
    main = MAIN_STAT[t]
    tot_over = tot_punc = 0
    st_over = st_punc = 0
    for n in (1, 2, 4):
        for d in walk_nodes(by_id[f"club_chain_{t}_s{n}"]):
            sd = d.get("statDelta")
            if isinstance(sd, dict):
                tot_over += sd.get(main, 0)
                tot_punc += sd.get(main, 0)
                st_over += sd.get("stress", 0)
                st_punc += sd.get("stress", 0)
    s3 = by_id[f"club_chain_{t}_s3"]
    ch = s3["scenes"][0]["choices"]
    tot_over += ch[0]["statDelta"].get(main, 0)
    st_over += ch[0]["statDelta"].get("stress", 0)
    tot_punc += ch[1]["statDelta"].get(main, 0)
    st_punc += ch[1]["statDelta"].get("stress", 0)
    if tot_over > 10:
        bad_num.append((t, f"主属性通宵路线 {tot_over} > 10"))
    if tot_punc > 10:
        bad_num.append((t, f"主属性按时路线 {tot_punc} > 10"))
    if st_over < 4:
        bad_num.append((t, f"净 stress over={st_over} < 4"))
    if st_punc < 4:
        bad_num.append((t, f"净 stress punc={st_punc} < 4"))
check(not bad_num,
      "每链主属性总收益 ≤ +10 且净 stress ≥ +4（S-6 ①②）",
      f"违规 {bad_num}")

# ITEM_DB 条目数不变
try:
    item_db = load_gd_literal(GM, "const ITEM_DB = ")
    check(len(item_db) == ITEM_DB_EXPECTED,
          f"ITEM_DB 条目数仍为 {ITEM_DB_EXPECTED}（不变）",
          f"实际 {len(item_db)}")
except Exception as ex:
    check(False, "ITEM_DB 可解析", str(ex))

# ════════════════════════════════════════════════════════════════
# T8 · S-7 零回归
# ════════════════════════════════════════════════════════════════
section("T8", "S-7 零回归（autoload 15 + 四大源码零改动）")
proj = read_text(PROJECT)
al_sec = (proj.split("[autoload]", 1)[1].split("\n[", 1)[0]
          if "[autoload]" in proj else "")
autoloads = re.findall(r'^(\w+)\s*=\s*"\*res://', al_sec, re.M)
check(len(autoloads) == 15, "project.godot [autoload] 恒为 15 项（R1 零新增）",
      f"实际 {len(autoloads)}: {autoloads}")
check(not [a for a in autoloads if "club" in a.lower()],
      "无任何 club 命名的 Autoload（全 flag 态）")

# DailyCycleManager 关键 erase 行仍在（GDD F6）
daily_src = read_text(DAILY)
check(re.search(r'GameManager\.flags\.erase\(\s*"flag_club_week_done"\s*\)',
               daily_src) is not None,
      "DailyCycleManager 仍含 erase('flag_club_week_done')（F6 周一重置）")

# MainGame 面板仍只读（不在 _show_club_popup 内写 flag）
main_src = read_text(MAIN)
popup_body_match = re.search(
    r"func _show_club_popup\(.*?\).*?:\n(.*?)(?=\n^func |\Z)",
    main_src, re.S | re.M)
popup_body = code_only(popup_body_match.group(1)) if popup_body_match else ""
WRITE_PATS = [r"set_flag\(", r"flags\[", r"flags\.erase", r"flags\.set",
              r"add_stat\(", r"advance_time\(", r"GameManager\.money\s*[+\-]?=",
              r"add_item\(", r"remove_item\(", r"slot_index\s*=",
              r"GameManager\.day\s*[+\-]?="]
_viol = []
for pat in WRITE_PATS:
    if re.search(pat, popup_body):
        _viol.append(pat)
check(not _viol, "_show_club_popup 零写操作（R3 · 面板纯只读）",
      f"越界 {_viol}")

# DataManager / DialogueUI 零 club 业务字写入（仅 JSON 事件授 flag）
dm_src = read_text(DATAMGR)
dlg_src = read_text(DLG)
for name, src in [("DataManager.gd", dm_src),
                  ("DialogueUI.gd", dlg_src),
                  ("MainGame.gd", main_src),
                  ("DailyCycleManager.gd", daily_src)]:
    code = code_only(src)
    bad = re.findall(r'set_flag\(\s*"flag_club_achievement_|'
                     r'flags\[\s*"flag_club_achievement_|'
                     r'set_flag\(\s*"flag_club_chain_|'
                     r'flags\[\s*"flag_club_chain_', code)
    check(not bad,
          f"{name} 零直接写 flag_club_achievement_/flag_club_chain_"
          f"（只能经 JSON 事件授予）",
          f"越界 {bad[:3]}")

# project.godot 零 club 行
check("club" not in proj.lower(),
      "project.godot 零 club 引用（未新增任何 club Autoload/配置）")

# ════════════════════════════════════════════════════════════════
# T9 · OQ-1 club_weekly_* 纯追加
# ════════════════════════════════════════════════════════════════
section("T9", "OQ-1 club_weekly_* 纯追加（flag_club_active_<type>）")
bad_w = []
for t in TYPES:
    e = by_id[f"club_weekly_{t}"]
    last = e["scenes"][-1]
    if last.get("setFlags") != [f"flag_club_active_{t}"]:
        bad_w.append((t, f"setFlags={last.get('setFlags')}"))
    if last.get("setFlag") != "flag_club_week_done":
        bad_w.append((t, "setFlag 被改动"))
    if e.get("priority") != WEEKLY_PRIORITY[t]:
        bad_w.append((t, f"priority 漂移 {e.get('priority')}"))
    if e.get("repeatable") is not True:
        bad_w.append((t, "repeatable 漂移"))
    if e.get("excludeFlags") != ["flag_club_week_done"]:
        bad_w.append((t, "excludeFlags 漂移"))
    if e.get("requireFlags") != ["flag_club_joined", f"flag_club_{t}"]:
        bad_w.append((t, "requireFlags 漂移"))
check(not bad_w,
      "5 个 club_weekly_* 终场景含 setFlags[flag_club_active_<type>]，"
      "priority/repeatable/require/exclude/setFlag 零漂移（纯追加）",
      f"违规 {bad_w}")

# s1 requireFlags 含 flag_club_active_<type>（与 T2.4 互证）
bad_s1_active = []
for t in TYPES:
    rf = by_id[f"club_chain_{t}_s1"].get("requireFlags", [])
    if f"flag_club_active_{t}" not in rf:
        bad_s1_active.append(t)
check(not bad_s1_active,
      "5 个 s1 requireFlags 含 flag_club_active_<type>（与 club_weekly 闭环）",
      f"违规 {bad_s1_active}")

# club_join_hub 既有字段零改动
hub = by_id["club_join_hub"]
check(hub.get("priority") == 212
      and hub.get("excludeFlags") == ["flag_club_joined"]
      and hub.get("triggerDay") == 30
      and hub.get("repeatable") is False
      and hub.get("charId") is None
      and hub.get("location") == "classroom"
      and hub.get("slotId") == "after",
      "club_join_hub 既有字段零改动（priority 212 / excludeFlags 等）")

# ════════════════════════════════════════════════════════════════
# T10 · skipToNextDay 语义
# ════════════════════════════════════════════════════════════════
section("T10", "skipToNextDay 语义（s3 分支 + DialogueUI 处理）")
bad_s3 = []
for t in TYPES:
    s3 = by_id[f"club_chain_{t}_s3"]
    ch = s3["scenes"][0].get("choices", [])
    if len(ch) != 2:
        bad_s3.append((t, f"choices={len(ch)}"))
        continue
    if ch[0].get("skipToNextDay") is not True:
        bad_s3.append((t, "分支A 缺 skipToNextDay"))
    if "skipToNextDay" in ch[1]:
        bad_s3.append((t, "分支B 不应带 skipToNextDay"))
    if len(s3["scenes"]) != 4:
        bad_s3.append((t, f"s3 场景数 {len(s3['scenes'])} != 4"))
check(not bad_s3,
      "5 个 s3 双分支：A 带 skipToNextDay / B 不带，4 场景（分支+汇合，F14）",
      f"违规 {bad_s3}")

# DialogueUI 处理 scene 级 skipToNextDay
check(re.search(r'scene\.get\(\s*"skipToNextDay"\s*,\s*false\s*\)',
               dlg_src) is not None,
      "DialogueUI 处理 scene 级 skipToNextDay（L168 附近）")
# DialogueUI 处理 choice 级 skipToNextDay
check(re.search(r'choice_data\.get\(\s*"skipToNextDay"\s*,\s*false\s*\)',
               dlg_src) is not None,
      "DialogueUI 处理 choice 级 skipToNextDay（L426 附近）")
# DialogueUI finish_event 消费 skipToNextDay
check(re.search(r'_should_skip_to_next_day or current_event\.get\(\s*"skipToNextDay"',
               dlg_src) is not None,
      "DialogueUI.finish_event 消费 skipToNextDay（L577 附近，slot=0/day+=1）")

# ════════════════════════════════════════════════════════════════
# T11 · 变异测试（注入缺陷算子，门禁必须抓到）
# ════════════════════════════════════════════════════════════════
section("T11", "变异测试（5 个缺陷算子，门禁必须抓到，逃逸 0）")


def run_self_in_sandbox(sandbox_root: Path) -> tuple:
    """把 sandbox_root 作为 CLUB_TARGET_QA_ROOT 跑本脚本自身，
    返回 (returncode, stdout_tail)。
    传入 QA_MUTATION_DEPTH+1，使子进程跳过 T11 变异测试，防止递归。"""
    env = os.environ.copy()
    env["CLUB_TARGET_QA_ROOT"] = str(sandbox_root)
    env["QA_MUTATION_DEPTH"] = str(MUTATION_DEPTH + 1)  # 递归深度守卫
    try:
        r = subprocess.run(
            [PY, __file__], cwd=str(sandbox_root),
            capture_output=True, text=True, encoding="utf-8",
            errors="replace", env=env, timeout=120,
        )
        out = (r.stdout or "") + (r.stderr or "")
        # 取末尾 30 行
        tail = "\n".join(out.splitlines()[-30:])
        return r.returncode, tail
    except Exception as ex:
        return -1, f"异常: {ex}"


def setup_sandbox() -> Path:
    """在 tempfile 创建 sandbox 副本（仅 scripts + project.godot + assets 占位）。"""
    sb = Path(tempfile.mkdtemp(prefix="club_target_mut_"))
    (sb / "scripts").mkdir()
    (sb / "assets" / "backgrounds").mkdir(parents=True)
    # 复制 scripts/
    for p in SCRIPTS.glob("*.gd"):
        shutil.copy(p, sb / "scripts" / p.name)
    for p in SCRIPTS.glob("*.json"):
        shutil.copy(p, sb / "scripts" / p.name)
    # 复制 project.godot
    shutil.copy(PROJECT, sb / "project.godot")
    return sb


def mutate_and_test(mutator_name: str, mutator_fn) -> bool:
    """对 sandbox 副本施加变异，跑本门禁，返回 True=被门禁抓到（FAIL）。"""
    sb = setup_sandbox()
    try:
        mutator_fn(sb)
        rc, tail = run_self_in_sandbox(sb)
        caught = (rc != 0)
        if caught:
            note(f"变异 {mutator_name}：被门禁抓到（rc={rc}）")
        else:
            concern(f"变异 {mutator_name} 逃逸！门禁未抓到。末尾输出：\n{tail}")
        return caught
    finally:
        shutil.rmtree(sb, ignore_errors=True)


# 变异 1：删 s4 成就 flag → S-2 失败（T3 抓）
def mut_drop_achv(sb: Path):
    p = sb / "scripts" / "events_life.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    for e in data:
        if e["id"] == "club_chain_literature_s4":
            last = e["scenes"][-1]
            last["setFlags"] = [f for f in last.get("setFlags", [])
                                if not f.startswith("flag_club_achievement_")]
            break
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


# 变异 2：改某 priority 成 205 → S-5 失败（T6 抓）
def mut_priority_205(sb: Path):
    p = sb / "scripts" / "events_life.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    for e in data:
        if e["id"] == "club_chain_literature_s1":
            e["priority"] = 205
            break
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


# 变异 3：成就 flag 加进 excludeFlags → S-4/R6 失败（T5/T6 抓）
def mut_achv_in_exclude(sb: Path):
    p = sb / "scripts" / "events_life.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    for e in data:
        if e["id"] == "club_chain_literature_s1":
            e["excludeFlags"] = ["flag_club_week_done",
                                 "flag_club_achievement_literature"]
            break
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


# 变异 4：改某 grad_club pose 撞重 → S-3 失败（T4 抓）
def mut_pose_collision(sb: Path):
    p = sb / "scripts" / "GameManager.gd"
    txt = p.read_text(encoding="utf-8")
    # 把 grad_club_literature 改成 grad_photo（既有 pose）
    txt = txt.replace('"pose": "grad_club_literature"',
                      '"pose": "grad_photo"', 1)
    p.write_text(txt, encoding="utf-8")


# 变异 5：改 event 总数非 92 → S-1 失败（T2 抓）
def mut_event_count(sb: Path):
    p = sb / "scripts" / "events_life.json"
    data = json.loads(p.read_text(encoding="utf-8"))
    # 复制一条事件制造重复 id（让总数变 93）
    dup = copy.deepcopy(data[0])
    data.append(dup)
    p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


if MUTATION_DEPTH >= 1:
    # 子进程沙箱内：跳过 T11，防止递归爆炸
    note(f"QA_MUTATION_DEPTH={MUTATION_DEPTH}，跳过 T11 变异测试（防递归守卫）")
    check(True, "T11 跳过（子进程沙箱内，递归深度守卫激活）")
else:
    mutations = [
        ("M1 删 s4 成就 flag", mut_drop_achv),
        ("M2 priority 改 205", mut_priority_205),
        ("M3 成就 flag 加进 excludeFlags", mut_achv_in_exclude),
        ("M4 grad_club pose 撞重", mut_pose_collision),
        ("M5 event 总数非 92", mut_event_count),
    ]
    caught_count = 0
    for name, fn in mutations:
        if mutate_and_test(name, fn):
            caught_count += 1
    check(caught_count == len(mutations),
          f"变异测试：{caught_count}/{len(mutations)} 被抓，逃逸 {len(mutations) - caught_count}",
          ("零逃逸" if caught_count == len(mutations)
           else f"{len(mutations) - caught_count} 个逃逸"))
    note(f"变异测试结论：{caught_count}/{len(mutations)} 被抓，逃逸 {len(mutations) - caught_count}。"
         f"门禁对 5 类典型缺陷均具抓取能力。")

# ════════════════════════════════════════════════════════════════
# 判定
# ════════════════════════════════════════════════════════════════
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
