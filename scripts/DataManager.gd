extends Node

# 事件与角色数据
var events: Array = []
var char_list: Array = []  # 完整角色列表（含男女双方）
var _event_index: Dictionary = {}   # 地点分桶索引：location_id -> Array[event]（空串=全局事件）
var _char_dict: Dictionary = {}     # 角色字典：char_id -> Dictionary

# 事件文件列表（按人物线/类型分拆，方便维护）
const EVENT_FILES = [
    "res://scripts/events_opening.json",
    "res://scripts/events_yutong.json",
    "res://scripts/events_jingjing.json",
    "res://scripts/events_wanqing.json",
    "res://scripts/events_xiaoxia.json",
    "res://scripts/events_keke.json",
    "res://scripts/events_male.json",
    "res://scripts/events_special.json",
    "res://scripts/events_break.json",
    "res://scripts/events_sports.json",
    "res://scripts/events_dean.json",
    "res://scripts/events_ptm.json",
    "res://scripts/events_roles.json",
    "res://scripts/events_grad.json",
    "res://scripts/events_deskmate.json",
    "res://scripts/events_daily.json",
    "res://scripts/events_life.json",
    "res://scripts/events_birthday.json",
    "res://scripts/events_vacation.json",
    "res://scripts/events_campus.json",
    "res://scripts/events_festivals.json",
    "res://scripts/events_graduation.json",
    "res://scripts/events_social.json",
    "res://scripts/events_exams.json",
]

# 地点基础属性增益（对应 LOCATION_STAT_GAINS）
const LOCATION_STAT_GAINS = {
    "classroom":       {"intellect": 3, "stress": 5},
    "library":         {"intellect": 4, "art": 1, "stress": 3},
    "playground":      {"strength": 4, "stress": -6},
    "music_room":      {"art": 4, "social": 1, "stress": -2},
    "art_room":        {"art": 4, "stress": -2},
    "off_campus_shop": {"social": 2, "stress": -5},
    "school_gate":     {"social": 1, "stress": -2},
    "lakeside":        {"social": 2, "art": 2, "stress": -10},
    "community":       {"social": 1, "stress": -5},
    "home":            {},  # 卧室收益通过专属事件控制
    "cinema":          {"social": 3, "stress": -8},
    "amusement_park":  {"social": 3, "strength": 1, "stress": -12},
}

# 礼物个性化喜好反馈配置
const GIFT_PREFERENCES = {
    "yutong": {
        "exam_guide": {
            "favor": 15,
            "dialogue": "“中考复习指南？谢谢你！里面很多归纳确实很精妙，咱们课后可以一起讨论错题，加油！”"
        },
        "love_letter": {
            "favor": 12,
            "dialogue": "（她愣了一下，接过粉色信封，脸颊微微起了一抹绯红）“这、这是给我的信？谢谢……我会认真读的。”",
            "gallery_unlock": "seen_yutong_shy"
        },
        "milk_tea": {
            "favor": 6,
            "dialogue": "“温热的奶茶？谢谢。不过偶尔喝喝放松一下就好了，高糖饮料喝多了容易犯困呢。”"
        },
        "game_console": {
            "favor": 1,
            "dialogue": "“游戏机？……谢谢，不过初三阶段最好还是少玩游戏比较好，不要分心哦。”"
        }
    },
    "jingjing": {
        "milk_tea": {
            "favor": 15,
            "dialogue": "“哇！是我最喜欢的满杯乌龙奶茶，还加了椰果！算你识相，那本天才就勉为其难收下啦！”"
        },
        "love_letter": {
            "favor": 15,
            "dialogue": "（她咬了咬嘴唇，有些不知所措地把信封藏在背后）“笨蛋！怎么突然送我这个……别、别以为一封信就能收买我！”",
            "gallery_unlock": "seen_jingjing_shy"
        },
        "game_console": {
            "favor": 10,
            "dialogue": "“掌上游戏机？好啊，你竟敢拿这个诱惑我！不过看起来是最新款，拿来借我玩几天，不许反悔！”"
        }
    },
    "xiaoxia": {
        "game_console": {
            "favor": 20,
            "dialogue": "“哇塞！最新的掌机！这个限定游戏我排队好久都没买到，你太够哥们了！今晚联机，不见不散！”"
        },
        "milk_tea": {
            "favor": 10,
            "dialogue": "“打完球来一杯冰镇奶茶简直是人间美味！谢啦，下回体育课我分你半个西瓜！”"
        }
    },
    "wanqing": {
        "exam_guide": {
            "favor": 10,
            "dialogue": "“复习指南吗？谢谢，刚好可以查漏补缺。这本诗集也送给你，我们可以互相分享感悟。”"
        },
        "love_letter": {
            "favor": 12,
            "dialogue": "（她静静地端详着粉色信封，嘴角扬起一抹温柔的笑意）“文字是心之声……谢谢你的情谊，我会珍藏的。”"
        }
    }
}


