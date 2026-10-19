# -*- coding: utf-8 -*-
"""
QA-CLUB-01 反向注入（变异）测试 —— 证明 verify_qa.py 的断言不是「永远 PASS 的死断言」。

做法：把真源码复制到临时沙箱 → 逐条注入一个「本该被抓住」的缺陷 →
      以 CLUB_QA_ROOT 指向沙箱跑 verify_qa.py → 断言它**必须** FAIL，
      且失败编号命中预期断言。**全程不触碰 D:\\zkgame 下的真源码。**

用法：python tests/club_smoke/mutation_check_club.py
退出码：0 = 全部变异均被抓住（断言有效）；1 = 有变异逃逸（断言是死的）。
"""
import hashlib
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

REAL = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve().parent / "verify_qa.py"


def _life(root):
    return root / "scripts" / "events_life.json"


def _read_json(p):
    return json.loads(p.read_text(encoding="utf-8"))


def _write_json(p, d):
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


# ── 变异算子：每个接收沙箱根目录，就地注入一个缺陷 ──────────────
def mut_notimecost(root):
    """给周活动加 noTimeCost → 社团白嫖时段，S-4 命门失守。"""
    p = _life(root)
    d = _read_json(p)
    for e in d:
        if e.get("id") == "club_weekly_art":
            e["noTimeCost"] = True
    _write_json(p, d)


def mut_erase_out_of_scope(root):
    """把周一 erase 挪出 _check_weekly_allowance（挪进兼职函数）→ 周一重置失效。"""
    p = root / "scripts" / "DailyCycleManager.gd"
    s = p.read_text(encoding="utf-8")
    line = '\t\tGameManager.flags.erase("flag_club_week_done")\n'
    s = s.replace(line, "")
    s = s.replace("func _check_parttime_income():\n",
                  "func _check_parttime_income():\n" + line)
    p.write_text(s, encoding="utf-8")


def mut_break_facade(root):
    """GameManager 周结算门面被掏空 → 通宵跳日路径读不到社团 erase。

    注意：GameManager.gd 用**空格**缩进，故这里必须用缩进无关的正则，
    不能硬编码 \\t（早期版本正是因此静默 no-op，被 no-op 守卫抓出）。
    """
    p = root / "scripts" / "GameManager.gd"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"(func _check_weekly_allowance\(\):\n)([ \t]+)DailyCycleManager\._check_weekly_allowance\(\)",
               r"\1\2pass", s)
    p.write_text(s, encoding="utf-8")


def mut_priority_205_to_200(root):
    """把美术社 priority 调回 200 → 被 life_health_art_relief 永久压制（功能死亡）。"""
    p = _life(root)
    d = _read_json(p)
    for e in d:
        if e.get("id") == "club_weekly_art":
            e["priority"] = 200
    _write_json(p, d)


def mut_escape_choice(root):
    """给招新 hub 加第 6 个「再想想」逃逸选项（不置 flag）→ 事件被消耗但未入社 = 永久 soft-lock。"""
    p = _life(root)
    d = _read_json(p)
    for e in d:
        if e.get("id") == "club_join_hub":
            for s in e["scenes"]:
                if "choices" in s:
                    s["choices"].append({"text": "算了，我再想想", "next": 99})
    _write_json(p, d)


def mut_money_reward(root):
    """周活动发钱 → R6 经济红线失守。"""
    p = _life(root)
    d = _read_json(p)
    for e in d:
        if e.get("id") == "club_weekly_basketball":
            e["scenes"][-1]["statDelta"]["money"] = 30
    _write_json(p, d)


def mut_starving_competitor(root):
    """在 art_room 插一条「可重复 + 零门控 + priority 210」的常驻事件 → 美术社被永久饿死。"""
    p = _life(root)
    d = _read_json(p)
    d.append({
        "id": "life_artroom_squatter", "charId": None, "location": "art_room",
        "slotId": "after", "priority": 210, "repeatable": True,
        "title": "常驻占位", "scenes": [{"speaker": None, "text": "占位。", "next": 99}],
    })
    _write_json(p, d)


