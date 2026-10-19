# 记忆回响 · 情境回响（Contextual Memory Echo）GDD

- 任务：DS-RN-02 ｜ 设计：文策渊 ｜ 评审强度：lean（逻辑级验证，无 Godot runtime）
- 交付对象：engineering-lead（程基岩）+ quality-lead（严守真）｜ **art-director 无需求（零新资产）**
- 项目：《西湖边的青春》· Godot 4.5 mobile · 1280×720 横屏 · 570 天流程
- 状态：**按推荐全定**，§8 仅留 2 项可选拍板（D-1 / D-2），不拍板亦可直接实现
- 形态：**情境回响（Contextual Echo）** —— 已收集的假期记忆在匹配情境下自发 flashback（用户已拍板）

---

## §0 概览与目标

### 0.1 特性定位

「记忆回响」是**拟真叙事**阶段的最后一块，也是三块子特性中唯一处理"时间纵深"的一块：

| 子特性 | 状态 | 承载的玩家动机 | 时间维度 |
|---|---|---|---|
| 拟真手机UI闭环（DS-RN-01） | 已落地 | 社交拟真 | **当下** |
| 西湖十景集章（DS-RN-03） | 已落地 | 地域拟真 + 收集 | **空间** |
| **记忆回响（DS-RN-02）** | **本文档** | **时间拟真 —— 让 570 天真的有"以前"** | **过去** |

### 0.2 缺口界定（Phase 0 核实结论）

`holiday_memory_*` 的**画廊层已 100% 完工**，本特性**不重做任何已完成的事**：

| 层 | 状态 | 语义 |
|---|---|---|
| 记忆的**产生** | ✅ 已完工 | `events_break.json` 10 个 chapter 终场景 `setFlag: holiday_memory_<season>_<char>`（L310/316、380/386、452/458、525/531、595/601、665/671、736/742、806/812、879/885、949/955） |
| 记忆的**主动回看** | ✅ 已完工 | `GameManager.GALLERY_ITEMS` L345-354 十条 `pose:"memory"` 条目 + 4 张 CG 齐备 |
| 记忆的**被动浮现** | ❌ **本特性** | 玩家不去翻画廊，记忆自己在情境中"回响"出来 |

一句话：**画廊是"我去打开抽屉"，回响是"抽屉自己打开了"。** 两者是同一批数据的两种消费方式，互补不重叠（§6.1）。

### 0.3 设计支柱

1. **编码特异性（Encoding Specificity）** —— 记忆最容易被"当初编码它的那个情境"唤起。所以触发条件不是随机、不是计时器，而是**回到那件事发生的那个地方**。这条心理学原则直接决定了 §2 的触发模型。
2. **稀有即珍贵** —— 回响不是日常反馈，是"整整三年里发生过八九次的事"。密度上限（§2.4）不是防刷屏的补丁，是**特性本体的一部分**。
3. **零惩罚** —— 玩家没有主动请求它，因此它**不能收取任何代价**：不消耗时段、不扣属性、不打断流程（§3.4）。

### 0.4 成功标准

| # | 标准 | 可验证方式（静态断言，无需 runtime） |
|---|---|---|
| S-1 | 零新 Autoload、**零新脚本文件**、零存档迁移 | `project.godot` `[autoload]` 段逐字节不变；`scripts/` 无新增 `.gd`；新增键全落 `GameManager.flags` |
| S-2 | 零新美术 / 零新记忆资产 | `assets/` 无新增文件；`MEMORY_ECHO_CONTEXTS` 的 10 个 sid ⊂ `GALLERY_ITEMS` 中 `holiday_memory_*` 的 flag 全集 |
| S-3 | **防刷屏可证** | 常量满足：`ECHO_TOTAL_CAP + FINALE_BONUS ≤ 10`，且非终章全局间隔 ≥ 14 天、终章 ≥ 5 天 → 单周目回响总次数 ≤ 11（含毕业前夜特例 1 次） |
| S-4 | **不消耗时段** | 回响 vignette 携带 `noTimeCost:true`，`DialogueUI.finish_event()` 对该键短路 `advance_time()`；全工程仅此一处使用该键 |
| S-5 | **不打断** | 回响的唯一播放入口是 `MainGame._on_location_selected()` 的 step 0（进入地点之前）。全工程 grep：`build_memory_echo_vignette` 的调用点有且仅有 1 处 |
| S-6 | **数据单一真源** | `MEMORY_ECHO_CONTEXTS` 不含 `char` / `bg` / `label` 字段（运行时从 `GALLERY_ITEMS` 反查）；不含 `born_day`（从 `DailyCycleManager.BREAK_PERIODS` 推导） |
| S-7 | NG+ 自动清零 | 所有键以 `mem_echo_` 为前缀，随 `EndingScreen.gd:440` `flags = {}` 清空；且不在 L466-467 的继承白名单中 |
| S-8 | 不与画廊 / 集章 / 深夜聊天冲突 | 回响不写任何 `stamp_*` / `seen_*` / `night_chat_*` / `holiday_memory_*` 键；不调用 `unlock_gallery()` |

---

## §1 记忆池

### 1.1 池规模与来源

**复用现有 10 条 `holiday_memory_*`，不新增任何记忆资产。** 池大小固定为 10；单周目**运行时可用池** = 玩家实际解锁的条数（典型 2-6 条，理论上限 10 条）。

> **单周目池大小推算**：每个长假的 3/3/2/2 个 chapter 通过 `requireFlags:["holiday_chapter_<season>"]` 统一开闸、彼此**不互斥**（核实：该 flag 由 kickoff 事件写入后永不擦除），但受 `slotId` + `location` + `minAff:30` + `excludeRelState:"cold"` 四重约束。优先级最高的一档（priority 170）**全部是 `lakeside` + `evening`**，这是每个长假的"主章"。因此**模式玩家的记忆池高度集中在 lakeside**——这与"回响主钩子挂地点进入"的选型天然契合（§2.1）。

### 1.2 触发上下文映射表（真源：`events_break.json` chapter 定义）

`sid` = `<season>_<char>`，与 flag 一一对应：`flag = "holiday_memory_" + sid`。
`loc` / `slot` **逐字取自对应 chapter 事件的 `location` / `slotId` 字段**，不是设计臆造：

| # | sid | 画廊 label | 角色 | **loc**（原发地点） | **slot**（原发时段） | 源 chapter 事件 | CG（反查 GALLERY_ITEMS.bg） | 长假区间 | born | **mature**(+30) |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | `winter_yutong` | 寒假·雪夜断桥 | yutong | **lakeside** | evening | `break_winter_chapter_yutong` | `holiday_winter.jpg` | 90-100 | 100 | **130** |
| 2 | `winter_jingjing` | 寒假·糖水铺约定 | jingjing | **off_campus_shop** | after | `break_winter_chapter_jingjing` | `holiday_winter.jpg` | 90-100 | 100 | **130** |
| 3 | `winter_yifei` | 寒假·冬夜影院 | yifei | **cinema** | noon | `break_winter_chapter_yifei` | `holiday_winter.jpg` | 90-100 | 100 | **130** |
| 4 | `spring_wanqing` | 春假·桃林写生 | wanqing | **lakeside** | evening | `break_spring_chapter_wanqing` | `holiday_spring_outing.jpg` | 150-155 | 155 | **185** |
| 5 | `spring_xiaoxia` | 春假·攀岩馆 | xiaoxia | **community** | after | `break_spring_chapter_xiaoxia` | `holiday_spring_outing.jpg` | 150-155 | 155 | **185** |
| 6 | `spring_beichen` | 春假·科幻片 | beichen | **cinema** | noon | `break_spring_chapter_beichen` | `holiday_spring_outing.jpg` | 150-155 | 155 | **185** |
| 7 | `summer_keke` | 暑假·萤火夜跑 | keke | **lakeside** | evening | `break_summer_chapter_keke` | `holiday_summer_trip.jpg` | 270-300 | 300 | **330** |
| 8 | `summer_zijun` | 暑假·夜市淘宝 | zijun | **community** | after | `break_summer_chapter_zijun` | `holiday_summer_trip.jpg` | 270-300 | 300 | **330** |
| 9 | `autumn_zicheng` | 秋假·桂花林 | zicheng | **lakeside** | evening | `break_autumn_chapter_zicheng` | `holiday_autumn_osmanthus.jpg` | 303-309 | 309 | **339** |
| 10 | `autumn_jingjing_m` | 秋假·桂花诗会 | jingjing_m | **community** | after | `break_autumn_chapter_jingjing_m` | `holiday_autumn_osmanthus.jpg` | 303-309 | 309 | **339** |

