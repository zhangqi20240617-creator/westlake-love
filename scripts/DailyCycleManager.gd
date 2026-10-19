extends Node

# ═══════════════════════════════════════════════════════════════
# ── DailyCycleManager ─────────────────────────────────────────
# 每日结算系统：特殊日期 / 角色心情 / 冷落与沉迷衰减 / 零花钱 / 作业后果链
# 实现从 GameManager 抽出（门面委托，对外 API 不变）
# 共享状态（char_mood / hw_status / hw_neglect_count / flags / favorability
#  / stats / money / day / day_of_week）留守 GameManager，本类经 GameManager.xxx 访问
# ═══════════════════════════════════════════════════════════════

# ── 特殊日期 ─────────────────────────────────────────────────
const SPECIAL_DATES = {
    1:   {"label": "🏫 初一开学第一天",  "effect": "opening",     "banner": "opening_day1"},
    14:  {"label": "🏃 军训结束！联欢晚会", "effect": "training_end", "banner": "training_end_ceremony"},
    30:  {"label": "🎉 元旦快乐！",     "effect": "festival",   "banner": "new_year"},
    31:  {"label": "元旦假期",          "effect": "free_day"},
    15:  {"label": "班干部竞选",        "effect": "class_election"},
    60:  {"label": "期末考试",          "effect": "exam"},
    90:  {"label": "寒假开始",          "effect": "break"},
    150: {"label": "🌱 春假开始",   "effect": "break"},
    120: {"label": "🎋 端午节到了！",   "effect": "festival",   "banner": "dragon_boat"},
    180: {"label": "期中考试",          "effect": "exam"},
    210: {"label": "第二次月考", "effect": "exam"},
    240: {"label": "🎪 文化节开幕！", "effect": "special", "banner": "文化节来了，去教室或校门口看看吧！"},
    270: {"label": "暑假开始",          "effect": "break"},
    304: {"label": "🍂 秋假开始",   "effect": "break"},
    310: {"label": "🥮 中秋佳节！",     "effect": "festival",   "banner": "mid_autumn"},
    330: {"label": "💌 白色情人节", "effect": "special", "banner": "今天是白色情人节……有什么人想见吗？"},
    360: {"label": "一模", "effect": "exam"},
    500: {"label": "中考体测",          "effect": "exam_sport"},
    540: {"label": "中考倒计时30天",    "effect": "pressure"},
    569: {"label": "🌙 毕业前夜",       "effect": "special",    "banner": "最后一个夜晚，去西湖边吧。"},
    570: {"label": "🎓 初三毕业典礼",  "effect": "ending"},
    10:  {"label": "📚 教师节",     "effect": "festival", "banner": "teacher_day"},
    110: {"label": "第一次月考", "effect": "exam"},
    480: {"label": "二模",         "effect": "exam"},
    95:  {"label": "🧧 春节", "effect": "festival", "banner": "spring_festival"},
    
    45:  {"label": "🏃‍♂️ 秋季校运会", "effect": "sports_meet", "banner": "一年一度的秋季长跑开赛了！"},
    225: {"label": "🏃‍♂️ 春季校运会", "effect": "sports_meet", "banner": "春风十里，奔跑吧少年！"},
    410: {"label": "🏃‍♂️ 初三绝杀校运会", "effect": "sports_meet", "banner": "初中生涯最后一次校运会！"},

    # ── 生日系统 ─────────────────────────────────────────────────
    43:  {"label": "🎂 今天是你的生日！", "effect": "birthday_player", "banner": ""},
    55:  {"label": "🎂 陈雨桐的生日",  "effect": "birthday_char", "banner": "yutong"},
    75:  {"label": "🎂 沈逸飞的生日",  "effect": "birthday_char", "banner": "yifei"},
    130: {"label": "🎂 叶菁菁的生日",  "effect": "birthday_char", "banner": "jingjing"},
    200: {"label": "🎂 苏晚晴的生日",  "effect": "birthday_char", "banner": "wanqing"},
    250: {"label": "🎂 林小夏的生日",  "effect": "birthday_char", "banner": "xiaoxia"},
    320: {"label": "🎂 方可可的生日",  "effect": "birthday_char", "banner": "keke"},

    # ── 节日节气补全（P1）────────────────────────────────────────
    170: {"label": "🎈 六一儿童节！",   "effect": "festival", "banner": "childrenday"},
    260: {"label": "🏫 西湖中学校庆",   "effect": "festival", "banner": "school_anniversary"},
    490: {"label": "🎄 圣诞节到了！",   "effect": "festival", "banner": "christmas"},

    # ── 毕业仪式感（P1）─────────────────────────────────────────
    563: {"label": "📚 初中最后一课",   "effect": "special", "banner": "grad_last_class"},
    564: {"label": "📸 拍毕业照",        "effect": "special", "banner": "grad_class_photo"},
    565: {"label": "📖 写同学录",        "effect": "special", "banner": "grad_yearbook"},
    567: {"label": "🍻 散伙饭",          "effect": "special", "banner": "grad_farewell_dinner"},
    568: {"label": "🌊 三年回望",        "effect": "special", "banner": "grad_three_year_montage"},
}