def mut_mixed_indent(root):
    """把 erase 行改成空格缩进 → GDScript 混用缩进，Godot 直接解析失败。"""
    p = root / "scripts" / "DailyCycleManager.gd"
    s = p.read_text(encoding="utf-8")
    s = s.replace('\t\tGameManager.flags.erase("flag_club_week_done")',
                  '        GameManager.flags.erase("flag_club_week_done")')
    p.write_text(s, encoding="utf-8")


def mut_ngplus_whitelist(root):
    """NG+ 清档后回注社团 flag → 上周目社团带入新周目，招新永不再现。"""
    p = root / "scripts" / "EndingScreen.gd"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"([ \t]+)GameManager\.flags = \{\}",
               r'\1GameManager.flags = {}\n\1GameManager.flags["flag_club_joined"] = true',
               s, count=1)
    p.write_text(s, encoding="utf-8")


def mut_panel_writes_flag(root):
    """社团面板代写「本周已参加」→ 绕过时段消耗（支柱 A 红线）。"""
    p = root / "scripts" / "MainGame.gd"
    s = p.read_text(encoding="utf-8")
    s = s.replace("func _show_club_popup():\n",
                  "func _show_club_popup():\n"
                  '    GameManager.set_flag("flag_club_week_done", true)\n', 1)
    p.write_text(s, encoding="utf-8")


def mut_erase_loses_monday_guard(root):
    """把周一 erase 提到 day_of_week 守卫之外 → 每天都清标记，周上限失效。"""
    p = root / "scripts" / "DailyCycleManager.gd"
    s = p.read_text(encoding="utf-8")
    s = re.sub(r"[ \t]*GameManager\.flags\.erase\(\"flag_club_week_done\"\)\n", "", s)
    s = re.sub(r"(func _check_weekly_allowance\(\):\n)",
               r'\1\tGameManager.flags.erase("flag_club_week_done")\n', s)
    p.write_text(s, encoding="utf-8")


def mut_fengwu_regression(root):
    """删掉 1 条风物 → 已放行特性回归（S-3）。"""
    p = root / "scripts" / "CollectionManager.gd"
    s = p.read_text(encoding="utf-8")
    s = s.replace("const FENGWU_TOTAL := 24", "const FENGWU_TOTAL := 23")
    p.write_text(s, encoding="utf-8")


def mut_life_pillar_deleted(root):
    """删掉 1 条生活支柱 P2 事件 → 既有内容被社团改动误伤。"""
    p = _life(root)
    d = [e for e in _read_json(p) if e.get("id") != "int_pet_care"]
    _write_json(p, d)


def mut_charid_split(root):
    """给周活动挂 charId → S-5 双路线分流。"""
    p = _life(root)
    d = _read_json(p)
    for e in d:
        if e.get("id") == "club_weekly_broadcast":
            e["charId"] = "yutong"
    _write_json(p, d)


def mut_weekly_cap_removed(root):
    """去掉周上限门控 → 一天可无限刷社团。"""
    p = _life(root)
    d = _read_json(p)
    for e in d:
        if e.get("id") == "club_weekly_literature":
            e.pop("excludeFlags", None)
    _write_json(p, d)


MUTANTS = [
    ("M01 周活动加 noTimeCost（S-4 命门）",            mut_notimecost,          "Q1."),
    ("M02 周一 erase 挪出 _check_weekly_allowance",    mut_erase_out_of_scope,  "Q2."),
    ("M03 GameManager 周结算门面被掏空（通宵路径）",    mut_break_facade,        "Q2."),
    ("M04 美术社 priority 205→200（功能死亡）",         mut_priority_205_to_200, "Q5."),
    ("M05 招新 hub 加逃逸选项（永久 soft-lock）",       mut_escape_choice,       "Q6."),
    ("M06 周活动发 money（R6）",                        mut_money_reward,        "Q8."),
    ("M07 art_room 插常驻高优竞争者（饿死）",           mut_starving_competitor, "Q13."),
    ("M08 erase 行改空格缩进（GDScript 解析失败）",     mut_mixed_indent,        "Q14."),
    ("M09 NG+ 回注 flag_club_joined",                   mut_ngplus_whitelist,    "Q11."),
    ("M10 社团面板代写 flag_club_week_done",            mut_panel_writes_flag,   "Q4."),
    ("M15 erase 脱离周一守卫（每日重置）",              mut_erase_loses_monday_guard, "Q2."),
    ("M11 FENGWU_TOTAL 24→23（S-3 回归）",              mut_fengwu_regression,   "Q10."),
    ("M12 删除 int_pet_care（生活支柱 P2 误伤）",       mut_life_pillar_deleted, "Q10."),
    ("M13 周活动挂 charId（S-5 分流）",                 mut_charid_split,        "Q7."),
    ("M14 去掉周上限 excludeFlags",                     mut_weekly_cap_removed,  "Q13."),
]