**地点分布**：`lakeside` ×4（且全是 priority 170 主章）/ `community` ×3 / `cinema` ×2 / `off_campus_shop` ×1。
**born**（记忆"发生日"）= `DailyCycleManager.BREAK_PERIODS[season][1]`，即该长假的**结束日**，**不需要存任何 flag**。
**mature**（可回响起始日）= `born + ECHO_MATURE_DAYS(30)`，见 §2.3 G4。

> ⚠️ **不要用 `WeatherManager.get_season()` 做季节匹配。** 核实：游戏内四季是**线性单次**的（春1-150 / 夏151-300 / 秋301-450 / 冬451-570），而长假的季节命名与之**错位**——寒假在 day 90-100（游戏内季节="spring"）。若把"当季"设为触发条件或文案变体条件，**春假记忆（mature 185 > 春季末 150）与暑假记忆（mature 330 > 夏季末 300）将永远无法命中**，产生 2 个死字段 / 死分支。本 GDD 因此**完全不引入季节匹配**，改用**终章变体**（`finale_line`，day ≥ 540 必然可命中，见 §1.4）。

### 1.3 回响文案（`lines`，每条 3 句）

**基调约束**（与 `design/holiday_events_design.md` 及 `events_break.json` 既有终场景对齐）：
- 第二人称旁白，`speaker: null`（house style，见 §3.2 论证）；
- 初中生视角、口语化、克制、不煽情；杭州具体物候；
- **不引入任何新角色、不引入新事件、不改变任何既有事实**；
- 三句的固定结构：**L1 触景（当下）→ L2 闪回（过去，内嵌「」原话）→ L3 独白（收束，留白）**。

---

**① `winter_yutong` · 寒假·雪夜断桥**（hint 基调："雪夜断桥，与雨桐的牵手时刻。"）
1. 湖风从断桥那头灌过来，你下意识把手插进口袋——又想起来，那天口袋里不是空的。
2. 那年寒假的雪夜，雪落在栏杆上化成一层薄水。她的手在你掌心颤了一下，谁都没有先松开。
3. 桥还是那座桥。只是今天没有下雪。
- `finale_line`：还有不到两个月就毕业了。你忽然很想再下一场那样的雪。

**② `winter_jingjing` · 寒假·糖水铺约定**（hint 基调："糖水铺，与菁菁的「明年同班」约定。"）
1. 小卖部门口飘出一股热气，甜的。你站了两秒才想起来这味道像什么。
2. 那年寒假的糖水铺，桂花酒酿冒着白汽。她把空碗往你这边一推：「记住你说的啊，赖账我就……」后半句她自己先笑没了。
3. 「明年同班」——那句话到底算不算数，你至今没敢问。
- `finale_line`：明年已经没有「同班」这回事了。你把这句咽了回去。

**③ `winter_yifei` · 寒假·冬夜影院**（hint 基调："冬夜影院，与逸飞的「下次还来」。"）
1. 影院大厅的空调风一吹，你打了个哆嗦。冬天的时候，这里更冷一点。
2. 那年寒假散场，街灯把两个人的影子拉得很长。他把保温杯塞进你手里捂了捂：「拿着，暖。」
3. 杯子后来还回去了。手心那点温度倒是留到了现在。
- `finale_line`：快毕业了。你想，散场之后，总得有人先走。

**④ `spring_wanqing` · 春假·桃林写生**（hint 基调："桃林写生，晚晴念出春天故事的主角名。"）
1. 苏堤这一段的桃树又开了。你走着走着就慢了下来。
2. 那年春假她坐在树下写生，花瓣落满裙摆。她念出故事主角的名字，声音轻得像花瓣落地——「……就是现在这个春天。」
3. 那个名字你听清了。你从来没有跟任何人说过。
- `finale_line`：春天还会再来。她那个本子，你不知道还在不在。

**⑤ `spring_xiaoxia` · 春假·攀岩馆**（hint 基调："攀岩馆，与小夏的每年之约。"）
1. 楼下那面广告牌换过一轮，还是攀岩馆的。你盯着看了一会儿。
2. 那年春假她挂在半空回头喊你，手心全是镁粉。落地之后撞了下你的肩：「说话算话啊，笨蛋！」
3. 「每年春天都来」——今年的春天，好像已经过去了。
- `finale_line`：毕业以后还能不能凑齐一次，谁也说不好。你决定先不想。

**⑥ `spring_beichen` · 春假·科幻片**（hint 基调："科幻片，与北辰的「下个春假老地方」。"）
1. 排片表上又挂了一部科幻片。海报那种蓝，跟那年那张有点像。
2. 那年春假的场子几乎没人。片尾字幕滚到一半，他忽然说：「下个春假，老地方。」虎牙一咧，「跑了我追你三条街。」
3. 老地方还在。追不追得上，就不一定了。
- `finale_line`：下个春假，你们大概已经不在同一所学校了。

**⑦ `summer_keke` · 暑假·萤火夜跑**（hint 基调："萤火夜跑，与可可的芦苇荡秘密基地。"）
1. 天刚黑，芦苇荡那边有细碎的光在动。可能是萤火虫，也可能只是眼花。
2. 那年暑假她拽着你一路跑到水边，指着一片乱晃的光说：「这是我们的秘密基地。」然后把额头轻轻抵在你肩上。
3. 秘密基地这种东西，好像只要说出口，就开始过期了。
- `finale_line`：今年夏天你没再来过这里。而现在再来，已经是最后一个夏天。

**⑧ `summer_zijun` · 暑假·夜市淘宝**（hint 基调："夜市淘宝，与子珺的河灯之约。"）
1. 楼下有人在摆摊，灯串一闪一闪。你想起另一条更长的街。
2. 那年暑假的夜市，河灯顺水漂得很慢。他把灯往水里推了推：「愿望要两个人一起许，才算数。」
3. 你到现在也没想起来，那天自己许的是什么。
- `finale_line`：现在倒是很清楚该许什么了。可惜灯早就漂远了。

**⑨ `autumn_zicheng` · 秋假·桂花林**（hint 基调："桂花林，与子诚的「每年秋天都来」。"）
1. 风里有桂花味。杭州一到这个时候，整座城都是这个味道。
2. 那年秋假的桂花林，花落了一石桌。他把纸袋往你怀里一塞：「成交！敢不来我天天堵你。」
3. 「每年秋天都来」——你数了数，还剩几个秋天。
- `finale_line`：答案是没有了。下一个秋天，你已经不在这所学校。

**⑩ `autumn_jingjing_m` · 秋假·桂花诗会**（hint 基调："桂花诗会，与菁菁（男）的朗诵之约。"）
1. 楼下的桂花开过一茬了，地上还留着一层碎金似的东西。
2. 那年秋假的诗会，他把整首桂花念完了，最后一行念得特别慢。散场时塞给你一枚桂花书签：「记住啊。」
3. 书签夹在哪本书里，你一时想不起来。但那一行你记得。
- `finale_line`：快毕业了。你翻遍了书架，想把那枚书签找出来。

### 1.4 `finale_line`（终章加句）

