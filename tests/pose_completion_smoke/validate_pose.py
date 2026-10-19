# -*- coding: utf-8 -*-
"""
validate_pose.py — 《立绘多 pose 补全》独立质量门校验（quality-lead）
运行: C:\\Users\\Administrator\\.workbuddy\\binaries\\python\\versions\\3.13.12\\python.exe validate_pose.py
独立实现，不 import scratch/verify_pose_assets.py（逻辑等价重写）。
只读校验，不修改任何源码/资产。退出码: 0 = 全部 PASS, 1 = 存在 FAIL。
"""
import json
import os
import re
import sys

ROOT = r"D:\zkgame"
SCRIPTS = os.path.join(ROOT, "scripts")
SPRITE_ROOT = os.path.join(ROOT, "assets", "sprites")
DATAMANAGER = os.path.join(SCRIPTS, "DataManager.gd")
GAMEMANAGER = os.path.join(SCRIPTS, "GameManager.gd")
COLLECTIONMANAGER = os.path.join(SCRIPTS, "CollectionManager.gd")
EVENTS_JSON = os.path.join(SCRIPTS, "events.json")

EXPECTED_EVENT_FILE_COUNT = 10
EXPECTED_TOTAL_REFS = 408

# 本轮 10 张新增资产 (char, pose)
NEW_ASSETS = [
    ("wanqing", "shy"), ("wanqing", "serious"), ("wanqing", "casual"),
    ("yifei", "shy"), ("yifei", "serious"), ("yifei", "casual"),
    ("zicheng", "shy"), ("zicheng", "serious"), ("zicheng", "casual"),
    ("xiaoxia", "sport"),
]

# 本轮 10 个新增画廊 flag
NEW_GALLERY_FLAGS = [
    "seen_wanqing_shy", "seen_wanqing_serious", "seen_wanqing_casual",
    "seen_yifei_shy", "seen_yifei_serious", "seen_yifei_casual",
    "seen_zicheng_shy", "seen_zicheng_serious", "seen_zicheng_casual",
    "seen_xiaoxia_sport",
]

# C-6 好感度阈值解锁要求: char -> {flag: threshold}
FAVOR_REQUIRED = {
    "yifei":   {"seen_yifei_shy": 30,   "seen_yifei_serious": 60},
    "zicheng": {"seen_zicheng_shy": 30, "seen_zicheng_serious": 60},
}

RESULTS = []  # (check_id, name, passed, detail)


def record(check_id, name, passed, detail=""):
    RESULTS.append((check_id, name, passed, detail))
    tag = "PASS" if passed else "FAIL"
    print(f"[{tag}] {check_id} {name}")
    if detail:
        for line in str(detail).splitlines():
            print(f"       {line}")


