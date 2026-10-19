import json
import os

path = 'd:/zkgame/scripts/events_life.json'
with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

for e in events:
    if e.get("id") in ["olympiad_city_round", "olympiad_province_final"]:
        if "logicTargets" in e["scenes"][0]:
            e["scenes"][0]["logicTargets"]["pass"] = 1
            e["scenes"][0]["logicTargets"]["fail"] = 2

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Fixed logic targets for olympiad")
