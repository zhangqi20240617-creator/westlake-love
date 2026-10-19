import json
import os

achievements_path = "d:/zkgame/scripts/achievements.json"

with open(achievements_path, "r", encoding="utf-8") as f:
    existing = json.load(f)

existing_ids = {a["id"] for a in existing}

# New unexpected easter-egg achievements
new_achievements = [
    # ── 🎭 天地万象（意想不到的奇葩/失败/彩蛋?──
    {
        "id": "curio_extreme_skew",
        "category": "curiosities",
        "name": "偏科之神",
        "desc": "单门科目考到90分以上，但另一门学科不?5分！“偏科偏到教导主任都头疼”?,
        "icon": "📐",
        "points": 20,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_extreme_skew"
    },
    {
        "id": "curio_stress_99",
        "category": "curiosities",
        "name": "心跳的临界点",
        "desc": "压力值达?8点以上（仅差2点崩溃），依然咬牙撑过了一整天?,
        "icon": "?,
        "points": 20,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_stress_99"
    },
    {
        "id": "curio_penniless",
        "category": "curiosities",
        "name": "钱包比脸还干净",
        "desc": "手中零花钱恰好花光到 0 元整！“只要心态好，空气也是甜的”?,
        "icon": "🪙",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_penniless"
    },
    {
        "id": "curio_caffeine_rush",
        "category": "curiosities",
        "name": "咖啡因过?,
        "desc": "累计购买或品尝奶茶与龙井茶达?5 次。“今晚的自习注定无法入睡”?,
        "icon": "🍵",
        "points": 15,
        "hidden": True,
        "condition_type": "counter",
        "condition_key": "tea_drink_count",
        "condition_target": 5
    },
    {
        "id": "curio_claw_slip",
        "category": "curiosities",
        "name": "就差一厘米?,
        "desc": "娃娃机抓取时，玩偶在距离出货口仅一步之遥处晃动滑落…?,
        "icon": "😱",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_claw_slip"
    },
    {
        "id": "curio_coin_vacuum",
        "category": "curiosities",
        "name": "娃娃机吞币狂?,
        "desc": "连续投币抓娃娃失?5 次，但依然相信下一把必出货?,
        "icon": "🕹?,
        "points": 20,
        "hidden": True,
        "condition_type": "counter",
        "condition_key": "claw_fail_count",
        "condition_target": 5
    },
    {
        "id": "curio_shaker_overkill",
        "category": "curiosities",
        "name": "无情摇杯机器",
        "desc": "奶茶调制时以超高频率连续点击摇晃雪克杯，体魄加成瞬间爆表?,
        "icon": "🌪?,
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_shaker_overkill"
    },
    {
        "id": "curio_paper_corridor",
        "category": "curiosities",
        "name": "同学，你纸条掉了",
        "desc": "课堂传纸条力度太小，纸条尴尬地停在过道正中间被全班围观…?,
        "icon": "📜",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_paper_slip_corridor"
    },
    {
        "id": "curio_badminton_stuck",
        "category": "curiosities",
        "name": "羽毛球上树了?,
        "desc": "操场打羽毛球时挥拍用力过猛直接打出界外！",
        "icon": "🏸",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_badminton_stuck"
    },
    {
        "id": "curio_slacking_scholar",
        "category": "curiosities",
        "name": "学神也摸?,
        "desc": "智力达到 80 点以上时，在课堂上成功传出一张小纸条?,
        "icon": "🕶?,
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_slacking_scholar"
    },
    {
        "id": "curio_cat_mafia",
        "category": "curiosities",
        "name": "被碰瓷团伙盯?,
        "desc": "累计喂食或探望小区假摔橘猫达?8 次，成为小区猫帮编外人员?,
        "icon": "🐾",
        "points": 20,
        "hidden": True,
        "condition_type": "counter",
        "condition_key": "cat_pet_count",
        "condition_target": 8
    },
    {
        "id": "curio_duty_master",
        "category": "curiosities",
        "name": "劳动委员狂喜",
        "desc": "周五放学后留堂完成大扫除值日，黑板擦得光可鉴人?,
        "icon": "🧹",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_duty_cleaning"
    },
    {
        "id": "curio_dean_caught",
        "category": "curiosities",
        "name": "教导主任的凝?,
        "desc": "进宿舍时遭遇教导主任突击检查，所幸平安无事?,
        "icon": "👀",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_dean_caught"
    },
    {
        "id": "curio_double_scholar",
        "category": "curiosities",
        "name": "文理双状?,
        "desc": "语文与数学两门分科复习成绩同时突?90 分！",
        "icon": "📜",
        "points": 25,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_double_scholar"
    },
    {
        "id": "curio_trio_jealousy",
        "category": "curiosities",
        "name": "端水大师的日?,
        "desc": "同时与三位同窗的好感度维持在 50 点以上！",
        "icon": "⚖️",
        "points": 25,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_trio_jealousy"
    },
    {
        "id": "curio_vacation_study",
        "category": "curiosities",
        "name": "初三哪有假！",
        "desc": "在寒暑长假期间依旧坚持在书桌前做作业温习功课?,
        "icon": "📖",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_vacation_study"
    },
    {
        "id": "curio_fish_disaster",
        "category": "curiosities",
        "name": "传说中的黑暗料理",
        "desc": "做西湖醋溜鱼时火候失控做出酸掉牙的低品质成品…?,
        "icon": "🍲",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_fish_too_sour"
    },
    {
        "id": "curio_bridge_not_broken",
        "category": "curiosities",
        "name": "断桥真的不断啊！",
        "desc": "初次在断桥打卡时发出由衷的感慨——原来白堤的断桥是一座完整的石拱桥！",
        "icon": "🌉",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_bridge_not_broken"
    },
    {
        "id": "curio_wish_diver",
        "category": "curiosities",
        "name": "西湖水底?,
        "desc": "在许愿树湖畔累计打捞?5 盏来自其他同学的心愿花灯?,
        "icon": "🏮",
        "points": 20,
        "hidden": True,
        "condition_type": "counter",
        "condition_key": "wishes_fetched_count",
        "condition_target": 5
    },

    # ── 🏞?人间西湖（深入杭州风物与民俗）──
    {
        "id": "hz_fengwu_tuopian",
        "category": "hangzhou",
        "name": "偷走岁月一层皮",
        "desc": "亲手完成手作风物「西湖碑文拓片」。墨香渗进宣纸，把千年石碑纹理带回了家?,
        "icon": "📜",
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "fengwu_fw_hm_tuopian"
    },
    {
        "id": "hz_fengwu_zhuze",
        "category": "hangzhou",
        "name": "青竹留香",
        "desc": "亲手制作手作风物「竹编茶则」。手指被划红了，但茶则泛出清雅的光泽?,
        "icon": "🎋",
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "fengwu_fw_hm_zhuze"
    },
    {
        "id": "hz_fw_fan_umbrella",
        "category": "hangzhou",
        "name": "江南烟雨?,
        "desc": "背包中同时收藏有王星记黑纸扇与西湖绸伞两件非遗老字号风物?,
        "icon": "🌂",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_fan_and_umbrella"
    },
    {
        "id": "hz_cook_osmanthus",
        "category": "hangzhou",
        "name": "满城尽带桂花?,
        "desc": "成功烹饪出一盒晶莹软糯、桂香满室的杭州传统糕点「桂花糕」?,
        "icon": "🍡",
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_cooked_osmanthus"
    },
    {
        "id": "hz_cook_fish_good",
        "category": "hangzhou",
        "name": "名动钱塘",
        "desc": "成功烹饪出一道酸甜适口、肉质弹嫩的完美品质「西湖醋溜鱼」?,
        "icon": "🐟",
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_cooked_fish_good"
    },
    {
        "id": "hz_lakeside_v1",
        "category": "hangzhou",
        "name": "西湖常客",
        "desc": "累计前往西湖湖畔散步漫游 5 次。湖风把所有复习的烦恼吹向波心?,
        "icon": "🚶",
        "points": 10,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "visit_lakeside_count",
        "condition_target": 5
    },
    {
        "id": "hz_lakeside_v3",
        "category": "hangzhou",
        "name": "西湖长住?,
        "desc": "累计前往西湖湖畔漫步达到 20 次。断桥的每一块石砖你都如数家珍?,
        "icon": "🚴",
        "points": 25,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "visit_lakeside_count",
        "condition_target": 20
    },
    {
        "id": "hz_market_shopper",
        "category": "hangzhou",
        "name": "清河坊老饕",
        "desc": "在清河坊集市累计购买食材与特产达?10 次?,
        "icon": "🛒",
        "points": 15,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "market_buy_count",
        "condition_target": 10
    },

    # ── 📘 学海无涯（题海与学科冲刺）──
    {
        "id": "acad_quiz_streak_100",
        "category": "academics",
        "name": "中考题库破壁人",
        "desc": "在中考速写刷题中累计答?100 道题目！书山有路，勤为舟楫?,
        "icon": "🏆",
        "points": 30,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "quiz_correct_count",
        "condition_target": 100
    },
    {
        "id": "acad_combo_8",
        "category": "academics",
        "name": "考场超频状?,
        "desc": "在刷题练习中实现连续 8 道题目无失误全对? Combo）！",
        "icon": "🔥",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_quiz_combo_8"
    },
    {
        "id": "acad_math_100",
        "category": "academics",
        "name": "几何与代数的交响",
        "desc": "数学分科复习成绩达到 100 满分！辅助线宛如天成?,
        "icon": "📐",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_math_100"
    },
    {
        "id": "acad_chinese_100",
        "category": "academics",
        "name": "下笔如有?,
        "desc": "语文分科复习成绩达到 100 满分！古文默写与作文立意无可挑剔?,
        "icon": "✒️",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_chinese_100"
    },
    {
        "id": "acad_english_100",
        "category": "academics",
        "name": "无障碍视?,
        "desc": "英语分科复习成绩达到 100 满分！听力与阅读毫无死角?,
        "icon": "🌍",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_english_100"
    },
    {
        "id": "acad_science_100",
        "category": "academics",
        "name": "真理的探求?,
        "desc": "科学分科复习成绩达到 100 满分！物理化学生物全线拉满?,
        "icon": "🔬",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_science_100"
    },
    {
        "id": "acad_all_subjects_80",
        "category": "academics",
        "name": "重高稳拿?,
        "desc": "中考全部六门学科复习评分均突破 80 分以上，前三所志愿信手拈来?,
        "icon": "🏛?,
        "points": 35,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_subjects_all_80"
    },
    {
        "id": "acad_library_5",
        "category": "academics",
        "name": "静水深流",
        "desc": "累计在学校图书馆专注自习达到 5 次，书页泛黄的油墨最抚人心?,
        "icon": "📚",
        "points": 15,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "library_study_count",
        "condition_target": 5
    },

    # ── 🌸 青春羁绊（专属立绘与深层心动）──
    {
        "id": "soc_yutong_study",
        "category": "social",
        "name": "同桌的笔?,
        "desc": "在图书馆看见认真整理错题的陈雨桐，解锁「陈雨桐·自习」立绘?,
        "icon": "📝",
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "seen_yutong_study"
    },
    {
        "id": "soc_jingjing_shy",
        "category": "social",
        "name": "悄悄泛红的耳尖",
        "desc": "在老校门口看见不好意思别过头的叶菁菁，解锁「叶菁菁·羞涩」立绘?,
        "icon": "🌸",
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "seen_jingjing_shy"
    },
    {
        "id": "soc_yifei_serious",
        "category": "social",
        "name": "琴房里的专注",
        "desc": "沈逸飞好感度达?60，解锁「沈逸飞·认真」专属立绘?,
        "icon": "🎻",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "seen_yifei_serious"
    },
    {
        "id": "soc_zicheng_serious",
        "category": "social",
        "name": "最后一防的决心",
        "desc": "周子诚好感度达到 60，解锁「周子诚·认真」专属立绘?,
        "icon": "🏀",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "seen_zicheng_serious"
    },
    {
        "id": "soc_wechat_10",
        "category": "social",
        "name": "常驻置顶好友",
        "desc": "在微信中与同窗好友累计聊天互动达?10 次?,
        "icon": "💬",
        "points": 15,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "wechat_chat_count",
        "condition_target": 10
    },
    {
        "id": "soc_soulmate",
        "category": "social",
        "name": "白月光的誓言",
        "desc": "与任意一名角色的好感度达?100 满格大关！“千言万语，尽在不言中”?,
        "icon": "💍",
        "points": 35,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_favor_100"
    },
    {
        "id": "soc_gifts_5",
        "category": "social",
        "name": "礼物配送专?,
        "desc": "累计给同窗好友送出?5 件贴心礼物，深得大家信赖?,
        "icon": "🎁",
        "points": 20,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "gifts_given_count",
        "condition_target": 5
    },

    # ── 🎮 闲暇微光（小游戏高超技巧）──
    {
        "id": "game_boba_tier3",
        "category": "minigames",
        "name": "金牌调饮宗师",
        "desc": "累计调制奶茶达到 5 杯，奶茶店长甚至想聘请你当全职店长?,
        "icon": "🥤",
        "points": 20,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "boba_crafted_count",
        "condition_target": 5
    },
    {
        "id": "game_claw_tier3",
        "category": "minigames",
        "name": "梦幻捕手",
        "desc": "累计从娃娃机中成功抓?6 只毛绒玩偶，卧室床头已经堆不下了?,
        "icon": "🧸",
        "points": 25,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "claw_won_count",
        "condition_target": 6
    },
    {
        "id": "game_claw_collection",
        "category": "minigames",
        "name": "玩偶之家",
        "desc": "同时拥有 3 种以上不同款式的娃娃机玩偶（粉兔/小熊/橘猫/暴龙/锦鲤）?,
        "icon": "🎪",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_doll_collection_3"
    },
    {
        "id": "game_stealth_thrilling",
        "category": "minigames",
        "name": "心跳在喉?,
        "desc": "课堂传纸条警戒值在 85% 以上极限惊险送达！冷汗浸湿了校服后背?,
        "icon": "💓",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_stealth_thrilling"
    },
    {
        "id": "game_badminton_smash",
        "category": "minigames",
        "name": "雷霆扣杀?,
        "desc": "羽毛球对打中成功施展一记势大力沉的凌空绝杀暴扣得分?,
        "icon": "?,
        "points": 15,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_badminton_smash"
    },
    {
        "id": "game_badminton_marathon",
        "category": "minigames",
        "name": "持久战大?,
        "desc": "操场羽毛球单局达成 18 拍超长对打！全场观众为之鼓掌喝彩?,
        "icon": "🏅",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_badminton_rally_18"
    },
    {
        "id": "game_shutter_shy",
        "category": "minigames",
        "name": "最是那一低头的温?,
        "desc": "西湖快门摄影时，恰好在同伴害羞笑颜的瞬间精准定格镜头?,
        "icon": "📷",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_shutter_shy"
    },

    # ── 🏆 光阴长卷（终局与多周目传奇）──
    {
        "id": "mile_good_ending",
        "category": "milestones",
        "name": "金榜题名，双宿双?,
        "desc": "在中考放榜之日，顺利达成任意角色的【同一所学校好结局】！",
        "icon": "🎓",
        "points": 30,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_good_ending"
    },
    {
        "id": "mile_ng_3",
        "category": "milestones",
        "name": "三生三世西湖?,
        "desc": "开启第三周目（NG+2）循环，记忆深处的碎片愈发清晰明亮?,
        "icon": "?,
        "points": 40,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_ng_3"
    },
    {
        "id": "mile_all_endings_3",
        "category": "milestones",
        "name": "故事的千百种可能",
        "desc": "在往昔回忆中累计见证过至?3 种不同的初三人生结局?,
        "icon": "📖",
        "points": 35,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_seen_endings_3"
    },
    {
        "id": "mile_master_collector",
        "category": "milestones",
        "name": "西湖大收藏家",
        "desc": "同时集齐【西湖十景通】印章全集与【西湖风物通】廿四件大成?,
        "icon": "👑",
        "points": 50,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_master_collector"
    },
    {
        "id": "mile_legend_graduate",
        "category": "milestones",
        "name": "西湖传奇毕业?,
        "desc": "同时拥有【奥赛金牌直升保送】与【五社团全能王】双重绝顶荣耀?,
        "icon": "🌟",
        "points": 60,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_legend_graduate"
    }
]

# 合并去重写入
count_added = 0
for a in new_achievements:
    if a["id"] not in existing_ids:
        existing.append(a)
        existing_ids.add(a["id"])
        count_added += 1

with open(achievements_path, "w", encoding="utf-8") as f:
    json.dump(existing, f, ensure_ascii=False, indent=2)

print(f"?Successfully added {count_added} new achievements! Total count now: {len(existing)}")