import json

path = 'd:/zkgame/scripts/events_life.json'
with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

for e in events:
    if e.get("id") in ("olympiad_training_1", "olympiad_training_2", "olympiad_training_3"):
        e["slotId"] = "after"
        e["requireWeekend"] = True
        print(f"Updated {e['id']}: slotId -> after, requireWeekend -> True")

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Done tweaking training events.")
