# 拟真手机UI闭环 GDD（Phase 4 · 拟真叙事）

- 任务：DS-RN-01 ｜ 设计：文策渊 ｜ 评审强度：lean（逻辑级验证，无 Godot runtime）
- 交付对象：engineering-lead（程基岩）
- 状态：待用户拍板 §8 决策区（C-1 / C-2 / C-3）后进入实现

---

## §0 范围与目标

**本轮已批准范围（拟真手机UI闭环）：**

1. **朋友圈补全**：`WeChatUI.gd` 的 `moments_db` 从 4 条扩到 10 条 —— 保留现有 4 条（yutong/jingjing/xiaoxia/wanqing），新增 6 条（keke + 5 位男性角色 yifei/zicheng/beichen/jingjing_m/zijun），实现"10 位可攻略角色人人有朋友圈"。
2. **深夜聊天模式**：微信手机 UI 内新增夜间专属的"深夜聊天"——每晚（slot_index==3）最多一位符合条件的角色主动发来深夜消息，走既有主动消息金色高亮通道，点开后进入专属深夜对话树。

**明确延期（本轮不设计、不实现）：**
- ❌ 记忆回响（memory echo）
- ❌ 西湖十景集章（ten-scene stamps）

**设计目标**：用最小引擎改动（不新增 Autoload、不动 SaveSystem 结构）把"手机"从单向工具变成有昼夜节律的拟真社交闭环——白天看朋友圈、日常聊天，深夜收到那个"最在乎你的人"的消息。

**源码核实结论（本 GDD 全部数据以实际源码为准，简报中有两处需要修正）：**

| 核实项 | 结论 |
|---|---|
| 夜间信号 | `DailyCycleManager.gd` **不存在**任何 night 信号或属性。时段状态在 `GameManager.slot_index`（0上午/1中午/2放学后/3晚上），`GameManager._get_slot_id()` 返回 `"evening"`，`get_time_label()` 返回 `"晚上"`。夜间钩子必须挂在 `GameManager.advance_time()` 中 slot_index 递增为 3 的分支（见 §2.1、§4） |
| 角色显示名 | 以 `GameManager.char_meta` 为准（与任务简报不同）：keke=**方可可**🎀转学生、yifei=沈逸飞🎻、zicheng=周子诚🏀、beichen=**顾北辰**🌙神秘转学生、jingjing_m=**叶明轩**🌿青梅竹马、zijun=**林紫君**🎨美术课代表；jingjing=叶菁菁（简报写"林菁菁"，WeChatUI 内旧硬编码名会被 `_ready()` 的 char_meta 合并覆盖，朋友圈渲染直接读 char_meta，无冲突） |
| 解锁日约束 | `char_meta.unlockDay`：keke=**300**、beichen=**300**，其余相关角色 1~3。→ keke/beichen 的朋友圈 unlock_day 必须 ≥300 |
| 主动消息队列 | `InitiativeManager.char_initiative[cid]["wechat_msg"/"wechat_day"]`，门面 `GameManager.get_pending_wechat_msgs()` / `consume_wechat_msg(cid)`；每角色同时仅 1 条 pending；`char_initiative` 已随 SaveSystem 持久化 |
| 冷战态 | `RelationshipManager.get_rel_state(cid)` 返回 `"cold"`（覆盖态，flag `rel_cold_<cid>`）；关系阶梯 stranger/acquaintance(15)/friend(30)/close暧昧(60)/crush心动(85) |
| 存档 | SaveSystem 整体序列化 `GameManager.flags` 字典与 `char_initiative`，新增任意 flag 键**无需**版本迁移 |

---

## §1 朋友圈补全设计

### 1.1 十帖矩阵总览

现有 4 帖不动。新增 6 帖 unlock_day 铺满 570 天周期，与现有 3/7/12/18 错开；keke/beichen 受 unlockDay=300 硬约束，排在后期，恰好成为"转学生登场"的叙事节拍。

