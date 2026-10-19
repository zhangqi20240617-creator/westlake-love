# 《西湖边青春》· 生活支柱补强 P2 内容 · 设计草案 GDD

> **文档性质**：设计草案（DESIGN-ONLY）。本文件**不写任何事件 JSON、不修改任何 `.gd` 源码**，仅供主理人（游承峰）汇编后交用户确认；确认后才进入工程落地。
> **范围**：审计 `life_coverage_audit.md` 中 P2 两项内容支柱 —— ① 兴趣扩展（追星 / 宠物 / 手作）② 经济深度（压岁钱 / 兼职 / 攒钱）。P2 为审计判定的最低优先级"锦上添花"，本草案刻意**低密度**，事件总数 16（兴趣 9 + 经济 7），落于建议区间 14–20。
> **前缀约定**：兴趣 `int_`（追星 `int_idol_*` / 宠物 `int_pet_*` / 手作 `int_craft_*`）；经济 `eco_`（压岁钱 `eco_lucky_*` / 兼职 `eco_parttime_*` / 攒钱 `eco_save_*` / 消费抉择 `eco_shop_*`）。
> **负责人**：文策渊（design-strategist）　**调度者**：游承峰
> **设计红线**（继承审计 §六 + P0/P1）：不碰 `RelationshipManager`（恋爱状态机）；不新建 Autoload；`statDelta` 仅用合法键、严禁 `study` 死键；无经济失衡 / 主导策略；性别对称。

---

## 0. 读盘结论摘要（真实证据，非臆造）

| # | 结论 | 证据（文件 · 行号） |
|---|---|---|
| E1 | `events_life.json` 已注册且为 EVENT_FILES 末位（position 10，重复 id 时优先） | `DataManager.gd` L10-21 |
| E2 | 现 `events_life.json` 共 **44** 事件 = P0 `life_*` 24 + P1 `fest_*`4 / `mock_*`6 / `grad_*`4 / `bond_*`6（Grep 实证：前缀零冲突） | Grep `events_life.json` L3–1038 |
| E3 | `int_*` / `eco_*` / `pet_*` **前缀零占用**（全 `scripts/` JSON Grep 0 命中）→ 可安全使用 | Grep `"id":"(int_\|eco_\|pet_"` |
| E4 | 合法 `statDelta` 键 = `intellect/strength/social/art/charm/stress/addict/money`；`money` 在 `add_stat` 特判（正=收入、负=支出、无 clamp） | `GameManager.gd` L8-16, L604-611 |
| E5 | 每周零花钱 = `100 + int(intellect/5)`（≈100–120），周一发放 | `DailyCycleManager.gd` L92-97 |
| E6 | 赛季金钱奖励量级 50/100/150（Lv1/4/7）→ 压岁钱"一次性大额"应显著大于周零花但不过离谱 | `SeasonManager.gd` L90-101, L196-197 |
| E7 | `SPECIAL_DATES` **无"春节"**，最近似 = day90 寒假开始(break) / day30 元旦(festival) | `DailyCycleManager.gd` L12-34 |
| E8 | 节日叙事强制启动模式（P1 已落地）：`_on_special_date` 的 `fest_narrative_map`(L306-311) 按 banner 强制 `start_event` | `MainGame.gd` L291-315 |
| E9 | 小橘猫碰瓷梗存在于 `post_jingjing_cat`（WeChat 朋友圈，unlock_day 7） | `WeChatUI.gd` L52-69 |
| E10 | 既有"喂路边的野猫"是 `events_daily.json`/events.json 的**路线 choice 选项**（social+2,stress-15,next:99），非事件链 | `events_daily.json` L217 / `events.json` L4284 |
| E11 | `setFlag`（场景级/选项级）自动 `unlock_gallery(flag)` → GALLERY 收集项 = 1 行 `GALLERY_ITEMS` const | `DialogueUI.gd` L197-200, L467-469 |
| E12 | 选项级 `reqMoney`（L398）仅**扣费**不**门控**（不足时 `money` 变负，无 clamp）→ 不能用作"攒够才解锁"的硬门控 | `DialogueUI.gd` L397-413 |
| E13 | 衣橱 6 槽 = `top/bottom/outfit/head/accessory/shoes`，**无宠物栏**；加宠物栏需改 `WardrobeManager.gd`+`WardrobeUI.gd` | `WardrobeManager.gd` L12, L40-173 |
| E14 | `CollectionManager.add_item` 要求 item 在 `GameManager.ITEM_DB`（const，L254-261） | `CollectionManager.gd` L11-17 |
| E15 | `charId:null` 事件经 `get_available_event` 不做性别过滤 → 男女主通用（对称） | `DataManager.gd` L210-215 |
| E16 | 现有消费系统统一读 `GameManager.money`，不足提示"零花钱不足"（Shop/Wardrobe/Cooking） | `ShopUI.gd` L232 / `WardrobeManager.gd` L208 / `CookingManager.gd` L191 |

