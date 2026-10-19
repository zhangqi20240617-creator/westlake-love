# 社团 / 兴趣小组系统 · 游戏设计文档（GDD）

> 游戏：《西湖边的青春》（Godot 4.5 横屏手游，1280×720，GDScript）
> 子系统：社团 / 兴趣小组系统（Club / Interest Group System）
> 作者：design-strategist 文策渊（Vince Coyer）
> 阶段：模式创新扩展期（已落地：拟真手机 UI、西湖十景集章、记忆回响、风物志、好感度关系状态机、生活支柱 P0+P1+P2、长假 set-piece）
> 约束：只出设计，不写代码，不修改任何源文件。零新增 Autoload。不得削弱或绕过核心支柱「时间即代价」。

---

## §-1 读盘结论（源码实证）

> 本章节每一项结论均标注「文件:行号」出处。所有事实来自本次动笔前的真实源码读取（非推测）。

### 1.1 事实表（E1–E16）

| 编号 | 事实 | 出处 | 对社团系统的影响 |
|---|---|---|---|
| E1 | 时段由 `GameManager.slot_index` 驱动，取值 `{0,1,2,3}`，映射为 `["morning","noon","after","evening"]`（上午/中午/放学后/晚上） | `GameManager.gd` L20–21，L421–422；`DataManager.gd` L358–360 | 社团活动必须锚定其中一个 slot；唯一可行的「真实竞争」位点是 `after`（放学后） |
| E2 | `advance_time()` 每调用一次 `slot_index+=1`；`>=4` 跨日并重算 `day_of_week`，触发每日结算钩子链 | `GameManager.gd` L449–498 | 社团活动走默认 `advance_time()` 即可自然消耗一个时段 |
| E3 | 每日结算钩子链（跨日时顺序）：`_update_current_holiday → _refresh_weather_by_season → _refresh_char_moods → _check_daily_decay → _check_special_date → _check_weekly_allowance → _check_parttime_income → _check_char_initiative` | `GameManager.gd` L461–470 | 社团「每周重置」可挂入既有的 `_check_weekly_allowance`（周一触发），零新 Autoload |
| E4 | 每周一（`day_of_week==1`）发放零花钱：`money += 100 + int(intellect/5)` | `DailyCycleManager.gd` L93–98 | 社团每周重置复用此周一钩子，无额外调度成本 |
| E5 | 兼职周薪：`flag_has_parttime_job` + 周末 → `+80 money, +2 stress` | `DailyCycleManager.gd` L101–106 | 社团收入增长须低于此值，防经济失衡 |
| E6 | 放学后（`sid=="after"`）且非周末、作业未布置时自动布置作业（`hw_status=1`） | `GameManager.gd` L473–477 | 社团占 `after` 时段与作业布置同序，逻辑自洽、无冲突 |
| E7 | 「时间即代价」机会成本提示：初三（`day>=PRESSURE_START_DAY`）非学习时段流逝、每天节流一次 | `GameManager.gd` L490–493 | 社团占 `after` 会触发该提示，强化而非削弱支柱 |
| E8 | 事件门控引擎 `get_available_event` 支持字段：`location`/`slotId`/`triggerDay`/`repeatable`/`charId`+`unlockDay`+`minAff`/`requireFlags`/`excludeFlags`/`requireItem`(+Amt)/`requireMoney`/`minAddict`/`minStress`/`conditionType`/`requireWeather`/`requireSeason`/`requireHoliday`/`requireRelState`/`excludeRelState`/`requireNGCount`/`requireNotEnding`，按 `priority` 取最高 | `DataManager.gd` L175–329 | 社团每周活动可纯靠门控表达；注意**无** `day_of_week` 字段 |
| E9 | 长假期间抑制校内地点日常事件；`SCHOOL_LOCATIONS = ["classroom","library","playground","music_room","art_room"]` | `DataManager.gd` L288–293 | 社团活动若挂在以上地点，长假自动停办，与长假 set-piece 零冲突 |
| E10 | 场景级效果字段含 `setFlag`/`setFlags`/`addItem`/`removeItem`/`grantFengwu`/`statDelta`/`affDelta`；`setFlag` **仅置真**，无清 flag 能力 | `DialogueUI.gd` L160–239（`play_current_scene`），L660–675（`_apply_scene_level_effects`） | 社团「每周已参加」标记可置真；但**清除**需代码（见 §3.1） |
| E11 | `finish_event()`：默认 `GameManager.advance_time()`；仅当 `noTimeCost:true` 不消耗时段；`skipToNextDay` 跳到次日 | `DialogueUI.gd` L554–594（noTimeCost L591，skipToNextDay L577） | 社团活动 JSON **不带** `noTimeCost` → 确凿消耗时段（满足 S-4） |
| E12 | 七个属性维度：`intellect/strength/social/art/charm/stress/addict`；`money=100`；`add_stat` 中 `money` 不 clamp，`intellect` 正向增长置 `studied_this_slot=true` | `GameManager.gd` L8–16（stats），L18（money），L639–666（add_stat） | 社团属性成长落 `stats`；成长量须低于学习收益，避免主导策略 |
| E13 | 现有 Autoload 共 **15 个**（GameManager/InitiativeManager/ExamManager/WeatherManager/CollectionManager/LocationManager/DailyCycleManager/NGPlusManager/RelationshipManager/DataManager/SaveSystem/NetworkManager/CookingManager/SeasonManager/WardrobeManager） | `project.godot` L20–34 | 本系统**零新增** Autoload（成功标准 S-1） |
| E14 | 「更多菜单」实际为 **10 个**按钮：角色状态/我的衣橱/游戏存档/青春赛季/全服学霸/珍贵画廊/集章簿/风物志/往昔结局/世界聊天 | `MainGame.gd` L433–444 | 社团入口需处理「10→11」按钮约束（见 §3.3，成功标准 S-6） |
| E15 | `events_life.json` 现有 **66** 个事件，位于 `EVENT_FILES` 第 10 位（末位）；新增事件免注册 | `events_life.json`（grep `"id"` 计数=66）；`DataManager.gd` L10–21 | 全部社团事件追加进 `events_life.json`，零注册、零迁移（S-2） |
| E16 | 性别对称：`_get_target_char_ids()` 男主攻略 5 女角、女主攻略 5 男角；`club_` 前缀工程内**零占用** | `DataManager.gd` L364–371；Grep `club_` 全工程无匹配 | 社团事件 `charId:null` 即性别对称；`club_` 命名空间可安全独占 |