- 触发条件：`GameManager.day >= ECHO_FINALE_DAY(540)`，作为**第 4 句**追加在 `lines` 之后。
- 为什么选它而不是"当季加句"：540-570 这 31 天是**必然可达**的（游戏必定走到 day 570 结局），而"当季"对 4 条记忆中的 2 条永远不可达（§1.2 ⚠️）。**不写死分支**是本 GDD 的硬约束。
- 叙事价值：与 §2.4 的"终章加密"（冷却 14→5 天）形成合力——**越接近毕业，回忆来得越频繁、也越诚实**。这是一条被设计出来的情绪曲线，而不是平坦的随机噪声。

### 1.5 与 GALLERY `hint` 的关系

`GALLERY_ITEMS` 的 `hint`（如"雪夜断桥，与雨桐的牵手时刻。"）是**索引式**文案（给"翻抽屉"用，要一眼可辨）；`lines` 是**沉浸式**文案（给"抽屉自己打开"用，要有画面）。二者基调同源、用途不同，**不互相替代、不互相同步**。`hint` 保持原样不改。

> 工程兜底：若某 sid 在 `MEMORY_ECHO_CONTEXTS` 中 `lines` 为空（不应发生，由 T-2 断言拦截），`build_memory_echo_vignette()` 降级为单句 = 该条的 GALLERY `hint`，**不报错、不崩**。

---

## §2 触发模型（核心）

### 2.1 钩子选型：**故地重游（Location Re-entry）· 单主钩子**

| 候选钩子 | 采纳 | 理由 |
|---|---|---|
| **① 进入相关地点** | ✅ **选定为唯一主钩子** | 编码特异性原则（§0.3-1）；`loc` 有权威数据源（chapter 的 `location` 字段）；模式玩家的记忆池集中在 lakeside，而 lakeside 是全局访问频次最高的校外地点之一（周末全时段 + 工作日 after/evening + day 569 强制）；**唯一一个天然非重入的安全点**（§7-②） |
| ② 季节切换时 | ❌ | 游戏内四季线性单次且与长假季节命名错位，2/4 季永远不可命中（§1.2 ⚠️）。会产生死分支 |
| ③ `advance_time()` evening 分支 | ❌ **主动否决** | `advance_time()` 被 `DialogueUI.finish_event()`（L572）在**自身尚未 emit `event_finished` 时**调用。在此处拉起新的 `start_event()` 会与 `MainGame._on_event_finished()` 的 UI 恢复（`board_ui.show_center_info` + `update_ui`）产生栈内竞态。要修必须引入 pending 队列 + 延迟消费 + 多点轮询，代码量与风险都远大于收益。**详见 §8 D-1（作为可选扩展保留，默认不做）** |
| ④ 其它（毕业前夜） | ✅ **作为①的放宽分支** | day 569 `LocationManager.get_forced_location_for_day()` 强制 lakeside，本身就是"进入地点"。放宽守卫即可获得整个特性的情感峰值（§2.5） |

**播放位点**：`MainGame._on_location_selected(loc_id)` 的 **step 0** —— 即"选定地点之后、进入该地点之前"。
叙事上这是"你走到门口，忽然愣了一下神"；工程上这是**整条链路里唯一一个没有其它 UI 在栈上的时刻**（§4-D 给出精确契约）。

### 2.2 判定函数签名

```
CollectionManager.pick_memory_echo(loc_id: String) -> Dictionary
  显式输入 : loc_id                  （玩家正在进入的地点）
  隐式输入 : GameManager.day / slot_index / flags / current_holiday / favorability
             RelationshipManager.get_rel_state()
             DailyCycleManager.BREAK_PERIODS   （推导 born_day）
  输出     : {"sid": String}  命中一条  |  {}  不触发
  副作用   : 无（纯函数式判定，不写任何 flag）—— 写入由 commit_memory_echo() 独立负责
```

### 2.3 守卫清单（全部为硬门槛，任一不过即 `return {}`）

**阶段 0 · 全局门**（与具体记忆无关，先算，短路最快）

| 编号 | 守卫 | 判定 | 设计理由 |
|---|---|---|---|
| G0 | 非结局日 | `GameManager.day < 570` | day 570 是毕业典礼 + 结局结算，不插入任何软演出 |
| G3 | **非长假期间** | `GameManager.current_holiday == ""` | 长假正在**制造**新记忆，此时回响旧记忆会自我冲突；且玩家可能当天刚拿到该 flag |
| G6 | **全局冷却** | `day - flags.get("mem_echo_last_day", -999) >= gap`，`gap = 5 if day>=540 else 14` | 防刷屏**主兜底**。终章加密（§1.4） |
| G8 | **全局总次数上限** | `flags.get("mem_echo_total", 0) < ECHO_TOTAL_CAP(8) + (2 if day>=540 else 0)` | 整局硬顶 10 次 |

**阶段 1 · 逐条筛选**（遍历 `MEMORY_ECHO_CONTEXTS`）

| 编号 | 守卫 | 判定 | 设计理由 |
|---|---|---|---|
| G1 | **已解锁** | `GameManager.flags.has("holiday_memory_" + sid)` | 只回响玩家真的经历过的事 |
| G2 | **地点匹配** | `ctx["loc"] == loc_id` | 特性本体（编码特异性） |
| G4 | **成熟期** | `day >= BREAK_PERIODS[season][1] + ECHO_MATURE_DAYS(30)` | 刚发生 3 天就"回响"极其出戏。30 天 ≈ 一个多月，足够沉淀。**零新 flag、纯常量推导** |
| G5 | **单条冷却** | `day - flags.get("mem_echo_<sid>_last", -999) >= ECHO_MEM_COOLDOWN_DAYS(60)` | 同一段记忆两个月内不重复 |
| G7 | **单条次数上限** | `flags.get("mem_echo_<sid>_count", 0) < ECHO_PER_MEM_CAP(2)` | 同一段记忆整局最多 2 次；第 2 次通常落在终章（配 `finale_line`，形成"同一记忆的今昔两读"） |
| G9 | **排除冷战** | `RelationshipManager.get_rel_state(char) != "cold"` | **对齐既有惯例**：`InitiativeManager.check_night_chat()` L165 同款守卫。冷战期玩家的注意力在修复关系上，插甜蜜回忆属于**支柱漂移**（把玩家从当下张力里拉走）。可反悔项见 §8 D-2 |

> **刻意不设的守卫**（列出以免下游误加）：
> - ❌ 不设 `stress` 门槛 —— 玩家无法预测也无法理解"为什么今天没回响"，制造隐性黑箱。
> - ❌ 不设天气门槛 —— 同上，且与 §1.2 的死分支风险同源。
> - ❌ 不设 `minAff` —— 记忆已经解锁就说明当初达标了；此后好感掉了不该抹掉过去。好感只参与**排序权重**（§2.4）。
> - ❌ 不设 `slot` 硬匹配 —— 原发时段仅作强权重（§2.4），硬匹配会把命中率砍到 1/4。

### 2.4 命中后的选择（多条同时通过守卫时）

确定性打分，**降序取第一**：

```
score(sid) =  100 · [ ctx.slot == GameManager._get_slot_id() ]     # 原发时段匹配 —— 最强的"情境"信号
            +  50 · [ mem_echo_<sid>_count == 0 ]                  # 从未回响过 —— 覆盖广度优先
            +  clampi(GameManager.favorability[char] / 10, 0, 10)  # 关系越深越容易浮现（0-10）
            +  min(day - mem_echo_<sid>_last, 200) / 100.0         # 越久未响越优先（0.0-2.0；从未响过按 200 计）
平局打破：sid 字典序升序（全序，结果可复现，便于静态测试）
```

四项权重两两不同量级（100 / 50 / 10 / 2），**不存在主导策略问题**——玩家无法也不需要为它做任何决策，这是纯被动系统。

### 2.5 毕业前夜特例（day 569）

`LocationManager.get_forced_location_for_day()` 在 day 569 强制只能去 lakeside。该日：