---

## 1. 命名空间核查（Grep 实证，先查后写）

| 检查项 | 命令 | 结果 |
|---|---|---|
| `int_*` / `eco_*` / `pet_*` 前缀是否被占用 | Grep `"id":\s*"(int_\|eco_\|pet_)` 于 `scripts/*.json` | **0 命中** —— 三前缀完全空闲 |
| `life_/fest_/mock_/grad_/bond_` 现有占用 | 同上 | 仅 `events_life.json` 内 44 条（P0 24 + P1 20），无冲突 |
| `exam_` 前缀 | （P1 已确认） | 与 `exam_result_*` 共享前缀；故本草案用 `eco_` 规避 |

**结论**：本草案 16 个事件 id 全部以 `int_`（兴趣）/ `eco_`（经济）前缀，不与现有 ~306 事件冲突。宠物线归入 `int_pet_*`（属兴趣支柱），`pet_*` 前缀虽零占用但**故意不用**，以保持"两前缀"整洁、便于校验去重。

---

## 2. 设计目标与支柱对齐

- **支柱一（既有）**：恋爱情感弧。
- **支柱二（已立，P0/P1）**：初中生活真实度（生活事件 → 属性/中考闭环）。
- **本阶段 P2（锦上添花）**：在支柱二之下补两块**低密度、纯装饰/回忆向**内容——兴趣扩展与经济深度。定位延续审计 §六定性：**"情感/回忆向消费"，不形成数值主导策略**。
- **反支柱漂移 / 反信息过载**：P2 事件 `priority` 设 **180–240**（低于 P0/P1 的 200–300、远低于恋爱 500–1000）；多数一次性或轻量 `repeatable`；靠 `triggerDay`/`requireFlags`/`requireHoliday` 自然节流。
- **零新建系统**：全部复用 `GameManager`（stats/money/flags）+ `DataManager` 门控 + `DialogueUI` 的 `setFlag`/`reqMoney`/`statDelta`；宠物收集挂 GALLERY（1 行 const），不碰 `RelationshipManager`、不新建 Autoload。

---

## 3. 支柱一 · 兴趣扩展（int_*，9 事件）

> 命名 `int_idol_*`(追星) / `int_pet_*`(宠物·小橘猫) / `int_craft_*`(手作)。**全部 `charId:null`**（性别天然对称）。
> 回写：social / stress / art / charm / addict（追星）；宠物线额外接 GALLERY（flag）；手作接 art（创作收益）。

### 3.1 追星（idol，3 事件）

| # | id | 标题 | 触发 | charId | statΔ | 门控 | eng |
|---|---|---|---|---|---|---|---|
| I1 | `int_idol_fanfeed` | 📱 刷爱豆超话/追番 | `triggerDay:60`, `repeatable:true`, `location:home`, `slotId:evening`, `priority:190` | null | social+2, stress-3, **addict+3** | — | -（联动现有网瘾衰减链 E12） |
| I2 | `int_idol_merch` | 🛍️ 买应援周边 | `triggerDay:120`, `repeatable:false`, `location:off_campus_shop`, `priority:200` | null | money-60, social+2, charm+1 | — | - |
| I3 | `int_idol_concert` | 🎤 省零花钱看演出 | `triggerDay:200`, `repeatable:false`, `requireHoliday:"any"`, `priority:210`, `excludeFlags:["seen_idol_show"]` | null | money-120, social+4, stress-6, `setFlag:seen_idol_show` | `setFlag` 自动 GALLERY（可选 E11） | - |