| # | id | char_id | 角色 | unlock_day | 备注 |
|---|----|---------|------|-----------|------|
| 1 | post_yutong_study | yutong | 陈雨桐 | 3 | 现有 |
| 2 | post_jingjing_cat | jingjing | 叶菁菁 | 7 | 现有 |
| 3 | post_xiaoxia_run | xiaoxia | 林小夏 | 12 | 现有 |
| 4 | post_wanqing_lake | wanqing | 苏晚晴 | 18 | 现有 |
| 5 | post_zijun_sketch | zijun | 林紫君 | 25 | 新增·前期 |
| 6 | post_jingjing_m_bike | jingjing_m | 叶明轩 | 40 | 新增·前期 |
| 7 | post_zicheng_match | zicheng | 周子诚 | 75 | 新增·初一下 |
| 8 | post_yifei_recital | yifei | 沈逸飞 | 160 | 新增·初二 |
| 9 | post_keke_transfer | keke | 方可可 | 305 | 新增·登场后（≥300） |
| 10 | post_beichen_moon | beichen | 顾北辰 | 320 | 新增·登场后（≥300） |

时间轴分布：前期 3/7/12/18/25/40 密集建立习惯 → 中期 75/160 维持新鲜感 → 300+ 双转学生带来"朋友圈也有新面孔"的后期惊喜。天数间隔均 ≥5，不会同日刷屏。

### 1.2 六条新帖完整数据

评论选项规则沿用现有 4 帖：每帖恰好 2 个选项，一高一低，aff ∈ [4,12]，由 `GameManager.add_favor()` 结算（全局 0.4x 平滑由 add_favor 内部处理，本表填原始值）。

**① post_zijun_sketch（林紫君 🎨 美术课代表，day 25）**
- text：`在断桥边写生了一下午，水彩纸都被湖风吹卷边了，但最后这张荷叶的颜色我真的好喜欢！🎨`
- timestamp：`1小时前`
- comments：
  - A（高）：`{"text": "能看出来你画的时候很开心，颜色里都是夏天的味道。", "reply": "“诶？你居然看得懂……下次写生带你一起，帮我扛画板！”", "aff": 11}`
  - B（低）：`{"text": "卷边了还能这么好看，不愧是美术课代表。", "reply": "“嘿嘿，那是～水彩就是要有点意外才有灵气嘛。”", "aff": 6}`

**② post_jingjing_m_bike（叶明轩 🌿 青梅竹马，day 40）**
- text：`修好了那辆旧自行车，链条上了油，铃铛还是小学时那个声音。放学要不要捎你一段？就当补票。🚲`
- timestamp：`昨天`
- comments：
  - A（高）：`{"text": "补什么票？小学你蹭我橡皮的账还没算呢。", "reply": "“喂喂，陈年旧账就别翻了！明天校门口等你，别迟到。”", "aff": 12}`
  - B（低）：`{"text": "这辆车居然还能骑，真是老古董了。", "reply": "“老古董才有感情好吗，它可比你懂我。”", "aff": 5}`

**③ post_zicheng_match（周子诚 🏀 篮球队长，day 75）**
- text：`区联赛小组出线了！最后那记压哨三分，出手的瞬间整个体育馆都安静了。下一场，主场，等你们来。🏀🔥`
- timestamp：`3小时前`
- comments：
  - A（高）：`{"text": "压哨那球我看了三遍回放，队长稳得可怕！下一场我一定到场。", "reply": "“好兄弟！给你留第一排，记得帮我喊防守！”", "aff": 11}`
  - B（低）：`{"text": "恭喜出线！不过别骄傲，决赛才是硬仗。", "reply": "“放心，教练也是这么说的。冠军拿回来给你看。”", "aff": 6}`

**④ post_yifei_recital（沈逸飞 🎻 音乐课代表，day 160）**
- text：`校庆汇演的独奏曲定了，是我自己写的那首。副歌部分改了十七遍，写它的时候，总想起西湖傍晚的风。🎻`
- timestamp：`晚上 10:02`
- comments：
  - A（高）：`{"text": "十七遍……那首曲子里一定藏着很重要的东西吧。", "reply": "“……被你听出来了。汇演那天，你会来听吗？”", "aff": 12}`
  - B（低）：`{"text": "自己作曲还能上校庆，太厉害了！", "reply": "“谢谢。不过比起厉害，我更希望它能被听懂。”", "aff": 6}`

**⑤ post_keke_transfer（方可可 🎀 转学生，day 305）**
- text：`转学第一周打卡！这个学校居然出门就是西湖，杭州的同学们也太幸福了吧！有人愿意当我的向导嘛？🎀✨`
- timestamp：`30分钟前`
- comments：
  - A（高）：`{"text": "向导预定！先从苏堤走起，秋天的落叶配奶茶刚刚好。", "reply": "“成交！！那说好了，这周末苏堤见，奶茶你请～”", "aff": 12}`
  - B（低）：`{"text": "欢迎来到西湖中学！习惯了就知道，考试周可没空看湖。", "reply": "“呜，别吓我啦！不过谢谢你的欢迎，感觉安心多了。”", "aff": 6}`