| 放宽项 | 说明 |
|---|---|
| **忽略 G2（地点）** | 从**全部已解锁记忆**中选，不再要求 loc 匹配。理由：最后一夜站在西湖边，想起的不一定是湖边的事 |
| **忽略 G5 / G6 / G7 / G8**（全部冷却与上限） | 保证任何拥有 ≥1 条记忆的玩家**必然**在这一夜得到一次回响 |
| 保留 G0 / G1 / G3 / G4 / G9 | 未解锁 / 未成熟 / 冷战的记忆仍然不响 |
| 选择规则 | `count` 升序 → 其余同 §2.4。即"优先给你还没想起过的那一段" |
| 文案 | day 569 ≥ 540，自动追加 `finale_line` |

> 这条特例是整个特性的**保底**：即使玩家只解锁了 1 条记忆、且从未在情境中触发过，也一定会在毕业前夜的西湖边收到它。特性的下限因此从"可能一次都看不到"提升为"至少一次，且落在情感峰值上"。

### 2.6 密度推演（S-3 的算术证明）

| 场景 | 记忆池 | 推演 | 总回响次数 |
|---|---|---|---|
| 极小池（1 条，winter_yutong） | 1 | mature 130 → 首响 ~130；G5 冷却 60 天 → 次响 ~190；G7 上限 2 → 停。+ day 569 特例 1 次 | **3** |
| 典型池（4 条，每假主章） | 4 | 窗口 130-539 共 410 天 / G6 14 天 = 29 次机会，被 G8(8) 与 G7(4×2=8) 同时约束 → 8 次；终章 540-568 冷却 5 天 → 最多 +2；+ 569 特例 1 次 | **≤ 11** |
| 满池（10 条，理论极限） | 10 | 同上，G8 硬顶不变 | **≤ 11** |

**最坏情况下，570 天内回响 ≤ 11 次，平均间隔 ≥ 50 天。任意两次间隔 ≥ 5 天（终章）/ ≥ 14 天（常态）。** 刷屏在数学上不可能发生。

---

## §3 回响表现（UI）

### 3.1 播放管线：**完全复用 `DialogueUI.start_event()`，零新播放器**

与西湖十景 vignette（`CollectionManager.build_stamp_vignette()` → `DialogueUI.start_event()`）走**同一条管线**。核实过的关键行为：

| DialogueUI 行为 | 位置 | 对回响的影响 |
|---|---|---|
| 事件级 `bg` 覆盖背景层 | L117-121 | ✅ **这是 CG 全屏 flashback 的实现基础**，直接喂 `holiday_<season>.jpg` |
| `location == ""` 时跳过背景加载 | L135-137 | ✅ 我们传 `""`，让事件级 `bg` 独占背景 |
| `location == ""` 时跳过 `_apply_location_gains` | L144-145 | ✅ **必须传 `""`**，否则回响会重复发放地点属性增益 + 弹天气 toast |
| `charId == ""` 时跳过 `last_interact_` / 日记 | L542-549 | ✅ 我们**不传 `charId`**，回响不算"和角色互动过"（不影响冷落惩罚计时） |
| `repeatable == true` 时不写 `flags[event_id]` | L540-541 | ✅ **必须传 `true`**，否则会污染出 `mem_echo_<sid>` 布尔键 |
| `speaker == null` → 清空立绘 + 名字条留空 | L178-179 / L234-239 | ✅ 见 §3.2 |
| `pose != "" and speaker 非空/非 player` → 自动 `unlock_gallery("seen_<char>_<pose>")` | L219-223 | ⚠️ **回响 scene 一律不写 `pose` 字段**，避免产出 `seen_yutong_memory` 这类不在 `GALLERY_ITEMS` 中的垃圾键 |

### 3.2 视觉形态：**全屏 CG + 纯旁白，无立绘**

**决策：所有 scene 使用 `speaker: null`。**

| 备选 | 结论 |
|---|---|
| `speaker: <char>` + `pose: "memory"` | ❌ **资产不存在**。已 `ls` 核实：`assets/sprites/*/memory.*` 一个都没有。`GALLERY_ITEMS` 的 `pose:"memory"` 只是画廊条目的分类标签，画廊渲染走的是 `bg` 字段（CG），不加载同名立绘。硬用会走到 `DialogueUI.gd:307` 的 `print("警告: 找不到立绘")` 分支 |
| `speaker: <char>` + 不写 pose（fallback `default`） | ❌ 校服立绘 + 假期 CG 背景 = 严重穿帮；且 flashback 里出现"当下的立绘"会把画面拉回现在 |
| `speaker: "narrator"` | ❌ 名字条会显示字面量 `narrator`（L176-177，`DataManager.get_character("narrator")` 返回空 → fallback 到 id 本身） |
| **`speaker: null`（选定）** | ✅ 名字条留空（L179）、立绘清空（L234-239）、**全屏只剩 CG 与文字**。这正是 flashback 该有的样子。且**与 `events_break.json` 全部 10 个记忆终场景的写法逐字一致**（那些场景本身就是 `"speaker": null` + 第二人称旁白 + 内嵌「」原话）——回响与记忆源头共用同一声道 |

### 3.3 轻差异化（可选 P1）

CG 突然覆盖当前地点背景，本身已是极强的"闪回"信号。在此之上建议一处**极轻量**差异化：

- **`bgTint`（P1，可选）**：事件级字段，`Array[float]` = RGBA。`DialogueUI.start_event()` 在 L121 之后追加 3 行：若事件带 `bgTint` 则 `bg_rect.modulate = Color(...)`，并在 `finish_event()` 末尾复位 `bg_rect.modulate = Color.WHITE`。回响统一用 `[1.0, 0.94, 0.86, 1.0]`（微暖褪色，"旧照片"感）。
- **P0 不依赖它**。若 engineering-lead 认为 modulate 复位有回归风险（如与 `GameUtils.load_bg_texture` 的时段调色叠加），**直接跳过 P1，特性完整可用**。

> ❌ **明确不做**：不加边框、不加 vignette 遮罩、不加转场动画、不新建任何 `.tscn` / `.gd`。`DialogueUI` 的打字机效果（L310+）已经提供了足够的"缓慢浮现"质感。

### 3.4 收敛方式：**不消耗时段**（决策 + 论证）

**决策：回响 `noTimeCost: true`，播放前后 `GameManager.day` / `slot_index` 完全不变。**

论证：

1. **玩家没有请求它。** 回响是系统主动插入的被动演出。对一个玩家未主动发起的行为收取 570 天流程中最稀缺的资源（时段），是**惩罚性设计**。
2. **会立刻扭曲玩家行为。** 若消耗时段，玩家会学会"初三别去西湖边，会白掉半天"——这直接摧毁了特性想营造的"故地重游"心理，反而把 lakeside 变成需要规避的地点。这是典型的**支柱漂移**。
3. **它不提供任何收益。** 回响不加属性、不加好感、不给物品（刻意为之，见下）。既然没有产出，就不能有成本。

**实现契约**（这是本 GDD 唯一必需的引擎能力补齐，见 §4-A）：
`DialogueUI.finish_event()` L571-572 的 `else: GameManager.advance_time()` 改为
`elif not current_event.get("noTimeCost", false): GameManager.advance_time()`。
**纯新增语义、1 行改动**：全工程当前无任何事件携带 `noTimeCost` 键 → 零回归面。

**回响之后回到哪里**：回响在进入地点**之前**播放，播完后由 `MainGame` 重新走一遍 `_on_location_selected(loc_id)`（此时冷却已写入，`pick_memory_echo` 必然返回 `{}`，天然防递归），玩家**正常进入该地点**，什么都没损失。见 §4-D。

### 3.5 回响的"产出"

**刻意零机制产出**：不加属性、不加好感、不给物品、不解锁任何 flag、不发 toast。

唯一的两条落地痕迹（写在 `commit_memory_echo()` 里，都是纯记录）：
- `GameManager.add_log("🕯️ 记忆回响 · <label>")` —— 进主界面日志流；
- `GameManager.add_diary_entry("忽然想起<label>")` —— 进日记本，**这条最重要**：它让"回忆"这件事在玩家的日记里留下时间戳，三年后翻日记能看到"我在第 342 天想起了第 100 天的那个雪夜"。这是本特性与日记系统的唯一耦合，也是它最好的长尾。

