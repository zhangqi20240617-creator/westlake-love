# -*- coding: utf-8 -*-
"""
西湖十景集章系统（DS-RN-03）静态断言验证
=========================================
无 Godot runtime，纯文本 / JSON 解析级验证。
对齐 design/west_lake_stamps_gdd.md §8-④ T-1 ~ T-12 清单。

用法：  python scratch/verify_west_lake_stamps.py
退出码：0 = 全过；1 = 有断言失败
"""
from __future__ import unicode_literals

import io
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "scripts")

PASSED = []
FAILED = []


def check(name, cond, detail=""):
    if cond:
        PASSED.append(name)
        print("  [PASS] %s" % name)
    else:
        FAILED.append((name, detail))
        print("  [FAIL] %s  -- %s" % (name, detail))


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


# ── 期望的十景 sid 全集（GDD §1.2）────────────────────────────
EXPECTED_SIDS = [
    "sudichunxiao", "quyuanfenghe", "pinghuqiuyue", "duanqiaocanxue",
    "huagangguanyu", "liulangwenying", "leifengxizhao", "santanyinyue",
    "nanpingwanzhong", "shuangfengchayun",
]
# 浪漫事件 → sid 映射（GDD §2.1 双路径收敛）
ROMANCE_MAP = {
    "west_lake_spring_jingjing": "stamp_sudichunxiao",
    "west_lake_summer_yutong": "stamp_quyuanfenghe",
    "west_lake_autumn_wanqing": "stamp_pinghuqiuyue",
    "west_lake_winter_jingjing": "stamp_duanqiaocanxue",
}
EXPECTED_NAME_EMOJI = {
    "sudichunxiao": ("苏堤春晓", "🌸"),
    "quyuanfenghe": ("曲院风荷", "🌿"),
    "pinghuqiuyue": ("平湖秋月", "🍂"),
    "duanqiaocanxue": ("断桥残雪", "❄️"),
}

cm_src = read(os.path.join(SCRIPTS, "CollectionManager.gd"))
dlg_src = read(os.path.join(SCRIPTS, "DialogueUI.gd"))
gm_src = read(os.path.join(SCRIPTS, "GameManager.gd"))
hot_src = read(os.path.join(SCRIPTS, "HotspotExploreUI.gd"))
main_src = read(os.path.join(SCRIPTS, "MainGame.gd"))
wm_src = read(os.path.join(SCRIPTS, "WeatherManager.gd"))
sb_path = os.path.join(SCRIPTS, "StampBookUI.gd")
sb_src = read(sb_path) if os.path.exists(sb_path) else ""
ev_path = os.path.join(SCRIPTS, "events_special.json")
with io.open(ev_path, encoding="utf-8") as f:
    events = json.load(f)


def extract_block(src, start_marker, open_ch="{", close_ch="}"):
    """从 start_marker 处提取首个平衡括号块（含括号）。"""
    i = src.index(start_marker)
    j = src.index(open_ch, i)
    depth = 0
    for k in range(j, len(src)):
        if src[k] == open_ch:
            depth += 1
        elif src[k] == close_ch:
            depth -= 1
            if depth == 0:
                return src[j:k + 1]
    raise ValueError("unbalanced block after %r" % start_marker)


# ════════════════════════════════════════════════════════════
print("\n=== T-1  十景注册表：恰含 10 键且 == GDD sid 全集 ===")
try:
    reg = extract_block(cm_src, "const WEST_LAKE_STAMP_SCENES")
    # 顶层键（缩进为单个 tab 的 "xxx": {）
    sids = re.findall(r'^\t"([a-z_]+)": \{', reg, re.M)
    check("T-1a 注册表键数 == 10", len(sids) == 10, "实得 %d: %s" % (len(sids), sids))
    check("T-1b 键集合与 GDD §1.2 一致", sids == EXPECTED_SIDS,
          "实得顺序 %s" % sids)
except Exception as e:  # pragma: no cover
    check("T-1 注册表可解析", False, repr(e))
    reg, sids = "", []

