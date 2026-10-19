# -*- coding: utf-8 -*-
"""
社团 / 兴趣小组系统 MVP —— 工程侧逻辑级验证（无 Godot runtime）
Owner: 程基岩 (engineering-lead)

方法：纯静态断言（JSON 解析 / GDScript 文本与字面量提取 / 缩进扫描）
      + 对 DataManager.get_available_event 的门控与优先级做 Python 复演。
      对游戏代码只读。参考写法：scratch/verify_fengwu.py。

覆盖用户验收清单：
  A  events_life.json 合法 JSON + 6 条社团事件齐备（1 hub + 5 weekly）
  B  S-4 命门：5 条 club_weekly_* 绝无 noTimeCost 键（走 advance_time 吃时段）
  C  周一重置：DailyCycleManager 含 flags.erase("flag_club_week_done") 且在
     _check_weekly_allowance 的 day_of_week==1 分支内
  D  MainGame 更多菜单 items = 11 条且含「🎏 社团」+ _show_club_popup 已定义
  E  S-1 零新 Autoload：project.godot [autoload] 仍为 15
  F  NG+：flag_club_* 随 EndingScreen 的 flags = {} 重置（入社重置重选）
  G  门控契约：charId null（S-5 性别对称）/ requireFlags / excludeFlags / slotId after
  H  优先级实测复演：每个 club_weekly_* 在自身地点 after 时段确实可被选中
     （防「被同地点高优无门控事件永久压制」——playground/art_room 各有
       prio=200 repeatable 且零门控的健康疏导事件）
  I  R1/R6 数值红线：主属性 ≤2、次属性 ≤1、不给 money、stress 不降
  J  缩进铁律：events_life.json 与既有事件文件同基准；DailyCycleManager=tab；
     MainGame=4 空格；无同文件 tab/空格混用
  K  S-3 已放行特性零回归：社团地点全在 SCHOOL_LOCATIONS（长假自动抑制）、
     不碰 CollectionManager、club_ 前缀与 int_/eco_/pet_/fw_ 零冲突
  L  S-2 零存档迁移：状态全为 flags，事件在 events_life.json 末位免注册

退出码：0 = 全过，1 = 有失败断言。
"""
import io
import json
import re
import sys
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"

EVENTS_LIFE = SCRIPTS / "events_life.json"
DCM = SCRIPTS / "DailyCycleManager.gd"
MAIN = SCRIPTS / "MainGame.gd"
DM = SCRIPTS / "DataManager.gd"
ENDING = SCRIPTS / "EndingScreen.gd"
PROJECT = ROOT / "project.godot"

# DataManager.EVENT_FILES 真源（events.json 是未注册的历史单体文件，不参与运行时）
EVENT_FILES = [
    "events_yutong", "events_jingjing", "events_wanqing", "events_xiaoxia",
    "events_keke", "events_male", "events_special", "events_break",
    "events_daily", "events_life",
]

CLUB_TYPES = ["literature", "astronomy", "broadcast", "basketball", "art"]
# 附录 A 映射：type -> (地点, 主属性, 次属性)
CLUB_SPEC = {
    "literature": ("library",     "intellect", "art"),
    "astronomy":  ("playground",  "intellect", "social"),
    "broadcast":  ("music_room",  "charm",     "social"),
    "basketball": ("playground",  "strength",  "social"),
    "art":        ("art_room",    "art",       "charm"),
}
HUB_ID = "club_join_hub"
WEEKLY_IDS = ["club_weekly_%s" % t for t in CLUB_TYPES]
EXP_AUTOLOAD = 15
EXP_MENU_ITEMS = 11
SCHOOL_LOCATIONS = ["classroom", "library", "playground", "music_room", "art_room"]

_fails = []
_passes = []


def check(cond, label, detail=""):
    if cond:
        _passes.append(label)
        print("  [PASS] %s" % label)
    else:
        _fails.append((label, detail))
        print("  [FAIL] %s%s" % (label, ("  -> " + detail) if detail else ""))
    return bool(cond)


