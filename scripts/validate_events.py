#!/usr/bin/env python3
"""
events 快速验证脚本 - 改完 JSON 后先跑这个
用法: python scripts/validate_events.py
"""
import json, os, sys

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
EVENT_FILES = [
    "events_yutong.json", "events_jingjing.json", "events_wanqing.json",
    "events_xiaoxia.json", "events_male.json", "events_special.json",
    "events_daily.json",
]

errors = []
warnings = []
all_ids = {}  # id -> filename

KNOWN_CHARS = {"yutong","jingjing","wanqing","xiaoxia","keke",
               "yifei","zicheng","beichen","jingjing_m","zijun","player"}
KNOWN_LOCS  = {"classroom","library","playground","music_room","art_room",
               "off_campus_shop","school_gate","lakeside","community",
               "home","cinema","amusement_park","hotspot"}
KNOWN_SLOTS = {"morning","noon","after","evening", None, ""}

def check(condition, msg, level="ERROR"):
    if not condition:
        if level == "ERROR":
            errors.append(msg)
        else:
            warnings.append(msg)

for filename in EVENT_FILES:
    path = os.path.join(SCRIPTS_DIR, filename)
    if not os.path.exists(path):
        errors.append(f"[{filename}] 文件不存在")
        continue

    # 1. JSON 格式
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        errors.append(f"[{filename}] JSON 解析失败: {e}")
        continue

    check(isinstance(data, list), f"[{filename}] 顶层应为 Array")

    for ev in data:
        ev_id = ev.get("id", "???")
        prefix = f"[{filename}] {ev_id}"

        # 2. 重复 ID
        if ev_id in all_ids:
            errors.append(f"{prefix} ID 重复 (也在 {all_ids[ev_id]})")
        else:
            all_ids[ev_id] = filename

        # 3. 必填字段
        check("id" in ev,       f"{prefix} 缺少 id 字段")
        check("scenes" in ev,   f"{prefix} 缺少 scenes 字段")
        check("priority" in ev, f"{prefix} 缺少 priority 字段", "WARN")

        # 4. 地点合法性
        loc = ev.get("location")
        if loc is not None:
            check(loc in KNOWN_LOCS, f"{prefix} 未知 location: {loc}")

        # 5. 时段合法性
        slot = ev.get("slotId", "")
        check(slot in KNOWN_SLOTS, f"{prefix} 未知 slotId: {slot}")

        # 6. scenes 检查
        scenes = ev.get("scenes", [])
        for i, scene in enumerate(scenes):
            sp = f"{prefix}[scene{i}]"
            # 每个 scene 要有 text 或 choices
            has_text    = "text" in scene
            has_choices = "choices" in scene
            check(has_text or has_choices, f"{sp} 既无 text 也无 choices")

            # next 值合法性（不能越界）
            nxt = scene.get("next")
            if nxt is not None and nxt != 99:
                check(0 <= nxt < len(scenes),
                      f"{sp} next={nxt} 越界 (scenes共{len(scenes)}个)", "WARN")

            # choices 里的 next 合法性
            for j, c in enumerate(scene.get("choices", [])):
                cp = f"{sp}[choice{j}]"
                check("text" in c, f"{cp} 缺少 text")
                nxt_c = c.get("next")
                if nxt_c is not None and nxt_c != 99 and nxt_c != 1:
                    check(0 <= nxt_c < len(scenes),
                          f"{cp} next={nxt_c} 越界 (scenes共{len(scenes)}个)", "WARN")
                # 乱码检测
                txt = c.get("text", "")
                check("xF0" not in txt and "x9F" not in txt,
                      f"{cp} 文本含乱码字节: {txt[:40]}")

        # 7. requireFlags 中的 flag 是否有对应事件 ID（延迟检查）
        for f in ev.get("requireFlags", []):
            if f not in all_ids and f not in [e.get("id") for e in data]:
                pass  # 跨文件引用，延迟到第二轮检查

# 第二轮：跨文件 requireFlags 引用检查
KNOWN_CUSTOM_FLAGS = {
    "date_yt_cinema", "date_yt_amusement",
    "date_jj_cinema", "date_jj_amusement"
}

for filename in EVENT_FILES:
    path = os.path.join(SCRIPTS_DIR, filename)
    if not os.path.exists(path): continue
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    for ev in data:
        for rf in ev.get("requireFlags", []):
            if rf not in all_ids and rf not in KNOWN_CUSTOM_FLAGS:
                warnings.append(f"[{filename}] {ev.get('id')} requireFlag '{rf}' 无对应事件ID")

# ── 输出报告 ──────────────────────────────────────────────────────
print(f"\n{'='*50}")
print(f"验证完成: {len(all_ids)} 个事件, {len(EVENT_FILES)} 个文件")
print(f"{'='*50}")

if errors:
    print(f"\n[ERRORS] {len(errors)} 个错误:")
    for e in errors:
        print(f"  [ERROR] {e}")
else:
    print("\n  [OK] 无错误")

if warnings:
    print(f"\n[WARNINGS] {len(warnings)} 个警告:")
    for w in warnings:
        print(f"  [WARNING] {w}")
else:
    print("  [OK] 无警告")

# 统计各文件事件数
print(f"\n{'='*50}")
print("各文件统计:")
for filename in EVENT_FILES:
    path = os.path.join(SCRIPTS_DIR, filename)
    if os.path.exists(path):
        with open(path,"r",encoding="utf-8") as f:
            d = json.load(f)
        print(f"  {filename:<30} {len(d):>3} 个事件  {os.path.getsize(path)//1024}KB")

sys.exit(1 if errors else 0)