### 1.2 两个关键设计问题的明确回答

**(a) 时段 / slot 模型如何运作？社团每周活动挂哪个钩子、以什么频率触发、为何不冲突？**

- **模型**：每天 4 个 slot（`morning/noon/after/evening`），由 `slot_index` 推进（E1/E2）。每个 slot 玩家分配一项活动，活动结束默认 `advance_time()` 进入下一 slot（E2/E11）。
- **挂钩点**：社团每周活动**不挂新 Autoload、不挂新调度器**。它表现为 `events_life.json` 中一条 `repeatable:true` 事件，由既有 `DataManager.get_available_event` 门控返回（E8）。门控条件 = `slotId:"after"` + 社团地点 + `requireFlags:["flag_club_joined","flag_club_<type>"]` + `excludeFlags:["flag_club_week_done"]`（实现「每周一次」）。
- **频率与重置**：引擎无 `day_of_week` 门控（E8），故「每周一次」用**周一重置标记**实现——在既有的 `_check_weekly_allowance`（周一触发，E4）中追加一行 `GameManager.flags.erase("flag_club_week_done")`。这是本系统**唯一**建议的源码改动，且为零新 Autoload、零新系统、对现有 66+ 事件零回归（未涉及命名空间外 flag）。
- **为何不冲突**：社团活动锚定 `after` 时段 + 校内地点（E9 长假自动抑制），与学习/约会/探索在放学后同序竞争，不另起炉灶、不抢占其他钩子链。

**(b) 社团消耗时段如何与学习 / 约会 / 探索真实竞争？**

- 社团活动 JSON **不带 `noTimeCost`**（区别于记忆回响，E11），走 `finish_event()` 默认 `advance_time()`，确凿消耗一个 `after` 时段（S-4 可验证：检查社团事件 JSON 无 `noTimeCost` 键）。
- 玩家每天仅 4 个 slot；`after`（放学后）同时是：回家学习（`home_study`）、自习（`class_study`）、地点探索（`HotspotExploreUI`）、部分约会事件、以及现在的社团活动共同争夺的时段。花在社团就不能花在学习/约会/探索——**直接深化「时间即代价」**而非削弱。
- 初三期间占用 `after` 会触发机会成本提示（E7），让玩家在「社团成长 vs 备考」间做真实取舍。

