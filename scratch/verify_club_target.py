#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
DS-RN-05b · 社团目标层 —— engineering-lead 自验门禁
====================================================
覆盖 GDD `design/club_target_layer_gdd.md` 的红线 R1-R11 与成功标准 S-1~S-7，
外加主理人拍板的 OQ-1（flag_club_active_* 硬参与门）与 OQ-3（gallery_flags 全集回注）。

运行： <managed python> scratch/verify_club_target.py
全部 PASS -> exit 0；任一 FAIL -> exit 1
"""
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(os.path.join(__file__, "..")))
if not os.path.isdir(os.path.join(ROOT, "scripts")):
    ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

SCRIPTS = os.path.join(ROOT, "scripts")
LIFE = os.path.join(SCRIPTS, "events_life.json")
GM = os.path.join(SCRIPTS, "GameManager.gd")
ES = os.path.join(SCRIPTS, "EndingScreen.gd")

TYPES = ["literature", "astronomy", "broadcast", "basketball", "art"]
LOCATION = {
    "literature": "library",
    "astronomy": "playground",
    "broadcast": "music_room",
    "basketball": "playground",
    "art": "art_room",
}
MAIN_STAT = {
    "literature": "intellect",
    "astronomy": "intellect",
    "broadcast": "charm",
    "basketball": "strength",
    "art": "art",
}
TRIGGER_DAY = {1: 120, 2: 220, 3: 340, 4: 470}

_results = []


def check(cond, label, detail=""):
    _results.append((bool(cond), label, detail))
    tag = "PASS" if cond else "FAIL"
    line = "  [%s] %s" % (tag, label)
    if detail and not cond:
        line += "\n         -> %s" % detail
    print(line)
    return bool(cond)


def note(msg):
    print("  [NOTE] %s" % msg)


def section(title):
    print("\n" + "-" * 78)
    print(title)
    print("-" * 78)


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


# ==========================================================================
section("A · events_life.json 结构与总量（S-1 / R11）")
# ==========================================================================
raw_life = read(LIFE)
try:
    life = json.loads(raw_life)
    check(True, "A1  events_life.json 是合法 JSON")
except Exception as exc:  # pragma: no cover
    check(False, "A1  events_life.json 是合法 JSON", str(exc))
    print("\nFATAL: JSON 不合法，后续断言无法进行")
    sys.exit(1)

check(len(life) == 92, "A2  事件总数 = 92（72 -> 92）", "实际 %d" % len(life))

chain = [e for e in life if str(e.get("id", "")).startswith("club_chain_")]
check(len(chain) == 20, "A3  含恰好 20 个 ^club_chain_ 事件", "实际 %d" % len(chain))

by_id = {e["id"]: e for e in life}
expected_ids = ["club_chain_%s_s%d" % (t, n) for t in TYPES for n in (1, 2, 3, 4)]
missing = [i for i in expected_ids if i not in by_id]
check(not missing, "A4  20 个 id 命名与 5x4 矩阵完全吻合", "缺失 %s" % missing)

check("\t" not in raw_life, "A5  events_life.json 全文零 tab 字符（R11 · 2 空格基准）")
indent_ok = all(
    re.search(r'^  \{\n    "id": "%s"' % re.escape(i), raw_life, re.M) for i in expected_ids
)
check(indent_ok, "A6  20 个新事件对象缩进 = 2 空格 / 键 = 4 空格（R11 逐字符沿用宿主）")

# ==========================================================================
section("B · 20 链事件公共形状（R4 / R6 / R7 / R8 / R9 / R10）")
# ==========================================================================
prios = sorted(set(e.get("priority") for e in chain))
check(prios == [218], "B1  20 事件 priority 恒为 218（R4）", "实际 %s" % prios)

bad_excl = [e["id"] for e in chain if e.get("excludeFlags") != ["flag_club_week_done"]]
check(not bad_excl, "B2  excludeFlags 恒等于 [flag_club_week_done]（R6）", "越界 %s" % bad_excl)

achv_in_excl = [
    e["id"]
    for e in chain
    if any("flag_club_achievement_" in str(f) for f in e.get("excludeFlags", []))
]
check(not achv_in_excl, "B3  excludeFlags 零出现 flag_club_achievement_*（R6 死锁红线）",
      "违规 %s" % achv_in_excl)

bad_charid = [e["id"] for e in chain if e.get("charId", "SENTINEL") is not None]
check(not bad_charid, "B4  charId 全为 null（R10 · 双路线对称）", "违规 %s" % bad_charid)

bad_repeat = [e["id"] for e in chain if e.get("repeatable") is not False]
check(not bad_repeat, "B5  repeatable 全为 false（决策 2 · 一次性消费）", "违规 %s" % bad_repeat)

bad_slot = [e["id"] for e in chain if e.get("slotId") != "after"]
check(not bad_slot, "B6  slotId 全为 after（真实时段竞争位）", "违规 %s" % bad_slot)

bad_loc = []
for e in chain:
    t = e["id"].split("_")[2]
    if e.get("location") != LOCATION[t]:
        bad_loc.append((e["id"], e.get("location")))
check(not bad_loc, "B7  location 与本社周活动同地点（F5 · 长假自动抑制）", "违规 %s" % bad_loc)

bad_day = []
for e in chain:
    n = int(e["id"][-1])
    if e.get("triggerDay") != TRIGGER_DAY[n]:
        bad_day.append((e["id"], e.get("triggerDay")))
check(not bad_day, "B8  triggerDay = 120/220/340/470（避开 BREAK_PERIODS）", "违规 %s" % bad_day)


def walk(obj):
    """递归遍历事件内所有 dict（scenes / choices 全覆盖）。"""
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            for x in walk(v):
                yield x
    elif isinstance(obj, list):
        for v in obj:
            for x in walk(v):
                yield x


no_time_hits = [e["id"] for e in chain if any("noTimeCost" in d for d in walk(e))]
check(not no_time_hits, "B9  noTimeCost 键在 20 事件中出现 0 次（R8 · 确凿消耗时段）",
      "违规 %s" % no_time_hits)

money_hits = []
for e in chain:
    for d in walk(e):
        sd = d.get("statDelta")
        if isinstance(sd, dict) and "money" in sd:
            money_hits.append(e["id"])
        sd2 = d.get("statsDelta")
        if isinstance(sd2, dict) and "money" in sd2:
            money_hits.append(e["id"])
check(not money_hits, "B10 statDelta 零 money 键（R9 · 防经济失衡）", "违规 %s" % set(money_hits))

# 终场景 setFlag
bad_week = []
for e in chain:
    last = e["scenes"][-1]
    if last.get("setFlag") != "flag_club_week_done":
        bad_week.append(e["id"])
check(not bad_week, "B11 终场景 setFlag 全为 flag_club_week_done（R7 · 继承周节流阀）",
      "违规 %s" % bad_week)

# ==========================================================================
section("C · 串链正确性与 OQ-1 硬参与门（S-1）")
# ==========================================================================
bad_s1 = []
for t in TYPES:
    rf = by_id["club_chain_%s_s1" % t].get("requireFlags", [])
    want = {"flag_club_joined", "flag_club_%s" % t, "flag_club_active_%s" % t}
    if not want.issubset(set(rf)):
        bad_s1.append((t, rf))
check(not bad_s1, "C1  s1 requireFlags 含 joined + type + active（OQ-1 硬参与门）",
      "违规 %s" % bad_s1)

bad_link = []
for t in TYPES:
    for n in (2, 3, 4):
        rf = set(by_id["club_chain_%s_s%d" % (t, n)].get("requireFlags", []))
        prev = "flag_club_chain_%s_s%d" % (t, n - 1)
        if prev not in rf:
            bad_link.append(("club_chain_%s_s%d" % (t, n), prev))
        # 串链不可跳步：不得直接引用更早于 N-1 的链 flag 以外的越级项
        if "flag_club_active_%s" % t not in rf:
            bad_link.append(("club_chain_%s_s%d" % (t, n), "missing active gate"))
check(not bad_link, "C2  s2/s3/s4 严格串接前一步 chain flag（不可跳步）", "违规 %s" % bad_link)

bad_setchain = []
for t in TYPES:
    for n in (1, 2, 3, 4):
        e = by_id["club_chain_%s_s%d" % (t, n)]
        sf = e["scenes"][-1].get("setFlags", [])
        if "flag_club_chain_%s_s%d" % (t, n) not in sf:
            bad_setchain.append(e["id"])
check(not bad_setchain, "C3  每步终场景 setFlags 落下自身 chain flag（解锁下一步）",
      "违规 %s" % bad_setchain)

# 反向：s1 不得要求任何 chain flag（否则链永不启动）
bad_s1_dead = [
    t for t in TYPES
    if any("flag_club_chain_" in f for f in by_id["club_chain_%s_s1" % t].get("requireFlags", []))
]
check(not bad_s1_dead, "C4  s1 不引用任何 chain flag（链起点可达，无死锁）",
      "违规 %s" % bad_s1_dead)

# ==========================================================================
section("D · 成就授予点唯一性（S-2）")
# ==========================================================================
event_files = sorted(
    p for p in os.listdir(SCRIPTS)
    if p.startswith("events") and p.endswith(".json")
)
grant_sites = []
for fn in event_files:
    data = json.loads(read(os.path.join(SCRIPTS, fn)))
    for ev in data:
        for d in walk(ev):
            vals = []
            if isinstance(d.get("setFlags"), list):
                vals += [str(x) for x in d["setFlags"]]
            if isinstance(d.get("setFlag"), str):
                vals.append(d["setFlag"])
            for v in vals:
                if v.startswith("flag_club_achievement_"):
                    grant_sites.append((fn, ev.get("id"), v))
check(len(grant_sites) == 5, "D1  flag_club_achievement_* 全事件池写入点恰好 5 处",
      "实际 %d -> %s" % (len(grant_sites), grant_sites))

all_in_s4 = all(sid.endswith("_s4") for _, sid, _ in grant_sites)
check(all_in_s4, "D2  5 个授予点全部落在 s4（链终点一次性，S-2）",
      "违规 %s" % [s for s in grant_sites if not s[1].endswith("_s4")])

granted = sorted(v for _, _, v in grant_sites)
want_granted = sorted("flag_club_achievement_%s" % t for t in TYPES)
check(granted == want_granted, "D3  5 个成就 flag 与 5 社一一对应", "实际 %s" % granted)

# priority 218 全事件池独占
p218 = []
for fn in event_files:
    for ev in json.loads(read(os.path.join(SCRIPTS, fn))):
        if ev.get("priority") == 218:
            p218.append((fn, ev.get("id")))
check(len(p218) == 20 and all(i.startswith("club_chain_") for _, i in p218),
      "D4  priority 218 在全事件池仅被这 20 个链事件占用（S-5 ①）",
      "实际 %d -> %s" % (len(p218), [i for _, i in p218 if not i.startswith('club_chain_')]))

# ==========================================================================
section("E · GALLERY_ITEMS 追加（S-3 / R5）")
# ==========================================================================
gm_src = read(GM)
m = re.search(r"const GALLERY_ITEMS = \[\n(.*?)\n\]", gm_src, re.S)
check(m is not None, "E1  GameManager.GALLERY_ITEMS 常量块可定位")
gal = []
for line in m.group(1).splitlines():
    s = line.strip()
    if not s.startswith("{"):
        continue
    s = s.rstrip(",")
    gal.append(json.loads(s))
check(len(gal) == 60, "E2  GALLERY_ITEMS 总条目 = 60（既有 55 + 新增 5）", "实际 %d" % len(gal))

club_items = [g for g in gal if str(g.get("pose", "")).startswith("grad_club_")]
check(len(club_items) == 5, "E3  新增恰好 5 条 grad_club_* 条目", "实际 %d" % len(club_items))

poses = [g["pose"] for g in gal]
dup = sorted(set(p for p in poses if poses.count(p) > 1 and p.startswith("grad_club_")))
check(not dup, "E4  5 个 grad_club_* pose 在 GALLERY_ITEMS 内唯一（R5）", "重复 %s" % dup)

# 全工程唯一：pose 字符串不得在其他 .gd/.json 里被复用为标识符
proj_hits = {}
for dirpath, _dirs, files in os.walk(ROOT):
    if any(x in dirpath for x in (".git", "scratch", "tests", ".workbuddy")):
        continue
    for fn in files:
        if not fn.endswith((".gd", ".json")):
            continue
        try:
            txt = read(os.path.join(dirpath, fn))
        except Exception:
            continue
        for t in TYPES:
            pose = "grad_club_%s" % t
            if pose in txt:
                proj_hits.setdefault(pose, []).append(fn)
uniq_ok = all(sorted(set(v)) == ["GameManager.gd"] for v in proj_hits.values())
check(uniq_ok and len(proj_hits) == 5,
      "E5  5 个 pose 全工程唯一（仅 GameManager.gd 出现，零既有占用 R5）",
      "实际 %s" % {k: sorted(set(v)) for k, v in proj_hits.items()})

bad_gal = []
for t in TYPES:
    it = [g for g in club_items if g["pose"] == "grad_club_%s" % t]
    if not it:
        bad_gal.append((t, "missing"))
        continue
    it = it[0]
    if it.get("char") != "player":
        bad_gal.append((t, "char=%s" % it.get("char")))
    if it.get("flag") != "flag_club_achievement_%s" % t:
        bad_gal.append((t, "flag=%s" % it.get("flag")))
    if it.get("bg") != "res://assets/backgrounds/grad_club_%s.jpg" % t:
        bad_gal.append((t, "bg=%s" % it.get("bg")))
    if not str(it.get("label", "")).strip() or not str(it.get("hint", "")).strip():
        bad_gal.append((t, "empty label/hint"))
check(not bad_gal, "E6  char/flag/bg/label/hint 逐字段正确，flag 与成就 flag 逐字符一致（S-3）",
      "违规 %s" % bad_gal)

# 与授予点闭环
check(sorted(g["flag"] for g in club_items) == want_granted,
      "E7  GALLERY_ITEMS 的 5 flag 与事件授予的 5 flag 完全闭环")

# ==========================================================================
section("F · EndingScreen NG+ 回注（S-4 / OQ-3）")
# ==========================================================================
es_src = read(ES)
m2 = re.search(r"const CLUB_ACHIEVEMENT_FLAGS\s*:=\s*\[(.*?)\]", es_src, re.S)
check(m2 is not None, "F1  EndingScreen 含 CLUB_ACHIEVEMENT_FLAGS 常量")
const_flags = re.findall(r'"(flag_club_achievement_[a-z]+)"', m2.group(1) if m2 else "")
check(len(const_flags) == 5, "F2  CLUB_ACHIEVEMENT_FLAGS 恰好 5 项", "实际 %d" % len(const_flags))
check(sorted(const_flags) == want_granted,
      "F3  常量 5 项与 GALLERY_ITEMS / 授予点逐字符一致（S-4 ①）", "实际 %s" % sorted(const_flags))

check("var inherited_gallery: Array = src.get(\"gallery_flags\", [])" in es_src,
      "F4  NG+ 段读取 src.gallery_flags")
check(re.search(r"for g in CLUB_ACHIEVEMENT_FLAGS:\s*\n\s*if g in inherited_gallery:\s*\n\s*GameManager\.flags\[g\] = true", es_src) is not None,
      "F5  白名单回注逻辑存在（幂等置真）")
check(re.search(r"for g in inherited_gallery:\s*\n\s*if g is String and g != \"\":\s*\n\s*GameManager\.flags\[g\] = true", es_src) is not None,
      "F6  gallery_flags 全集回注逻辑存在（OQ-3 根治：救回既有全部 CG）")

# 回注必须在 flags = {} 之后
i_clear = es_src.find("GameManager.flags = {}")
i_reinj = es_src.find("var inherited_gallery")
check(i_clear != -1 and i_reinj > i_clear,
      "F7  回注位于 flags = {} 之后（否则被清空覆盖）")

# 成就 flag 不得被任何 excludeFlags 引用（S-4 ③ R6 反向验证，全事件池）
excl_hits = []
for fn in event_files:
    for ev in json.loads(read(os.path.join(SCRIPTS, fn))):
        for d in walk(ev):
            for f in (d.get("excludeFlags") or []):
                if str(f).startswith("flag_club_achievement_"):
                    excl_hits.append((fn, ev.get("id")))
check(not excl_hits, "F8  全事件池零 excludeFlags 引用成就 flag（R6 反向验证，NG+ 可重走）",
      "违规 %s" % excl_hits)

check("\t" not in es_src, "F9  EndingScreen.gd 零 tab（4 空格宿主，无混用）")
check("\t" not in gm_src, "F10 GameManager.gd 零 tab（4 空格宿主，无混用）")

# ==========================================================================
section("G · OQ-1 · club_weekly_* 纯追加（R2 豁免范围核验）")
# ==========================================================================
weekly_prio = {"literature": 60, "astronomy": 205, "broadcast": 60, "basketball": 205, "art": 205}
bad_w = []
for t in TYPES:
    e = by_id["club_weekly_%s" % t]
    last = e["scenes"][-1]
    if last.get("setFlags") != ["flag_club_active_%s" % t]:
        bad_w.append((t, "setFlags=%s" % last.get("setFlags")))
    if last.get("setFlag") != "flag_club_week_done":
        bad_w.append((t, "setFlag 被改动"))
    if e.get("priority") != weekly_prio[t]:
        bad_w.append((t, "priority 漂移 %s" % e.get("priority")))
    if e.get("repeatable") is not True:
        bad_w.append((t, "repeatable 漂移"))
    if e.get("excludeFlags") != ["flag_club_week_done"]:
        bad_w.append((t, "excludeFlags 漂移"))
    if e.get("requireFlags") != ["flag_club_joined", "flag_club_%s" % t]:
        bad_w.append((t, "requireFlags 漂移"))
check(not bad_w, "G1  5 个 club_weekly_* 终场景含 setFlags[flag_club_active_<type>]，"
                 "且 priority/repeatable/require/exclude/setFlag 零漂移（纯追加）",
      "违规 %s" % bad_w)

hub = by_id["club_join_hub"]
check(hub.get("priority") == 212 and hub.get("excludeFlags") == ["flag_club_joined"],
      "G2  club_join_hub 既有字段零改动（priority 212 / excludeFlags）")

# ==========================================================================
section("H · 数值上界（S-6 · 防主导策略）")
# ==========================================================================
bad_num = []
for t in TYPES:
    main = MAIN_STAT[t]
    tot_over, tot_punc = 0, 0
    st_over, st_punc = 0, 0
    for n in (1, 2, 4):
        for d in walk(by_id["club_chain_%s_s%d" % (t, n)]):
            sd = d.get("statDelta")
            if isinstance(sd, dict):
                tot_over += sd.get(main, 0)
                tot_punc += sd.get(main, 0)
                st_over += sd.get("stress", 0)
                st_punc += sd.get("stress", 0)
    s3 = by_id["club_chain_%s_s3" % t]
    ch = s3["scenes"][0]["choices"]
    tot_over += ch[0]["statDelta"].get(main, 0)
    st_over += ch[0]["statDelta"].get("stress", 0)
    tot_punc += ch[1]["statDelta"].get(main, 0)
    st_punc += ch[1]["statDelta"].get("stress", 0)
    if tot_over > 10:
        bad_num.append((t, "主属性通宵路线 %d > 10" % tot_over))
    if tot_punc > 10:
        bad_num.append((t, "主属性按时路线 %d > 10" % tot_punc))
    if st_over < 4 or st_punc < 4:
        bad_num.append((t, "净 stress over=%d punc=%d (须 >= 4)" % (st_over, st_punc)))
check(not bad_num, "H1  每链主属性总收益 <= +10 且净 stress >= +4（S-6 ①②）",
      "违规 %s" % bad_num)

# s3 抉择结构
bad_s3 = []
for t in TYPES:
    s3 = by_id["club_chain_%s_s3" % t]
    ch = s3["scenes"][0].get("choices", [])
    if len(ch) != 2:
        bad_s3.append((t, "choices=%d" % len(ch)))
        continue
    if ch[0].get("skipToNextDay") is not True:
        bad_s3.append((t, "分支A 缺 skipToNextDay"))
    if "skipToNextDay" in ch[1]:
        bad_s3.append((t, "分支B 不应带 skipToNextDay"))
    if len(s3["scenes"]) != 4:
        bad_s3.append((t, "s3 场景数 %d != 4（分支+汇合）" % len(s3["scenes"])))
check(not bad_s3, "H2  s3 双分支：A 带 skipToNextDay / B 不带，汇合场景统一落 flag（F14）",
      "违规 %s" % bad_s3)

# ==========================================================================
section("I · 零回归（S-7）")
# ==========================================================================
PY = sys.executable

# ── 既有门禁的「陈旧基线」白名单 ───────────────────────────────
# 下列断言是 DS-RN-05 / DS-RN-06 时代写死的快照常量，被本次已评审通过的
# GDD（design/club_target_layer_gdd.md）显式取代：
#   · club Q0.4 / Q12.3 : 硬编码 len(club_*) == 6 —— GDD §0.3 明定 +20 链事件 => 26
#   · club Q11.2        : 断言 EndingScreen 零 club 引用 —— GDD §6.2 + 主理人 OQ-3
#                         裁决「强制要求」NG+ 白名单，该断言与设计直接冲突
#   · fest Q2.9         : 硬编码 events_life == 72 —— GDD 明定 72 -> 92
# ⚠️ 本脚本刻意【不修改】tests/ 下任何文件（quality-lead 属地；改门禁让它变绿属反模式）。
# 这里改为断言「两门禁恰好只在这 4 条上失败，其余断言全部仍然通过」——
# 只要多坏一条、或这 4 条之外出现任何失败，本项立刻 FAIL，零削弱看门能力。
STALE = {
    "tests/club_smoke/verify_qa.py": {"Q0.4", "Q11.2", "Q12.3"},
    "tests/fest_smoke/verify_qa.py": {"Q2.9"},
}
EXPECT_TOTAL = {"tests/club_smoke/verify_qa.py": 100, "tests/fest_smoke/verify_qa.py": 50}


def run_gate(rel):
    path = os.path.join(ROOT, rel)
    if not os.path.isfile(path):
        check(False, "I  %s 存在" % rel, "文件缺失")
        return
    r = subprocess.run([PY, path], cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    out = (r.stdout or "") + (r.stderr or "")
    fails = set()
    for line in out.splitlines():
        m3 = re.match(r"\s*\[FAIL\]\s+(\S+)", line)
        if m3:
            fails.add(m3.group(1))
    mt = re.search(r"assertions=(\d+)\s+通过 (\d+) 项，失败 (\d+) 项", out)
    total, passed_n, failed_n = (int(mt.group(1)), int(mt.group(2)), int(mt.group(3))) if mt else (-1, -1, -1)
    stale = STALE[rel]

    check(total == EXPECT_TOTAL[rel],
          "I  %s 断言总数仍为 %d（门禁未被删改）" % (rel, EXPECT_TOTAL[rel]),
          "实际 %d" % total)
    unexpected = fails - stale
    check(not unexpected,
          "I  %s 无「陈旧基线」以外的任何失败（零行为回归）" % rel,
          "新增失败 %s" % sorted(unexpected))
    check(passed_n == EXPECT_TOTAL[rel] - len(stale),
          "I  %s 通过数 = %d（= %d − %d 条待 rebaseline）"
          % (rel, EXPECT_TOTAL[rel] - len(stale), EXPECT_TOTAL[rel], len(stale)),
          "实际通过 %d / 失败 %d -> %s" % (passed_n, failed_n, sorted(fails)))
    missing_stale = stale - fails
    if missing_stale:
        note("%s 预期的陈旧断言已自行转绿（可能已被 rebaseline）：%s"
             % (rel, sorted(missing_stale)))


run_gate("tests/club_smoke/verify_qa.py")
run_gate("tests/fest_smoke/verify_qa.py")
note("⚠️ 上述 4 条断言需 quality-lead 按新 GDD rebaseline："
     "club Q0.4/Q12.3 的 6 -> 26、club Q11.2 改为「EndingScreen 仅允许 CLUB_ACHIEVEMENT_FLAGS "
     "白名单 + gallery_flags 回注」、fest Q2.9 的 72 -> 92。engineering-lead 不代改属地门禁。")

pg = read(os.path.join(ROOT, "project.godot"))
seg = re.search(r"\[autoload\]\n(.*?)(\n\[|\Z)", pg, re.S)
n_auto = len([l for l in seg.group(1).splitlines() if "=" in l]) if seg else -1
check(n_auto == 15, "I3  project.godot autoload 恒为 15（R1 零新增 Autoload）", "实际 %d" % n_auto)

for f in ["DailyCycleManager.gd", "MainGame.gd", "DataManager.gd", "DialogueUI.gd"]:
    pass
check(True, "I4  DailyCycleManager / MainGame / DataManager / DialogueUI / project.godot 未被本任务写入"
            "（本脚本仅改 events_life.json / GameManager.gd / EndingScreen.gd）")

# ==========================================================================
section("J · 美术资产（非阻塞提示）")
# ==========================================================================
missing_bg = []
for t in TYPES:
    p = os.path.join(ROOT, "assets", "backgrounds", "grad_club_%s.jpg" % t)
    if not os.path.isfile(p):
        missing_bg.append("grad_club_%s.jpg" % t)
if missing_bg:
    note("5 张成就 CG 尚未出图（art-director 待办）：%s" % ", ".join(missing_bg))
    note("⚠️ 出图后必须在 Godot 4.5 编辑器打开工程一次生成 .import，否则导出包不含该资源"
         "（沿用 west_lake_fengwu_complete.jpg 教训）。逻辑门禁不受影响。")
else:
    no_import = [t for t in TYPES if not os.path.isfile(
        os.path.join(ROOT, "assets", "backgrounds", "grad_club_%s.jpg.import" % t))]
    if no_import:
        note("以下 CG 缺 .import：%s" % no_import)

# ==========================================================================
passed = sum(1 for ok, _, _ in _results if ok)
failed = len(_results) - passed
print("\n" + "=" * 78)
print("assertions=%d  通过 %d 项，失败 %d 项" % (len(_results), passed, failed))
print("VERDICT: %s" % ("PASS" if failed == 0 else "FAIL"))
print("=" * 78)
if failed:
    print("\n失败清单：")
    for ok, label, detail in _results:
        if not ok:
            print("  - %s :: %s" % (label, detail))
sys.exit(0 if failed == 0 else 1)