*论证（追星↔现有机制）*：应援消费 = `money` 负（呼应 Shop/Wardrobe/Cooking 经济）；情绪收益 = `social`/`stress` 正。是否联动 `addict`：建议**联动**（I1 `addict+3`，小量），把"追番/刷手机应援"隐喻进现有网瘾属性，打通 `DailyCycleManager` 网瘾衰减链（L119-129）——不新增机制，仅复用。控量 +3 避免与网瘾惩罚（>60 好感衰减）直接冲突。

### 3.2 宠物（小橘猫，4 事件）— 承接 `post_jingjing_cat` 碰瓷梗

| # | id | 标题 | 触发 | charId | statΔ | 门控 | eng |
|---|---|---|---|---|---|---|---|
| I4 | `int_pet_meet` | 🐱 再遇小区小橘猫 | `triggerDay:30`, `repeatable:false`, `location:community`, `priority:195` | null | 分支：投喂 social+2,stress-3,money-5 / 只看 stress-2 | — | - |
| I5 | `int_pet_adopt` | 🏠 决定收养小橘猫 | `requireFlags:["int_pet_meet"]`, `triggerDay:40`, `repeatable:false`, `location:community`, `priority:205` | null | 收养：`setFlag:pet_orange_cat`→GALLERY, social+3,stress-5 / 不养：stress-1 | `setFlag:pet_orange_cat` | **需 GALLERY_ITEMS +1 行（GameManager.gd L291-345）** |
| I6 | `int_pet_care` | 🍽️ 日常照料（repeatable） | `requireFlags:["pet_orange_cat"]`, `triggerDay:45`, `repeatable:true`, `location:home`, `slotId:evening`, `priority:185` | null | social+1, stress-2, money-3(猫粮) | — | - |
| I7 | `int_pet_moment` | 💞 和小橘猫的暖心时刻 | `requireFlags:["pet_orange_cat"]`, `triggerDay:60`, `repeatable:true`, `location:home`, `priority:185` | null | social+2, stress-4 | — | - |

*论证（宠物与"喂野猫"选项如何区分）*：
- 既有 `events_daily.json:217` / `events.json:4284` 的"喂路边的野猫"是**路线 choice 选项**（一次性善意，social+2/stress-15，next:99）——属"路过随手善举"。
- 本 P2 `int_pet_*` 是**收养事件链**（meet→adopt→care→moment），属"持续饲养关系 + GALLERY 收集"。二者主题相邻但机制不同：一个是 choice、一个是 event 链；一个无状态、一个有 `pet_orange_cat` flag 持续态。文案在 I4 显式呼应 `post_jingjing_cat` 碰瓷梗（"那只学会假摔的小橘猫又来了"），让收养线成为朋友圈梗的自然延伸，不重复。

*论证（宠物收集落点）*：推荐进 **GALLERY**（非 WardrobeManager 宠物栏）。
- GALLERY 方案：`int_pet_adopt` 设 `setFlag:pet_orange_cat` → `DialogueUI` 自动 `unlock_gallery`（E11）→ 只需在 `GameManager.gd` `GALLERY_ITEMS`（L291-345，仿 `char:"player"` 的 `grad_*` 条目）**追加 1 行** `{char:"player", pose:"pet_orange_cat", label:"小橘猫·到家", flag:"pet_orange_cat", bg:"res://assets/backgrounds/community.png"}`。**零新 Autoload、1 行 const**。
- 不推荐 WardrobeManager 宠物栏：`SLOTS` 目前 6 槽（E13），加宠物栏需改 `WardrobeManager.gd`+`WardrobeUI.gd` 两处，超出 P2 低密度范围，且与"换装"语义不符。

### 3.3 手作（craft，2 事件）

| # | id | 标题 | 触发 | charId | statΔ | 门控 | eng |
|---|---|---|---|---|---|---|---|
| I8 | `int_craft_make` | 🎨 做手作/文创/改造 | `triggerDay:80`, `repeatable:true`, `location:home`(或 `art_room`), `priority:190` | null | art+3, stress-4 | 可选 `add_item("handmade_gift",1)` | **可选** ITEM_DB +1 行（GameManager.gd L254-261） |
| I9 | `int_craft_gift` | 🎁 把手作送给朋友 | `triggerDay:120`, `repeatable:false`, `location:community`, `priority:200` | null | social+4, art+1, `setFlag:craft_gift_done` | `setFlag` | - |