**⑥ post_beichen_moon（顾北辰 🌙 神秘转学生，day 320）**
- text：`凌晨的平湖秋月，没有游客，只有月亮和湖。原来安静的时候，一座城市是会呼吸的。`
- timestamp：`凌晨 1:47`
- comments：
  - A（高）：`{"text": "会呼吸的城市……你看到的西湖，好像和所有人的都不一样。", "reply": "“……第一次有人这么回我。下次，带你看凌晨的湖。”", "aff": 12}`
  - B（低）：`{"text": "凌晨还在外面？快回去睡觉，明天还要上课呢。", "reply": "“睡不着而已。不过，谢谢你的关心。”", "aff": 7}`

> 文案基调对齐既有帖：口语化初中生语气 + 西湖在地元素（断桥/苏堤/平湖秋月）+ 角色标签强绑定；beichen 帖刻意无 emoji 结尾、凌晨时间戳，强化"神秘"人设。

### 1.3 关系状态门控规则（本节结论 → §8 C-2 待拍板）

**推荐立场：本轮 10 帖全部仅按 `unlock_day` 解锁，不加关系状态门控。** 理由：
1. 现有 `build_moments_list()` 只做 `GameManager.day >= post.unlock_day` 一层过滤，零门控 = 零引擎改动，符合 lean 原则；
2. 朋友圈的拟真隐喻是"公开广播"，人人可见才真实；私密感表达已由深夜聊天（本轮）承担，功能分层清晰；
3. 若加 crush 门控，好感低的玩家会看到"朋友圈永远缺一块"，且无法得知缺失原因，易被误判为 bug。

若用户选择 C-2 备选项（少数帖加门控），schema 已预留可选字段 `min_rel_state`（见 §5），实现为 build_moments_list 中一行状态判断，随时可加。

---

## §2 深夜聊天模式设计（核心新功能）

### 2.1 触发机制

- **夜间信号（精确结论）**：DailyCycleManager 无可用夜间信号。**触发点 = `GameManager.advance_time()` 中 `slot_index` 递增后等于 3 的分支**（即"放学后→晚上"的时刻）。推荐实现：在 advance_time 内该分支处调用 `InitiativeManager.check_night_chat()`（新增函数，非新增 Autoload）。判断口径可复用 `GameManager._get_slot_id() == "evening"`。
- **频率**：每晚最多 1 位角色、1 条深夜消息。去重 flag：`night_chat_day_<day>`（bool，进 `GameManager.flags`，随存档持久化）——`advance_time` 存在网瘾跳时段的递归调用（`advance_time(true)`），该 flag 同时防递归双触发。
- **触发概率**：建议 100%（只要有合格角色就触发）。深夜聊天是本轮核心拟真体验，不宜再叠概率；节奏控制交给"每角色 3 天冷却"（flag `night_chat_last_<cid>` 记录上次触发 day，`day - last >= 3` 方可再选中同一角色）。

**角色遴选算法（每晚执行一次）：**

```
candidates = 所有 char_id 满足:
    GameManager.day >= char_meta[cid].unlockDay          # 已登场
    RelationshipManager.get_rel_state(cid) in ["friend", "close", "crush"]   # ≥朋友；天然排除 cold（cold 是覆盖态，get_rel_state 直接返回 "cold"）
    InitiativeManager.char_initiative[cid]["wechat_msg"] == ""               # 无未读主动消息，防覆盖
    day - flags.get("night_chat_last_"+cid, -999) >= 3                       # 角色冷却
selected = candidates 中 GameManager.favorability[cid] 最大者
    （并列时取 REL_ORDER 更高者，再并列取 char_id 字典序，保证确定性、便于测试）
fallback: candidates 为空 → 今晚无深夜聊天，静默跳过（不提示、不补偿；
    前中期玩家好感未到 friend 属正常节奏，不视为异常）
```

### 2.2 投递机制（复用主动消息队列，零新管道）

选中角色后**精确调用链**：

