# -*- coding: utf-8 -*-
"""
QA-RN-03 — 西湖十景集章（DS-RN-03）独立逻辑级烟雾测试 / 质量门
Owner: 严守真 (quality-lead)
Independent of scratch/verify_west_lake_stamps.py — 重写实现，独立断言编号。

方法：纯静态断言（解析 .gd 文本 + json.load + 文件存在性 + 坐标计算），
      不依赖 Godot runtime。对游戏代码只读。

覆盖 design/west_lake_stamps_gdd.md §8-④ 的 T-1 ~ T-12，并额外扩展：
  A  注册表唯一真源（T-1 / S-5）
  B  与 WeatherManager.WEST_LAKE_SCENES 前四景一致性（T-2）
  C  浪漫事件终局 setFlags 含 stamp_*（T-3 / S-3）
  D  根级 setFlag 死数据清零 · 断桥残雪 bug 回归守卫（T-4）
  E  DialogueUI 场景级 setFlags 支持 + 零回归面（T-5）
  F  stamp_ 字面量跨文件无拼写漂移（T-6）
  G  GALLERY_ITEMS 条目 + CG 资产落盘（T-7）
  H  lakeside 热点 ↔ HotspotExploreUI 路由闭合（T-8）
  I  热点坐标间距（T-9）
  J  零新 Autoload（T-10 / S-4）
  K  stamp_ flag 单一写入源（T-11）
  L  StampBookUI 单向数据流（T-12）
  M  grant_stamp 幂等 + 集满原子语义（扩展）
  N  每日 1 章限速（扩展）
  O  MainGame 入口 + 补偿扫描调用链闭合（扩展）
  P  vignette 契约（扩展）
  Q  路线解耦：打卡路径零好感/角色门槛（S-1 / S-2）
  R  NG+ 语义 + 称号 flag 往返（扩展）
  S  缩进风格一致性（扩展，防 GDScript "mixed tabs and spaces" 解析错误）

退出码：0 = PASS / PASS-with-concerns，1 = FAIL。
"""
import ast
import io
import json
import math
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"

COLL     = SCRIPTS / "CollectionManager.gd"
WEATHER  = SCRIPTS / "WeatherManager.gd"
GM       = SCRIPTS / "GameManager.gd"
DLG      = SCRIPTS / "DialogueUI.gd"
HOTSPOT  = SCRIPTS / "HotspotExploreUI.gd"
STAMPUI  = SCRIPTS / "StampBookUI.gd"
MAIN     = SCRIPTS / "MainGame.gd"
LOCMGR   = SCRIPTS / "LocationManager.gd"
ENDING   = SCRIPTS / "EndingScreen.gd"
SAVESYS  = SCRIPTS / "SaveSystem.gd"
EV_SPEC  = SCRIPTS / "events_special.json"
PROJECT  = ROOT / "project.godot"

# GDD §1.2 —— 十景 sid 全集（顺序即集章簿格子顺序，不可排序）
EXPECTED_SIDS = [
    "sudichunxiao", "quyuanfenghe", "pinghuqiuyue", "duanqiaocanxue", "huagangguanyu",
    "liulangwenying", "leifengxizhao", "santanyinyue", "nanpingwanzhong", "shuangfengchayun",
]
# GDD §1.2 —— 浪漫事件 → sid 映射（路径 B）
ROMANCE_MAP = {
    "west_lake_spring_jingjing": "sudichunxiao",
    "west_lake_summer_yutong":   "quyuanfenghe",
    "west_lake_autumn_wanqing":  "pinghuqiuyue",
    "west_lake_winter_jingjing": "duanqiaocanxue",
}
# GDD §1.3 —— WeatherManager 季节键 → stamp sid（前四景一致性约束）
SEASON_TO_SID = {
    "spring": "sudichunxiao", "summer": "quyuanfenghe",
    "autumn": "pinghuqiuyue", "winter": "duanqiaocanxue",
}
AUTOLOAD_EXPECTED = 15   # 改动前基线（S-4：零新 Autoload）

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
# GDScript 字面量提取（字符串感知，# 注释仅在字符串外生效）
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
    text = re.sub(r"Vector2\(", "(", text)          # Vector2(x, y) -> (x, y)
    text = re.sub(r'Color\(\s*("([^"\\]|\\.)*")\s*\)', r"\1", text)
    return text


def load_literal(path: Path, anchor: str):
    return ast.literal_eval(gd_to_py(extract_block(path.read_text(encoding="utf-8"), anchor)))