*论证（手作产出落点）*：默认轻量纯 `flag`+属性版（I8 art+3/stress-4，I9 social+4/art+1+flag），**零引擎改动**。若用户希望手作可"作为礼物赠给角色"，则在 `GameManager.ITEM_DB`（L254-261）追加 `handmade_gift`（price 0），并在 `DataManager.GIFT_PREFERENCES` 加反馈，`int_craft_make` 用 `CollectionManager.add_item`（E14 需 ITEM_DB 存在）。属可选 eng 依赖，默认不启用。

---

## 4. 支柱二 · 经济深度（eco_*，7 事件）

> 命名 `eco_lucky_*`(压岁钱) / `eco_parttime_*`(兼职) / `eco_save_*`(攒钱) / `eco_shop_*`(消费抉择)。**全部 `charId:null`**。
> 回写：money（核心，正=收入/负=支出）+ social/stress（情绪）。**money 不进中考公式**（延续审计 §六"消费/回忆向"定性，无经济失衡风险）。

| # | id | 标题 | 触发 | charId | statΔ | 门控 | eng |
|---|---|---|---|---|---|---|---|
| E1 | `eco_lucky_money` | 🧧 春节压岁钱 | **方案A**：`SPECIAL_DATES` day95(festival/spring_festival) 强制叙事；**方案B(零引擎)**：`triggerDay:95`,`location:null`,`repeatable:false` | null | money+500, social+2, stress-3 | — | **方案A 需 SPECIAL_DATES+fest_narrative_map（DailyCycleManager/MainGame）** |
| E2 | `eco_parttime_apply` | 📋 报名兼职 | `triggerDay:150`, `repeatable:false`, `location:off_campus_shop`, `priority:200` | null | `setFlag:flag_has_parttime_job` | `setFlag` | - |
| E3 | `eco_parttime_firstshift` | 💼 第一次打工 | `requireFlags:["flag_has_parttime_job"]`, `triggerDay:155`, `repeatable:false`, `location:community`, `priority:200` | null | social+3, stress+2(时间成本) | — | 周薪由结算给（方案B） |
| E4 | `eco_save_set_goal` | 🎯 立下攒钱目标 | `triggerDay:100`, `repeatable:false`, `priority:195` | null | `setFlag:flag_save_goal` | `setFlag` | - |
| E5 | `eco_save_deposit` | 🐷 往存钱罐塞钱(repeatable) | `requireFlags:["flag_save_goal"]`, `excludeFlags:["flag_save_done"]`, `triggerDay:105`, `repeatable:true`, `location:home`, `priority:185` | null | money-15(积蓄), stress-2(自律) | `excludeFlags` | - |
| E6 | `eco_save_claim` | ✅ 攒够啦，兑现目标！ | `requireFlags:["flag_save_goal"]`, `excludeFlags:["flag_save_done"]`, `triggerDay:110`, `repeatable:false`, `priority:210` | null | money-<cost>(兑现), social+3, stress-5, `setFlag:flag_save_done` | `setFlag` | **可选** requireMoney 门控（DataManager） |
| E7 | `eco_shop_dilemma` | ⚖️ 消费抉择(买 vs 攒) | `triggerDay:180`, `repeatable:false`, `location:off_campus_shop`, `priority:195` | null | 分支：冲动买 money-?,stress+2 / 理智攒 stress-3 | — | - |

---

## 5. 各支柱与现有系统衔接 + Engineering 依赖清单

> 全部为**设计描述**，本草案不修改源码。下列行号来自真实读盘（§0）。

### 5.1 压岁钱（E1）— 挂哪天？是否加"春节" SPECIAL_DATES？

**文化/语义论证**：压岁钱最准确挂在**春节**（≈寒假中段），其次元旦。现 `SPECIAL_DATES` 无春节，最近似 day90 寒假开始(break)/day30 元旦(festival)（E7）。

**方案A（推荐，保证大额送达）**——复用 P1 已批准的节日强制叙事模式（E8）：
- `DailyCycleManager.gd` · `SPECIAL_DATES`(L12-34)：**追加 1 行** `95: {"label":"🧧 春节","effect":"festival","banner":"spring_festival"}`（day95 落在 winter 长假 [90,100] 内）。
- `MainGame.gd` · `_on_special_date` · `fest_narrative_map`(L306-311)：**追加 1 行** `"spring_festival": "eco_lucky_money"`。
- 注意：`festival_map`(L293-297) **不收录** `spring_festival` → 不解锁烹饪，仅触发叙事（同 `teacher_day` 模式），符合预期。
- 优点：春节当天 `_check_special_date` 强制 `start_event`，**保证 500 大额零花一定送达**（money 是核心体验，丢发可惜）。改动面仅 2 行。