def run_gate(root):
    r = subprocess.run([sys.executable, str(QA)],
                       env={**__import__("os").environ, "CLUB_QA_ROOT": str(root)},
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def sandbox(tmp, name):
    root = Path(tmp) / name
    (root / "scripts").mkdir(parents=True)
    for p in (REAL / "scripts").iterdir():
        if p.is_file() and p.suffix in (".gd", ".json", ".uid"):
            shutil.copy2(p, root / "scripts" / p.name)
    shutil.copy2(REAL / "project.godot", root / "project.godot")
    return root


def fingerprint(root):
    """沙箱内全部受检源文件的内容指纹 —— 用于识别「静默 no-op 变异」。

    早期版本的 M03/M09 硬编码了 \\t 缩进，而 GameManager.gd / EndingScreen.gd
    实际用空格 → replace 未命中 → 变异根本没注入，门禁当然 PASS，
    却被误报成「断言是死的」。有了本守卫，变异器自身的 bug 会被单独标记。
    """
    h = hashlib.sha256()
    for p in sorted(root.rglob("*")):
        if p.is_file():
            h.update(p.relative_to(root).as_posix().encode())
            h.update(p.read_bytes())
    return h.hexdigest()


def main():
    print("=" * 78)
    print("QA-CLUB-01 反向注入（变异）测试 —— 验证门禁断言有效性")
    print("=" * 78)
    escaped, caught, noop = [], [], []
    with tempfile.TemporaryDirectory() as tmp:
        # 基线：未变异沙箱必须 PASS，否则说明沙箱复制不完整
        base = sandbox(tmp, "baseline")
        rc, out = run_gate(base)
        print(f"\n[基线] 未变异沙箱 → exit={rc} "
              f"({'PASS' if rc == 0 else 'FAIL —— 沙箱不完整，结果不可信'})")
        if rc != 0:
            print(out[-2500:])
            return 1

        for i, (name, fn, expect) in enumerate(MUTANTS, 1):
            root = sandbox(tmp, f"mut{i:02d}")
            before = fingerprint(root)
            fn(root)
            if fingerprint(root) == before:
                noop.append(name)
                print(f"  [NO-OP!!] {name}  → 变异器未改动任何字节（变异器自身 bug，非断言问题）")
                continue
            rc, out = run_gate(root)
            hits = [l.strip()[7:] for l in out.splitlines() if l.strip().startswith("[FAIL]")]
            hit_expected = any(h.startswith(expect) for h in hits)
            if rc != 0 and hit_expected:
                caught.append(name)
                first = next(h for h in hits if h.startswith(expect))
                print(f"  [CAUGHT] {name}\n           → exit={rc}, 命中 {first[:96]}")
            else:
                escaped.append((name, rc, hits[:3]))
                print(f"  [ESCAPED] {name}  exit={rc}  期望前缀 {expect}  实际 {hits[:3]}")

    print("\n" + "=" * 78)
    print(f"变异 {len(MUTANTS)} 个：抓住 {len(caught)}，逃逸 {len(escaped)}，变异器 no-op {len(noop)}")
    if noop:
        print("VERDICT: FAIL —— 以下变异器未注入任何改动（变异器 bug，需修）：")
        for n in noop:
            print(f"  ? {n}")
        return 1
    if escaped:
        print("VERDICT: FAIL —— 以下缺陷未被门禁抓住，对应断言是死断言：")
        for n, rc, h in escaped:
            print(f"  x {n} (exit={rc}, failures={h})")
        return 1
    print("VERDICT: PASS —— 全部注入缺陷均被门禁拦下，断言有效。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
