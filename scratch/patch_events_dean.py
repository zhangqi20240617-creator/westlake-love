import json

path = 'd:/zkgame/scripts/events_daily.json'
with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

for e in events:
    if e["id"] == "home_study":
        new_choices = []
        for choice in e["scenes"][0]["choices"]:
            new_choices.append(choice)
        
        # 加上消除处分的选项
        new_choices.append({
            "text": "[背着处分] 熬夜手抄行为规范消除处分",
            "requireStats": {"punishment_level": 1},
            "next": 100
        })
        e["scenes"][0]["choices"] = new_choices
        
        # 加场景
        e["scenes"].append({
            "speaker": "player",
            "text": "你咬着牙，盯着微弱的台灯强忍困意，一笔一划地抄写着《中学生日常行为规范》。\n只要坚持抄完几本，总能打动教导主任大发慈悲的……",
            "statDelta": {
                "stress": 15,
                "punishment_level": -1
            },
            "next": 99
        })

    if e["id"] == "go_internet_cafe":
        # 增加去网吧被教导主任怀疑度提升的红线逻辑
        found = False
        for scene in e["scenes"]:
            if "网吧" in scene.get("text", "") and "statDelta" in scene:
                scene["statDelta"]["dean_suspicion"] = 15
                found = True
        
with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Patched home_study and go_internet_cafe in events_daily.json")
