import json
import re
import sys
import os

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

print("=" * 60)
print("🚀 Running Achievement System Full QA Smoke Check...")
print("=" * 60)

fails = 0
EXPECTED_CATEGORIES = {
    "hangzhou": "人间西湖",
    "academics": "学海无涯",
    "social": "青春羁绊",
    "minigames": "闲暇微光",
    "curiosities": "天地万象",
    "milestones": "光阴长卷"
}

# 1. 验证 scripts/achievements.json
achv_path = 'd:/zkgame/scripts/achievements.json'
try:
    with open(achv_path, 'r', encoding='utf-8') as f:
        achievements = json.load(f)
    print(f"✅ achievements.json is valid JSON. Total items: {len(achievements)}")
    
    if len(achievements) < 50:
        print(f"❌ Expected at least 50 achievements, found {len(achievements)}")
        fails += 1
    else:
        print(f"✅ Achievement matrix scale verified (count >= 50: {len(achievements)})")

    # 检查 ID 唯一性与字段规范
    seen_ids = set()
    category_counts = {c: 0 for c in EXPECTED_CATEGORIES}
    total_pts = 0

    for a in achievements:
        aid = a.get("id")
        if not aid:
            print("❌ Achievement missing ID!")
            fails += 1
            continue
        if aid in seen_ids:
            print(f"❌ Duplicate achievement ID: {aid}")
            fails += 1
        seen_ids.add(aid)

        cat = a.get("category")
        if cat not in EXPECTED_CATEGORIES:
            print(f"❌ Unknown category '{cat}' in achievement {aid}")
            fails += 1
        else:
            category_counts[cat] += 1

        pts = a.get("points", 0)
        if not isinstance(pts, int) or pts <= 0:
            print(f"❌ Invalid points in achievement {aid}: {pts}")
            fails += 1
        total_pts += pts

        c_type = a.get("condition_type")
        if c_type not in ["flag", "stat", "favor", "counter", "custom"]:
            print(f"❌ Invalid condition_type in achievement {aid}: {c_type}")
            fails += 1

    print(f"✅ Total achievement points: {total_pts} 🎖️")
    for cat, name in EXPECTED_CATEGORIES.items():
        cnt = category_counts[cat]
        if cnt < 5:
            print(f"❌ Category '{cat}' ({name}) has too few achievements: {cnt}")
            fails += 1
        else:
            print(f"  - [{cat}] {name}: {cnt} items")

except Exception as e:
    print(f"❌ Failed to parse achievements.json: {e}")
    fails += 1

# 2. 验证 project.godot Autoload
godot_cfg_path = 'd:/zkgame/project.godot'
try:
    with open(godot_cfg_path, 'r', encoding='utf-8') as f:
        godot_cfg = f.read()
    if 'AchievementManager="*res://scripts/AchievementManager.gd"' in godot_cfg:
        print("✅ AchievementManager is properly registered as Autoload in project.godot")
    else:
        print("❌ AchievementManager is missing from project.godot Autoload!")
        fails += 1
except Exception as e:
    print(f"❌ Failed to read project.godot: {e}")
    fails += 1

# 3. 验证 AchievementManager.gd
mgr_path = 'd:/zkgame/scripts/AchievementManager.gd'
try:
    with open(mgr_path, 'r', encoding='utf-8') as f:
        mgr_code = f.read()
    required_symbols = [
        "load_achievements_db", "is_unlocked", "unlock", "check_all",
        "get_stats", "get_category_stats", "add_counter", "CATEGORY_META"
    ]
    for sym in required_symbols:
        if sym not in mgr_code:
            print(f"❌ AchievementManager.gd missing required method/symbol: {sym}")
            fails += 1
    print("✅ AchievementManager.gd core API verified")
except Exception as e:
    print(f"❌ Failed to read AchievementManager.gd: {e}")
    fails += 1

# 4. 验证 UI 脚本存在
ui_scripts = [
    'd:/zkgame/scripts/AchievementBannerUI.gd',
    'd:/zkgame/scripts/AchievementPopupUI.gd'
]
for p in ui_scripts:
    if os.path.exists(p):
        print(f"✅ UI component exists: {os.path.basename(p)}")
    else:
        print(f"❌ UI component missing: {p}")
        fails += 1

# 5. 验证 MainGame.gd 集成
main_game_path = 'd:/zkgame/scripts/MainGame.gd'
try:
    with open(main_game_path, 'r', encoding='utf-8') as f:
        mg_code = f.read()
    if '_show_achievement_popup' in mg_code and '成就中心' in mg_code:
        print("✅ MainGame.gd includes _show_achievement_popup and menu entry")
    else:
        print("❌ MainGame.gd missing achievement popup trigger or menu entry")
        fails += 1
except Exception as e:
    print(f"❌ Failed to read MainGame.gd: {e}")
    fails += 1

# 6. 验证 EndingScreen.gd 跨周目继承
ending_path = 'd:/zkgame/scripts/EndingScreen.gd'
try:
    with open(ending_path, 'r', encoding='utf-8') as f:
        ending_code = f.read()
    if 'achv_' in ending_code and 'achv_ending_reached' in ending_code:
        print("✅ EndingScreen.gd persists achv_* flags and triggers ending achievement")
    else:
        print("❌ EndingScreen.gd missing achv_* NG+ persistence or ending hook")
        fails += 1
except Exception as e:
    print(f"❌ Failed to read EndingScreen.gd: {e}")
    fails += 1

# 7. 验证小游戏与题库联动钩子
hooks = {
    "QuizUI.gd": "achv_quiz_perfect_first",
    "BobaTeaCraftUI.gd": "achv_boba_crafted",
    "ClawMachineUI.gd": "achv_claw_caught",
    "PaperSlipStealthUI.gd": "achv_stealth_perfect",
    "BadmintonRallyUI.gd": "achv_badminton_rally_10",
    "WestLakeShutterUI.gd": "achv_shutter_perfect"
}
for script_name, hook_flag in hooks.items():
    s_path = os.path.join('d:/zkgame/scripts/minigames' if 'UI' in script_name and script_name != 'QuizUI.gd' else 'd:/zkgame/scripts', script_name)
    try:
        with open(s_path, 'r', encoding='utf-8') as f:
            code = f.read()
        if hook_flag in code:
            print(f"✅ {script_name} has achievement hook ({hook_flag})")
        else:
            print(f"❌ {script_name} is missing achievement hook: {hook_flag}")
            fails += 1
    except Exception as e:
        print(f"❌ Failed to read {script_name}: {e}")
        fails += 1

print("=" * 60)
if fails == 0:
    print("🎉 ALL CHECKS PASSED! VERDICT: PASS")
    sys.exit(0)
else:
    print(f"💥 FOUND {fails} FAILURES! VERDICT: FAIL")
    sys.exit(1)
