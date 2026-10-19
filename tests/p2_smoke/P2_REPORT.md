# P2 生活支柱补强 — 质量门独立校验报告

- **项目**：《西湖边的青春》（Godot 4.5 手游）
- **校验对象**：P2 生活支柱补强（设计 + 工程已落地，本次为 trust-but-verify 独立读盘）
- **校验角色**：质量负责人（quality-lead）
- **校验方式**：逻辑级（无 Godot 运行时）—— Python `json.load` 解析真实 JSON + 文本扫描 `.gd` 源码
- **校验日期**：2025-07-30

---

## 一、校验概要

| 项 | 内容 |
|---|---|
| 校验脚本 | `D:\zkgame\tests\p2_smoke\validate_p2.py` |
| 运行命令 | `"C:\Users\Administrator\.workbuddy\binaries\python\versions\3.13.12\python.exe" "D:\zkgame\tests\p2_smoke\validate_p2.py"` |
| 运行结果 | **10/10 断言 PASS，0 CONCERNS，0 FAIL** |
| 校验产物 | `events_life.json`（60 事件）、`DailyCycleManager.gd`、`GameManager.gd`、`DataManager.gd`、`DialogueUI.gd`、`MainGame.gd` |

---

## 二、逐项结论表（A–J）

| 项 | 结论 | 证据（行号 / 数据） |
|---|---|---|
| **A** events_life.json 可解析且总数==60 | **PASS** | `events_life.json` 成功 `json.load`；事件总数 = **60**（L1–L1406，60 个顶层对象） |
| **B** 事件 id 唯一 | **PASS** | 60 个 id，重复 = 无 |
| **C** 16 个 P2 事件全部存在 | **PASS** | int_*(9)：`int_idol_fanfeed`(L1061)/`int_idol_merch`(L1079)/`int_idol_concert`(L1097)/`int_pet_meet`(L1118)/`int_pet_adopt`(L1150)/`int_pet_care`(L1184)/`int_pet_moment`(L1203)/`int_craft_make`(L1222)/`int_craft_gift`(L1241)；eco_*(7)：`eco_lucky_money`(L1260)/`eco_parttime_apply`(L1278)/`eco_parttime_firstshift`(L1296)/`eco_save_set_goal`(L1315)/`eco_save_deposit`(L1333)/`eco_save_claim`(L1353)/`eco_shop_dilemma`(L1375) |
| **D** P2 charId 须为 null/缺失，且不触关系状态机 | **PASS** | 全部 16 件 `charId: null`；无任何 `requireRelState`/`excludeRelState`（男女对称，未碰 `RelationshipManager`） |
| **E** P2 statDelta 仅合法键 | **PASS** | P2 实际使用键 ⊆ `{social, stress, money, art, charm, addict}`，全部 ∈ 引擎合法集 `LEGAL_STAT_KEYS={intellect,strength,social,art,charm,stress,addict,money}`；非法键 = 无。合法集来源：`GameManager.gd` L8–16（`stats` 7 维）+ `money` 独立变量 + `add_stat()` L607–619 对 `"money"` 特判 |
| **F** flag 串联闭环 | **PASS** | 未被满足的 `requireFlags` = 无（已识别置位源 60 个）。依赖均闭环：`int_pet_adopt→int_pet_meet`(非可重复事件自动置位 id，L1124)、`int_pet_care`/`int_pet_moment→pet_orange_cat`(`int_pet_adopt` 显式 `setFlag` L1171)、`eco_parttime_firstshift→flag_has_parttime_job`(`eco_parttime_apply` 显式 `setFlag` L1290)、`eco_save_deposit`/`eco_save_claim→flag_save_goal`(`eco_save_set_goal` 显式 `setFlag` L1327) |
| **G** requireMoney 门控 + 储蓄模型修正 | **PASS** | `DataManager.gd` L252–255 含 `requireMoney` 门控（紧随 `requireItem` L245–250 之后，`if req_money>0 and GameManager.money<req_money: continue`）；`eco_save_claim` `requireMoney:100`(L1360)；`eco_save_deposit` statDelta 仅 `{stress:-2}`(L1347)，**无 money 扣减**；扣减经 `add_stat("money",-100)` 实际生效（`GameManager.gd` L608–614） |
| **H** 春节 + 兼职周薪 + Gallery + ITEM_DB | **PASS** | `DailyCycleManager.gd` L34 `95:{"label":"🧧 春节","effect":"festival","banner":"spring_festival"}`；L101–106 `func _check_parttime_income()`（`flag_has_parttime_job`+周末 `money+80`+`stress+2`+toast）；`GameManager.gd` L441 `advance_time` 内调用 `_check_parttime_income()`；L346 `GALLERY_ITEMS` 含 `pet_orange_cat`（`char:"player"`, `bg:"res://assets/backgrounds/community.png"`）；L254/L261 `ITEM_DB` 含 `handmade_gift`（name"手作礼物",icon"🎁",price 0,category"gift"） |
| **I** fest_narrative_map + 两处 addItem | **PASS** | `MainGame.gd` L306–312 `fest_narrative_map` 含 `"spring_festival": "eco_lucky_money"`(L311)；`DialogueUI.gd` L122–125 事件级 `addItem`（`event_data.get("addItem")`），L207–209 场景级 `addItem`（`scene["addItem"]`，真正生效点）；`int_craft_make` 场景级 `addItem:"handmade_gift"`(L1235) |
| **J** 人工目视样本 | **PASS** | 已打印 `int_craft_make`、`eco_save_claim` 完整 JSON 片段（见脚本 stdout），供人工复核 |

