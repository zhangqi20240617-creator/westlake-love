extends Panel
# WeChatUI.gd - 📱 模拟微信聊天社交系统 (Interactive WeChat Messaging Popup)

signal closed

var active_char_id: String = ""
var _night_open: bool = false   # 本次打开聊天是否注入了深夜消息（影响时间戳显示）
var typing_timer: Timer
var wechat_green = Color("#95EC69") # 微信标志性绿色发送泡泡
var bg_color = Color("#EDEDED")     # 微信经典聊天背景灰

# 控件引用
var phone_frame: PanelContainer
var chat_list_scroll: ScrollContainer
var chat_list_container: VBoxContainer
var active_chat_view: VBoxContainer
var active_chat_scroll: ScrollContainer
var bubble_container: VBoxContainer
var header_title: Label
var back_btn: Button
var choices_container: VBoxContainer
var input_bar: Panel

# ── 朋友圈系统变量 ──
var moments_scroll: ScrollContainer
var moments_container: VBoxContainer
var tab_bar: Panel
var chat_tab_btn: Button
var moments_tab_btn: Button

# 朋友圈内容数据库
var moments_db = [
    {
        "id": "post_yutong_study",
        "char_id": "yutong",
        "unlock_day": 3,
        "text": "第一阶段的物理和数学错题本整理好了，中考倒计时在一天天减少，大家也要加油复习呀！📚💪",
        "timestamp": "3天前",
        "comments": [
            {
                "text": "班长求借阅！物理最后那道大题我卡了好久了。",
                "reply": "“明天早上第一节课前拿给你，记得好好做受力分析哦。”",
                "aff": 8
            },
            {
                "text": "这才刚开学就这么拼，真是卷王本王啊……",
                "reply": "“哪有，这叫合理规划。加油复习，你也行的。”",
                "aff": 4
            }
        ]
    },
    {
        "id": "post_jingjing_cat",
        "char_id": "jingjing",
        "unlock_day": 7,
        "text": "小区楼下那只小橘猫居然学会假摔碰瓷了，喵喵叫个不停，害我把买棒冰的硬币都拿去买猫罐头了！🐱💔",
        "timestamp": "昨天",
        "comments": [
            {
                "text": "肯定是因为你看起来特别好骗（偷笑）。",
                "reply": "“喂！猫猫也是看人下菜碟的好不好！咬你哦！”",
                "aff": 8
            },
            {
                "text": "其实是那只猫觉得你可爱，才主动接近你吧。",
                "reply": "“哼、哼，那当然……不对！你这家伙什么时候学得嘴这么甜了？！”",
                "aff": 12
            }
        ]
    },
    {
        "id": "post_xiaoxia_run",
        "char_id": "xiaoxia",
        "unlock_day": 12,
        "text": "雨后跑完10公里的西湖苏堤，空气超级清新！感觉整个人的精气神都回来了！等会去喝大杯奶茶！🏃‍♀️🥤✨",
        "timestamp": "2小时前",
        "comments": [
            {
                "text": "雨后跑步加冰镇奶茶，你是真的不怕拉肚子啊……",
                "reply": "“健壮如牛！体测的时候让你见识一下什么叫体育课代表的实力！”",
                "aff": 5
            },
            {
                "text": "太有活力了，下次跑步能带我一个吗？",
                "reply": "“好啊！明天下午放学后操场见，掉队了可别哭鼻子！”",
                "aff": 12
            }
        ]
    },
    {
        "id": "post_wanqing_lake",
        "char_id": "wanqing",
        "unlock_day": 18,
        "text": "“水光潋滟晴方好，山色空蒙雨亦奇。” 细雨中的西湖，比晴天更有一番朦胧的诗意。🍃✍️",
        "timestamp": "4小时前",
        "comments": [
            {
                "text": "雨天散步确实安静，有一种心灵沉淀的感觉。",
                "reply": "“是的呢，如果你也喜欢，下次雨后可以一同走走。”",
                "aff": 10
            },
            {
                "text": "大文豪又作诗了，虽然看不大懂，但觉得非常有品位！",
                "reply": "“只是随笔而已，读诗能让人心神平静，你可以试试看。”",
                "aff": 6
            }
        ]
    },
    {
        "id": "post_zijun_sketch",
        "char_id": "zijun",
        "unlock_day": 25,
        "text": "在断桥边写生了一下午，水彩纸都被湖风吹卷边了，但最后这张荷叶的颜色我真的好喜欢！🎨",
        "timestamp": "1小时前",
        "comments": [
            {"text": "能看出来你画的时候很开心，颜色里都是夏天的味道。", "reply": "“诶？你居然看得懂……下次写生带你一起，帮我扛画板！”", "aff": 11},
            {"text": "卷边了还能这么好看，不愧是美术课代表。", "reply": "“嘿嘿，那是～水彩就是要有点意外才有灵气嘛。”", "aff": 6}
        ]
    },
    {
        "id": "post_jingjing_m_bike",
        "char_id": "jingjing_m",
        "unlock_day": 40,
        "text": "修好了那辆旧自行车，链条上了油，铃铛还是小学时那个声音。放学要不要捎你一段？就当补票。🚲",
        "timestamp": "昨天",
        "comments": [
            {"text": "补什么票？小学你蹭我橡皮的账还没算呢。", "reply": "“喂喂，陈年旧账就别翻了！明天校门口等你，别迟到。”", "aff": 12},
            {"text": "这辆车居然还能骑，真是老古董了。", "reply": "“老古董才有感情好吗，它可比你懂我。”", "aff": 5}
        ]
    },
    {
        "id": "post_zicheng_match",
        "char_id": "zicheng",
        "unlock_day": 75,
        "text": "区联赛小组出线了！最后那记压哨三分，出手的瞬间整个体育馆都安静了。下一场，主场，等你们来。🏀🔥",
        "timestamp": "3小时前",
        "comments": [
            {"text": "压哨那球我看了三遍回放，队长稳得可怕！下一场我一定到场。", "reply": "“好兄弟！给你留第一排，记得帮我喊防守！”", "aff": 11},
            {"text": "恭喜出线！不过别骄傲，决赛才是硬仗。", "reply": "“放心，教练也是这么说的。冠军拿回来给你看。”", "aff": 6}
        ]
    },
    {
        "id": "post_yifei_recital",
        "char_id": "yifei",
        "unlock_day": 160,
        "text": "校庆汇演的独奏曲定了，是我自己写的那首。副歌部分改了十七遍，写它的时候，总想起西湖傍晚的风。🎻",
        "timestamp": "晚上 10:02",
        "comments": [
            {"text": "十七遍……那首曲子里一定藏着很重要的东西吧。", "reply": "“……被你听出来了。汇演那天，你会来听吗？”", "aff": 12},
            {"text": "自己作曲还能上校庆，太厉害了！", "reply": "“谢谢。不过比起厉害，我更希望它能被听懂。”", "aff": 6}
        ]
    },
    {
        "id": "post_keke_transfer",
        "char_id": "keke",
        "unlock_day": 305,
        "text": "转学第一周打卡！这个学校居然出门就是西湖，杭州的同学们也太幸福了吧！有人愿意当我的向导嘛？🎀✨",
        "timestamp": "30分钟前",
        "comments": [
            {"text": "向导预定！先从苏堤走起，秋天的落叶配奶茶刚刚好。", "reply": "“成交！！那说好了，这周末苏堤见，奶茶你请～”", "aff": 12},
            {"text": "欢迎来到西湖中学！习惯了就知道，考试周可没空看湖。", "reply": "“呜，别吓我啦！不过谢谢你的欢迎，感觉安心多了。”", "aff": 6}
        ]
    },
    {
        "id": "post_beichen_moon",
        "char_id": "beichen",
        "unlock_day": 320,
        "text": "凌晨的平湖秋月，没有游客，只有月亮和湖。原来安静的时候，一座城市是会呼吸的。",
        "timestamp": "凌晨 1:47",
        "comments": [
            {"text": "会呼吸的城市……你看到的西湖，好像和所有人的都不一样。", "reply": "“……第一次有人这么回我。下次，带你看凌晨的湖。”", "aff": 12},
            {"text": "凌晨还在外面？快回去睡觉，明天还要上课呢。", "reply": "“睡不着而已。不过，谢谢你的关心。”", "aff": 7}
        ]
    }
]