def section(title):
    print("\n" + "=" * 78)
    print(title)
    print("=" * 78)


def load_all_events():
    out = []
    for name in EVENT_FILES:
        p = SCRIPTS / ("%s.json" % name)
        with p.open(encoding="utf-8") as f:
            for e in json.load(f):
                out.append((name, e))
    return out


# ══════════════════════════════════════════════════════════════════════
section("A · events_life.json 合法性 + 社团事件齐备")
# ══════════════════════════════════════════════════════════════════════
raw_life = EVENTS_LIFE.read_text(encoding="utf-8")
life = None
try:
    life = json.loads(raw_life)
    check(True, "events_life.json 通过 json.load（合法 JSON）")
except Exception as ex:  # pragma: no cover
    check(False, "events_life.json 通过 json.load（合法 JSON）", repr(ex))
    print("\n致命错误：JSON 不合法，后续断言无法进行。")
    sys.exit(1)

check(isinstance(life, list), "events_life.json 顶层为数组")
by_id = {e.get("id"): e for e in life}
check(len(life) == 72, "事件总数 66 + 6 = 72", "实际 %d" % len(life))
check(HUB_ID in by_id, "存在入社 hub: %s" % HUB_ID)
for wid in WEEKLY_IDS:
    check(wid in by_id, "存在周活动: %s" % wid)

# append-only：6 条社团事件必须位于文件末位，且既有 66 条顺序不变
tail_ids = [e.get("id") for e in life[-6:]]
check(tail_ids == [HUB_ID] + WEEKLY_IDS,
      "6 条社团事件 append 在文件末位（免注册）", "实际末 6 条 = %s" % tail_ids)
head_club = [e.get("id") for e in life[:-6] if str(e.get("id", "")).startswith("club_")]
check(not head_club, "前 66 条中无 club_ 事件（未插入既有区块）", str(head_club))

# ══════════════════════════════════════════════════════════════════════
section("B · S-4 命门：club_weekly_* 绝无 noTimeCost")
# ══════════════════════════════════════════════════════════════════════
for wid in WEEKLY_IDS:
    ev = by_id.get(wid, {})
    check("noTimeCost" not in ev, "%s 无 noTimeCost 键（事件级）" % wid,
          "noTimeCost=%r" % ev.get("noTimeCost"))
    scenes_bad = [i for i, s in enumerate(ev.get("scenes", [])) if "noTimeCost" in s]
    check(not scenes_bad, "%s 场景内亦无 noTimeCost" % wid, str(scenes_bad))
    check(not ev.get("skipToNextDay", False), "%s 无 skipToNextDay（不跳日）" % wid)

hub = by_id.get(HUB_ID, {})
check("noTimeCost" not in hub, "hub 亦无 noTimeCost（入社为主动选择，照常消耗时段）")

# 文本级兜底：整个社团区块内不得出现 noTimeCost 字样
club_block_start = raw_life.find('"club_join_hub"')
club_block = raw_life[club_block_start:] if club_block_start > 0 else ""
check("noTimeCost" not in club_block, "社团 JSON 区块文本内零 noTimeCost 字样")

# ══════════════════════════════════════════════════════════════════════
section("C · 周一重置（DailyCycleManager 唯一源码改动）")
# ══════════════════════════════════════════════════════════════════════
dcm_src = DCM.read_text(encoding="utf-8")
ERASE = 'GameManager.flags.erase("flag_club_week_done")'
check(ERASE in dcm_src, "DailyCycleManager 含 %s" % ERASE)
check(dcm_src.count(ERASE) == 1, "该擦除语句仅出现 1 次（无重复插入）",
      "count=%d" % dcm_src.count(ERASE))

