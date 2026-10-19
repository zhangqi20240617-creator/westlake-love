extends Node

var player_name = "主角"
var school_name = "西湖中学"
var gender = "male" # "male" or "female"

# ── 属性系统（7维，新增 addict 网瘾）─────────────────────────
var stats = {
    "intellect": 10,
    "strength":  10,
    "social":    10,
    "art":       10,
    "charm":     10,
    "stress":    0,
    "addict":    0,
    "dean_suspicion": 0,
    "punishment_level": 0
}

var money = 100
var day = 1
var slot_index = 0    # 0:上午, 1:中午, 2:放学后, 3:晚上
var day_of_week = 1   # 1-7 (1=周一)
var current_location: String = ""  # 玩家当前所在地点（供穿搭地点好感加成使用）

# ── 时间即代价：机会成本追踪 ──────────────────────────────────
var studied_this_slot: bool = false  # 本时段是否学习过（智力/分科加分即视为学习）
var _oppcost_last_day: int = -1      # 机会成本提示节流：每天最多提示一次

# ── 天气系统 ──────────────────────────────────────────────────
var current_weather: String = "sunny" # "sunny", "cloudy", "rainy", "snowy"
var current_holiday: String = ""   # 当前所处长假类型（winter/spring/summer/autumn），否则 ""
const WEATHER_NAMES = {
    "sunny":  "☀️ 晴朗",
    "cloudy": "☁️ 阴天",
    "rainy":  "🌧️ 烟雨",
    "snowy":  "❄️ 飘雪"
}

# ── 天气/季节/运势门面（实现已拆至 WeatherManager）────────────────
# 注意：current_weather 与 WEATHER_NAMES 仍留守本类（外部脚本直接读取）；
# WEST_LAKE_SCENES 及所有逻辑已随系统整体迁入 WeatherManager。
func get_season() -> String:
    return WeatherManager.get_season()

func get_season_label() -> String:
    return WeatherManager.get_season_label()

func get_west_lake_scene() -> Dictionary:
    return WeatherManager.get_west_lake_scene()

func get_weather_stat_bonus(stat_name: String, location_id: String) -> float:
    return WeatherManager.get_weather_stat_bonus(stat_name, location_id)

func get_weather_effect_desc() -> String:
    return WeatherManager.get_weather_effect_desc()


# ══════════════════════════════════════════════════════════
# ── 特殊日期地点/热点扩展系统 ─────────────────────────────
# ══════════════════════════════════════════════════════════

# 实现已拆至 LocationManager（locations/day/slot_index 状态留守本类）
func get_location_hotspots(loc_id: String) -> Array:
    return LocationManager.get_location_hotspots(loc_id)

func get_forced_location_for_day() -> String:
    return LocationManager.get_forced_location_for_day()

# ── NG+ 熟悉感台词门面（实现已拆至 NGPlusManager）──────────────
# flags / favorability 状态留守本类；台词池与逻辑已整体迁入 NGPlusManager。
func get_ng_familiarity_line(char_id: String) -> String:
    return NGPlusManager.get_ng_familiarity_line(char_id)


# ── 学期/年级计算 ─────────────────────────────────────────────
func get_grade_info() -> Dictionary:
    if day <= 90:   return {"grade": "初一", "sem": "上学期"}
    elif day <= 180: return {"grade": "初一", "sem": "下学期"}
    elif day <= 270: return {"grade": "初二", "sem": "上学期"}
    elif day <= 360: return {"grade": "初二", "sem": "下学期"}
    elif day <= 450: return {"grade": "初三", "sem": "上学期"}
    else:            return {"grade": "初三", "sem": "下学期"}

func get_day_in_sem() -> int:
    return ((day - 1) % 90) + 1

func is_weekend() -> bool:
    return day_of_week == 6 or day_of_week == 7

# ── 好感度系统 ────────────────────────────────────────────────
var favorability = {
    # 女角色（男主攻略）
    "yutong":    0,
    "jingjing":  20,
    "wanqing":   0,
    "xiaoxia":   0,
    "keke":      0,
    # 男角色（女主攻略）
    "yifei":     0,
    "zicheng":   0,
    "beichen":   0,
    "jingjing_m":20,
    "zijun":     0,
}

var char_meta = {
    "yutong":    {"name": "陈雨桐", "emoji": "👩‍🎓", "tag": "班长·学霸", "color": "#5b9fd4", "unlockDay": 1},
    "jingjing":  {"name": "叶菁菁", "emoji": "🌸",   "tag": "青梅竹马",   "color": "#e87d9a", "unlockDay": 1},
    "wanqing":   {"name": "苏晚晴", "emoji": "📚",   "tag": "文艺委员",   "color": "#a78bfa", "unlockDay": 3},
    "xiaoxia":   {"name": "林小夏", "emoji": "⚽",   "tag": "体育委员",   "color": "#4caf8a", "unlockDay": 2},
    "keke":      {"name": "方可可", "emoji": "🎀",   "tag": "转学生",     "color": "#f59e0b", "unlockDay": 300},
    "yifei":     {"name": "沈逸飞", "emoji": "🎻",   "tag": "音乐课代表", "color": "#5b9fd4", "unlockDay": 1},
    "zicheng":   {"name": "周子诚", "emoji": "🏀",   "tag": "篮球队长",   "color": "#4caf8a", "unlockDay": 2},
    "beichen":   {"name": "顾北辰", "emoji": "🌙",   "tag": "神秘转学生", "color": "#a78bfa", "unlockDay": 300},
    "jingjing_m":{"name": "叶明轩", "emoji": "🌿",  "tag": "青梅竹马",   "color": "#e87d9a", "unlockDay": 1},
    "zijun":     {"name": "林紫君", "emoji": "🎨",   "tag": "美术课代表", "color": "#f59e0b", "unlockDay": 1},
}