# 存储各角色的聊天记录与状态
var chats_db = {
    "yutong": {
        "name": "陈雨桐",
        "emoji": "🌸",
        "avatar_color": Color("#4A7BB7"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "yutong",
                "text": "明天学校要收物理练习册了，你写完了吗？第一天感觉你有点吃力呢。",
                "choices": [
                    {"text": "写完了！明天第一节课前就交给你。", "next": "study_ok", "aff": 3, "stress": -5},
                    {"text": "还差最后一道重力加速度的题，感觉太难了...", "next": "study_help", "aff": 5, "stress": 3}
                ]
            },
            "study_ok": {
                "sender": "yutong",
                "text": "（小赞表情）嗯，不愧是班长信任的组员！明天记得早点来学校交给我，早起适当读书效率更好哦。",
                "choices": [
                    {"text": "好，明天早上见！", "next": "end", "aff": 2, "stress": 0}
                ]
            },
            "study_help": {
                "sender": "yutong",
                "text": "那道题吗？重力加速度 $g$ 一般取 $9.8$ 或者 $10$，记得跟空气阻力受力分析合并计算。\n我把我的解题草稿拍照发你？你对照看一下。",
                "choices": [
                    {"text": "太棒了！班长大人简直是救星！", "next": "study_grateful", "aff": 5, "stress": -10},
                    {"text": "不用啦，我自己再琢磨琢磨，不打扰你休息了。", "next": "study_independent", "aff": 2, "stress": 2}
                ]
            },
            "study_grateful": {
                "sender": "yutong",
                "text": "（她发了一张手写草稿图）...少贫嘴，能帮到你就好。看完弄懂就早点休息，明天别迟到了哦。",
                "choices": [
                    {"text": "遵命，晚安！", "next": "end", "aff": 2, "stress": 0}
                ]
            },
            "study_independent": {
                "sender": "yutong",
                "text": "这样啊，那也很棒。有钻研精神是好事！不过别熬太晚，太累了第二天上课会犯困的。晚安。",
                "choices": [
                    {"text": "好的，晚安！", "next": "end", "aff": 2, "stress": 0}
                ]
            },
            "end": {
                "sender": "yutong",
                "text": "（系统提示：雨桐去复习英语啦，明天学校见吧~）",
                "choices": []
            },
            "night_start": {
                "sender": "yutong",
                "text": "还没睡吧？刚整理完模拟卷才发现这么晚了。\n……其实今天想跟你说声抱歉，白天催作业的时候，语气好像有点凶。",
                "choices": [
                    {"text": "一点也不凶，我知道班长是为大家好。", "next": "night_soft", "aff": 6, "stress": -3},
                    {"text": "确实有点凶哦～不过被你凶一下，作业效率翻倍。", "next": "night_tease", "aff": 4, "stress": -2}
                ]
            },
            "night_soft": {
                "sender": "yutong",
                "text": "……谢谢你这么说。当班长有时候挺累的，好像必须一直是“靠谱的陈雨桐”。\n只有跟你说话的时候，可以稍微松口气。",
                "choices": [
                    {"text": "在我这里，你不用一直靠谱，做陈雨桐就好。", "next": "night_end", "aff": 6, "stress": -4, "setFlag": "night_heart_yutong"}
                ]
            },
            "night_tease": {
                "sender": "yutong",
                "text": "效率翻倍？那明天我再凶一点好了。……开玩笑的啦。\n不早了，明天还有早读，我们都快睡吧。",
                "choices": [
                    {"text": "晚安班长，明天早读见。", "next": "night_end", "aff": 3, "stress": -2}
                ]
            },
            "night_end": {
                "sender": "yutong",
                "text": "（她发来一个小小的月亮表情。你猜她合上错题本的时候，嘴角是弯着的。）",
                "choices": []
            }
        }
    },
    "jingjing": {
        "name": "林菁菁",
        "emoji": "🌿",
        "avatar_color": Color("#E87D9A"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "jingjing",
                "text": "笨蛋！听说今天英语小测验你错了不少？\n没有本天才在旁边监督，你是不是又上课偷偷发呆了？",
                "choices": [
                    {"text": "怎么可能，我明明是在思考极其深奥的问题！", "next": "genius_reply", "aff": 5, "stress": -5},
                    {"text": "唉，单词太难背了，我确实有点走神...", "next": "comfort_reply", "aff": 3, "stress": 5}
                ]
            },
            "genius_reply": {
                "sender": "jingjing",
                "text": "哼，少吹牛了！你脑子里除了游戏，还能思考什么深奥问题？\n不过...看在邻居的份上，错题本借你抄一下也不是不行。（高傲）",
                "choices": [
                    {"text": "那本天才就恭敬不如从命啦，谢谢菁菁！", "next": "happy_end", "aff": 4, "stress": -8},
                    {"text": "不用，这周中考模拟，我肯定能反超你！", "next": "rival_end", "aff": 2, "stress": 10}
                ]
            },
            "comfort_reply": {
                "sender": "jingjing",
                "text": "（拍桌子表情）笨蛋笨蛋！初中三年时间一晃就过去了，你这样怎么考得上好高中啊！\n不过...别太沮丧了，晚上多吃点好吃的，压力太大的话脑子会锈掉的。",
                "choices": [
                    {"text": "知道了，邻居管家婆，你也早点休息吧。", "next": "warm_end", "aff": 5, "stress": -8}
                ]
            },
            "happy_end": {
                "sender": "jingjing",
                "text": "谁、谁要你谢了，顺手而已！明天上学在楼下等我，别迟到！晚安啦。",
                "choices": []
            },
            "rival_end": {
                "sender": "jingjing",
                "text": "呵！好大的口气！那这周五出成绩时见分晓，输的人要请吃一根棒冰！晚安，笨蛋！",
                "choices": []
            },
            "warm_end": {
                "sender": "jingjing",
                "text": "谁是管家婆啊！（愤怒敲头表情）……算啦不跟你计较，快去洗洗睡吧，晚安！",
                "choices": []
            },
            "night_start": {
                "sender": "jingjing",
                "text": "喂……你睡了吗？我睡不着。今天白天跟妈妈吵架了，一直心里闷闷的。\n从小到大好像每次难受，最后都是找你说。",
                "choices": [
                    {"text": "我在。慢慢说，我听着呢。", "next": "night_listen", "aff": 6, "stress": -3},
                    {"text": "这么晚还不睡，明天上课又要打瞌睡啦。", "next": "night_tease", "aff": 3, "stress": 0}
                ]
            },
            "night_listen": {
                "sender": "jingjing",
                "text": "……其实也不是什么大事，就是她总拿我跟别人家孩子比。\n跟你说完，突然就没那么难受了。喂，笨蛋，谢谢你啊。今晚的事不许告诉别人！",
                "choices": [
                    {"text": "保密。不过下次难受，第一个还是要来找我。", "next": "night_end", "aff": 5, "stress": -5, "setFlag": "night_heart_jingjing"}
                ]
            },
            "night_tease": {
                "sender": "jingjing",
                "text": "哼，就知道你会这么说！……不过听到你回消息，心情就好多了。真是奇怪。\n好啦好啦，睡了睡了，晚安，笨蛋。",
                "choices": [
                    {"text": "晚安，做个好梦。", "next": "night_end", "aff": 3, "stress": -2}
                ]
            },
            "night_end": {
                "sender": "jingjing",
                "text": "（对话框安静下来，窗外的月光正好。你能想象她抱着手机踢被子的样子。）",
                "choices": []
            }
        }
    },
    "wanqing": {
        "name": "苏晚晴",
        "emoji": "📚",
        "avatar_color": Color("#A78BFA"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "wanqing",
                "text": "你最近在看什么书呢？我最近在看泰戈尔的诗集，觉得有很多句子写得很美。",
                "choices": [
                    {"text": "我也喜欢泰戈尔，‘生如夏花之绚烂’这句特别棒。", "next": "poetry_lover", "aff": 5, "stress": -5},
                    {"text": "我不怎么看诗集，平时看复习题和小说多一些。", "next": "novel_reader", "aff": 3, "stress": 3}
                ]
            },
            "poetry_lover": {
                "sender": "wanqing",
                "text": "真的吗？我也最喜欢那句。‘生如夏花之绚烂，死如秋叶之静美。’ 感觉写出了一种极致生命力的绚烂与安静。很高兴你也能理解这种美。",
                "choices": [
                    {"text": "能在喧嚣的生活中找到共鸣，真的很不容易。", "next": "end", "aff": 4, "stress": -5}
                ]
            },
            "novel_reader": {
                "sender": "wanqing",
                "text": "小说也很好呀，里面也有丰富的人生百态。其实读什么都可以，只要能让浮躁的心安静下来。复习累了记得多看窗外，注意眼睛哦。",
                "choices": [
                    {"text": "谢谢晚晴姐的关心，我会的。", "next": "end", "aff": 3, "stress": -5}
                ]
            },
            "end": {
                "sender": "wanqing",
                "text": "（系统提示：晚晴静静地合上书本，去写手账日记啦，晚安哦～）",
                "choices": []
            },
            "night_start": {
                "sender": "wanqing",
                "text": "睡不着，就着台灯读了会儿诗。“今夜偏知春气暖，虫声新透绿窗纱。”\n……忽然想，不知道你此刻的窗外，是什么声音。",
                "choices": [
                    {"text": "有风穿过树叶的声音，很轻。你听，我们听的是同一阵风。", "next": "night_wind", "aff": 6, "stress": -4},
                    {"text": "只有我翻复习题的声音，唉。", "next": "night_study", "aff": 4, "stress": -2}
                ]
            },
            "night_wind": {
                "sender": "wanqing",
                "text": "同一阵风……你这句话，比我今晚读的诗还好。\n我把它抄在手账的今天这一页了，署名是你哦。",
                "choices": [
                    {"text": "那我可是第一次“发表作品”，多亏了你。", "next": "night_end", "aff": 5, "stress": -4, "setFlag": "night_heart_wanqing"}
                ]
            },
            "night_study": {
                "sender": "wanqing",
                "text": "这么晚还在做题，那也是很动听的声音呀，是认真生活的声音。\n不过再动听也要按时休息。我陪你，到你合上笔为止。",
                "choices": [
                    {"text": "好，现在就合上。晚安，晚晴。", "next": "night_end", "aff": 4, "stress": -3}
                ]
            },
            "night_end": {
                "sender": "wanqing",
                "text": "（对话停在这里，像一页被轻轻合上的书。窗外的雨，不知何时停了。）",
                "choices": []
            }
        }
    },
    "xiaoxia": {
        "name": "林小夏",
        "emoji": "⚽",
        "avatar_color": Color("#4CAF8A"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "xiaoxia",
                "text": "喂！今天下午体测，我跑了全班第一！你小子跑完怎么直接躺地上了，体力也太弱了吧？",
                "choices": [
                    {"text": "我那是战术性躺下！其实我还有力气跑十公里！", "next": "brag_reply", "aff": 5, "stress": -5},
                    {"text": "唉，体育确实是我的弱项，以后能带我一起练练吗？", "next": "train_reply", "aff": 5, "stress": 2}
                ]
            },
            "brag_reply": {
                "sender": "xiaoxia",
                "text": "哈哈哈少吹牛了！是谁跑完1000米扶着电线杆直喘粗气的？不过你要是真想练，明天放学操场见，我带你跑！不许放鸽子！",
                "choices": [
                    {"text": "一言为定，谁怂谁是小狗！", "next": "dog_end", "aff": 4, "stress": 0}
                ]
            },
            "train_reply": {
                "sender": "xiaoxia",
                "text": "好说！本体育课代表包教包会！先从每天慢跑2公里开始。运动完喝杯冰镇盐汽水，那感觉简直爽爆！明天放学等我！",
                "choices": [
                    {"text": "没问题，明天见！", "next": "soda_end", "aff": 4, "stress": -5}
                ]
            },
            "dog_end": {
                "sender": "xiaoxia",
                "text": "那明天放学操场见！我要让你见识一下什么叫风一样的速度！晚安！",
                "choices": []
            },
            "soda_end": {
                "sender": "xiaoxia",
                "text": "嘿嘿，那早点休息补充体力，明天操场不见不散，晚安啦！",
                "choices": []
            },
            "night_start": {
                "sender": "xiaoxia",
                "text": "喂！你还醒着吧！我睡不着——明天区运动会4x100我跑最后一棒，越想越紧张。\n居然会紧张，我诶！",
                "choices": [
                    {"text": "你可是林小夏诶，接过棒的那一秒你只会想赢。", "next": "night_hype", "aff": 6, "stress": -3},
                    {"text": "紧张说明你在乎。深呼吸，我陪你聊到困为止。", "next": "night_calm", "aff": 5, "stress": -4}
                ]
            },
            "night_hype": {
                "sender": "xiaoxia",
                "text": "……对啊！我可是林小夏诶！哈哈，你这句话比十罐冰镇盐汽水还提神！\n好，明天最后一棒，我把所有人都甩在身后给你看！",
                "choices": [
                    {"text": "明天我在终点线等你，第一个跟你击掌。", "next": "night_end", "aff": 6, "stress": -3, "setFlag": "night_promise_xiaoxia"}
                ]
            },
            "night_calm": {
                "sender": "xiaoxia",
                "text": "呼——吸——好像真的好点了。第一次发现，慢下来聊天也不错嘛。\n喂，今晚的事不许说出去！体育课代表的形象还要不要了！",
                "choices": [
                    {"text": "保密。但明天喊加油的声音，我一定最大。", "next": "night_end", "aff": 5, "stress": -3}
                ]
            },
            "night_end": {
                "sender": "xiaoxia",
                "text": "（她发来一个握拳表情：明天见！然后大概三秒钟就睡着了吧，那家伙。）",
                "choices": []
            }
        }
    },
    "yifei": {
        "name": "沈逸飞",
        "emoji": "🎻",
        "avatar_color": Color("#5B9FD4"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "yifei",
                "text": "今天在琴房练了一首新写的曲子，但是总觉得副歌的过渡不够流畅……你觉得音乐最吸引你的是什么？",
                "choices": [
                    {"text": "是旋律中传达的真挚情感，能让人感同身受。", "next": "emotion_reply", "aff": 5, "stress": -5},
                    {"text": "是节奏和律动吧，能让人暂时忘掉压力和烦恼。", "next": "beat_reply", "aff": 4, "stress": -8}
                ]
            },
            "emotion_reply": {
                "sender": "yifei",
                "text": "感同身受吗……说得对。我写这首歌时，脑海里确实浮现出了某些西湖边的画面。也许正是因为倾注了情感，所以才会觉得有些羞涩吧。谢谢你的建议。",
                "choices": [
                    {"text": "我很期待这首新曲子完成的那天！", "next": "music_end", "aff": 4, "stress": 0}
                ]
            },
            "beat_reply": {
                "sender": "yifei",
                "text": "节奏确实能带走疲倦。不过我的这首新歌节奏偏慢，也许适合在安静的雨天戴着耳机听。等我录好小样，第一个发给你听吧。",
                "choices": [
                    {"text": "太好了，我随时准备当你的第一位听众！", "next": "music_end", "aff": 4, "stress": 0}
                ]
            },
            "music_end": {
                "sender": "yifei",
                "text": "（系统提示：逸飞微笑着戴上耳机，继续在五线谱上修改旋律了，晚安～）",
                "choices": []
            },
            "night_start": {
                "sender": "yifei",
                "text": "抱歉，这么晚打扰。那首曲子……刚才终于写完了最后一小节。\n写完的第一秒，不知道为什么，就想告诉你。",
                "choices": [
                    {"text": "我很荣幸是第一个知道的人。现在能听吗？", "next": "night_listen", "aff": 6, "stress": -3},
                    {"text": "恭喜！改了十七遍的副歌，终于放过你了。", "next": "night_tease", "aff": 4, "stress": -2}
                ]
            },
            "night_listen": {
                "sender": "yifei",
                "text": "（他发来一段琴房录的小样，末尾有很轻的呼吸声）\n……其实副歌里藏了一句话，是用旋律写的。等汇演那天，你坐在台下，也许就听懂了。",
                "choices": [
                    {"text": "那我一定坐在能听懂的位置。", "next": "night_end", "aff": 6, "stress": -4, "setFlag": "night_promise_yifei"}
                ]
            },
            "night_tease": {
                "sender": "yifei",
                "text": "哈，是它放过我了。不过说真的，能改十七遍，是因为总觉得——\n要是会被“那个人”听到的话，就不能有一点将就。",
                "choices": [
                    {"text": "“那个人”很期待汇演那天。", "next": "night_end", "aff": 5, "stress": -2}
                ]
            },
            "night_end": {
                "sender": "yifei",
                "text": "（很久之后，他又发来一句：晚安。琴房的灯，现在才关。）",
                "choices": []
            }
        }
    },
    "zicheng": {
        "name": "周子诚",
        "emoji": "🏀",
        "avatar_color": Color("#4CAF8A"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "zicheng",
                "text": "哥们！最新出的那款合作联机游戏你买了没？今晚刚好有空，联机打一局？",
                "choices": [
                    {"text": "必须的！带好零食，今晚咱们开启通宵联机模式！", "next": "game_on", "aff": 5, "stress": -10},
                    {"text": "今晚还要复习，改天吧，下回我请你喝冰可乐赔罪！", "next": "study_first", "aff": 3, "stress": 5}
                ]
            },
            "game_on": {
                "sender": "zicheng",
                "text": "爽快！不愧是我的铁哥们！上麦上麦，这把看我带你飞，直接平推对面！",
                "choices": [
                    {"text": "冲冲冲，开黑！", "next": "game_end", "aff": 3, "stress": 0}
                ]
            },
            "study_first": {
                "sender": "zicheng",
                "text": "好吧，初三毕竟要紧，学习第一。不过你可记着这顿冰可乐啊！下次打球分你半个西瓜，先预祝你今晚复习顺利！",
                "choices": [
                    {"text": "谢啦哥们，回见！", "next": "study_end", "aff": 3, "stress": -5}
                ]
            },
            "game_end": {
                "sender": "zicheng",
                "text": "（系统提示：子诚已经迫不及待地开启了游戏加速器，等待你的联机加入啦～）",
                "choices": []
            },
            "study_end": {
                "sender": "zicheng",
                "text": "哈哈，加油，回见！",
                "choices": []
            },
            "night_start": {
                "sender": "zicheng",
                "text": "兄弟，睡了没。今天训练赛我罚球三连铁，最后输了两分……\n队长当成这样，有点没脸见队里那帮人。",
                "choices": [
                    {"text": "一场训练赛而已。你带队打进区联赛那晚，可是全队都兴奋得睡不着。", "next": "night_up", "aff": 6, "stress": -4},
                    {"text": "铁三个球说明什么？说明你敢站上罚球线三次。", "next": "night_line", "aff": 5, "stress": -3}
                ]
            },
            "night_up": {
                "sender": "zicheng",
                "text": "……哈，还得是你。行！明早六点我去球馆加练罚球，练到闭眼都能进。\n等决赛那天，我把今天丢的分连本带利赢回来！",
                "choices": [
                    {"text": "六点我陪你去，帮你捡球。", "next": "night_end", "aff": 6, "stress": -3, "setFlag": "night_heart_zicheng"}
                ]
            },
            "night_line": {
                "sender": "zicheng",
                "text": "敢站上去三次……兄弟，你这话我记一辈子。教练也说过，怕的不是打铁，是不敢出手。\n行了，我又行了！",
                "choices": [
                    {"text": "这才是我认识的周队长。睡吧，明天生龙活虎。", "next": "night_end", "aff": 5, "stress": -3}
                ]
            },
            "night_end": {
                "sender": "zicheng",
                "text": "（他发来一个碰拳的表情。你仿佛已经听见明天清晨球馆里砰砰的运球声。）",
                "choices": []
            }
        }
    },
    "keke": {
        "name": "方可可",
        "emoji": "🎀",
        "avatar_color": Color("#f59e0b"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "keke",
                "text": "救命！转学生迷路第三天，教学楼B座到底怎么走啊，我又绕回食堂了！😭",
                "choices": [
                    {"text": "别慌，我画张校园地图发你，标了所有近道。", "next": "map_thanks", "aff": 5, "stress": -5},
                    {"text": "食堂也不错啊，说明你有干饭的天赋。", "next": "foodie_joke", "aff": 3, "stress": -3}
                ]
            },
            "map_thanks": {
                "sender": "keke",
                "text": "呜呜你是天使吧！地图收藏了！作为报答，请你喝我家乡最好喝的汽水！",
                "choices": [
                    {"text": "成交，明天见面交货。", "next": "end", "aff": 4, "stress": -3},
                    {"text": "不用报答啦，帮转学生带路是本校光荣传统。", "next": "end", "aff": 3, "stress": 0}
                ]
            },
            "foodie_joke": {
                "sender": "keke",
                "text": "喂！人家是路痴不是吃货！……好吧其实食堂三楼的糖醋排骨确实好吃。下次带你去！",
                "choices": [
                    {"text": "那我勉为其难当你的干饭搭子吧。", "next": "end", "aff": 4, "stress": 0},
                    {"text": "行，但带路费是一份糖醋排骨，先说好。", "next": "end", "aff": 3, "stress": -2}
                ]
            },
            "end": {
                "sender": "keke",
                "text": "（可可发来一排比心表情，看来已经把你标记成“在杭州第一个朋友”啦～）",
                "choices": []
            },
            "night_start": {
                "sender": "keke",
                "text": "呜……你还醒着吗？今天跟爸妈视频，看到我家楼下的桂花开了，突然有点想家。\n杭州明明也有桂花，闻起来却不太一样。",
                "choices": [
                    {"text": "等这边的桂花全开了，我带你去满觉陇，香到你想不起家里那棵。", "next": "night_guide", "aff": 6, "stress": -4},
                    {"text": "想家不丢人哦，说明那是个很好的家。", "next": "night_home", "aff": 5, "stress": -3}
                ]
            },
            "night_guide": {
                "sender": "keke",
                "text": "满觉陇？听名字就好香！好，说定了！\n……嘿嘿，跟你说完，突然觉得杭州也开始像“我的城市”了。",
                "choices": [
                    {"text": "本向导正式接单，桂花季不见不散。", "next": "night_end", "aff": 5, "stress": -3, "setFlag": "night_promise_keke"}
                ]
            },
            "night_home": {
                "sender": "keke",
                "text": "呜呜你怎么说话这么戳人啦！……嗯，是个很好的家。\n不过现在，这里也慢慢有很好的朋友了。比如你。",
                "choices": [
                    {"text": "以后想家了就来找我，随叫随到。", "next": "night_end", "aff": 5, "stress": -4}
                ]
            },
            "night_end": {
                "sender": "keke",
                "text": "（她发来一张贴着窗户拍的月亮，配字：杭州的月亮，今天也很圆哦～晚安！）",
                "choices": []
            }
        }
    },
    "beichen": {
        "name": "顾北辰",
        "emoji": "🌙",
        "avatar_color": Color("#a78bfa"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "beichen",
                "text": "物理笔记借我看一下。……上周病假落了两节课。",
                "choices": [
                    {"text": "给你，重点我都标了荧光笔。需要的话我讲一遍？", "next": "explain", "aff": 5, "stress": 2},
                    {"text": "可以是可以，不过你的“病假”，真的是生病吗？", "next": "evade", "aff": 2, "stress": 5}
                ]
            },
            "explain": {
                "sender": "beichen",
                "text": "……你讲得比老师慢，但是清楚。谢谢。改天还你一个人情。",
                "choices": [
                    {"text": "记账上了，利息是一杯热可可。", "next": "end", "aff": 4, "stress": -3},
                    {"text": "同学之间，不用记这种账。", "next": "end", "aff": 3, "stress": 0}
                ]
            },
            "evade": {
                "sender": "beichen",
                "text": "……你观察得很仔细。笔记先借我，其他的，以后再说。",
                "choices": [
                    {"text": "好，笔记明天给你。", "next": "end", "aff": 3, "stress": 0},
                    {"text": "行。不过“以后”这个词，我记住了。", "next": "end", "aff": 4, "stress": 2}
                ]
            },
            "end": {
                "sender": "beichen",
                "text": "（他很快退出了对话，但你注意到，他把你的消息设成了星标。）",
                "choices": []
            },
            "night_start": {
                "sender": "beichen",
                "text": "还醒着？\n刚才在阳台看月亮，突然想，这座城市里大概只有你会回我这种时间的消息。",
                "choices": [
                    {"text": "巧了，我也刚好在看月亮。今晚很亮。", "next": "night_moon", "aff": 6, "stress": -3},
                    {"text": "你总是这么晚睡，是有什么心事吗？", "next": "night_ask", "aff": 5, "stress": 2}
                ]
            },
            "night_moon": {
                "sender": "beichen",
                "text": "……同一个月亮。以前在旧学校，我从没想过会跟谁分享这种时刻。\n下个满月，平湖秋月，我带你去看真正的月亮。这是约定。",
                "choices": [
                    {"text": "好，约定了。不许放我鸽子。", "next": "night_end", "aff": 6, "stress": -4, "setFlag": "night_promise_beichen"}
                ]
            },
            "night_ask": {
                "sender": "beichen",
                "text": "心事……算是吧。转学的原因，我还没跟任何人说过。\n今晚先不说这个。但总有一天，我想让你第一个知道。",
                "choices": [
                    {"text": "不着急，我等你想说的那天。", "next": "night_end", "aff": 5, "stress": -3, "setFlag": "night_heart_beichen"}
                ]
            },
            "night_end": {
                "sender": "beichen",
                "text": "（他发来一张手机拍的月亮，有点糊，但很亮。）\n晚安。",
                "choices": []
            }
        }
    },
    "jingjing_m": {
        "name": "叶明轩",
        "emoji": "🌿",
        "avatar_color": Color("#e87d9a"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "jingjing_m",
                "text": "我妈炖了排骨汤让我给你端一碗，趁热。另外……小学毕业时埋在香樟树下的那个盒子，你还记得吗？",
                "choices": [
                    {"text": "当然记得！时间胶囊！我们约好初三毕业挖出来的！", "next": "capsule", "aff": 5, "stress": -5},
                    {"text": "什么盒子？……我只记得排骨汤，快端来！", "next": "soup", "aff": 3, "stress": -3}
                ]
            },
            "capsule": {
                "sender": "jingjing_m",
                "text": "你居然还记得。那就说定了，570天之后，香樟树下，谁都不许缺席。",
                "choices": [
                    {"text": "一言为定。", "next": "end", "aff": 5, "stress": 0, "setFlag": "capsule_promise_jmx"},
                    {"text": "缺席的那个人，负责挖土。", "next": "end", "aff": 4, "stress": -2}
                ]
            },
            "soup": {
                "sender": "jingjing_m",
                "text": "好好好，干饭要紧。盒子的事，等你哪天想起来再说——反正钥匙在我这。",
                "choices": [
                    {"text": "故弄玄虚！汤凉了你负责！", "next": "end", "aff": 3, "stress": -2},
                    {"text": "钥匙？喂，话说一半最讨厌了！", "next": "end", "aff": 2, "stress": 2}
                ]
            },
            "end": {
                "sender": "jingjing_m",
                "text": "（窗外传来自行车铃声，是他端着保温盒下楼了。）",
                "choices": []
            },
            "night_start": {
                "sender": "jingjing_m",
                "text": "你房间灯还亮着，别装，我阳台看得一清二楚。\n这么晚不睡，又在跟哪道题过不去？",
                "choices": [
                    {"text": "被你抓包了……确实卡在一道题上，脑子转不动了。", "next": "night_help", "aff": 5, "stress": 1},
                    {"text": "监视邻居睡觉，叶明轩你的爱好真高雅。", "next": "night_snark", "aff": 4, "stress": -3}
                ]
            },
            "night_help": {
                "sender": "jingjing_m",
                "text": "笨。题目拍给我，十分钟给你讲明白。\n——别误会，是你灯太亮晃得我睡不着，纯属自救。",
                "choices": [
                    {"text": "好好好，纯属自救。谢了，明轩。", "next": "night_end", "aff": 6, "stress": -5, "setFlag": "night_heart_jingjing_m"}
                ]
            },
            "night_snark": {
                "sender": "jingjing_m",
                "text": "谁监视你了，是你灯亮得跟灯塔似的！\n……行了，不管卡在哪，十二点前必须睡。从小到大你一熬夜第二天准感冒，我可不想再帮你抄一个星期笔记。",
                "choices": [
                    {"text": "那次的笔记我还留着呢。晚安，灯塔管理员。", "next": "night_end", "aff": 5, "stress": -4}
                ]
            },
            "night_end": {
                "sender": "jingjing_m",
                "text": "（对面阳台的灯闪了两下——是小时候约好的暗号：睡了，晚安。）",
                "choices": []
            }
        }
    },
    "zijun": {
        "name": "林紫君",
        "emoji": "🎨",
        "avatar_color": Color("#f59e0b"),
        "current_node": "start",
        "nodes": {
            "start": {
                "sender": "zijun",
                "text": "问你个事！校园艺术节的主题海报我入围了，但要在两版里选一版提交，你帮我看看？（发来两张草图）",
                "choices": [
                    {"text": "左边这版，湖的留白特别妙，一眼就是西湖。", "next": "pick_left", "aff": 5, "stress": -3},
                    {"text": "我不太懂画，但右边的颜色看着更热闹。", "next": "pick_right", "aff": 3, "stress": 0}
                ]
            },
            "pick_left": {
                "sender": "zijun",
                "text": "哇，你和我想的一样！就它了！等海报贴出来，右下角签名旁边我偷偷画了个小彩蛋，只告诉你哦。",
                "choices": [
                    {"text": "那我一定第一个去找彩蛋。", "next": "end", "aff": 4, "stress": 0},
                    {"text": "彩蛋？不会是把我画进去了吧？", "next": "end", "aff": 3, "stress": -2}
                ]
            },
            "pick_right": {
                "sender": "zijun",
                "text": "热闹……嗯，艺术节确实要热闹！你这个“外行视角”反而提醒我了，谢啦！",
                "choices": [
                    {"text": "能帮上忙就好，加油！", "next": "end", "aff": 3, "stress": -3},
                    {"text": "外行也有外行的用处嘛，随时找我。", "next": "end", "aff": 2, "stress": 0}
                ]
            },
            "end": {
                "sender": "zijun",
                "text": "（她的头像亮着，大概正趴在画板前赶稿吧。）",
                "choices": []
            },
            "night_start": {
                "sender": "zijun",
                "text": "还没睡？哼，正好。艺术节的海报……评委说要大改。\n我盯着画板两个小时了，一笔都下不去。",
                "choices": [
                    {"text": "评委只看五分钟，我可看了你画画一学期。那张画很好。", "next": "night_true", "aff": 6, "stress": -4},
                    {"text": "改不动就先不改。给我讲讲，你最喜欢那张画的哪里？", "next": "night_talk", "aff": 5, "stress": -3}
                ]
            },
            "night_true": {
                "sender": "zijun",
                "text": "……你、你这个人，怎么突然说这种话啦！（隔了很久才回复）\n不过，谢谢。评委的意见我会听，但湖边那块留白，我谁的都不听——那是要留给懂它的人的。",
                "choices": [
                    {"text": "那块留白，我会一直懂。", "next": "night_end", "aff": 6, "stress": -4, "setFlag": "night_heart_zijun"}
                ]
            },
            "night_talk": {
                "sender": "zijun",
                "text": "最喜欢的……是右下角那只纸船。小时候我在断桥边放过一只一模一样的。\n……说出来的瞬间突然就知道该怎么改了！把纸船画大一点，管评委怎么说！",
                "choices": [
                    {"text": "对，把你的纸船画大一点。", "next": "night_end", "aff": 5, "stress": -3}
                ]
            },
            "night_end": {
                "sender": "zijun",
                "text": "（凌晨的聊天框安静下来。第二天，你会看到她顶着黑眼圈、得意洋洋地展示新海报。）",
                "choices": []
            }
        }
    }
}

