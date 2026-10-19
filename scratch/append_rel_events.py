# -*- coding: utf-8 -*-
import json, io

BASE = "scripts"

# 每个角色：冷战事件 + 挽回事件
# 字段与 yutong PoC 对齐：requireRelState / minAff / priority / slotId / relCold / relRecover
EVENTS = {
    "jingjing": {
        "name": "叶菁菁",
        "cold": {
            "id": "jj_cold_war_01",
            "charId": "jingjing",
            "requireRelState": "close",
            "location": "school_gate",
            "slotId": "evening",
            "triggerDay": 0,
            "minAff": 60,
            "priority": 900,
            "title": "巷口的沉默",
            "scenes": [
                {
                    "speaker": "jingjing",
                    "pose": "upset",
                    "text": "（她背靠路灯杆，把玩着手里的钥匙）……最近你总是一副心事重重的样子。是我多嘴，还是你正跟别人聊得开心？"
                },
                {
                    "speaker": "player",
                    "text": "？",
                    "choices": [
                        {
                            "text": "（不耐烦）我的事不用你管，你少操心。",
                            "affDelta": -5,
                            "relCold": True,
                            "next": 99
                        },
                        {
                            "text": "（缓和）抱歉，最近家里有点事，不是针对你。",
                            "affDelta": 3,
                            "next": 99
                        }
                    ]
                }
            ]
        },
        "recover": {
            "id": "jj_cold_recover_01",
            "charId": "jingjing",
            "requireRelState": "cold",
            "location": "community",
            "slotId": "morning",
            "triggerDay": 0,
            "minAff": 0,
            "priority": 950,
            "relRecover": True,
            "title": "门缝下的一张纸条",
            "scenes": [
                {
                    "speaker": "jingjing",
                    "pose": "shy",
                    "text": "（她站在你家门口，把叠好的纸条往你手里一塞）……昨晚是我语气不好。从小住隔壁的人，哪能说生分就生分。"
                },
                {
                    "speaker": "jingjing",
                    "text": "我们……还像以前那样，好不好？",
                    "next": 99
                }
            ]
        }
    },
    "wanqing": {
        "name": "苏晚晴",
        "cold": {
            "id": "wq_cold_war_01",
            "charId": "wanqing",
            "requireRelState": "close",
            "location": "library",
            "slotId": "evening",
            "triggerDay": 0,
            "minAff": 60,
            "priority": 900,
            "title": "书页间的误会",
            "scenes": [
                {
                    "speaker": "wanqing",
                    "pose": "serious",
                    "text": "（她合上笔记本，目光落在你身上）你上周说帮我看看新写的段落……后来就没了消息。是觉得写得不好，还是根本没放在心上？"
                },
                {
                    "speaker": "player",
                    "text": "？",
                    "choices": [
                        {
                            "text": "（烦躁）你整天就知道写你那点破故事，根本不懂我。",
                            "affDelta": -5,
                            "relCold": True,
                            "next": 99
                        },
                        {
                            "text": "（温和）对不起，我这几天有点累，不是故意不回你。",
                            "affDelta": 3,
                            "next": 99
                        }
                    ]
                }
            ]
        },
        "recover": {
            "id": "wq_cold_recover_01",
            "charId": "wanqing",
            "requireRelState": "cold",
            "location": "lakeside",
            "slotId": "morning",
            "triggerDay": 0,
            "minAff": 0,
            "priority": 950,
            "relRecover": True,
            "title": "夹在书里的书签",
            "scenes": [
                {
                    "speaker": "wanqing",
                    "pose": "shy",
                    "text": "（她把一本你借过的书递回来，扉页夹着一枚手绘书签）……那天我也太固执了，明明该先问你发生了什么。"
                },
                {
                    "speaker": "wanqing",
                    "text": "书先还你。我们……还能像之前那样，一起聊聊故事吗？",
                    "next": 99
                }
            ]
        }
    },
    "xiaoxia": {
        "name": "林小夏",
        "cold": {
            "id": "xx_cold_war_01",
            "charId": "xiaoxia",
            "requireRelState": "close",
            "location": "playground",
            "slotId": "evening",
            "triggerDay": 0,
            "minAff": 60,
            "priority": 900,
            "title": "跑道上的冷风",
            "scenes": [
                {
                    "speaker": "xiaoxia",
                    "pose": "upset",
                    "text": "（她擦着汗，挑眉看你）今天训练你心不在焉的，队友跟你搭话你都爱答不理。怎么，跟我待一块儿嫌闷了？"
                },
                {
                    "speaker": "player",
                    "text": "？",
                    "choices": [
                        {
                            "text": "（火大）你懂个屁，少来管我！",
                            "affDelta": -5,
                            "relCold": True,
                            "next": 99
                        },
                        {
                            "text": "（缓和）刚才情绪有点崩，别往心里去。",
                            "affDelta": 3,
                            "next": 99
                        }
                    ]
                }
            ]
        },
        "recover": {
            "id": "xx_cold_recover_01",
            "charId": "xiaoxia",
            "requireRelState": "cold",
            "location": "playground",
            "slotId": "morning",
            "triggerDay": 0,
            "minAff": 0,
            "priority": 950,
            "relRecover": True,
            "title": "递来的水瓶",
            "scenes": [
                {
                    "speaker": "xiaoxia",
                    "pose": "shy",
                    "text": "（她把一瓶水抛给你，咧了咧嘴又别过脸）……那天是我嘴太快，拿你撒气不对。"
                },
                {
                    "speaker": "xiaoxia",
                    "text": "还一起训练不？操场又不会自己跑。",
                    "next": 99
                }
            ]
        }
    }
}

for char_id, spec in EVENTS.items():
    path = "%s/events_%s.json" % (BASE, char_id)
    with io.open(path, encoding="utf-8") as f:
        data = json.load(f)
    existing_ids = {e.get("id") for e in data if isinstance(e, dict)}
    assert spec["cold"]["id"] not in existing_ids, "cold id 重复: " + spec["cold"]["id"]
    assert spec["recover"]["id"] not in existing_ids, "recover id 重复: " + spec["recover"]["id"]
    data.append(spec["cold"])
    data.append(spec["recover"])
    with io.open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("OK  %s: +2 事件 (cold=%s, recover=%s)" % (char_id, spec["cold"]["id"], spec["recover"]["id"]))
print("全部完成")