---

## §0 概览与目标

### 0.1 特性定位

社团系统是「初中三年生活」第二设计支柱下的**身份与社交锚点**系统：初一入学后可加入一个社团（文学社 / 天文社 / 广播站 / 篮球队 / 美术社）；社团提供每周一次的放学后活动，消耗一个时段，换取属性成长、社交/好感机会与专属事件链。它不是「额外奖励系统」，而是把既有的「时间预算战争」再添一个真实战场。

### 0.2 设计支柱（2 条不漂移）

- **支柱 A · 时间即代价（承接全局，不漂移）**：社团每周活动必须真实占用 `after` 时段，不可绕过、不可 `noTimeCost`、不可无损回退。
- **支柱 B · 选择定义青春（本系统定位）**：加入哪个社团、投入多少，塑造不同的成长轨迹与社交圈；强调**承诺而非试错**——一旦加入即长线绑定，转社受限。

> 红线：任何让社团「零时段成本」「属性碾压学习」「可无限刷」的设计均视为支柱漂移，立即否决（见 §4）。

### 0.3 范围分层表（MVP / 目标 / 愿景）

| 层级 | 条目 | 内容 | 工作量 |
|---|---|---|---|
| **MVP** | 5 个社团入社事件（单 hub 选择） | `club_join_hub` 一条事件含 5 选项，设 `flag_club_joined` + `flag_club_<type>`；`triggerDay≈30`（适应期后），`charId:null` 性别对称 | M |
| | 5 个每周社团活动事件 | `club_weekly_<type>`：`repeatable:true`，`slotId:"after"`，校内地点，`excludeFlags:["flag_club_week_done"]`，场景 `statDelta` 成长，无 `noTimeCost` | M |
| | 状态落 flags + stats | `flag_club_joined` / `flag_club_<type>` / `flag_club_week_done`；成长落 `stats` | L（设计） |
| | 周一重置标记（1 行代码建议） | 在 `_check_weekly_allowance` 追加 `flags.erase("flag_club_week_done")` | M（实现） |
| | 更多菜单入口 | 「🎏 社团」第 11 按钮 或 折叠进「角色状态」（待拍板，见 OQ-2） | M |
| **目标** | 5 条社团专属事件链 | 每社团 3–4 步顺序链（如文学社社刊、篮球队联赛、广播站晨间播报、天文社流星观测、美术社画展），`flag_club_story_<type>_<step>` 门控 | L |
| | 社团成就 / 毕业纪念 | `flag_club_achievement_<x>` + 画廊条目（`GALLERY_ITEMS` 风格，player 条目） | M |
| | 社团社交圈 NPC | 社团同伴 `charId` 支线 + `affDelta`，深化社交维度 | L |
| | 跨社团联动事件 | 如文学社×广播站合作播报，复用 `requireFlags` 组合 | M |
| **愿景** | 社团对抗赛 / 赛季 | 复用 `SeasonManager._run_conditional_checks`（E2 末尾已调用）做赛季积分 | L |
| | 双路线对称叙事 | 男女主角各自社团叙事对称（E16） | M |
| | NG+ 社团传承 | 社团成就白名单进 NG+ 携带，入社状态重置重选（OQ-3） | M |

> 工作量标注：M = 中，L = 大（仅设计文档工作量；实现由工程团队执行，本 GDD 不写代码）。

---

## Part I 概念对比

### 三方案对比表

| 维度 | 方案 α · 纯事件周活动（推荐） | 方案 β · 独立社团场景/UI | 方案 γ · 社团=属性挂机养成 |
|---|---|---|---|
| 实现方式 | 全靠 `events_life.json` + 现有门控 + 周一重置 1 行 | 新增社团主场景 + 专属 UI 面板 | 加入后每日自动涨属性，无需到现场 |
| 新增 Autoload | **0** | 可能 1+（社团管理器） | 0（但需新结算逻辑） |
| 时段消耗 | **真实消耗 `after` 时段**（S-4） | 真实消耗（但需新流程接入） | **不消耗时段** ❌ 违背支柱 A |
| 时间即代价 | **强化**（与学习/约会同抢 `after`） | 强化 | 削弱 ❌ |
| 主导策略风险 | 低（成长量受控） | 中 | 高（挂机碾压学习） |
| 回归面 | 仅 1 行周一重置，零影响现有事件 | 多（新 UI + 新状态机） | 中（每日结算链改动） |
| 内容容量 | MVP 5 入社 + 5 周活动事件 | 需 5 套场景美术/UI | 需大量平衡数值 |
| 与长假/集章/风物志一致性 | 高（复用同一事件引擎） | 中（需额外接入） | 低 |