func _ready():
    _load_data()

func _load_data():
    events = []
    # 加载所有事件文件
    var loaded_count = 0
    for file_path in EVENT_FILES:
        var ef = FileAccess.open(file_path, FileAccess.READ)
        if ef:
            var json = JSON.new()
            if json.parse(ef.get_as_text()) == OK:
                var file_events = json.get_data()
                if file_events is Array:
                    events.append_array(file_events)
                    loaded_count += file_events.size()
                    print("DataManager: %s 加载了 %d 个事件" % [file_path.get_file(), file_events.size()])
            else:
                print("DataManager: %s 解析失败" % file_path.get_file())
            ef.close()
        else:
            print("DataManager: 找不到文件 %s" % file_path.get_file())

    print("DataManager: 共加载 %d 个事件" % loaded_count)

    if events.is_empty():
        print("DataManager: 所有事件文件均加载失败，使用内置备用数据")
        _load_fallback_events()

    # 构建事件索引（按地点分桶，加速后续查询）
    _build_index()

    # 读取 characters.json
    var cf = FileAccess.open("res://scripts/characters.json", FileAccess.READ)
    if cf:
        var json2 = JSON.new()
        if json2.parse(cf.get_as_text()) == OK:
            char_list = json2.get_data()
            print("DataManager: 加载了 %d 个角色" % char_list.size())
        cf.close()

    # 构建角色字典（O(1) 查找替代线性遍历）
    _char_dict.clear()
    for c in char_list:
        var cid = c.get("id", "")
        if cid != "":
            _char_dict[cid] = c


# 备用内置事件（防止 JSON 缺失时完全空白）
func _load_fallback_events():
    events = [
        {
            "id": "yt_001", "charId": "yutong", "location": "classroom",
            "slotId": "morning", "triggerDay": 1, "minAff": 0, "priority": 1000,
            "title": "第一天，班长出现了",
            "scenes": [
                {"speaker": null, "text": "教室里还没几个人。你找到自己的座位，刚放下书包——"},
                {"speaker": "yutong", "text": "喂，你就是新来的吧？我叫陈雨桐，班长。这是课程表，记好了。"},
                {"speaker": null, "text": "稍微整理了一下心情，时间悄悄流逝了。"}
            ]
        }
    ]

# ── 事件索引构建（启动加载一次，热重载后重新调用）────────────────
func _build_index():
    _event_index.clear()
    for ev in events:
        if not ev is Dictionary: continue
        var loc = ev.get("location", "")
        if loc == null: loc = ""
        if not _event_index.has(loc):
            _event_index[loc] = []
        _event_index[loc].append(ev)
    print("DataManager: 索引构建完成，地点分桶: %d" % _event_index.size())