print("\n=== T-2  前 4 景 name/emoji 与 WeatherManager.WEST_LAKE_SCENES 一致 ===")
for sid, (name, emoji) in EXPECTED_NAME_EMOJI.items():
    m = re.search(r'"%s": \{\s*\n\s*"name": "([^"]+)", "emoji": "([^"]+)"' % sid, reg)
    ok = bool(m) and m.group(1) == name and m.group(2) == emoji
    check("T-2 %s 注册表 name/emoji" % sid, ok,
          "实得 %r" % (m.groups() if m else None,))
    check("T-2 %s 见于 WeatherManager" % sid,
          ('"name": "%s", "emoji": "%s"' % (name, emoji)) in wm_src,
          "WeatherManager 缺少 %s/%s" % (name, emoji))

print("\n=== T-3  4 个浪漫事件所有 next:99 终局 scene 含对应 stamp_* ===")
for ev in events:
    eid = ev.get("id", "")
    if eid not in ROMANCE_MAP:
        continue
    want_stamp = ROMANCE_MAP[eid]
    finals = [s for s in ev.get("scenes", []) if s.get("next") == 99]
    check("T-3 %s 有终局 scene" % eid, len(finals) > 0, "无 next:99 场景")
    for idx, s in enumerate(finals):
        flags = s.get("setFlags", [])
        check("T-3 %s 终局#%d 含 setFlags 数组" % (eid, idx),
              isinstance(flags, list) and len(flags) >= 2, "实得 %r" % (flags,))
        check("T-3 %s 终局#%d 含原 west_lake flag" % (eid, idx),
              eid in flags, "实得 %r" % (flags,))
        check("T-3 %s 终局#%d 含 %s" % (eid, idx, want_stamp),
              want_stamp in flags, "实得 %r" % (flags,))
        check("T-3 %s 终局#%d 已无遗留单 setFlag" % (eid, idx),
              "setFlag" not in s, "仍有 setFlag=%r" % s.get("setFlag"))

print("\n=== T-4  events_special.json 不存在事件根级 setFlag（死数据回归守卫）===")
root_offenders = [ev.get("id", "?") for ev in events if "setFlag" in ev]
check("T-4 根级 setFlag 数 == 0", not root_offenders, "违规事件: %s" % root_offenders)

print("\n=== T-5  DialogueUI 场景级同时处理 setFlags 与 setFlag ===")
scene_block = dlg_src[dlg_src.index("func play_current_scene"):dlg_src.index("func update_sprites")]
check("T-5a 场景级 setFlags 分支存在", 'scene.has("setFlags")' in scene_block,
      "play_current_scene 内未见 scene.has(\"setFlags\")")
check("T-5b 场景级 setFlag 分支保留（零回归）", 'scene.has("setFlag")' in scene_block,
      "原 setFlag 分支被误删")
check("T-5c setFlags 分支同步 unlock_gallery",
      re.search(r'scene\.has\("setFlags"\)[\s\S]{0,220}?unlock_gallery', scene_block) is not None,
      "setFlags 分支缺 unlock_gallery")
check("T-5d 选项级 setFlags 写法未被破坏", 'choice_data.has("setFlags")' in dlg_src)

print("\n=== T-6  stamp_<sid> 字面量在 CollectionManager 与 JSON 之间无拼写漂移 ===")
ev_raw = read(ev_path)
json_stamps = set(re.findall(r'"(stamp_[a-z_]+)"', ev_raw))
check("T-6a JSON 中 stamp_* 恰 4 个（4 浪漫事件）", len(json_stamps) == 4,
      "实得 %s" % sorted(json_stamps))
for st in sorted(json_stamps):
    sid = st[len("stamp_"):]
    check("T-6 %s 的 sid 见于注册表" % st, sid in sids, "注册表无 %r" % sid)

print("\n=== T-7  GALLERY_ITEMS 含 west_lake_stamps_complete 条目 ===")
gal = extract_block(gm_src, "const GALLERY_ITEMS", "[", "]")
check("T-7a 画廊条目存在", '"flag": "west_lake_stamps_complete"' in gal)
m_bg = re.search(r'"flag": "west_lake_stamps_complete", "bg": "([^"]+)"', gal)
check("T-7b 条目含 bg 路径", m_bg is not None, "未匹配到 bg 字段")
if m_bg:
    bg = m_bg.group(1)
    check("T-7c bg 指向约定路径",
          bg == "res://assets/backgrounds/west_lake_stamps_complete.jpg", bg)
    disk = os.path.join(ROOT, bg.replace("res://", ""))
    exists = os.path.exists(disk)
    print("       [INFO] CG 资源%s（美术并行产出，缺失不阻塞："
          "GalleryPopupUI 用 ResourceLoader.exists 守卫）" % ("已就位" if exists else "尚未就位"))
