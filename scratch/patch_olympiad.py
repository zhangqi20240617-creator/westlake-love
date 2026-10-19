import json
import os

path = 'd:/zkgame/scripts/events_life.json'
with open(path, 'r', encoding='utf-8') as f:
    events = json.load(f)

for e in events:
    if e.get("id") == "olympiad_city_round":
        e["scenes"] = [
            {
                "speaker": None,
                "text": "初赛的考场在市里的重点高中。这是一卷真题，你握紧了笔。",
                "logicType": "quiz_olympiad_city",
                "logicTargets": {
                    "pass": 98,
                    "fail": 99
                },
                "next": 99
            },
            {   # Index 1: Pass
                "speaker": "player",
                "text": "呼……顺利通过了！那道压轴大题思路正好清晰！",
                "setFlag": "flag_olympiad_city_done",
                "statDelta": {
                    "stress": 15,
                    "intellect": 10
                },
                "next": 100 # End
            },
            {   # Index 2: Fail
                "speaker": "player",
                "text": "全乱了……完全没有头绪。这场竞赛对我来说还是太勉强了。",
                "setFlag": "flag_olympiad_dropped",
                "statDelta": {
                    "stress": 30,
                    "art": -5
                },
                "next": 100 # End
            }
        ]
        
    elif e.get("id") == "olympiad_province_final":
        e["scenes"] = [
            {
                "speaker": None,
                "text": "省级决赛的大礼堂座无虚席。这是最终的决战，必须答对至少2道以上才能斩获金牌。",
                "logicType": "quiz_olympiad_final",
                "logicTargets": {
                    "pass": 98,
                    "fail": 99
                },
                "next": 99
            },
            {   # Index 1: Pass (Gold)
                "speaker": "player",
                "text": "……做对了！！这份答卷将改变我的人生轨迹！",
                "setFlag": "flag_olympiad_gold",
                "statDelta": {
                    "stress": -50,
                    "social": 20,
                    "charm": 20
                },
                "next": 100
            },
            {   # Index 2: Fail (Drop)
                "speaker": "player",
                "text": "那些精妙的辅助线到底在哪里……还是功亏一篑了。",
                "setFlag": "flag_olympiad_dropped",
                "statDelta": {
                    "stress": 40,
                    "art": -10
                },
                "next": 100
            }
        ]

with open(path, 'w', encoding='utf-8', newline='\n') as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("Patched events_life.json for olympiad quizes")