func _ready():
    # ── 自身全屏遮罩铺设（手动设置，避开 Godot 4 在 dynamic 实例化时的布局 preset 缓存 Bug） ──
    anchor_left = 0.0
    anchor_top = 0.0
    anchor_right = 1.0
    anchor_bottom = 1.0
    offset_left = 0
    offset_top = 0
    offset_right = 0
    offset_bottom = 0

    # 铺设全屏半透明遮罩
    var barrier = StyleBoxFlat.new()
    barrier.bg_color = Color(0, 0, 0, 0.45)
    add_theme_stylebox_override("panel", barrier)
    
    # 创建手机框 PanelContainer
    phone_frame = PanelContainer.new()
    phone_frame.custom_minimum_size = Vector2(380, 620)
    
    var frame_style = StyleBoxFlat.new()
    frame_style.bg_color = bg_color
    frame_style.corner_radius_top_left = 28
    frame_style.corner_radius_top_right = 28
    frame_style.corner_radius_bottom_left = 28
    frame_style.corner_radius_bottom_right = 28
    frame_style.border_width_left = 6
    frame_style.border_width_right = 6
    frame_style.border_width_top = 8
    frame_style.border_width_bottom = 8
    frame_style.border_color = Color("#1C1C1E") # 手机黑色外框
    frame_style.shadow_color = Color(0, 0, 0, 0.3)
    frame_style.shadow_size = 20
    phone_frame.add_theme_stylebox_override("panel", frame_style)
    
    # ── 手机框绝对物理居中定位（380x620 尺寸下，利用 offset 精准对齐） ──
    phone_frame.anchor_left = 0.5
    phone_frame.anchor_top = 0.5
    phone_frame.anchor_right = 0.5
    phone_frame.anchor_bottom = 0.5
    phone_frame.offset_left = -190
    phone_frame.offset_top = -310
    phone_frame.offset_right = 190
    phone_frame.offset_bottom = 310
    add_child(phone_frame)
    
    # 手机内部垂直布局 (VBoxContainer)
    var phone_vbox = VBoxContainer.new()
    phone_vbox.theme_type_variation = ""
    phone_vbox.add_theme_constant_override("separation", 0)
    phone_frame.add_child(phone_vbox)
    
    # ── 1. 微信头部 Bar ──────────────────────────────
    var header = Panel.new()
    header.custom_minimum_size = Vector2(0, 52)
    var header_style = StyleBoxFlat.new()
    header_style.bg_color = Color("#F3F3F3")
    header_style.border_width_bottom = 1
    header_style.border_color = Color("#D6D6D6")
    header_style.corner_radius_top_left = 20
    header_style.corner_radius_top_right = 20
    header.add_theme_stylebox_override("panel", header_style)
    phone_vbox.add_child(header)
    
    # 头部内部 HBox 布局（撑满整个 header）
    var header_hbox = HBoxContainer.new()
    header_hbox.anchors_preset = Control.PRESET_FULL_RECT
    header_hbox.add_theme_constant_override("separation", 0)
    header.add_child(header_hbox)
    
    var btn_style_empty = StyleBoxEmpty.new()
    
    # 左区：返回按钮（固定宽度）
    back_btn = Button.new()
    back_btn.text = "◀ 微信"
    back_btn.custom_minimum_size = Vector2(80, 0)
    back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    back_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    back_btn.add_theme_stylebox_override("normal", btn_style_empty)
    back_btn.add_theme_stylebox_override("hover", btn_style_empty)
    back_btn.add_theme_stylebox_override("pressed", btn_style_empty)
    back_btn.add_theme_stylebox_override("focus", btn_style_empty)
    back_btn.add_theme_color_override("font_color", Color("#07C160"))
    back_btn.add_theme_color_override("font_hover_color", Color("#05A952"))
    back_btn.add_theme_font_size_override("font_size", 13)
    back_btn.pressed.connect(_on_back_pressed)
    header_hbox.add_child(back_btn)
    
    # 中区：标题（弹性填充）
    header_title = Label.new()
    header_title.text = "微信"
    header_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
    header_title.add_theme_color_override("font_color", Color("#191919"))
    header_title.add_theme_font_size_override("font_size", 16)
    header_hbox.add_child(header_title)
    
    # 右区：关闭按钮（固定宽度，与左区对称）
    var close_btn = Button.new()
    close_btn.text = "✕"
    close_btn.custom_minimum_size = Vector2(80, 0)
    close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
    close_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    close_btn.add_theme_stylebox_override("normal", btn_style_empty)
    close_btn.add_theme_stylebox_override("hover", btn_style_empty)
    close_btn.add_theme_stylebox_override("pressed", btn_style_empty)
    close_btn.add_theme_stylebox_override("focus", btn_style_empty)
    close_btn.add_theme_color_override("font_color", Color("#888888"))
    close_btn.add_theme_color_override("font_hover_color", Color("#555555"))
    close_btn.add_theme_font_size_override("font_size", 14)
    close_btn.pressed.connect(_on_close_clicked)
    header_hbox.add_child(close_btn)
    
    # ── 2. 主体区 (列表 / 聊天) ──────────────────────────────
    # A. 列表 ScrollContainer
    chat_list_scroll = ScrollContainer.new()
    chat_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    chat_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    phone_vbox.add_child(chat_list_scroll)
    
    chat_list_container = VBoxContainer.new()
    chat_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_list_container.add_theme_constant_override("separation", 0)
    chat_list_scroll.add_child(chat_list_container)
    
    # C. 朋友圈 ScrollContainer & Layout (默认隐藏)
    moments_scroll = ScrollContainer.new()
    moments_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    moments_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    moments_scroll.hide()
    phone_vbox.add_child(moments_scroll)
    
    moments_container = VBoxContainer.new()
    moments_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    moments_container.add_theme_constant_override("separation", 0)
    moments_scroll.add_child(moments_container)
    
    # B. 聊天 ScrollContainer & Layout (默认隐藏)
    active_chat_view = VBoxContainer.new()
    active_chat_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
    active_chat_view.add_theme_constant_override("separation", 0)
    active_chat_view.hide()
    phone_vbox.add_child(active_chat_view)
    
    active_chat_scroll = ScrollContainer.new()
    active_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    active_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    active_chat_view.add_child(active_chat_scroll)
    
    bubble_container = VBoxContainer.new()
    bubble_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bubble_container.add_theme_constant_override("separation", 14)
    active_chat_scroll.add_child(bubble_container)
    
    # ── 3. 底部栏 (输入栏 / 选择气泡) ────────────────────────
    input_bar = Panel.new()
    input_bar.custom_minimum_size = Vector2(0, 50)
    var input_style = StyleBoxFlat.new()
    input_style.bg_color = Color("#F7F7F7")
    input_style.border_width_top = 1
    input_style.border_color = Color("#D6D6D6")
    input_style.corner_radius_bottom_left = 20
    input_style.corner_radius_bottom_right = 20
    input_bar.add_theme_stylebox_override("panel", input_style)
    phone_vbox.add_child(input_bar)
    
    # 底部栏上方弹出选项 VBox
    choices_container = VBoxContainer.new()
    choices_container.custom_minimum_size = Vector2(0, 0)
    choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    choices_container.add_theme_constant_override("separation", 6)
    active_chat_view.add_child(choices_container)
    
    # 模拟微信键盘框
    var keyboard_mock = Label.new()
    keyboard_mock.text = "   [⌨️ 微信安全输入法]"
    keyboard_mock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    keyboard_mock.anchors_preset = Control.PRESET_FULL_RECT
    keyboard_mock.add_theme_color_override("font_color", Color("#B0B0B0"))
    keyboard_mock.add_theme_font_size_override("font_size", 15)
    input_bar.add_child(keyboard_mock)
    
    # ── 4. 微信底部 Tab 导航条 ──
    tab_bar = Panel.new()
    tab_bar.custom_minimum_size = Vector2(0, 50)
    var tab_style = StyleBoxFlat.new()
    tab_style.bg_color = Color("#F7F7F7")
    tab_style.border_width_top = 1
    tab_style.border_color = Color("#E3E3E3")
    tab_style.corner_radius_bottom_left = 20
    tab_style.corner_radius_bottom_right = 20
    tab_bar.add_theme_stylebox_override("panel", tab_style)
    phone_vbox.add_child(tab_bar)
    
    var tab_hbox = HBoxContainer.new()
    tab_hbox.anchors_preset = Control.PRESET_FULL_RECT
    tab_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    tab_hbox.add_theme_constant_override("separation", 0)
    tab_bar.add_child(tab_hbox)
    
    # 微信聊天列表 Tab 按钮
    chat_tab_btn = Button.new()
    chat_tab_btn.text = "💬 微信"
    chat_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    chat_tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    chat_tab_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    chat_tab_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
    chat_tab_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
    chat_tab_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    chat_tab_btn.add_theme_color_override("font_color", Color("#07C160")) # 选中绿
    chat_tab_btn.add_theme_font_size_override("font_size", 13)
    chat_tab_btn.pressed.connect(_on_chat_tab_pressed)
    tab_hbox.add_child(chat_tab_btn)
    
    # 朋友圈 Tab 按钮
    moments_tab_btn = Button.new()
    moments_tab_btn.text = "✨ 朋友圈"
    moments_tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    moments_tab_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    moments_tab_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    moments_tab_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
    moments_tab_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
    moments_tab_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    moments_tab_btn.add_theme_color_override("font_color", Color("#7c7c7c")) # 未选中灰
    moments_tab_btn.add_theme_font_size_override("font_size", 13)
    moments_tab_btn.pressed.connect(_on_moments_tab_pressed)
    tab_hbox.add_child(moments_tab_btn)
    
    # 计时器
    typing_timer = Timer.new()
    typing_timer.one_shot = true
    typing_timer.timeout.connect(_on_typing_finished)
    add_child(typing_timer)
    
    # 从全局 GameManager.flags 恢复各个角色的聊天节点进度，并动态合并 GameManager.char_meta 数据源
    for char_id in chats_db.keys():
        var flag_node_key = "wechat_node_" + char_id
        if GameManager.flags.has(flag_node_key):
            chats_db[char_id].current_node = GameManager.flags[flag_node_key]
            
        var meta = GameManager.char_meta.get(char_id, {})
        if not meta.is_empty():
            chats_db[char_id]["name"] = meta.get("name", chats_db[char_id].get("name", ""))
            chats_db[char_id]["emoji"] = meta.get("emoji", chats_db[char_id].get("emoji", ""))
            chats_db[char_id]["avatar_color"] = Color(meta.get("color", "#4A7BB7"))
            
    # 渲染首页列表
    build_chat_list()
    update_navigation_bar()

