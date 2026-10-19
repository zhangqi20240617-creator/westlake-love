#!/usr/bin/env python3
"""
彻底修复 events.json：
  1. 逐行扫描，找到损坏位置，通过找到前一个完整事件来截断
  2. 把 jj_chat 事件补全（硬编码正确内容）
  3. 拆分为多个文件
  4. 添加缺失的日常事件
"""
import json, os, re, sys

SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))

# ── 1. 强力修复：找到第一个 JSON 解析错误前的所有完整事件 ────────
raw_path = os.path.join(SCRIPTS_DIR, "events.json")
with open(raw_path, "r", encoding="utf-8", errors="replace") as f:
    content = f.read()

# 替换掉所有 replacement character (损坏的 UTF-8)
content_clean = content.replace('\ufffd', '?')

# 找损坏位置
try:
    all_events = json.loads(content_clean)
    print(f"[OK] 直接解析成功，共 {len(all_events)} 个事件")
except json.JSONDecodeError as e:
    print(f"[WARN] 在 char {e.pos} / line {e.lineno} 发现 JSON 错误")
    
    # 策略：截断到损坏处，然后找最后一个完整的 "  }," 模式
    bad_pos = e.pos
    truncated = content_clean[:bad_pos]
    
    # 向前找最后一个完整的事件结束 (看到 `  },\n` 或 `  }\n`)
    # 具体来说，找最后一个 `  }` 在数组顶层
    # 我们用贪婪方式：截断后加 "]" 再解析
    # 每次往前移10个字符试一次
    saved_events = []
    for shrink in range(0, 5000, 1):
        test_content = truncated[:bad_pos - shrink]
        last_brace = test_content.rfind('\n  }')
        if last_brace == -1:
            continue
        candidate = test_content[:last_brace+4].rstrip().rstrip(',') + '\n]'
        try:
            saved_events = json.loads(candidate)
            print(f"[OK] 截断修复成功：保留到第 {len(saved_events)} 个事件 (shrink={shrink})")
            break
        except:
            continue
    
    if not saved_events:
        print("[ERROR] 无法自动修复，请手动检查文件")
        sys.exit(1)
    
    all_events = saved_events

print(f"有效事件数量: {len(all_events)}")
existing_ids = {e.get('id') for e in all_events}

# ── 2. 补全被截断的 jj_chat 事件 ────────────────────────────────
if 'jj_chat' not in existing_ids:
    print("[+] 补全缺失的 jj_chat 事件")
    all_events.append({
        "id": "jj_chat", "charId": "jingjing", "location": "community", "slotId": "evening",
        "triggerDay": 0, "minAff": 0, "priority": 1, "repeatable": True,
        "requireFlags": ["jj_001"],
        "title": "晚风与散步",
        "scenes": [
            {"speaker": None, "text": "晚上的小区里，菁菁正百无聊赖地踢着路边的石子。", "choices": [
                {"text": "陪她聊聊天", "blockIfTempFlag": "jj_chat_done", "affDelta": 2, "setTempFlag": "jj_chat_done", "next": 2},
                {"text": "买些路边小吃一起分享 (💰-30)", "reqMoney": 30, "affDelta": 6, "statDelta": {"money": -30, "stress": -8}, "next": 3},
                {"text": "不早了，早点回家休息吧", "next": 99}
            ]},
            {"speaker": "jingjing", "text": "（她转头看见是你，眉毛扬了一下）……家里太闷了，出来透透气。陪我走走？", "next": 4},
            {"speaker": "jingjing", "text": "（她开心地接过小吃）……嘿嘿，还是你懂我！正好饿了。", "next": 4},
            {"speaker": "jingjing", "text": "还有事吗？没事我再踢会儿石头。", "next": 1}
        ]
    })