1. `InitiativeManager.char_initiative[cid]["wechat_msg"] = <该角色深夜树 start 节点的 text>`；`["wechat_day"] = GameManager.day`（复用现有 2 天过期逻辑：当晚没看，次日白天仍可见，第 3 天消失——拟真且防堆积）。
2. `GameManager.set_flag("night_chat_pending_" + cid, true)` —— 标记"这条 pending 是深夜消息"，供 WeChatUI 区分普通主动消息。
3. `GameManager.set_flag("night_chat_day_" + str(GameManager.day), true)`、`GameManager.set_flag("night_chat_last_" + cid, GameManager.day)`。
4. `GameManager.show_toast.emit("🌙 %s 深夜给你发来了消息…" % char_name)`；`GameManager.initiative_updated.emit()`。

**WeChatUI 侧（全部走现有通路）**：聊天列表 `build_chat_list()` 已会对 pending 消息角色渲染金色高亮 + 红点 + `[主动]` 预览——仅需一处小改：若 `flags.night_chat_pending_<cid>` 为真，预览前缀改 `[深夜]`、高亮边框可改月光蓝（#7DA7D9，可选拟真项）。玩家点开 → `_on_chat_card_clicked()` 现有注入段把消息写入 `wechat_history_<cid>` 并 `consume_wechat_msg(cid)` ——此处加一个分支：若 `night_chat_pending_<cid>` 为真，则额外把 `chats_db[cid].current_node` 切到 `night_start`（并同步 `flags["wechat_node_"+cid]`），清除 `night_chat_pending_<cid>`。后续选项加载、打字机、奖励结算全部复用现有 `rebuild_bubble_history()` / `_on_choice_selected()` / `apply_rewards()`，**无需任何新 UI 流程**。

### 2.3 对话内容结构（推荐：per-character 专属深夜子树）

两个候选方案：

| 方案 | 说明 | 评估 |
|---|---|---|
| **A. 专属深夜子树（推荐）** | 每角色在自己 `nodes` 字典内追加 `night_start → night_a/night_b → night_end` 一组节点，格式与现有节点完全一致 | 引擎零改动（节点机就是查 key）；文案角色浓度高；每角色约 4-5 节点 × 10 角色，文案量可控（lean 下可先做好感前 6 名角色，后 4 名下轮补） |
| B. 共享深夜场景+角色分支 | 一棵公共树，节点内按 char_id 插值文本 | 省文案但节点机需新增"按角色取文本"逻辑，反而改引擎；且深夜是高情感浓度场景，模板句容易穿帮 |

**选 A。** 理由：本项目节点机以"key→节点"寻址，A 方案是纯数据扩展；深夜聊天的价值恰恰在"这个人只会在深夜对你说这种话"，共享模板与设计目标相悖。

**深夜树设计规约**：每角色 1 棵，规模 start + 2 分支 + end（4~5 节点）；选项 aff 3~6（略高于日常聊天，体现深夜谈心权重）、stress 多为负（深夜谈心解压），个别"敞开心扉"节点可 setFlag（如 `night_heart_<cid>`）供后续剧情引用；`night_end` 节点 choices 为空，复用现有"结束聊天"按钮。**注意**：走完深夜树后 `current_node` 停在 `night_end`，聊天列表预览将显示深夜收尾语，属可接受的拟真表现（就像真实聊天停在最后一句）；该角色的日常树进度已被覆盖——lean 取舍，见 §7 R-5。

**样例①（女性角色 · 叶菁菁 jingjing，青梅竹马）：**

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

**样例②（男性角色 · 顾北辰 beichen，神秘转学生）：**

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

> 前提：C-3 若批准，keke/beichen/jingjing_m/zijun 将拥有完整 chats_db 条目，深夜子树直接挂入；若 C-3 未批准，深夜候选池临时限定为已有 chats_db 的 6+keke？——不行，无条目角色无法进聊天室。**故深夜聊天覆盖 10 人依赖 C-3，这是推荐 C-3 选"是"的核心理由。**

### 2.4 奖励结算

与日常聊天完全一致：走 `apply_rewards()` → `add_favor` / `add_stat("stress", n)` / `set_flag`。深夜选项数值规约：aff 3~6、stress -5~+2、每树至多 1 个 setFlag。无新增货币/道具奖励（lean）。

### 2.5 边缘情况