# ── 构建列表首页 ───────────────────────────────────────────
func build_chat_list():
    for child in chat_list_container.get_children():
        child.queue_free()
        
    for char_id in chats_db.keys():
        var chat = chats_db[char_id]
        
        # 卡片容器
        var card = Button.new()
        card.custom_minimum_size = Vector2(0, 72)
        card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        
        # 卡片背景样式
        var normal_style = StyleBoxFlat.new()
        normal_style.bg_color = Color("#FFFFFF")
        normal_style.border_width_bottom = 1
        normal_style.border_color = Color("#F2F2F2")
        card.add_theme_stylebox_override("normal", normal_style)
        
        var hover_style = normal_style.duplicate()
        hover_style.bg_color = Color("#F5F5F5")
        card.add_theme_stylebox_override("hover", hover_style)
        card.add_theme_stylebox_override("pressed", hover_style)
        card.add_theme_stylebox_override("focus", hover_style)
        
        # 卡片内部布局
        var hbox = HBoxContainer.new()
        hbox.anchors_preset = Control.PRESET_FULL_RECT
        hbox.add_theme_constant_override("separation", 12)
        hbox.layout_mode = 1
        hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        hbox.size_flags_vertical = Control.SIZE_FILL
        card.add_child(hbox)
        
        # 占位间距
        var spacer = Control.new()
        spacer.custom_minimum_size = Vector2(4, 0)
        hbox.add_child(spacer)
        
        # 头像
        var avatar = Panel.new()
        avatar.custom_minimum_size = Vector2(46, 46)
        avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        var av_style = StyleBoxFlat.new()
        av_style.bg_color = chat.avatar_color
        av_style.corner_radius_top_left = 6
        av_style.corner_radius_top_right = 6
        av_style.corner_radius_bottom_left = 6
        av_style.corner_radius_bottom_right = 6
        avatar.add_theme_stylebox_override("panel", av_style)
        hbox.add_child(avatar)
        
        # 头像字
        var av_lbl = Label.new()
        av_lbl.text = chat.emoji
        av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        av_lbl.anchors_preset = Control.PRESET_FULL_RECT
        av_lbl.add_theme_font_size_override("font_size", 20)
        avatar.add_child(av_lbl)
        
        # 红点未读标志 (如果还是起始状态，标红点)
        if chat.current_node == "start":
            var badge = Panel.new()
            badge.custom_minimum_size = Vector2(9, 9)
            var badge_style = StyleBoxFlat.new()
            badge_style.bg_color = Color("#FA5151") # 微信红点色
            badge_style.corner_radius_top_left = 5; badge_style.corner_radius_top_right = 5
            badge_style.corner_radius_bottom_left = 5; badge_style.corner_radius_bottom_right = 5
            badge.add_theme_stylebox_override("panel", badge_style)
            # 定位在头像右上角
            badge.position = Vector2(38, -2)
            avatar.add_child(badge)
            
        # 文字垂直叠放 (名字 + 预览)
        var vbox = VBoxContainer.new()
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        vbox.add_theme_constant_override("separation", 4)
        hbox.add_child(vbox)
        
        # 名字
        var name_lbl = Label.new()
        name_lbl.text = chat.name
        name_lbl.add_theme_color_override("font_color", Color("#191919"))
        name_lbl.add_theme_font_size_override("font_size", 15)
        vbox.add_child(name_lbl)
        
        # 预览消息 (取当前节点文本)
        var preview_lbl = Label.new()
        var node = chat.nodes[chat.current_node]
        var preview_text = node.text.replace("\n", " ")
        if preview_text.length() > 16:
            preview_text = preview_text.substr(0, 15) + "..."
        preview_lbl.text = preview_text
        preview_lbl.add_theme_color_override("font_color", Color("#999999"))
        preview_lbl.add_theme_font_size_override("font_size", 15)
        vbox.add_child(preview_lbl)
        
        # 主动消息检测：若该角色有待处理的主动微信消息，覆盖预览并显示金色高亮边框
        var wechat_msgs = GameManager.get_pending_wechat_msgs()
        var initiative_msg = ""
        for wm in wechat_msgs:
            if wm["char_id"] == char_id:
                initiative_msg = wm["message"]
                break

        # 深夜消息标记：同为 pending，但用月光蓝 + [深夜] 前缀区分
        var is_night_msg = GameManager.flags.get("night_chat_pending_" + char_id, false)

        if initiative_msg != "":
            # 高亮边框（深夜=月光蓝 / 普通主动=金色）
            var hl_style = normal_style.duplicate()
            hl_style.border_width_left   = 2; hl_style.border_width_right  = 2
            hl_style.border_width_top    = 2; hl_style.border_width_bottom = 2
            hl_style.border_color = Color("#7DA7D9") if is_night_msg else Color(1.0, 0.84, 0.0, 0.85)
            card.add_theme_stylebox_override("normal", hl_style)
            # 强制红点（主动消息 badge）
            var badge2 = Panel.new()
            badge2.custom_minimum_size = Vector2(9, 9)
            var badge2_style = StyleBoxFlat.new()
            badge2_style.bg_color = Color("#FA5151")
            badge2_style.corner_radius_top_left = 5; badge2_style.corner_radius_top_right = 5
            badge2_style.corner_radius_bottom_left = 5; badge2_style.corner_radius_bottom_right = 5
            badge2.add_theme_stylebox_override("panel", badge2_style)
            badge2.position = Vector2(38, -2)
            avatar.add_child(badge2)
            # 预览文字改为主动消息预览
            var prev = initiative_msg if initiative_msg.length() <= 16 else initiative_msg.substr(0, 15) + "..."
            preview_lbl.text = ("[深夜] " if is_night_msg else "[主动] ") + prev
            preview_lbl.add_theme_color_override("font_color", Color("#7DA7D9") if is_night_msg else Color(1.0, 0.84, 0.0))

        # 绑定点击
        var cid = char_id
        card.pressed.connect(func(): _on_chat_card_clicked(cid))
        chat_list_container.add_child(card)

