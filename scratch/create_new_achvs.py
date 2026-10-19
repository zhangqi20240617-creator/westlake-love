# -*- coding: utf-8 -*-
"""Generate additional 45+ creative and unexpected achievements in JSON."""
import json

new_achievements = [
    # ── 🎭 curiosities: 意想不到的奇葩/失败/彩蛋 ──
    {
        "id": "curio_extreme_skew",
        "category": "curiosities",
        "name": "偏科之神",
        "desc": "单门科目考到90分以上，但另一门学科不足25分！“偏科偏到教导主任都头疼”",
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
        "desc": "压力值达到98点以上（仅差2点崩溃），依然咬牙撑过了一整天",
        "icon": "💥",
        "points": 20,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_stress_99"
    },
    {
        "id": "curio_penniless",
        "category": "curiosities",
        "name": "钱包比脸还干净",
        "desc": "身上的金币刚好花到了恰好0元整，“连根辣条都买不起了”",
        "icon": "💸",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_penniless"
    },
    {
        "id": "curio_claw_drop",
        "category": "curiosities",
        "name": "就差一厘米！",
        "desc": "娃娃机抓起玩偶升到了洞口上方，却在最后一瞬间脱落（痛，太痛了）",
        "icon": "🧸",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_claw_drop"
    },
    {
        "id": "curio_claw_glutton",
        "category": "curiosities",
        "name": "娃娃机吞币狂魔",
        "desc": "沉迷抓娃娃，累计在娃娃机投币超过10次",
        "icon": "🎰",
        "points": 20,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "claw_plays_total",
        "condition_value": 10
    },
    {
        "id": "curio_slip_hallway",
        "category": "curiosities",
        "name": "同学，你纸条掉了",
        "desc": "传纸条小游戏中，纸条不偏不倚正好掉落在走廊过道正中央",
        "icon": "📄",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_slip_hallway"
    },
    {
        "id": "curio_badminton_tree",
        "category": "curiosities",
        "name": "球呢？上树了！",
        "desc": "羽毛球大力扣杀，球竟然卡在了操场大树树权上",
        "icon": "🏸",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_badminton_tree"
    },
    {
        "id": "curio_boba_explosive",
        "category": "curiosities",
        "name": "这杯奶茶能防身",
        "desc": "调制出一杯全糖全料、搅拌超时的“核能生化奶茶”",
        "icon": "🧪",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_boba_explosive"
    },
    {
        "id": "curio_cat_robber",
        "category": "curiosities",
        "name": "被碰瓷团伙盯上了",
        "desc": "在校门口连续喂橘猫达到8次，“你已经被猫咪列为终身指定粮仓”",
        "icon": "🐱",
        "points": 25,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "campus_cat_feeds",
        "condition_value": 8
    },
    {
        "id": "curio_slack_scholar",
        "category": "curiosities",
        "name": "学神也摸鱼",
        "desc": "智力或学力满值的情况下，在课间连续倒头大睡3次",
        "icon": "😴",
        "points": 20,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_slack_scholar"
    },
    {
        "id": "curio_trio_jealousy",
        "category": "curiosities",
        "name": "修罗场的微风",
        "desc": "同时与三位女生的好感度达到50以上，“空气中弥漫着危险的气息”",
        "icon": "⚡",
        "points": 30,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_trio_jealousy"
    },
    {
        "id": "curio_raining_wet",
        "category": "curiosities",
        "name": "雨中的落汤鸡",
        "desc": "雨天未带雨伞在西湖边闲逛，被淋得一身湿透",
        "icon": "🌧️",
        "points": 15,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_raining_wet"
    },
    {
        "id": "curio_shutter_ghost",
        "category": "curiosities",
        "name": "抓拍了个寂寞",
        "desc": "西湖快门摄影小游戏中，镜头内空无一物却按下了快门",
        "icon": "📷",
        "points": 10,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_shutter_ghost"
    },
    {
        "id": "curio_water_master",
        "category": "curiosities",
        "name": "端水大师翻车记",
        "desc": "试图在同一时间答应两位女生的周末邀约，结果翻车当场",
        "icon": "⚖️",
        "points": 25,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_water_master"
    },
    {
        "id": "curio_foodie_glutton",
        "category": "curiosities",
        "name": "小吃街扫荡者",
        "desc": "一天之内品尝了校门口小吃街的3种不同小吃",
        "icon": "🍢",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_foodie_glutton"
    },
    {
        "id": "curio_lucky_clover",
        "category": "curiosities",
        "name": "被幸运女神眷顾",
        "desc": "在抽签或随机事件中连续获得3次上上签或幸运判定",
        "icon": "🍀",
        "points": 20,
        "hidden": True,
        "condition_type": "counter",
        "condition_key": "lucky_streaks",
        "condition_value": 3
    },

    # ── 📚 academics: 金榜题名 ──
    {
        "id": "acad_math_100",
        "category": "academics",
        "name": "数学满分！",
        "desc": "在模拟考或期末考中数学单科斩获100分满分",
        "icon": "💯",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_math_100"
    },
    {
        "id": "acad_chinese_100",
        "category": "academics",
        "name": "妙笔生花满分卷",
        "desc": "在考试中语文单科获得100分满分，“阅卷老师击节赞赏”",
        "icon": "✒️",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_chinese_100"
    },
    {
        "id": "acad_english_100",
        "category": "academics",
        "name": "无障碍原声大碟",
        "desc": "在考试中英语单科获得100分满分",
        "icon": "🔤",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_english_100"
    },
    {
        "id": "acad_science_100",
        "category": "academics",
        "name": "理科天花板",
        "desc": "在考试中科学单科获得100分满分",
        "icon": "🔬",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_science_100"
    },
    {
        "id": "acad_subjects_all_80",
        "category": "academics",
        "name": "全能六边形战士",
        "desc": "语数英科四门科目期末成绩均在80分以上，无任何偏科",
        "icon": "🛡️",
        "points": 30,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_subjects_all_80"
    },
    {
        "id": "acad_double_scholar",
        "category": "academics",
        "name": "文理双状元",
        "desc": "同一次考试中语文与数学成绩同时超过95分",
        "icon": "📜",
        "points": 35,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_double_scholar"
    },
    {
        "id": "acad_library_ghost",
        "category": "academics",
        "name": "图书馆地缚灵",
        "desc": "累计在学校图书馆或自修室自习超过15次",
        "icon": "📚",
        "points": 25,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "library_study_count",
        "condition_value": 15
    },
    {
        "id": "acad_quiz_ace_50",
        "category": "academics",
        "name": "题海征服者",
        "desc": "在随堂测验与学科答题中累计答对50道题",
        "icon": "📝",
        "points": 30,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "quiz_correct_count",
        "condition_value": 50
    },

    # ── 🌸 hangzhou: 人间天堂 ──
    {
        "id": "hz_longjing_tea_master",
        "category": "hangzhou",
        "name": "龙井问茶识春意",
        "desc": "在茶馆或西湖边品尝明前特级西湖龙井，“一啜得神和”",
        "icon": "🍵",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_longjing_tea_master"
    },
    {
        "id": "hz_lingyin_peace",
        "category": "hangzhou",
        "name": "灵隐梵钟洗客尘",
        "desc": "游历灵隐飞来峰，听古刹钟声使压力归零",
        "icon": "🔔",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_lingyin_peace"
    },
    {
        "id": "hz_qiantang_bore",
        "category": "hangzhou",
        "name": "钱塘八月观弄潮",
        "desc": "前往钱塘江畔目睹壮观的一线潮奇景",
        "icon": "🌊",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_qiantang_bore"
    },
    {
        "id": "hz_xixi_slow",
        "category": "hangzhou",
        "name": "西溪芦荡泛轻舟",
        "desc": "游历西溪湿地水乡，感受“西溪且留下”的诗意",
        "icon": "🛶",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_xixi_slow"
    },
    {
        "id": "hz_gongchen_bridge",
        "category": "hangzhou",
        "name": "运河南端看拱宸",
        "desc": "漫步京杭大运河拱宸桥桥畔，领略老杭州水乡风韵",
        "icon": "🌉",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_gongchen_bridge"
    },
    {
        "id": "hz_hangzhou_master",
        "category": "hangzhou",
        "name": "杭州城活地图",
        "desc": "足迹遍布杭州城所有打卡胜地与风物景点",
        "icon": "🗺️",
        "points": 50,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_hangzhou_master"
    },

    # ── 🤝 social: 青葱岁月 ──
    {
        "id": "soc_favor_100",
        "category": "social",
        "name": "至死不渝的羁绊",
        "desc": "与任意一位女生的好感度达到100满值",
        "icon": "💖",
        "points": 35,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_favor_100"
    },
    {
        "id": "soc_gift_favorite",
        "category": "social",
        "name": "送到了心坎里",
        "desc": "赠送给女生她最喜爱的专属专属心愿礼物，好感度暴涨",
        "icon": "🎁",
        "points": 20,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_gift_favorite"
    },
    {
        "id": "soc_wechat_chatter",
        "category": "social",
        "name": "置顶聊天小红点",
        "desc": "在微信通讯录中累计回复聊天信息达到25次",
        "icon": "💬",
        "points": 20,
        "hidden": False,
        "condition_type": "counter",
        "condition_key": "wechat_reply_count",
        "condition_value": 25
    },
    {
        "id": "soc_shared_umbrella",
        "category": "social",
        "name": "雨季的那把同心伞",
        "desc": "下雨天触发与女生共撑一把伞漫步校园的特殊剧情",
        "icon": "☂️",
        "points": 25,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_shared_umbrella"
    },
    {
        "id": "soc_secret_confidant",
        "category": "social",
        "name": "独家秘密的倾听者",
        "desc": "在长谈夜话中解开女生的心结，得知她深藏的心愿",
        "icon": "🗝️",
        "points": 25,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_secret_confidant"
    },

    # ── 🎮 minigames: 街机达人 ──
    {
        "id": "mini_claw_golden",
        "category": "minigames",
        "name": "神之右手！金色传说！",
        "desc": "在抓娃娃机中一发入魂，抓到超级稀有的金色玩偶",
        "icon": "🏆",
        "points": 30,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_claw_golden"
    },
    {
        "id": "mini_paper_silent",
        "category": "minigames",
        "name": "幽灵传纸条",
        "desc": "传纸条小游戏中，在巡逻老师警戒度全程为0的状态下顺利传达",
        "icon": "👻",
        "points": 25,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_paper_silent"
    },
    {
        "id": "mini_badminton_50",
        "category": "minigames",
        "name": "五十连击！凌空绝杀！",
        "desc": "羽毛球双人拉吊小游戏中，达成50次以上无失误对攻",
        "icon": "⚡",
        "points": 35,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_badminton_50"
    },
    {
        "id": "mini_shutter_perfect_triple",
        "category": "minigames",
        "name": "三连神级快门",
        "desc": "西湖快门摄影小游戏中，单局内连续三次抓拍判定全部为Perfect",
        "icon": "🎯",
        "points": 30,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_shutter_perfect_triple"
    },
    {
        "id": "mini_boba_3star_all",
        "category": "minigames",
        "name": "特级国宴调饮大师",
        "desc": "自制奶茶小游戏中，所有维度全满星达成传奇金标奶茶",
        "icon": "🥤",
        "points": 25,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_boba_3star_all"
    },

    # ── 🏆 milestones: 如歌年华 ──
    {
        "id": "mile_rich_1000",
        "category": "milestones",
        "name": "校园理财大亨",
        "desc": "持有金币总额突破1000大关，“高中生里的隐形富豪”",
        "icon": "💰",
        "points": 30,
        "hidden": False,
        "condition_type": "stat",
        "condition_key": "money",
        "condition_value": 1000
    },
    {
        "id": "mile_all_clubs",
        "category": "milestones",
        "name": "百团大战体验家",
        "desc": "参观或体验过天文、文学、篮球、广播、美术所有社团",
        "icon": "🎪",
        "points": 30,
        "hidden": False,
        "condition_type": "flag",
        "condition_key": "achv_all_clubs"
    },
    {
        "id": "mile_full_gallery",
        "category": "milestones",
        "name": "青春光影大圆满",
        "desc": "在相册与画廊中集齐所有毕业结局纪念CG与插画",
        "icon": "🖼️",
        "points": 50,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_full_gallery"
    },
    {
        "id": "mile_legend_graduate",
        "category": "milestones",
        "name": "无悔的青春史诗",
        "desc": "以全科目优异、全好感丰收的超神姿态圆满完成三年学业",
        "icon": "👑",
        "points": 60,
        "hidden": True,
        "condition_type": "flag",
        "condition_key": "achv_legend_graduate"
    }
]

with open("d:/zkgame/scratch/new_achievements.json", "w", encoding="utf-8") as f:
    json.dump(new_achievements, f, ensure_ascii=False, indent=2)

print(f"Generated {len(new_achievements)} new achievements in scratch/new_achievements.json")