# ── 长假区间（寒假/春假/暑假/秋假）────────────────────────────
const BREAK_PERIODS = {
    "training": [2, 14],
    "winter":  [90, 100],
    "spring":  [150, 155],
    "summer":  [270, 300],
    "autumn":  [303, 309],
}

## 根据 GameManager.day 计算当前所处长假类型（否则 ""）
func _update_current_holiday():
    var cur: String = ""
    for hol_type in BREAK_PERIODS.keys():
        var rng: Array = BREAK_PERIODS[hol_type]
        if GameManager.day >= int(rng[0]) and GameManager.day <= int(rng[1]):
            cur = hol_type
            break
    GameManager.current_holiday = cur

# ── 角色心情状态系统 ──────────────────────────────────────────
const MOOD_DISPLAY: Dictionary = {
    "happy":  {"emoji": "😊", "label": "开心",    "favor_mult": 1.2},
    "normal": {"emoji": "😐", "label": "普通",    "favor_mult": 1.0},
    "upset":  {"emoji": "😟", "label": "不好意思", "favor_mult": 0.7},
}

## 基于日期 + 角色名哈希的伪随机，同一天同一角色心情固定
func _refresh_char_moods():
    for char_id in GameManager.favorability.keys():
        var meta = GameManager.char_meta.get(char_id, {})
        if GameManager.day < meta.get("unlockDay", 1): continue
        var c_hash = 0
        for c in char_id: c_hash = (c_hash * 31 + c.unicode_at(0)) & 0xFFFF
        var raw = (GameManager.day * 1009 + c_hash * 37) % 10
        GameManager.char_mood[char_id] = "happy" if raw < 3 else ("upset" if raw >= 8 else "normal")

func get_char_mood(char_id: String) -> String:
    return GameManager.char_mood.get(char_id, "normal")

func get_char_mood_display(char_id: String) -> Dictionary:
    return MOOD_DISPLAY.get(get_char_mood(char_id), MOOD_DISPLAY["normal"])

# ── 特殊日期检测 ──────────────────────────────────────────────
func _check_special_date():
    if not SPECIAL_DATES.has(GameManager.day):
        return
    var sp = SPECIAL_DATES[GameManager.day]
    GameManager.special_date_triggered.emit(
        sp.get("label", ""),
        sp.get("effect", ""),
        sp.get("banner", "")
    )
    # ── 白色情人节（day 330）：好感≥60的角色强制推送今日邀请 ──
    if GameManager.day == 330:
        InitiativeManager._push_valentines_invites()
    # ── 玩家生日（day 43）：好感≥40的角色发来祝福toast；全角色当日好感加成×1.5 ──
    if GameManager.day == 43:
        GameManager.flags["birthday_boost_day"] = 43  # 供 add_favor 读取乘数
        for cid in GameManager.char_meta.keys():
            var meta = GameManager.char_meta.get(cid, {})
            if GameManager.day < meta.get("unlockDay", 1): continue
            var fav = GameManager.favorability.get(cid, 0)
            if fav >= 40:
                var char_name = meta.get("name", cid)
                var char_emoji = meta.get("emoji", "🎂")
                GameManager.show_toast.emit("%s %s：生日快乐！" % [char_emoji, char_name])
    # ── 角色生日（birthday_char）：toast + 好感≥40则自动推送邀请 ──
    if sp.get("effect", "") == "birthday_char":
        var char_id = sp.get("banner", "")
        if char_id != "" and GameManager.char_meta.has(char_id):
            var fav = GameManager.favorability.get(char_id, 0)
            if fav >= 40:
                var state = InitiativeManager.char_initiative.get(char_id, {})
                if state.get("pending_invite", "") == "":
                    InitiativeManager.char_initiative[char_id]["pending_invite"] = "community"
                    InitiativeManager.char_initiative[char_id]["invite_slot"] = GameManager.slot_index
                    InitiativeManager.char_initiative[char_id]["invite_day"] = GameManager.day
                    GameManager.initiative_updated.emit()

