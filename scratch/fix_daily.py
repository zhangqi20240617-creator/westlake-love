import json

path = 'd:/zkgame/scripts/events_daily.json'
try:
    with open(path, 'r', encoding='utf-8') as f:
        events = json.load(f)
    
    fixed = 0
    for e in events:
        if e.get('id') in ('home_study', 'home_sleep'):
            if e.get('location') in (None, 'none', ''):
                e['location'] = 'home'
                print(f"Fixed {e['id']}: location -> home")
                fixed += 1
    
    if fixed:
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            json.dump(events, f, ensure_ascii=False, indent=2)
        print(f"Saved {fixed} fixes.")
    else:
        print("home_study/home_sleep not found in events_daily.json, checking events.json...")
        path2 = 'd:/zkgame/scripts/events.json'
        try:
            with open(path2, 'r', encoding='utf-8') as f:
                events2 = json.load(f)
            for e in events2:
                if e.get('id') in ('home_study', 'home_sleep'):
                    print(f"  FOUND in events.json: {e.get('id')} location={e.get('location')}")
        except:
            print("events.json not found or not a list")

except Exception as ex:
    print(f"Error: {ex}")