# ── 点击某位角色聊天卡片 ────────────────────────────────────
func _on_chat_card_clicked(char_id: String):
    active_char_id = char_id
    chat_list_scroll.hide()
    moments_scroll.hide()
    active_chat_view.show()
    
    var chat = chats_db[char_id]
    header_title.text = chat.name
    back_btn.text = "  ◀ 微信"

    # ── 主动消息注入：若该角色有待处理的主动微信消息，将其写入聊天历史 ──
    var wechat_msgs = GameManager.get_pending_wechat_msgs()
    var injected_msg = false
    for wm in wechat_msgs:
        if wm["char_id"] == char_id:
            var history_key = "wechat_history_" + char_id
            var history = []
            if GameManager.flags.has(history_key):
                history = GameManager.flags[history_key].duplicate(true)
            # 在历史末尾追加角色的主动消息气泡
            history.append({"sender": char_id, "text": wm["message"]})
            GameManager.flags[history_key] = history
            # 消费该消息，避免重复显示
            GameManager.consume_wechat_msg(char_id)
            injected_msg = true
            break

    # ── 深夜聊天路由：注入的开场白即 night_start 文本，此处把节点指针切到深夜树 ──
    _night_open = false
    if GameManager.flags.get("night_chat_pending_" + char_id, false):
        _night_open = true
        # 兜底：若深夜消息已过期被清空（未注入气泡），此处补上 night_start 文本，
        # 避免出现“只有深夜选项、没有深夜消息”的错位显示
        if not injected_msg:
            var n_key = "wechat_history_" + char_id
            var n_hist = []
            if GameManager.flags.has(n_key):
                n_hist = GameManager.flags[n_key].duplicate(true)
            n_hist.append({"sender": char_id, "text": chats_db[char_id].nodes["night_start"].text})
            GameManager.flags[n_key] = n_hist
        chats_db[char_id].current_node = "night_start"
        GameManager.flags["wechat_node_" + char_id] = "night_start"
        GameManager.set_flag("night_chat_pending_" + char_id, false)

    update_navigation_bar()
    # 重建当前对话记录
    rebuild_bubble_history()