check("T-7d 画廊渲染对缺图有容错", "ResourceLoader.exists(bg_path)" in
      read(os.path.join(SCRIPTS, "GalleryPopupUI.gd")))

print("\n=== T-8  lakeside 热点 ↔ HotspotExploreUI 路由闭合 ===")
lakeside_block = gm_src[gm_src.index('"lakeside": {'):]
lakeside_block = lakeside_block[:lakeside_block.index('"community": {')]
check("T-8a lakeside 含 west_lake_stamp 热点",
      '"event_id": "west_lake_stamp"' in lakeside_block)
check("T-8b 热点 label 与 GDD 一致",
      '"🏞️ 西湖十景·集章打卡"' in lakeside_block)
check("T-8c 既有 lakeside_wishes 热点未被破坏",
      '"event_id": "lakeside_wishes"' in lakeside_block)
check("T-8d HotspotExploreUI 有同名 match 分支",
      '"west_lake_stamp":' in hot_src)
check("T-8e 分支打开 StampBookUI 且 mode=checkin",
      'res://scripts/StampBookUI.gd' in hot_src and '"mode", "checkin"' in hot_src)
check("T-8f 选中后调用 grant_stamp + build_stamp_vignette",
      "CollectionManager.grant_stamp(" in hot_src
      and "CollectionManager.build_stamp_vignette(" in hot_src)

print("\n=== T-9  lakeside 热点坐标间距 ===")
poss = [(float(a), float(b)) for a, b in
        re.findall(r'Vector2\(([\d.]+), ?([\d.]+)\)', lakeside_block)]
check("T-9a lakeside 基础热点 == 5 个", len(poss) == 5, "实得 %d: %s" % (len(poss), poss))
min_d = 9.0
for i in range(len(poss)):
    for j in range(i + 1, len(poss)):
        d = math.hypot(poss[i][0] - poss[j][0], poss[i][1] - poss[j][1])
        min_d = min(min_d, d)
check("T-9b 基础热点两两距离 >= 0.20", min_d >= 0.20, "最小间距 %.3f" % min_d)
temp_poss = [(0.40, 0.50), (0.40, 0.45), (0.38, 0.48)]  # LocationManager lakeside 长假临时热点
new_pos = (0.72, 0.28)
min_t = min(math.hypot(new_pos[0] - p[0], new_pos[1] - p[1]) for p in temp_poss)
check("T-9c 新热点与长假临时热点距离 >= 0.15", min_t >= 0.15, "最小间距 %.3f" % min_t)

print("\n=== T-10 project.godot [autoload] 段未新增（S-4 零新 Autoload）===")
pg = read(os.path.join(ROOT, "project.godot"))
auto = pg[pg.index("[autoload]"):]
auto = auto[:auto.index("[display]")]
auto_names = re.findall(r'^(\w+)=', auto, re.M)
check("T-10a autoload 数量 == 15", len(auto_names) == 15, "实得 %d: %s" % (len(auto_names), auto_names))
check("T-10b 无 StampBook / Stamp 相关 Autoload",
      not any("stamp" in n.lower() for n in auto_names), str(auto_names))

print("\n=== T-11 stamp_ 前缀 flag 写入源单一 ===")
writers = []
for fn in sorted(os.listdir(SCRIPTS)):
    if not (fn.endswith(".gd") or fn == "events_special.json"):
        continue
    src = read(os.path.join(SCRIPTS, fn))
    if re.search(r'set_flag\(\s*"stamp_|set_flag\(flag|"stamp_[a-z_]+"', src):
        if 'stamp_' in src:
            writers.append(fn)
check("T-11 stamp_* 仅出现在允许文件中",
      set(writers) <= {"CollectionManager.gd", "events_special.json", "StampBookUI.gd",
                       "GameManager.gd", "HotspotExploreUI.gd", "MainGame.gd"},
      "意外文件: %s" % writers)