| # | 场景 | 处理 |
|---|---|---|
| E-1 | 玩家与该角色日常树已停在 `end`（choices 空） | 无影响：注入时直接把 `current_node` 覆写为 `night_start`，深夜树自带新选项，反而"复活"了死聊天 |
| E-2 | 连续多晚流逝 / 网瘾跳时段递归 | `night_chat_day_<day>` 每晚一 flag 防重；跳过整天（DialogueUI 手动结算路径）时若未经过 slot 3 分支则当晚自然无深夜消息，可接受 |
| E-3 | 深夜消息发出后角色进入冷战（选中时未冷战） | 消息已在队列则保留（拟真：消息发出后吵架，消息还在）；但下一晚遴选即排除。可接受，不做撤回逻辑 |
| E-4 | 深夜树已走完（current_node==night_end），角色再次被选中 | 允许：再次注入时将 `current_node` 重置回 `night_start` 重走（3 天冷却限频）。重复走树 aff 有限（add_favor 0.4x 平滑 + 好感上限 100 天然封顶），无刷分风险；lean 下不做二套文案 |
| E-5 | 该角色已有普通主动消息 pending | 遴选阶段已排除（`wechat_msg != ""` 跳过），每角色单槽位不冲突 |
| E-6 | NG+ 二周目 | **推荐：深夜聊天每周目重置重玩。** NG+ 重置走 flags 处理，需确认周目重置清单包含 `night_chat_*` 与 `wechat_node_*`/`wechat_history_*` 前缀键（NGPlusManager 现仅管熟悉感台词，flags 清理在开新周目流程中）；深夜文案是关系构建内容，二周目攻略不同角色时必须可重新体验。NG+ 熟悉感台词（`get_ng_familiarity_line`）与深夜树无耦合 |

---

## §3 聊天列表补全（建议项 · **建议一并做，待用户确认** → §8 C-3）

现状 `chats_db` 仅 6 角色（yutong/jingjing/wanqing/xiaoxia/yifei/zicheng），缺 **keke/beichen/jingjing_m/zijun** 4 人。缺失后果：① 4 人无法聊天，"闭环"名不副实；② 深夜聊天无法覆盖此 4 人（无 nodes 容器）；③ 4 人的主动微信消息（InitiativeManager 未来扩展配置后）点开会因 `chats_db[char_id]` 缺 key 直接报错——现列表只渲染 chats_db 键故当前不炸，但属埋雷。

4 棵补全树草案（规模对齐现有：start + 2 分支 + end，aff 2~5 / stress ±10 内）：

**keke 方可可 🎀（转学生，元气）** `start`:"救命！转学生迷路第三天，教学楼B座到底怎么走啊，我又绕回食堂了！😭" → A"别慌，我画张校园地图发你，标了所有近道。"(aff5,stress-5)→`map_thanks`:"呜呜你是天使吧！地图收藏了！作为报答，请你喝我家乡最好喝的汽水！"→"成交，明天见面交货。"(aff4,stress-3)→end；B"食堂也不错啊，说明你有干饭的天赋。"(aff3,stress-3)→`foodie_joke`:"喂！人家是路痴不是吃货！……好吧其实食堂三楼的糖醋排骨确实好吃。下次带你去！"→"那我勉为其难当你的干饭搭子吧。"(aff4)→end。end:"（可可发来一排比心表情，看来已经把你标记成'在杭州第一个朋友'啦～）"

**beichen 顾北辰 🌙（神秘，疏离→靠近）** `start`:"物理笔记借我看一下。……上周病假落了两节课。" → A"给你，重点我都标了荧光笔。需要的话我讲一遍？"(aff5,stress2)→`explain`:"……你讲得比老师慢，但是清楚。谢谢。改天还你一个人情。"→"记账上了，利息是一杯热可可。"(aff4,stress-3)→end；B"可以是可以，不过你的'病假'，真的是生病吗？"(aff2,stress5)→`evade`:"……你观察得很仔细。笔记先借我，其他的，以后再说。"→"好，笔记明天给你。"(aff3)→end。end:"（他很快退出了对话，但你注意到，他把你的消息设成了星标。）"

**jingjing_m 叶明轩 🌿（青梅竹马，男版）** `start`:"我妈炖了排骨汤让我给你端一碗，趁热。另外……小学毕业时埋在香樟树下的那个盒子，你还记得吗？" → A"当然记得！时间胶囊！我们约好初三毕业挖出来的！"(aff5,stress-5)→`capsule`:"你居然还记得。那就说定了，570天之后，香樟树下，谁都不许缺席。"→"一言为定。"(aff5,setFlag:"capsule_promise_jmx")→end；B"什么盒子？……我只记得排骨汤，快端来！"(aff3,stress-3)→`soup`:"好好好，干饭要紧。盒子的事，等你哪天想起来再说——反正钥匙在我这。"→"故弄玄虚！汤凉了你负责！"(aff3)→end。end:"（窗外传来自行车铃声，是他端着保温盒下楼了。）"

