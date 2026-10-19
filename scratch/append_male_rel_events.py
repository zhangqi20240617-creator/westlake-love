# -*- coding: utf-8 -*-
import json, io

PATH = "scripts/events_male.json"

# 女主路线 5 男角色：冷战 + 挽回事件
# 字段与女角色 PoC 对齐：requireRelState / minAff / priority / slotId / relCold / relRecover
# location / slotId 严格匹配角色真实出现地点（get_available_event 地点硬过滤）
EVENTS = [
    # ── 沈逸飞 yifei（音乐，music_room/lakeside）────────────
    {
        "id": "yf_cold_war_01",
        "charId": "yifei",
        "requireRelState": "close",
        "location": "music_room",
        "slotId": "evening",
        "triggerDay": 0,
        "minAff": 60,
        "priority": 900,
        "title": "琴声戛然而止",
        "scenes": [
            {
                "speaker": "yifei",
                "pose": "serious",
                "text": "（他停下弓，侧脸在灯下显得疏冷）……你刚才看手机的样子，像是在忍着听我拉琴。是我自作多情了？"
            },
            {
                "speaker": "player",
                "text": "？",
                "choices": [
                    {
                        "text": "（不耐烦）你那点高雅爱好，谁耐烦听。",
                        "affDelta": -5,
                        "relCold": True,
                        "next": 99
                    },
                    {
                        "text": "（缓和）抱歉，刚才走神了，不是故意的。",
                        "affDelta": 3,
                        "next": 99
                    }
                ]
            }
        ]
    },
    {
        "id": "yf_cold_recover_01",
        "charId": "yifei",
        "requireRelState": "cold",
        "location": "lakeside",
        "slotId": "morning",
        "triggerDay": 0,
        "minAff": 0,
        "priority": 950,
        "relRecover": True,
        "title": "乐谱里夹着的纸条",
        "scenes": [
            {
                "speaker": "yifei",
                "pose": "shy",
                "text": "（他把一卷乐谱递给你，指尖有点凉）……那天是我太沉溺自己，没注意到你。谱子里夹了张纸，你看看。"
            },
            {
                "speaker": "yifei",
                "text": "还愿意来听我拉琴吗？",
                "next": 99
            }
        ]
    },
    # ── 周子诚 zicheng（篮球，playground/off_campus_shop）────
    {
        "id": "zc_cold_war_01",
        "charId": "zicheng",
        "requireRelState": "close",
        "location": "playground",
        "slotId": "evening",
        "triggerDay": 0,
        "minAff": 60,
        "priority": 900,
        "title": "球场边的冷脸",
        "scenes": [
            {
                "speaker": "zicheng",
                "pose": "upset",
                "text": "（他擦着汗，笑容收了起来）刚才训练你冲我发那通火，队友都看见了。我……是哪里惹你不痛快了？"
            },
            {
                "speaker": "player",
                "text": "？",
                "choices": [
                    {
                        "text": "（火大）你算老几？少来管教我！",
                        "affDelta": -5,
                        "relCold": True,
                        "next": 99
                    },
                    {
                        "text": "（缓和）刚才心情差，冲你撒气了，别往心里去。",
                        "affDelta": 3,
                        "next": 99
                    }
                ]
            }
        ]
    },
    {
        "id": "zc_cold_recover_01",
        "charId": "zicheng",
        "requireRelState": "cold",
        "location": "off_campus_shop",
        "slotId": "morning",
        "triggerDay": 0,
        "minAff": 0,
        "priority": 950,
        "relRecover": True,
        "title": "递来的冰可乐",
        "scenes": [
            {
                "speaker": "zicheng",
                "pose": "shy",
                "text": "（他把一瓶冰可乐塞给你，咧了下嘴又别开眼）……那天我嘴太快，拿你撒气不对。可乐你爱喝冰的。"
            },
            {
                "speaker": "zicheng",
                "text": "还一起打球不？球场又不会自己跑。",
                "next": 99
            }
        ]
    },
    # ── 顾北辰 beichen（神秘转学，library/school_gate，D300）─
    {
        "id": "bc_cold_war_01",
        "charId": "beichen",
        "requireRelState": "close",
        "location": "library",
        "slotId": "evening",
        "triggerDay": 300,
        "minAff": 60,
        "priority": 900,
        "title": "最后一盏灯下",
        "scenes": [
            {
                "speaker": "beichen",
                "pose": "serious",
                "text": "（闭馆铃响，他合上书，难得主动开口）……你刚才那句'跟你没话聊'，是认真的？"
            },
            {
                "speaker": "player",
                "text": "？",
                "choices": [
                    {
                        "text": "（冷淡）你话这么少，跟你说着累。",
                        "affDelta": -5,
                        "relCold": True,
                        "next": 99
                    },
                    {
                        "text": "（缓和）抱歉，我没听清，你再说一遍？",
                        "affDelta": 3,
                        "next": 99
                    }
                ]
            }
        ]
    },
    {
        "id": "bc_cold_recover_01",
        "charId": "beichen",
        "requireRelState": "cold",
        "location": "school_gate",
        "slotId": "morning",
        "triggerDay": 300,
        "minAff": 0,
        "priority": 950,
        "relRecover": True,
        "title": "校门口的伞",
        "scenes": [
            {
                "speaker": "beichen",
                "pose": "shy",
                "text": "（他撑着伞在校门口等你，难得抬眼）……昨天是我不对，不该赌气不理你。下雨了，一起走？"
            },
            {
                "speaker": "beichen",
                "text": "路不远，伞够两个人。",
                "next": 99
            }
        ]
    },
    # ── 叶明轩 jingjing_m（青梅竹马，community/school_gate）──
    {
        "id": "jm_cold_war_01",
        "charId": "jingjing_m",
        "requireRelState": "close",
        "location": "community",
        "slotId": "evening",
        "triggerDay": 0,
        "minAff": 60,
        "priority": 900,
        "title": "隔壁窗内的沉默",
        "scenes": [
            {
                "speaker": "jingjing_m",
                "pose": "upset",
                "text": "（他拎着书包站在你家门口，欲言又止）……我刚想顺路陪你走段，你那句'不用你管'说得挺顺口。"
            },
            {
                "speaker": "player",
                "text": "？",
                "choices": [
                    {
                        "text": "（不耐烦）我的事不用你这个哥哥操心。",
                        "affDelta": -5,
                        "relCold": True,
                        "next": 99
                    },
                    {
                        "text": "（缓和）抱歉，今天有点烦，不是冲你。",
                        "affDelta": 3,
                        "next": 99
                    }
                ]
            }
        ]
    },
    {
        "id": "jm_cold_recover_01",
        "charId": "jingjing_m",
        "requireRelState": "cold",
        "location": "school_gate",
        "slotId": "morning",
        "triggerDay": 0,
        "minAff": 0,
        "priority": 950,
        "relRecover": True,
        "title": "塞进书包的糖",
        "scenes": [
            {
                "speaker": "jingjing_m",
                "pose": "shy",
                "text": "（他趁你不备，往你书包侧袋塞了颗糖，耳根发红）……从小一块长大，你别跟我生分。"
            },
            {
                "speaker": "jingjing_m",
                "text": "还当我是不说话的邻居哥哥，行吗？",
                "next": 99
            }
        ]
    },
    # ── 林紫君 zijun（美术，art_room/library）──────────────
    {
        "id": "zj_cold_war_01",
        "charId": "zijun",
        "requireRelState": "close",
        "location": "art_room",
        "slotId": "evening",
        "triggerDay": 0,
        "minAff": 60,
        "priority": 900,
        "title": "画布前的僵局",
        "scenes": [
            {
                "speaker": "zijun",
                "pose": "serious",
                "text": "（她握着画笔，挑眉看你）我这幅画改了三遍，你刚才那句'也就那样'……是真觉得不好，还是随便敷衍我？"
            },
            {
                "speaker": "player",
                "text": "？",
                "choices": [
                    {
                        "text": "（冷淡）就你那点画，也值得较真？",
                        "affDelta": -5,
                        "relCold": True,
                        "next": 99
                    },
                    {
                        "text": "（缓和）抱歉，我刚才说话重了。",
                        "affDelta": 3,
                        "next": 99
                    }
                ]
            }
        ]
    },
    {
        "id": "zj_cold_recover_01",
        "charId": "zijun",
        "requireRelState": "cold",
        "location": "library",
        "slotId": "morning",
        "triggerDay": 0,
        "minAff": 0,
        "priority": 950,
        "relRecover": True,
        "title": "速写本里的一页",
        "scenes": [
            {
                "speaker": "zijun",
                "pose": "shy",
                "text": "（她把速写本推到你面前，翻到一页——画的是你，脸有点红）……那天是我太要强了。这幅，是照着记忆画的。"
            },
            {
                "speaker": "zijun",
                "text": "还当我是朋友吗？",
                "next": 99
            }
        ]
    },
]

with io.open(PATH, encoding="utf-8") as f:
    data = json.load(f)

existing_ids = {e.get("id") for e in data if isinstance(e, dict)}
for ev in EVENTS:
    assert ev["id"] not in existing_ids, "事件 id 冲突: " + ev["id"]

data.extend(EVENTS)

with io.open(PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("OK events_male.json: +%d 事件 (yifei/zicheng/beichen/jingjing_m/zijun 各 cold+recover)" % len(EVENTS))
print("总计事件数:", len(data))