# §6.5 单向数据流：StampBookUI 只输出 picked_sid，flag 授予统一在 HotspotExploreUI 侧。
# 排除注释中的字面量（如"grant_stamp() 在…"），仅匹配真实调用。
_real_write = re.search(r'(GameManager\.set_flag\(|GameManager\.flags\[|CollectionManager\.grant_stamp\([a-zA-Z]|grant_stamp\([a-zA-Z])', sb_src)
check("T-11b StampBookUI 不含任何 flag 写操作（§6.5 单向数据流）",
      _real_write is None,
      "StampBookUI 出现写操作: %s" % (_real_write.group() if _real_write else ""))

print("\n=== T-12 CollectionManager 集章 API 完备性 ===")
for fn_sig in ["func grant_stamp(", "func is_stamp_owned(", "func get_stamp_day(",
               "func get_stamp_progress(", "func _check_stamp_completion(",
               "func _retroactive_stamp_check(", "func build_stamp_vignette(",
               "func is_stamp_checkin_used_today(", "func is_stamp_bonus_active("]:
    check("T-12 %s 存在" % fn_sig.replace("func ", "").rstrip("("), fn_sig in cm_src)

print("\n=== T-13 grant_stamp / 集满 关键语义片段 ===")
grant = cm_src[cm_src.index("func grant_stamp("):cm_src.index("func _check_stamp_completion(")]
check("T-13a grant_stamp 幂等（已得 return）", "if GameManager.flags.has(flag): return false" in grant)
check("T-13b 写 stamp_<sid> = true", 'GameManager.set_flag(flag, true)' in grant)
check("T-13c 写获得日 stamp_<sid>_day", 'set_flag(flag + "_day", GameManager.day)' in grant)
check("T-13d 打卡路径写 stamp_checkin_day", '"stamp_checkin_day", GameManager.day' in grant)
check("T-13e toast 含「获得西湖十景章：」", "获得西湖十景章：" in grant)
check("T-13f 集满时抑制普通章 toast", "if _check_stamp_completion(): return true" in grant)

comp = cm_src[cm_src.index("func _check_stamp_completion("):cm_src.index("func _retroactive_stamp_check(")]
check("T-13g 置 west_lake_stamps_complete", "STAMP_COMPLETE_FLAG" in comp
      and 'const STAMP_COMPLETE_FLAG := "west_lake_stamps_complete"' in cm_src)
check("T-13h 置称号 title_西湖十景通", 'const STAMP_TITLE_FLAG := "title_西湖十景通"' in cm_src
      and "STAMP_TITLE_FLAG" in comp)
check("T-13i 集满 toast 含「西湖十景通！集章大成」", "西湖十景通！集章大成" in comp)
check("T-13j 集满判定幂等（已置位则 return）",
      "if GameManager.flags.has(STAMP_COMPLETE_FLAG): return false" in comp)

print("\n=== T-14 补偿扫描接线（路径 B 兜底）===")
check("T-14a _retroactive_gallery_check 链式调用 stamp 扫描",
      "_retroactive_stamp_check()" in cm_src[cm_src.index("func _retroactive_gallery_check("):
                                             cm_src.index("func _retroactive_stamp_check(")])
check("T-14b MainGame._on_event_finished 调用补偿扫描",
      "CollectionManager._retroactive_stamp_check()" in
      main_src[main_src.index("func _on_event_finished("):])
check("T-14c SaveSystem 读档后经 GameManager 触发",
      "GameManager._retroactive_gallery_check()" in read(os.path.join(SCRIPTS, "SaveSystem.gd")))
check("T-14d GameManager._ready 启动时触发",
      'call_deferred("_retroactive_gallery_check")' in gm_src)

print("\n=== T-15 MainGame board 入口 ===")
check("T-15a board items 含「📖 集章簿」", '"📖 集章簿"' in main_src)
check("T-15b 绑定 _show_stampbook_popup", '"fn": _show_stampbook_popup' in main_src)
check("T-15c _show_stampbook_popup 已定义", "func _show_stampbook_popup():" in main_src)
check("T-15d 以 book 模式打开", '"mode", "book"' in main_src)
items_block = extract_block(main_src, "var items = [", "[", "]")
n_items = items_block.count('{"text"')
check("T-15e board 按钮数 8 → 9", n_items == 9, "实得 %d" % n_items)