---

## 三、质量门总判定

> ## **PASS**

**阻塞项：无。**
全部 10 条断言（A–J）通过，P2 设计意图（D1 春节 / D2 兼职周薪 / D3 宠物进 GALLERY / D5 requireMoney 门控 / D6 ITEM_DB+addItem / D7 成瘾机制不冲突 / D8 接受 16 件）均在盘上得到真实产物印证，事件文件自洽（总数 60、id 唯一、flag 闭环、statDelta 键合法、未误触关系状态机）。

---

## 四、已知风险与缓解

> 以下为**非阻塞**项，建议跟踪但不影响本次放行。

### R1. 兼职周薪「周末任一天」可能单周发 2 次（CONCERN / 待策划调参）
- **现象**：`is_weekend()` = `day_of_week == 6 or 7`（`GameManager.gd` L86–87，即周六**与**周日都为真）。`_check_parttime_income()` 在任一周末日都会 `money += 80`，故双休周末 **+160/周** 而非设计预期的「周薪 +80」。
- **影响**：经济系统潜在失衡（高于每周零花钱 100 的边际被放大）。
- **缓解**：① 改为仅单日发放（如 `day_of_week == 7`）；② 或加周维度冷却 flag（如 `flag_parttime_paid_week`，每周一清零）。属设计可调参数，不阻塞 P2 放行，建议 P2.1 调平。

### R2. 无 Godot 运行时，未做端到端连通性验证
- **现象**：本次为纯逻辑级读盘校验，未实跑引擎。无法验证 `add_stat` / Gallery 解锁动画 / 事件在游戏内真实弹出 / `fest_narrative_map` 触发链路等运行时行为。
- **缓解**：需在 dev 环境跑一次冒烟（参考 `tests/holiday_smoke`、`tests/p1_smoke` 既有模式），对 day95 春节弹窗、`eco_lucky_money` 触发、`pet_orange_cat` 入 Gallery、`handmade_gift` 入背包做人工确认。

### R3. flag 命名与设计回顾文本不一致（文档级，非功能缺陷）
- **现象**：设计回顾写 `has_parttime_job`，实际实现用 `flag_has_parttime_job`（带 `flag_` 前缀）。引擎侧 `_check_parttime_income` 读取的也是 `flag_has_parttime_job`，与 `eco_parttime_apply` 的 `setFlag` 一致，**内部自洽**。
- **缓解**：建议统一设计文档与代码命名，避免后续维护误读。不影响功能。

### R4. 小橘猫承接既有「碰瓷/假摔」梗，本次未改 WeChatUI（无冲突）
- **现象**：`int_pet_meet` 文案与 Gallery hint 提及「学会假摔的小橘猫」，属对既有内容的承接；本次 P2 未改动 `WeChatUI`。
- **缓解**：D7 已验证 P2 未破坏成瘾/关系机制；该梗承接属内容连贯性，无冲突风险。

### R5. 跨文件 flag 闭环未穷举（低风险）
- **现象**：本校验仅加载 `events_life.json`，未交叉验证其它 `events_*.json` 是否也 `setFlag` 同名。
- **缓解**：P2 全部 `requireFlags` 已在 `events_life.json` 内或已知全局 flag 闭环，风险低；如需 100% 把握可在全量事件加载下复跑 F 项。

### R6. 时间序闭环（正面确认）
- 所有依赖在触发天数上可达：`eco_save_set_goal`(day100) → `eco_save_deposit`(day105) → `eco_save_claim`(day110)；`int_pet_meet`(day30) → `int_pet_adopt`(day40) → `int_pet_care`(day45)/`int_pet_moment`(day60)；`eco_parttime_apply`(day150) → `eco_parttime_firstshift`(day155)。时序无死锁。

### R7. 成瘾机制未受影响（D7 验证通过）
- P2 事件中 `int_idol_*` 沿用既有 `addict` 键（经 `add_stat` 已支持），未新增/修改 `RelationshipManager`、`requireRelState`、`excludeRelState`，与既有成瘾机制无冲突。

---

## 五、结论

P2 生活支柱补强**通过独立质量门校验（PASS，无阻塞项）**。工程产物真实存在且自洽，16 件事件、春节、兼职周薪、宠物 Gallery、requireMoney 门控、ITEM_DB/addItem 均已落地。建议后续跟进 **R1 兼职双付调平** 与 **R2 运行时冒烟**，以补足逻辑级校验未覆盖的端到端连通性。