> 不发 toast 的理由：全屏 CG 演出已经是最强通知；再叠一条 toast 是**认知过载**，且 `MainGame._on_show_toast` 会把它二次写进日志，造成重复。

---

## §4 接线清单

按依赖顺序。**共 3 个文件，0 个新建，0 个新 Autoload，0 个新美术资产。**

| # | 文件 | 位置 | 改动 | 类型 | 优先级 |
|---|---|---|---|---|---|
| **A** | `scripts/DialogueUI.gd` | **L571-572**（`finish_event()` 尾部的 `else: GameManager.advance_time()`） | `else:` → `elif not current_event.get("noTimeCost", false):` | 引擎能力补齐（**1 行**） | **P0 · 必需** |
| **B** | `scripts/DialogueUI.gd` | L121 之后（事件级 bg 覆盖块）+ `finish_event()` 内 `hide()` 前 | `bgTint` 支持：设置 `bg_rect.modulate`，结束时复位 `Color.WHITE` | 引擎能力（3 行） | P1 · 可选（§3.3） |
| **C** | `scripts/CollectionManager.gd` | **文件末尾（L338 之后）** 新增「记忆回响」区 | ① `const MEMORY_ECHO_CONTEXTS`（§5.2）② 6 个常量（§5.1）③ `pick_memory_echo(loc_id) -> Dictionary` ④ `commit_memory_echo(sid) -> void` ⑤ `build_memory_echo_vignette(sid) -> Dictionary` ⑥ `_memory_gallery_item(sid) -> Dictionary`（私有反查）⑦ `_memory_born_day(sid) -> int`（私有推导） | 新增逻辑（**核心**） | P0 |
| **D** | `scripts/MainGame.gd` | **L216-220** `_on_location_selected()` | step 0 插入 + 新增私有方法 `_try_memory_echo(loc_id) -> bool` | 集成（**~14 行**） | P0 |

### 4.1 改动 D 的精确契约

```gdscript
# ── 现状（MainGame.gd L216-220）────────────────────────────
func _on_location_selected(loc_id: String):
    GameManager.current_location = loc_id
    center_info.hide()
    hotspot_container.show()
    hotspot_ui.on_location_selected(loc_id)          # ← step 0 插在这一行之前

# ── 改后 ────────────────────────────────────────────────
func _on_location_selected(loc_id: String):
    GameManager.current_location = loc_id
    center_info.hide()
    hotspot_container.show()
    if _try_memory_echo(loc_id): return              # ← 新增：命中则先播回响，播完自回调
    hotspot_ui.on_location_selected(loc_id)

## 情境回响 step 0（GDD §2.1 / §3.4）
## 命中 → 播放 flashback（不消耗时段），播完后重入 _on_location_selected 正常进地点。
## 返回 true 表示"本次已被回响接管"，调用方应立即 return。
func _try_memory_echo(loc_id: String) -> bool:
    var hit: Dictionary = CollectionManager.pick_memory_echo(loc_id)
    if hit.is_empty(): return false
    var vignette: Dictionary = CollectionManager.build_memory_echo_vignette(hit["sid"])
    if vignette.is_empty(): return false             # 数据异常兜底：静默放行，不阻断进地点
    CollectionManager.commit_memory_echo(hit["sid"]) # ← 必须在 start_event 之前写冷却（防重入）
    location_explore_ui.hide()
    dialogue_ui.show()
    # 一次性回调：回响播完 → 重走一遍进地点流程（此时冷却已写，pick 必返回 {}，无递归风险）
    dialogue_ui.event_finished.connect(
        func(): _on_location_selected(loc_id), CONNECT_ONE_SHOT)
    dialogue_ui.start_event(vignette)
    return true
```

**信号顺序核实**（关键，engineering-lead 请确认）：
`MainGame._ready()` L40 已把 `_on_event_finished` 连到 `dialogue_ui.event_finished`（**先连**）。本处的一次性 lambda **后连**。Godot 按连接顺序派发 → `_on_event_finished()`（`show_center_info` + `update_ui`）先跑，随后 lambda 重入 `_on_location_selected()` 执行 `center_info.hide()` + `hotspot_container.show()`。**最终 UI 状态正确**（回到探索层），顺序无需额外干预。

**为什么把 `commit` 放在 `start_event` 之前**：`start_event` 内部会 `show()` 并可能同步触发信号；先落冷却可保证任何异常路径下都不会二次命中同一条记忆（宁可漏播一次，不可重复播）。

### 4.2 明确**不需要**改动的项

| 项 | 理由 |
|---|---|
| `project.godot` | 零新 Autoload。逻辑寄居已注册的 `CollectionManager`（S-1） |
| `SaveSystem.gd` | `flags` 字典整体序列化，新增任意键零迁移（`GameManager.set_flag()` L678-685 已支持 int 值） |
| `scripts/HotspotExploreUI.gd` | **完全不动**。step 0 挂在更上游的 `MainGame._on_location_selected`，`hotspot_ui.on_location_selected()` 的全部既有逻辑（special 事件优先、探索模式、NG+ 熟悉感）零改动 |
| `scripts/LocationManager.gd` | 不新增热点、不改可达性 |
| `scripts/GameManager.gd` | 不改 `GALLERY_ITEMS`、不改 `locations`、不改 `advance_time()`（③号钩子已否决，§2.1） |
| `scripts/events_break.json` | 10 条 `holiday_memory_*` 的 `setFlag` 已完整落地，不动 |
| `assets/**` | 4 张 CG 齐备，零新资产 |
| `scripts/EndingScreen.gd` | NG+ 走既有 `flags = {}`（L440），`mem_echo_*` 不在继承白名单（L465-467 仅 `ng_count`/`seen_endings`/`title_*`）→ 自动清零（S-7） |
| `scripts/GalleryPopupUI.gd` | 回响不改画廊任何数据 |

### 4.3 NG+ 行为确认

| 键 | NG+ 后 | 符合预期 |
|---|---|---|
| `mem_echo_<sid>_last` / `_count` | 清空 | ✅ 新周目没有旧记忆 |
| `mem_echo_last_day` / `mem_echo_total` | 清空 | ✅ 冷却与配额重置 |
| `holiday_memory_*`（前置） | 清空（既有行为） | ✅ 新周目重新经历长假 → 回响池自然从 0 重建 |

**无需任何 NG+ 专属代码。**

---

## §5 数据格式

### 5.1 常量（放 `CollectionManager.gd` 记忆回响区顶部）

```gdscript
# ── 记忆回响（DS-RN-02）调参常量 ──────────────────────────────
const ECHO_MATURE_DAYS        := 30    # 记忆"沉淀期"：born_day + 30 起才可回响（G4）
const ECHO_MEM_COOLDOWN_DAYS  := 60    # 单条记忆冷却（G5）
const ECHO_GLOBAL_GAP_DAYS    := 14    # 全局冷却 · 常态（G6）
const ECHO_GLOBAL_GAP_FINALE  := 5     # 全局冷却 · 终章加密（G6，day >= 540）
const ECHO_PER_MEM_CAP        := 2     # 单条记忆整局回响次数上限（G7）
const ECHO_TOTAL_CAP          := 8     # 全局整局回响次数上限（G8）
const ECHO_FINALE_BONUS       := 2     # 终章额外配额（G8，day >= 540）
const ECHO_FINALE_DAY         := 540   # 终章起始日（finale_line + 加密 + 加配额）
const ECHO_LAST_NIGHT_DAY     := 569   # 毕业前夜特例日（§2.5）
const ECHO_BG_TINT            := [1.0, 0.94, 0.86, 1.0]   # P1 可选，见 §3.3
```

### 5.2 `MEMORY_ECHO_CONTEXTS`（触发上下文映射表 · 唯一真源）

**只装本层独有的信息。** `char` / `bg` / `label` 从 `GALLERY_ITEMS` 反查，`born_day` 从 `DailyCycleManager.BREAK_PERIODS` 推导 —— **零数据重复**（S-6）。