**方案B（零引擎，备选）**：`eco_lucky_money` 作为普通 `triggerDay:95` / `location:null` / `repeatable:false` 事件，无 SPECIAL_DATES 改动。缺点：依赖玩家到访地点触发 `get_available_event`，**不保证当天触发**（可能延后到首个 eligible 访问），大额入账"错过春节感"。

**金额论证**：每周 allowance ≈ 100–120（E5）；赛季奖励 50/100/150（E6）。压岁钱取 **money+500**（≈5 周 allowance，明确"一次性大额"但不离谱；区间建议 500–600）。量级远大于日常消费（衣橱 rare 68–158、limited 188–368），但属"节日红包"叙事，不破坏周常经济节奏。

### 5.2 兼职（E2/E3）— 周期性收入两种方案

**方案B（推荐，真实 + 防经济失衡）**——在 `DailyCycleManager` 加周兼职结算：
- `DailyCycleManager.gd` · 新增 `_check_parttime_income()`（仿 `_check_weekly_allowance` L92-97）：若 `GameManager.flags.has("flag_has_parttime_job")` 且 `GameManager.day_of_week in [6,7]`（周末），则 `GameManager.money += 80`（兼职周薪，**量级 < allowance**，避免压倒零花节奏），并可 `GameManager.add_stat("stress", +2)`（时间成本）。
- 在 `GameManager.advance_time` 每日块（L438 `_check_weekly_allowance()` 之后）**追加调用** `_check_parttime_income()`（+1 行调用）。
- `eco_parttime_apply` 设 `flag_has_parttime_job`（纯数据）；`eco_parttime_firstshift` 为一次性叙事（social+3/stress+2），**钱由周结算给**，不重复发。
- 合计引擎改动 ≈ **+8~12 行**（DailyCycleManager 函数 + advance_time 调用）。不新建 Autoload。

**方案A（纯数据，不推荐）**——`eco_parttime_shift` 设为 `repeatable:true` + `money+80`：
- 致命缺陷：**无冷却机制**（引擎无按时间清 flag 的门控）。`repeatable` 事件每次 eligible 访问都触发 → 玩家每天到访即 +80 → **日更 spam 式经济失衡**，撞审计 §六红线。故不推荐。

**结论**：推荐方案B（周结算，周末限发，flag 门控），量级受控、语义真实。

### 5.3 攒钱（E4/E5/E6）— flag 驱动 + money 比较，不新建状态

**默认（零引擎，推荐）**：纯 `flag` + **玩家侧** money 比较。
- `eco_save_set_goal` 设 `flag_save_goal`（立目标，叙事含目标金额）。
- `eco_save_deposit`（`repeatable`，`excludeFlags:flag_save_done`）每次 `money-15`（把零花存进存钱罐），是"储蓄动作"；玩家重复直到攒够。
- `eco_save_claim`（`excludeFlags:flag_save_done`）提供 choice "用攒的钱买下目标" → `statDelta money-<cost>`（兑现花费）+ `setFlag:flag_save_done` + social+3/stress-5。**money 比较由玩家在 UI 看到 💰 后自行判断是否够**（引擎无 money 门控，E12）。

**可选增强（轻量引擎）**：给 `DataManager.get_available_event` 加 `requireMoney` 门控（仿 `requireItem` L245-250，+5~6 行）：
```
var req_money = int(ev.get("requireMoney", 0))
if req_money > 0 and GameManager.money < req_money: continue
```
使 `eco_save_claim` 仅在 `money >= 阈值` 时自动可触发（真·money 比较、自动解锁）。**非新 Autoload**，属可选。

**攒满后解锁什么**：默认 `flag_save_done` 作为成就 flag（可接 GALLERY 收集项，仿 grad_*）；目标多为"衣橱大件 / 宠物用品 / 文创 / 为某人买礼物"——这些本就是现有消费/收集系统，攒钱只决定"何时买得起"，**不新建解锁系统**。