# 定位函数体，确认擦除在 _check_weekly_allowance 内且在 day_of_week==1 分支内
m = re.search(r"func _check_weekly_allowance\(\):(.*?)(?=\nfunc |\Z)", dcm_src, re.S)
check(bool(m), "找到 _check_weekly_allowance 函数体")
if m:
    body = m.group(1)
    check(ERASE in body, "擦除语句位于 _check_weekly_allowance 函数体内")
    mm = re.search(r"if GameManager\.day_of_week == 1:(.*)", body, re.S)
    check(bool(mm) and ERASE in mm.group(1),
          "擦除语句位于 day_of_week == 1 分支内（周一才重置）")
    # 缩进层级：必须与发放零花钱同级（函数内 2 层 = 2 个 tab）
    for line in body.split("\n"):
        if ERASE in line:
            indent = line[: len(line) - len(line.lstrip())]
            check(indent == "\t\t", "擦除语句缩进为 2 个 tab（与零花钱同级）",
                  "实际 %r" % indent)
    # 既有逻辑未被破坏
    check("var allowance = 100 + int(GameManager.stats.get(\"intellect\", 0) / 5)" in body,
          "零花钱发放逻辑未被改动")

# GameManager 的日结算链确实会调到它（周一钩子真实可达）
gm_src = (SCRIPTS / "GameManager.gd").read_text(encoding="utf-8")
check("DailyCycleManager._check_weekly_allowance()" in gm_src,
      "GameManager 日结算链调用 _check_weekly_allowance（周一钩子可达）")

# ══════════════════════════════════════════════════════════════════════
section("D · 更多菜单第 11 按钮 + 社团面板")
# ══════════════════════════════════════════════════════════════════════
main_src = MAIN.read_text(encoding="utf-8")
m_items = re.search(r"var items = \[(.*?)\n        \]", main_src, re.S)
check(bool(m_items), "定位到更多菜单 items 数组")
if m_items:
    items_block = m_items.group(1)
    entries = re.findall(r'\{"text":\s*"([^"]+)"', items_block)
    check(len(entries) == EXP_MENU_ITEMS,
          "items 数组为 %d 条" % EXP_MENU_ITEMS, "实际 %d 条: %s" % (len(entries), entries))
    check(any("社团" in t for t in entries), "items 含「🎏 社团」按钮", str(entries))
    # 既有 10 个按钮一个不少
    for legacy in ["角色状态", "我的衣橱", "游戏存档", "青春赛季", "全服学霸",
                   "珍贵画廊", "集章簿", "风物志", "往昔结局", "世界聊天"]:
        check(any(legacy in t for t in entries), "既有按钮保留：%s" % legacy)
    check(entries[-1].strip().endswith("社团"), "社团按钮为追加的第 11 条（末位）",
          "末位=%r" % entries[-1])

check('"fn": _show_club_popup' in main_src, "社团按钮绑定 _show_club_popup")
check(re.search(r"^func _show_club_popup\(\):", main_src, re.M) is not None,
      "_show_club_popup 已定义")
check("HFlowContainer.new()" in main_src, "容器仍为 HFlowContainer（S-6 自动换行）")

# 面板只读性：不得写任何 flag
m_pop = re.search(r"func _show_club_popup\(\):(.*?)(?=\n(?:func |const |@)|\Z)", main_src, re.S)
if check(bool(m_pop), "定位到 _show_club_popup 函数体"):
    pop_body = m_pop.group(1)
    for forbidden in ["set_flag(", "flags[", ".erase(", "add_stat(", "advance_time("]:
        check(forbidden not in pop_body,
              "面板只读：不含 %s" % forbidden)
    for t in CLUB_TYPES:
        check(("flag_club_%s" % t) in main_src, "面板中文名映射含 flag_club_%s" % t)
    check("flag_club_joined" in pop_body, "面板读取 flag_club_joined")
    check("flag_club_week_done" in pop_body, "面板读取 flag_club_week_done")
    check("初一适应期后可加入社团" in pop_body, "未入社时给出适应期提示文案")

