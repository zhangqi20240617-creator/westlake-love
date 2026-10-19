import json

path = 'd:/zkgame/scripts/events_deskmate.json'
with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

for e in events:
    if e["id"] == "deskmate_wanqing_note":
        e["requireFlags"] = ["flag_deskmate_wanqing"]
    elif e["id"] == "deskmate_fatboy_sleep":
        e["requireFlags"] = ["flag_deskmate_generic_boy_sleep"]
    elif e["id"] == "deskmate_nerd_notes":
        e["requireFlags"] = ["flag_deskmate_generic_girl_nerd"]
    elif e["id"] == "deskmate_troublemaker_snack":
        e["requireFlags"] = ["flag_deskmate_generic_boy_trouble"]

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Linked flags for events_deskmate.json")
