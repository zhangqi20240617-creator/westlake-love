#!/usr/bin/env python3
"""
校园生活系统 Smoke QA
验证 events_birthday / events_vacation / events_campus / 关键 GDScript 改动
"""
import json, sys, pathlib

def load_json(fpath):
    """兼容 BOM + CRLF 的 JSON 读取"""
    raw = fpath.read_bytes()
    # 去除 BOM
    if raw.startswith(b'\xef\xbb\xbf'):
        raw = raw[3:]
    return json.loads(raw.decode("utf-8"))

ROOT = pathlib.Path(__file__).parents[2]
SCRIPTS = ROOT / "scripts"

PASS = "✅ PASS"
FAIL = "❌ FAIL"
errors = []

def check(cond, msg):
    if cond:
        print(f"{PASS}  {msg}")
    else:
        print(f"{FAIL}  {msg}")
        errors.append(msg)

# ── 1. JSON 文件合法性 & 事件数量 ─────────────────────────────
for fname, min_count in [
    ("events_birthday.json", 7),
    ("events_vacation.json", 3),
    ("events_campus.json",   4),
]:
    fpath = SCRIPTS / fname
    try:
        data = load_json(fpath)
        check(isinstance(data, list), f"{fname}: 是合法 JSON 数组")
        check(len(data) >= min_count,
              f"{fname}: 至少包含 {min_count} 个事件（实际 {len(data)}）")
    except Exception as e:
        check(False, f"{fname}: JSON 解析失败 – {e}")

# ── 2. events_birthday.json 含 requireFav / item 类 effect ────
birthday = load_json(SCRIPTS / "events_birthday.json")
has_item_ref = any(
    any(n.get("requireItem") or any(e.get("type") in ("removeItem","favor") for e in n.get("effects",[]))
        for n in ev.get("nodes", []) if isinstance(n, dict))
    for ev in birthday if isinstance(ev, dict)
)
check(has_item_ref, "events_birthday.json: 包含 requireItem / favor 效果字段")

# ── 3. events_vacation.json: 无超额赠金（单次 money > 500）─────
vacation = load_json(SCRIPTS / "events_vacation.json")
max_money = 0
for ev in vacation:
    for node in ev.get("nodes", []):
        for eff in node.get("effects", []):
            if eff.get("type") == "money" and eff.get("amount", 0) > 0:
                max_money = max(max_money, eff["amount"])
check(max_money <= 500, f"events_vacation.json: 单次赠金不超过 500（最大 {max_money}）")

# ── 4. GDScript 关键字检查 ─────────────────────────────────────
checks = {
    "DailyCycleManager.gd": ["birthday_player"],
    "GameManager.gd":       ["school_canteen", "vacation_park"],
    "LocationManager.gd":   ["vacationOnly"],
    "MainGame.gd":          ["birthday_char", "birthday_player"],
    "DataManager.gd":       ["events_birthday.json", "events_vacation.json", "events_campus.json"],
}
for fname, keywords in checks.items():
    fpath = ROOT / "scripts" / fname
    text = fpath.read_text(encoding="utf-8", errors="replace")
    for kw in keywords:
        check(kw in text, f"{fname}: 包含关键字 '{kw}'")

# ── 结果汇总 ──────────────────────────────────────────────────
print()
if errors:
    print(f"共 {len(errors)} 项未通过：")
    for e in errors: print(f"  • {e}")
    sys.exit(1)
else:
    print("🎉 全部通过！三大校园系统 QA 通过。")
    sys.exit(0)