# ── 获取可用事件（核心过滤逻辑）──────────────────────────────
func get_available_event(location_id: String) -> Dictionary:
    var current_day = GameManager.day
    var current_slot = _get_slot_id_from_index(GameManager.slot_index)

    # 获取当前性别对应的攻略角色ID列表
    var target_char_ids = _get_target_char_ids()

    # 候选事件列表（满足所有条件）
    var candidates: Array = []

    # 使用索引：仅遍历当前地点 + 全局事件（空串key），而非全部事件
    var pool: Array = []
    pool.append_array(_event_index.get(location_id, []))
    pool.append_array(_event_index.get("", []))

    for ev in pool:
        if not ev is Dictionary: continue
        # 如果是专供外围逻辑强制拉起的事件（如大考、校运会、发榜、固定包抄），严禁普通探索随机出
        if ev.get("manual_only", false): continue
        
        # 检查地点（null location = 全局事件，在任意地点可触发）
        var ev_location = ev.get("location", "")
        if ev_location == null: ev_location = ""
        if ev_location != "" and ev_location != location_id: continue

        # 检查时间段（JSON null 在 GDScript 里不等于 ""，需显式处理）
        var slot_id = ev.get("slotId", "")
        if slot_id == null: slot_id = ""
        if slot_id != "" and slot_id != current_slot: continue

        # 检查触发天数：triggerDay 为"从该天起可用"，而不是"仅在该天"
        # ⚠️ 【fest 约定】节日事件因为被 MainGame._apply_special_date 直通触发，不受下列门槛拦截。
        # 在 JSON 中，fest 类事件必须将其 triggerDay 写死为刚好等于节日当天（否则会在之前的天数错误流入常规池被消费）
        var trigger_day = int(ev.get("triggerDay", 0))
        if trigger_day > 0 and current_day < trigger_day: continue

        # 检查是否已触发（非可重复事件）
        var ev_id = ev.get("id", "")
        if not ev.get("repeatable", false) and GameManager.flags.has(ev_id): continue

        # 检查角色相关条件（JSON null 在 GDScript 里不等于 ""，需显式处理）
        var char_id = ev.get("charId", "")
        if char_id == null: char_id = ""
        if char_id != "":
            # 仅显示当前性别对应的攻略角色的事件
            if not target_char_ids.has(char_id): continue
            # 检查角色解锁天数
            var char_data = get_character(char_id)
            var unlock_day = int(char_data.get("unlockDay", 1)) if not char_data.is_empty() else 1
            if current_day < unlock_day: continue
            # 检查最低好感度
            var min_aff = int(ev.get("minAff", 0))
            var current_aff = GameManager.favorability.get(char_id, 0)
            if current_aff < min_aff: continue

        # 检查 requireFlags
        var req_flags = ev.get("requireFlags", [])
        if req_flags == null: req_flags = []
        var flags_ok = true
        for f in req_flags:
            if not (f in GameManager.flags):
                flags_ok = false
                break
        if not flags_ok: continue

        # 检查 excludeFlags (互斥标志位，防止已邀约时重复触发邀请事件)
        var ex_flags = ev.get("excludeFlags", [])
        if ex_flags == null: ex_flags = []
        var flags_ex_ok = true
        for f in ex_flags:
            if f in GameManager.flags:
                flags_ex_ok = false
                break
        if not flags_ex_ok: continue

        # 检查 requireItem & requireItemAmt (触发需要物品，如电影票等，用于完美的约会邀请机制)
        var req_item = ev.get("requireItem", "")
        if req_item != "" and req_item != null:
            var req_item_amt = int(ev.get("requireItemAmt", 1))
            if not GameManager.has_item(req_item, req_item_amt):
                continue

        # 检查 requireMoney（攒钱门控：金钱不足时跳过该事件，用于限时攒钱目标事件）
        var req_money = int(ev.get("requireMoney", 0))
        if req_money > 0 and GameManager.money < req_money:
            continue

        # 检查 minAddict（网瘾最低值，用于上瘾/警告事件）
        var min_addict = int(ev.get("minAddict", 0))
        if min_addict > 0 and GameManager.stats.get("addict", 0) < min_addict: continue

        # 检查 minStress（压力最低值）
        var min_stress = int(ev.get("minStress", 0))
        if min_stress > 0 and GameManager.stats.get("stress", 0) < min_stress: continue

        # 检查 conditionType（特殊条件类型）
        var cond_type = ev.get("conditionType", "")
        if cond_type == null: cond_type = ""
        if cond_type == "hw_pending" and GameManager.hw_status == 0: continue

        # 检查 requireWeather（天气条件，用于四季西湖限定事件）
        var req_weather = ev.get("requireWeather", "")
        if req_weather == null: req_weather = ""
        if req_weather != "" and req_weather != GameManager.current_weather: continue

        # 检查 requireSeason（季节条件，用于十景限定事件）
        var req_season = ev.get("requireSeason", "")
        if req_season == null: req_season = ""
        if req_season != "" and req_season != GameManager.get_season(): continue

        # 检查 requireHoliday（长假门控：事件仅在该长假期间触发；"any"=任意长假期间）
        var req_holiday = ev.get("requireHoliday", "")
        if req_holiday == null: req_holiday = ""
        if req_holiday != "":
            if req_holiday == "any":
                if GameManager.current_holiday == "": continue
            elif GameManager.current_holiday != req_holiday: continue

        # 长假期间：抑制校内地点日常事件（位置集合方案，零 JSON 改动）
        if GameManager.current_holiday != "":
            var SCHOOL_LOCATIONS = ["classroom", "library", "playground", "music_room", "art_room"]
            var ev_loc = ev.get("location", "")
            if ev_loc == null: ev_loc = ""
            if ev_loc in SCHOOL_LOCATIONS: continue

        # 检查 requireRelState / excludeRelState（关系状态机）
        # requireRelState：关系状态必须等于该值才触发（如专属心动事件仅 crush 出现）
        # excludeRelState：关系状态不能等于（如冷战期屏蔽普通邀约事件）
        var rel_char = ev.get("charId", "")
        if rel_char == null: rel_char = ""
        if rel_char != "":
            var req_rel = ev.get("requireRelState", "")
            if req_rel == null: req_rel = ""
            if req_rel != "" and RelationshipManager.get_rel_state(rel_char) != req_rel: continue
            var ex_rel = ev.get("excludeRelState", "")
            if ex_rel == null: ex_rel = ""
            if ex_rel != "" and RelationshipManager.get_rel_state(rel_char) == ex_rel: continue

        # 检查 requireNGCount（NG+ 专属事件：至少经历过 N 个周目才触发）
        var req_ng = ev.get("requireNGCount", 0)
        if req_ng == null: req_ng = 0
        var current_ng = GameManager.flags.get("ng_count", 0)
        if req_ng > 0 and current_ng < req_ng: continue

        # 检查 requireNotEnding（排除已走过的特定结局，防止已攻略角色重复触发初次相遇感）
        var req_not_ending = ev.get("requireNotEnding", "")
        if req_not_ending == null: req_not_ending = ""
        if req_not_ending != "":
            var seen = GameManager.flags.get("seen_endings", [])
            if seen is Array and req_not_ending in seen: continue


        candidates.append(ev)

    if candidates.is_empty():
        return {}

    # 按优先级排序，取最高的
    candidates.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))
    return candidates[0]

