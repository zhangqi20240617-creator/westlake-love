import json

def patch_events(path):
    print(f"Patching {path}...")
    try:
        with open(path, 'r', encoding='utf-8') as f:
            events = json.load(f)
            
        modified = False
        for e in events:
            if e.get("id") == "home_study":
                print("Found home_study:", e["id"])
                e["title"] = "完成今日作业"
                e["scenes"] = [
                    {
                        "speaker": None,
                        "text": "坐在书桌前，你拿出今天的作业...",
                        "logicType": "quiz_homework",
                        "next": 99
                    }
                ]
                modified = True
        
        if modified:
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                json.dump(events, f, ensure_ascii=False, indent=2)
            print("  -> Patched.")
        else:
            print("  -> Not modified.")
    except Exception as ex:
        print("  -> Error:", ex)

patch_events('d:/zkgame/scripts/events_daily.json')
patch_events('d:/zkgame/scripts/events.json')
