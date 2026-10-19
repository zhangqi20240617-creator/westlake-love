#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
冷战（cold）逻辑级冒烟测试
====================================================================
环境：本机无 Godot 可执行文件，无法做引擎内 playtest。
策略：将 scripts/DataManager.gd L273-284 中真实的事件过滤 predicate
      逐字复刻为 Python 函数，跑在真实事件 JSON 上，产出可证伪证据。

Predicate 来源（scripts/DataManager.gd L273-284，已逐字确认）：
    var rel_char = ev.get("charId", "")
    if rel_char == null: rel_char = ""
    if rel_char != "":
        var req_rel = ev.get("requireRelState", "")
        if req_rel == null: req_rel = ""
        if req_rel != "" and RelationshipManager.get_rel_state(rel_char) != req_rel: continue
        var ex_rel = ev.get("excludeRelState", "")
        if ex_rel == null: ex_rel = ""
        if ex_rel != "" and RelationshipManager.get_rel_state(rel_char) == ex_rel: continue

说明：get_rel_state(char) 是关系状态机输出（Phase 2 已独立验证的组件）。
本测试**不重算状态机**，把它当作输入参数 rel_state 注入，只测「过滤 predicate」本身。

断言（全部 PASS 才整体 PASS）：
  A. COLD 场景：每个在 cold 下 eligible 的角色事件，其 requireRelState 必须 == "cold"。
     （回归核心：证明补丁生效——excludeRelState:"cold" 压住了普通日常弹窗，
      且无锁普通事件不会漏出。）
  B. COLD 场景：requireRelState=="cold" 的 recover 事件必须 eligible。
     至少验证 keke/beichen/jingjing_m/zijun 各自的 *_cold_recover_01。
  C. NON-COLD 场景（以 familiar 为例）：带 excludeRelState:"cold" 的事件必须 eligible
     （证明 exclude 只在 cold 触发，不误伤正常状态）。验证样本 keke_meet_01。
  D. 不变量：全量事件中同时含 requireRelState 与 excludeRelState 的数量为 0。
  E. 通用事件：events_daily.json（charId=null）在所有 rel_state 下均 eligible。

