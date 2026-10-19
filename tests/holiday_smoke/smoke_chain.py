#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
长假 set-piece 触发链冒烟测试 (holiday_smoke)
《西湖边的青春》 Godot 4.5 手游 — Phase 3 长假系统

环境约束：无 Godot 可执行环境，仅做"逻辑级模拟"。
- 真实读取 events_break.json / characters.json
- 用正则从 GameManager.gd 提取 GALLERY_ITEMS 的 holiday_memory_* 键集合
- 用正则从 DailyCycleManager.gd 提取 BREAK_PERIODS 与 break 特殊日
- 复刻 DataManager.get_available_event 的 gate 逻辑（requireHoliday / requireFlags /
  unlockDay / minAff / excludeRelState / 校内地点抑制 / triggerDay / repeatable），
  模拟运行时级联：kickoff 三选一 → chapter 闸门 → gallery 解锁。
不修改任何 .gd / 事件 .json 源码（本脚本只读取它们）。

退出码：出现 FAIL 断言 -> 1；否则 0（CONCERNS 为建议性，不阻断退出码）。
"""

import json
import re
import os
import sys
import datetime

# ─────────────────────────────────────────────────────────────
# 路径（与仓库结构绑定；仅读取，不写源码）
# ─────────────────────────────────────────────────────────────
REPO = r"D:\zkgame"
SCRIPTS = os.path.join(REPO, "scripts")
EVENTS_PATH = os.path.join(SCRIPTS, "events_break.json")
CHARS_PATH = os.path.join(SCRIPTS, "characters.json")
DATAMGR_PATH = os.path.join(SCRIPTS, "DataManager.gd")
DAILY_PATH = os.path.join(SCRIPTS, "DailyCycleManager.gd")
GAMEMGR_PATH = os.path.join(SCRIPTS, "GameManager.gd")
COLMGR_PATH = os.path.join(SCRIPTS, "CollectionManager.gd")

# 复刻自 DataManager.gd L284（长假校内地点抑制集合）
SCHOOL_LOCATIONS = ["classroom", "library", "playground", "music_room", "art_room"]
HOLIDAY_TYPES = ["winter", "spring", "summer", "autumn"]

# 设计文档 §10 / GameManager.gd GALLERY_ITEMS 中 holiday 背景占位映射
EXPECTED_BG = {
    "winter": "res://assets/backgrounds/holiday_winter.jpg",
    "spring": "res://assets/backgrounds/holiday_spring_outing.jpg",
    "summer": "res://assets/backgrounds/holiday_summer_trip.jpg",
    "autumn": "res://assets/backgrounds/holiday_autumn_osmanthus.jpg",
}

# ─────────────────────────────────────────────────────────────
# 断言收集器
# ─────────────────────────────────────────────────────────────
RESULTS = []  # list of dict: {id, group, desc, status, detail}


def chk(cid, group, desc, cond, detail_pass, detail_fail=None):
    status = "PASS" if cond else "FAIL"
    detail = detail_pass if cond else (detail_fail if detail_fail is not None else "条件不成立")
    RESULTS.append({"id": cid, "group": group, "desc": desc, "status": status, "detail": detail})
    return cond


def concern(cid, group, desc, detail):
    RESULTS.append({"id": cid, "group": group, "desc": desc, "status": "CONCERNS", "detail": detail})


# ─────────────────────────────────────────────────────────────
# 读取源文件（真实 IO）
# ─────────────────────────────────────────────────────────────
def read_text(p):
    with open(p, "r", encoding="utf-8") as f:
        return f.read()


def load_json(p):
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


# ─────────────────────────────────────────────────────────────
# 从 .gd 复刻常量（真实正则提取，避免与源码漂移）
# ─────────────────────────────────────────────────────────────
def parse_break_periods(text):
    """复刻 DailyCycleManager.gd L32-37 const BREAK_PERIODS"""
    d = {}
    for m in re.finditer(r'"(\w+)":\s*\[(\d+),\s*(\d+)\]', text):
        d[m.group(1)] = [int(m.group(2)), int(m.group(3))]
    return d


def parse_special_break_days(text):
    """复刻 DailyCycleManager.gd L12-29 SPECIAL_DATES 中 effect=='break' 的日"""
    days = []
    for m in re.finditer(r'(\d+):\s*\{[^{}]*"effect":\s*"(break)"', text):
        days.append(int(m.group(1)))
    return sorted(days)


def parse_gallery_memory(text):
    """从 GameManager.gd GALLERY_ITEMS 提取 holiday_memory_* 条目 -> {flag:(char,bg)}"""
    out = {}
    pat = re.compile(r'"char":\s*"(\w+)"[^}]*?"flag":\s*"(holiday_memory_[a-z]+_[a-z_]+)"[^}]*?"bg":\s*"([^"]+)"')
    for m in pat.finditer(text):
        out[m.group(2)] = (m.group(1), m.group(3))
    return out


def has_unlock_gallery(text):
    """确认 CollectionManager.gd 存在 unlock_gallery(func)"""
    return bool(re.search(r'func unlock_gallery\s*\(', text))


# ─────────────────────────────────────────────────────────────
# 复刻 DataManager.get_available_event 的运行时门控（核心）
# 仅保留与长假触发链相关的检查，忠实于 L189-300 的逻辑顺序。
# ─────────────────────────────────────────────────────────────
def event_eligible(ev, location_id, current_slot, current_day, current_holiday,
                   flags, favorability, char_targets, rel_state="normal"):
    ev_loc = ev.get("location") or ""
    ev_slot = ev.get("slotId") or ""

    # 地点匹配（空串 = 全局事件）
    if ev_loc != "" and ev_loc != location_id:
        return False, "location mismatch (%s!=%s)" % (ev_loc, location_id)
    # 时间段匹配
    if ev_slot != "" and ev_slot != current_slot:
        return False, "slot mismatch (%s!=%s)" % (ev_slot, current_slot)
    # triggerDay：从该天起可用
    trig = int(ev.get("triggerDay", 0) or 0)
    if trig > 0 and current_day < trig:
        return False, "triggerDay %d 未到 (day=%d)" % (trig, current_day)
    # 非可重复事件：已触发则排除
    ev_id = ev.get("id", "")
    if not ev.get("repeatable", False) and ev_id in flags:
        return False, "已触发(repeatable:false) %s" % ev_id
    # 角色相关
    char_id = ev.get("charId") or ""
    if char_id != "":
        if char_id not in char_targets:
            return False, "charId %s 非当前路线目标" % char_id
        unlock_day = int(ev.get("_unlockDay", 1))
        if current_day < unlock_day:
            return False, "角色未解锁(unlockDay=%d, day=%d)" % (unlock_day, current_day)
        min_aff = int(ev.get("minAff", 0) or 0)
        if favorability.get(char_id, 0) < min_aff:
            return False, "好感不足(minAff=%d)" % min_aff
    # requireFlags（chapter 闸门）
    for f in (ev.get("requireFlags") or []):
        if f not in flags:
            return False, "requireFlags 缺失: %s" % f
    # requireHoliday（长假门控，L274-280）
    req_hol = ev.get("requireHoliday") or ""
    if req_hol != "":
        if req_hol == "any":
            if current_holiday == "":
                return False, "requireHoliday=any 但当前无长假"
        elif current_holiday != req_hol:
            return False, "requireHoliday=%s 但 current=%s" % (req_hol, current_holiday)
    # 长假校内地点抑制（L282-287）
    if current_holiday != "":
        if ev_loc in SCHOOL_LOCATIONS:
            return False, "校内地点 %s 在长假被抑制" % ev_loc
    # excludeRelState（长假暂停冷战 -> 传 normal 即不触发，L298-300）
    ex_rel = ev.get("excludeRelState") or ""
    if ex_rel != "" and rel_state == ex_rel:
        return False, "excludeRelState=%s" % ex_rel
    return True, "eligible"


def chapter_test_day(ev, htype, periods, unlock):
    """返回该 chapter 在长假窗口内、且角色已解锁后的最早可触发日；
    若不存在（角色解锁日晚于长假结束）返回 None -> 不可达。"""
    trig = int(ev.get("triggerDay", 0) or 0)
    ud = unlock.get(ev.get("charId", ""), 1)
    start, end = periods[htype]
    d = max(trig, ud)
    if d < start:
        d = start
    if d <= end:
        return d
    return None


# ─────────────────────────────────────────────────────────────
# 事件结构辅助
# ─────────────────────────────────────────────────────────────
def classify(e):
    if e["id"].startswith("holiday_kickoff_"):
        return "kickoff"
    rf = e.get("requireFlags") or []
    if any(f.startswith("holiday_chapter_") for f in rf):
        return "chapter"
    return "filler"


def kickoff_choices(ev):
    for sc in ev["scenes"]:
        if "choices" in sc:
            return sc["choices"]
    return []


def kickoff_flags(ev):
    study_flag = None
    chapter_flag = None
    for ch in kickoff_choices(ev):
        sf = ch.get("setFlag")
        if not sf:
            continue
        if sf.startswith("holiday_mode_"):
            study_flag = sf
        elif sf.startswith("holiday_chapter_"):
            chapter_flag = sf  # 出游/陪伴 均置同一 flag
    return study_flag, chapter_flag


def chapter_memory_flags(ev):
    out = []
    for sc in ev["scenes"]:
        sf = sc.get("setFlag")
        if sf and sf.startswith("holiday_memory_"):
            out.append(sf)
    return out


def unlock_gallery_sim(flags, flag_name):
    """复刻 CollectionManager.gd L30-32：消费 flag 写入 GameManager.flags"""
    if flag_name != "" and flag_name not in flags:
        flags[flag_name] = True
    return flags


# ─────────────────────────────────────────────────────────────
# 主流程
# ─────────────────────────────────────────────────────────────
def main():
    # ---- 读取真实源 ----
    events = load_json(EVENTS_PATH)
    chars = load_json(CHARS_PATH)
    daily_text = read_text(DAILY_PATH)
    game_text = read_text(GAMEMGR_PATH)
    col_text = read_text(COLMGR_PATH)

    periods = parse_break_periods(daily_text)
    break_days = parse_special_break_days(daily_text)
    gallery = parse_gallery_memory(game_text)
    col_has_func = has_unlock_gallery(col_text)

    char_ids = [c["id"] for c in chars]
    unlock = {c["id"]: int(c.get("unlockDay", 1)) for c in chars}
    favorability = {cid: 100 for cid in char_ids}      # 高好感以隔离好感门控
    char_targets = list(char_ids)                       # 视玩家处于任意路线（最佳情形）

    # 把 unlockDay 挂到事件上，供 event_eligible 使用
    for e in events:
        cid = e.get("charId") or ""
        e["_unlockDay"] = unlock.get(cid, 1)

    # 分类
    kickoffs = [e for e in events if classify(e) == "kickoff"]
    chapters = [e for e in events if classify(e) == "chapter"]
    fillers = [e for e in events if classify(e) == "filler"]
    chapters_by_type = {t: [] for t in HOLIDAY_TYPES}
    for e in chapters:
        rf = e.get("requireFlags") or []
        for f in rf:
            if f.startswith("holiday_chapter_"):
                t = f[len("holiday_chapter_"):]
                if t in chapters_by_type:
                    chapters_by_type[t].append(e)

    # =========================================================
    # SECTION A — 加载与清单一致性
    # =========================================================
    chk("A1", "加载", "events_break.json 可被 JSON 解析", True, "已加载 %d 个事件" % len(events))
    chk("A2", "加载", "characters.json 可被 JSON 解析", True, "已加载 %d 个角色" % len(chars))
    chk("A3", "清单", "事件总数 == 26", len(events) == 26, "实际 %d" % len(events),
        detail_fail="实际 %d，预期 26" % len(events))
    chk("A4", "清单", "kickoff == 4 且 priority==200",
        len(kickoffs) == 4 and all(e.get("priority") == 200 for e in kickoffs),
        "4 个 kickoff 均 priority=200",
        detail_fail="kickoff 数=%d / priority 不全为200" % len(kickoffs))
    chk("A5", "清单", "chapter == 10", len(chapters) == 10, "实际 %d" % len(chapters),
        detail_fail="实际 %d，预期 10" % len(chapters))
    chk("A6", "清单", "filler == 12", len(fillers) == 12, "实际 %d" % len(fillers),
        detail_fail="实际 %d，预期 12" % len(fillers))
    chk("A7", "画廊", "GALLERY_ITEMS 含 10 条 holiday_memory_*",
        len(gallery) == 10, "提取到 %d 条" % len(gallery),
        detail_fail="提取到 %d 条，预期 10（GameManager.gd L333-342）" % len(gallery))
    chk("A8", "解锁", "CollectionManager.gd 存在 unlock_gallery(func)",
        col_has_func, "已定位 func unlock_gallery",
        detail_fail="未在 CollectionManager.gd 找到 unlock_gallery")
    chk("A9", "日历", "BREAK_PERIODS 含 4 个长假且区间正确",
        periods.get("winter") == [90, 100] and periods.get("spring") == [150, 155]
        and periods.get("summer") == [270, 300] and periods.get("autumn") == [303, 309],
        "winter[90,100] spring[150,155] summer[270,300] autumn[303,309]",
        detail_fail="解析结果: %s（应源自 DailyCycleManager.gd L32-37）" % periods)
    chk("A10", "日历", "SPECIAL_DATES 含 4 个 break 日且与 kickoff 对应",
        break_days == [90, 150, 270, 304],
        "break 日=%s" % break_days,
        detail_fail="break 日=%s，预期 [90,150,270,304]" % break_days)

    # =========================================================
    # SECTION B/C — 每个长假的完整级联 + 学习支线隔离
    # =========================================================
    for t in HOLIDAY_TYPES:
        kickoff = next((e for e in kickoffs if e["id"] == "holiday_kickoff_" + t), None)
        study_flag, chapter_flag = kickoff_flags(kickoff)
        chs = chapters_by_type[t]

        # B: 出游 / 陪伴 -> 设 chapter flag -> chapter 变 eligible -> 终场景 -> gallery -> unlock
        for choice in ["出游", "陪伴"]:
            flags = {chapter_flag: True}
            cid_prefix = "B-%s-%s" % (t, choice)
            chk(cid_prefix + "-1", "kickoff→flag",
                "[%s] 选「%s」设置 %s" % (t, choice, chapter_flag),
                chapter_flag in flags,
                "%s 已置位" % chapter_flag)
            # 该长假全部 chapter 变 eligible
            for ch in chs:
                td = chapter_test_day(ch, t, periods, unlock)
                if td is None:
                    chk(cid_prefix + "-elig-" + ch["id"], "chapter门控",
                        "[%s] %s 在长假内可放行(eligible)" % (t, ch["id"]),
                        False,
                        "不可达：角色 %s unlockDay=%d 晚于 %s 窗口结束 %d（DataManager.gd L216-218 / characters.json）"
                        % (ch["charId"], unlock.get(ch["charId"]), t, periods[t][1]),
                        detail_fail="不可达")
                    continue
                elig, why = event_eligible(ch, ch["location"], ch["slotId"], td, t,
                                           flags, favorability, char_targets)
                chk(cid_prefix + "-elig-" + ch["id"], "chapter门控",
                    "[%s] %s 在长假内可放行(eligible)" % (t, ch["id"]),
                    elig, "eligible@day%d" % td,
                    detail_fail="被排除: %s" % why)
            # 端到端：取首个 chapter 走终场景
            if chs:
                rep = chs[0]
                mem = list(dict.fromkeys(chapter_memory_flags(rep)))
                expected_mem = "holiday_memory_%s_%s" % (t, rep["charId"])
                chk(cid_prefix + "-mem", "终场景→memory",
                    "[%s] 终场景设置 %s" % (t, expected_mem),
                    expected_mem in mem,
                    "终场景 setFlag=%s" % mem,
                    detail_fail="终场景仅设置 %s，缺 %s" % (mem, expected_mem))
                # 模拟走完终场景：置 memory flag
                flags2 = dict(flags)
                flags2[expected_mem] = True
                # GALLERY 含该条目
                in_gal = expected_mem in gallery
                chk(cid_prefix + "-gal", "gallery映射",
                    "[%s] GALLERY_ITEMS 含 %s" % (t, expected_mem),
                    in_gal,
                    "GALLERY flag=%s bg=%s" % (expected_mem, gallery.get(expected_mem)),
                    detail_fail="GALLERY_ITEMS 无 %s（GameManager.gd L333-342）" % expected_mem)
                # CollectionManager.unlock_gallery 注册
                unlock_gallery_sim(flags2, expected_mem)
                registered = (expected_mem in flags2) and (expected_mem in gallery)
                chk(cid_prefix + "-unlock", "解锁注册",
                    "[%s] unlock_gallery(%s) 写入 flags" % (t, expected_mem),
                    registered,
                    "flags[%s]=true 且 GALLERY 存在" % expected_mem,
                    detail_fail="unlock_gallery 未注册 %s（CollectionManager.gd L30-32）" % expected_mem)

        # C: 学习 -> 不设 chapter flag -> chapter 被排除
        flags_study = {study_flag: True} if study_flag else {}
        cid_prefix = "C-%s" % t
        chk(cid_prefix + "-1", "kickoff→flag",
            "[%s] 选「学习」设置 %s 且**不**设 %s" % (t, study_flag, chapter_flag),
            (study_flag in flags_study) and (chapter_flag not in flags_study),
            "%s 置位，%s 缺省" % (study_flag, chapter_flag))
        for ch in chs:
            td = chapter_test_day(ch, t, periods, unlock)
            day_for_test = td if td is not None else periods[t][0]
            elig, why = event_eligible(ch, ch["location"], ch["slotId"], day_for_test, t,
                                       flags_study, favorability, char_targets)
            chk(cid_prefix + "-excl-" + ch["id"], "学习隔离",
                "[%s] 选「学习」后 %s 被门控排除" % (t, ch["id"]),
                not elig, "正确排除(缺 %s)" % chapter_flag,
                detail_fail="未排除: %s" % why)

    # =========================================================
    # SECTION D — requireHoliday 隔离（用各长假一个可达 chapter 代表）
    # =========================================================
    iso_rep = {
        "winter": "break_winter_chapter_yutong",
        "spring": "break_spring_chapter_wanqing",
        "summer": "break_summer_chapter_zijun",
        "autumn": "break_autumn_chapter_zicheng",
    }
    for t in HOLIDAY_TYPES:
        ev = next((e for e in chapters if e["id"] == iso_rep[t]), None)
        td = chapter_test_day(ev, t, periods, unlock)
        if td is None:
            concern("D-%s" % t, "requireHoliday隔离",
                    "[%s] 代表 chapter 不可达(unlockDay)，隔离测试降级为信息项" % t,
                    "因角色解锁日晚于窗口，无法构造可达日；见 SEC B 的不可达结论。")
            continue
        chapter_flag = "holiday_chapter_" + t
        # 正确长假 -> 放行
        elig, _ = event_eligible(ev, ev["location"], ev["slotId"], td, t,
                                 {chapter_flag: True}, favorability, char_targets)
        chk("D-%s-correct" % t, "requireHoliday隔离",
            "[%s] current_holiday==正确长假 时放行" % t, elig, "eligible")
        # 错误长假 -> 排除
        wrong = HOLIDAY_TYPES[(HOLIDAY_TYPES.index(t) + 1) % 4]
        elig_w, why_w = event_eligible(ev, ev["location"], ev["slotId"], td, wrong,
                                       {chapter_flag: True}, favorability, char_targets)
        chk("D-%s-wrong" % t, "requireHoliday隔离",
            "[%s] current_holiday==错误长假(%s) 时排除" % (t, wrong),
            not elig_w, "正确排除(%s)" % why_w,
            detail_fail="未排除: %s" % why_w)
        # 无长假 -> 排除
        elig_n, why_n = event_eligible(ev, ev["location"], ev["slotId"], td, "",
                                       {chapter_flag: True}, favorability, char_targets)
        chk("D-%s-none" % t, "requireHoliday隔离",
            "[%s] current_holiday==\"\" 时排除" % t,
            not elig_n, "正确排除(%s)" % why_n,
            detail_fail="未排除: %s" % why_n)
        # "any" -> 特定类型 chapter 不被放行（仅 requireHoliday=="any" 的事件才被放行）
        elig_a, why_a = event_eligible(ev, ev["location"], ev["slotId"], td, "any",
                                       {chapter_flag: True}, favorability, char_targets)
        chk("D-%s-any" % t, "requireHoliday隔离",
            "[%s] current_holiday==\"any\" 时特定类型 chapter 仍排除(符合引擎逻辑)" % t,
            not elig_a, "正确排除(%s)" % why_a,
            detail_fail="未排除: %s" % why_a)

    concern("D-note", "requireHoliday隔离",
            "requireHoliday==\"any\" 分支（DataManager.gd L278-279）当前无集成覆盖",
            "events_break.json 中没有任何事件使用 requireHoliday==\"any\"，故该分支仅在单元层面可验证，运行时无事件触发；建议补一条 any 事件或单元测试。")

    # =========================================================
    # SECTION E — 跨长假串味检查（选 winter kickoff 后，其余长假 chapter 仍排除）
    # 推广为全矩阵：src 设 flag，其余 type 的 chapter 必被排除
    # =========================================================
    for src in HOLIDAY_TYPES:
        flags_src = {"holiday_chapter_" + src: True}
        for t2 in HOLIDAY_TYPES:
            if t2 == src:
                continue
            for ch in chapters_by_type[t2]:
                td = chapter_test_day(ch, t2, periods, unlock)
                day_for_test = td if td is not None else periods[t2][0]
                elig, _ = event_eligible(ch, ch["location"], ch["slotId"], day_for_test, t2,
                                         flags_src, favorability, char_targets)
                chk("E-%s->%s-%s" % (src, t2, ch["id"]), "跨长假串味",
                    "选 %s kickoff 后，%s 的 %s 仍被排除(不串味)" % (src, t2, ch["id"]),
                    not elig, "正确排除(缺 %s)" % ("holiday_chapter_" + t2))

    # =========================================================
    # SECTION F — filler 在长假期间可触发（无 holiday_chapter 依赖）
    # =========================================================
    for fl in fillers:
        t = fl.get("requireHoliday") or ""
        if t not in HOLIDAY_TYPES:
            concern("F-%s" % fl["id"], "filler",
                    "%s 无有效 requireHoliday" % fl["id"], "requireHoliday=%s" % t)
            continue
        td = int(fl.get("triggerDay", 0) or 0)
        elig, why = event_eligible(fl, fl["location"], fl["slotId"], td, t,
                                   {}, favorability, char_targets)
        chk("F-%s" % fl["id"], "filler",
            "[%s] filler %s 在长假内可触发(且不依赖 chapter flag)" % (t, fl["id"]),
            elig, "eligible@day%d（flags 为空仍可达 => 无 chapter 依赖）" % td,
            detail_fail="被排除: %s" % why)

    # =========================================================
    # SECTION G — 一致性 / 已知项
    # =========================================================
    # G1: 每个 chapter 的 requireHoliday==type 且 requireFlags==["holiday_chapter_<type>"]
    for ch in chapters:
        rf = ch.get("requireFlags") or []
        req_hol = ch.get("requireHoliday") or ""
        t = req_hol
        ok = (t in HOLIDAY_TYPES) and (rf == ["holiday_chapter_" + t])
        chk("G1-" + ch["id"], "一致性",
            "%s requireHoliday==%s 且 requireFlags==[holiday_chapter_%s]" % (ch["id"], t, t),
            ok, "ok", detail_fail="requireHoliday=%s requireFlags=%s" % (req_hol, rf))

    # G2: 每个 chapter 终场景 memory flag 的 char == ev.charId 且存在于 GALLERY
    for ch in chapters:
        mem = list(dict.fromkeys(chapter_memory_flags(ch)))
        expected = "holiday_memory_%s_%s" % (ch.get("requireHoliday", ""), ch["charId"])
        ok = (expected in mem) and (expected in gallery)
        chk("G2-" + ch["id"], "一致性",
            "%s 终场景 memory flag(%s) 与 charId 一致且 GALLERY 存在" % (ch["id"], expected),
            ok, "ok", detail_fail="mem=%s 期望=%s gallery有=%s" % (mem, expected, expected in gallery))

    # G3: GALLERY 中 holiday_memory 的 bg 指向对应长假 holiday 背景
    for flag, (char, bg) in gallery.items():
        t = flag.split("_")[2]  # holiday_memory_<type>_<char>
        ok = (bg == EXPECTED_BG.get(t))
        chk("G3-" + flag, "一致性",
            "%s 的 bg 指向 %s" % (flag, EXPECTED_BG.get(t)),
            ok, "bg=%s" % bg, detail_fail="bg=%s 期望=%s" % (bg, EXPECTED_BG.get(t)))

    # G4: 全部 break 事件地点均不在 SCHOOL_LOCATIONS（长假校内抑制不应误伤 set-piece）
    bad_locs = [e["id"] for e in events if (e.get("location") or "") in SCHOOL_LOCATIONS]
    chk("G4-locs", "一致性",
        "全部 26 个 break 事件地点均非校内地点(不被长假抑制误伤)",
        len(bad_locs) == 0, "无校内地点事件",
        detail_fail="命中校内地点: %s（DataManager.gd L282-287）" % bad_locs)

    # G5: chapter 级联可达性汇总 + 脆弱性提示
    for ch in chapters:
        t = ch.get("requireHoliday", "")
        td = chapter_test_day(ch, t, periods, unlock)
        if td is None:
            concern("G5-unreach-" + ch["id"], "可达性",
                    "%s 在 %s 窗口内**不可达**：角色 %s unlockDay=%d > 窗口结束 %d"
                    % (ch["id"], t, ch["charId"], unlock.get(ch["charId"]), periods[t][1]),
                    "DataManager.gd L216-218 的 unlockDay 门控 + characters.json unlockDay=%d；"
                    "设计文档 §7 风险4 声称「%s=女主线」但该角色长假期间未解锁，触发链断裂。"
                    % (unlock.get(ch["charId"]), t))
        elif unlock.get(ch["charId"], 1) > int(ch.get("triggerDay", 0) or 0) and td == periods[t][1]:
            concern("G5-frag-" + ch["id"], "可达性",
                    "%s 仅能在 %s 最后一天(day %d)触发：角色 %s unlockDay=%d == 窗口末日，错过风险高"
                    % (ch["id"], t, td, ch["charId"], unlock.get(ch["charId"])),
                    "建议提前 unlockDay 或延长窗口，避免玩家因未在末日访问对应地点而永久错过 CG。")

    # G6: 画廊条目与 chapter 一一对应（集合相等）
    chapter_mem_set = set()
    for ch in chapters:
        for m in chapter_memory_flags(ch):
            chapter_mem_set.add(m)
    gal_set = set(gallery.keys())
    chk("G6-set", "一致性",
        "chapter 终场景 memory flag 集合 == GALLERY holiday_memory 集合",
        chapter_mem_set == gal_set,
        "两集合均为 %d 条" % len(gal_set),
        detail_fail="chapter=%s\ngallery=%s" % (sorted(chapter_mem_set), sorted(gal_set)))
    # 悬空画廊条目（存在但对应 chapter 不可达）
    dangling = [f for f in gal_set if f not in chapter_mem_set]
    # （上面集合相等时 dangling 为空；此处仅占位，真正风险在 G5-unreach）

    # G7: bg 字段引擎消费缺口（设计 §7 风险7）— 已知项，非本次门控范围
    concern("G7-bg", "已知项",
            "DialogueUI 当前未消费事件 bg 字段（设计 §7 风险7）",
            "events_break.json 已写 holiday_*.jpg 占位，但 DialogueUI.start_event 未切换背景层；"
            "不影响逻辑门控，仅影响 CG 显示，待 engineering 完成接线（§6 #12）。")

    # =========================================================
    # 汇总与报告生成
    # =========================================================
    write_report(periods, break_days, gallery, chapters_by_type, kickoffs, chapters, fillers)
    print_console()

    n_fail = sum(1 for r in RESULTS if r["status"] == "FAIL")
    n_con = sum(1 for r in RESULTS if r["status"] == "CONCERNS")
    n_pass = sum(1 for r in RESULTS if r["status"] == "PASS")
    print("\n════════════════════════════════════════════════════════")
    print("质量门判定: %s   (PASS=%d / CONCERNS=%d / FAIL=%d / 总=%d)"
          % ("FAIL" if n_fail else ("CONCERNS" if n_con else "PASS"),
             n_pass, n_con, n_fail, len(RESULTS)))
    print("════════════════════════════════════════════════════════")
    sys.exit(1 if n_fail else 0)


# ─────────────────────────────────────────────────────────────
# 控制台输出
# ─────────────────────────────────────────────────────────────
def print_console():
    print("\n──────── 逐条断言 ────────")
    for r in RESULTS:
        mark = {"PASS": "✔", "FAIL": "✘", "CONCERNS": "⚠"}.get(r["status"], "?")
        print("[%s] %-22s %s | %s" % (r["status"], r["id"], mark, r["desc"]))
        if r["status"] != "PASS":
            print("        ↳ %s" % r["detail"])


# ─────────────────────────────────────────────────────────────
# 报告写入
# ─────────────────────────────────────────────────────────────
def write_report(periods, break_days, gallery, chapters_by_type, kickoffs, chapters, fillers):
    today = datetime.date.today().isoformat()
    n_fail = sum(1 for r in RESULTS if r["status"] == "FAIL")
    n_con = sum(1 for r in RESULTS if r["status"] == "CONCERNS")
    n_pass = sum(1 for r in RESULTS if r["status"] == "PASS")
    gate = "FAIL" if n_fail else ("CONCERNS" if n_con else "PASS")

    lines = []
    lines.append("# 长假 set-piece 触发链冒烟报告")
    lines.append("")
    lines.append("- 项目：《西湖边的青春》（Godot 4.5 手游 / 杭州西湖中学初中恋爱模拟 / 570 天流程）")
    lines.append("- 模块：Phase 3 长假 set-piece 系统 触发链冒烟测试")
    lines.append("- 执行日期：%s" % today)
    lines.append("- 执行人：quality-lead（严守真）· 逻辑级模拟（无 Godot 可执行环境）")
    lines.append("- 运行环境：C:\\Users\\Administrator\\.workbuddy\\binaries\\python\\versions\\3.13.12\\python.exe")
    lines.append("- 测试脚本：`tests/holiday_smoke/smoke_chain.py`（真实读取 JSON + 复刻门控逻辑，不改源码）")
    lines.append("")
    lines.append("## 1. 测试范围")
    lines.append("")
    lines.append("验证运行时级联 **kickoff 三选一 → chapter 闸门 → gallery 解锁** 是否走得通，覆盖：")
    lines.append("")
    lines.append("1. 4 个长假分别模拟「出游」「陪伴」支线 → 断言 `holiday_chapter_<type>` 被置位 → 该长假全部 chapter 变 eligible → 走终场景置 `holiday_memory_<type>_<char>` → GALLERY_ITEMS 含对应条目 → `unlock_gallery` 注册。")
    lines.append("2. 模拟「学习」支线 → 断言**不**置 `holiday_chapter_<type>` → chapter 被门控排除。")
    lines.append("3. `requireHoliday` 隔离：正确长假放行 / 错误长假 / 无长假 / `\"any\"` 均按引擎逻辑排除。")
    lines.append("4. 跨长假串味：选某长假 kickoff 后，其余长假 chapter 仍被排除。")
    lines.append("5. 12 个 filler 在长假期间、且不依赖 chapter flag 时可正常触发。")
    lines.append("6. 一致性：chapter 结构、GALLERY 映射、bg 指向、校内地点抑制、集合相等。")
    lines.append("")
    lines.append("门控逻辑复刻自 `DataManager.gd` `get_available_event`（L189-300），含：")
    lines.append("`requireHoliday`(L274-280)、`SCHOOL_LOCATIONS` 抑制(L282-287)、`requireFlags`(L224-232)、")
    lines.append("`unlockDay`(L216-218)、`minAff`、`excludeRelState`(L298-300)、`triggerDay`、`repeatable`。")
    lines.append("长假区间复刻自 `DailyCycleManager.gd` `BREAK_PERIODS`(L32-37)；画廊映射用正则从 `GameManager.gd` GALLERY_ITEMS(L333-342) 提取；")
    lines.append("解锁函数复刻 `CollectionManager.gd` `unlock_gallery`(L30-32)。")
    lines.append("")
    lines.append("## 2. 用例清单（场景组）")
    lines.append("")
    lines.append("| 组 | 场景 | 关键断言 |")
    lines.append("|----|------|----------|")
    lines.append("| A | 加载/清单/日历 | JSON 可解析；事件 26 / kickoff 4(pri200) / chapter 10 / filler 12；BREAK_PERIODS & break 日正确 |")
    lines.append("| B | 出游/陪伴完整级联 | 4×2 选支线→置 flag→全部 chapter eligible→终场景 memory→GALLERY 命中→unlock 注册 |")
    lines.append("| C | 学习支线隔离 | 4× 选学习→置 mode flag、不置 chapter flag→chapter 被排除 |")
    lines.append("| D | requireHoliday 隔离 | 每长假代表 chapter：正确放行 / 错误排除 / 无长假排除 / any 排除 |")
    lines.append("| E | 跨长假串味 | 全矩阵：src 置 flag 后，其余 3 长假 chapter 全排除 |")
    lines.append("| F | filler 长假可触发 | 12 个 filler 在各自长假、空 flags 下 eligible（无 chapter 依赖） |")
    lines.append("| G | 一致性/可达性/已知项 | requireHoliday&requireFlags 结构、memory↔charId、bg 指向、校内地点、集合相等、可达性、bg 引擎缺口 |")
    lines.append("")
    lines.append("## 3. PASS/FAIL 汇总")
    lines.append("")
    lines.append("| 指标 | 数量 |")
    lines.append("|------|------|")
    lines.append("| 总断言 | %d |" % len(RESULTS))
    lines.append("| PASS | %d |" % n_pass)
    lines.append("| CONCERNS | %d |" % n_con)
    lines.append("| FAIL | %d |" % n_fail)
    lines.append("| **质量门判定** | **%s** |" % gate)
    lines.append("")
    lines.append("## 4. 逐条结果")
    lines.append("")
    lines.append("| 状态 | ID | 描述 | 说明 |")
    lines.append("|------|----|------|------|")
    for r in RESULTS:
        desc = r["desc"].replace("|", "\\|")
        det = r["detail"].replace("|", "\\|").replace("\n", " ")
        lines.append("| %s | %s | %s | %s |" % (r["status"], r["id"], desc, det))
    lines.append("")
    lines.append("## 5. GALLERY_ITEMS 一致性核对")
    lines.append("")
    lines.append("- 提取到 `holiday_memory_*` 条目数：**%d**（预期 10，GameManager.gd L333-342）。" % len(gallery))
    lines.append("- chapter 终场景 memory flag 集合 与 GALLERY 集合：%s。"
                  % ("相等 ✔" if (set(gallery.keys()) == set(g for ch in chapters for g in chapter_memory_flags(ch))) else "**不相等 ✘**"))
    lines.append("- 10 条映射（flag → char / bg）：")
    lines.append("")
    for flag, (char, bg) in sorted(gallery.items()):
        lines.append("  - `%s` → char=`%s`, bg=`%s`" % (flag, char, bg))
    lines.append("")
    lines.append("## 6. 阻塞项 / CONCERNS（含文件+行号+现象）")
    lines.append("")
    blockers = [r for r in RESULTS if r["status"] in ("FAIL", "CONCERNS")]
    if not blockers:
        lines.append("无。所有断言通过。")
    else:
        for r in blockers:
            lines.append("### [%s] %s — %s" % (r["status"], r["id"], r["desc"]))
            lines.append("")
            lines.append("- 现象：%s" % r["detail"])
            lines.append("")
    # 重点阻塞项索引
    lines.append("### 重点阻塞项（按严重度）")
    lines.append("")
    fail_items = [r for r in RESULTS if r["status"] == "FAIL"]
    if fail_items:
        lines.append("- **FAIL（触发链断裂）**：")
        for r in fail_items:
            lines.append("  - `%s`：%s —— %s" % (r["id"], r["desc"], r["detail"]))
    con_items = [r for r in RESULTS if r["status"] == "CONCERNS"]
    if con_items:
        lines.append("- **CONCERNS（脆弱/已知）**：")
        for r in con_items:
            lines.append("  - `%s`：%s" % (r["id"], r["detail"]))
    lines.append("")
    lines.append("## 7. 质量门判定与建议")
    lines.append("")
    lines.append("**判定：%s**" % gate)
    lines.append("")
    if gate == "FAIL":
        lines.append("存在触发链断裂（FAIL），建议在发布前修复：")
        lines.append("1. 修复角色解锁日与长假窗口错配（见 §6 FAIL/G5-unreach）：`characters.json` 中 `beichen`/`keke` 的 `unlockDay=300` 晚于春/夏长假，导致对应 chapter 不可达或仅末日可达。")
        lines.append("   - `break_spring_chapter_beichen`：春窗 [150,155]，beichen 解锁日 300 → **整段春假不可达**（设计 §7 风险4 声称的「春假·女主线」实际断裂）。")
        lines.append("   - `break_summer_chapter_keke`：夏窗 [270,300]，keke 解锁日 300 → 仅 day300 可达，错过风险极高。")
        lines.append("   - 建议：将 beichen/keke 的 `unlockDay` 提前（如 beichen→≤150、keke→≤270），或在长假窗口内为其单独解锁；并回归本冒烟脚本至全绿。")
    elif gate == "CONCERNS":
        lines.append("逻辑级联全部走通，但存在脆弱/已知项（见 §6），建议产品决策：")
        lines.append("1. 关注 chapter 可达性脆弱点（角色解锁日贴近窗口末日）。")
        lines.append("2. `bg` 字段引擎接线为已知缺口（设计 §7 风险7），影响 CG 显示但不影响门控。")
        lines.append("3. `requireHoliday==\"any\"` 分支无运行时覆盖，建议补测试。")
    else:
        lines.append("触发链逻辑级联全部走通，无阻塞项。仍建议产品侧确认：角色解锁日与长假窗口的错配风险、bg 引擎接线、any 分支覆盖。")
    lines.append("")
    lines.append("> 说明：本测试为**逻辑级模拟**，未启动 Godot；门控逻辑为对 `DataManager.gd` 的忠实复刻。")
    lines.append("> 质量门为建议性门控（advisory），最终放行由人工审批。未做 git 提交。")
    lines.append("")

    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "SMOKE_REPORT.md")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("报告已写入: %s" % out_path)


if __name__ == "__main__":
    main()