### 5.4 宠物 GALLERY（I5）— 见 §3.2，1 行 const，setFlag 自动解锁

### 5.5 手作产出（I8）— 见 §3.3，默认纯 flag；可选 ITEM_DB

### 5.6 文件注册（免改）
P2 事件**追加进 `events_life.json`**（已在 `EVENT_FILES` position 10，最后加载，重复 id 优先；与 P0/P1 同源便于维护）→ **无需改 `DataManager.EVENT_FILES`**。备选新建 `events_p2.json` 需注册（不推荐，沿用 P1 已定策略 E1）。

### 5.7 Engineering 依赖清单（精确汇总，供落地）

| 序 | 文件 · 函数/常量 · 行号 | 改动性质 | 触发条件（决策） |
|---|---|---|---|
| 1 | `DailyCycleManager.gd` · `SPECIAL_DATES` · L12-34 | 追加 1 行（春节 day95） | 压岁钱选**方案A** |
| 2 | `MainGame.gd` · `_on_special_date` · `fest_narrative_map` L306-311 | 追加 1 行（`"spring_festival":"eco_lucky_money"`） | 方案A |
| 3 | `DailyCycleManager.gd` · 新增 `_check_parttime_income()`（仿 L92-97）+ `GameManager.advance_time` L438 追加调用 | +8~12 行 | 兼职选**方案B**（推荐） |
| 4 | `GameManager.gd` · `GALLERY_ITEMS` · L291-345 | 追加 1 行（小橘猫 `char:"player"`） | 宠物进 GALLERY（推荐） |
| 5 | `GameManager.gd` · `ITEM_DB` · L254-261 | 追加 1 行（`handmade_gift`，可选） | 手作做可赠物品（可选） |
| 6 | `DataManager.gd` · `get_available_event` · 仿 `requireItem` L245-250 | +5~6 行（可选 `requireMoney`） | 攒钱自动 money 门控（可选） |
| 7 | 文件注册 | **无**（追加 `events_life.json`） | 默认策略 |

---

## 6. 质量门草案（PASS / CONCERNS / FAIL）

> 口径继承 P0/P1 校验（design/life_pillar_p0_gdd.md §9、tests/life_smoke/validate_life.py）。落地阶段由 engineering 跑校验。

| 检查项 | PASS | CONCERNS | FAIL |
|---|---|---|---|
| ID 唯一性 | P2 全部 id 在 live `EVENT_FILES` 内零重复；`int_`/`eco_` 前缀 Grep 零冲突（§1） | 前缀不同但全 id 不同（仅警告） | 与现有 ~306 事件全 id 重复 |
| statDelta 合法 | 仅用 `intellect/strength/social/art/charm/stress/addict/money` | — | 出现 `study` 等死键或非上述字段 |
| charId 对称 | 全部 P2 事件 `charId:null`，男女主均可触发 | 个别含性别名词但 `charId:null` | 误写 `charId` 指向具体角色 |
| 不碰恋爱状态机 | 无 `affDelta`/`favors`/`relCold`/`requireRelState`/`excludeRelState` | — | 写入好感或触发冷战/挽回 |
| 不新建 Autoload | 仅复用 GameManager/DataManager/DialogueUI/CollectionManager/DailyCycleManager | 改 DailyCycleManager/WardrobeManager/GameManager const（非新单例） | 新增 Autoload / 单例 |
| 文件注册 | P2 事件已落入 `events_life.json` | 仅放入未注册文件 | 完全未注册 → 运行时不加载 |
| 门控合法性 | `requireFlags`/`excludeFlags` 引用的 flag 真实存在（如 `int_pet_meet`/`flag_save_goal`） | 引用 P0/P1 之外未定义 flag | 引用不存在的 flag 导致永不触发 |
| 经济/主导策略 | 压岁钱 500、兼职周薪 80(<allowance)、攒钱为转移非产出；无单一属性主导回路 | 兼职方案A 日更 spam（须用方案B） | 引入刷分主导策略或新经济失衡 |
| 时间轴密度 | P2 事件散布 day30–200，强制类仅 E1（春节单日）；任意 5 日窗口强制触发 ≤1 | 某窗口 2 次强制触发 | 同日/相邻日 ≥3 次强制触发（认知过载） |
| 宠物区分 | `int_pet_*` 为事件链 + flag 态；与 `events_daily`"喂野猫"choice 机制不同 | 文案主题相邻需文案显式区分 | 与"喂野猫"选项重复成双份 |

