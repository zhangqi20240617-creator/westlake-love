# -*- coding: utf-8 -*-
"""
QA-OPENING-01 — 初一开学 + 军训系统 独立质量门禁
Owner: 质量组

覆盖范围：
  Q0  events_opening.json 文件可达性与 JSON 合法性
  Q1  开学事件链 4 条 manual_only 事件完整
  Q2  军训探索事件 ≥ 8 条，均含 requireHoliday: "training"
  Q3  training_end_ceremony 存在，manual_only: true，无 repeatable
  Q4  全局 event id 唯一（跨所有 EVENT_FILES）
  Q5  DailyCycleManager.BREAK_PERIODS 包含 training: [2, 14]
  Q6  SPECIAL_DATES 中 day 1 / day 14 均存在且 effect 正确
  Q7  DataManager.EVENT_FILES 包含 events_opening.json
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"
DAILY_CYCLE_GD = SCRIPTS / "DailyCycleManager.gd"
DATA_MANAGER_GD = SCRIPTS / "DataManager.gd"
OPENING_JSON = SCRIPTS / "events_opening.json"

# ── 期望值常量 ─────────────────────────────────────────────────────────────
OPENING_MANUAL_IDS = [
    "opening_day1_morning",
    "opening_day1_noon",
    "opening_day1_after",
    "opening_day1_eve",
]
TRAINING_HOLIDAY_MIN = 8    # requireHoliday:training 事件最少数量
TRAINING_END_ID = "training_end_ceremony"


# ═══════════════════════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════════════════════

def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def read_gd(path: Path) -> str:
    with path.open(encoding="utf-8") as f:
        return f.read()


def collect_all_event_ids() -> list[str]:
    """从 DataManager.EVENT_FILES 加载所有事件，返回全部 id 列表。"""
    gd_src = read_gd(DATA_MANAGER_GD)
    pattern = re.compile(r'"res://scripts/([^"]+\.json)"')
    filenames = pattern.findall(gd_src)
    ids = []
    for fn in filenames:
        p = SCRIPTS / fn
        if not p.exists():
            continue
        try:
            data = load_json(p)
            for ev in data:
                if isinstance(ev, dict) and "id" in ev:
                    ids.append(ev["id"])
        except Exception:
            pass
    return ids


# ═══════════════════════════════════════════════════════════════════════════
# 测试用例
# ═══════════════════════════════════════════════════════════════════════════

results: list[tuple[str, bool, str]] = []


def check(label: str, ok: bool, detail: str = ""):
    results.append((label, ok, detail))
    status = "PASS" if ok else "FAIL"
    mark = "✅" if ok else "❌"
    print(f"  {mark} [{status}] {label}" + (f"\n       {detail}" if detail else ""))


# ── Q0 ── 文件可达 + JSON 合法 ──────────────────────────────────────────────
print("\n[Q0] 文件可达性与 JSON 合法性")
try:
    opening_events = load_json(OPENING_JSON)
    check("Q0-readable", True, f"{len(opening_events)} 条事件")
    check("Q0-list-type", isinstance(opening_events, list))
except FileNotFoundError:
    check("Q0-readable", False, f"文件不存在: {OPENING_JSON}")
    opening_events = []
    print("  ⛔ Q0 FATAL — 后续测试跳过")
    # 继续运行其他不依赖 opening_events 的测试
except json.JSONDecodeError as e:
    check("Q0-json-valid", False, str(e))
    opening_events = []

# ── 工具：构建 opening id→event 字典 ─────────────────────────────────────
opening_by_id: dict = {ev.get("id"): ev for ev in opening_events if isinstance(ev, dict)}

# ── Q1 ── 开学事件链完整 ─────────────────────────────────────────────────────
print("\n[Q1] 开学事件链完整性")
for eid in OPENING_MANUAL_IDS:
    ev = opening_by_id.get(eid)
    found = ev is not None
    check(f"Q1-exists-{eid}", found, "" if found else f"缺少事件 id={eid}")
    if found:
        check(f"Q1-manual_only-{eid}", ev.get("manual_only") is True,
              f"manual_only={ev.get('manual_only')}")
        check(f"Q1-has-scenes-or-nodes-{eid}",
              "scenes" in ev or "nodes" in ev,
              "无 scenes / nodes 字段")

# ── Q2 ── 军训探索事件数量 ────────────────────────────────────────────────────
print("\n[Q2] 军训探索事件（requireHoliday: training）")
training_events = [
    ev for ev in opening_events
    if isinstance(ev, dict) and ev.get("requireHoliday") == "training"
]
check(f"Q2-training-event-count≥{TRAINING_HOLIDAY_MIN}",
      len(training_events) >= TRAINING_HOLIDAY_MIN,
      f"实际找到 {len(training_events)} 条，期望 ≥ {TRAINING_HOLIDAY_MIN}")
for ev in training_events:
    eid = ev.get("id", "?")
    has_content = "scenes" in ev or "nodes" in ev
    check(f"Q2-has-content-{eid}", has_content,
          "缺少 scenes/nodes 字段")

# ── Q3 ── training_end_ceremony ──────────────────────────────────────────────
print(f"\n[Q3] 联欢晚会事件 {TRAINING_END_ID}")
end_ev = opening_by_id.get(TRAINING_END_ID)
check("Q3-exists", end_ev is not None)
if end_ev:
    check("Q3-manual_only", end_ev.get("manual_only") is True,
          f"manual_only={end_ev.get('manual_only')}")
    check("Q3-no-repeatable", "repeatable" not in end_ev or end_ev.get("repeatable") is False,
          f"repeatable={end_ev.get('repeatable')}")
    has_content = "scenes" in end_ev or "nodes" in end_ev
    check("Q3-has-content", has_content)

# ── Q4 ── 全局 id 唯一性 ──────────────────────────────────────────────────────
print("\n[Q4] 全局 event id 唯一性")
all_ids = collect_all_event_ids()
seen: dict[str, int] = {}
for eid in all_ids:
    seen[eid] = seen.get(eid, 0) + 1
dupes = {k: v for k, v in seen.items() if v > 1}
check("Q4-no-duplicate-ids",
      len(dupes) == 0,
      f"重复 id: {list(dupes.keys())}" if dupes else "")
check("Q4-total-ids-nonzero", len(all_ids) > 0, f"加载到 {len(all_ids)} 个事件 id")

# ── Q5 ── DailyCycleManager BREAK_PERIODS 包含 training ─────────────────────
print("\n[Q5] DailyCycleManager.BREAK_PERIODS 包含 training 区间")
dcm_src = read_gd(DAILY_CYCLE_GD)
# 匹配 "training": [2, 14]（允许空格变体）
has_training_break = bool(re.search(r'"training"\s*:\s*\[\s*2\s*,\s*14\s*\]', dcm_src))
check("Q5-BREAK_PERIODS-training-[2,14]", has_training_break,
      '未在 DailyCycleManager.gd 中找到 "training": [2, 14]')

# ── Q6 ── SPECIAL_DATES day 1 / day 14 ──────────────────────────────────────
print("\n[Q6] SPECIAL_DATES day 1 / day 14 effect 正确")
has_day1_opening = bool(re.search(r'1\s*:\s*\{[^}]*"effect"\s*:\s*"opening"', dcm_src))
check("Q6-SPECIAL_DATES-day1-effect-opening", has_day1_opening,
      'SPECIAL_DATES day 1 缺少 effect:"opening"')

has_day14_training_end = bool(re.search(r'14\s*:\s*\{[^}]*"effect"\s*:\s*"training_end"', dcm_src))
check("Q6-SPECIAL_DATES-day14-effect-training_end", has_day14_training_end,
      'SPECIAL_DATES day 14 缺少 effect:"training_end"')

# ── Q7 ── DataManager.EVENT_FILES 包含 events_opening.json ──────────────────
print("\n[Q7] DataManager.EVENT_FILES 包含 events_opening.json")
dm_src = read_gd(DATA_MANAGER_GD)
has_opening_registered = "events_opening.json" in dm_src
check("Q7-EVENT_FILES-includes-events_opening", has_opening_registered,
      '未在 DataManager.gd 中找到 "events_opening.json"')

# ═══════════════════════════════════════════════════════════════════════════
# 汇总 VERDICT
# ═══════════════════════════════════════════════════════════════════════════
total  = len(results)
passed = sum(1 for _, ok, _ in results if ok)
failed = total - passed

print("\n" + "═" * 60)
print(f"  QA-OPENING-01  {passed}/{total} PASS  |  {failed} FAIL")
print("═" * 60)

if failed == 0:
    print("  VERDICT: ✅ PASS")
    sys.exit(0)
else:
    print("  VERDICT: ❌ FAIL")
    print("\n  失败项汇总：")
    for label, ok, detail in results:
        if not ok:
            print(f"    • {label}  →  {detail}")
    sys.exit(1)
