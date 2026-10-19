import json
import codecs
import re
import string

path = "d:/zkgame/scripts/events_life.json"
with open(path, "rb") as f:
    data = f.read()

try:
    text = data.decode("utf-8")
except:
    text = data.decode("utf-16")
    
start = text.find("[")
match = re.search(r"club_chain_art_s4(.*?)\]", text, re.IGNORECASE | re.DOTALL)
if not match:
    # Try finding the last }
    match = re.search(r".*}", text, re.IGNORECASE | re.DOTALL)

valid_part = text[start:match.end()]
# Make sure it ends cleanly 
# it might not have ] so we manually put it
valid_part = valid_part.strip()
if not valid_part.endswith("]"):
    valid_part = valid_part + "\n]"

events = []
try:
    events = json.loads(valid_part)
    print(f"Loaded {len(events)} existing events.")
except Exception as e:
    print("Could not load partially cleaned JSON:", e)
    # clean it up further
    cleaned = ""
    for c in valid_part:
        if c in string.printable or ord(c) > 127: # roughly
            cleaned += c
    valid_part = cleaned
    try:
        events = json.loads(valid_part)
    except:
        print("Still failing")
        exit(1)

new_events = [
  {
    "id": "olympiad_invite",
    "triggerDay": 150,
    "priority": 220,
    "repeatable": False,
    "location": "classroom",
    "slotId": "after",
    "requireFlags": [],
    "excludeFlags": [],
    "dialogue": [
      {"name": "班主任老张", "text": "你的理科成绩非常突出。市里在组织初中科学奥赛集训，有没有兴趣参加？"},
      {"name": "班主任老张", "text": "不过丑话说在前面，这条路需要你牺牲几乎所有的休息时间，抗压能力要极强。"},
      {
        "name": "player",
        "text": "我要参加吗？",
        "options": [
          {
            "label": "毫不犹豫地答应（压力激增先兆）",
            "statDelta": {"stress": 20, "intellect": 2},
            "setFlags": ["flag_olympiad_joined"],
            "next": "olympiad_invite_yes"
          },
          {
            "label": "还是算了吧，我更喜欢均衡发展",
            "statDelta": {"stress": -5},
            "next": "olympiad_invite_no"
          }
        ]
      }
    ],
    "subScenes": {
      "olympiad_invite_yes": [
        {"name": "班主任老张", "text": "好！这周末就开始集训，别让我失望。"},
        {"isEndTrigger": True}
      ],
      "olympiad_invite_no": [
        {"name": "player", "text": "（老张似乎有些遗憾，但他尊重了我的选择。）"},
        {"isEndTrigger": True}
      ]
    },
    "customCondition": "return GameManager.subject_scores.get(\"math\", 0) >= 20 and GameManager.subject_scores.get(\"science\", 0) >= 20 and GameManager.stats.get(\"intellect\", 0) >= 30"
  },
  {
    "id": "olympiad_training_1",
    "triggerDay": 160,
    "priority": 220,
    "repeatable": False,
    "location": "classroom",
    "slotId": "after",
    "requireFlags": ["flag_olympiad_joined"],
    "excludeFlags": [],
    "dialogue": [
      {"name": "系统", "text": "你迎来了第一次奥赛周末集训。整整一个下午都在解题，完全没有时间休息。"},
      {
        "name": "player",
        "text": "该死，这道几何题也太偏门了吧...",
        "options": [
          {
            "label": "死磕到底！放弃所有社团与玩乐",
            "statDelta": {"stress": 15, "intellect": 3},
            "setFlags": ["flag_olympiad_t1"],
            "next": "olympiad_t1_end"
          }
        ]
      }
    ],
    "subScenes": {
      "olympiad_t1_end": [
        {"name": "player", "text": "（做完几十张卷子，感觉自己被掏空了，朋友的消息也一句没回。）"},
        {"isEndTrigger": True}
      ]
    }
  },
  {
    "id": "olympiad_training_2",
    "triggerDay": 210,
    "priority": 220,
    "repeatable": False,
    "location": "library",
    "slotId": "after",
    "requireFlags": ["flag_olympiad_t1"],
    "excludeFlags": [],
    "dialogue": [
      {"name": "系统", "text": "又是长达4个小时的魔鬼集训。窗外同学在一起打球，你面对的是一黑板天书。"},
      {
        "name": "player",
        "text": "（感觉压力好大，随时可能会崩溃……）",
        "options": [
          {
            "label": "咬紧牙关，继续撑下去",
            "statDelta": {"stress": 20, "intellect": 3, "social": -2},
            "setFlags": ["flag_olympiad_t2"],
            "next": "olympiad_t2_end"
          }
        ]
      }
    ],
    "subScenes": {
      "olympiad_t2_end": [
        {"name": "player", "text": "（你甚至没时间参加最近的一次班级聚会。）"},
        {"isEndTrigger": True}
      ]
    }
  },
  {
    "id": "olympiad_training_3",
    "triggerDay": 280,
    "priority": 220,
    "repeatable": False,
    "location": "classroom",
    "slotId": "after",
    "requireFlags": ["flag_olympiad_t2"],
    "excludeFlags": [],
    "dialogue": [
      {"name": "系统", "text": "考前拔高集训，很多同学中途退出了，考场越来越空旷。"},
      {
        "name": "player",
        "text": "大家都在哪？",
        "options": [
          {
            "label": "不管他们，我是为了保送",
            "statDelta": {"stress": 20, "intellect": 5, "social": -5},
            "setFlags": ["flag_olympiad_t3"],
            "next": "olympiad_t3_end"
          }
        ]
      }
    ],
    "subScenes": {
      "olympiad_t3_end": [
        {"name": "老张", "text": "很好，能坚持到现在，你是最有希望的苗子。"},
        {"isEndTrigger": True}
      ]
    }
  },
  {
    "id": "olympiad_semifinal",
    "triggerDay": 360,
    "priority": 225,
    "repeatable": False,
    "location": "city_center",
    "slotId": None,
    "noTimeCost": True,
    "requireFlags": ["flag_olympiad_t3"],
    "excludeFlags": [],
    "dialogue": [
      {"name": "系统", "text": "【市级奥赛初赛】今天正式打响，考场寂静无声。"}
    ],
    "customCondition": "return true",
    "evaluateScript": "var math=GameManager.subject_scores.get(\"math\", 0); if math >= 28: return \"pass\"; else: return \"fail\";",
    "subScenes": {
      "pass": [
        {"name": "评委会", "text": "【红榜公布】：初赛满分！获取省决入场券！"},
        {"setFlags": ["flag_olympiad_semifinal_pass"]},
        {"isEndTrigger": True}
      ],
      "fail": [
        {"name": "评委会", "text": "【很遗憾，你未通过初赛，止步于此】"},
        {"name": "player", "text": "（失去了一切时间，到头来还是竹篮打水一场空……这极度的压抑感……）"},
        {"statDelta": {"stress": 40}},
        {"setFlags": ["flag_olympiad_dropped"]},
        {"isEndTrigger": True}
      ]
    }
  },
  {
    "id": "olympiad_final",
    "triggerDay": 420,
    "priority": 225,
    "repeatable": False,
    "location": "city_center",
    "slotId": None,
    "noTimeCost": True,
    "requireFlags": ["flag_olympiad_semifinal_pass"],
    "excludeFlags": ["flag_olympiad_gold"],
    "dialogue": [
      {"name": "系统", "text": "【全省总决赛】最后的战役。只有一个人能拿下独一无二的保送名额。"},
      {
        "name": "player",
        "text": "拼了，三年不曾有过周末，就为了今天！",
        "options": [
          {
            "label": "【交卷】",
            "statDelta": {"intellect": 10},
            "next": "final_eval"
          }
        ]
      }
    ],
    "subScenes": {
      "final_eval": [
        {"name": "系统", "text": "【系统广播】比赛结束了，你的思路如同神助……"},
        {"name": "省教委主任", "text": "恭喜你！毫无争议的全省第一金牌！"},
        {"setFlags": ["flag_olympiad_gold"]},
        {"isEndTrigger": True}
      ]
    }
  }
]

all_ids = set([e.get("id") for e in events])
for ne in new_events:
    if ne["id"] not in all_ids:
        events.append(ne)

with open(path, "w", encoding="utf-8") as f:
    json.dump(events, f, ensure_ascii=False, indent=2)

print("SUCCESS")