```gdscript
# ── 记忆回响上下文映射（GDD §1.2 / §1.3）─────────────────────
# 键 sid = "<season>_<char>"，与 flag 一一对应：flag = "holiday_memory_" + sid
# 字段（仅 4 个，其余全部派生）：
#   loc          String        原发地点 —— 逐字取自 events_break.json 对应 chapter 的 "location"
#   slot         String        原发时段 —— 逐字取自同一 chapter 的 "slotId"（仅作排序强权重，非门槛）
#   lines        Array[String] 回响正文 3 句：触景 / 闪回 / 独白
#   finale_line  String        day >= ECHO_FINALE_DAY 时追加的第 4 句
# 派生（不要在此重复定义，由函数运行时求值）：
#   flag   = "holiday_memory_" + sid
#   season = sid.split("_")[0]
#   char   = sid.substr(season.length() + 1)          # "autumn_jingjing_m" → "jingjing_m"
#   born   = DailyCycleManager.BREAK_PERIODS[season][1]
#   bg / label / hint = _memory_gallery_item(sid) 从 GameManager.GALLERY_ITEMS 反查
# ⚠️ 字典保持插入顺序；不要对 keys() 排序（排序由 §2.4 打分函数负责）。
const MEMORY_ECHO_CONTEXTS = {
    "winter_yutong":     { "loc": "lakeside",        "slot": "evening", "lines": [...], "finale_line": "..." },
    "winter_jingjing":   { "loc": "off_campus_shop", "slot": "after",   "lines": [...], "finale_line": "..." },
    "winter_yifei":      { "loc": "cinema",          "slot": "noon",    "lines": [...], "finale_line": "..." },
    "spring_wanqing":    { "loc": "lakeside",        "slot": "evening", "lines": [...], "finale_line": "..." },
    "spring_xiaoxia":    { "loc": "community",       "slot": "after",   "lines": [...], "finale_line": "..." },
    "spring_beichen":    { "loc": "cinema",          "slot": "noon",    "lines": [...], "finale_line": "..." },
    "summer_keke":       { "loc": "lakeside",        "slot": "evening", "lines": [...], "finale_line": "..." },
    "summer_zijun":      { "loc": "community",       "slot": "after",   "lines": [...], "finale_line": "..." },
    "autumn_zicheng":    { "loc": "lakeside",        "slot": "evening", "lines": [...], "finale_line": "..." },
    "autumn_jingjing_m": { "loc": "community",       "slot": "after",   "lines": [...], "finale_line": "..." },
}
```

`lines` / `finale_line` 的正文见 **§1.3**，engineering-lead 直接照抄填入，无需二次编辑。

### 5.3 flag 命名规范

**全部以 `mem_echo_` 为前缀**（便于 grep 与 NG+ 审计）。共 4 类键，最多 `10×2 + 2 = 22` 个：

| 键 | 类型 | 写入方 | 语义 |
|---|---|---|---|
| `mem_echo_<sid>_last` | `int` | `commit_memory_echo()` | 该条记忆最近一次回响的 `day`（G5 冷却基准）。未回响过 → 键不存在，读取默认 `-999` |
| `mem_echo_<sid>_count` | `int` | `commit_memory_echo()` | 该条记忆整局已回响次数（G7 上限基准）。默认 `0` |
| `mem_echo_last_day` | `int` | `commit_memory_echo()` | **任意**记忆最近一次回响的 `day`（G6 全局冷却基准）。默认 `-999` |
| `mem_echo_total` | `int` | `commit_memory_echo()` | 整局回响总次数（G8 上限基准）。默认 `0` |

**完整 sid 清单**（供工程直接复制，10 条）：
```
winter_yutong      spring_wanqing     summer_keke      autumn_zicheng
winter_jingjing    spring_xiaoxia     summer_zijun     autumn_jingjing_m
winter_yifei       spring_beichen
```

> 写入一律走 `GameManager.set_flag(key, int_value)` —— L678-685 已核实：非 bool 值直接赋值，支持 int。**不要**用 `flags[key] = v` 直接写（保持单一写入 API）。

### 5.4 vignette dict 示例（`build_memory_echo_vignette("winter_yutong")` 在 day 342 的返回值）

```gdscript
{
    "id":         "mem_echo_winter_yutong",
    "location":   "",          # ⚠️ 必须空串：跳过地点增益重复发放 + 天气 toast（DialogueUI L144-145）
    "title":      "🕯️ 记忆回响 · 寒假·雪夜断桥",   # 装饰性；DialogueUI 当前不渲染 title，保留供调试
    "bg":         "res://assets/backgrounds/holiday_winter.jpg",  # ← 反查 GALLERY_ITEMS.bg
    "isSpecial":  false,       # 不进 special 优先级队列
    "repeatable": true,        # ⚠️ 必须 true：否则 finish_event L540-541 会写出 mem_echo_winter_yutong 布尔键
    "noTimeCost": true,        # ⚠️ 新引擎字段（§4-A）：不推进时段
    # "charId" 刻意不写 —— 避免 finish_event L542-549 写 last_interact_ 与日记条目
    # "bgTint": [1.0, 0.94, 0.86, 1.0],   # P1 可选（§3.3）
    "scenes": [
        {"speaker": null, "text": "湖风从断桥那头灌过来，你下意识把手插进口袋——又想起来，那天口袋里不是空的。"},
        {"speaker": null, "text": "那年寒假的雪夜，雪落在栏杆上化成一层薄水。她的手在你掌心颤了一下，谁都没有先松开。"},
        {"speaker": null, "text": "桥还是那座桥。只是今天没有下雪。", "next": 99},
    ],
}
```

**day ≥ 540 时**：第 3 句去掉 `"next": 99`，在其后追加
`{"speaker": null, "text": <finale_line>, "next": 99}`。

**每个 scene 的硬约束**（静态断言 T-6 守护）：
- ❌ 不写 `pose`（防 `seen_<char>_memory` 垃圾键，§3.1）
- ❌ 不写 `setFlag` / `setFlags` / `addItem`（回响零产出，§3.5）
- ❌ 不写 `affDelta` / `statDelta` / `statsDelta`（同上）
- ❌ 不写 `choices`（被动演出，无交互分支）
- ✅ 仅最后一条写 `"next": 99`

### 5.5 派生函数契约

```gdscript
## 从 GALLERY_ITEMS 反查该记忆的画廊条目（char / label / hint / bg 的唯一真源）
## 未找到时返回 {}，调用方须做空判断（数据异常兜底：整条回响静默跳过，不崩）
func _memory_gallery_item(sid: String) -> Dictionary
    # 遍历 GameManager.GALLERY_ITEMS，取 item["flag"] == "holiday_memory_" + sid 的那条

## 从 DailyCycleManager.BREAK_PERIODS 推导该记忆的"发生日"（= 所属长假结束日）
## sid 前缀不在 BREAK_PERIODS 中时返回 99999（永不成熟，安全失败）
func _memory_born_day(sid: String) -> int
    # season = sid.split("_")[0]；return int(BREAK_PERIODS[season][1])
```

---

## §6 与现有系统的边界

### 6.1 与画廊（`GalleryPopupUI` / `GALLERY_ITEMS`）—— **互补，零重叠**

| 维度 | 珍贵画廊 | **记忆回响** |
|---|---|---|
| 发起方 | 玩家（点主界面按钮） | 系统（进入原发地点时） |
| 心理动作 | "我去打开抽屉" | "抽屉自己打开了" |
| 呈现 | 网格缩略图 + 一行 `hint` | 全屏 CG + 3-4 句旁白 |
| 可及性 | 随时、无限次 | 稀有、整局 ≤ 11 次 |
| 数据 | `GALLERY_ITEMS`（**真源**） | `MEMORY_ECHO_CONTEXTS`（仅 loc/slot/lines，char/bg/label **反查画廊**） |
| 写入 | `unlock_gallery()` 写 `holiday_memory_*` | **不写任何画廊键**，只读 |