# ── 新增：根据 ID 查找事件 ────────────────────────────
func get_event_by_id(event_id: String) -> Dictionary:
    for e in events:
        if e.get("id", "") == event_id:
            return e
    return {}

# ── 应用地点基础属性增益（含天气加成） ─────────────────────────
func apply_location_gains(location_id: String) -> Array:
    var gains = LOCATION_STAT_GAINS.get(location_id, {})
    var msgs: Array = []
    for stat_key in gains.keys():
        var amount = gains[stat_key]
        # 网瘾>40时，正向收益减半
        if GameManager.stats.get("addict", 0) > 40 and amount > 0 and stat_key != "stress":
            amount = max(1, amount / 2)
        # 天气动态加成（晴天户外+30%，雨/雪天室内学习+20%）
        var bonus = GameManager.get_weather_stat_bonus(stat_key, location_id)
        if bonus != 1.0 and amount > 0:
            amount = max(1, int(float(amount) * bonus))
        GameManager.add_stat(stat_key, amount)
        if amount != 0:
            var sign = "+" if amount > 0 else ""
            msgs.append("%s%s%d" % [stat_key, sign, amount])
    return msgs

# ── 工具方法 ────────────────────────────────────────────────
func _get_slot_id_from_index(index: int) -> String:
    var slots = ["morning", "noon", "after", "evening"]
    if index >= 0 and index < slots.size():
        return slots[index]
    return "morning"

func _get_target_char_ids() -> Array:
    # 男主攻略女角色，女主攻略男角色
    var female_chars = ["yutong", "jingjing", "wanqing", "xiaoxia", "keke"]
    var male_chars   = ["yifei", "zicheng", "beichen", "jingjing_m", "zijun"]
    if GameManager.gender == "male":
        return female_chars
    else:
        return male_chars

func get_character(char_id: String) -> Dictionary:
    # O(1) 字典查找，替代原来的线性遍历
    if _char_dict.has(char_id):
        return _char_dict[char_id]
    # fallback：从 GameManager.char_meta 中取
    return GameManager.char_meta.get(char_id, {})

func get_gift_preference(char_id: String, item_id: String) -> Dictionary:
    var char_pref = GIFT_PREFERENCES.get(char_id, {})
    return char_pref.get(item_id, {
        "favor": 3,
        "dialogue": "谢谢你的礼物！我很喜欢。"
    })