def src_of(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def func_body(src: str, name: str) -> str:
    m = re.search(r"^func %s\(.*?\).*?:\n(.*?)(?=^func |\Z)" % re.escape(name),
                  src, re.S | re.M)
    return m.group(1) if m else ""


# ═════════════════════════════════════════════════════════════════
print("=" * 78)
print("QA-RN-03  西湖十景集章 · 独立逻辑级烟雾测试 / 质量门")
print(f"root = {ROOT}")
print("=" * 78)

coll_src   = src_of(COLL)
dlg_src    = src_of(DLG)
hot_src    = src_of(HOTSPOT)
ui_src     = src_of(STAMPUI)
main_src   = src_of(MAIN)
gm_src     = src_of(GM)
ending_src = src_of(ENDING)

SCENES      = load_literal(COLL, "const WEST_LAKE_STAMP_SCENES = ")
WEATHER_4   = load_literal(WEATHER, "const WEST_LAKE_SCENES = ")
GALLERY     = load_literal(GM, "GALLERY_ITEMS = ")
LAKESIDE    = load_literal(GM, '"lakeside": ')
EVENTS      = json.loads(EV_SPEC.read_text(encoding="utf-8"))
ALL_EVENT_FILES = sorted(SCRIPTS.glob("events*.json"))

print(f"\n[parse] WEST_LAKE_STAMP_SCENES={len(SCENES)}  WeatherManager.WEST_LAKE_SCENES={len(WEATHER_4)}"
      f"  GALLERY_ITEMS={len(GALLERY)}  events_special={len(EVENTS)}"
      f"  event files={[p.name for p in ALL_EVENT_FILES]}")

# ── A. 注册表唯一真源（T-1 / S-5）────────────────────────────────
section("A. 十景注册表 —— 唯一数据真源  (GDD T-1 / S-5)")
sids = list(SCENES.keys())
check(len(SCENES) == 10, "WEST_LAKE_STAMP_SCENES 恰含 10 个键", f"实得 {len(SCENES)}")
check(sids == EXPECTED_SIDS,
      "键集合与顺序 == GDD §1.2 十景表（顺序即集章簿格子顺序）",
      f"实得 {sids}")
check(len(set(sids)) == len(sids), "sid 无重复")

required_fields = ("name", "emoji", "season", "summary", "lines", "season_line", "romance_ev")
missing = {s: [f for f in required_fields if f not in SCENES[s]] for s in sids}
missing = {k: v for k, v in missing.items() if v}
check(not missing, "每景字段齐全 name/emoji/season/summary/lines/season_line/romance_ev", str(missing))

bad_lines = {s: len(SCENES[s].get("lines", [])) for s in sids
             if not (2 <= len(SCENES[s].get("lines", [])) <= 4)}
check(not bad_lines, "每景 lines 句数在 [2,4]（GDD §6.1）", str(bad_lines))

bad_season = {s: SCENES[s]["season"] for s in sids
              if SCENES[s]["season"] not in ("spring", "summer", "autumn", "winter", "")}
check(not bad_season, 'season 取值仅限 spring/summer/autumn/winter/""', str(bad_season))

from collections import Counter
season_dist = Counter(SCENES[s]["season"] for s in sids)
check(season_dist == Counter({"spring": 3, "summer": 2, "autumn": 2, "winter": 2, "": 1}),
      "季节配平 春3/夏2/秋2/冬2/无季节1（GDD §1.2）", str(dict(season_dist)))

check(SCENES["shuangfengchayun"]["season"] == "",
      "双峰插云 season == ''（改用晴天正反馈，非季节）")

emojis = [SCENES[s]["emoji"] for s in sids]
check(len(set(emojis)) == 10, "10 景 emoji 互不重复", str([e for e, c in Counter(emojis).items() if c > 1]))
names = [SCENES[s]["name"] for s in sids]
check(len(set(names)) == 10, "10 景景名互不重复")

empty_sl = [s for s in sids if not str(SCENES[s].get("season_line", "")).strip()]
check(not empty_sl, "每景 season_line 非空（当季/晴天加句可用）", str(empty_sl))

# 唯一真源：全工程仅一处定义十景注册表
defs = []
for p in SCRIPTS.rglob("*.gd"):
    if re.search(r"WEST_LAKE_STAMP_SCENES\s*=\s*\{", p.read_text(encoding="utf-8")):
        defs.append(p.name)
check(defs == ["CollectionManager.gd"],
      "全工程仅 CollectionManager.gd 一处定义 WEST_LAKE_STAMP_SCENES（S-5）", str(defs))

# ── B. 与 WeatherManager 前四景一致性（T-2）──────────────────────
section("B. 与 WeatherManager.WEST_LAKE_SCENES 前四景一致性  (GDD T-2)")
for season, sid in SEASON_TO_SID.items():
    w = WEATHER_4.get(season, {})
    s = SCENES.get(sid, {})
    check(w.get("name") == s.get("name") and w.get("emoji") == s.get("emoji"),
          f"{season}: name/emoji 一致（{w.get('name')} {w.get('emoji')}）",
          f"weather=({w.get('name')},{w.get('emoji')}) stamp=({s.get('name')},{s.get('emoji')})")
check(len(WEATHER_4) == 4,
      "WeatherManager.WEST_LAKE_SCENES 保持 4 条未被改动（零回归，GDD §1.3）",
      f"实得 {len(WEATHER_4)}")

# ── C. 浪漫事件终局 setFlags（T-3 / S-3）─────────────────────────
section("C. 浪漫事件终局 setFlags 含 stamp_*  (GDD T-3 / S-3)")
ev_by_id = {e["id"]: e for e in EVENTS if isinstance(e, dict) and "id" in e}
for ev_id, sid in ROMANCE_MAP.items():
    ev = ev_by_id.get(ev_id)
    if not check(ev is not None, f"{ev_id}: 事件存在于 events_special.json"):
        continue
    terminals = [(i, s) for i, s in enumerate(ev.get("scenes", []))
                 if isinstance(s, dict) and s.get("next") == 99]
    check(len(terminals) >= 1, f"{ev_id}: 至少 1 条 next:99 终局场景", f"实得 {len(terminals)}")
    bad = [i for i, s in terminals
           if not (isinstance(s.get("setFlags"), list)
                   and ev_id in s["setFlags"]
                   and f"stamp_{sid}" in s["setFlags"])]
    check(not bad,
          f"{ev_id}: 全部 {len(terminals)} 条终局均含 setFlags=[{ev_id}, stamp_{sid}]",
          f"缺失分支 idx={bad}")

winter = ev_by_id.get("west_lake_winter_jingjing", {})
w_terms = [i for i, s in enumerate(winter.get("scenes", []))
           if isinstance(s, dict) and s.get("next") == 99]
check(len(w_terms) == 2,
      f"断桥残雪（winter）双终局分支均被覆盖 idx={w_terms}（GDD §5 C-4 特别要求）",
      f"实得 {len(w_terms)} 条")

# 反向：不得有 west_lake_* 事件遗漏 stamp
covered = set()
for e in EVENTS:
    for s in e.get("scenes", []) or []:
        if isinstance(s, dict):
            for f in (s.get("setFlags") or []):
                if str(f).startswith("stamp_"):
                    covered.add(f)
check(covered == {f"stamp_{v}" for v in ROMANCE_MAP.values()},
      "events_special.json 中出现的 stamp_* 恰为 4 个浪漫景，无多余/漂移",
      str(sorted(covered)))

# ── D. 根级 setFlag 死数据清零（T-4）─────────────────────────────
section("D. 事件根级 setFlag 死数据清零 · 断桥残雪 bug 回归守卫  (GDD T-4)")
root_offenders = []
for p in ALL_EVENT_FILES:
    data = json.loads(p.read_text(encoding="utf-8"))
    for e in data:
        if isinstance(e, dict) and "setFlag" in e:
            root_offenders.append(f"{p.name}:{e.get('id')}")
check(not root_offenders,
      f"全部 {len(ALL_EVENT_FILES)} 个事件 JSON 中根级 setFlag 数量 == 0（死数据不得复活）",
      str(root_offenders))

# 引擎侧确认：确实无任何代码读取事件根级 setFlag
root_readers = []
for p in SCRIPTS.rglob("*.gd"):
    t = p.read_text(encoding="utf-8")
    for m in re.finditer(r'(current_event|ev|ev_copy|event)\s*(\.get\(\s*"setFlag"|\[\s*"setFlag"\s*\])', t):
        root_readers.append(f"{p.name}:{t[:m.start()].count(chr(10))+1}")
check(not root_readers,
      "无任何 .gd 读取事件根级 setFlag（确认该字段确为死数据，删除无副作用）",
      str(root_readers))

# ── E. DialogueUI 场景级 setFlags 支持（T-5）─────────────────────
section("E. DialogueUI 场景级 setFlags 数组支持 + 零回归面  (GDD T-5)")
scene_flags_blk = re.search(
    r'if scene\.has\("setFlags"\):\s*\n\s*for f in scene\["setFlags"\]:\s*\n'
    r'\s*GameManager\.set_flag\(f,\s*true\)\s*\n\s*GameManager\.unlock_gallery\(f\)',
    dlg_src)
check(scene_flags_blk is not None,
      'DialogueUI 场景级：if scene.has("setFlags") → set_flag + unlock_gallery 循环存在')
check('if scene.has("setFlag"):' in dlg_src,
      "既有场景级 setFlag 单字符串分支保持不变（纯新增，零回归）")
if scene_flags_blk:
    idx_flags = scene_flags_blk.start()
    idx_flag = dlg_src.index('if scene.has("setFlag"):')
    check(idx_flags < idx_flag,
          "setFlags 数组分支位于 setFlag 单值分支之前（GDD §5 改动 A 指定顺序）")
# 与选项级写法对称
choice_blk = re.search(r'choice_data\.has\("setFlags"\)', dlg_src)
check(choice_blk is not None, "选项级 setFlags 分支仍在（对称性参照物存在）")
# 零回归面：全仓仅 west_lake 5 条终局使用场景级 setFlags
users = []
for p in ALL_EVENT_FILES:
    for e in json.loads(p.read_text(encoding="utf-8")):
        for i, s in enumerate(e.get("scenes", []) or []):
            if isinstance(s, dict) and "setFlags" in s:
                users.append(f"{e.get('id')}#{i}")
check(len(users) == 5 and all(u.startswith("west_lake_") for u in users),
      f"全仓场景级 setFlags 使用者恰 5 处且全为 west_lake_*（零回归面）", str(users))

# ── F. stamp_ 字面量无拼写漂移（T-6）─────────────────────────────
section("F. stamp_ 字面量跨文件无拼写漂移  (GDD T-6)")
lit_in_coll = set(re.findall(r'"stamp_([a-z]+)"', coll_src))
check(not (lit_in_coll - set(sids)),
      "CollectionManager 中出现的 stamp_<sid> 字面量均属注册表",
      str(sorted(lit_in_coll - set(sids))))
json_sids = {f.replace("stamp_", "") for f in covered}
check(json_sids <= set(sids),
      "events_special.json 的 stamp_<sid> 均属注册表（无拼写漂移）",
      str(sorted(json_sids - set(sids))))
# flag 拼接方式确认（避免硬编码 10 份字面量）
check('"stamp_" + sid' in coll_src,
      'grant_stamp/查询 API 使用 "stamp_" + sid 拼接（不硬编码 10 份字面量）')

# ── G. GALLERY_ITEMS 条目 + CG 资产（T-7）────────────────────────
section("G. 画廊条目与 CG 资产落盘  (GDD T-7)")
gal = [g for g in GALLERY if g.get("flag") == "west_lake_stamps_complete"]
check(len(gal) == 1, "GALLERY_ITEMS 恰含 1 条 flag==west_lake_stamps_complete", f"实得 {len(gal)}")
if gal:
    g = gal[0]
    check(all(k in g for k in ("char", "pose", "label", "hint", "flag", "bg")),
          "画廊条目字段齐全 char/pose/label/hint/flag/bg", str(sorted(g.keys())))
    check(g.get("char") == "player",
          'char == "player"（对齐既有 3 条非角色 CG 写法）', str(g.get("char")))
    bg = str(g.get("bg", ""))
    check(bg.startswith("res://assets/backgrounds/"), "bg 指向 res://assets/backgrounds/", bg)
    bg_path = ROOT / bg.replace("res://", "")
    check(bg_path.exists(), f"CG 资产已落盘 {bg_path.name}", str(bg_path))
    if bg_path.exists():
        check(bg_path.stat().st_size > 20_000,
              f"CG 文件非空桩（{bg_path.stat().st_size} bytes）")
        check((bg_path.parent / (bg_path.name + ".import")).exists(),
              f"{bg_path.name}.import 已生成（Godot 导入元数据）")
# 注：flag == "" 是既有「初始解锁」条目的约定值（is_gallery_unlocked 直接返回 true），
#     允许重复；仅校验具名 flag 的唯一性。
gal_flags = [g.get("flag") for g in GALLERY if g.get("flag")]
check(len(gal_flags) == len(set(gal_flags)), "GALLERY_ITEMS 具名 flag 无重复",
      str([f for f, c in Counter(gal_flags).items() if c > 1]))
check(sum(1 for g in GALLERY if not g.get("flag")) == 6,
      "初始解锁条目（flag==\"\"）仍为 6 条，未被本特性改动")

# ── H. 路由闭合（T-8）───────────────────────────────────────────
section("H. lakeside 热点 ↔ HotspotExploreUI 路由闭合  (GDD T-8)")
hotspots = LAKESIDE.get("hotspots", [])
check(len(hotspots) == 5, "lakeside 基础热点 5 个（原 4 + 集章 1）", f"实得 {len(hotspots)}")
ids = [h.get("event_id") for h in hotspots]
check(ids.count("west_lake_stamp") == 1,
      "lakeside.hotspots 恰含 1 个 event_id == west_lake_stamp", str(ids))
stamp_hs = next((h for h in hotspots if h.get("event_id") == "west_lake_stamp"), None)
if stamp_hs:
    check(stamp_hs.get("label", "").startswith("🏞️"),
          f"热点 label 为「{stamp_hs.get('label')}」")
    check(hotspots[-1] is stamp_hs, "集章热点追加在数组末尾（GDD §6.2，不打乱既有顺序）")
check(re.search(r'"west_lake_stamp":\s*\n\s*_open_west_lake_stamp_checkin\(\)\s*\n\s*return',
                hot_src) is not None,
      "HotspotExploreUI.on_hotspot_clicked match 表存在 west_lake_stamp 分支并 early return")
check("func _open_west_lake_stamp_checkin" in hot_src,
      "_open_west_lake_stamp_checkin() 已定义（路由闭合，无悬空引用）")
body_route = func_body(hot_src, "_open_west_lake_stamp_checkin")
check('set_meta("mode", "checkin")' in body_route,
      'pre_add_cb 注入 set_meta("mode","checkin")（打卡模式）')
check('_open_sub_ui("res://scripts/StampBookUI.gd"' in body_route,
      "经 _open_sub_ui 加载 res://scripts/StampBookUI.gd")
check(STAMPUI.exists(), "scripts/StampBookUI.gd 存在（脚本路径可解析）")
# 反向：热点表里不能有无路由的孤儿（仅校验本特性引入项）
check(hot_src.count('"west_lake_stamp"') == 1,
      "HotspotExploreUI 中 west_lake_stamp 字面量恰出现 1 次（无重复分支）")

# ── I. 热点坐标间距（T-9）───────────────────────────────────────
section("I. lakeside 热点坐标间距  (GDD T-9)")
pts = [(h.get("label"), tuple(h.get("pos"))) for h in hotspots]
worst = None
for i in range(len(pts)):
    for j in range(i + 1, len(pts)):
        d = math.dist(pts[i][1], pts[j][1])
        if worst is None or d < worst[0]:
            worst = (d, pts[i][0], pts[j][0])
check(worst and worst[0] >= 0.20,
      f"5 个基础热点两两欧氏距离 ≥ 0.20（最近 {worst[0]:.3f}: {worst[1]} ↔ {worst[2]}）")
TEMP_LAKESIDE = [("🌉 西湖夏夜游", (0.40, 0.50)),
                 ("🍃 清明踏青", (0.40, 0.45)),
                 ("🇨🇳 国庆西湖行", (0.38, 0.48))]
if stamp_hs:
    sp = tuple(stamp_hs["pos"])
    worst_t = min((math.dist(sp, p), lbl) for lbl, p in TEMP_LAKESIDE)
    check(worst_t[0] >= 0.15,
          f"集章热点与 3 个长假临时热点距离 ≥ 0.15（最近 {worst_t[0]:.3f}: {worst_t[1]}）")
    check(0.0 <= sp[0] <= 1.0 and 0.0 <= sp[1] <= 1.0,
          f"集章热点 pos {sp} 在 [0,1]² 归一化范围内")
# 临时热点坐标与源码一致性（防 GDD 与实现漂移）
loc_src = src_of(LOCMGR)
for lbl, p in TEMP_LAKESIDE:
    pat = r"Vector2\(%s,\s*%s\)" % (re.escape(f"{p[0]:.2f}"), re.escape(f"{p[1]:.2f}"))
    check(re.search(pat, loc_src) is not None,
          f"LocationManager 中临时热点 {lbl} 坐标 {p} 与本测试基线一致")

# ── J. 零新 Autoload（T-10 / S-4）───────────────────────────────
section("J. 零新 Autoload / 零存档迁移  (GDD T-10 / S-4)")
proj = src_of(PROJECT)
m = re.search(r"\[autoload\]\n(.*?)(?=\n\[|\Z)", proj, re.S)
autoloads = re.findall(r"^(\w+)=", m.group(1), re.M) if m else []
check(len(autoloads) == AUTOLOAD_EXPECTED,
      f"project.godot [autoload] 段恰 {AUTOLOAD_EXPECTED} 项（未新增）", str(autoloads))
check("CollectionManager" in autoloads,
      "集章逻辑寄居的 CollectionManager 已在 autoload 中（无需新注册）")
check(not any("Stamp" in a for a in autoloads),
      "无任何 Stamp* 相关新 Autoload", str([a for a in autoloads if "Stamp" in a]))
save_src = src_of(SAVESYS)
check("flags" in save_src and re.search(r'"flags"', save_src) is not None,
      "SaveSystem 整体序列化 GameManager.flags（新增键零迁移）")
check("stamp" not in save_src.lower(),
      "SaveSystem 未针对 stamp 做任何特判/迁移代码（S-4）")

# ── K. stamp_ flag 单一写入源（T-11）────────────────────────────
section("K. stamp_ flag 单一写入源  (GDD T-11)")
writers = []
WRITE_PAT = re.compile(r'(set_flag\(\s*"stamp_|flags\[\s*"stamp_|set_flag\(\s*flag\s*\+\s*"_day"|'
                       r'set_flag\(\s*"west_lake_stamps_complete"|set_flag\(STAMP_)')
for p in SCRIPTS.rglob("*.gd"):
    t = p.read_text(encoding="utf-8")
    for ln, line in enumerate(t.splitlines(), 1):
        if WRITE_PAT.search(line):
            writers.append(f"{p.name}:{ln}")
check(all(w.startswith("CollectionManager.gd:") for w in writers),
      f"所有 stamp_* / complete flag 写入点均在 CollectionManager.gd（{len(writers)} 处）",
      str([w for w in writers if not w.startswith("CollectionManager.gd:")]))
check(len(writers) >= 4, f"写入点计数合理（{len(writers)} ≥ 4）", str(writers))
# 数据侧写入源仅 events_special.json（路径 B）
json_writers = [p.name for p in ALL_EVENT_FILES
                if "stamp_" in p.read_text(encoding="utf-8")]
check(json_writers == ["events_special.json"],
      "数据侧 stamp_* 写入仅出现在 events_special.json", str(json_writers))

# ── L. StampBookUI 单向数据流（T-12）────────────────────────────
section("L. StampBookUI 单向数据流  (GDD T-12 / §6.5)")
ui_writes = [f"L{n}: {l.strip()}" for n, l in enumerate(ui_src.splitlines(), 1)
             if re.search(r'set_flag\(|GameManager\.flags\s*\[|\.flags\[.*\]\s*=|unlock_gallery\(', l)]
check(not ui_writes, "StampBookUI 不含任何 set_flag / flags[...] = / unlock_gallery 写操作", str(ui_writes))
ui_code_only = "\n".join(l for l in ui_src.splitlines() if not l.lstrip().startswith("#"))
check("grant_stamp" not in ui_code_only,
      "StampBookUI 可执行代码中不调用 grant_stamp（授予职责在 HotspotExploreUI 侧；文档注释提及不计）")
check(re.search(r"^var picked_sid:\s*String\s*=\s*\"\"", ui_src, re.M) is not None,
      'StampBookUI 唯一输出 var picked_sid: String = ""')
check("signal closed" in ui_src, "StampBookUI 暴露 signal closed（关闭契约）")
check(re.search(r'get_meta\("mode",\s*"book"\)', ui_src) is not None,
      'StampBookUI 通过 get_meta("mode","book") 读取模式，默认 book（防误开打卡态）')
check(ui_src.count("CollectionManager.") >= 5,
      "StampBookUI 全部业务数据经 CollectionManager 只读 API 获取（单一真源消费）")
# 输出被消费方读取
check("ui.picked_sid" in hot_src, "HotspotExploreUI 读取 picked_sid（输出契约闭合）")
check("grid.columns = 5" in ui_src, "集章簿 5 列网格（GDD §3.3）")

# ── M. grant_stamp 幂等 + 集满原子语义 ──────────────────────────
section("M. grant_stamp 幂等 + 集满原子语义  (GDD §2.1 / §4.2)")
gs = func_body(coll_src, "grant_stamp")
check(gs != "", "grant_stamp() 已定义")
check(re.search(r"if not WEST_LAKE_STAMP_SCENES\.has\(sid\):\s*return false", gs) is not None,
      "未知 sid 直接 return false（非法输入防御）")
check(re.search(r"if GameManager\.flags\.has\(flag\):\s*return false", gs) is not None,
      "已得则 return false —— 幂等守卫（路径 A/B 收敛的技术落点）")
check('GameManager.set_flag(flag, true)' in gs and 'set_flag(flag + "_day", GameManager.day)' in gs,
      "授予时同时写 stamp_<sid>=true 与 stamp_<sid>_day=day")
check(re.search(r"if from_checkin:\s*\n\s*GameManager\.set_flag\(\"stamp_checkin_day\", GameManager\.day\)", gs)
      is not None,
      "仅 from_checkin=True 时写 stamp_checkin_day（路径 B 不挤占当日额度，GDD §2.5 注）")
check(re.search(r"if _check_stamp_completion\(\):\s*return true", gs) is not None,
      "本次授予即集满 → 只发集满 toast，跳过普通章 toast（GDD §8⑤ 防刷屏）")
check(re.search(r'func grant_stamp\(sid: String, from_checkin: bool = true\)', coll_src) is not None,
      "签名 grant_stamp(sid: String, from_checkin: bool = true) 与 GDD §4.1 一致")

cs = func_body(coll_src, "_check_stamp_completion")
check(re.search(r"if GameManager\.flags\.has\(STAMP_COMPLETE_FLAG\):\s*return false", cs) is not None,
      "_check_stamp_completion 已完成则 return false（不重复发奖）")
check(re.search(r"for sid in WEST_LAKE_STAMP_SCENES\.keys\(\):\s*\n\s*if not is_stamp_owned\(sid\):\s*return false", cs)
      is not None,
      "集满判定遍历注册表全 10 键（不硬编码计数）")
for tok, desc in (("set_flag(STAMP_COMPLETE_FLAG, true)", "置 west_lake_stamps_complete"),
                  ("set_flag(STAMP_TITLE_FLAG, true)", "置称号 flag"),
                  ("unlock_gallery(STAMP_COMPLETE_FLAG)", "解锁画廊条目"),
                  ("show_toast.emit", "发出集满 toast")):
    check(tok in cs, f"集满原子动作：{desc}")
check(re.search(r'const STAMP_TITLE_FLAG\s*:?=\s*"title_西湖十景通"', coll_src) is not None,
      'STAMP_TITLE_FLAG == "title_西湖十景通"（D-2(a) 中文 flag，substr(6) 直出可读称号）')
check(re.search(r'const STAMP_COMPLETE_FLAG\s*:?=\s*"west_lake_stamps_complete"', coll_src) is not None,
      "STAMP_COMPLETE_FLAG 与 GALLERY_ITEMS.flag 字面量一致")
check(re.search(r"const STAMP_TOTAL\s*:?=\s*10", coll_src) is not None, "STAMP_TOTAL == 10")

rs = func_body(coll_src, "_retroactive_stamp_check")
check(re.search(r"if is_stamp_owned\(sid\) and get_stamp_day\(sid\) < 0:", rs) is not None,
      "_retroactive_stamp_check 补齐缺失的 stamp_<sid>_day（路径 B 兜底）")
check("_check_stamp_completion()" in rs,
      "_retroactive_stamp_check 末尾触发集满判定（存量存档补发奖）")
check("_retroactive_stamp_check()" in func_body(coll_src, "_retroactive_gallery_check"),
      "_retroactive_gallery_check() 调用 _retroactive_stamp_check()（共用既有补偿时机，CollectionManager L85 区）")

# ── N. 每日 1 章限速 ────────────────────────────────────────────
section("N. 每日 1 章限速  (GDD §2.5 L3)")
ck = func_body(coll_src, "is_stamp_checkin_used_today")
check('flags.get("stamp_checkin_day", -1)' in ck and "== GameManager.day" in ck,
      "is_stamp_checkin_used_today() 以 stamp_checkin_day == GameManager.day 判定")
check("_checkin_locked = CollectionManager.is_stamp_checkin_used_today()" in ui_src,
      "StampBookUI checkin 模式 _ready() 读取当日限速状态")
check(re.search(r"var selectable: bool = \(_mode == \"checkin\"\) and \(not owned\) and \(not _checkin_locked\)",
                ui_src) is not None,
      "可选条件 = checkin 模式 ∧ 未得 ∧ 当日未打卡（C1 ∧ C2，GDD §2.4）")
check(re.search(r"if _mode == \"checkin\":\s*\n\s*_checkin_locked", ui_src) is not None,
      "限速仅在 checkin 模式生效（book 模式只读浏览不受限）")
check("今天已经在湖边盖过一枚印了" in ui_src, "限速触发时有明确玩家可读提示（无静默失败）")
# 限速守卫不能被 book 模式绕过
check("picked_sid = sid" in ui_src and ui_src.count("picked_sid = sid") == 1,
      "picked_sid 仅在一处被赋值（且位于 selectable 分支内）")
pick_ctx = ui_src[max(0, ui_src.index("picked_sid = sid") - 300): ui_src.index("picked_sid = sid")]
check("if selectable:" in pick_ctx,
      "picked_sid 赋值受 if selectable 守卫（无法绕过限速/幂等）")

# ── O. MainGame 入口 + 补偿扫描调用链 ───────────────────────────
section("O. MainGame board 入口 + 补偿扫描调用链闭合  (GDD §3.4 / §4.1)")
check('{"text": "📖 集章簿"' in main_src, "MainGame board items 数组含「📖 集章簿」按钮")
check('"fn": _show_stampbook_popup' in main_src, "按钮绑定 _show_stampbook_popup")
sb = func_body(main_src, "_show_stampbook_popup")
check(sb != "", "_show_stampbook_popup() 已定义")
check('set_meta("mode", "book")' in sb, 'board 入口注入 mode=="book"（只读模式）')
check('load("res://scripts/StampBookUI.gd")' in sb, "按需 load 实例化（不常驻内存）")
check("inst.closed.connect" in sb and "update_ui()" in sb,
      "closed 信号回连 update_ui()（关闭后界面刷新）")
check("if not scr: return" in sb, "load 失败早退（防空引用崩溃）")
# board 按钮不撞色
btn_colors = re.findall(r'"color": Color\(([0-9.]+), ([0-9.]+), ([0-9.]+)\)', main_src)
check(len(btn_colors) == len(set(btn_colors)),
      f"board 全部 {len(btn_colors)} 个按钮配色互不重复")
# 补偿扫描三处调用点
check("CollectionManager._retroactive_stamp_check()" in func_body(main_src, "_on_event_finished"),
      "MainGame._on_event_finished() 调用 _retroactive_stamp_check()（路径 B 关键补偿点）")
check("call_deferred(\"_retroactive_gallery_check\")" in gm_src,
      "GameManager 启动时 call_deferred 补偿扫描（开局路径）")
check("_retroactive_gallery_check()" in src_of(SAVESYS),
      "SaveSystem 读档后补偿扫描（读档路径）")
check("CollectionManager._retroactive_gallery_check()" in func_body(gm_src, "_retroactive_gallery_check"),
      "GameManager._retroactive_gallery_check 门面转发到 CollectionManager（链路不断）")

# ── P. vignette 契约 ────────────────────────────────────────────
section("P. build_stamp_vignette 契约  (GDD §6.3)")
bv = func_body(coll_src, "build_stamp_vignette")
check(bv != "", "build_stamp_vignette() 已定义")
check("set_flag" not in bv and "flags[" not in bv,
      "vignette 合成函数不写任何 flag（授予职责单一归属 grant_stamp）")
check('"next": 99' in bv, "末条 scene 携带 next:99（走 finish_event → advance_time 消耗 1 时段）")
check('"repeatable": true' in bv,
      '事件字典含 repeatable:true —— DialogueUI.finish_event() 不会写入 west_lake_stamp_<sid> 垃圾 flag')
check(re.search(r'"repeatable"', coll_src) is not None
      and 'current_event.get("repeatable", false)' in dlg_src,
      "repeatable 字段名与 DialogueUI.finish_event() L540 读取处一致")
check('"isSpecial": false' in bv, "isSpecial:false —— 不进 special 优先级队列，不被随机抽取")
check('"location":  "lakeside"' in bv or '"location": "lakeside"' in bv,
      "location 固定 lakeside")
check('last["statDelta"] = {"stress": -2}' in bv,
      "当季/晴天正反馈 stress -2（GDD §2.4 弱引导）")
check('for key in ["statsDelta", "statDelta"]' in dlg_src,
      "statDelta 字段名与 DialogueUI._apply_scene_level_effects() 实际读取的键一致（无静默失效）")
check("if bonus and season_line" in bv,
      "season_line 仅在 bonus 状态下插入（非当季不显示加句）")
check(re.search(r"if data\.is_empty\(\):\s*return \{\}", bv) is not None,
      "未知 sid 返回空字典；HotspotExploreUI 侧有 vignette.is_empty() 兜底")
check("if vignette.is_empty():" in body_route,
      "HotspotExploreUI 对空 vignette 兜底：恢复探索层且不消耗时段")
ba = func_body(coll_src, "is_stamp_bonus_active")
check('GameManager.current_weather == "sunny"' in ba,
      "双峰插云（season=='')走晴天判定 current_weather == 'sunny'")
check("WeatherManager.get_season() == season" in ba,
      "其余九景走 WeatherManager.get_season() 比对")
check(re.search(r'var current_weather: String = "sunny"', gm_src) is not None,
      "GameManager.current_weather 属性存在（引用不悬空）")

# ── Q. 路线解耦：打卡路径零好感/角色门槛（S-1 / S-2）────────────
section("Q. 路线解耦 —— 打卡路径零角色/好感/季节门槛  (GDD S-1 / S-2 / D-1=A)")
GATE_PAT = re.compile(r"minAff|favorability|rel_state|relState|excludeRelState|char_meta|charId|get_favor")

# ⚠️ A136 作用域修正（sprint1 后）：CollectionManager.gd 是多特性共居文件——
#    集章区之后追加了「记忆回响 · 情境回响」区，该区按设计合法使用
#    favorability 打分 + get_rel_state 排除冷战（memory_echo GDD G9），与集章路径无关。
#    原实现只截上界（WEST_LAKE_STAMP_SCENES 起）、不截下界，把整个记忆回响区一并扫入，
#    导致 A136 误报 4 行（L496/537/554/567，其中 2 行还只是 docstring 注释）。
#    集章区本身自始至终零门槛。此处按区块标记切出 [集章区起点, 记忆回响区起点)。
STAMP_AREA_START = "const WEST_LAKE_STAMP_SCENES"
# 记忆回响区起点候选，按出现优先级取首个命中（容忍下游改名/加区块横幅）
ECHO_AREA_MARKERS = ("# ── 记忆回响", "## 记忆回响", "## 情境回响",
                     "const ECHO_MATURE_DAYS", "const MEMORY_ECHO_CONTEXTS")


def stamp_area(text: str) -> tuple[str, int]:
    """切出 CollectionManager.gd 的集章区，返回 (区块文本, 区块首行的绝对行号)。

    起点缺失 → 从文件头扫（安全失败：宁可多扫误报，不可漏扫漏检）。
    终点缺失 → 扫到文件尾（同上）。
    """
    start = text.find(STAMP_AREA_START)
    if start < 0:
        start = 0
    end = -1
    for marker in ECHO_AREA_MARKERS:
        idx = text.find(marker, start)
        if idx >= 0:
            end = idx
            break
    if end < 0:
        end = len(text)
    return text[start:end], text.count("\n", 0, start) + 1


for path, label in ((COLL, "CollectionManager 集章区"), (STAMPUI, "StampBookUI"),):
    text, line0 = stamp_area(coll_src) if path is COLL else (ui_src, 1)
    hits = [f"L{line0 + i}: {l.strip()}"
            for i, l in enumerate(text.splitlines()) if GATE_PAT.search(l)]
    check(not hits, f"{label} 不含任何 minAff/好感/关系状态/charId 门槛", str(hits[:5]))
route_hits = [l.strip() for l in body_route.splitlines() if GATE_PAT.search(l)]
check(not route_hits, "HotspotExploreUI 集章路由不含任何角色/好感门槛", str(route_hits[:5]))
# 季节非门槛：可选性判定里不得出现 season
sel_line = re.search(r"var selectable: bool =.*", ui_src)
check(sel_line and "season" not in sel_line.group(0) and "bonus" not in sel_line.group(0),
      "selectable 判定式中不含 season/bonus（季节是推荐而非门槛，D-1 选 A）",
      sel_line.group(0) if sel_line else "")
check("bonus" in ui_src and "⭐" in ui_src,
      "当季仅体现为 ⭐ 徽标 + 置顶排序（纯正反馈）")
check("不是门槛，任何季节都能盖任何一枚" in ui_src,
      "面板空态文案向玩家明示「季节不是门槛」（防误解性 soft-lock 焦虑）")
# 常驻热点（非临时），不受长假/文化节影响
check('"west_lake_stamp"' not in loc_src,
      "集章热点是 GameManager 基础热点，未混入 LocationManager._get_temp_hotspots（常驻可达）")

# ── R. NG+ 语义 + 称号 flag 往返 ───────────────────────────────
section("R. NG+ 语义 + 称号 flag 往返  (GDD §5.2 / §4.3)")
check(re.search(r"GameManager\.flags = \{\}", ending_src) is not None,
      "EndingScreen NG+ 整体清空 flags → stamp_*/complete 自动清空（预期：新周目重集）")
check(re.search(r'flag_key\.begins_with\("title_"\)', ending_src) is not None
      and "substr(6)" in ending_src,
      'EndingScreen 扫描 title_ 前缀并 substr(6) 去前缀')
check(len("title_") == 6,
      'substr(6) 与 "title_" 前缀长度匹配 → "title_西湖十景通".substr(6) == "西湖十景通"（GDScript 按字符切分）')
check(re.search(r'GameManager\.flags\["title_" \+ t\] = true', ending_src) is not None,
      'NG+ 以 "title_" + t 回写 → 中文称号 flag 往返无损')
check("STAMP_TITLE_FLAG" in cs, "集满时经 STAMP_TITLE_FLAG 常量置位（无字面量漂移）")
# ⚠️ QA 独立复核修正 GDD §4.3 的一处事实错误：
#    GDD 称「本 GDD 未在工程中检出任何 title_* 的授予点」，实际 SeasonManager.gd:206
#    早已存在赛季称号授予（title_ + 中文名）。结论不变但理由更强：
#    D-2(a) 的中文 flag 选择不是"确立新惯例"，而是"对齐既有惯例"。
title_defs = sorted(p.name for p in SCRIPTS.rglob("*.gd")
                    if re.search(r'set_flag\(\s*"title_|STAMP_TITLE_FLAG',
                                 p.read_text(encoding="utf-8")))
check(title_defs == ["CollectionManager.gd", "SeasonManager.gd"],
      f"全工程 title_* 授予点恰 2 处 {title_defs}（集章 + 赛季奖励）", str(title_defs))
season_src = src_of(SCRIPTS / "SeasonManager.gd")
season_titles = re.findall(r'\{"type": "title",\s*"amount": \d+,\s*"name": "([^"]+)"', season_src)
check(len(season_titles) >= 3,
      f"既有赛季称号 {season_titles} 全部为中文名 → title_ 前缀 + 中文是工程既有惯例")
check(all(not t.isascii() for t in season_titles),
      "既有 title_* 均为中文后缀 —— title_西湖十景通 与之一致（D-2(a) 为对齐既有惯例而非新立）",
      str([t for t in season_titles if t.isascii()]))
check("西湖十景通" not in season_titles,
      "称号名「西湖十景通」与既有赛季称号无重名冲突", str(season_titles))
check(re.search(r'set_flag\("active_title"', season_src) is not None
      and not re.search(r'"active_title"', coll_src),
      '集章称号不写 active_title（佩戴态仍由赛季系统独占，无语义争夺）')
check(not "active_title".startswith("title_"),
      'active_title 不以 title_ 开头 → 不会被 EndingScreen 误当作一个称号上传')

# ── S. 缩进风格一致性 ──────────────────────────────────────────
section("S. 缩进风格一致性（防 GDScript mixed-indent 解析错误）")
INDENT_EXPECT = {
    "CollectionManager.gd": "tab",
    "StampBookUI.gd": "space", "HotspotExploreUI.gd": "space",
    "DialogueUI.gd": "space", "MainGame.gd": "space", "GameManager.gd": "space",
}
for fname, want in INDENT_EXPECT.items():
    text = (SCRIPTS / fname).read_text(encoding="utf-8")
    lines = [l for l in text.splitlines() if l.strip()]
    tabs = sum(1 for l in lines if l.startswith("\t"))
    spcs = sum(1 for l in lines if l.startswith(" "))
    if want == "tab":
        check(tabs > 0 and spcs == 0, f"{fname}: 纯 tab 缩进（{tabs} tab / {spcs} space）")
    else:
        check(spcs > 0 and tabs == 0, f"{fname}: 纯空格缩进（{spcs} space / {tabs} tab）")
    mixed = [n for n, l in enumerate(text.splitlines(), 1)
             if re.match(r"^(\t+ | +\t)", l)]
    check(not mixed, f"{fname}: 无行内 tab/space 混用", str(mixed[:5]))

# ── 非阻塞关注项（advisory）──────────────────────────────────────
section("非阻塞关注项 (advisory)")
if stamp_hs:
    n_base = len(hotspots)
    note(f"lakeside 最坏情况热点数 = {n_base} 基础 + 1 长假临时 = {n_base + 1} 个按钮，"
         f"HFlowContainer 自动换行承载，建议实机在 1280×720 下目视确认不溢出")
note("vignette 走 DialogueUI.finish_event() → advance_time()，即「盖章消耗 1 个时段」；"
     "打开面板本身免费（空手退出不消耗）——需产品侧确认此成本符合预期")
note("NG+ 行为：stamp_* / stamp_*_day / stamp_checkin_day / west_lake_stamps_complete 清空，"
     "title_西湖十景通 保留（EndingScreen L440 + L466），与 GDD §5.2 一致")
note("emoji ⛰️ / 🌇 在部分安卓设备可能缺字形，格子下方恒有中文景名兜底，功能不受影响")
if gal:
    note("画廊 CG west_lake_stamps_complete.jpg 已落盘并生成 .import；"
         "右下角 AI 水印已由主理人使用同高度石栏纹理覆盖并轻微模糊融合，保持 1280x720，建议人工最终目视确认")
note("GDD §4.3 / D-2 事实错误已回填：SeasonManager.gd:206 已授予赛季称号 "
     f"{season_titles}（均为中文名），本特性并非首个称号授予方；"
     "D-2(a) 的中文 title_西湖十景通 对齐既有惯例而非新立惯例")
note("GDD §3.3 学期换算已修正为 90 天/学期（对齐 GameManager.get_grade_info() 真源："
     "1-90 初一上 / 91-180 初一下 / 181-270 初二上 / 271-360 初二下 / 361-450 初三上 / 451-570 初三下）；"
     "原 150 天季节分段说法已勘误")

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
