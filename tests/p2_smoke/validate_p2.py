#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""
P2 生活支柱补强 — 独立质量门校验脚本（逻辑级，无 Godot 运行时）
================================================================
质量负责人(quality-lead) 对《西湖边的青春》P2 落地产物做 trust-but-verify：
用 Python 解析真实 JSON + 文本扫描 .gd 源码，逐条断言 A~J。

运行：
  C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe ^
      D:\zkgame\tests\p2_smoke\validate_p2.py

设计基准（来自 P2 设计回顾，逐条在盘上验证）：
  D1 春节 / D2 兼职周薪 / D3 宠物进 GALLERY / D5 requireMoney 门控
  D6 ITEM_DB+addItem / D7 成瘾机制不冲突 / D8 接受16件
"""
import json
import os
import re
import sys

# ── 路径 ──────────────────────────────────────────────────────
ROOT = r"D:\zkgame"
SCRIPTS = os.path.join(ROOT, "scripts")
EVENTS = os.path.join(SCRIPTS, "events_life.json")
DCM = os.path.join(SCRIPTS, "DailyCycleManager.gd")
GM = os.path.join(SCRIPTS, "GameManager.gd")
DM = os.path.join(SCRIPTS, "DataManager.gd")
DUI = os.path.join(SCRIPTS, "DialogueUI.gd")
MG = os.path.join(SCRIPTS, "MainGame.gd")

# ── 引擎权威合法 statDelta 键 ────────────────────────────────
# 来源：GameManager.stats 定义(7维) + 独立 money 变量 + add_stat() 对 "money" 特判。
# add_stat() 仅对 stats.has(key) 或 key=="money" 生效，其余键被静默丢弃 => 未知键即缺陷。
LEGAL_STAT_KEYS = {"intellect", "strength", "social", "art", "charm", "stress", "addict", "money"}

# ── P2 预期 16 事件 ──────────────────────────────────────────
P2_INT = ["int_idol_fanfeed", "int_idol_merch", "int_idol_concert",
          "int_pet_meet", "int_pet_adopt", "int_pet_care", "int_pet_moment",
          "int_craft_make", "int_craft_gift"]
P2_ECO = ["eco_lucky_money", "eco_parttime_apply", "eco_parttime_firstshift",
          "eco_save_set_goal", "eco_save_deposit", "eco_save_claim", "eco_shop_dilemma"]
P2_ALL = P2_INT + P2_ECO

# 已知全局 flag（由引擎置位 / 设计公认），用于 requireFlags 闭环兜底
KNOWN_GLOBAL_FLAGS = {"flag_has_parttime_job", "has_parttime_job", "pet_orange_cat"}

results = []  # (letter, status, detail)


def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def record(letter, status, detail):
    results.append((letter, status, detail))
    print(f"[{status}] {letter}: {detail}")


def collect_stat_keys(ev):
    """递归收集事件内所有 statDelta 的键（含 scenes/choices 嵌套）。"""
    keys = set()
    def walk(obj):
        if isinstance(obj, dict):
            if "statDelta" in obj and isinstance(obj["statDelta"], dict):
                keys.update(obj["statDelta"].keys())
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for v in obj:
                walk(v)
    walk(ev)
    return keys


def collect_set_flags(ev):
    """递归收集事件内所有显式 setFlag 字符串。"""
    out = set()
    def walk(obj):
        if isinstance(obj, dict):
            if "setFlag" in obj and isinstance(obj["setFlag"], str):
                out.add(obj["setFlag"])
            for v in obj.values():
                walk(v)
        elif isinstance(obj, list):
            for v in obj:
                walk(v)
    walk(ev)
    return out


def main():
    # ── A. JSON 可解析 + 总数 == 60 ───────────────────────────
    try:
        with open(EVENTS, "r", encoding="utf-8") as f:
            data = json.load(f)
        a_ok = isinstance(data, list) and len(data) == 60
        record("A", "PASS" if a_ok else "FAIL",
               f"events_life.json 解析成功，事件总数 = {len(data)} (期望 60)")
    except Exception as e:
        record("A", "FAIL", f"JSON 解析失败: {e}")
        print_summary()
        return

    # ── B. id 唯一 ───────────────────────────────────────────
    ids = [ev.get("id") for ev in data if isinstance(ev, dict)]
    dup = sorted({x for x in ids if ids.count(x) > 1})
    record("B", "PASS" if not dup else "FAIL",
           f"事件 id 数 = {len(ids)}，重复 id = {dup if dup else '无'}")

    by_id = {ev.get("id"): ev for ev in data if isinstance(ev, dict)}

    # ── C. 16 个 P2 事件存在 ─────────────────────────────────
    missing = [eid for eid in P2_ALL if eid not in by_id]
    record("C", "PASS" if not missing else "FAIL",
           f"P2 事件缺失 = {missing if missing else '无'} "
           f"(int_*{len(P2_INT)} + eco_*{len(P2_ECO)} = {len(P2_ALL)})")

    # ── D. P2 charId 必须为 null/缺失，且不得含 requireRelState/excludeRelState ──
    d_bad = []
    for eid in P2_ALL:
        ev = by_id.get(eid)
        if ev is None:
            continue
        cid = ev.get("charId", None)
        if cid is not None:
            d_bad.append(f"{eid}:charId={cid!r}")
        if "requireRelState" in ev or "excludeRelState" in ev:
            d_bad.append(f"{eid}:含 requireRelState/excludeRelState")
    record("D", "PASS" if not d_bad else "FAIL",
           f"P2 触关系状态机风险项 = {d_bad if d_bad else '无'} (charId 须为 null/缺失)")

    # ── E. P2 statDelta 仅合法键 ─────────────────────────────
    e_bad = []
    for eid in P2_ALL:
        ev = by_id.get(eid)
        if ev is None:
            continue
        bad_keys = collect_stat_keys(ev) - LEGAL_STAT_KEYS
        if bad_keys:
            e_bad.append(f"{eid}:{sorted(bad_keys)}")
    record("E", "PASS" if not e_bad else "FAIL",
           f"P2 非法 statDelta 键 = {e_bad if e_bad else '无'} ; "
           f"合法键集={sorted(LEGAL_STAT_KEYS)}")

    # ── F. flag 串联闭环 ─────────────────────────────────────
    # 提供的 flag = 所有事件显式 setFlag ∪ 非可重复事件 id 自动置位 ∪ 已知全局
    # （DataManager 约定：非 repeatable 事件触发后 flags[自身id]=true）
    provided = set(KNOWN_GLOBAL_FLAGS)
    for ev in data:
        if not isinstance(ev, dict):
            continue
        provided |= collect_set_flags(ev)
        if not ev.get("repeatable", False):
            provided.add(ev.get("id"))
    unmet = []
    for eid in P2_ALL:
        ev = by_id.get(eid)
        if ev is None:
            continue
        req = ev.get("requireFlags", [])
        if req is None:
            req = []
        for fl in req:
            if fl not in provided:
                unmet.append(f"{eid}:requireFlags[{fl}]")
    record("F", "PASS" if not unmet else "FAIL",
           f"未被满足的 requireFlags = {unmet if unmet else '无'} "
           f"(已识别置位源 {len(provided)} 个)")

    # ── 读取 .gd 文本 ────────────────────────────────────────
    dcm_txt = read_text(DCM)
    gm_txt = read_text(GM)
    dm_txt = read_text(DM)
    dui_txt = read_text(DUI)
    mg_txt = read_text(MG)

    # ── G. requireMoney 门控 + eco_save_claim requireMoney:100 + eco_save_deposit 无 money 扣减 ──
    g1 = ("req_money" in dm_txt) and ("GameManager.money < req_money" in dm_txt)
    eco_claim = by_id.get("eco_save_claim", {})
    g2 = eco_claim.get("requireMoney", 0) == 100
    eco_dep = by_id.get("eco_save_deposit", {})
    g3 = "money" not in collect_stat_keys(eco_dep)   # 存款纯叙事，不应扣 money
    g_checks = [g1, g2, g3]
    record("G", "PASS" if all(g_checks) else "FAIL",
           f"DataManager.requireMoney 门控={'有' if g1 else '无'}; "
           f"eco_save_claim.requireMoney={eco_claim.get('requireMoney')}(期望100)={g2}; "
           f"eco_save_deposit 含 money 扣减={'是' if not g3 else '否'}={g3}")

    # ── H. DailyCycle 春节+兼职 / advance_time 调用 / GALLERY pet / ITEM_DB handmade ──
    m95 = re.search(r'95:\s*\{', dcm_txt)
    h1 = (m95 is not None) and ('"🧧 春节"' in dcm_txt) and ('"spring_festival"' in dcm_txt)
    h2 = "func _check_parttime_income" in dcm_txt
    h3 = "_check_parttime_income()" in gm_txt          # advance_time 内的调用点
    h4 = ("GALLERY_ITEMS" in gm_txt) and ("pet_orange_cat" in gm_txt)
    h5 = ('"handmade_gift"' in gm_txt) and ("ITEM_DB" in gm_txt)
    h_checks = [h1, h2, h3, h4, h5]
    record("H", "PASS" if all(h_checks) else "FAIL",
           f"day95春节={h1}; _check_parttime_income函数={h2}; advance_time调用={h3}; "
           f"GALLERY含pet_orange_cat={h4}; ITEM_DB含handmade_gift={h5}")

    # ── I. MainGame fest_narrative_map spring->eco_lucky_money ; DialogueUI 两处 addItem ──
    i1 = re.search(r'"spring_festival"\s*:\s*"eco_lucky_money"', mg_txt) is not None
    i2 = ('event_data.get("addItem"' in dui_txt) or ("event_data.get('addItem'" in dui_txt)
    i3 = ('scene.has("addItem")' in dui_txt) or ('scene["addItem"]' in dui_txt)
    craft = by_id.get("int_craft_make", {})
    i4 = "addItem" in json.dumps(craft, ensure_ascii=False)   # 场景级 addItem 生效点
    i_checks = [i1, i2, i3, i4]
    record("I", "PASS" if all(i_checks) else "FAIL",
           f"fest_narrative_map spring_festival->eco_lucky_money={i1}; "
           f"DialogueUI事件级addItem={i2}; 场景级addItem={i3}; int_craft_make场景级addItem={i4}")

    # ── J. 打印 2 个 P2 事件完整片段供人工目视 ───────────────
    print("\n===== J. 人工目视样本（2 个 P2 事件完整 JSON）=====")
    for sid in ["int_craft_make", "eco_save_claim"]:
        ev = by_id.get(sid)
        if ev is not None:
            print(f"\n--- {sid} ---")
            print(json.dumps(ev, ensure_ascii=False, indent=2))
    record("J", "PASS", "已打印样本: int_craft_make / eco_save_claim")

    print_summary()


def print_summary():
    print("\n" + "=" * 64)
    print("P2 质量门校验汇总")
    print("=" * 64)
    total = len(results)
    passed = sum(1 for _, s, _ in results if s == "PASS")
    concerns = sum(1 for _, s, _ in results if s == "CONCERNS")
    failed = sum(1 for _, s, _ in results if s == "FAIL")
    print(f"断言总数: {total} | PASS: {passed} | CONCERNS: {concerns} | FAIL: {failed}")
    if failed > 0:
        gate = "FAIL"
    elif concerns > 0:
        gate = "CONCERNS"
    else:
        gate = "PASS"
    print(f"质量门总判定: **{gate}**")
    for letter, status, detail in results:
        print(f"  {letter}: {status}")
    print("=" * 64)
    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