纯 Python + 标准库（json/os/sys），不依赖 Godot。
"""

import json
import os
import sys

# ----------------------------------------------------------------------------
# 配置：8 个事件文件（相对脚本所在仓库根目录的 scripts/）
# ----------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)              # .../zkgame
SCRIPTS_DIR = os.path.join(REPO_ROOT, "scripts")

EVENT_FILES = [
    "events_daily",
    "events_special",
    "events_wanqing",
    "events_yutong",
    "events_xiaoxia",
    "events_jingjing",
    "events_keke",
    "events_male",
]

# 需要覆盖的关系状态
REL_STATES = ["cold", "familiar", "friend", "close", "crush"]

# 断言 B 的样本 recover 事件（角色 -> 期望事件 id）
RECOVER_SAMPLES = {
    "keke":      "kk_cold_recover_01",
    "beichen":   "bc_cold_recover_01",
    "jingjing_m":"jm_cold_recover_01",
    "zijun":     "zj_cold_recover_01",
}

# 断言 C 的样本事件
EXCLUDE_SAMPLE_ID = "keke_meet_01"


# ----------------------------------------------------------------------------
# 忠实复刻 DataManager.gd L273-284 的过滤 predicate
# ----------------------------------------------------------------------------
def _norm(v):
    """
    复刻 GDScript 的 `if x == null: x = ""` 语义。
    JSON 的 null 在 Python 中为 None；dict.get(key, "") 在 key 存在且值为 null 时
    返回 None（不会回退默认值）。因此统一把 None 规约为空串 ""（表示"无锁"）。
    """
    if v is None:
        return ""
    return v


def is_eligible(ev, rel_state):
    """
    复刻 DataManager.gd L273-284 的事件过滤判断。
    入参：
        ev        : dict，单条事件（来自真实事件 JSON）
        rel_state : str，注入的关系状态（替代 get_rel_state(char)）
    返回：True 表示在给定 rel_state 下该事件 eligible（可被抽取），False 表示被跳过。
    """
    rel_char = _norm(ev.get("charId", ""))
    if rel_char != "":
        req_rel = _norm(ev.get("requireRelState", ""))
        if req_rel != "" and rel_state != req_rel:
            return False
        ex_rel = _norm(ev.get("excludeRelState", ""))
        if ex_rel != "" and rel_state == ex_rel:
            return False
    return True


# ----------------------------------------------------------------------------
# 加载事件
# ----------------------------------------------------------------------------
def load_events():
    """
    返回 (events, daily_events)
      events       : list of dict，每条含 _file / _id / _charId / _req / _ex / _is_char
      daily_events : 仅 events_daily.json 中的事件（用于断言 E）
    """
    events = []
    daily_events = []
    missing = []
    for name in EVENT_FILES:
        path = os.path.join(SCRIPTS_DIR, name + ".json")
        if not os.path.isfile(path):
            missing.append(path)
            continue
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, list):
            raise ValueError("期望顶层是数组: %s" % path)
        for ev in data:
            char_id = _norm(ev.get("charId", ""))
            req = _norm(ev.get("requireRelState", ""))
            ex = _norm(ev.get("excludeRelState", ""))
            rec = {
                "_file": name,
                "_id": ev.get("id", "<no-id>"),
                "_charId": char_id,
                "_req": req,
                "_ex": ex,
                "_is_char": char_id != "",   # charId 为空/空串/None -> 通用事件
                "ev": ev,
            }
            events.append(rec)
            if name == "events_daily":
                daily_events.append(rec)
    if missing:
        raise FileNotFoundError("缺失事件文件: %s" % ", ".join(missing))
    return events, daily_events


# ----------------------------------------------------------------------------
# 主流程
# ----------------------------------------------------------------------------
def main():
    print("=" * 72)
    print("冷战（cold）逻辑级冒烟测试  —  复刻 DataManager.gd L273-284 predicate")
    print("=" * 72)
    print("事件目录 : %s" % SCRIPTS_DIR)
    print("关系状态 : %s" % ", ".join(REL_STATES))
    print("")

    events, daily_events = load_events()
    total = len(events)
    char_events = [e for e in events if e["_is_char"]]
    print("载入事件总数: %d  (角色事件: %d, 通用/系统事件: %d)"
          % (total, len(char_events), total - len(char_events)))
    print("")

    # ---- 对每个 rel_state 跑全量事件，收集 eligible id 列表 ----
    eligible_by_state = {}
    for rs in REL_STATES:
        elig = [e["_id"] for e in events if is_eligible(e["ev"], rs)]
        eligible_by_state[rs] = elig

    print("-" * 72)
    print("各关系状态下 eligible 事件数量")
    print("-" * 72)
    for rs in REL_STATES:
        n_char = sum(1 for e in events
                     if e["_is_char"] and is_eligible(e["ev"], rs))
        n_gen = sum(1 for e in events
                    if (not e["_is_char"]) and is_eligible(e["ev"], rs))
        print("  %-9s : eligible 总 %3d  (角色 %3d / 通用 %3d)"
              % (rs, len(eligible_by_state[rs]), n_char, n_gen))
    print("")

    # ---- COLD 场景 eligible 角色事件清单（断言 A 的证据）----
    cold_eligible_char = [e for e in events
                          if e["_is_char"] and is_eligible(e["ev"], "cold")]
    print("-" * 72)
    print("COLD 场景下 eligible 的角色事件清单（应为各 *_cold_recover_01 等 requireRelState:cold）")
    print("-" * 72)
    if cold_eligible_char:
        for e in cold_eligible_char:
            print("  %-22s charId=%-12s requireRelState=%s"
                  % (e["_id"], e["_charId"], e["_req"] or "-"))
    else:
        print("  （无）")
    print("")

    # =====================================================================
    # 断言 A：COLD 下 eligible 的角色事件，其 requireRelState 必须 == "cold"
    # =====================================================================
    a_violations = []
    for e in cold_eligible_char:
        if e["_req"] != "cold":
            a_violations.append(e["_id"])
    print("-" * 72)
    print("断言 A : COLD 下所有 eligible 角色事件的 requireRelState == 'cold'")
    print("-" * 72)
    if not a_violations:
        print("  PASS  ✅  无可疑漏出；COLD eligible 角色事件均受 requireRelState:cold 锁约束。")
    else:
        print("  FAIL  ❌  以下角色事件在 COLD 下 eligible 但 requireRelState != 'cold'（普通/无锁事件漏出）：")
        for vid in a_violations:
            print("        - %s" % vid)

    # =====================================================================
    # 断言 B：requireRelState=="cold" 的 recover 事件必须 eligible（COLD）
    # =====================================================================
    cold_eligible_ids = set(eligible_by_state["cold"])
    recover_all = [e for e in events if e["_req"] == "cold"]
    b_missing = [e["_id"] for e in recover_all if e["_id"] not in cold_eligible_ids]
    b_sample_fail = []
    for char, eid in RECOVER_SAMPLES.items():
        if eid not in cold_eligible_ids:
            b_sample_fail.append((char, eid))
    print("-" * 72)
    print("断言 B : requireRelState=='cold' 的 recover 事件在 COLD 下必须 eligible")
    print("-" * 72)
    print("  全量 requireRelState:cold 事件数 = %d" % len(recover_all))
    if not b_missing and not b_sample_fail:
        print("  PASS  ✅  全部 %d 个 cold 锁事件 eligible；样本 keke/beichen/jingjing_m/zijun 的 *_cold_recover_01 均出现。"
              % len(recover_all))
    else:
        if b_missing:
            print("  FAIL  ❌  以下 requireRelState:cold 事件在 COLD 下未 eligible：")
            for vid in b_missing:
                print("        - %s" % vid)
        if b_sample_fail:
            print("  FAIL  ❌  样本 recover 事件缺失：")
            for char, eid in b_sample_fail:
                print("        - %s -> %s" % (char, eid))

    # =====================================================================
    # 断言 C：NON-COLD（familiar）下，带 excludeRelState:"cold" 的事件必须 eligible
    # =====================================================================
    familiar_eligible_ids = set(eligible_by_state["familiar"])
    ex_cold_events = [e for e in events if e["_ex"] == "cold"]
    c_missing = [e["_id"] for e in ex_cold_events if e["_id"] not in familiar_eligible_ids]
    c_sample_fail = EXCLUDE_SAMPLE_ID not in familiar_eligible_ids
    print("-" * 72)
    print("断言 C : NON-COLD（familiar）下，excludeRelState:'cold' 事件必须 eligible（不误伤正常状态）")
    print("-" * 72)
    print("  全量 excludeRelState:cold 事件数 = %d" % len(ex_cold_events))
    if not c_missing and not c_sample_fail:
        print("  PASS  ✅  全部 %d 个 excludeRelState:cold 事件在 familiar 下 eligible；样本 %s 出现。"
              % (len(ex_cold_events), EXCLUDE_SAMPLE_ID))
    else:
        if c_missing:
            print("  FAIL  ❌  以下 excludeRelState:cold 事件在 familiar 下被错误排除：")
            for vid in c_missing:
                print("        - %s" % vid)
        if c_sample_fail:
            print("  FAIL  ❌  样本事件 %s 在 familiar 下未 eligible。" % EXCLUDE_SAMPLE_ID)

    # =====================================================================
    # 断言 D：不变量——同时含 requireRelState 与 excludeRelState 的事件数为 0
    # =====================================================================
    both_lock = [e for e in events if e["_req"] != "" and e["_ex"] != ""]
    print("-" * 72)
    print("断言 D : 不变量——同时含 requireRelState 与 excludeRelState 的事件数 == 0")
    print("-" * 72)
    if not both_lock:
        print("  PASS  ✅  无事件同时携带两把锁。")
    else:
        print("  FAIL  ❌  发现 %d 个事件同时含两把锁（矛盾配置）：" % len(both_lock))
        for e in both_lock:
            print("        - %s (charId=%s, req=%s, ex=%s)"
                  % (e["_id"], e["_charId"], e["_req"], e["_ex"]))

    # =====================================================================
    # 断言 E：events_daily.json（charId=null）在所有 rel_state 下均 eligible
    # =====================================================================
    e_nonnull = [e for e in daily_events if e["_is_char"]]
    e_not_eligible = []
    for e in daily_events:
        for rs in REL_STATES:
            if not is_eligible(e["ev"], rs):
                e_not_eligible.append((e["_id"], rs))
    print("-" * 72)
    print("断言 E : 通用事件 events_daily.json（charId=null）在所有 rel_state 下 eligible")
    print("-" * 72)
    print("  events_daily.json 事件数 = %d" % len(daily_events))
    if not e_nonnull and not e_not_eligible:
        print("  PASS  ✅  所有通用事件 charId 均为 null，且在 %s 下均 eligible。"
              % "/".join(REL_STATES))
    else:
        if e_nonnull:
            print("  FAIL  ❌  events_daily.json 中存在非通用（含 charId）事件：")
            for e in e_nonnull:
                print("        - %s (charId=%s)" % (e["_id"], e["_charId"]))
        if e_not_eligible:
            print("  FAIL  ❌  以下通用事件在特定关系状态下未 eligible：")
            for vid, rs in e_not_eligible:
                print("        - %s @ %s" % (vid, rs))

    # =====================================================================
    # 汇总
    # =====================================================================
    results = {
        "A": not a_violations,
        "B": (not b_missing) and (not b_sample_fail),
        "C": (not c_missing) and (not c_sample_fail),
        "D": not both_lock,
        "E": (not e_nonnull) and (not e_not_eligible),
    }
    print("=" * 72)
    print("断言汇总")
    print("=" * 72)
    for k in ["A", "B", "C", "D", "E"]:
        mark = "PASS ✅" if results[k] else "FAIL ❌"
        print("  [%s] %s" % (k, mark))
    overall = all(results.values())
    print("-" * 72)
    print("整体结论: %s" % ("PASS ✅ 全部断言通过" if overall else "FAIL ❌ 存在未通过断言"))
    print("=" * 72)

    # 关键计数（质量门文档引用）
    print("")
    print("关键计数:")
    print("  载入事件总数                         : %d" % total)
    print("  COLD 下 eligible 角色事件数          : %d" % len(cold_eligible_char))
    print("  requireRelState:cold 事件数          : %d" % len(recover_all))
    print("  excludeRelState:cold 事件数          : %d" % len(ex_cold_events))
    print("  同时含两把锁的事件数（应为 0）       : %d" % len(both_lock))
    print("  events_daily.json 通用事件数         : %d" % len(daily_events))

    return 0 if overall else 1


if __name__ == "__main__":
    sys.exit(main())