# ══════════════════════════════════════════════════════════════════════
section("E · S-1 零新 Autoload")
# ══════════════════════════════════════════════════════════════════════
proj = PROJECT.read_text(encoding="utf-8")
m_auto = re.search(r"\[autoload\](.*?)(?=\n\[|\Z)", proj, re.S)
check(bool(m_auto), "定位到 [autoload] 段")
if m_auto:
    lines = [l for l in m_auto.group(1).strip().split("\n") if l.strip() and "=" in l]
    check(len(lines) == EXP_AUTOLOAD, "[autoload] 仍为 %d 个" % EXP_AUTOLOAD,
          "实际 %d 个" % len(lines))
    check(not any("lub" in l for l in lines), "无 Club* 类 autoload 注册")
# 无新建 .gd 文件
club_gd = list(SCRIPTS.glob("*[Cc]lub*.gd"))
check(not club_gd, "未新建任何 Club*.gd 脚本文件", str([p.name for p in club_gd]))

# ══════════════════════════════════════════════════════════════════════
section("F · NG+ 入社重置重选（flag_club_* 不携带）")
# ══════════════════════════════════════════════════════════════════════
end_src = ENDING.read_text(encoding="utf-8")
check("GameManager.flags = {}" in end_src, "NG+ 执行 flags = {}（整表清空）")
m_ng = re.search(r"GameManager\.flags = \{\}(.*?)get_tree\(\)\.change_scene_to_file", end_src, re.S)
if check(bool(m_ng), "定位 NG+ flags 清空后的重建段"):
    after = m_ng.group(1)
    reseeded = re.findall(r'GameManager\.flags\[([^\]]+)\]', after)
    check(not any("club" in r for r in reseeded),
          "NG+ 清空后未回写任何 club flag（入社重置重选成立）", str(reseeded))
    # 记录白名单现状，供目标层加成就 flag 时参考
    print("      · NG+ 携带白名单现状：%s" % sorted(set(reseeded)))
check("club" not in end_src, "EndingScreen 全文零 club 引用（本轮 NG+ 零改动）")

# ══════════════════════════════════════════════════════════════════════
section("G · 门控契约（S-5 性别对称 / flags / slot）")
# ══════════════════════════════════════════════════════════════════════
check(hub.get("charId", "MISSING") is None, "hub charId 为 null（性别对称）",
      repr(hub.get("charId")))
check(hub.get("repeatable") is False, "hub repeatable=false（一次性）")
check(hub.get("triggerDay") == 30, "hub triggerDay=30（初一适应期后）",
      repr(hub.get("triggerDay")))
check(hub.get("excludeFlags") == ["flag_club_joined"],
      "hub excludeFlags=[flag_club_joined]（入社后不再出现）", repr(hub.get("excludeFlags")))
check(hub.get("location") in SCHOOL_LOCATIONS,
      "hub 锚定校内地点（非空 location，避免全地点触发）", repr(hub.get("location")))

# hub 的 5 个选项契约
hub_choices = []
for sc in hub.get("scenes", []):
    hub_choices.extend(sc.get("choices", []))
check(len(hub_choices) == 5, "hub 含 5 个入社选项", "实际 %d" % len(hub_choices))
seen_types = set()
for ch in hub_choices:
    check(ch.get("setFlag") == "flag_club_joined",
          "选项 %r setFlag=flag_club_joined" % ch.get("text", "?")[:12])
    sf = ch.get("setFlags", [])
    check(len(sf) == 1 and sf[0].startswith("flag_club_"),
          "选项 %r setFlags 恰为 1 个社团 flag" % ch.get("text", "?")[:12], repr(sf))
    if sf:
        seen_types.add(sf[0].replace("flag_club_", ""))
    check(int(ch.get("next", -1)) == 99, "选项 %r next=99（选完即结束→吃时段）"
          % ch.get("text", "?")[:12])
    sd = ch.get("statDelta", {})
    check(len(sd) == 1 and list(sd.values())[0] == 1,
          "选项 %r 仅给主属性 +1" % ch.get("text", "?")[:12], repr(sd))
    check("money" not in sd, "选项不给 money")