# ── 3. 定义拆分规则 ──────────────────────────────────────────────
CHAR_FILES = {
    "yutong":     "events_yutong.json",
    "jingjing":   "events_jingjing.json",
    "wanqing":    "events_wanqing.json",
    "xiaoxia":    "events_xiaoxia.json",
    "yifei":      "events_male.json",
    "zicheng":    "events_male.json",
    "beichen":    "events_male.json",
    "zijun":      "events_male.json",
    "jingjing_m": "events_male.json",
}

SPECIAL_IDS = {
    "special_festival", "special_festival_jj",
    "special_valentine_yt", "special_valentine_jj",
    "special_valentine_wq", "special_valentine_xx",
    "special_valentine_yf", "special_valentine_zc",
    "special_graduation_eve", "special_grad_wq",
    "special_grad_xx", "special_grad_yf", "special_grad_zc",
}

buckets = {
    "events_yutong.json":   [],
    "events_jingjing.json": [],
    "events_wanqing.json":  [],
    "events_xiaoxia.json":  [],
    "events_male.json":     [],
    "events_special.json":  [],
    "events_daily.json":    [],
}

for ev in all_events:
    ev_id   = ev.get("id", "")
    char_id = ev.get("charId", "") or ""
    if ev_id in SPECIAL_IDS:
        buckets["events_special.json"].append(ev)
    elif char_id in CHAR_FILES:
        buckets[CHAR_FILES[char_id]].append(ev)
    else:
        buckets["events_daily.json"].append(ev)