# ── 根据当前剧情节点加载/刷新聊天历史泡泡 ───────────
func rebuild_bubble_history():
    for child in bubble_container.get_children():
        child.queue_free()
    
    for child in choices_container.get_children():
        child.queue_free()
        
    var chat = chats_db[active_char_id]
    var current_id = chat.current_node
    
    # 微信首行时间戳气泡（按当前时段动态显示；深夜消息注入时显示深夜时间）
    append_timestamp_bubble(_get_chat_timestamp())
    
    # 获取或初始化全局保存的聊天历史
    var history_key = "wechat_history_" + active_char_id
    var history = []
    if GameManager.flags.has(history_key):
        history = GameManager.flags[history_key].duplicate(true)
    
    # 如果历史为空，说明第一次开启聊天，把起始节点的第一句话放入历史
    if history.is_empty():
        var start_node = chat.nodes["start"]
        history.append({"sender": start_node.sender, "text": start_node.text})
        GameManager.flags[history_key] = history
    
    # 依次绘制所有历史记录中的气泡
    for msg in history:
        append_msg_bubble(msg.get("sender", "player"), msg.get("text", ""))
    
    # 加载当前节点的底部选项
    var current_node = chat.nodes[current_id]
    load_choices(current_node.choices)
    
    # 延时滚到底部
    await get_tree().process_frame
    active_chat_scroll.scroll_vertical = int(bubble_container.size.y)

# ── 辅助：按当前时段生成聊天时间戳文案 ─────────────────────
func _get_chat_timestamp() -> String:
    if _night_open:
        return "深夜 23:47"
    var slot_labels = {
        "morning": "上午 10:20",
        "noon":    "中午 12:35",
        "after":   "下午 17:05",
        "evening": "晚上 21:15"
    }
    return slot_labels.get(GameManager._get_slot_id(), "晚上 21:15")

# ── 装载选项气泡 ──────────────────────────────────────────
func load_choices(choices: Array):
    for child in choices_container.get_children():
        child.queue_free()
        
    if choices.is_empty():
        # 聊天已结束，提供一个“返回”键
        var finish_btn = Button.new()
        finish_btn.text = " 💬 结束微信聊天，放下手机 "
        style_choice_button(finish_btn)
        finish_btn.pressed.connect(_on_back_pressed)
        choices_container.add_child(finish_btn)
        return
        
    for i in range(choices.size()):
        var choice = choices[i]
        var btn = Button.new()
        btn.text = choice.text
        style_choice_button(btn)
        
        # 点击选项发送
        btn.pressed.connect(func(): _on_choice_selected(choice))
        choices_container.add_child(btn)

