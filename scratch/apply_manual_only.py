import json
import os

patch_files = [
    "scripts/events_grad.json",
    "scripts/events_ptm.json",
    "scripts/events_sports.json",
    "scripts/events_roles.json",
    "scripts/events_dean.json"
]

for p in patch_files:
    full_path = f"d:/zkgame/{p}"
    if not os.path.exists(full_path):
        continue
    with open(full_path, 'r', encoding='utf-8') as f:
        events = json.load(f)
        
    for ev in events:
        ev["manual_only"] = True
        
    with open(full_path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(events, f, ensure_ascii=False, indent=2)

print("Applied manual_only to directed events")
