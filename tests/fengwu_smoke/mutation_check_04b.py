# -*- coding: utf-8 -*-
"""
DS-RN-04b 反向注入（变异）测试 —— 证明 verify_qa.py 新增的 M 区手作断言不是死断言。

做法：把真源码复制到临时沙箱 → 逐条注入一个「本该被抓住」的缺陷 →
      以 FENGWU_QA_ROOT 指向沙箱跑 verify_qa.py → 断言它**必须** FAIL，
      且失败编号命中预期断言。**全程不触碰 D:\\zkgame 下的真源码。**

用法：python tests/fengwu_smoke/mutation_check_04b.py
退出码：0 = 全部变异均被抓住（断言有效）；1 = 有变异逃逸（断言是死的）。
"""
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

REAL = Path(__file__).resolve().parents[2]
QA = Path(__file__).resolve()


# ── 变异算子：每个接收沙箱根目录，就地注入一个缺陷 ──────────────
def mut_no_remove(root: Path):
    """去掉一条手作事件的 removeItem → 1 个礼物可做 2 件（真消耗失守）。"""
    p = root / "scripts" / "events_life.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    for e in d:
        if e.get("id") == "fw_craft_yahua":
            e["scenes"][-1].pop("removeItem", None)
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


def mut_free_craft(root: Path):
    """门控收 15 元但 statDelta 不扣钱 → 白做（经济语义失守）。"""
    p = root / "scripts" / "events_life.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    for e in d:
        if e.get("id") == "fw_craft_taci":
            e["scenes"][-1]["statDelta"] = {"money": 0}
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


def mut_repeatable(root: Path):
    """把手作事件改成可重复 → 无限刷（去重失守）。"""
    p = root / "scripts" / "events_life.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    for e in d:
        if e.get("id") == "fw_craft_luyin":
            e["repeatable"] = True
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


def mut_drop_event(root: Path):
    """删掉一条手作事件 → 该槽无授予通道，称号永锁（可达性失守）。"""
    p = root / "scripts" / "events_life.json"
    d = [e for e in json.loads(p.read_text(encoding="utf-8"))
         if e.get("id") != "fw_craft_xiangnang"]
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


def mut_low_priority(root: Path):
    """手作 priority 降到 int_craft_make 之下 → 永远抢不到 candidates[0]。"""
    p = root / "scripts" / "events_life.json"
    d = json.loads(p.read_text(encoding="utf-8"))
    for e in d:
        if str(e.get("id", "")).startswith("fw_craft_"):
            e["priority"] = 180
    p.write_text(json.dumps(d, ensure_ascii=False, indent=2), encoding="utf-8")


def mut_setflag_bypass(root: Path):
    """grantFengwu 旁路成 set_flag → 集满判定永不触发，称号永锁。"""
    p = root / "scripts" / "DialogueUI.gd"
    s = p.read_text(encoding="utf-8")
    s = s.replace('CollectionManager.grant_fengwu(scene["grantFengwu"])',
                  'GameManager.set_flag("fengwu_" + scene["grantFengwu"], true)')
    p.write_text(s, encoding="utf-8")


def mut_into_itemdb(root: Path):
    """把手作产物塞进 ITEM_DB → ShopUI 全量上架，price 缺省即可白嫖。"""
    p = root / "scripts" / "GameManager.gd"
    s = p.read_text(encoding="utf-8")
    s = s.replace('const ITEM_DB = {',
                  'const ITEM_DB = {\n\t"fw_hm_yahua": {"name": "押花书签", "price": 0, '
                  '"category": "fengwu", "desc": "白嫖变异"},', 1)
    p.write_text(s, encoding="utf-8")


def mut_reachable_regress(root: Path):
    """把 reachable 退回排除手作 → 图鉴又谎报「本章可达 18」。"""
    p = root / "scripts" / "CollectionManager.gd"
    s = p.read_text(encoding="utf-8")
    s = s.replace("\treturn FENGWU_TOTAL\n", "\treturn 18\n", 1)
    p.write_text(s, encoding="utf-8")