func style_choice_button(btn: Button):
    btn.custom_minimum_size = Vector2(0, 42)
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    btn.add_theme_font_size_override("font_size", 13)
    btn.add_theme_color_override("font_color", Color("#333333"))
    btn.add_theme_color_override("font_hover_color", Color("#07C160"))
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color("#FFFFFF")
    style.corner_radius_top_left = 20
    style.corner_radius_top_right = 20
    style.corner_radius_bottom_left = 20
    style.corner_radius_bottom_right = 20
    style.border_width_left = 1; style.border_width_right = 1
    style.border_width_top = 1; style.border_width_bottom = 1
    style.border_color = Color("#E0E0E0")
    style.content_margin_left = 12; style.content_margin_right = 12
    btn.add_theme_stylebox_override("normal", style)
    
    var hover = style.duplicate()
    hover.border_color = Color("#07C160")
    hover.bg_color = Color("#F3FCF5")
    btn.add_theme_stylebox_override("hover", hover)
    btn.add_theme_stylebox_override("pressed", hover)
    btn.add_theme_stylebox_override("focus", hover)

# ── 选项选中，发送并进入“对方正在输入” ─────────────
func _on_choice_selected(choice: Dictionary):
    # 1. 禁用所有当前选项
    for child in choices_container.get_children():
        if child is Button: child.disabled = true
        
    # 2. 玩家气泡发送，并记录到全局聊天历史中
    append_msg_bubble("player", choice.text)
    
    var history_key = "wechat_history_" + active_char_id
    var history = []
    if GameManager.flags.has(history_key):
        history = GameManager.flags[history_key].duplicate(true)
    history.append({"sender": "player", "text": choice.text})
    GameManager.flags[history_key] = history
    
    # 滚到底部
    await get_tree().process_frame
    active_chat_scroll.scroll_vertical = int(bubble_container.size.y)
    
    # 3. 立即应用属性奖励
    apply_rewards(choice)

    # ── 成就联动：微信回复计数 ──
    if is_instance_valid(AchievementManager):
        AchievementManager.add_counter("wechat_reply_count", 1)
        AchievementManager.check_all()
    
    # 4. 进入微信经典的“对方正在输入...”状态，极具拟真浪漫感！
    header_title.text = "对方正在输入..."
    
    # 启动打字机倒计时 (0.8s ~ 1.5s 随机)
    typing_timer.start(randf_range(0.8, 1.4))
    
    # 存下下一个剧情节点，并实时同步到全局 flags 字典
    var chat = chats_db[active_char_id]
    chat.current_node = choice.next
    GameManager.flags["wechat_node_" + active_char_id] = choice.next

# ── 对方输入完成，女孩气泡弹出 ─────────────────────────
func _on_typing_finished():
    var chat = chats_db[active_char_id]
    header_title.text = chat.name
    
    # 渲染新的一行
    var current_node = chat.current_node
    var node = chat.nodes[current_node]
    
    append_msg_bubble(node.sender, node.text)
    
    # 保存女孩的回复到全局聊天历史中
    var history_key = "wechat_history_" + active_char_id
    var history = []
    if GameManager.flags.has(history_key):
        history = GameManager.flags[history_key].duplicate(true)
    history.append({"sender": node.sender, "text": node.text})
    GameManager.flags[history_key] = history
    
    # 装载下一个选项
    load_choices(node.choices)
    
    # 滚到底部
    await get_tree().process_frame
    active_chat_scroll.scroll_vertical = int(bubble_container.size.y)

# ── 微信系统数据应用器 ───────────────────────────
func apply_rewards(choice: Dictionary):
    # 增加好感度 (经过全局0.4x平滑，由add_favor处理)
    var aff = choice.get("aff", 0)
    if aff != 0:
        GameManager.add_favor(active_char_id, aff)
        
    # 增减压力
    var stress = choice.get("stress", 0)
    if stress != 0:
        GameManager.add_stat("stress", stress)
        
    # 触发特定微信约会标志位 (例如 seen_wechat_date)
    var set_flag = choice.get("setFlag", "")
    if set_flag != "":
        GameManager.set_flag(set_flag, true)

# ── 构建气泡 UI Row (核心排版布局) ──────────────────────
func append_msg_bubble(sender: String, message_text: String):
    # 最外层容器 HBox
    var row = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 8)
    bubble_container.add_child(row)
    
    # 占位符 (头像和边距)
    var spacer_left = Control.new()
    spacer_left.custom_minimum_size = Vector2(6, 0)
    row.add_child(spacer_left)
    
    # 头像 (Panel)
    var avatar = Panel.new()
    avatar.custom_minimum_size = Vector2(38, 38)
    avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    
    var av_style = StyleBoxFlat.new()
    av_style.corner_radius_top_left = 4; av_style.corner_radius_top_right = 4
    av_style.corner_radius_bottom_left = 4; av_style.corner_radius_bottom_right = 4
    
    var av_lbl = Label.new()
    av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    av_lbl.anchors_preset = Control.PRESET_FULL_RECT
    av_lbl.add_theme_font_size_override("font_size", 16)
    
    if sender == "player":
        # 男主发，头像靠右
        row.move_child(spacer_left, row.get_child_count() - 1)
        
        # 占位弹簧把气泡挤到右侧
        var spring = Control.new()
        spring.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(spring)
        row.move_child(spring, 0) # 插入到最左边
        
        av_style.bg_color = Color("#4D4D4D") # 主角暗灰色头像
        avatar.add_theme_stylebox_override("panel", av_style)
        av_lbl.text = "👤"
        avatar.add_child(av_lbl)
        row.add_child(avatar)
    else:
        # 攻略对象发，头像靠左
        var chat = chats_db[active_char_id]
        av_style.bg_color = chat.avatar_color
        avatar.add_theme_stylebox_override("panel", av_style)
        av_lbl.text = chat.emoji
        avatar.add_child(av_lbl)
        row.add_child(avatar)
        row.move_child(avatar, 1) # 刚好在 spacer_left 后面
        
    # 文本气泡面板 (PanelContainer)
    var bubble = PanelContainer.new()
    bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    
    var bubble_style = StyleBoxFlat.new()
    bubble_style.content_margin_left = 10; bubble_style.content_margin_right = 10
    bubble_style.content_margin_top = 8; bubble_style.content_margin_bottom = 8
    bubble_style.corner_radius_top_left = 6; bubble_style.corner_radius_top_right = 6
    bubble_style.corner_radius_bottom_left = 6; bubble_style.corner_radius_bottom_right = 6
    
    if sender == "player":
        GameManager.flags["achv_wechat_chatted"] = true
        if _night_open:
            GameManager.flags["achv_night_owl"] = true
        if is_instance_valid(AchievementManager):
            AchievementManager.check_all()
        bubble_style.bg_color = wechat_green # 经典绿泡泡
        bubble.add_theme_stylebox_override("panel", bubble_style)
        row.add_child(bubble)
        row.move_child(bubble, row.get_child_count() - 2) # 仅在头像左侧
    else:
        bubble_style.bg_color = Color("#FFFFFF") # 经典白泡泡
        bubble.add_theme_stylebox_override("panel", bubble_style)
        row.add_child(bubble)
        
    # 文本 Label
    var lbl = Label.new()
    lbl.text = message_text
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.custom_minimum_size = Vector2(160, 0)
    lbl.add_theme_color_override("font_color", Color("#191919"))
    lbl.add_theme_font_size_override("font_size", 15)
    bubble.add_child(lbl)
    
    # 右侧补足间距 (左侧发时右侧挤压)
    if sender != "player":
        var spring_right = Control.new()
        spring_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(spring_right)
        
    var spacer_right = Control.new()
    spacer_right.custom_minimum_size = Vector2(6, 0)
    row.add_child(spacer_right)

# ── 辅助：系统时间戳气泡 ─────────────────────────────────────
func append_timestamp_bubble(text_str: String):
    var row = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    bubble_container.add_child(row)
    
    var label = Label.new()
    label.text = "  %s  " % text_str
    label.add_theme_color_override("font_color", Color("#FFFFFF"))
    label.add_theme_font_size_override("font_size", 14)
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.12)
    style.corner_radius_top_left = 4; style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4; style.corner_radius_bottom_right = 4
    style.content_margin_left = 6; style.content_margin_right = 6
    style.content_margin_top = 2; style.content_margin_bottom = 2
    label.add_theme_stylebox_override("normal", style)
    row.add_child(label)

# ── 导航条同步 ───────────────────────────────────────────
func update_navigation_bar():
    if chat_list_scroll.visible or moments_scroll.visible:
        if chat_list_scroll.visible:
            var active_count = 0
            for char_id in chats_db.keys():
                if chats_db[char_id].current_node == "start":
                    active_count += 1
            if active_count > 0:
                header_title.text = "微信 (%d)" % active_count
            else:
                header_title.text = "微信"
        else:
            header_title.text = "朋友圈"
        back_btn.hide()
        tab_bar.show()
        input_bar.hide()
    else:
        back_btn.show()
        tab_bar.hide()
        input_bar.show()

# ── 返回按钮 pressed ──────────────────────────────────────
func _on_back_pressed():
    if active_chat_view.visible:
        # 退出聊天室，回退到微信列表首页
        active_chat_view.hide()
        chat_list_scroll.show()
        moments_scroll.hide()
        chat_tab_btn.add_theme_color_override("font_color", Color("#07C160"))
        moments_tab_btn.add_theme_color_override("font_color", Color("#7c7c7c"))
        build_chat_list()
        update_navigation_bar()
    else:
        # 已经在列表首页，关闭微信
        _on_close_clicked()

# ── 关闭微信/退出 ────────────────────────────────────────
func _on_close_clicked():
    closed.emit()
    queue_free()


# ── 朋友圈 Tab 选中与加载 ─────────────────────────────────
func _on_chat_tab_pressed():
    moments_scroll.hide()
    chat_list_scroll.show()
    chat_tab_btn.add_theme_color_override("font_color", Color("#07C160"))
    moments_tab_btn.add_theme_color_override("font_color", Color("#7c7c7c"))
    build_chat_list()
    update_navigation_bar()

func _on_moments_tab_pressed():
    chat_list_scroll.hide()
    moments_scroll.show()
    chat_tab_btn.add_theme_color_override("font_color", Color("#7c7c7c"))
    moments_tab_btn.add_theme_color_override("font_color", Color("#07C160"))
    build_moments_list()
    update_navigation_bar()