# ── 每周零花钱 ────────────────────────────────────────────────
func _check_weekly_allowance():
    # 每周一发放零花钱
    if GameManager.day_of_week == 1:
        var allowance = 100 + int(GameManager.stats.get("intellect", 0) / 5)
        GameManager.money += allowance
        GameManager.show_toast.emit("📅 周一发放零花钱：💰%d" % allowance)
        # 社团系统（club_system_gdd §3.1 / E10）：场景 setFlag 只能置真、无法清除，
        # 故「每周可再参加一次」由本周一钩子擦除标记实现。仅动 club_ 命名空间，
        # 对既有 66+ 事件零影响；零新增 Autoload、零新调度器。
        GameManager.flags.erase("flag_club_week_done")

# ── 兼职周末周薪 ──────────────────────────────────────────────
func _check_parttime_income():
    # 已获得兼职 flag 且当前为周末时，发放兼职周薪（< 每周 allowance，防失衡）
    if GameManager.flags.has("flag_has_parttime_job") and GameManager.is_weekend():
        GameManager.money += 80
        GameManager.add_stat("stress", 2)
        GameManager.show_toast.emit("💼 兼职周薪到账：💰80")

# ── 每日衰减结算 ──────────────────────────────────────────────
func _check_daily_decay():
    var addict_val = GameManager.stats.get("addict", 0)
    var stress_val = GameManager.stats.get("stress", 0)

    # 1. 冷落惩罚：14天未互动好感-1
    for char_id in GameManager.favorability.keys():
        var meta = GameManager.char_meta.get(char_id, {})
        var unlock_day = meta.get("unlockDay", 1)
        if GameManager.day >= unlock_day and GameManager.favorability[char_id] > 5:
            var last_day = GameManager.flags.get("last_interact_" + char_id, unlock_day)
            if last_day is int and GameManager.day - last_day >= 14:
                GameManager.favorability[char_id] = clampi(GameManager.favorability[char_id] - 1, 0, 100)
                if GameManager.day - last_day == 14:
                    var char_name = meta.get("name", char_id)
                    GameManager.show_toast.emit("💔 很久没和 %s 说话了，关系似乎变得生疏了..." % char_name)

    # 2. 沉迷/压力 全局好感惩罚
    var glob_decay = 0
    var reason = ""
    if addict_val > 80 and randf() < 0.4:
        glob_decay = 2
        reason = "过度沉迷虚拟世界，现实中的朋友觉得你很难接近..."
    elif addict_val > 60 and randf() < 0.2:
        glob_decay = 1
        reason = "状态浑浑唠唠，无意中冷落了周围的人..."
    if stress_val > 90 and randf() < 0.3:
        glob_decay = max(glob_decay, 2)
        reason = "压力太大导致脂气暴躁，身边的人对你有些失望..."
    if glob_decay > 0:
        for char_id in GameManager.favorability.keys():
            var meta = GameManager.char_meta.get(char_id, {})
            var unlock_day = meta.get("unlockDay", 1)
            if GameManager.day >= unlock_day and GameManager.favorability[char_id] > 5:
                GameManager.favorability[char_id] = clampi(GameManager.favorability[char_id] - glob_decay, 0, 100)
        GameManager.show_toast.emit("💔 " + reason)

    # 3. 作业后果链：连续3次未交 → 触发叫家长事件
    _check_hw_neglect_consequence()

    # 4. 重度冷落冷战检测：处于暧昧/心动 且 连续 21 天未互动 → 进入冷战
    #    （仅对玩家真正互动过的角色生效，避免从未对话角色误触发）
    #    长假期间暂停检测：current_holiday 非空时跳过（design §5；advance_time 已提前置位）
    if GameManager.current_holiday == "":
        for char_id in GameManager.favorability.keys():
            var st = RelationshipManager.get_rel_state(char_id)
            if st == "close" or st == "crush":
                if GameManager.flags.has("last_interact_" + char_id):
                    var last_day = GameManager.flags.get("last_interact_" + char_id, 1)
                    if last_day is int and GameManager.day - last_day >= 21:
                        if not GameManager.flags.has("rel_cold_" + char_id):
                            RelationshipManager.enter_cold_war(char_id)

    # 5. 好感变动后统一重算所有角色关系状态
    RelationshipManager.recompute_all_states(false)
    
    # 教务体系：违纪值的每日自然消除
    if GameManager.stats.get("dean_suspicion", 0) > 0:
        GameManager.stat_name_internal_add("dean_suspicion", -1)
    
    # 班干部特权收益：班长额外降查房率和压力，体委加魅力，学委加智力
    if GameManager.flags.has("role_monitor"):
        GameManager.stat_name_internal_add("stress", -2)
        if GameManager.stats.get("dean_suspicion", 0) > 0:
            GameManager.stat_name_internal_add("dean_suspicion", -1)
    if GameManager.flags.has("role_pe"):
        GameManager.stat_name_internal_add("charm", 1)
    if GameManager.flags.has("role_study"):
        GameManager.stat_name_internal_add("intellect", 1)

    # ── 假期倒计时提醒：结束前3天给 toast ──────────────────────────
    var cur_hol = GameManager.current_holiday
    if cur_hol != "":
        var rng = BREAK_PERIODS.get(cur_hol, [])
        if rng.size() == 2:
            var days_left = int(rng[1]) - GameManager.day
            if days_left >= 1 and days_left <= 3:
                GameManager.show_toast.emit("📅 假期还剩 %d 天，准备开学了！" % days_left)