# ── 地点定义（含时段与周末限制）────────────────────────────────
var locations = {
    "classroom": {
        "name": "教室", "icon": "🏫", "sub": "本班 / 隔壁班", "unlock": 1, "slots": ["morning","noon","after"], "workdayOnly": true,
        "bg": "res://assets/backgrounds/classroom.jpg",
        "hotspots": [
            {"label": "🔍 黑板 (听课)", "pos": Vector2(0.4, 0.4), "event_id": "class_study"},
            {"label": "🔍 窗外 (发呆)", "pos": Vector2(0.15, 0.45), "event_id": "class_rest"},
            {"label": "💌 课桌 (桌下传纸条)", "pos": Vector2(0.65, 0.6), "event_id": "paper_slip"},
            {"label": "👤 走廊 (找人聊天)", "pos": Vector2(0.85, 0.45), "event_id": "random_event"}
        ]
    },
    "playground": {
        "name": "操场", "icon": "⚽", "sub": "体育运动", "unlock": 1, "slots": ["noon","after"],
        "bg": "res://assets/backgrounds/playground.jpg",
        "hotspots": [
            {"label": "🏸 羽毛球场 (双人切磋)", "pos": Vector2(0.5, 0.55), "event_id": "badminton_rally"},
            {"label": "🏃 跑道 (体能训练)", "pos": Vector2(0.2, 0.7), "event_id": "random_event"},
            {"label": "🥅 球门 (操场漫步)", "pos": Vector2(0.8, 0.5), "event_id": "random_event"}
        ]
    },
    "library": {
        "name": "图书馆", "icon": "📖", "sub": "阅读 / 自习", "unlock": 1, "slots": ["morning","noon","after","evening"],
        "bg": "res://assets/backgrounds/library.jpg",
        "hotspots": [
            {"label": "📚 书架 (检索书籍)", "pos": Vector2(0.3, 0.4), "event_id": "random_event"},
            {"label": "✍️ 阅览桌 (自习钻研)", "pos": Vector2(0.65, 0.6), "event_id": "random_event"},
            {"label": "🪟 靠窗位 (眺望思考)", "pos": Vector2(0.85, 0.45), "event_id": "random_event"}
        ]
    },
    "off_campus_shop": {
        "name": "校外小卖部", "icon": "🥤", "sub": "校门外小巷 / 零食", "unlock": 1, "slots": ["noon","after"],
        "bg": "res://assets/backgrounds/snack_bar.jpg",
        "hotspots": [
            {"label": "🥤 货架 (挑选商品)", "pos": Vector2(0.25, 0.55), "event_id": "shop_ui"},
            {"label": "🏪 柜台 (结账/聊天)", "pos": Vector2(0.7, 0.45), "event_id": "random_event"},
            {"label": "📱 休息区 (蹭网玩手机)", "pos": Vector2(0.5, 0.7), "event_id": "skip_class_game"},
            {"label": "🧸 街角娃娃机 (10元/次)", "pos": Vector2(0.85, 0.65), "event_id": "claw_machine"},
            {"label": "🧋 奶茶小吧 (兼职调饮)", "pos": Vector2(0.12, 0.68), "event_id": "boba_craft"}
        ]
    },
    "school_gate": {
        "name": "校门口", "icon": "🚪", "sub": "放学 / 偶遇", "unlock": 1, "slots": ["after"],
        "bg": "res://assets/backgrounds/school_gate.png",
        "hotspots": [
            {"label": "🚪 铁门 (等同学)", "pos": Vector2(0.5, 0.45), "event_id": "random_event"},
            {"label": "🍡 小吃摊 (吃点零食)", "pos": Vector2(0.2, 0.7), "event_id": "random_event"}
        ]
    },
    "lakeside": {
        "name": "西湖边", "icon": "🌊", "sub": "散步 / 约会", "unlock": 1, "slots": ["after","evening"],
        "bg": "res://assets/backgrounds/lakeside.jpg",
        "hotspots": [
            {"label": "📷 湖畔抓拍 (光影定格)", "pos": Vector2(0.45, 0.35), "event_id": "lake_shutter"},
            {"label": "🪑 长椅 (小憩发呆)", "pos": Vector2(0.2, 0.65), "event_id": "random_event"},
            {"label": "🌊 码头 (观察游船)", "pos": Vector2(0.75, 0.6), "event_id": "random_event"},
            {"label": "🏮 许愿花灯与漂流瓶", "pos": Vector2(0.5, 0.75), "event_id": "lakeside_wishes"},
            {"label": "🏞️ 西湖十景·集章打卡", "pos": Vector2(0.72, 0.28), "event_id": "west_lake_stamp"}
        ]
    },
    "community": {
        "name": "小区楼下", "icon": "🏘️", "sub": "青梅竹马", "unlock": 1, "slots": ["evening"],
        "bg": "res://assets/backgrounds/community.png",
        "hotspots": [
            {"label": "🏘️ 单元门 (上楼回家)", "pos": Vector2(0.5, 0.5), "event_id": "random_event"},
            {"label": "🌳 树荫花坛 (闲逛透气)", "pos": Vector2(0.2, 0.6), "event_id": "random_event"},
            {"label": "🪑 凉亭 (休息坐坐)", "pos": Vector2(0.8, 0.6), "event_id": "random_event"}
        ]
    },
    "music_room":      {"name": "音乐教室",   "icon": "🎵", "sub": "音乐 / 艺术",       "unlock": 3,   "slots": ["noon","after"], "workdayOnly": true, "bg": "res://assets/backgrounds/music_room.jpg"},
    "art_room":        {"name": "美术教室",   "icon": "🎨", "sub": "画画 / 安静",       "unlock": 3,   "slots": ["noon","after"], "workdayOnly": true, "bg": "res://assets/backgrounds/art_room.jpg"},
    "home": {
        "name": "主角卧室", "icon": "🛏️", "sub": "休息 / 独处", "unlock": 1, "slots": ["morning","noon","after","evening"],
        "bg": "res://assets/backgrounds/home.png",
        "hotspots": [
            {"label": "🔍 书桌 (做作业)", "pos": Vector2(0.2, 0.6), "event_id": "home_study"},
            {"label": "🛌 床 (睡觉)", "pos": Vector2(0.8, 0.7), "event_id": "home_sleep"},
            {"label": "📱 手机 (微信聊天)", "pos": Vector2(0.5, 0.75), "event_id": "phone_wechat"},
            {"label": "👤 其它活动", "pos": Vector2(0.5, 0.45), "event_id": "random_event"}
        ]
    },
    "cinema":          {"name": "市中心影院", "icon": "🍿", "sub": "约会圣地",           "unlock": 7,   "slots": ["morning","noon","after","evening"], "weekendOnly": true, "bg": "res://assets/backgrounds/cinema_bg.jpg"},
    "amusement_park": {
        "name": "市郊游乐园", "icon": "🎡", "sub": "放松身心 / 约会", "unlock": 7,
        "slots": ["morning","noon","after","evening"], "weekendOnly": true,
        "bg": "res://assets/backgrounds/amusement_park_bg.jpg",
        "hotspots": [
            {"label": "🧸 梦幻娃娃机 (抓玩偶)", "pos": Vector2(0.75, 0.6), "event_id": "claw_machine"},
            {"label": "🎡 摩天轮 (俯瞰全景)", "pos": Vector2(0.35, 0.45), "event_id": "random_event"},
            {"label": "🎠 旋转木马 (浪漫打卡)", "pos": Vector2(0.55, 0.65), "event_id": "random_event"}
        ]
    },
    "market": {
        "name": "清河坊市集", "icon": "🏮", "sub": "杭州特产 / 食材", "unlock": 1,
        "slots": ["morning","noon","after"],
        "bg": "res://assets/backgrounds/school_gate.png",
        "hotspots": [
            {"label": "🛒 食材摊 (购买食材)", "pos": Vector2(0.3, 0.5), "event_id": "cooking_market"},
            {"label": "🍡 小食摊 (品尝小吃)", "pos": Vector2(0.65, 0.55), "event_id": "random_event"},
            {"label": "🫖 茶叶铺 (选购龙井)", "pos": Vector2(0.5, 0.35), "event_id": "cooking_market"}
        ]
    },
    "kitchen": {
        "name": "主角厨房", "icon": "🍳", "sub": "烹饪 / 料理", "unlock": 1,
        "slots": ["noon","evening"],
        "bg": "res://assets/backgrounds/home.png",
        "hotspots": [
            {"label": "🍳 灶台 (开始烹饪)", "pos": Vector2(0.45, 0.5), "event_id": "cooking_ui"},
            {"label": "📖 食谱本 (查看菜谱)", "pos": Vector2(0.2, 0.4), "event_id": "cooking_ui"},
            {"label": "📦 食材柜 (查看库存)", "pos": Vector2(0.75, 0.45), "event_id": "cooking_ui"}
        ]
    },
    # ── 系统 C：食堂 / 校内小卖部 ──────────────────────────────
    "school_canteen": {
        "name": "学校食堂", "icon": "🍱", "sub": "午饭 / 偶遇", "unlock": 1,
        "slots": ["noon"], "workdayOnly": true,
        "bg": "res://assets/backgrounds/classroom.jpg",
        "hotspots": [
            {"label": "🍱 打饭窗口 (随机偶遇)", "pos": Vector2(0.3, 0.45), "event_id": "canteen_random"},
            {"label": "🪑 座位区 (找个地方坐)", "pos": Vector2(0.65, 0.55), "event_id": "canteen_seat_meet"},
            {"label": "🧋 饮料机 (买饮料)", "pos": Vector2(0.5, 0.75), "event_id": "canteen_drink_buy"}
        ]
    },
    "school_kiosk": {
        "name": "校内小卖部", "icon": "🏪", "sub": "零食 / 文具", "unlock": 1,
        "slots": ["noon","after"], "workdayOnly": true,
        "bg": "res://assets/backgrounds/snack_bar.jpg",
        "hotspots": [
            {"label": "🍜 快餐货架 (买零食)", "pos": Vector2(0.25, 0.5), "event_id": "kiosk_snack_buy"},
            {"label": "📒 文具区 (购买文具)", "pos": Vector2(0.6, 0.4), "event_id": "kiosk_stationery"},
            {"label": "👤 收银台 (偶遇同学)", "pos": Vector2(0.8, 0.6), "event_id": "kiosk_encounter"}
        ]
    },
    # ── 系统 B：假期专属地点 ────────────────────────────────────
    "vacation_park": {
        "name": "假期公园", "icon": "🌳", "sub": "假期漫步 / 放松", "unlock": 1,
        "slots": ["morning","noon","after"], "vacationOnly": true,
        "bg": "res://assets/backgrounds/community.png",
        "hotspots": [
            {"label": "🌅 湖边步道 (散步)", "pos": Vector2(0.4, 0.5), "event_id": "vacation_park_explore"},
            {"label": "🎡 休闲广场 (闲逛)", "pos": Vector2(0.7, 0.4), "event_id": "vacation_park_explore"},
            {"label": "☕ 露天茶摊 (喝茶)", "pos": Vector2(0.2, 0.65), "event_id": "vacation_park_explore"}
        ]
    },
    "part_time_job": {
        "name": "兼职岗位", "icon": "🛍️", "sub": "假期兼职 / 赚钱", "unlock": 1,
        "slots": ["morning","noon","after"], "vacationOnly": true,
        "bg": "res://assets/backgrounds/snack_bar.jpg",
        "hotspots": [
            {"label": "🧋 奶茶店 (调饮实战)", "pos": Vector2(0.3, 0.5), "event_id": "boba_craft"},
            {"label": "📚 图书整理 (兼职打工)", "pos": Vector2(0.65, 0.45), "event_id": "part_time_work"},
            {"label": "📦 快递分拣 (兼职打工)", "pos": Vector2(0.5, 0.7), "event_id": "part_time_work"}
        ]
    },
}