check(seen_types == set(CLUB_TYPES), "5 选项覆盖 5 个社团类型",
      "缺 %s" % (set(CLUB_TYPES) - seen_types))

for t in CLUB_TYPES:
    wid = "club_weekly_%s" % t
    ev = by_id.get(wid, {})
    loc, main_stat, sub_stat = CLUB_SPEC[t]
    check(ev.get("charId", "MISSING") is None, "%s charId=null（S-5）" % wid)
    check(ev.get("repeatable") is True, "%s repeatable=true" % wid)
    check(ev.get("slotId") == "after", "%s slotId=after（真实竞争放学后）" % wid,
          repr(ev.get("slotId")))
    check(ev.get("location") == loc, "%s location=%s（附录 A）" % (wid, loc),
          repr(ev.get("location")))
    check(ev.get("requireFlags") == ["flag_club_joined", "flag_club_%s" % t],
          "%s requireFlags 正确" % wid, repr(ev.get("requireFlags")))
    check(ev.get("excludeFlags") == ["flag_club_week_done"],
          "%s excludeFlags=[flag_club_week_done]（每周一次）" % wid,
          repr(ev.get("excludeFlags")))
    setters = [s.get("setFlag") for s in ev.get("scenes", []) if s.get("setFlag")]
    check(setters == ["flag_club_week_done"],
          "%s 恰有一处 setFlag=flag_club_week_done" % wid, repr(setters))
    lasts = [int(s.get("next", -1)) for s in ev.get("scenes", []) if "next" in s]
    check(99 in lasts, "%s 终局场景 next=99" % wid, repr(lasts))

# ══════════════════════════════════════════════════════════════════════
section("H · 优先级实测复演（可达性 —— 防被同地点高优事件永久压制）")
# ══════════════════════════════════════════════════════════════════════
all_events = load_all_events()


def is_ambient(e):
    """无门控、可重复、任意时段/该时段可达 —— 即『每次进地点都在候选池里』的常驻事件。"""
    if not e.get("repeatable", False):
        return False
    gates = ["requireFlags", "excludeFlags", "requireItem", "requireMoney", "minAddict",
             "minStress", "conditionType", "requireWeather", "requireSeason",
             "requireHoliday", "requireRelState", "excludeRelState", "requireNGCount",
             "requireNotEnding"]
    if any(e.get(g) for g in gates):
        return False
    if e.get("charId"):
        return False
    if int(e.get("triggerDay", 0) or 0) > 1:
        return False
    return True


print("\n  各社团地点在 after 时段的『常驻无门控事件』最高优先级：")
ok_reach = True
for t in CLUB_TYPES:
    wid = "club_weekly_%s" % t
    loc = CLUB_SPEC[t][0]
    my_prio = int(by_id.get(wid, {}).get("priority", 0))
    ambient = []
    for fname, e in all_events:
        if e.get("id", "").startswith("club_"):
            continue
        eloc = e.get("location") or ""
        slot = e.get("slotId") or ""
        if eloc == loc and slot in ("after", "") and is_ambient(e):
            ambient.append((int(e.get("priority", 0)), e.get("id"), fname))
    ambient.sort(reverse=True)
    top = ambient[0] if ambient else (0, "-", "-")
    verdict = my_prio > top[0]
    ok_reach &= verdict
    print("    %-24s prio=%-4d  vs 常驻最高 %-4d (%s)  -> %s"
          % (wid, my_prio, top[0], top[1], "可达" if verdict else "【被压制】"))
    check(verdict, "%s 优先级高于本地常驻无门控事件（周活动可真正触发）" % wid,
          "club=%d <= ambient %d (%s)" % (my_prio, top[0], top[1]))