**回响是画廊的消费者，不是竞争者。** 回响甚至有正向导流：玩家看完一次 flashback，更可能去画廊翻完整的 10 条。

### 6.2 与西湖十景集章（`stamp_*`）—— 三层不同的"回顾"

`design/west_lake_stamps_gdd.md` §0.2 已划定边界，本 GDD 遵守并补全：

| 系统 | 回顾的是 | 触发 | 时段成本 |
|---|---|---|---|
| 集章簿 | **我去过哪**（空间） | 主动（热点 / board 按钮） | 盖章 1 时段 |
| 珍贵画廊 | **我见过谁**（索引） | 主动（board 按钮） | 0 |
| **记忆回响** | **我和谁发生过什么**（时间纵深） | **被动（情境）** | **0** |

**零冲突点核实**：
- 回响不写 `stamp_*`、不读 `stamp_*`、不影响 `stamp_checkin_day` 每日额度；
- 集章 vignette 走 `HotspotExploreUI._open_west_lake_stamp_checkin()`（热点点击后），回响走 `MainGame._on_location_selected()` step 0（**进入地点之前**）—— 时序上一前一后，物理上不可能同帧；
- 极端同日场景：玩家 day 342 evening 进 lakeside → 回响播放（不消耗时段）→ 进探索层 → 点集章热点 → 盖章（消耗 1 时段）。**两件事都发生，互不干扰，体验连贯。**

### 6.3 与深夜聊天 / 朋友圈（`InitiativeManager`）—— 不同的媒介、不同的时态

| | 深夜聊天 | **记忆回响** |
|---|---|---|
| 媒介 | 微信消息（文字，异步，可回复） | 全屏 CG flashback（演出，同步，不可交互） |
| 时态 | **现在时**（对方此刻在想你） | **过去时**（你此刻想起过去） |
| 主体 | 角色主动 | 玩家内心 |
| 钩子 | `advance_time()` evening 分支（`GameManager.gd` L463-465） | `MainGame._on_location_selected()` step 0 |
| 冷却键 | `night_chat_day_<day>` / `night_chat_last_<cid>` | `mem_echo_last_day` / `mem_echo_<sid>_last` |
| 队列 | `char_initiative[cid]["wechat_msg"]` | 无队列（同步播完即止） |

**共享的唯一约定**：G9（排除 `cold` 状态）刻意与 `check_night_chat()` L165 保持同款语义 —— 冷战期，系统一律不做温情推送。这是跨系统的一致性纪律。

**回响不产生任何微信消息、不占用 `wechat_msg` 槽位、不触碰 `pending_invite`。**

---

## §7 风险与缓解

### ① 触发刷屏

**风险**：玩家反复进出 lakeside 刷 CG，或后期每天弹。
**缓解（四层，任一层独立生效）**：
1. G6 全局冷却 14 天（终章 5 天）—— 主兜底；
2. G8 全局总上限 8（终章 +2）—— 硬顶；
3. G5 单条冷却 60 天 + G7 单条上限 2 —— 防同一段记忆重复；
4. G4 成熟期 30 天 —— 掐掉"刚发生就回响"的窗口。

**S-3 已给出算术证明（§2.6）：最坏情况整局 ≤ 11 次，平均间隔 ≥ 50 天。** 刷屏不可能发生。
**反向风险（过稀）**由 §2.5 毕业前夜特例兜底：任何拥有 ≥1 条记忆的玩家必然至少看到 1 次，且落在情感峰值。

### ② 回响打断当前流程 —— **本 GDD 最重要的风险，已用选址消解**

**风险**：回响在对话中 / 事件中 / 结算中触发，与既有 UI 抢栈。

**缓解 = 选址而非补丁**。回响的唯一播放点是 `MainGame._on_location_selected()` step 0，该点的性质：

| 性质 | 核实 |
|---|---|
| 是玩家**主动点击**触发的同步调用 | `LocationListUI` / `CenterDashboardUI` 的 action 回调 / `_on_accept_invite` 三个入口全部收敛于此 |
| 调用时**栈上无其它 UI** | `DialogueUI` 未启动、`LocationExploreUI` 未 show、无子 UI 实例 |
| **不在 `advance_time()` 栈内** | 这正是否决③号钩子的理由（§2.1）。`advance_time()` 被 `DialogueUI.finish_event()` L572 在自身 emit 前调用，在其中拉起 `start_event()` 会与 `MainGame._on_event_finished()` 的 UI 恢复产生竞态 |
| 特殊事件不会被抢 | `hotspot_ui.on_location_selected()` 的 step 1（`DataManager.get_available_event` 高优 special）在回响**之后**才执行 —— 回响播完重入时才轮到它。**高优剧情不会被回响吞掉，只会被延后几秒** |

**因此本特性不需要 pending 队列、不需要延迟消费、不需要多点轮询。** 这是选址换来的复杂度削减，也是不选③号钩子的核心收益。

**残留风险（可接受）**：玩家点了 lakeside，先看 15 秒 flashback 才进去。这在恋爱模拟里是**正收益**，不缓解。

### ③ 无 Godot runtime → 静态断言验证清单

移交 quality-lead（严守真）。建议新建 `tests/memory_echo_smoke/`（对齐 `tests/west_lake_stamps_smoke/` 的 `verify_qa.py` + `QA_REPORT.md` 双文件结构），**全部为静态断言**（grep / JSON parse / 常量比对 / 算术验算），零引擎依赖：

| # | 断言 | 方法 | 守护的标准 |
|---|---|---|---|
| T-1 | `MEMORY_ECHO_CONTEXTS` 恰含 10 键，键集合 == §1.2 sid 全集 | 解析 `CollectionManager.gd` 常量块 | S-2 |
| T-2 | 每条的 `lines` 长度 == 3 且非空串；`finale_line` 非空串 | 常量遍历 | §1.3 |
| T-3 | **每条的 `loc` / `slot` 与 `events_break.json` 中 `break_<season>_chapter_<char>` 的 `location` / `slotId` 逐字一致** | JSON 交叉比对（**最关键的一条**，防设计漂移） | §1.2 真源 |
| T-4 | 每条 `"holiday_memory_" + sid` 都能在 `GALLERY_ITEMS` 中找到 `flag` 完全相等的条目 | 双源交叉 grep | S-2 / S-6 |
| T-5 | `MEMORY_ECHO_CONTEXTS` 中**不出现** `char` / `bg` / `label` / `born` 字段名 | 常量块字段名扫描 | S-6 数据不重复 |
| T-6 | 全部 `lines` / `finale_line` 所在的 scene 构造中**不出现** `pose` / `setFlag` / `setFlags` / `addItem` / `affDelta` / `statDelta` / `statsDelta` / `choices` | 审 `build_memory_echo_vignette()` 源码 | §5.4 硬约束 |
| T-7 | `build_memory_echo_vignette()` 返回的 dict 含 `"location": ""` 且 `"repeatable": true` 且 `"noTimeCost": true`，且**不含** `"charId"` 键 | 源码字面量比对 | S-4 / §3.1 |
| T-8 | `DialogueUI.gd` 中 `noTimeCost` 有且仅有 1 处出现（`finish_event()` 内），且原 `else: GameManager.advance_time()` 语义未被其它改动影响 | grep + diff | S-4 |
| T-9 | 全工程 `noTimeCost` 的写入方只有 `CollectionManager.build_memory_echo_vignette()`（即无既有事件 JSON 携带该键） | 全仓 grep（含所有 `events_*.json`） | S-4 零回归 |
| T-10 | `build_memory_echo_vignette` / `pick_memory_echo` 的调用点各有且仅有 1 处，均在 `MainGame.gd` | 全仓 grep | S-5 |
| T-11 | 常量算术：`ECHO_TOTAL_CAP + ECHO_FINALE_BONUS <= 10` 且 `ECHO_GLOBAL_GAP_FINALE >= 5` 且 `ECHO_MEM_COOLDOWN_DAYS >= 2 × ECHO_GLOBAL_GAP_DAYS` | 常量解析 + 验算 | S-3 |
| T-12 | 成熟期可达性：对 4 个 season，`BREAK_PERIODS[season][1] + ECHO_MATURE_DAYS < 569` | 常量验算（防"某季记忆永不成熟"） | §1.2 |
| T-13 | `project.godot` `[autoload]` 段与改动前逐字节一致；`scripts/` 目录无新增 `.gd`；`assets/` 无新增文件 | diff + 文件列表比对 | S-1 / S-2 |
| T-14 | 全工程 `mem_echo_` 前缀键的写入点仅出现在 `CollectionManager.gd` 的 `commit_memory_echo()` 一处 | 全仓 grep | 单一写入源 |
| T-15 | `mem_echo_` **不在** `EndingScreen.gd` L465-467 的 NG+ 继承白名单中 | grep | S-7 |
| T-16 | `CollectionManager` 记忆回响区**不调用** `unlock_gallery` / `set_flag("stamp_*")` / `show_toast.emit` | grep | S-8 / §3.5 |