### 推荐方案与理由

**推荐方案 α（纯事件周活动）**。理由：
1. **零新 Autoload、零新系统**（S-1），仅 1 行周一重置代码，对现有 66+ 事件零回归（S-3）。
2. **确凿消耗 `after` 时段**（S-4），把社团变成「时间预算战争」的真实战场，强化而非削弱「时间即代价」（支柱 A）。
3. **完全复用既有门控与场景效果引擎**（E8/E10），开发成本最低、与已放行特性（记忆回响/风物志/生活支柱）同构、可审计。
4. 方案 γ 因「不消耗时段」直接否决（支柱漂移）；方案 β 过度工程，违背「零新 Autoload」与扩展期交付节奏。

---

## §1 核心循环

### 1.1 微观：单次社团活动（一个 `after` 时段）

```
[玩家处于 after 时段，身处社团地点]
        │
        ▼
DataManager.get_available_event → 命中 club_weekly_<type>
  (requireFlags: joined+<type>; excludeFlags: week_done)
        │
        ▼
DialogueUI 播放社团场景（statDelta 成长 / 可选 affDelta 给同伴）
        │
        ▼
场景 setFlag: flag_club_week_done = true   ← 本周已参加
        │
        ▼
finish_event() 默认分支 → GameManager.advance_time()   ← 消耗 after 时段（无 noTimeCost）
        │
        ▼
时段推进；若初三则触发机会成本提示（E7）
```

### 1.2 宏观：570 天跨社团成长循环

```
Day≈30  社团招新 hub → 选择并加入 1 个社团（flag_club_joined + flag_club_<type>）
   │
   ├─ 每周一：_check_weekly_allowance 清除 flag_club_week_done（可再参加）
   │
   ├─ 每周 after：参加 club_weekly_<type> → stats 成长 + 社交机会
   │       │
   │       └─ 触发后 flag_club_week_done=true，本周锁定
   │
   ├─ 累计参加 → 解锁社团专属事件链（flag_club_story_<type>_<step>）
   │
   ├─ 达成条件 → 社团成就 / 毕业纪念（flag_club_achievement_<x> + 画廊）
   │
   └─ Day≈570 毕业：社团身份写入「往昔结局」叙事与画廊条目
```

> 宏观循环与「时间即代价」耦合：玩家每周都要在「社团 vs 学习 vs 约会 vs 探索」之间用 `after` 时段做取舍，三年累计形成不可无损回退的身份轨迹（支柱 B）。

---

## §2 MDA 分析

### Mechanics（机制，玩家可操作的具体规则）
- 入社：单 hub 事件 5 选项，一次承诺（MVP 不支持转社，见 §3.1 / OQ-1）。
- 周活动：`repeatable` 事件，`after` 时段 + 校内地点门控，每周一次（`excludeFlags` + 周一重置）。
- 成长：场景 `statDelta` 按社团类型给 1–2 点主属性 + 1 点次属性（见附录 A），远低于学习收益。
- 社交：专属链含 `affDelta` 给社团同伴；可偶遇攻略角色（复用 `charId`/`minAff` 门控）。
- 成就：里程碑 `flag_club_achievement_<x>` + 画廊条目。

### Dynamics（动态，机制涌现的行为）
- **时间预算迁移**：加入社团后，玩家 `after` 时段被周期性占用，倒逼重新分配学习/约会/探索节奏。
- **承诺效应**：一次入社、长线绑定，玩家在后续选择中围绕社团身份做一致决策（支柱 B）。
- **机会成本可视化**：初三占用 `after` 触发提示（E7），把「社团 vs 备考」矛盾显性化。
- **防主导策略**：成长量受控 + 每周一次上限，社团无法替代学习成为最优解。

