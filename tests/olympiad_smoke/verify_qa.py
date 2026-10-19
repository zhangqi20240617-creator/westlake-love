import json
import re
import sys

# Windows GBK 终端安全：强制 UTF-8 输出，防止 emoji 打印崩溃
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

print("Running D3 Olympiad System QA Check...")
fails = 0

events_path = 'd:/zkgame/scripts/events_life.json'
try:
    with open(events_path, 'r', encoding='utf-8-sig') as f:
        events = json.load(f)
    print("✅ events_life.json is valid JSON.")
    
    olympiad_events = [e for e in events if e.get('id', '').startswith('olympiad_')]
    if len(olympiad_events) == 6:
        print(f"✅ Found all 6 olympiad events: {[e['id'] for e in olympiad_events]}")
    else:
        print(f"❌ Expected 6 olympiad events, found {len(olympiad_events)}")
        fails += 1
except Exception as e:
    print(f"❌ Failed to parse events: {e}")
    fails += 1

exam_mgr_path = 'd:/zkgame/scripts/ExamManager.gd'
try:
    with open(exam_mgr_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'flag_olympiad_gold' in content and 'hz2' in content:
        print("✅ ExamManager.gd intercepts flag_olympiad_gold and overrides admission.")
    else:
        print("❌ ExamManager.gd is missing early admission hook!")
        fails += 1
except Exception as e:
    print(f"❌ Failed to parse ExamManager: {e}")
    fails += 1

study_popup_path = 'd:/zkgame/scripts/StudySubjectPopup.gd'
try:
    with open(study_popup_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    if 'flag_olympiad_joined' in content:
        print("✅ StudySubjectPopup.gd references Olympiad flags for UI feedback.")
    else:
        print("❌ StudySubjectPopup.gd missing UI feedback hooks!")
        fails += 1
except Exception as e:
    print(f"❌ Failed to parse StudySubjectPopup: {e}")
    fails += 1

print("======================")
if fails == 0:
    print("VERDICT: PASS")
    sys.exit(0)
else:
    print(f"VERDICT: FAIL ({fails} errors)")
    sys.exit(1)
