# 拟真手机UI闭环 · 全量文案交付（RL-CONTENT-01）

- 设计：文策渊 ｜ 上游：`design/realistic_phone_gdd.md`（已批准：C-1=A / C-2=A / C-3=A）
- 交付对象：engineering-lead（程基岩）——全部为 paste-ready GDScript 字典字面量，可直接粘贴入 `scripts/WeChatUI.gd`
- 数值规约：朋友圈评论 aff∈[4,12]；日常聊天树 aff 2~5 / stress ±10；深夜树 aff 3~6 / stress -5~+2；每树至多 1 个 setFlag（beichen 深夜树为 GDD §2.3 范文原样，两分支各 1 flag、单次通关只触发其一）
- C-2=A：所有 moments 条目**无** `min_rel_state` 字段
- char_id 拼写以 `GameManager.char_meta` 为准：`jingjing_m`（勿写 jingjingm）、`keke`（勿写 coco）

---

# SECTION 1: MOMENTS（6 条新帖，GDD §1.2 原文照抄）

**PASTE INTO `moments_db`:**（追加到现有 4 条之后即可，`build_moments_list()` 反序渲染无顺序要求）

```gdscript
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
```

---

# SECTION 2: CHAT TREES（4 位缺失角色的完整 chats_db 条目）

> 说明：GDD §3 草案叙事全部保留（草案首选项即 A/B 首条），按"每非终端节点 2 选项"规约为各分支节点补齐第二选项。`avatar_color` 按 char_meta 填写（`_ready()` 会再次合并覆盖，安全）。
> **重要**：keke / beichen / jingjing_m / zijun 的深夜子树见 SECTION 3，须追加进**本节同一个 `nodes` 字典**内。

## 2.1 PASTE INTO `chats_db` as key `"keke"`:

```gdscript
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
            }
        }
    }
```

## 2.2 PASTE INTO `chats_db` as key `"beichen"`:

```gdscript
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
            }
        }
    }
```

## 2.3 PASTE INTO `chats_db` as key `"jingjing_m"`:

```gdscript
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
            }
        }
    }
```

## 2.4 PASTE INTO `chats_db` as key `"zijun"`:

```gdscript
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
            }
        }
    }
```

---

# SECTION 3: NIGHT TREES（10 位角色深夜子树）

> 挂载规则：全部追加进各角色 `chats_db[<cid>]["nodes"]` 字典内，与日常节点同级。入口 key 固定 `night_start`，终点固定 `night_end`（choices 为空，复用"结束聊天"按钮）。全部树已自检：night_start → 分支 → night_end 可达，无悬空 next。
> keke / beichen / jingjing_m / zijun 追加进 **SECTION 2 新建的 nodes 字典**；其余 6 人追加进 **现有 chats_db 条目**。

## 3.1 APPEND INTO `chats_db["jingjing"]["nodes"]`:（GDD §2.3 样例① 原文）

```gdscript
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
```

## 3.2 APPEND INTO `chats_db["beichen"]["nodes"]`（即 SECTION 2.2 的 nodes 字典）:（GDD §2.3 样例② 原文）

```gdscript
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
```

> 注：3.2 为 GDD 范文原样保留（双分支各带 1 个 setFlag，单次通关仅触发其一）。其余各树均严格 ≤1 个 setFlag。

## 3.3 APPEND INTO `chats_db["yutong"]["nodes"]`:（陈雨桐 · 班长温柔鼓励）

```gdscript
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
```

## 3.4 APPEND INTO `chats_db["wanqing"]["nodes"]`:（苏晚晴 · 诗意安静陪伴）

```gdscript
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
```

## 3.5 APPEND INTO `chats_db["xiaoxia"]["nodes"]`:（林小夏 · 活力直率）

```gdscript
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
```

## 3.6 APPEND INTO `chats_db["keke"]["nodes"]`（即 SECTION 2.1 的 nodes 字典）:（方可可 · 元气撒娇/想家）

```gdscript
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
```

## 3.7 APPEND INTO `chats_db["yifei"]["nodes"]`:（沈逸飞 · 含蓄音乐分享）

```gdscript
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
```

## 3.8 APPEND INTO `chats_db["zicheng"]["nodes"]`:（周子诚 · 兄弟式热血谈心）

```gdscript
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
```

## 3.9 APPEND INTO `chats_db["jingjing_m"]["nodes"]`（即 SECTION 2.3 的 nodes 字典）:（叶明轩 · 毒舌掩饰的关心）

```gdscript
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
```

## 3.10 APPEND INTO `chats_db["zijun"]["nodes"]`（即 SECTION 2.4 的 nodes 字典）:（林紫君 · 傲娇但真诚）

```gdscript
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
```

---

# 附：自检清单（供 quality-lead 冒烟）

| 校验项 | 结果 |
|---|---|
| 6 帖 comments 均恰 2 项、aff∈[4,12] 且两项不等 | ✅（11/6, 12/5, 11/6, 12/6, 12/6, 12/7） |
| keke/beichen 帖 unlock_day ≥ 300 | ✅（305 / 320） |
| 4 棵日常树：start+2分支+end，非终端节点均 2 选项，aff 2~5，stress ∈ ±10，next 无悬空 | ✅ |
| 10 棵深夜树：night_start+2分支+night_end，aff 3~6，stress ∈ [-5,+2]，next 无悬空 | ✅ |
| setFlag：日常树仅 jingjing_m 1 个（capsule_promise_jmx）；深夜树每树 ≤1（beichen 为 GDD 范文原样例外，双分支互斥） | ✅ |
| char_id 拼写（jingjing_m / keke）、姓名/emoji/颜色对齐 char_meta | ✅ |

**深夜树 flag 总表（10 个角色）**：`night_heart_jingjing`、`night_promise_beichen` + `night_heart_beichen`（范文原样，分支互斥）、`night_heart_yutong`、`night_heart_wanqing`、`night_promise_xiaoxia`、`night_promise_keke`、`night_promise_yifei`、`night_heart_zicheng`、`night_heart_jingjing_m`、`night_heart_zijun`
