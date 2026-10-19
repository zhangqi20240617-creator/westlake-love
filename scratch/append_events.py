# 向 events_yutong.json 安全追加两个关系状态机 PoC 事件，并校验 JSON
import io, os, json

path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "scripts", "events_yutong.json"))

with io.open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

assert isinstance(data, list), "events_yutong.json 根应为数组"

existing_ids = {e.get("id") for e in data if isinstance(e, dict)}

new_events = [
    {
        "id": "yt_cold_war_01",
        "charId": "yutong",
        "requireRelState": "close",
        "location": "lakeside",
        "slotId": "evening",
        "triggerDay": 200,
        "minAff": 60,
        "priority": 900,
        "title": "断桥边的争执",
        "scenes": [
            {
                "speaker": "yutong",
                "pose": "serious",
                "text": "（她望着湖面，声音有些凉）你最近……好像总是心不在焉。是我多想了吗？"
            },
            {
                "speaker": "player",
                "text": "？",
                "choices": [
                    {
                        "text": "（不耐烦）你想太多了，别烦我。",
                        "affDelta": -5,
                        "relCold": True,
                        "next": 99
                    },
                    {
                        "text": "对不起，我最近确实有点忙。",
                        "affDelta": 3,
                        "next": 99
                    }
                ]
            }
        ]
    },
    {
        "id": "yt_cold_recover_01",
        "charId": "yutong",
        "requireRelState": "cold",
        "location": "classroom",
        "slotId": "morning",
        "triggerDay": 0,
        "minAff": 0,
        "priority": 950,
        "relRecover": True,
        "title": "课桌里的一封道歉信",
        "scenes": [
            {
                "speaker": "yutong",
                "pose": "shy",
                "text": "（她别过脸，把一张折好的信推到你桌上）……这封信，我看了。谢谢你愿意解释。"
            },
            {
                "speaker": "yutong",
                "text": "之前的事，我也有不对。我们……还像以前那样，好吗？",
                "affDelta": 5,
                "next": 99
            }
        ]
    },
]

for ev in new_events:
    if ev["id"] in existing_ids:
        print("跳过已存在事件:", ev["id"])
        continue
    data.append(ev)
    existing_ids.add(ev["id"])
    print("已追加事件:", ev["id"])

with io.open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

# 回读校验
with io.open(path, "r", encoding="utf-8") as f:
    reloaded = json.load(f)
print("校验通过，事件总数:", len(reloaded))