func _check_hw_neglect_consequence():
    # hw_status == 1 表示当天有作业但未完成（每天结束时若仍为1则记一次拖欠）
    if GameManager.hw_status == 1 and not GameManager.is_weekend():
        GameManager.hw_neglect_count += 1
        if GameManager.hw_neglect_count == 3:
            # 第3次：老师叫家长，触发全局惩罚
            GameManager.show_toast.emit("😨 已连续3次未交作业！老师打电话叫了家长……")
            GameManager.show_toast.emit("💔 家长批评了你，压力剧增，教导主任盯上了你！")
            GameManager.stat_name_internal_add("stress", 20)
            GameManager.stat_name_internal_add("dean_suspicion", 30)
            for char_id in GameManager.favorability.keys():
                if GameManager.favorability[char_id] > 5:
                    GameManager.favorability[char_id] = clampi(GameManager.favorability[char_id] - 2, 0, 100)
            GameManager.hw_neglect_count = 0
        elif GameManager.hw_neglect_count >= 1:
            GameManager.show_toast.emit("📋 作业又没交……（第%d次）" % GameManager.hw_neglect_count)
        # hw_status 保持 1，让第二天的 classroom_homework_check 看到 hw_missing
    else:
        # 当天完成（status 2/3）或无作业（0）：
        # hw_status 保留到第二天早上，让 classroom_homework_check 自行处理：
        #   hw==2 → hw_good 场景（表扬 + 社交+1 学习+1）→ resetHwStatus 归零
        #   hw==3 → hw_sloppy 场景（轻批）→ resetHwStatus 归零
        # 只清 neglect_count，不动 hw_status
        if GameManager.hw_status == 2:
            GameManager.hw_neglect_count = 0