# ── 4. 添加缺失的日常事件（如果不存在） ─────────────────────────
DAILY_EVENTS = [
  {
    "id": "home_actions", "charId": None, "location": "home", "slotId": None,
    "triggerDay": 0, "minAff": 0, "priority": 150, "repeatable": True,
    "title": "在卧室里",
    "scenes": [{"speaker": None, "text": "回到卧室，温暖的台灯光下，你想做点什么？", "choices": [
      {"text": "📚 认真钻研完成作业 (压力+5, 学习+3)", "conditionType": "hw_pending", "statDelta": {"stress": 5, "intellect": 3}, "setHwStatus": 2, "next": 99},
      {"text": "📚 应付一下作业了事 (压力+2, 学习+1)", "conditionType": "hw_pending", "statDelta": {"stress": 2, "intellect": 1}, "setHwStatus": 3, "next": 99},
      {"text": "🧘 健康休息 (压力-30, 学习+2)", "statDelta": {"stress": -30, "intellect": 2}, "next": 99},
      {"text": "📱 玩手机刷视频 (压力-50, 网瘾+10)", "statDelta": {"stress": -50, "addict": 10}, "next": 99}
    ]}]
  },
  {
    "id": "classroom_homework_check", "charId": None, "location": "classroom",
    "slotId": "morning", "triggerDay": 0, "priority": 200, "repeatable": True,
    "conditionType": "hw_pending",
    "title": "📝 早读课的检查",
    "scenes": [
      {"speaker": None, "text": "（课代表开始挨个收作业，教室里充满了翻动纸张的声音）",
       "logicType": "hw_check", "logicTargets": {"hw_good": 2, "hw_sloppy": 3, "hw_missing": 4, "hw_3rd_miss": 5}},
      {"speaker": "yutong", "text": "你的作业写得真整洁，继续保持。", "statDelta": {"social": 1, "intellect": 1}, "resetHwStatus": True, "next": 99},
      {"speaker": "yutong", "text": "写得有点潦草哦，下次注意。", "statDelta": {"intellect": 1}, "resetHwStatus": True, "next": 99},
      {"speaker": "yutong", "text": "（她皱着眉头站在你课桌前）你的作业呢？……别告诉我你又忘在家里了。", "statDelta": {"stress": 15, "social": -5}, "resetHwStatus": True, "incHwNeglect": True, "next": 99},
      {"speaker": None, "text": "（班主任出现在门口，脸色铁青）{playerName}，这周你已经三次没交作业了。跟我去办公室走一趟。", "statDelta": {"stress": 40, "intellect": -5, "social": -15}, "resetHwStatus": True, "next": 99}
    ]
  },
  {"id": "classroom_general", "charId": None, "location": "classroom", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "在教室内",
   "scenes": [{"speaker": None, "text": "教室里弥漫着淡淡的墨水味和纸张的气息，你想利用这段时间做什么？", "choices": [
     {"text": "📝 认真听讲/自习 (学习+4, 压力+5)", "statDelta": {"intellect": 4, "stress": 5}, "next": 99},
     {"text": "😴 课间趴着打个盹 (压力-12)", "statDelta": {"stress": -12}, "next": 99},
     {"text": "💬 和前后位闲聊 (社交+3, 压力+2)", "statDelta": {"social": 3, "stress": 2}, "next": 99},
     {"text": "🪟 望着窗外发呆 (压力-15, 艺术+1)", "statDelta": {"stress": -15, "art": 1}, "next": 99}
   ]}]},
  {"id": "library_general", "charId": None, "location": "library", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "图书馆自习",
   "scenes": [{"speaker": None, "text": "阳光斜射入静谧的图书馆，这里是绝佳的沉淀之处。", "choices": [
     {"text": "📖 沉浸式深度阅读 (学习+5, 艺术+2, 压力+4)", "statDelta": {"intellect": 5, "art": 2, "stress": 4}, "next": 99},
     {"text": "✍️ 整理错题与笔记 (学习+4, 压力+2)", "statDelta": {"intellect": 4, "stress": 2}, "next": 99},
     {"text": "🧘 坐在靠窗位发呆 (压力-20)", "statDelta": {"stress": -20}, "next": 99}
   ]}]},
  {"id": "playground_general", "charId": None, "location": "playground", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "活跃的操场",
   "scenes": [{"speaker": None, "text": "塑胶跑道的热气混着少年们的呼喊声，充满了活力。", "choices": [
     {"text": "🏃 挥洒汗水的训练 (运动+6, 压力+5)", "statDelta": {"strength": 6, "stress": 5}, "next": 99},
     {"text": "🏀 组织一场对抗赛 (运动+4, 社交+5, 压力+8)", "statDelta": {"strength": 4, "social": 5, "stress": 8}, "next": 99},
     {"text": "🍃 坐在看台吹风 (压力-22)", "statDelta": {"stress": -22}, "next": 99},
     {"text": "👟 练习定点投篮 (运动+5, 压力+3)", "statDelta": {"strength": 5, "stress": 3}, "next": 99}
   ]}]},
  {"id": "off_campus_shop_general", "charId": None, "location": "off_campus_shop", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "校外的小卖部",
   "scenes": [{"speaker": None, "text": "校外的一条狭窄巷子里，这家不起眼的小店挤满了学生。老板娘熟练地收着零钱，空气中满是烤香肠的味道。", "choices": [
     {"text": "🥤 买瓶冰镇汽水 (💰-5, 压力-15)", "statDelta": {"money": -5, "stress": -15}, "next": 99},
     {"text": "🍟 买袋辣条边走边吃 (💰-10, 压力-25)", "statDelta": {"money": -10, "stress": -25}, "next": 99},
     {"text": "🤝 帮同学掩护偷溜出来 (社交+4, 压力+2)", "statDelta": {"social": 4, "stress": 2}, "next": 99}
   ]}]},
  {"id": "music_room_general", "charId": None, "location": "music_room", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "艺术空间",
   "scenes": [{"speaker": None, "text": "空气中似乎还残留着乐器的余韵。", "choices": [
     {"text": "🎵 练习乐理知识 (艺术+5, 学习+1, 压力+3)", "statDelta": {"art": 5, "intellect": 1, "stress": 3}, "next": 99},
     {"text": "🎹 弹奏简单的旋律 (艺术+3, 压力-10)", "statDelta": {"art": 3, "stress": -10}, "next": 99},
     {"text": "🎧 戴上耳机听磁带 (压力-18)", "statDelta": {"stress": -18}, "next": 99}
   ]}]},
  {"id": "art_room_general", "charId": None, "location": "art_room", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "安静的画室",
   "scenes": [{"speaker": None, "text": "松节油的味道让你感到平静。", "choices": [
     {"text": "🎨 临摹大师素描 (艺术+6, 压力+4)", "statDelta": {"art": 6, "stress": 4}, "next": 99},
     {"text": "🖌️ 随意涂鸦写生 (艺术+4, 压力-8)", "statDelta": {"art": 4, "stress": -8}, "next": 99},
     {"text": "🖼️ 欣赏前辈作品 (艺术+2, 压力-15)", "statDelta": {"art": 2, "stress": -15}, "next": 99}
   ]}]},
  {"id": "lakeside_general", "charId": None, "location": "lakeside", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "如画的西湖",
   "scenes": [{"speaker": None, "text": "西湖的美景无论看多少次都不会厌倦。", "choices": [
     {"text": "🚶 环湖漫步思考 (艺术+3, 压力-25)", "statDelta": {"art": 3, "stress": -25}, "next": 99},
     {"text": "📷 拍摄美丽的风景 (艺术+5)", "statDelta": {"art": 5, "stress": -10}, "next": 99},
     {"text": "🛶 观察湖面游船 (社交+2, 压力-15)", "statDelta": {"social": 2, "stress": -15}, "next": 99}
   ]}]},
  {"id": "community_general", "charId": None, "location": "community", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "小区楼下",
   "scenes": [{"speaker": None, "text": "晚风轻拂，邻居们正在散步。", "choices": [
     {"text": "👋 帮邻居提东西 (社交+5, 压力+2)", "statDelta": {"social": 5, "stress": 2}, "next": 99},
     {"text": "🐈 喂路边的野猫 (社交+2, 压力-15)", "statDelta": {"social": 2, "stress": -15}, "next": 99},
     {"text": "🌌 抬头仰望星空 (压力-20)", "statDelta": {"stress": -20}, "next": 99}
   ]}]},
  {"id": "school_gate_general", "charId": None, "location": "school_gate", "slotId": None,
   "triggerDay": 0, "priority": 1, "repeatable": True, "title": "忙碌的校门",
   "scenes": [{"speaker": None, "text": "人来人往的校门口，承载着许多故事。", "choices": [
     {"text": "👀 观察往来人群 (社交+3, 压力-5)", "statDelta": {"social": 3, "stress": -5}, "next": 99},
     {"text": "⌛ 等待朋友路过 (社交+2, 压力-10)", "statDelta": {"social": 2, "stress": -10}, "next": 99},
     {"text": "🍡 购买门口小吃 (社交+1, 压力-12)", "statDelta": {"social": 1, "stress": -12}, "next": 99}
   ]}]},
]

existing_daily_ids = {e.get('id') for e in buckets["events_daily.json"]}
added = 0
for ev in DAILY_EVENTS:
    if ev["id"] not in existing_daily_ids:
        buckets["events_daily.json"].append(ev)
        added += 1
        print(f"  [+] 新增日常事件: {ev['id']}")

print(f"\n新增 {added} 个日常事件到 events_daily.json")

# ── 5. 写出各文件 ────────────────────────────────────────────────
for filename, event_list in buckets.items():
    if not event_list:
        print(f"[跳过] {filename} (空)")
        continue
    out_path = os.path.join(SCRIPTS_DIR, filename)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(event_list, f, ensure_ascii=False, indent=2)
    size_kb = os.path.getsize(out_path) // 1024
    print(f"[写出] {filename}  ({len(event_list)} 个事件, {size_kb}KB)")

print("\n✅ 全部完成！")
total = sum(len(v) for v in buckets.values())
print(f"事件总数: {total}")
