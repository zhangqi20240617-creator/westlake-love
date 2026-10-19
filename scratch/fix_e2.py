import json

path = 'd:/zkgame/scripts/events_life.json'

with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

# Fix E2: life_conflict_excluded should NOT have excludeFlags for flag_conflict_resolved
for e in events:
    if e.get('id') == 'life_conflict_excluded':
        if 'excludeFlags' in e:
            del e['excludeFlags']
            print(f"Fixed: removed excludeFlags from life_conflict_excluded")
        break

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Done.")