**验收门槛**：全部检查项 ≥ CONCERNS 且 **0 FAIL** 方可通过移交用户最终确认；出现任意 FAIL 须返工。

---

## 7. 风险与取舍

1. **信息过载（认知过载）**：P2 16 事件 + 现有 ~306，须避免喧宾夺主。取舍：P2 `priority` 180–240（低于 P0/P1 200–300、远低于恋爱 500–1000）；多数 `repeatable:false` 一次性，宠物照料/手作/追番为轻量 `repeatable`（一日一槽，自然节流）。门控靠 `triggerDay`/`requireFlags`/`requireHoliday` 错峰。
2. **性别对称**：16 事件 **全部 `charId:null`**，NPC/宠物/爱豆均为场景文本、无 charId 依赖 → 男女路线**天然对称**，无需双份脚本（相对恋爱事件按性别分两套的最大简化收益）。
3. **轻量"经济态"**：攒钱不新建任何字典/Autoload，用 `flag_save_goal`/`flag_save_done` 表达；兼职用 `flag_has_parttime_job` 表达"是否在职"。全部 flag 态，零新系统。
4. **不碰恋爱状态机**：P2 全事件 `social`+flag/money，零好感写入、零 `requireRelState`。对抗审计所指"支柱漂移"的关键护栏。
5. **money 与现有经济协调**：压岁钱 500 < 衣橱 limited(188–368)×多件累计，属节日叙事；兼职周薪 80 < allowance(100+) 且限周末+flag；攒钱是"零花→存钱罐"转移非新增产出。三种经济内容**不形成数值主导策略**（审计 §六已定性无失衡风险）。
6. **运行期地点可达性**：宠物 meet/adopt 在 `community`（unlock 1，可达）；craft 在 `home`/`art_room`（art_room unlock 3）；兼职在 `off_campus_shop`/`community`；压岁钱（方案A）强制叙事不受地点限制。E1 方案B 用 `location:null` 亦可全地点触发。
7. **与"喂野猫"选项区分**：见 §3.2 论证——一个是 route choice（一次性善意），一个是 event 链（持续饲养 + GALLERY）。文案在 I4 显式呼应 `post_jingjing_cat` 碰瓷梗，形成"梗→收养"叙事弧，不重复。

---

## 8. 事件总数建议

| 支柱 | 事件数 | 审计建议区间 | 达标 |
|---|---|---|---|
| 兴趣扩展 `int_*` | 9（追星3 / 宠物4 / 手作2） | 5–7（审计） | ✅（略高于审计，因宠物拆成事件链；仍在 P2 总区间） |
| 经济深度 `eco_*` | 7（压岁钱1 / 兼职2 / 攒钱3 / 消费抉择1） | 4–6（审计） | ✅ |
| **合计** | **16** | **14–20（用户建议）** | ✅ |

> 说明：审计对 P2 的兴趣/经济各给 5–7 / 4–6（合计 9–13）；本草案取 16，落在用户给定的 14–20 上限附近但仍是"低密度"（相对已存在的 ~306 事件）。若用户希望更克制，可砍 `int_pet_moment`(I7) 与 `eco_shop_dilemma`(E7) → 14 件，仍达标。

---

## 9. 待用户确认的关键决策点（交主理人汇编）