**zijun 林紫君 🎨（美术课代表）** `start`:"问你个事！校园艺术节的主题海报我入围了，但要在两版里选一版提交，你帮我看看？（发来两张草图）" → A"左边这版，湖的留白特别妙，一眼就是西湖。"(aff5,stress-3)→`pick_left`:"哇，你和我想的一样！就它了！等海报贴出来，右下角签名旁边我偷偷画了个小彩蛋，只告诉你哦。"→"那我一定第一个去找彩蛋。"(aff4)→end；B"我不太懂画，但右边的颜色看着更热闹。"(aff3,stress0)→`pick_right`:"热闹……嗯，艺术节确实要热闹！你这个'外行视角'反而提醒我了，谢啦！"→"能帮上忙就好，加油！"(aff3,stress-3)→end。end:"（她的头像亮着，大概正趴在画板前赶稿吧。）"

> 实现即：在 `chats_db` 追加 4 个键，格式与现有条目一致；`avatar_color` 取 char_meta color（_ready 会覆盖，占位即可）。**再次强调：此节为建议项，须待用户在 C-3 拍板后方可实现。**

---

## §4 集成点 & 引擎改动清单

**总原则：不新增 Autoload、不新增场景文件，全部为既有文件内的数据追加 + 小函数。**

| 文件 | 改动 | 规模 |
|---|---|---|
| `scripts/WeChatUI.gd` | ① `moments_db` 追加 6 条（§1.2 数据照抄）；② `_on_chat_card_clicked()` 注入段增加分支：`night_chat_pending_<cid>` 为真时切 `current_node = "night_start"` 并同步 flag、清 pending flag；③ `build_chat_list()` 预览前缀 `[深夜]` + 边框色分支；④（C-3 批准后）`chats_db` 追加 4 角色条目；⑤ 各角色 `nodes` 追加深夜子树；⑥（可选 §6）时间戳改动 | 主要是数据；逻辑改动 <30 行 |
| `scripts/InitiativeManager.gd` | 新增 `check_night_chat()`（遴选算法 §2.1 + 投递 §2.2）与深夜文案常量 `NIGHT_CHAT_OPENERS`（每角色 night_start 首句，用作 wechat_msg 预览文本）。放本文件因为它已持有 wechat_msg 槽位与存档序列化 | 新函数 ~40 行 |
| `scripts/GameManager.gd` | `advance_time()` 中 `slot_index` 递增后为 3 的分支（即现有 `else` 分支内，与"放学后布置作业"并列处加 `elif _get_slot_id() == "evening": InitiativeManager.check_night_chat()`）。门面 `get_pending_wechat_msgs`/`consume_wechat_msg` **无需改动** | 2~3 行 |
| `scripts/DailyCycleManager.gd` | **无改动**。核实结论：夜间态由 GameManager.slot_index 表达，不在本文件加信号（避免为一个调用点引入新信号链） |
| `scripts/RelationshipManager.gd` | **无改动**，只读 `get_rel_state()` |
| `scripts/SaveSystem.gd` | **无改动**。新增 flag 均为 `GameManager.flags` 普通键，整字典序列化，旧档读入缺键走 `flags.get(key, default)` 自然兜底，无需版本升级（详见 §7 R-3） |
| `scripts/NGPlusManager.gd` | **无改动**（若周目重置流程在别处清 flags，需在清单加 `night_chat_*` 前缀，见 §7 R-4） |

**新增 flags 一览**（全部 bool/int，随存档自动持久化）：
`night_chat_day_<day>`、`night_chat_last_<cid>`、`night_chat_pending_<cid>`、`night_heart_<cid>`/`night_promise_<cid>`（剧情钩子）、`capsule_promise_jmx`（C-3 树内）。

---

## §5 数据格式规范

### 5.1 moments_db 条目（与现有格式一致，新增 1 个可选字段）