### Aesthetics（美学，玩家体验的情感基调）
- **归属感**：拥有一个「属于自己」的社团身份与同伴社交圈。
- **青春的重量**：每周不得不为社团让出时间的取舍感，呼应「时间即代价」。
- **成长的印记**：三年社团轨迹在毕业叙事与画廊中沉淀为可回看的青春纪念。

### 如何强化「时间即代价」
社团是**新增的真实时段竞争者**（不是奖励挂件）。它占据既有的、已高度拥挤的 `after` 时段，与学习/约会/探索正面冲突；且不可 `noTimeCost`、不可挂机、不可无损转社——把全局支柱从「抽象提示」变成「每周一次的具象取舍」。

---

## §3 跨 GDD 一致性

### 3.1 零新 Autoload
- 本系统不新增任何 Autoload（S-1）。所有状态落 `GameManager.flags` / `GameManager.stats`（E12/E13）。
- **唯一源码改动建议**：在 `DailyCycleManager._check_weekly_allowance`（`DailyCycleManager.gd` L93–98 之后）追加 `GameManager.flags.erase("flag_club_week_done")`。该改动：
  - 不新增 Autoload、不新增系统、不新增文件；
  - 仅清除 `club_` 命名空间内一个标记，对现有 66+ 事件零影响（S-3）；
  - 复用既有周一钩子（E4/E3），无新调度。
- 转社/退出功能（目标层）如需清除旧 `flag_club_<type>`，同样建议用一处命名空间清理辅助（不新增 Autoload）。

### 3.2 状态落 flags + stats
- 全部社团状态为 flag 态，命名空间 `club_`（已确认零占用，E16）：
  - `flag_club_joined`（bool）、`flag_club_<type>`（bool，5 选 1）、`flag_club_week_done`（每周重置）、`flag_club_story_<type>_<step>`、`flag_club_achievement_<x>`。
- 属性成长落 `GameManager.stats`（E12），不新建属性维度，不改动 `add_stat`。
- 与风物志（全 flag 态）、生活支柱 P2（全 flag 态、不碰 RelationshipManager）同构，审计一致。

### 3.3 更多菜单 10 按钮约束（S-6）
- 现状：更多菜单 10 个按钮（`MainGame.gd` L433–444，E14）。
- 方案：新增第 11 个按钮 `🎏 社团`（在 `items` 数组追加一条 dict，1 行代码），打开社团状态/成就面板。
- 布局安全：按钮容器为 `HFlowContainer`（`MainGame.gd` L427）自动换行，11 个按钮仍 2 行容纳，不破坏现有 10 按钮（S-6）。
- **替代方案**：若主理人要求零菜单改动，则把社团状态折叠进现有「📊 角色状态」面板（`_show_stats_popup`），不新增按钮。二者择一，待拍板（OQ-2）。

### 3.4 三个已放行特性零回归（S-3）
| 已放行特性 | 社团系统的零回归保证 |
|---|---|
| 记忆回响（noTimeCost） | 社团活动**不带** `noTimeCost`（E11），时段消耗语义与记忆回响明确区分，不污染其逻辑 |
| 风物志（全 flag 态） | 社团复用同一 flag 命名空间约定，不触碰 `CollectionManager`、不新增 Autoload |
| 长假 set-piece | 社团活动地点在 `SCHOOL_LOCATIONS` 内（E9），长假自动抑制，与长假演出零冲突 |
| 生活支柱 P2 | 社团属「课余兴趣」维度补位（life_coverage_audit 维度#13 原缺失），前缀 `club_` 与 `int_/eco_/pet_` 零冲突 |

### 3.5 NG+ 对齐
- 现状：`GameManager` NG+ 携带白名单（`GameManager.gd` L337–522，E12 区域）。
- 建议：
  - `flag_club_joined` / `flag_club_<type>` / `flag_club_week_done` **不携带、NG+ 重置**，让玩家重选社团（强化「青春即选择」 replay 价值）。
  - `flag_club_achievement_<x>`（画廊/成就）**列入白名单携带**，作为跨周目荣誉印记。
- 需在 NG+ 白名单配置中显式登记上述携带项（OQ-3 待拍板是否携带成就）。

---

## §4 设计红线（逐条风险 + 廉价缓解）