### ④ 上游内容可达性风险（**移交核实，非本 GDD 修复**）

核实 `LocationManager.get_available_locations()` L82-87 与 chapter 条件后发现一处**既有内容可达性疑点**，会影响记忆池规模，请 engineering-lead / quality-lead 复核：

> `break_spring_chapter_xiaoxia` / `break_summer_chapter_zijun` / `break_autumn_chapter_jingjing_m` 三个 chapter 的 `location` = `community`、`slotId` = `after`；而 `GameManager.locations["community"]["slots"]` 只有 `["evening"]`（L176）。`get_available_locations()` L86 `if not slot_id in loc_slots: continue` 会使 community 在 `after` 时段**不出现在地点列表中**。
> **可达路径仅剩邀约**：`InitiativeManager` 给 jingjing / jingjing_m 设 `pending_invite = "community"`（L310），`MainGame._on_accept_invite()` L231 直接 `_on_location_selected(loc_id)` **绕过可达性检查**。
> **影响**：这 3 条记忆的解锁窗口极窄 → 回响池实际以 lakeside 4 条 + cinema 2 条 + off_campus_shop 1 条为主。
> **本 GDD 的立场**：**不修**（超出范围，且属既有内容 bug）。设计上已通过"主钩子挂地点 + lakeside 占 4 条主章 + day 569 无视地点特例"三重措施，使特性在最坏情况下依然可用。若上游修复该问题，回响池自动变大，**本设计零改动受益**。

### ⑤ 其它

| 风险 | 缓解 |
|---|---|
| `bgTint`（P1）复位遗漏 → 后续所有背景带黄 | `finish_event()` 内 `hide()` 之前**无条件**复位 `bg_rect.modulate = Color.WHITE`（不判断事件是否带 tint），确保幂等。若 engineering-lead 对此不放心 → **直接砍掉 P1**，P0 不受影响 |
| 一次性信号连接泄漏 | `CONNECT_ONE_SHOT` 由引擎自动断开。且 `_try_memory_echo` 只在 `pick` 命中时连接，`commit` 已先行写冷却 → 同一 loc 的同一帧内不可能连接两次 |
| 玩家读档到 day 569 之前反复 SL 刷回响 | `mem_echo_*` 随存档序列化，读档即回滚冷却 —— 与全游戏所有 SL 行为一致，**不特殊处理**（这是单机养成游戏的既定契约） |
| 记忆角色已毕业/离场？ | 570 天内无角色离场机制，不适用 |
| CG 加载耗时（4 张 1280×720 JPEG） | 与既有长假 chapter、`build_stamp_vignette` 走同一 `GameUtils.load_bg_texture` 路径，性能特征已知，无新增风险 |
| `speaker: null` 三连屏是否单调 | 打字机效果 + 全屏 CG + 3 句递进结构（触景/闪回/独白）已构成完整节奏。若实机验证后仍觉平，P1 的 `bgTint` 是最低成本的增强项 |

---

## §8 决策区

**总体：按推荐全定，无阻塞性待决项。** 以下 2 项为可选，不拍板亦可按推荐直接实现。

### D-1（用户可选拍板）是否追加"夜阑独处"副钩子？

| 选项 | 说明 | 评价 |
|---|---|---|
| **A（推荐 · 已写入正文）** | 单主钩子 = 故地重游（地点进入）+ day 569 无视地点特例 | ✅ 零重入风险、零队列、3 文件 ~20 行。§2.6 已证明覆盖充分：lakeside 独占 4 条主章且访问频次最高 |
| B | 追加 `advance_time()` evening 分支副钩子（对齐 `check_night_chat` 位置），用于兜底 cinema / community 等难重访地点 | ⚠️ 需引入：`mem_echo_pending` 队列键 + `MainGame` 侧 2-3 处消费轮询 + 播放前 UI 空闲守卫（`dialogue_ui.visible == false` 等）+ 重入保护。代码量约 ×2.5，且**无 Godot runtime 可验证竞态**。收益是让 2 条 cinema 记忆更容易被听见 |
| C | 只做 evening 钩子，砍掉地点钩子 | ❌ 丢掉"编码特异性"这条设计支柱，回响退化为随机计时器。**不建议** |

> 若用户选 B，设计侧需追加：pending 键规范、消费点清单、UI 空闲守卫定义、"排队超过 N 天自动作废"规则。设计侧约 1 小时可补，工程侧 +25~35 行。**建议先按 A 上线，实机体感后再决定是否补 B。**

### D-2（用户可选拍板）冷战状态（`cold`）是否也允许回响？

| 选项 | 说明 | 评价 |
|---|---|---|
| **A（推荐 · 已写入正文）** | G9 排除 `cold` | ✅ 对齐 `check_night_chat` L165 既有惯例；避免"回忆与现状落差"在玩家正焦虑修复关系时造成情绪错位（支柱漂移） |
| B | 允许 `cold` 触发，但用一套专属的 `cold_line` 替换第 3 句独白（10 条各写 1 句） | 叙事上是本特性最有力的一刀（回忆与现状的落差正是青春叙事的核心张力）。成本：+10 句文案 + 1 个 `if` 分支。**风险**：处理不好会像在嘲讽玩家 |

> 若用户选 B，我会为 10 条各补一句 `cold_line`（基调：不指责、不甜、只陈述"那时候不是这样的"），工程侧仅在 `build_memory_echo_vignette()` 增加一个三元判断。**设计侧 30 分钟可补。**

---

## §9 交付摘要

| 项 | 内容 |
|---|---|
| 新建文件 | **0** |
| 修改文件 | **3**（`CollectionManager.gd` 核心 / `MainGame.gd` 集成 14 行 / `DialogueUI.gd` **1 行** 引擎补齐；+1 处可选 P1） |
| 新增 Autoload | **0** |
| 新增美术资产 | **0**（4 张 holiday CG 全部复用） |
| 新增记忆资产 | **0**（10 条 `holiday_memory_*` 全部复用） |
| 新增文案 | 10 × (3 句 + 1 终章句) = **40 句**，全部见 §1.3，可直接照抄 |
| 新增 flag | 最多 22 个（`mem_echo_<sid>_last` ×10 + `_count` ×10 + `mem_echo_last_day` + `mem_echo_total`），全部 int，零迁移 |
| 存档迁移 | **不需要** |
| NG+ 处理 | **不需要**（随 `flags = {}` 自动清零） |
| 单周目回响次数 | **≤ 11 次**（数学证明见 §2.6），保底 ≥ 1 次（day 569 特例） |
| 阻塞性待决 | **无** |

**下游移交**：
- **engineering-lead（程基岩）**：§4 接线清单（3 文件） + §5 数据格式 + §1.3 文案（照抄）。实现顺序建议 A → C → D，P1(B) 最后且可选。
- **quality-lead（严守真）**：§7-③ T-1 ~ T-16 静态断言清单，建议落 `tests/memory_echo_smoke/`。另请复核 §7-④ 的上游可达性疑点（community + `after`）。
- **art-director（林绘澄）**：**无需求**。