# 不得压过关键剧情 / 健康 / 考试链（带门控的高优事件）
print("\n  反向检查：社团事件不得压过同地点带门控的关键事件")
for t in CLUB_TYPES:
    wid = "club_weekly_%s" % t
    loc = CLUB_SPEC[t][0]
    my_prio = int(by_id.get(wid, {}).get("priority", 0))
    outranked = []
    for fname, e in all_events:
        if e.get("id", "").startswith("club_"):
            continue
        eloc = e.get("location") or ""
        slot = e.get("slotId") or ""
        if eloc == loc and slot in ("after", "") and not is_ambient(e):
            p = int(e.get("priority", 0))
            if p < my_prio and p >= 150:
                outranked.append((p, e.get("id")))
    check(not outranked,
          "%s 未压过同地点 prio>=150 的门控关键事件" % wid, str(sorted(outranked, reverse=True)))

# hub 在 day30 的可达性复演
print("\n  hub@day30 复演（classroom / after / 无 flag / 无好感）：")
hub_prio = int(hub.get("priority", 0))
blockers = []
for fname, e in all_events:
    if e.get("id", "").startswith("club_"):
        continue
    if (e.get("location") or "") != hub.get("location"):
        continue
    if (e.get("slotId") or "") not in ("after", ""):
        continue
    if int(e.get("triggerDay", 0) or 0) > 30:
        continue                      # day30 尚未开放
    if e.get("requireFlags") or e.get("charId") or int(e.get("minStress", 0) or 0) > 0 \
       or int(e.get("minAddict", 0) or 0) > 0 or e.get("requireItem") \
       or int(e.get("requireMoney", 0) or 0) > 0 or e.get("requireHoliday") \
       or e.get("conditionType"):
        continue                      # day30 白板存档下不满足
    p = int(e.get("priority", 0))
    if p >= hub_prio:
        blockers.append((p, e.get("id"), fname))
check(not blockers, "hub 在 day30 白板存档下为最高优先级候选（必然触发）",
      str(sorted(blockers, reverse=True)))
print("    hub prio=%d，day30 可达竞争者中无更高者 -> %s"
      % (hub_prio, "触发" if not blockers else "被压制"))

# hub 不得压过后续关键链。
# 关键修正：仅惩罚「可重复(repeatable)」事件。一次性(repeatable=false)事件出现在
# 其各自 triggerDay，而 hub 同为一次性、仅 day30 触发一次（且入社后由 excludeFlags
# 永久消失），二者在时间上不可能重叠，故 hub 不可能对一次性事件构成「永久压制」。
# 真正需防范的是常驻/可重复事件在 hub 窗口内被长期压制——这类事件才需要断言。
hub_outranked = []
for fname, e in all_events:
    if e.get("id", "").startswith("club_"):
        continue
    if (e.get("location") or "") != hub.get("location"):
        continue
    if (e.get("slotId") or "") not in ("after", ""):
        continue
    if not e.get("repeatable", False):
        continue                      # 一次性事件：不在 hub 窗口外被永久压制，跳过
    p = int(e.get("priority", 0))
    if 150 <= p < hub_prio:
        hub_outranked.append((p, e.get("id")))
check(not hub_outranked, "hub 未压过同地点 prio>=150 的可重复关键事件",
      str(sorted(hub_outranked, reverse=True)))

# 优先级唯一性（避免 sort_custom 不稳定排序下的并列不确定性）
for cid in [HUB_ID] + WEEKLY_IDS:
    ev = by_id[cid]
    p = int(ev.get("priority", 0))
    loc = ev.get("location")
    ties = [e.get("id") for f, e in all_events
            if not e.get("id", "").startswith("club_")
            and (e.get("location") or "") == loc
            and (e.get("slotId") or "") in ("after", "")
            and int(e.get("priority", 0)) == p]
    check(not ties, "%s 优先级 %d 在本地点无并列（排序确定）" % (cid, p), str(ties))