def read_text(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


# ── A. DataManager EVENT_FILES × (speaker,pose) × 资产交叉校验 ──────────

def parse_event_files_from_datamanager():
    """从 DataManager.gd 提取 EVENT_FILES 常量（res:// 路径 → 本地路径）。"""
    text = read_text(DATAMANAGER)
    m = re.search(r"const\s+EVENT_FILES\s*=\s*\[(.*?)\]", text, re.S)
    if not m:
        return []
    files = re.findall(r'"res://scripts/([^"]+\.json)"', m.group(1))
    return files


def asset_exists(char, pose):
    base = os.path.join(SPRITE_ROOT, str(char).lower(), str(pose).lower())
    return any(os.path.isfile(base + ext) for ext in (".png", ".jpg", ".ogv"))


def collect_pose_refs(obj, acc):
    """递归收集 (speaker, pose, event_id)；speaker 为空/player/narrator 跳过。"""
    if isinstance(obj, dict):
        if "speaker" in obj:
            sp = obj.get("speaker", "")
            if sp not in ("", "player", "narrator", None):
                pose = obj.get("pose", "default") or "default"
                acc.append((sp, pose, obj.get("id", "?")))
        for v in obj.values():
            collect_pose_refs(v, acc)
    elif isinstance(obj, list):
        for v in obj:
            collect_pose_refs(v, acc)


def check_a_pose_asset_crosscheck():
    files = parse_event_files_from_datamanager()
    record("A1", f"DataManager.gd EVENT_FILES 数量 == {EXPECTED_EVENT_FILE_COUNT}",
           len(files) == EXPECTED_EVENT_FILE_COUNT,
           f"实际 {len(files)} 个: {files}")

    all_refs = []
    load_errors = []
    for fname in files:
        p = os.path.join(SCRIPTS, fname)
        if not os.path.isfile(p):
            load_errors.append(f"缺文件: {fname}")
            continue
        try:
            data = json.loads(read_text(p))
        except Exception as e:
            load_errors.append(f"解析失败: {fname}: {e}")
            continue
        collect_pose_refs(data, all_refs)
    record("A2", "10 个事件 JSON 全部存在且可解析",
           not load_errors, "\n".join(load_errors) or "全部加载成功")

    missing = [(c, p, e) for c, p, e in all_refs if not asset_exists(c, p)]
    by_char = {}
    for c, p, _ in missing:
        by_char.setdefault(c, set()).add(p)
    miss_detail = "; ".join(f"{c}: {sorted(ps)}" for c, ps in sorted(by_char.items()))
    record("A3", "(speaker,pose) 引用 → 资产 MISSING == 0",
           len(missing) == 0,
           f"total refs={len(all_refs)}, resolved={len(all_refs) - len(missing)}, "
           f"missing={len(missing)}" + (f" [{miss_detail}]" if missing else ""))

    record("A4", f"总引用数 == {EXPECTED_TOTAL_REFS}（预期基线）",
           len(all_refs) == EXPECTED_TOTAL_REFS,
           f"实际 {len(all_refs)}")


# ── B. 10 张新资产 PNG 存在且 2048×2048 RGBA ────────────────────────────

def check_b_new_assets():
    try:
        from PIL import Image
        has_pil = True
    except ImportError:
        has_pil = False

    problems = []
    for char, pose in NEW_ASSETS:
        path = os.path.join(SPRITE_ROOT, char, pose + ".png")
        if not os.path.isfile(path):
            problems.append(f"{char}/{pose}.png 不存在")
            continue
        if has_pil:
            try:
                with Image.open(path) as im:
                    if im.size != (2048, 2048):
                        problems.append(f"{char}/{pose}.png 尺寸 {im.size} != (2048,2048)")
                    if im.mode != "RGBA":
                        problems.append(f"{char}/{pose}.png 模式 {im.mode} != RGBA")
            except Exception as e:
                problems.append(f"{char}/{pose}.png 无法读取: {e}")
    detail = "\n".join(problems) if problems else (
        f"10/10 PNG 存在" + ("，均 2048x2048 RGBA" if has_pil else "（无 PIL，仅校验存在性）"))
    record("B1", "10 张新立绘 PNG 存在且 2048×2048 RGBA", not problems, detail)


# ── C. GameManager GALLERY_ITEMS 含 10 条新增 ───────────────────────────

def check_c_gallery_items():
    text = read_text(GAMEMANAGER)
    m = re.search(r"GALLERY_ITEMS\s*=\s*\[(.*?)\n\]", text, re.S)
    scope = m.group(1) if m else text  # 回退全文查 flag
    missing = [f for f in NEW_GALLERY_FLAGS
               if not re.search(r'"flag"\s*:\s*"%s"' % re.escape(f), scope)]
    record("C1", "GALLERY_ITEMS 含 10 条新增 flag", not missing,
           ("缺: " + ", ".join(missing)) if missing else "10/10 flag 均在 GALLERY_ITEMS 中")


# ── D. CollectionManager FAVOR_GALLERY_UNLOCKS 按 C-6 ───────────────────

def check_d_favor_unlocks():
    text = read_text(COLLECTIONMANAGER)
    m = re.search(r"const\s+FAVOR_GALLERY_UNLOCKS\s*=\s*\{(.*?)\n\}", text, re.S)
    if not m:
        record("D1", "FAVOR_GALLERY_UNLOCKS 存在", False, "未找到常量定义")
        return
    body = m.group(1)
    problems = []
    for char, req in FAVOR_REQUIRED.items():
        cm = re.search(r'"%s"\s*:\s*\[(.*?)\]' % re.escape(char), body, re.S)
        if not cm:
            problems.append(f"缺角色 {char}")
            continue
        block = cm.group(1)
        for flag, threshold in req.items():
            entry = re.search(
                r'\{[^{}]*"threshold"\s*:\s*(\d+)[^{}]*"flag"\s*:\s*"%s"[^{}]*\}' % re.escape(flag),
                block, re.S)
            if not entry:
                problems.append(f"{char} 缺 {flag}")
            elif int(entry.group(1)) != threshold:
                problems.append(f"{char}.{flag} 阈值 {entry.group(1)} != {threshold}")
    record("D1", "FAVOR_GALLERY_UNLOCKS: yifei/zicheng shy@30 + serious@60 (C-6)",
           not problems, "\n".join(problems) or "4 条阈值解锁均正确")


# ── E. GameManager 无「谢怡菲」(C-5) ────────────────────────────────────

def check_e_c5_typo():
    text = read_text(GAMEMANAGER)
    hits = [i + 1 for i, line in enumerate(text.splitlines()) if "谢怡菲" in line]
    record("E1", "GameManager.gd 全文无「谢怡菲」(C-5 已修)", not hits,
           f"残留行: {hits}" if hits else "0 处残留")


# ── F. events.json（历史未加载文件）yf_/zc_ 事件未被本轮改写 (R1) ────────

def check_f_events_json_untouched():
    try:
        data = json.loads(read_text(EVENTS_JSON))
    except Exception as e:
        record("F1", "events.json 可解析", False, str(e))
        return
    targets = [e for e in data if str(e.get("id", "")).startswith(("yf_", "zc_"))]
    pose_hits = []

    def walk(o, eid):
        if isinstance(o, dict):
            if "pose" in o:
                pose_hits.append((eid, o["pose"]))
            for v in o.values():
                walk(v, eid)
        elif isinstance(o, list):
            for v in o:
                walk(v, eid)

    for ev in targets:
        walk(ev, ev.get("id", "?"))
    record("F1", "events.json 的 yf_/zc_ 事件未注入本轮 pose 键 (R1 防误改)",
           not pose_hits,
           f"{len(targets)} 个 yf_/zc_ 事件, pose 键出现 {len(pose_hits)} 处"
           + (f": {pose_hits}" if pose_hits else "（0 处，符合预期）"))


# ── main ────────────────────────────────────────────────────────────────

def main():
    print("=" * 64)
    print("POSE COMPLETION SMOKE — 独立质量门校验 (validate_pose.py)")
    print("=" * 64)
    check_a_pose_asset_crosscheck()
    check_b_new_assets()
    check_c_gallery_items()
    check_d_favor_unlocks()
    check_e_c5_typo()
    check_f_events_json_untouched()

    failed = [r for r in RESULTS if not r[2]]
    print("-" * 64)
    print(f"SUMMARY: {len(RESULTS) - len(failed)}/{len(RESULTS)} PASS")
    print("GATE:", "PASS" if not failed else "FAIL")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