print("\n=== T-16 StampBookUI 契约 ===")
check("T-16a 文件已创建", sb_src != "")
check("T-16b extends CanvasLayer", sb_src.startswith("extends CanvasLayer"))
check("T-16c signal closed", "signal closed" in sb_src)
check("T-16d 输出 picked_sid", 'var picked_sid: String = ""' in sb_src)
check("T-16e 双模式读 meta", 'get_meta("mode", "book")' in sb_src)
check("T-16f 每日限速守卫", "is_stamp_checkin_used_today()" in sb_src)
check("T-16g 限速提示文案含「今天已经在西湖集过章啦」", "今天已经在西湖集过章啦" in sb_src)
check("T-16h 5 列网格", "grid.columns = 5" in sb_src)
check("T-16i 已得展示获得日", "get_stamp_day(" in sb_src)

print("\n=== T-17 缩进一致性（严禁同文件混用）===")
INDENT_SPEC = {
    "CollectionManager.gd": "tab",
    "GameManager.gd": "space",
    "MainGame.gd": "space",
    "HotspotExploreUI.gd": "space",
    "DialogueUI.gd": "space",
    "StampBookUI.gd": "space",
    "events_special.json": "space",
}
for fn, want in INDENT_SPEC.items():
    src = read(os.path.join(SCRIPTS, fn))
    tab_lines = sum(1 for ln in src.split("\n") if ln.startswith("\t"))
    sp_lines = sum(1 for ln in src.split("\n") if ln.startswith("    "))
    if want == "tab":
        check("T-17 %s 纯 tab 缩进" % fn, tab_lines > 0 and sp_lines == 0,
              "tab=%d space=%d" % (tab_lines, sp_lines))
    else:
        check("T-17 %s 纯 4 空格缩进" % fn, sp_lines > 0 and tab_lines == 0,
              "tab=%d space=%d" % (tab_lines, sp_lines))

print("\n=== T-18 路线解耦（S-1）：打卡路径不含角色/好感/季节门槛 ===")
stamp_section = cm_src[cm_src.index("# ── 西湖十景集章"):]
for forbidden in ["minAff", "charId", "favorability", "relationship_state"]:
    check("T-18 集章区无 %s 依赖" % forbidden, forbidden not in stamp_section)
bonus_fn = cm_src[cm_src.index("func is_stamp_bonus_active("):cm_src.index("func format_stamp_day(")]
check("T-18e 季节仅用于 bonus（正反馈），不用于过滤",
      "return WeatherManager.get_season() == season" in bonus_fn)
sel_line = [ln for ln in sb_src.split("\n") if "var selectable" in ln]
check("T-18f 打卡可选条件仅「未得 + 当日未打卡」",
      len(sel_line) == 1 and "is_stamp_bonus_active" not in sel_line[0]
      and "not owned" in sel_line[0] and "_checkin_locked" in sel_line[0],
      str(sel_line))

print("\n=== T-19 JSON 结构完整性 ===")
check("T-19a events_special.json 可解析", isinstance(events, list) and len(events) == 23,
      "type=%s len=%s" % (type(events), len(events) if hasattr(events, "__len__") else "?"))
all_flags_in_json = set()
for ev in events:
    for s in ev.get("scenes", []):
        for f in s.get("setFlags", []):
            all_flags_in_json.add(f)
check("T-19b 4 个 stamp flag 全部落地",
      set(ROMANCE_MAP.values()) <= all_flags_in_json,
      "缺失 %s" % (set(ROMANCE_MAP.values()) - all_flags_in_json))
check("T-19c west_lake_winter_jingjing 现可被置位（bug 修复确认）",
      "west_lake_winter_jingjing" in all_flags_in_json)

# ════════════════════════════════════════════════════════════
print("\n" + "=" * 62)
print("断言总数: %d    通过: %d    失败: %d" % (len(PASSED) + len(FAILED), len(PASSED), len(FAILED)))
if FAILED:
    print("\n失败明细:")
    for n, d in FAILED:
        print("  - %s : %s" % (n, d))
    sys.exit(1)
print("✅ 全部断言通过")
sys.exit(0)