# ── Flags 与日志 ──────────────────────────────────────────────
var flags: Dictionary = {}   # 改为 Dictionary 方便 in 操作
var recent_logs: Array = []
var diary: Array = []        # 日记条目

# ── 作业系统 ────────────────────────────────────────────
var hw_status: int = 0         # 0:无作业, 1:待完成, 2:认真完成, 3:应付了事
var current_hw_subject: String = "" # 当日作业科目：chinese/math/english/science/society
var quiz_bonus_score: int = 0  # 中考答题额外奖励分数（每对一题+10，最终结算）
var hw_neglect_count: int = 0  # 连续未交次数

# ── 同桌系统 (Desk-mate System) ────────────────────────────────────────────────
var current_deskmate: String = "generic_boy_nerd" # 当前同桌ID

func refresh_deskmate():
    # 候选池
    var candidates = [{"id": "generic_boy_trouble", "weight": 10}, 
                      {"id": "generic_girl_nerd", "weight": 10},
                      {"id": "generic_boy_sleep", "weight": 10}]
    
    # 动态女主权重
    for char_id in ["wanqing", "yutong", "xiaoyu"]:
        var meta = char_meta.get(char_id, {})
        if day < meta.get("unlockDay", 1): continue
        if flags.has("rel_cold_" + char_id): continue # 冷战中绝对不同桌
        var fav = favorability.get(char_id, 0)
        var wt = 5 # 基础权重
        if fav > 80: wt = 40 # 高好感度权重飙升
        elif fav > 40: wt = 15
        candidates.append({"id": char_id, "weight": wt})
        
    var total_weight = 0
    for c in candidates: total_weight += c["weight"]
    
    var roll = randi() % total_weight
    var acc = 0
    var new_mate = "generic_boy_trouble"
    for c in candidates:
        acc += c["weight"]
        if roll < acc:
            new_mate = c["id"]
            break
            
    current_deskmate = new_mate
    
    # 清理所有可能会作为同桌的flag，并设置新的
    var all_possible = ["wanqing", "yutong", "xiaoyu", "generic_boy_trouble", "generic_girl_nerd", "generic_boy_sleep"]
    for c in all_possible:
        flags.erase("flag_deskmate_" + c)
    flags["flag_deskmate_" + new_mate] = true
    
    var name_label = char_meta.get(new_mate, {}).get("name", "")
    if name_label == "":
        if new_mate == "generic_boy_trouble": name_label = "【百事通调皮鬼】"
        elif new_mate == "generic_girl_nerd": name_label = "【内卷学霸女】"
        elif new_mate == "generic_boy_sleep": name_label = "【睡神胖子】"
        
    show_toast.emit("🔄 重新排座位了！你的新同桌是：" + name_label)
    add_log("🔄 重新排座位了！新同桌：" + name_label)

# ── 分科复习系统 ─────────────────────────────────────────────────
## 五科进度 0-100，独立于智力属性，直接影响中考各科满分
var subject_scores: Dictionary = {
    "chinese": 0, "math": 0, "english": 0, "science": 0, "society": 0
}
const SUBJECT_META: Dictionary = {
    "chinese": {"label": "语文", "emoji": "📖", "max_exam": 120},
    "math":    {"label": "数学", "emoji": "🔢", "max_exam": 120},
    "english": {"label": "英语", "emoji": "🌍", "max_exam": 120},
    "science": {"label": "科学", "emoji": "🔬", "max_exam": 160},
    "society": {"label": "社会", "emoji": "🌏", "max_exam": 100},
}

## 分科加分/薄弱科目（实现已拆至 ExamManager，此处为门面委托）
func add_subject_score(subject: String, amount: int):
    studied_this_slot = true  # 分科复习即视为本时段学习过
    ExamManager.add_subject_score(subject, amount)

func get_weakest_subject() -> Dictionary:
    return ExamManager.get_weakest_subject()

# ── 临时标志位（每个时段清空）───────────────────────────────
var temp_flags: Dictionary = {} # 每个时段进展后自动清除

# ── 物品系统 ──────────────────────────────────────────────────
# 物品定义数据库
const ITEM_DB = {
    "movie_ticket": {"name": "电影票", "icon": "🎫", "desc": "周末去市中心影院必备。", "price": 40},
    "amusement_ticket": {"name": "游乐园门票", "icon": "🎟️", "desc": "周末去市郊游乐园的入场券。", "price": 80},
    "exam_guide": {"name": "中考复习指南", "icon": "📚", "desc": "全科复习资料，或许能在学习时发挥大作用。", "price": 50},
    "love_letter": {"name": "粉色信封", "icon": "💌", "desc": "似乎是一封没有署名的情书。", "price": 25},
    "game_console": {"name": "掌上游戏机", "icon": "🎮", "desc": "缓解压力的好东西，但容易沉迷。", "price": 120},
    "milk_tea": {"name": "奶茶", "icon": "🧋", "desc": "大家都喜欢的饮品，适合送人。", "price": 15},
    "handmade_gift": {"name": "手作礼物", "icon": "🎁", "desc": "自己做的手作，可以送给朋友。", "price": 0, "category": "gift"},
    # ── 西湖风物志 · 购得 6 件（DS-RN-04）────────────────────────
    # category == "fengwu" 是购得入册的唯一识别位：CollectionManager.add_item()
    # 尾部的 _try_grant_fengwu_item() 会以 item_id 当 fid 直接落账。
    # ⚠️ 这 6 个 key 必须与 CollectionManager.FENGWU_ITEMS 的 fid 逐字相同。
    # ⚠️ ShopUI.update_shop_list() 无条件遍历 ITEM_DB → 此处新增即自动上架，勿另加白名单。
    "fw_longjing":    {"name": "明前龙井",     "icon": "🍵", "desc": "清明前采的头茬狮峰龙井，一小罐，香气清冽。", "price": 60, "category": "fengwu"},
    "fw_oufen":       {"name": "西湖藕粉",     "icon": "🥣", "desc": "开水一冲便成半透明的糊，撒上干桂花。",       "price": 30, "category": "fengwu"},
    "fw_guihuatang":  {"name": "桂花糖",       "icon": "🍯", "desc": "满觉陇的桂花腌成糖，把秋天存进罐子里。",     "price": 20, "category": "fengwu"},
    "fw_chousan":     {"name": "西湖绸伞",     "icon": "🌂", "desc": "竹骨绸面，薄得能透光。好看多过好用。",       "price": 90, "category": "fengwu"},
    "fw_wangxingji":  {"name": "王星记黑纸扇", "icon": "🪭", "desc": "杭扇老字号，一开一声「唰」，比风更像夏天。", "price": 70, "category": "fengwu"},
    "fw_tianzhukuai": {"name": "天竺筷",       "icon": "🥢", "desc": "天竺山细竹所制，竹节上烙着西湖十景。",       "price": 45, "category": "fengwu"},
    # ── 娃娃机专属玩偶系列 ────────────────────────────────────────
    "doll_bunny":     {"name": "软萌粉兔玩偶", "icon": "🐰", "desc": "粉扑扑的长耳朵兔子玩偶，菁菁最喜欢这种软绵绵的东西。", "price": 0, "category": "doll", "favorite_char": "jingjing"},
    "doll_bear":      {"name": "学士帽小熊",   "icon": "🧸", "desc": "戴着迷你学士帽的毛绒小熊，雨桐似乎对它情有独钟。",   "price": 0, "category": "doll", "favorite_char": "yutong"},
    "doll_cat":       {"name": "慵懒橘猫玩偶", "icon": "🐱", "desc": "圆滚滚眯着眼睛的猫咪抱枕，晚晴在书店常看这只猫的插画。", "price": 0, "category": "doll", "favorite_char": "wanqing"},
    "doll_dino":      {"name": "暴龙怪兽玩偶", "icon": "🦖", "desc": "呆萌的小恐龙玩偶，小夏房间里摆了好几只同款。",     "price": 0, "category": "doll", "favorite_char": "xiaoxia"},
    "doll_koi":       {"name": "西湖锦鲤布偶", "icon": "🐟", "desc": "金红相间的吉祥小锦鲤，可可刚来杭州时就想买一只。", "price": 0, "category": "doll", "favorite_char": "keke"}
}
var inventory: Dictionary = {} # item_id -> count