MUTANTS = [
    ("M1 去掉 removeItem（1 个礼物做 2 件）",           mut_no_remove,        "Q43"),
    ("M2 门控收钱但不扣钱（白做）",                     mut_free_craft,       "Q43"),
    ("M3 手作事件改 repeatable=true（无限刷）",          mut_repeatable,       "Q44"),
    ("M4 删掉 1 条手作事件（该槽永锁）",                 mut_drop_event,       "Q11"),
    ("M5 priority 降到 int_craft_make 之下（永选不中）", mut_low_priority,     "Q46"),
    ("M6 grantFengwu 旁路 set_flag（集满永不触发）",     mut_setflag_bypass,   "Q45"),
    ("M7 手作产物混入 ITEM_DB（可被白嫖）",              mut_into_itemdb,      "Q09"),
    ("M8 reachable 退回 18（图鉴谎报）",                 mut_reachable_regress, "Q12"),
]


def run_qa(root: Path):
    env = dict(os.environ, FENGWU_QA_ROOT=str(root), PYTHONIOENCODING="utf-8")
    r = subprocess.run([sys.executable, str(QA.parent / "verify_qa.py")],
                       capture_output=True, text=True, encoding="utf-8",
                       errors="replace", env=env)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


print("=" * 78)
print("DS-RN-04b 反向注入测试 —— verify_qa.py M 区断言有效性验证")
print("=" * 78)

# 基线：真源码必须 PASS（退出码 0）
rc0, out0 = run_qa(REAL)
base_n = re.search(r"assertions=(\d+)\s+passed=(\d+)\s+failed=(\d+)", out0)
print(f"\n[baseline] 真源码 exit={rc0}  {base_n.group(0) if base_n else '??'}")
ok_base = rc0 == 0 and base_n and base_n.group(3) == "0"
print(f"  [{'PASS' if ok_base else 'FAIL'}] 基线为绿（若基线本身红，后续变异结论无意义）")

escaped, results = [], []
for name, fn, expect in MUTANTS:
    tmp = Path(tempfile.mkdtemp(prefix="fengwu_mut_"))
    sbx = tmp / "zkgame"
    shutil.copytree(REAL / "scripts", sbx / "scripts")
    shutil.copy2(REAL / "project.godot", sbx / "project.godot")
    for sub in ("assets",):
        src = REAL / sub
        if src.exists():
            (sbx / sub).mkdir(parents=True, exist_ok=True)
            for f in src.rglob("*.jpg"):
                dst = sbx / sub / f.relative_to(src)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(f, dst)
    try:
        fn(sbx)
        rc, out = run_qa(sbx)
        fails = re.findall(r"\[FAIL\] (Q\d+)", out)
        caught = rc == 1 and fails
        hit = expect in fails
        results.append((name, caught, hit, fails, expect))
        tag = "PASS" if caught else "FAIL"
        print(f"\n  [{tag}] {name}")
        print(f"         exit={rc}  被抓住的断言={fails or '（无 —— 变异逃逸！）'}  "
              f"预期命中 {expect}: {'是' if hit else '否'}")
        if not caught:
            escaped.append(name)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

print("\n" + "=" * 78)
n_caught = sum(1 for _, c, _, _, _ in results if c)
n_hit = sum(1 for _, c, h, _, _ in results if c and h)
print(f"变异体 {len(MUTANTS)} 个：被抓 {n_caught}，其中命中预期断言 {n_hit}，逃逸 {len(escaped)}")
if not ok_base or escaped:
    print("VERDICT: FAIL")
    for e in escaped:
        print(f"  x 逃逸：{e}")
    sys.exit(1)
print("VERDICT: PASS —— 全部变异均被 verify_qa.py 抓住，断言非死断言")
sys.exit(0)