| 编号 | 风险 | 廉价缓解 |
|---|---|---|
| R1 | 社团成长量过高 → 碾压学习成为主导策略 | 周活动主属性 +1~2、次属性 +1，明确低于学习收益；`repeatable` 每周一次硬上限（E8） |
| R2 | 误加 `noTimeCost` → 社团零时段成本，削弱支柱 A | GDD 强制：社团活动 JSON 无 `noTimeCost` 键；S-4 验收即查此键（E11） |
| R3 | 新增 Autoload 或新系统 → 破坏 S-1 | 全 flag 态 + 复用既有引擎；唯一改动为 1 行周一重置（§3.1） |
| R4 | 转社/退出导致旧 `flag_club_<type>` 残留 → 双社团 bug | MVP 禁止转社（承诺制）；目标层转社经命名空间清理辅助，不靠事件清 flag（E10 限制） |
| R5 | 长假期间社团仍触发 → 与长假 set-piece 冲突 | 社团地点落在 `SCHOOL_LOCATIONS`（E9），长假自动抑制 |
| R6 | 经济失衡（社团给钱超兼职） | 社团**不给 money**，仅给 `stats`；收益低于兼职周薪 +80（E5） |
| R7 | 更多菜单按钮溢出/布局破坏 | `HFlowContainer` 自动换行；11 按钮仍 2 行（§3.3）；或折叠进角色状态（OQ-2） |
| R8 | 认知过载（玩家同时追太多周常） | 社团仅 1 个、每周 1 次；不与学习/约会每日频率叠加造成疲劳 |
| R9 | 存档迁移负担（S-2） | 全部状态为 flag 态，追加进 `events_life.json` 免注册、零迁移（E15） |
| R10 | 性别不对称 → 男/女主角社团叙事割裂 | 入社 hub 与周活动 `charId:null`；专属链 NPC 用对称设计（E16） |

---

## §5 成功标准

| 编号 | 标准 | 验证方式 |
|---|---|---|
| **S-1** | 零新增 Autoload | 核对 `project.godot` [autoload] 段仍为 15 个（E13）；本系统无新 `*` 注册 |
| **S-2** | 零存档迁移 | 全部社团状态为 `GameManager.flags`；事件追加 `events_life.json` 末位免注册（E15） |
| **S-3** | 已放行特性零回归 | 记忆回响/风物志/长假/生活支柱 P2 行为不变（§3.4） |
| **S-4** | 社团确消耗时段 | 社团活动 JSON **无 `noTimeCost`** 键，走 `finish_event` 默认 `advance_time()`（E11） |
| **S-5** | 双路线零分流 | 男/女主角社团事件 `charId:null` 对称，专属链 NPC 对称设计（E16） |
| **S-6** | 更多菜单按钮数约束 | 新增「🎏 社团」后仍为 `HFlowContainer` 2 行容纳，或折叠进角色状态，不破坏现有 10 按钮（§3.3） |

---

## 附录 A · 社团类型与属性映射

| 社团 | 主属性 (+1~2) | 次属性 (+1) | 周活动地点 | 专属链主题 |
|---|---|---|---|---|
| 文学社 | intellect | art | library | 校刊投稿 → 发表 → 座谈 |
| 天文社 | intellect | social | playground（天台观测） | 流星雨观测 → 星图展 |
| 广播站 | charm | social | music_room | 晨间播报 → 点歌台 → 校园之声 |
| 篮球队 | strength | social | playground | 年级联赛 → 校队选拔 |
| 美术社 | art | charm | art_room | 写生 → 画展 → 毕业壁画 |

> 成长量上限：单次周活动 `statDelta` 主属性 ≤2、次属性 ≤1，且 `stress` 不降（可微增以体现投入）。所有数值在实现期由数值策划按学习收益基线再标定，确保不形成主导策略（R1）。

## 附录 B · 事件 JSON 范本（落 `events_life.json`）