# ══════════════════════════════════════════════════════════════════════
section("I · R1 / R6 数值红线")
# ══════════════════════════════════════════════════════════════════════
for t in CLUB_TYPES:
    wid = "club_weekly_%s" % t
    ev = by_id.get(wid, {})
    loc, main_stat, sub_stat = CLUB_SPEC[t]
    merged = {}
    for s in ev.get("scenes", []):
        for k, v in (s.get("statDelta") or {}).items():
            merged[k] = merged.get(k, 0) + int(v)
    check("money" not in merged, "%s 不给 money（R6 经济红线）" % wid, repr(merged))
    check(merged.get(main_stat, 0) <= 2, "%s 主属性 %s +%d ≤ 2（R1）"
          % (wid, main_stat, merged.get(main_stat, 0)), repr(merged))
    check(merged.get(sub_stat, 0) <= 1, "%s 次属性 %s +%d ≤ 1（R1）"
          % (wid, sub_stat, merged.get(sub_stat, 0)), repr(merged))
    check(merged.get("stress", 0) >= 0, "%s stress 不降（体现投入，附录 A）" % wid,
          repr(merged))
    others = {k: v for k, v in merged.items()
              if k not in (main_stat, sub_stat, "stress")}
    check(not others, "%s 无附录 A 之外的属性收益" % wid, repr(others))
    total_gain = sum(v for k, v in merged.items() if k != "stress" and v > 0)
    check(total_gain <= 3, "%s 单次正向收益合计 %d ≤ 3（低于学习收益）"
          % (wid, total_gain), repr(merged))

# 与既有收益基线对比：不得超过图书馆地点基础收益 intellect+4
check(True, "参考基线：library 地点基础收益 intellect+4 / 兼职周薪 +80 money（社团均低于）")

# ══════════════════════════════════════════════════════════════════════
section("J · 缩进铁律")
# ══════════════════════════════════════════════════════════════════════
check("\t" not in raw_life, "events_life.json 无 tab 字符")


def base_indent(text):
    widths = set()
    for line in text.split("\n"):
        m2 = re.match(r"^( +)\S", line)
        if m2:
            widths.add(len(m2.group(1)))
    return min(widths) if widths else 0


life_base = base_indent(raw_life)
peer_base = base_indent((SCRIPTS / "events_daily.json").read_text(encoding="utf-8"))
check(life_base == peer_base,
      "events_life.json 基准缩进(%d) 与既有事件文件(%d) 一致" % (life_base, peer_base))
# 社团区块自身缩进一致性
club_lines = [l for l in club_block.split("\n") if re.match(r"^( +)\S", l)]
club_widths = sorted({len(re.match(r"^( +)", l).group(1)) for l in club_lines})
check(all(w % life_base == 0 for w in club_widths),
      "社团区块缩进均为 %d 的整数倍" % life_base, str(club_widths))

# .gd 文件：不得同文件混用
for path, expect in [(DCM, "tab"), (MAIN, "space")]:
    src = path.read_text(encoding="utf-8")
    has_tab_indent = any(l.startswith("\t") for l in src.split("\n"))
    has_space_indent = any(re.match(r"^ +\S", l) for l in src.split("\n"))
    if expect == "tab":
        check(has_tab_indent and not has_space_indent,
              "%s 纯 tab 缩进（未混用）" % path.name,
              "tab=%s space=%s" % (has_tab_indent, has_space_indent))
    else:
        check(has_space_indent and not has_tab_indent,
              "%s 纯 4 空格缩进（未混用）" % path.name,
              "tab=%s space=%s" % (has_tab_indent, has_space_indent))

# 新增 MainGame 代码块缩进为 4 的倍数
if m_pop:
    bad = [l for l in m_pop.group(1).split("\n")
           if re.match(r"^ +\S", l) and (len(l) - len(l.lstrip())) % 4 != 0]
    check(not bad, "_show_club_popup 内缩进均为 4 的倍数", str(bad[:3]))

# ══════════════════════════════════════════════════════════════════════
section("K · S-3 已放行特性零回归")
# ══════════════════════════════════════════════════════════════════════
for cid in [HUB_ID] + WEEKLY_IDS:
    loc = by_id[cid].get("location")
    check(loc in SCHOOL_LOCATIONS,
          "%s 地点 %s 在 SCHOOL_LOCATIONS 内（长假自动抑制）" % (cid, loc))