# ── 角色心情状态系统 ──────────────────────────────────────────────
## 每天换日时为各攻略角色随机生成心情，影响当日好感收益
var char_mood: Dictionary = {}  # char_id -> "happy"|"normal"|"upset"

# ── 关系状态机缓存（状态 = 好感度派生 + 冷战覆盖；真相仍在 favorability）──
## 由 RelationshipManager 在 add_favor / 每日结算时重算，随档保存
var relationship_state: Dictionary = {}  # char_id -> "stranger"|"acquaintance"|"friend"|"close"|"crush"|"cold"

# 心情逻辑与 MOOD_DISPLAY 常量已拆至 DailyCycleManager（char_mood 状态留守本类）
func get_char_mood(char_id: String) -> String:
    return DailyCycleManager.get_char_mood(char_id)

func get_char_mood_display(char_id: String) -> Dictionary:
    return DailyCycleManager.get_char_mood_display(char_id)

## 关系状态机门面（实现已拆至 RelationshipManager；relationship_state 状态留守本类）
func get_rel_state(char_id: String) -> String:
    return RelationshipManager.get_rel_state(char_id)

func get_rel_state_display(char_id: String) -> Dictionary:
    return RelationshipManager.get_rel_state_display(char_id)



# ── 画廊系统：所有可收集立绘的定义 ────────────────────────────
# 每条记录：{ char, pose, label, hint, flag }
# flag: 触发解锁的 flag 名；为空字符串 "" 表示初始即解锁
const GALLERY_ITEMS = [
    # ── 陈雨桐（yutong）────────────────────────────────────────
    { "char": "yutong",       "pose": "default",  "label": "陈雨桐·校服",    "hint": "初始解锁（默认校服立绘）",               "flag": "",                     "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "yutong",       "pose": "serious",  "label": "陈雨桐·认真",    "hint": "在对话中展示「陈雨桐·认真」立绘时自动解锁",      "flag": "seen_yutong_serious",  "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "yutong",       "pose": "shy",      "label": "陈雨桐·羞涩",    "hint": "在对话中展示「陈雨桐·羞涩」立绘时自动解锁",      "flag": "seen_yutong_shy",      "bg": "res://assets/backgrounds/lakeside.jpg" },
    { "char": "yutong",       "pose": "casual",   "label": "陈雨桐·便服",    "hint": "在对话中展示「陈雨桐·便服」立绘时自动解锁",      "flag": "seen_yutong_casual",   "bg": "res://assets/backgrounds/school_gate.png" },
    { "char": "yutong",       "pose": "study",    "label": "陈雨桐·自习",    "hint": "在对话中展示「陈雨桐·自习」立绘时自动解锁",      "flag": "seen_yutong_study",    "bg": "res://assets/backgrounds/library.jpg" },
    { "char": "yutong",       "pose": "sport",    "label": "陈雨桐·运动装",   "hint": "在对话中展示「陈雨桐·运动装」立绘时自动解锁",     "flag": "seen_yutong_sport",    "bg": "res://assets/backgrounds/playground.jpg" },
    { "char": "yutong",       "pose": "anim",     "label": "陈雨桐·动态立绘",  "hint": "与陈雨桐好感度达到50后解锁（动态视频立绘）",     "flag": "seen_yutong_anim",     "bg": "res://assets/backgrounds/lakeside.jpg", "type": "video" },
    # ── 叶菁菁（jingjing）────────────────────────────────────────
    { "char": "jingjing",     "pose": "default",  "label": "叶菁菁·校服",    "hint": "初始解锁（默认校服立绘）",               "flag": "",                     "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "jingjing",     "pose": "shy",      "label": "叶菁菁·羞涩",    "hint": "在对话中展示「叶菁菁·羞涩」立绘时自动解锁",      "flag": "seen_jingjing_shy",    "bg": "res://assets/backgrounds/community.png" },
    { "char": "jingjing",     "pose": "serious",  "label": "叶菁菁·认真",    "hint": "在对话中展示「叶菁菁·认真」立绘时自动解锁",      "flag": "seen_jingjing_serious","bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "jingjing",     "pose": "casual",   "label": "叶菁菁·便服",    "hint": "与叶菁菁好感度达到40后解锁（便服）",         "flag": "seen_jingjing_casual", "bg": "res://assets/backgrounds/lakeside.jpg" },
    { "char": "jingjing",     "pose": "sport",    "label": "叶菁菁·运动装",   "hint": "在对话中展示「叶菁菁·运动装」立绘时自动解锁",     "flag": "seen_jingjing_sport",  "bg": "res://assets/backgrounds/playground.jpg" },
    # ── 林小夏（xiaoxia）────────────────────────────────────────
    { "char": "xiaoxia",      "pose": "default",  "label": "林小夏·校服",    "hint": "初始解锁（默认校服立绘）",               "flag": "",                     "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "xiaoxia",      "pose": "casual",   "label": "林小夏·便服",    "hint": "与林小夏好感度达到60后解锁（便服）",         "flag": "seen_xiaoxia_casual",  "bg": "res://assets/backgrounds/lakeside.jpg" },
    { "char": "xiaoxia",      "pose": "shy",      "label": "林小夏·羞涩",    "hint": "在对话中展示「林小夏·羞涩」立绘时自动解锁",      "flag": "seen_xiaoxia_shy",     "bg": "res://assets/backgrounds/community.png" },
    { "char": "xiaoxia",      "pose": "sport",    "label": "林小夏·运动装",   "hint": "与林小夏好感度达到30后解锁，或对话中展示时自动解锁",  "flag": "seen_xiaoxia_sport",   "bg": "res://assets/backgrounds/playground.jpg" },
    # ── 苏晚晴（wanqing）────────────────────────────────────────
    { "char": "wanqing",      "pose": "default",  "label": "苏晚晴·校服",    "hint": "初始解锁（默认校服立绘）",               "flag": "",                     "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "wanqing",      "pose": "shy",      "label": "苏晚晴·羞涩",    "hint": "在对话中展示「苏晚晴·羞涩」立绘时自动解锁",      "flag": "seen_wanqing_shy",     "bg": "res://assets/backgrounds/library.jpg" },
    { "char": "wanqing",      "pose": "serious",  "label": "苏晚晴·认真",    "hint": "与苏晚晴好感度达到30后解锁，或对话中展示时自动解锁",  "flag": "seen_wanqing_serious", "bg": "res://assets/backgrounds/library.jpg" },
    { "char": "wanqing",      "pose": "casual",   "label": "苏晚晴·便服",    "hint": "与苏晚晴好感度达到60后解锁（便服）",         "flag": "seen_wanqing_casual",  "bg": "res://assets/backgrounds/lakeside.jpg" },
    # ── 沈逸飞（yifei）────────────────────────────────────────
    { "char": "yifei",        "pose": "default",  "label": "沈逸飞·校服",    "hint": "初始解锁（默认校服立绘）",               "flag": "",                     "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "yifei",        "pose": "shy",      "label": "沈逸飞·羞涩",    "hint": "在对话中展示「沈逸飞·羞涩」立绘时自动解锁",      "flag": "seen_yifei_shy",       "bg": "res://assets/backgrounds/music_room.jpg" },
    { "char": "yifei",        "pose": "serious",  "label": "沈逸飞·认真",    "hint": "在对话中展示「沈逸飞·认真」立绘时自动解锁",      "flag": "seen_yifei_serious",   "bg": "res://assets/backgrounds/music_room.jpg" },
    { "char": "yifei",        "pose": "casual",   "label": "沈逸飞·便服",    "hint": "在寒假章节展示「沈逸飞·便服」立绘时自动解锁",     "flag": "seen_yifei_casual",    "bg": "res://assets/backgrounds/cinema_bg.jpg" },
    # ── 周子诚（zicheng）────────────────────────────────────────
    { "char": "zicheng",      "pose": "default",  "label": "周子诚·校服",    "hint": "初始解锁（默认校服立绘）",               "flag": "",                     "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "zicheng",      "pose": "shy",      "label": "周子诚·羞涩",    "hint": "在对话中展示「周子诚·羞涩」立绘时自动解锁",      "flag": "seen_zicheng_shy",     "bg": "res://assets/backgrounds/snack_bar.jpg" },
    { "char": "zicheng",      "pose": "serious",  "label": "周子诚·认真",    "hint": "在对话中展示「周子诚·认真」立绘时自动解锁",      "flag": "seen_zicheng_serious", "bg": "res://assets/backgrounds/playground.jpg" },
    { "char": "zicheng",      "pose": "casual",   "label": "周子诚·便服",    "hint": "在秋假章节展示「周子诚·便服」立绘时自动解锁",     "flag": "seen_zicheng_casual",  "bg": "res://assets/backgrounds/holiday_autumn_osmanthus.jpg" },
    # ── 方可可（keke）────────────────────────────────────────
    { "char": "keke",         "pose": "default",  "label": "方可可·校服",    "hint": "待美术资源补全后，展示「方可可·校服」立绘时解锁",   "flag": "seen_keke_default",    "bg": "res://assets/backgrounds/classroom.jpg" },
    { "char": "keke",       "pose": "shy",     "label": "方可可·羞涩", "hint": "在对话中展示「方可可·羞涩」立绘时自动解锁",        "flag": "seen_keke_shy",     "bg": "res://assets/backgrounds/lakeside.jpg" },
    { "char": "keke",       "pose": "upset",   "label": "方可可·委屈", "hint": "在对话中展示「方可可·委屈」立绘时自动解锁",    "flag": "seen_keke_upset",   "bg": "res://assets/backgrounds/snack_bar.jpg" },
    # ── 顾北辰（beichen）────────────────────────────────────────
    { "char": "beichen",      "pose": "default",  "label": "顾北辰·校服",    "hint": "待美术资源补全后，展示「顾北辰·校服」立绘时解锁",   "flag": "seen_beichen_default", "bg": "res://assets/backgrounds/lakeside.jpg" },
    { "char": "beichen",    "pose": "serious", "label": "顾北辰·认真", "hint": "在对话中展示「顾北辰·认真」立绘时自动解锁", "flag": "seen_beichen_serious", "bg": "res://assets/backgrounds/school_gate.png" },
    { "char": "beichen",    "pose": "shy",     "label": "顾北辰·羞涩", "hint": "在对话中展示「顾北辰·羞涩」立绘时自动解锁", "flag": "seen_beichen_shy", "bg": "res://assets/backgrounds/library.jpg" },
    # ── 叶明轩（jingjing_m）────────────────────────────────────────
    { "char": "jingjing_m",   "pose": "default",  "label": "叶明轩·校服",    "hint": "待美术资源补全后，展示「叶明轩·校服」立绘时解锁",   "flag": "seen_jingjing_m_default","bg": "res://assets/backgrounds/community.png" },
    { "char": "jingjing_m", "pose": "shy",     "label": "叶明轩·羞涩", "hint": "在对话中展示「叶明轩·羞涩」立绘时自动解锁",   "flag": "seen_jingjing_m_shy", "bg": "res://assets/backgrounds/community.png" },
    { "char": "jingjing_m", "pose": "upset",   "label": "叶明轩·委屈", "hint": "在对话中展示「叶明轩·委屈」立绘时自动解锁",         "flag": "seen_jingjing_m_upset", "bg": "res://assets/backgrounds/community.png" },
    # ── 林紫君（zijun）────────────────────────────────────────
    { "char": "zijun",        "pose": "default",  "label": "林紫君·校服",    "hint": "待美术资源补全后，展示「林紫君·校服」立绘时解锁",   "flag": "seen_zijun_default",   "bg": "res://assets/backgrounds/art_room.jpg" },
    { "char": "zijun",      "pose": "serious", "label": "林紫君·认真", "hint": "在对话中展示「林紫君·认真」立绘时自动解锁",     "flag": "seen_zijun_serious", "bg": "res://assets/backgrounds/art_room.jpg" },
    { "char": "zijun",      "pose": "shy",     "label": "林紫君·羞涩", "hint": "在对话中展示「林紫君·羞涩」立绘时自动解锁", "flag": "seen_zijun_shy", "bg": "res://assets/backgrounds/library.jpg" },
    # ── 长假记忆画廊（holiday_memory_*，由 chapter 事件最终场景 setFlag 自动解锁）──
    { "char": "yutong",       "pose": "memory", "label": "寒假·雪夜断桥",   "hint": "雪夜断桥，与雨桐的牵手时刻。",           "flag": "holiday_memory_winter_yutong",   "bg": "res://assets/backgrounds/holiday_winter.jpg" },
    { "char": "jingjing",     "pose": "memory", "label": "寒假·糖水铺约定", "hint": "糖水铺，与菁菁的「明年同班」约定。",   "flag": "holiday_memory_winter_jingjing", "bg": "res://assets/backgrounds/holiday_winter.jpg" },
    { "char": "yifei",        "pose": "memory", "label": "寒假·冬夜影院",   "hint": "冬夜影院，与逸飞的「下次还来」。",     "flag": "holiday_memory_winter_yifei",    "bg": "res://assets/backgrounds/holiday_winter.jpg" },
    { "char": "wanqing",      "pose": "memory", "label": "春假·桃林写生",   "hint": "桃林写生，晚晴念出春天故事的主角名。", "flag": "holiday_memory_spring_wanqing",  "bg": "res://assets/backgrounds/holiday_spring_outing.jpg" },
    { "char": "xiaoxia",      "pose": "memory", "label": "春假·攀岩馆",     "hint": "攀岩馆，与小夏的每年之约。",         "flag": "holiday_memory_spring_xiaoxia",  "bg": "res://assets/backgrounds/holiday_spring_outing.jpg" },
    { "char": "beichen",      "pose": "memory", "label": "春假·科幻片",     "hint": "科幻片，与北辰的「下个春假老地方」。", "flag": "holiday_memory_spring_beichen",  "bg": "res://assets/backgrounds/holiday_spring_outing.jpg" },
    { "char": "keke",         "pose": "memory", "label": "暑假·萤火夜跑",   "hint": "萤火夜跑，与可可的芦苇荡秘密基地。", "flag": "holiday_memory_summer_keke",     "bg": "res://assets/backgrounds/holiday_summer_trip.jpg" },
    { "char": "zijun",        "pose": "memory", "label": "暑假·夜市淘宝",   "hint": "夜市淘宝，与子珺的河灯之约。",       "flag": "holiday_memory_summer_zijun",    "bg": "res://assets/backgrounds/holiday_summer_trip.jpg" },
    { "char": "zicheng",      "pose": "memory", "label": "秋假·桂花林",     "hint": "桂花林，与子诚的「每年秋天都来」。", "flag": "holiday_memory_autumn_zicheng",  "bg": "res://assets/backgrounds/holiday_autumn_osmanthus.jpg" },
    { "char": "jingjing_m",   "pose": "memory", "label": "秋假·桂花诗会",   "hint": "桂花诗会，与菁菁（男）的朗诵之约。", "flag": "holiday_memory_autumn_jingjing_m", "bg": "res://assets/backgrounds/holiday_autumn_osmanthus.jpg" },
    { "char": "player", "pose": "grad_photo",   "label": "毕业合影",   "hint": "初三毕业典礼当日合影，由 grad_photo CG 解锁。", "flag": "grad_photo",   "bg": "res://assets/backgrounds/grad_photo.jpg" },
    { "char": "player", "pose": "yearbook",     "label": "毕业纪念册", "hint": "毕业纪念册跨页，由 grad_yearbook 解锁。", "flag": "grad_yearbook", "bg": "res://assets/backgrounds/lakeside_evening.jpg" },
    { "char": "player", "pose": "pet_orange_cat", "label": "小橘猫·到家", "hint": "收养小区那只学会假摔的小橘猫，由 pet_orange_cat 解锁。", "flag": "pet_orange_cat", "bg": "res://assets/backgrounds/community.png" },
    # ── 西湖十景集章大成（集齐 10 枚印章后由 CollectionManager._check_stamp_completion 解锁）──
    { "char": "player", "pose": "west_lake_stamps", "label": "西湖十景·集章大成", "hint": "集齐西湖十景全部印章后解锁。三年，一座湖，十个你亲自走过的地方。", "flag": "west_lake_stamps_complete", "bg": "res://assets/backgrounds/west_lake_stamps_complete.jpg" },
    # ── 西湖风物志·大成（集齐 24 件后由 CollectionManager._check_fengwu_completion 解锁）──
    # ⚠️ 含 6 件「手作」槽：DS-RN-04b 已接通手作渠道，24 件全部可达。
    # ⚠️ 大成 CG 现已专属资源 west_lake_fengwu_complete.jpg（art-director 生成），不再与毕业纪念册共用图。
    { "char": "player", "pose": "west_lake_fengwu", "label": "西湖风物·大成", "hint": "集齐廿四件西湖风物后解锁。一味、一物、一草木、一声景——三年攒下来的杭州。", "flag": "west_lake_fengwu_complete", "bg": "res://assets/backgrounds/west_lake_fengwu_complete.jpg" },
    # ── 社团目标层·成就 CG（DS-RN-05b）──────────────────────────
    # flag 即 flag_club_achievement_<type>，由 club_chain_<type>_s4 终场景 setFlags 落下；
    # DialogueUI L204-207 的 setFlags 分支会同步调 unlock_gallery，无需额外解锁调用。
    # ⚠️ 这 5 个 flag 同时是 NG+ 携带白名单项（EndingScreen.CLUB_ACHIEVEMENT_FLAGS），
    #    二者必须逐字符一致，改名须同步两处。
    # ⚠️ 5 张 bg 图必须在 Godot 编辑器打开工程生成 .import，否则导出包不含该资源。
    { "char": "player", "pose": "grad_club_literature", "label": "社刊《湖畔》·复刊号", "hint": "让停刊三年的社刊重新发到每个班。三十二页，四百本，其中一页是你排的。", "flag": "flag_club_achievement_literature", "bg": "res://assets/backgrounds/grad_club_literature.jpg" },
    { "char": "player", "pose": "grad_club_astronomy",  "label": "流星观测·那一夜的记录", "hint": "守到凌晨的那一场流星雨。记录本最后一行的时间与方位，是你写的。", "flag": "flag_club_achievement_astronomy",  "bg": "res://assets/backgrounds/grad_club_astronomy.jpg" },
    { "char": "player", "pose": "grad_club_broadcast",  "label": "校园之声·最后一次早班", "hint": "三年的晨间播报走到最后一期。念完，把话筒推回原位，红灯灭了。", "flag": "flag_club_achievement_broadcast",  "bg": "res://assets/backgrounds/grad_club_broadcast.jpg" },
    { "char": "player", "pose": "grad_club_basketball", "label": "年级联赛·站到最后一场", "hint": "从报名表上的名字，到决赛终场的哨声。比分不重要了。", "flag": "flag_club_achievement_basketball", "bg": "res://assets/backgrounds/grad_club_basketball.jpg" },
    { "char": "player", "pose": "grad_club_art",        "label": "校庆画展·进门第二幅", "hint": "画挂在进门第二幅。有个低年级的学生在它前面站了很久。", "flag": "flag_club_achievement_art",        "bg": "res://assets/backgrounds/grad_club_art.jpg" },
    # ── 五社通大成（DS-RN-05c）──────────────────────────────────
    # ⚠️ 该条目仅在 EndingScreen 判定「CLUB_ACHIEVEMENT_FLAGS 全集达成」后才会置 flag。
    # ⚠️ 不得被 excludeFlags 引用，不参与链事件逻辑；纯粹为终局荣誉画廊条目。
    { "char": "player", "pose": "grad_club_master",     "label": "【全能王·西湖之夏】", "hint": "有人选择专精，有人选择广博。集齐五社团毕业成就，见证了你的西湖之夏。", "flag": "flag_club_achievement_master",     "bg": "res://assets/backgrounds/grad_club_master.jpg" },
    # ── 学科奥数竞赛大成（学科竞赛模式）──────────────────────────────────
    { "char": "player", "pose": "grad_olympiad",        "label": "【金牌的重量】", "hint": "凭借极其强悍的数理化功底与非人意志，斩落全省奥赛第一名，破格直升名校！", "flag": "flag_olympiad_gold", "bg": "res://assets/backgrounds/grad_olympiad.jpg" },
]

# ── 物品/画廊门面（实现已拆至 CollectionManager）──────────────
# 注意：ITEM_DB / GALLERY_ITEMS / inventory 仍留守本类（外部脚本直接读写）；
# FAVOR_GALLERY_UNLOCKS 及所有逻辑已随系统整体迁入 CollectionManager。
func unlock_gallery(flag_name: String):
    CollectionManager.unlock_gallery(flag_name)

func is_gallery_unlocked(item: Dictionary) -> bool:
    return CollectionManager.is_gallery_unlocked(item)

func get_gallery_progress() -> Dictionary:
    return CollectionManager.get_gallery_progress()

func add_item(item_id: String, amount: int = 1):
    CollectionManager.add_item(item_id, amount)

func remove_item(item_id: String, amount: int = 1):
    CollectionManager.remove_item(item_id, amount)

func has_item(item_id: String, amount: int = 1) -> bool:
    return CollectionManager.has_item(item_id, amount)



# ── 特殊日期（SPECIAL_DATES 常量与检测逻辑已拆至 DailyCycleManager）──

signal state_updated
signal special_date_triggered(label: String, effect: String, banner: String)
signal show_toast(message: String)
signal initiative_updated

func _ready():
    # 游戏启动时补偿扫描：修复已达到阈值但还未解锁画廊 flag 的存量状态
    call_deferred("_retroactive_gallery_check")
    # 关系状态机：启动时静默重算（避免误报升级 toast）
    RelationshipManager.recompute_all_states(true)

func _retroactive_gallery_check():
    CollectionManager._retroactive_gallery_check()

# ── 地点可访问性判断（实现已拆至 LocationManager）─────────────
func get_available_locations() -> Array:
    return LocationManager.get_available_locations()

func _get_slot_id() -> String:
    var slots = ["morning", "noon", "after", "evening"]
    return slots[slot_index] if slot_index < slots.size() else "morning"

# ── 状态修改方法 ─────────────────────────────────────────────
func add_log(text: String):
    var time_str = get_time_label()
    recent_logs.push_front("[%s] %s" % [time_str, text])
    if recent_logs.size() > 20:
        recent_logs.pop_back()
    state_updated.emit()

func add_diary_entry(text: String):
    var grade_info = get_grade_info()
    diary.append({
        "day": day,
        "slot": get_time_label(),
        "grade": grade_info.grade,
        "text": text
    })
    if diary.size() > 50:
        diary.pop_front()

func get_time_label() -> String:
    var labels = ["上午", "中午", "放学后", "晚上"]
    if slot_index < labels.size():
        return labels[slot_index]
    return "未知"

func advance_time(is_addict_skip: bool = false):
    var was_study_slot = studied_this_slot  # 记录刚结束的时段是否学习过
    slot_index += 1
    temp_flags.clear()  # 每个时段开始清除临时标志
    studied_this_slot = false  # 新时段重置学习标记
    if slot_index >= 4:
        slot_index = 0
        day += 1
        day_of_week = ((day - 1) % 7) + 1

        # 长假状态：每日块开头立即更新（必须在 _check_daily_decay 之前，
        # 否则长假首日 current_holiday 仍为空会误触发冷战暂停逻辑）
        DailyCycleManager._update_current_holiday()

        # 每日刷新天气（概率随季节变化）
        WeatherManager._refresh_weather_by_season()
        DailyCycleManager._refresh_char_moods()      # ← 角色心情：每日刷新一次
        DailyCycleManager._check_daily_decay()
        DailyCycleManager._check_special_date()
        DailyCycleManager._check_weekly_allowance()
        DailyCycleManager._check_parttime_income()
        InitiativeManager._check_char_initiative()   # ← 双向奔赴：每日结算角色主动行为
    else:
        var sid = _get_slot_id()
        # 放学后自动布置作业
        if sid == "after" and not is_weekend():
            if hw_status == 0:
                hw_status = 1
                var subjects = ["chinese", "math", "english", "science", "society"]
                current_hw_subject = subjects[randi() % subjects.size()]
                show_toast.emit("📅 课后作业[%s]已经布置，记得回卧室完成。" % SUBJECT_META.get(current_hw_subject, {}).get("label", current_hw_subject))
        elif sid == "evening":
            # 深夜聊天：每晚最多一位符合条件的角色主动发来消息
            InitiativeManager.check_night_chat()
    
    # 网瘾副作用：有概率强制跳过时段（仅在非跳过递归中检测，避免无限循环）
    if not is_addict_skip:
        var addict_val = stats.get("addict", 0)
        if addict_val > 60 and randf() < 0.25:
            show_toast.emit("不知不觉，几个小时就这么过去了……")
            advance_time(true)
            return
    
    # ── 时间即代价：初三期间，非学习时段流逝 → 机会成本提示（每天节流一次）──
    if not is_addict_skip and day >= ExamManager.PRESSURE_START_DAY and not was_study_slot and _oppcost_last_day != day:
        _oppcost_last_day = day
        ExamManager.emit_opportunity_cost_hint()

    # 统一在 advance_time 末尾做一次赛季检测（替代每次 add_stat/add_favor 都检测）
    SeasonManager._run_conditional_checks()
    
    state_updated.emit()

# ── P1: 批量推进算法接口（供长期或未来快速跳过 N 日调用） ──
func advance_days_bulk(days_to_skip: int):
    if days_to_skip <= 0: return
    
    var passed_weeks = (day_of_week - 1 + days_to_skip) / 7
    if passed_weeks > 0:
        var allowance = 100 + int(stats.get("intellect", 0) / 5)
        money += allowance * passed_weeks
        if flags.has("job_cafe") or flags.has("job_library"):
            money += 80 * passed_weeks
            
    day += days_to_skip
    day_of_week = ((day - 1) % 7) + 1
    slot_index = 0
    temp_flags.clear()
    studied_this_slot = false
    
    DailyCycleManager._update_current_holiday()
    WeatherManager._refresh_weather_by_season()
    DailyCycleManager._refresh_char_moods()
    RelationshipManager.recompute_all_states(false)
    
    state_updated.emit()

# ── 每日结算门面（实现已拆至 DailyCycleManager）────────────────
# 注意：DialogueUI 直接调用下列三个方法（跳过整天时手动结算），必须保留门面。
func _check_special_date():
    DailyCycleManager._check_special_date()

func _check_weekly_allowance():
    DailyCycleManager._check_weekly_allowance()

func _check_daily_decay():
    DailyCycleManager._check_daily_decay()

## 内部直接修改 stat 值（不走 add_stat 的 toast，避免副作用）
func stat_name_internal_add(stat_name: String, amount: int):
    if stats.has(stat_name):
        stats[stat_name] = clampi(stats[stat_name] + amount, 0, 100)

const STAT_DISPLAY = {
    "intellect": {"label": "学习", "emoji": "📚"},
    "strength":  {"label": "运动", "emoji": "⚽"},
    "social":    {"label": "社交", "emoji": "💬"},
    "art":       {"label": "艺术", "emoji": "🎨"},
    "charm":     {"label": "魅力", "emoji": "✨"},
    "stress":    {"label": "压力", "emoji": "💢"},
    "addict":    {"label": "网瘾", "emoji": "📱"},
    "money":     {"label": "金钱", "emoji": "💰"},
}

# 好感度剧情锁配置：[角色ID] -> [ { "cap": 阈值好感度, "flag": 阻挡解锁的 flag, "desc": 剧情提示 } ]
const FAVOR_MILESTONES = {
    "yutong": [
        {"cap": 30, "flag": "seen_yutong_shy", "desc": "触发与雨桐的心动对白（解锁 seen_yutong_shy 剧情）"},
        {"cap": 60, "flag": "date_yt_cinema", "desc": "与雨桐完成周末电影院约会（解锁 date_yt_cinema 剧情）"},
        {"cap": 85, "flag": "yt_stress", "desc": "在图书馆开导重压下的雨桐（解锁 yt_stress 剧情）"}
    ],
    "jingjing": [
        {"cap": 30, "flag": "seen_jingjing_shy", "desc": "触发与菁菁的午后羞涩瞬间（解锁 seen_jingjing_shy 剧情）"},
        {"cap": 60, "flag": "date_jj_cinema", "desc": "与菁菁进行周末电影院约会（解锁 date_jj_cinema 剧情）"},
        {"cap": 85, "flag": "jj_stress", "desc": "在小区楼下解开菁菁的心结（解锁 jj_stress 剧情）"}
    ],
    "xiaoxia": [
        {"cap": 30, "flag": "xx_injury", "desc": "在操场上关切受伤的小夏（解锁 xx_injury 剧情）"},
        {"cap": 60, "flag": "xx_sports_day", "desc": "在运动会终点线见证小夏的第一名（解锁 xx_sports_day 剧情）"},
        {"cap": 85, "flag": "xx_lose", "desc": "在班级联赛惨败后默默陪伴小夏（解锁 xx_lose 剧情）"}
    ],
    "wanqing": [
        {"cap": 30, "flag": "wq_book", "desc": "在图书馆与晚晴交流借书心得（解锁 wq_book 剧情）"},
        {"cap": 60, "flag": "wq_publish", "desc": "在教室见证晚晴荣登校刊的名作（解锁 wq_publish 剧情）"},
        {"cap": 85, "flag": "wq_writing", "desc": "在午后图书馆与晚晴探讨创作心声（解锁 wq_writing 剧情）"}
    ],
    "keke": [
        {"cap": 30, "flag": "seen_keke_shy", "desc": "触发与可可的心动对白（解锁 seen_keke_shy 剧情）"},
        {"cap": 60, "flag": "date_kk_amusement", "desc": "与可可完成周末游乐园约会（解锁 date_kk_amusement 剧情）"},
        {"cap": 85, "flag": "kk_stress", "desc": "在小卖部开导重压下的可可（解锁 kk_stress 剧情）"}
    ],
    "beichen": [
        {"cap": 30, "flag": "seen_beichen_shy", "desc": "触发与北辰的心动对白（解锁 seen_beichen_shy 剧情）"},
        {"cap": 60, "flag": "date_bc_cinema", "desc": "与北辰完成周末电影院约会（解锁 date_bc_cinema 剧情）"},
        {"cap": 85, "flag": "bc_stress", "desc": "在校门口开导重压下的北辰（解锁 bc_stress 剧情）"}
    ],
    "zijun": [
        {"cap": 30, "flag": "seen_zijun_shy", "desc": "触发与子珺的心动对白（解锁 seen_zijun_shy 剧情）"},
        {"cap": 60, "flag": "date_zj_artroom", "desc": "与子珺完成画图室约会（解锁 date_zj_artroom 剧情）"},
        {"cap": 85, "flag": "zj_stress", "desc": "在美术教室开导重压下的子珺（解锁 zj_stress 剧情）"}
    ],
    "jingjing_m": [
        {"cap": 30, "flag": "seen_jingjing_m_shy", "desc": "触发与明轩的午后羞涩瞬间（解锁 seen_jingjing_m_shy 剧情）"},
        {"cap": 60, "flag": "date_jjm_cinema", "desc": "与明轩进行周末电影院约会（解锁 date_jjm_cinema 剧情）"},
        {"cap": 85, "flag": "jjm_stress", "desc": "在小区楼下解开明轩的心结（解锁 jjm_stress 剧情）"}
    ]
}

# ── 有效属性（基础值 + 当前穿搭加成）────────────────────────
func get_effective_stat(stat_name: String) -> int:
    var base = stats.get(stat_name, 0)
    return base + WardrobeManager.get_active_bonus().get(stat_name, 0)

func add_favor(char_id: String, amount: int):
    if favorability.has(char_id):
        # ── 关系状态机：冷战期间增益封锁（仅封锁正向，惩罚仍生效）──
        if flags.has("rel_cold_" + char_id) and amount > 0:
            var cold_name = char_meta.get(char_id, {}).get("name", char_id)
            show_toast.emit("💔 现在不是增进感情的时候……（你和%s正处于冷战）" % cold_name)
            return

        var final_amount = amount
        var current_fav = favorability[char_id]
        
        # 1. 阶段性好感度边际效益递减
        if amount > 0:
            var multiplier = 0.35
            # 穿搭地点好感加成
            if current_location != "":
                var wardrobe_pct = WardrobeManager.get_fav_bonus_for_loc(current_location)
                if wardrobe_pct > 0.0:
                    multiplier += wardrobe_pct
            if current_fav >= 85:
                multiplier = 0.08
            elif current_fav >= 60:
                multiplier = 0.12
            elif current_fav >= 30:
                multiplier = 0.22

            # ── 角色心情加成：开心×1.2，不好×0.7 ──
            var mood_mult = DailyCycleManager.get_char_mood_display(char_id).get("favor_mult", 1.0)
            multiplier *= mood_mult

            # ── B1 同日重复互动衰减 ──
            var last_interact_day = flags.get("favor_interacted_day_" + char_id, -1)
            if last_interact_day == day:
                multiplier *= 0.5
            else:
                flags["favor_interacted_day_" + char_id] = day

            # ── 大吉日运势加成：★★★★★ 时好感获取×1.2 ──
            var fortune = WeatherManager.get_daily_fortune()
            if fortune == 5:
                multiplier *= 1.2
            
            final_amount = int(amount * multiplier)
            if final_amount <= 0 and amount > 0:
                final_amount = 1
        
        # 2. 剧情里程碑瓶颈锁检测（若未触发关键剧情，好感度将被锁定在 30/60/85 处）
        var target_fav = favorability[char_id] + final_amount
        var lock_cap = 100
        var lock_desc = ""
        
        if FAVOR_MILESTONES.has(char_id):
            for milestone in FAVOR_MILESTONES[char_id]:
                var cap = milestone["cap"]
                var required_flag = milestone["flag"]
                # 如果当前好感还没突破该上限，且加完后想要突破，但还没解锁对应剧情标志，则执行瓶颈锁定
                if current_fav <= cap and target_fav > cap:
                    if not flags.has(required_flag):
                        lock_cap = cap
                        lock_desc = milestone["desc"]
                        break
        
        var prev_fav = favorability[char_id]
        favorability[char_id] = clampi(target_fav, 0, lock_cap)
        state_updated.emit()
        
        # 3. 好感度阈值到达时，自动解锁对应画廊 flag
        CollectionManager._check_favor_gallery_unlocks(char_id, prev_fav, favorability[char_id])

        # 4. 关系状态机：好感变动后重算该角色状态（升级提示由 Manager 内部处理）
        RelationshipManager.recompute_rel_state(char_id)
        
        # 4. 弹出精致且直观的好感度变动提示
        var actual_diff = favorability[char_id] - prev_fav
        var char_name = char_meta.get(char_id, {}).get("name", char_id)
        var char_emoji = char_meta.get(char_id, {}).get("emoji", "❤️")
        
        if actual_diff > 0:
            var sign = "+"
            show_toast.emit("%s %s 好感度 %s%d" % [char_emoji, char_name, sign, actual_diff])
            
            # 如果刚好顶到了剧情瓶颈锁，发出提示引导玩家
            if favorability[char_id] == lock_cap and target_fav > lock_cap:
                show_toast.emit("🔒 关系遭遇瓶颈！需触发主线：%s" % lock_desc)
        elif actual_diff < 0:
            show_toast.emit("%s %s 好感度 %d" % [char_emoji, char_name, actual_diff])

# 好感度阈值自动解锁画廊（FAVOR_GALLERY_UNLOCKS + _check_favor_gallery_unlocks）
# 实现已迁入 CollectionManager；add_favor 内部经 CollectionManager 调用。

func add_stat(stat_name: String, amount: int):
    if stat_name == "money":
        money += amount
        state_updated.emit()
        if amount != 0:
            var sign = "+" if amount > 0 else ""
            show_toast.emit("💰 金钱 %s%d" % [sign, amount])
        return

    if stats.has(stat_name):
        var prev_val = stats[stat_name]
        stats[stat_name] = clampi(stats[stat_name] + amount, 0, 100)
        state_updated.emit()
        
        # ── 赛季学习进度（仅记录进度计数，条件检测统一在 advance_time 末尾执行）──
        if stat_name == "intellect" and amount > 0:
            SeasonManager.add_progress("action_study", 1)
            studied_this_slot = true  # 智力增长即视为本时段学习过（时间即代价）
        
        # 联网版：智力属性变动后，自动上报最新值至服务器排行榜
        if stat_name == "intellect" and stats[stat_name] > prev_val:
            NetworkManager.submit_score(stats[stat_name])
        
        # 弹出精美的属性增减提示
        if amount != 0:
            var sign = "+" if amount > 0 else ""
            var info = STAT_DISPLAY.get(stat_name, {"label": stat_name, "emoji": "✨"})
            show_toast.emit("%s %s %s%d" % [info.emoji, info.label, sign, amount])

func get_stat(stat_name: String) -> int:
    return stats.get(stat_name, 0)

## 每日运势门面（实现已拆至 WeatherManager）
func get_daily_fortune() -> int:
    return WeatherManager.get_daily_fortune()

## 返回当前角色好感瓶颈中最高优先级的那一条（供 Dashboard 待办区显示）
## 格式：{ char_id, char_name, cap, desc } 或空字典
func get_active_bottleneck() -> Dictionary:
    for char_id in FAVOR_MILESTONES.keys():
        var cur = favorability.get(char_id, 0)
        for milestone in FAVOR_MILESTONES[char_id]:
            if cur >= milestone["cap"] - 10 and cur <= milestone["cap"]:
                if not flags.has(milestone["flag"]):
                    var meta = char_meta.get(char_id, {})
                    return {
                        "char_id":   char_id,
                        "char_name": meta.get("name", char_id),
                        "char_emoji": meta.get("emoji", "❤️"),
                        "cap":        milestone["cap"],
                        "desc":       milestone["desc"]
                    }
    return {}

func set_flag(flag_name: String, value: Variant):
    if value is bool:
        if value:
            flags[flag_name] = true
        else:
            flags.erase(flag_name)
    else:
        flags[flag_name] = value

func has_flag(flag_name: String) -> bool:
    return flags.has(flag_name)

func set_temp_flag(flag_name: String):
    temp_flags[flag_name] = true

func has_temp_flag(flag_name: String) -> bool:
    return temp_flags.has(flag_name)

func set_hw_status(status: int):
    hw_status = status
    if status == 0:   # 修复：原逻辑 status > 0 且 status == 0 相互矛盾，永远不会清零
        hw_neglect_count = 0

func reset_hw_status(reset_neglect: bool = false):
    hw_status = 0
    current_hw_subject = ""
    if reset_neglect:
        hw_neglect_count = 0

# ═══════════════════════════════════════════════════════════════
# ── 中考与志愿系统门面（实现已拆至 ExamManager）─────────────────
# ═══════════════════════════════════════════════════════════════
# 注意：subject_scores / SUBJECT_META / target_high_school /
# latest_exam_result 等共享状态仍保留在本类（SaveSystem / EndingScreen /
# MainGame / ScoreRevealUI 等外部脚本直接读写）；HIGH_SCHOOLS 已随逻辑
# 迁入 ExamManager。

var target_high_school = "" # 玩家填报的志愿
var latest_exam_result = {} # 最近一次考试成绩

func calculate_exam_score(is_mock: bool = false) -> Dictionary:
    return ExamManager.calculate_exam_score(is_mock)

func set_target_high_school(school_id: String):
    ExamManager.set_target_high_school(school_id)

func get_admission_result() -> Dictionary:
    return ExamManager.get_admission_result()

## 时间即代价：预估中考总分 / 距目标高中差距（供 HUD 或提示读取）
func project_exam_score() -> int:
    return ExamManager.project_exam_score()

func get_target_gap() -> Dictionary:
    return ExamManager.get_target_gap()



# ═══════════════════════════════════════════════════════════════
# ── 双向奔赴系统门面（实现已拆至 InitiativeManager）─────────────
# ═══════════════════════════════════════════════════════════════

func get_pending_invites() -> Array:
    return InitiativeManager.get_pending_invites()

func get_pending_wechat_msgs() -> Array:
    return InitiativeManager.get_pending_wechat_msgs()

func accept_invite(char_id: String) -> String:
    return InitiativeManager.accept_invite(char_id)

func decline_invite(char_id: String):
    InitiativeManager.decline_invite(char_id)

func consume_wechat_msg(char_id: String):
    InitiativeManager.consume_wechat_msg(char_id)

func get_chars_at_location(loc_id: String) -> Array:
    return InitiativeManager.get_chars_at_location(loc_id)

func get_initiative_save_data() -> Dictionary:
    return InitiativeManager.get_initiative_save_data()

func load_initiative_save_data(data: Dictionary):
    InitiativeManager.load_initiative_save_data(data)

func reset_char_initiative():
    InitiativeManager.reset_char_initiative()