```gdscript
{
    "id": "post_<cid>_<slug>",       # String，全局唯一；like flag = "moment_liked_"+id，comment flag = "moment_comment_"+id
    "char_id": "zijun",              # String，必须 ∈ GameManager.char_meta 键
    "unlock_day": 25,                # int，1~570；必须 ≥ char_meta[char_id].unlockDay
    "text": "……",                    # String，1~2 句，可含 emoji 与 \n
    "timestamp": "1小时前",           # String，展示标签（§6 可选改为动态计算，字段保留作 fallback）
    "min_rel_state": "",             # 【可选·新增】String，""=不门控；"crush" 等 REL_STATES 键 → build_moments_list 追加过滤。C-2 选推荐项则本轮全部留 ""
    "comments": [                    # Array，恰好 2 项，[0]/[1] 顺序即渲染顺序
        {"text": "玩家评论文本", "reply": "角色回复文本", "aff": 11},   # aff: int 4~12，经 add_favor 结算
        {"text": "…", "reply": "…", "aff": 6}
    ]
}
```

### 5.2 深夜聊天节点（= 现有 chats_db 节点格式，仅约定命名前缀）

```gdscript
# 挂载位置：chats_db[<cid>]["nodes"] 内，与日常节点同级
"night_start": {                     # 入口 key 固定为 "night_start"；子节点前缀 "night_"
    "sender": "<cid>",               # String；节点机现有字段，照旧
    "text": "……",                    # String，可含 \n
    "choices": [                     # Array；空数组 = 终端节点（渲染"结束聊天"按钮）
        {
            "text": "玩家选项",        # String
            "next": "night_xxx",     # String，必须指向同角色 nodes 内存在的 key（终点统一 "night_end"）
            "aff": 5,                # int 3~6（深夜规约），经 apply_rewards→add_favor
            "stress": -3,            # int -5~+2，经 add_stat("stress", n)
            "setFlag": "night_heart_<cid>"   # 可选 String，经 set_flag(name, true)
        }
    ]
}
```

**校验规则（供 quality-lead 逻辑冒烟）**：① 每帖 comments.size()==2 且 aff∈[4,12] 且两项 aff 不等；② keke/beichen 帖 unlock_day≥300；③ 每棵深夜树从 night_start 可达 night_end 且无悬空 next；④ 全部 char_id/flag 名与 char_meta 键拼写一致（尤其 jingjing_m 勿写成 jingjingm）。

---

## §6 拟真度增强（可选小项，均 <10 行改动，可单独裁剪）

1. **朋友圈相对时间戳**：`timestamp` 改为按 `GameManager.day - unlock_day` 动态生成——0 天:"1小时前"、1 天:"昨天"、2~6 天:"N天前"、≥7 天:"1周前"（beichen 帖当天特例显示"凌晨 1:47"保人设）。静态字段保留作 fallback。
2. **聊天时间戳修正**：`rebuild_bubble_history()` 硬编码 `"晚上 21:15"` 改为按 `GameManager.get_time_label()` 映射：上午"上午 10:20" / 中午"中午 12:35" / 放学后"下午 17:05" / 晚上"晚上 21:15"；若本次为深夜消息注入，显示"深夜 23:47"。成本一行字典查表，拟真收益高，**建议纳入**。
3. **深夜视觉微调**：深夜 pending 的金色高亮改月光蓝 #7DA7D9 + 预览前缀 🌙；不改布局。
4. **红点补全**：现红点条件 `current_node == "start"` 导致走完树的角色永无红点；可补充"current_node == 'night_start' 也算未读"。lean 下仅此一条，不做通用未读系统。

---

## §7 风险与缓解

| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| R-1 | **关系门槛排除导致前期深夜聊天长期不触发**（friend 需好感 30，开局仅 jingjing/jingjing_m=20 最接近） | 中 | 属有意节奏（深夜谈心是关系成果，不是白给）；toast 文案不预告该系统存在，玩家无预期即无失落。若播测反馈过晚，可把门槛降到 acquaintance(15)，一行改动 |
| R-2 | **主动消息槽位竞争**：深夜消息占用 `wechat_msg` 单槽，可能挤占次日 InitiativeManager 正常主动消息 | 低 | 遴选已互斥（有 pending 即跳过）；反向（深夜想发但白天消息未读）自动落选，行为正确。2 天过期机制兜底不堆积 |
| R-3 | **存档兼容** | 低 | 已核实：SaveSystem 整字典存 `flags`（L30/L189）与 `char_initiative`（L36/L203-205），新 flag 键与 moments_db 新增条目均为读时兜底（`flags.get`、day 过滤），旧档加载后新帖按当前 day 直接可见、深夜系统从当晚开始工作。**无需 save version bump，无需迁移代码** |
| R-4 | **NG+ 重玩**：若周目重置未清 `night_chat_*` / `wechat_node_*` / `wechat_history_*`，二周目聊天停留在一周目末态 | 中 | 实现时在开新周目的 flags 重置处按前缀清除上述三组键（连同现有 `moment_liked_*`/`moment_comment_*` 一并核查——若一周目已有同样问题则顺手修复，需 engineering-lead 确认现状） |
| R-5 | **深夜树覆盖日常树进度**：`current_node` 单指针，切入 night_start 后日常树停点丢失 | 低 | lean 取舍：现日常树均为一次性短对话，多数玩家早已到 end；如需保留，可在切入前存 `flags["wechat_node_daily_"+cid]`，本轮不做，标注为后续增强 |
| R-6 | **主动消息去重**：`night_chat_day_<day>` flag 逐日累积（570 天最多 570 个 bool 键） | 低 | 存档体积影响可忽略（<20KB）；如介意可改为单键 `night_chat_last_day: int`，实现时任选，推荐单键写法 |
| R-7 | **文案量**（C-3 全批 = 6 帖 + 4 聊天树 + 10 深夜树） | 中 | 本 GDD 已交付 6 帖全文 + 4 树草案 + 2 深夜树全文；其余 8 棵深夜树按 §2.3 规约与两篇范文的规格产出，实现期由我补齐，不阻塞工程搭骨架 |

---

## §8 决策区（待用户拍板）

### C-1 深夜聊天触发与角色选择方式

| 选项 | 方案 | 评估 |
|---|---|---|
| **A（推荐）** | `advance_time` 进入 slot 3 时触发；每晚 1 条 100% 触发；候选 = 已登场 ∧ rel_state∈{friend,close,crush}（天然排除 cold）∧ 无 pending ∧ 角色 3 天冷却；选最高好感者，无候选则静默跳过 | 确定性强、可测试、"最在乎你的人深夜找你"叙事聚焦；引擎改动 2 行 |
| B | 同 A 但按好感加权随机选人 | 更多样但削弱"最亲密者深夜谈心"的情感逻辑，且不利于 quality-lead 复现测试 |
| C | 挂接 DailyCycleManager 新增 night_started 信号 | 更"架构正确"，但为单一消费者加信号链，违背本轮 lean 原则 |

**推荐 A。**

### C-2 朋友圈是否与关系状态联动

| 选项 | 方案 | 评估 |
|---|---|---|
| **A（推荐）** | 10 帖全部仅按 unlock_day 解锁，零门控 | 零引擎改动；朋友圈=公开广播的拟真隐喻成立；私密内容已由深夜聊天分层承担；不会出现"看不见也不知道为什么"的暗坑 |
| B | 少数帖（如 beichen/yifei）加 crush 门控 | 私密感强，但 570 天里低好感玩家的朋友圈永久缺块且无提示，易误判 bug；且需改 build_moments_list |
| C | 门控但给占位（"仅部分人可见"灰条） | 拟真最强，UI 工作量超 lean 预算 |

**推荐 A**（schema 已预留 `min_rel_state` 字段，后续任何时候可无痛升级到 B）。

### C-3 是否本轮一并补全 4 个缺失聊天树（keke/beichen/jingjing_m/zijun）

| 选项 | 方案 | 评估 |
|---|---|---|
| **A（推荐）** | 是，按 §3 草案一并补全 | ①"闭环"名副其实：10 人可聊+可朋友圈+可深夜；②深夜聊天覆盖 10 人**依赖**此项（无 chats_db 条目的角色进不了聊天室）；③消除未来主动消息点开缺 key 的埋雷；④增量纯数据，工程风险≈0 |
| B | 否，仅做已批 2 项；深夜候选池限定现有 6 人 | 范围最小，但深夜聊天对 keke/beichen（unlockDay 300 后正是后期核心新鲜感）完全失效，Phase 4"拟真"成色打折 |

**推荐 A**——不补全则本轮两个已批功能都只覆盖 6/10 角色，"闭环"不成立。

---

*附：本 GDD 全部接口名、行为描述均经源码核读（WeChatUI.gd / GameManager.gd / DailyCycleManager.gd / RelationshipManager.gd / InitiativeManager.gd / SaveSystem.gd / NGPlusManager.gd），可直接据此实现，无需再澄清。*