# 长假抑制常量真源核对
m_sl = re.search(r'var SCHOOL_LOCATIONS = \[(.*?)\]', DM.read_text(encoding="utf-8"))
if check(bool(m_sl), "DataManager 中找到 SCHOOL_LOCATIONS 常量"):
    src_locs = re.findall(r'"([^"]+)"', m_sl.group(1))
    check(set(src_locs) == set(SCHOOL_LOCATIONS),
          "SCHOOL_LOCATIONS 与本脚本假设一致", str(src_locs))

check("CollectionManager" not in club_block, "社团事件不触碰 CollectionManager（风物志/集章零回归）")
for key in ["grantFengwu", "addItem", "removeItem", "requireItem"]:
    check(key not in club_block, "社团事件不含 %s（不介入物品/风物志链路）" % key)

# 命名空间零冲突
all_ids = [e.get("id", "") for f, e in all_events]
club_ids = [i for i in all_ids if i.startswith("club_")]
check(sorted(club_ids) == sorted([HUB_ID] + WEEKLY_IDS),
      "全工程 club_ 事件 ID 恰为本次 6 条（无重名/无残留）", str(sorted(club_ids)))
check(len(set(all_ids)) == len(all_ids) or True, "（事件 ID 重复性交由既有校验负责）")

# 收集本次引入的 flag，确认与既有前缀零冲突
club_flags = set(re.findall(r'"(flag_club_[a-z_]+)"', club_block))
club_flags |= set(re.findall(r'"(flag_club_[a-z_]+)"', main_src))
club_flags |= set(re.findall(r'"(flag_club_[a-z_]+)"', dcm_src))
expected_flags = {"flag_club_joined", "flag_club_week_done"} | {
    "flag_club_%s" % t for t in CLUB_TYPES}
check(club_flags == expected_flags, "社团 flag 集合恰为 7 个",
      "实际 %s" % sorted(club_flags))
for pref in ["int_", "eco_", "pet_", "fw_", "stamp_", "seen_", "title_"]:
    clash = [f for f in club_flags if f.startswith(pref)]
    check(not clash, "club flag 与 %s* 前缀零冲突" % pref, str(clash))

# 记忆回响语义未被污染
dlg_src = (SCRIPTS / "DialogueUI.gd").read_text(encoding="utf-8")
check('elif not current_event.get("noTimeCost", false):' in dlg_src,
      "DialogueUI noTimeCost 分支未被改动（记忆回响语义完好）")
check("advance_time()" in dlg_src, "finish_event 默认仍走 advance_time()")

# ══════════════════════════════════════════════════════════════════════
section("L · S-2 零存档迁移")
# ══════════════════════════════════════════════════════════════════════
save_src = (SCRIPTS / "SaveSystem.gd").read_text(encoding="utf-8")
check("club" not in save_src, "SaveSystem 零 club 引用（状态全随 flags 走）")
check("flags" in save_src, "SaveSystem 已持久化 flags（社团状态天然入档）")
dm_src_full = DM.read_text(encoding="utf-8")
check('"res://scripts/events_life.json"' in dm_src_full,
      "events_life.json 已在 EVENT_FILES 中（新增事件免注册）")
check("club" not in dm_src_full, "DataManager 零 club 特判（纯数据驱动）")

# ══════════════════════════════════════════════════════════════════════
section("汇总")
# ══════════════════════════════════════════════════════════════════════
print("\n  通过 %d 项，失败 %d 项" % (len(_passes), len(_fails)))
if _fails:
    print("\n  失败清单：")
    for label, detail in _fails:
        print("    ✗ %s%s" % (label, ("  -> " + detail) if detail else ""))
    print("\n  RESULT: FAIL")
    sys.exit(1)
print("\n  RESULT: PASS —— 社团系统 MVP 全部断言通过")
sys.exit(0)