**B.1 入社 hub（单事件 5 选项，MVP）**
```json
{
  "id": "club_join_hub",
  "location": "",
  "slotId": "after",
  "triggerDay": 30,
  "repeatable": false,
  "charId": null,
  "excludeFlags": ["flag_club_joined"],
  "priority": 200,
  "scenes": [
    { "speaker": "社团招新", "text": "初一适应了，要不要加入一个社团？一旦加入就要认真参与哦。" },
    { "choices": [
        { "text": "文学社", "setFlag": "flag_club_joined", "setFlags": ["flag_club_literature"], "statDelta": {"intellect": 1} },
        { "text": "天文社", "setFlag": "flag_club_joined", "setFlags": ["flag_club_astronomy"], "statDelta": {"intellect": 1} },
        { "text": "广播站", "setFlag": "flag_club_joined", "setFlags": ["flag_club_broadcast"], "statDelta": {"charm": 1} },
        { "text": "篮球队", "setFlag": "flag_club_joined", "setFlags": ["flag_club_basketball"], "statDelta": {"strength": 1} },
        { "text": "美术社", "setFlag": "flag_club_joined", "setFlags": ["flag_club_art"], "statDelta": {"art": 1} }
    ]}
  ]
}
```

**B.2 每周社团活动（以文学社为例；其余 4 个同构替换地点/属性/flag）**
```json
{
  "id": "club_weekly_literature",
  "location": "library",
  "slotId": "after",
  "repeatable": true,
  "charId": null,
  "requireFlags": ["flag_club_joined", "flag_club_literature"],
  "excludeFlags": ["flag_club_week_done"],
  "priority": 60,
  "scenes": [
    { "speaker": "文学社", "text": "本周社课：共读与随笔。你沉浸在文字里，一下午过去了。" },
    { "statDelta": {"intellect": 2, "art": 1}, "setFlag": "flag_club_week_done", "next": 99 }
  ]
}
```
> 注意：**无 `noTimeCost`**，故 `finish_event()` 默认 `advance_time()` 消耗 `after` 时段（S-4）。

**B.3 周一重置（唯一建议源码改动，非 JSON）**
```gdscript
# DailyCycleManager.gd · _check_weekly_allowance() 内，L97 之后追加：
GameManager.flags.erase("flag_club_week_done")
```

## 附录 C · 开放问题（待主理人 / 用户拍板）

- **OQ-1** MVP 是否接受「一次入社、不可转社」（承诺制，强化支柱 B）？还是目标层必须提供一次转社机会（需命名空间清理辅助）？
- **OQ-2** 社团入口用「🎏 社团」第 11 按钮，还是折叠进「📊 角色状态」面板（零菜单改动）？
- **OQ-3** NG+ 是否携带 `flag_club_achievement_<x>` 成就？入社状态是否重置重选？
- **OQ-4** 社团周活动是否固定在「周五 after」（需额外 day_of_week 门控，当前引擎不支持，或改用更严格的周一~周日窗口），还是保持「每周任意 after 一次」（本 GDD 推荐，更灵活）？
- **OQ-5** 社团专属事件链（目标层）是否引入独立社团同伴 NPC（需扩 `characters.json`），还是复用现有攻略角色客串？

---

## 回传主理人（游承峰）

**推荐方案一句话**：采用方案 α「纯事件周活动」——社团全部用 `events_life.json` + 既有门控引擎实现，仅在 `_check_weekly_allowance` 追加 1 行周一重置标记，零新增 Autoload、零新系统，把社团变成 `after` 时段的真实竞争者。

**最大风险一句话**：唯一的工程风险是「周一重置那 1 行代码」若被遗漏会导致社团每周只能参加一次后永久锁死，但只要 S-4 验收时同时校验「无 `noTimeCost` 键 + 周一擦除标记存在」即可 100% 兜底，无架构性风险。

**MVP 落地建议一句话**：先交付「1 个入社 hub + 5 个每周活动事件 + 周一 1 行重置 + 更多菜单第 11 按钮」，即可在零新 Autoload 下跑通完整「时间即代价」闭环，专属事件链与成就留待目标层。

**需主理人 / 用户拍板的关键开放问题**：① MVP 是否接受「一次入社不可转社」（承诺制）；② 社团入口用新增第 11 按钮还是折叠进「角色状态」；③ NG+ 是否携带社团成就、入社是否重置重选；④ 周活动固定周五还是「每周任意 after 一次」（本 GDD 推荐后者）；⑤ 专属链是否引入独立社团同伴 NPC。以上任意一项定调后我可立即补出对应事件 JSON 明细与数值基线。

— 文策渊（Vince Coyer）· design-strategist