func build_moments_list():
    for child in moments_container.get_children():
        child.queue_free()
        
    # 1. 朋友圈封面
    var cover = Panel.new()
    cover.custom_minimum_size = Vector2(0, 130)
    var cover_style = StyleBoxFlat.new()
    cover_style.bg_color = Color("#38bdf8") # 天蓝色天空
    cover_style.border_width_bottom = 2
    cover_style.border_color = Color("#cbd5e1")
    cover.add_theme_stylebox_override("panel", cover_style)
    moments_container.add_child(cover)
    
    # 封面右下角名片
    var profile_hbox = HBoxContainer.new()
    profile_hbox.anchors_preset = Control.PRESET_BOTTOM_RIGHT
    profile_hbox.offset_right = -15
    profile_hbox.offset_bottom = -12
    profile_hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    profile_hbox.grow_vertical = Control.GROW_DIRECTION_BEGIN
    cover.add_child(profile_hbox)
    
    var name_lbl = Label.new()
    name_lbl.text = GameManager.player_name + "  "
    name_lbl.add_theme_color_override("font_color", Color("#ffffff"))
    name_lbl.add_theme_font_size_override("font_size", 14)
    name_lbl.add_theme_constant_override("outline_size", 4)
    name_lbl.add_theme_color_override("font_outline_color", Color("#000000"))
    name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    profile_hbox.add_child(name_lbl)
    
    var av_panel = Panel.new()
    av_panel.custom_minimum_size = Vector2(40, 40)
    var av_style = StyleBoxFlat.new()
    av_style.bg_color = Color("#475569")
    av_style.corner_radius_top_left = 6; av_style.corner_radius_top_right = 6
    av_style.corner_radius_bottom_left = 6; av_style.corner_radius_bottom_right = 6
    av_style.border_width_left = 2; av_style.border_width_right = 2
    av_style.border_width_top = 2; av_style.border_width_bottom = 2
    av_style.border_color = Color("#FFFFFF")
    av_panel.add_theme_stylebox_override("panel", av_style)
    profile_hbox.add_child(av_panel)
    
    var av_lbl = Label.new()
    av_lbl.text = "👤"
    av_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    av_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    av_lbl.anchors_preset = Control.PRESET_FULL_RECT
    av_lbl.add_theme_font_size_override("font_size", 18)
    av_panel.add_child(av_lbl)
    
    # 2. 遍历加载朋友圈帖子 (反序展示最新)
    var current_day = GameManager.day
    var has_any_post = false
    
    for idx in range(moments_db.size() - 1, -1, -1):
        var post = moments_db[idx]
        if current_day < post.unlock_day:
            continue
            
        has_any_post = true
        var char_id = post.char_id
        var char_info = GameManager.char_meta.get(char_id, {})
        var char_name = char_info.get("name", char_id)
        var char_emoji = char_info.get("emoji", "🌸")
        var char_color = Color(char_info.get("color", "#475569"))
        
        # 帖子容器
        var post_box = VBoxContainer.new()
        post_box.add_theme_constant_override("separation", 8)
        
        var row = PanelContainer.new()
        var row_style = StyleBoxFlat.new()
        row_style.bg_color = Color("#FFFFFF")
        row_style.border_width_bottom = 1
        row_style.border_color = Color("#E5E7EB")
        row_style.content_margin_left = 12; row_style.content_margin_right = 12
        row_style.content_margin_top = 12; row_style.content_margin_bottom = 12
        row.add_theme_stylebox_override("panel", row_style)
        row.add_child(post_box)
        moments_container.add_child(row)
        
        # A. 作者信息
        var auth_hbox = HBoxContainer.new()
        auth_hbox.add_theme_constant_override("separation", 8)
        post_box.add_child(auth_hbox)
        
        var avatar = Panel.new()
        avatar.custom_minimum_size = Vector2(36, 36)
        var avatar_style = StyleBoxFlat.new()
        avatar_style.bg_color = char_color
        avatar_style.corner_radius_top_left = 6; avatar_style.corner_radius_top_right = 6
        avatar_style.corner_radius_bottom_left = 6; avatar_style.corner_radius_bottom_right = 6
        avatar.add_theme_stylebox_override("panel", avatar_style)
        auth_hbox.add_child(avatar)
        
        var av_txt = Label.new()
        av_txt.text = char_emoji
        av_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        av_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        av_txt.anchors_preset = Control.PRESET_FULL_RECT
        av_txt.add_theme_font_size_override("font_size", 16)
        avatar.add_child(av_txt)
        
        var name_txt = Label.new()
        name_txt.text = char_name
        name_txt.add_theme_color_override("font_color", Color("#576B95"))
        name_txt.add_theme_font_size_override("font_size", 14)
        name_txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        auth_hbox.add_child(name_txt)
        
        # B. 帖子文本
        var post_txt = Label.new()
        post_txt.text = post.text
        post_txt.add_theme_color_override("font_color", Color("#1f2937"))
        post_txt.add_theme_font_size_override("font_size", 13)
        post_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        post_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        post_box.add_child(post_txt)
        
        # C. 时间与赞
        var info_hbox = HBoxContainer.new()
        info_hbox.add_theme_constant_override("separation", 15)
        post_box.add_child(info_hbox)
        
        var time_txt = Label.new()
        time_txt.text = post.timestamp
        time_txt.add_theme_color_override("font_color", Color("#9ca3af"))
        time_txt.add_theme_font_size_override("font_size", 13)
        time_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        info_hbox.add_child(time_txt)
        
        var like_flag = "moment_liked_" + post.id
        var liked = GameManager.flags.get(like_flag, false)
        
        var like_btn = Button.new()
        like_btn.text = " ❤️ 已赞 " if liked else " 🤍 赞 "
        like_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        like_btn.add_theme_font_size_override("font_size", 13)
        like_btn.add_theme_color_override("font_color", Color("#ef4444") if liked else Color("#6b7280"))
        like_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        like_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
        like_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
        like_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
        like_btn.pivot_offset = Vector2(20, 8)
        
        var pid = post.id
        like_btn.pressed.connect(func(): _on_moment_like_pressed(pid, like_btn))
        info_hbox.add_child(like_btn)
        
        # D. 评论回复区
        var comment_box = VBoxContainer.new()
        comment_box.add_theme_constant_override("separation", 6)
        
        var comment_panel = PanelContainer.new()
        var comment_style = StyleBoxFlat.new()
        comment_style.bg_color = Color("#f3f4f6")
        comment_style.content_margin_left = 10; comment_style.content_margin_right = 10
        comment_style.content_margin_top = 8; comment_style.content_margin_bottom = 8
        comment_style.corner_radius_top_left = 4; comment_style.corner_radius_top_right = 4
        comment_style.corner_radius_bottom_left = 4; comment_style.corner_radius_bottom_right = 4
        comment_panel.add_theme_stylebox_override("panel", comment_style)
        comment_panel.add_child(comment_box)
        post_box.add_child(comment_panel)
        
        var comm_flag = "moment_comment_" + post.id
        var comment_idx = GameManager.flags.get(comm_flag, -1)
        
        if comment_idx == -1:
            var opt_vbox = VBoxContainer.new()
            opt_vbox.add_theme_constant_override("separation", 4)
            comment_box.add_child(opt_vbox)
            
            var select_hint = Label.new()
            select_hint.text = "💬 发表评论回复："
            select_hint.add_theme_color_override("font_color", Color("#6b7280"))
            select_hint.add_theme_font_size_override("font_size", 11)
            opt_vbox.add_child(select_hint)
            
            for c_idx in range(post.comments.size()):
                var opt = post.comments[c_idx]
                var opt_btn = Button.new()
                opt_btn.text = " • " + opt.text
                opt_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
                opt_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
                opt_btn.add_theme_font_size_override("font_size", 12)
                opt_btn.add_theme_color_override("font_color", Color("#576B95"))
                opt_btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
                opt_btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
                opt_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
                opt_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
                
                var capture_idx = c_idx
                opt_btn.pressed.connect(func(): _on_moment_comment_selected(pid, capture_idx))
                opt_vbox.add_child(opt_btn)
        else:
            var my_opt = post.comments[comment_idx]
            
            var my_lbl = RichTextLabel.new()
            my_lbl.bbcode_enabled = true
            my_lbl.text = "[color=#576B95]我[/color]: %s" % my_opt.text
            my_lbl.fit_content = true
            my_lbl.add_theme_font_size_override("normal_font_size", 15)
            comment_box.add_child(my_lbl)
            
            var reply_lbl = RichTextLabel.new()
            reply_lbl.bbcode_enabled = true
            reply_lbl.text = "[color=#576B95]%s[/color]: %s" % [char_name, my_opt.reply]
            reply_lbl.fit_content = true
            reply_lbl.add_theme_font_size_override("normal_font_size", 15)
            comment_box.add_child(reply_lbl)
            
    if not has_any_post:
        var empty_lbl = Label.new()
        empty_lbl.text = "（朋友圈里静悄悄的，先去多过几天生活吧~）"
        empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        empty_lbl.add_theme_color_override("font_color", Color("#9ca3af"))
        empty_lbl.add_theme_font_size_override("font_size", 14)
        empty_lbl.custom_minimum_size = Vector2(0, 100)
        moments_container.add_child(empty_lbl)

func _on_moment_like_pressed(post_id: String, btn: Button):
    var like_flag = "moment_liked_" + post_id
    var currently_liked = GameManager.flags.get(like_flag, false)
    var next_state = not currently_liked
    GameManager.set_flag(like_flag, next_state)
    
    btn.text = " ❤️ 已赞 " if next_state else " 🤍 赞 "
    btn.add_theme_color_override("font_color", Color("#ef4444") if next_state else Color("#6b7280"))
    
    var tween = create_tween()
    tween.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.08)
    tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

func _on_moment_comment_selected(post_id: String, choice_idx: int):
    var comm_flag = "moment_comment_" + post_id
    GameManager.set_flag(comm_flag, choice_idx)
    
    # 增加好感度
    for post in moments_db:
        if post.id == post_id:
            var opt = post.comments[choice_idx]
            var aff = opt.get("aff", 0)
            if aff > 0:
                GameManager.add_favor(post.char_id, aff)
            break
            
    build_moments_list()
