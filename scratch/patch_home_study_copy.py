import json

path = 'd:/zkgame/scripts/events_daily.json'
with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

for e in events:
    if e["id"] == "home_study":
        e["scenes"] = [
            {
                "speaker": None,
                "text": "坐在书桌前，你拿出今天的作业...",
                "choices": [
                    {
                        "text": "自己埋头苦写",
                        "next": 1
                    },
                    {
                        "text": "[同桌特权] 发QQ要答案直接抄",
                        "requireFlags": [
                            "flag_deskmate_wanqing", 
                            "flag_deskmate_yutong", 
                            "flag_deskmate_xiaoyu", 
                            "flag_deskmate_generic_girl_nerd"
                        ],
                        "requireFlagsMatchAny": True,
                        "next": 2
                    }
                ]
            },
            {
                "speaker": None,
                "text": "开始答题...",
                "logicType": "quiz_homework",
                "next": 99
            },
            {
                "speaker": "player",
                "text": "（我在QQ上戳了戳同桌，没多久正确的步骤和答案就发过来了。几分钟搞定！）\n\n虽然没学到什么东西，但好在明天不用怕挨骂了。",
                "statDelta": {
                    "stress": -5,
                    "intellect": -1
                },
                "logicType": "hw_copy_finish",
                "next": 99
            }
        ]

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Patched home_study in events_daily.json")