| # | 决策点 | 草案默认建议 | 影响 |
|---|---|---|---|
| **D1** | 压岁钱挂哪天 + 是否加"春节" SPECIAL_DATES？ | **方案A**：春节 day95 + SPECIAL_DATES + fest_narrative_map（保证大额送达，复用 P1 模式） | 改 DailyCycleManager/MainGame 各 1 行 vs 零引擎 triggerDay |
| **D2** | 兼职用 repeatable 事件(方案A) 还是 DailyCycleManager 周结算(方案B)？ | **方案B**（周末限发、flag 门控、防经济失衡） | 改 DailyCycleManager +8~12 行 vs 纯数据(但有日更 spam 风险) |
| **D3** | 宠物是否进 GALLERY？ | **进 GALLERY**（1 行 const，setFlag 自动解锁，零新 Autoload） | 改 GameManager.gd 1 行 vs WardrobeManager 宠物栏（改造成本高，不推荐） |
| **D4** | 事件文件用 events_life.json 追加 还是新建 events_p2.json？ | **追加 events_life.json**（免注册，同源） | 是否需要改 DataManager.EVENT_FILES |
| **D5** | 攒钱用玩家侧 flag 比较（零引擎）还是加 requireMoney 门控（轻量引擎）？ | **零引擎默认**（玩家侧比较）；可选加 requireMoney | 是否改 DataManager +5~6 行 |
| **D6** | 手作是否做可赠送物品（ITEM_DB 依赖）？ | **轻量纯 flag+属性版**（默认）；可选加 ITEM_DB | 是否改 GameManager.ITEM_DB + GIFT_PREFERENCES |
| **D7** | 追星是否联动 addict（刷手机追番隐喻）？ | **建议联动**（`int_idol_fanfeed` addict+3，小量），不新增机制 | 是否接入现有网瘾衰减链 |
| **D8** | 事件总数 16（兴趣9+经济7）是否 OK？ | **接受 16**；若更克制可砍 I7/E7 → 14 | P2 密度 |

---

## 10. 用户确认记录（落地依据）

| # | 决策点 | 用户选择（2026-07-30） |
|---|---|---|
| D1 | 压岁钱 | 春节强制叙事（SPECIAL_DATES day95 + fest_narrative_map） |
| D2 | 兼职 | DailyCycleManager 周结算（_check_parttime_income，周末周薪 80） |
| D3 | 宠物 | 进 GALLERY（GALLERY_ITEMS +1 行，setFlag 自动解锁） |
| D4 | 事件文件 | 追加 events_life.json（免注册） |
| D5 | 攒钱 | 启用 requireMoney 门控；**修正储蓄模型**：存款不扣可花零花钱（纯叙事+stress-2），兑现 requireMoney:100 + money-100，逻辑自洽 |
| D6 | 手作 | 启用 ITEM_DB handmade_gift（可赠物品：DialogueUI 加 addItem 字段支持） |
| D7 | 追星 | 联动 addict（int_idol_fanfeed addict+3） |
| D8 | 密度 | 接受 16 件（兴趣9+经济7） |

→ 工程落地：design-strategist 写 16 事件入 events_life.json（D5/D6 启用对应字段）；engineering-lead 落 D1/D2/D3/D5/D6 引擎改动；quality-lead 校验。

## 附录 · 字段 / 门控 / 合法 statDelta 速查

- **合法 statDelta 键（8）**：`intellect / strength / social / art / charm / stress / addict / money`（E4）。严禁 `study` 死键（`add_stat` 对不存在 key 静默丢弃）。
- **门控字段（DataManager.get_available_event L196-314）**：`triggerDay`(下界) / `charId` / `slotId` / `priority` / `repeatable` / `requireFlags` / `excludeFlags` / `requireItem`/`requireItemAmt` / `minAddict` / `minStress` / `conditionType` / `requireWeather` / `requireSeason` / `requireHoliday`(`any`/具体) / `requireRelState`/`excludeRelState`(仅 charId 非空时) / `requireNGCount` / `requireNotEnding`。**无 `requireMoney` 门控**（E12）→ 攒钱 money 比较走玩家侧或可选 requireMoney。
- **scene / choice 支持**：`speaker`(`null`/`"player"`/角色id) / `text` / `setFlag` / `setFlags` / `clearFlag` / `statDelta` / `statsDelta`(二者均识别) / `next`(99=结束) / `reqMoney`(扣费非门控) / `choices[].statDelta/next/setFlag`。
- **setFlag → GALLERY**：场景级/选项级 `setFlag` 自动 `unlock_gallery`（DialogueUI L197-200/L467-469），对应 `GALLERY_ITEMS` 条目（同 flag）即收集项。

---

*—— 本草案完。所有字段名/门控/系数/行号均来自对 `scripts/` 真实源码与事件文件的读盘（DataManager / DailyCycleManager / GameManager / MainGame / WeChatUI / WardrobeManager / CollectionManager / SeasonManager / DialogueUI / events_life.json / events_daily.json / events.json / events_break.json），未臆造数据。未写任何事件 JSON、未改任何 `.gd` 源码。待用户确认后进入工程落地。*
