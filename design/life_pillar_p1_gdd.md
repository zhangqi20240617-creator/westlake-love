# 《西湖边青春》P1 内容补强 · 设计草案 GDD

> **文档性质**：设计草案（DESIGN-ONLY）。本文件**不写任何事件 JSON、不修改任何 `.gd` 源码**，仅供主理人（游承峰）汇编后交用户确认；确认后才进入落地阶段。
> **范围**：审计 `life_coverage_audit.md` 中 P1 四项内容支柱 —— ① 节日节气补全 ② 同学社交圈（正向 bonding）③ 考试节奏（一模/二模/月考）④ 毕业仪式感。拟真手机沉浸（P1-⑧）按用户要求**不在本次**。
> **事件总数**：**20** 个策划事件 + 4 条 `SPECIAL_DATES` 考试日配置（合计四支柱，落在审计建议的 16–24 区间内）。
> **前缀约定**：`fest_`（4）/ `mock_`（6，替代用户建议的 `exam_` 以规避冲突）/ `grad_`（4）/ `bond_`（6）。

---

## 0. 读盘结论摘要（真实证据，非臆造）

| # | 结论 | 证据（文件 · 行号） |
|---|---|---|
| E1 | 节日 `festival` 分支**仅解锁烹饪食谱**，不触发任何剧情事件 | `MainGame.gd` `_on_special_date()` L291-303；`festival_map` 仅 `new_year/dragon_boat/mid_autumn_cooking` |
| E2 | `SPECIAL_DATES` 现有节日：day30 元旦 / day120 端午 / day310 中秋 为 `festival`；**无教师节** | `DailyCycleManager.gd` L12-29 |
| E3 | `exam` 分支**按 effect 通用处理，未硬编码 day**（day60/180 之外的新 exam 日会**自动生效**） | `MainGame.gd` L243-265，`if effect == "exam"` |
| E4 | `exam` 分支**不调用 `ScoreRevealUI`**（仅 `ending` 分支 L237-242 用 `ScoreRevealUI`）；它改调 `exam_result_perfect`/`exam_result_bad` 事件 | `MainGame.gd` L243-265 vs L237-242 |
| E5 | `exam_result_perfect/bad` 在 `events.json` 与 `events_daily.json` **跨文件重复 id**；但 `events.json` **不在** `EVENT_FILES`，运行时实际用的是 `events_daily.json` 版本 | `DataManager.gd` L10-21；`events_daily.json` L306/L335 |
| E6 | **`events.json` 未被 `DataManager` 加载**（不在 `EVENT_FILES`）→ P1 事件须落进已注册文件，推荐 `events_life.json`（position 10，最后加载，重复 id 时优先） | `DataManager.gd` L10-21 |
| E7 | 事件 schema 支持 `id/charId/location/slotId/triggerDay/minStress/minAddict/priority/repeatable/requireFlags/excludeFlags/title/scenes[]`；scene 支持 `setFlag`/`statDelta`/`statsDelta`/`choices[].statDelta/next` | `events_life.json` 实证；`DialogueUI.gd` L198-200 / L416-423 / L465-470 |
| E8 | 合法 `statDelta` 键 = `intellect/strength/social/art/charm/stress/addict`（在 `GameManager.stats`）+ `money`（`add_stat` 特判）；**无 `study` 死键** | `GameManager.gd` L8-16 / L602-629 |
| E9 | 朋友圈 `moments_db` 为 `WeChatUI.gd` 内硬编码数组，按 `unlock_day` 过滤；`build_moments_list()` 无 flag 门控 | `WeChatUI.gd` L31-108 / L1118-1339 |
| E10 | 画廊收集项 = `GameManager.GALLERY_ITEMS`（const 数组，按 `flag` 解锁）；`setFlag` 会自动 `unlock_gallery(flag)` | `GameManager.gd` L291-343；`CollectionManager.gd` L30-32 |
| E11 | 事件 `charId:null` 时 `get_available_event` 不做性别过滤 → **男女主通用（对称）** | `DataManager.gd` L210-215 |
| E12 | P0 `events_life.json` 已有同学冲突 flag：`flag_conflict_active` / `flag_conflict_resolved` / `flag_peer_upstander` 等，可作 P1 bonding 门控复用 | `events_life.json` L246/271/297/328 |

---

## 1. 设计支柱与总览

设计目标：**把"初中三年生活"从恋爱支柱的装饰层，提升为与恋爱并列的第二支柱**（呼应审计 §五）。P1 四支柱均走 `social` + 新 `flag` + 合法属性，刻意**不写任何 `favorability` / 不碰 `RelationshipManager`**，避免支柱漂移。

| 支柱 | 事件数 | 触发方式 | 衔接系统 |
|---|---|---|---|
| ① 节日节气补全 | 4 | `SPECIAL_DATES`(festival) 强制启动 | CookingManager（既有）、`_on_special_date` festival 分支（需 eng 追加 start_event） |
| ② 同学社交圈（正向） | 6 | 地点 + triggerDay + priority 常规选择 | DataManager 门控、WeChatUI 朋友圈（可选） |
| ③ 考试节奏 | 6 事件 + 4 考试日配置 | 4 个新 `exam` 日（自动复用既有结算）+ 6 个上下文事件 | `exam` 分支（E3 已确认自动生效）、`exam_result_*` 事件 |
| ④ 毕业仪式感 | 4 | triggerDay 窗口（day555-569）+ priority | GALLERY_ITEMS/flags（collectible）、EndingScreen 既有多分支 |
| **合计** | **20** | — | — |

**时间轴分布（防认知过载）**：节日 day{10,30,120,310}；考试 day{100,240,330,480}；bonding day{60→300} 散布；毕业 day{555,558,562,565}。任意 5 日窗口内强制触发 ≤1 次（节日/考试为单日单发；毕业 4 件跨 14 天）。

---

## 2. 四支柱事件蓝图表

> 字段说明：`trigger` = 触发机制；`charId` 全为 `null`（性别对称）；`statΔ` 仅用合法键（E8）；`gate` = 门控；`eng` = 是否需要工程依赖（✓=需，`-`=纯 JSON 即可）。

### ① 节日节气补全（前缀 `fest_`，强制启动，location:null 以避免地点属性加成）

| id | 标题 | trigger | charId | statΔ | gate | eng |
|---|---|---|---|---|---|---|
| `fest_teacherday` | 📚 教师节·谢师 | `SPECIAL_DATES` day10 `festival`/`teacher_day`（**新增**） | null | social+3, stress-3 | — | ✓ 见 §4-D1/D2 |
| `fest_newyear` | 🎉 元旦·跨年愿望 | `SPECIAL_DATES` day30 `festival`/`new_year` | null | social+2, stress-5 | — | ✓ 见 §4-D1 |
| `fest_dragonboat` | 🎋 端午·龙舟彩绳 | `SPECIAL_DATES` day120 `festival`/`dragon_boat` | null | social+2, strength+1 | — | ✓ 见 §4-D1 |
| `fest_midautumn` | 🥮 中秋·湖畔赏月 | `SPECIAL_DATES` day310 `festival`/`mid_autumn` | null | social+2, stress-8, art+1 | — | ✓ 见 §4-D1 |

*注：4 个节日事件均设 `location:null` + 自带 `bg`（沿用现有背景如 `home.png`/`lakeside.jpg`），由 `_on_special_date` 在节日当天强制 `start_event()` 启动（设计仅描述，代码改动见 §4）。`repeatable:false` —— 每局每个节日仅一次。*

### ② 同学社交圈（前缀 `bond_`，常规地点事件，性别对称）

| id | 标题 | trigger（location · slot · triggerDay） | charId | statΔ | gate | eng |
|---|---|---|---|---|---|---|
| `bond_bestie` | 💬 闺蜜/死党夜谈 | community · evening · day60 | null | social+4, stress-8 | — | - |
| `bond_bros` | 🏀 兄弟/哥们球场 | playground · noon/after · day80 | null | social+4, strength+2, stress-8 | — | - |
| `bond_classgroup` | 📱 班级群接龙乌龙 | home · evening · day100 | null | social+3, stress-3 | — | - |
| `bond_accept` | 🤝 小团体接纳 | classroom · day150 | null | social+5, stress-6 | requireFlags:`flag_conflict_resolved`（E12 已存在） | - |
| `bond_misunderstanding` | 💭 误会疏远又和解 | community · day200 | null | 分支：解释 social+5,stress-5 / 赌气 social-2,stress+5 | requireFlags:`bond_accept`；excludeFlags:`bond_misunderstood` | - |
| `bond_birthday` | 🎂 班级生日惊喜 | classroom · day300 | null | social+4, stress-6, money-20 | — | - |

*注：文案采用性别中性写法（"和最好的朋友""班里同学"），适配男女主双性别（E11）。如需严格男女分线，见 §7 取舍与 §8 决策点。*

### ③ 考试节奏（前缀 `mock_`，6 上下文事件 + 4 考试日配置）

**A. 4 条 `SPECIAL_DATES` 考试日配置（effect:"exam"，自动复用既有结算，E3 确认零 eng）：**

| day | label | effect | 复用行为 |
|---|---|---|---|
| 100 | 第一次月考 | exam | 自动触发 `exam` 分支 → `exam_result_perfect/bad`（E4/E5） |
| 240 | 第二次月考 | exam | 同上 |
| 330 | 一模 | exam | 同上 |
| 480 | 二模 | exam | 同上 |

**B. 6 个考试上下文事件（纯 JSON，地点 + triggerDay，提供一模/二模/月考专属叙事氛围）：**

| id | 标题 | trigger（location · triggerDay） | charId | statΔ | gate | eng |
|---|---|---|---|---|---|---|
| `mock_prep` | 📝 月考前动员 | classroom · day90 | null | intellect+2, stress+3 | — | - |
| `mock_review` | 📖 月考后订正 | classroom · day105 | null | intellect+2, social+2, stress-4 | — | - |
| `mock_mid_prep` | 🌙 一模前夜 | home · day320 | null | intellect+2, stress+5 | — | - |
| `mock_mid_review` | 🎯 一模后定位 | classroom · day340 | null | intellect+2, social+2, stress-4 | — | - |
| `mock_stress_relief` | 🌿 备考减压 | library · day400 | null | social+2, stress-8 | — | - |
| `mock_reflection` | 🔭 二模后回望 | home · day490 | null | intellect+1, social+3, stress-5 | — | - |

*注：考试"成绩结算"本身由 `exam` 分支（既有 `exam_result_*` 事件，含 money±500/±100、stress± 等大摆动）承担；P1 不新增经济摆动量级，故**不引入新的经济失衡**（见 §6 红线）。若需一模/二模/月考各自独立结算文案，见 §4-D4 可选 eng。*

### ④ 毕业仪式感（前缀 `grad_`，triggerDay 窗口 day555-569，collectible 用 flag）

| id | 标题 | trigger（location · triggerDay） | charId | statΔ | gate / setFlag（collectible） | eng |
|---|---|---|---|---|---|---|
| `grad_yearbook` | 📔 写同学录 | classroom · day555 | null | social+3, stress-5 | setFlag:`grad_yearbook` | 可选 §4-D6 |
| `grad_photo` | 📸 拍毕业照 | playground · day558 | null | social+4, stress-4 | setFlag:`grad_photo`（**暂缓 CG**，先用文字 collectible + 现有 bg） | 可选 §4-D6 |
| `grad_dinner` | 🍻 散伙饭 | community · day562 | null | social+4, stress-8, money-30 | setFlag:`grad_dinner` | 可选 §4-D6 |
| `grad_lastclass` | 📚 班主任最后一课 | classroom · day565 | null | social+3, stress-6 | setFlag:`grad_lastclass` | 可选 §4-D6 |

*注：与既有 per-character 浪漫毕业前夜（`special_grad_*` @ lakeside day569，强制西湖）互补 —— 本支柱提供**集体**仪式，不抢 day569 个人线。collectible 默认以 `flag` + 日记 toast 落地；如需进画廊，见 §4-D6（可选）。*

---

## 3. 各支柱与现有系统的衔接

- **节日 ↔ CookingManager**：既有 `new_year/dragon_boat/mid_autumn_cooking` 解锁保持不变；P1 仅**追加**叙事事件，不改动烹饪逻辑。教师节 `teacher_day` 走 `festival` effect 但**不入 `festival_map`** → 不解锁食谱（设计见 §4-D1，分支对未知 banner 仅触发叙事、不报错）。
- **考试 ↔ 既有结算**：4 个新 exam 日直接复用 `exam` 分支（E3 已确认 effect 通用）。`exam_result_perfect/bad` 是 live 的 `events_daily.json` 版本（E5）。
- **社交 ↔ DataManager 门控**：`bond_accept` 复用 P0 的 `flag_conflict_resolved`（E12），形成"冲突→和解→被接纳→误会→再和解"的生活弧，且**全走 `social`+flag，不碰恋爱状态机**。
- **毕业 ↔ 收集/画廊**：`grad_*` 以 `setFlag` 写入 `GameManager.flags`，`DialogueUI` 在 `setFlag` 时自动 `unlock_gallery(flag)`（E10）；若 `GALLERY_ITEMS` 无对应条目，则仅作为普通 flag（不影响功能）。
- **朋友圈（可选）**：`bond_*` 事件完成后可选择性"发朋友圈"，由 engineering 在 `WeChatUI.moments_db` 增加对应帖子（E9）。

---

## 4. Engineering 依赖清单（精确到文件+函数+行号+改动性质）

> 全部为**设计描述**，本草案不修改源码。下列行号来自真实读盘。

**D1. `MainGame.gd` · `_on_special_date()` · festival 分支（L291-303）**
- 性质：**追加**（insert，约 +8 行），不改既有烹饪解锁。
- 设计：在 L303（`show_toast` 之后）新增节日叙事映射并 `start_event()`：
  ```
  # 设计草图（非源码，待落地时由 engineering 实现）
  var fest_narrative_map = {
      "new_year":    "fest_newyear",
      "dragon_boat": "fest_dragonboat",
      "mid_autumn":  "fest_midautumn",
      "teacher_day": "fest_teacherday"   # 不在 festival_map，仅触发叙事，不解锁食谱
  }
  if fest_narrative_map.has(banner):
      var nev = DataManager.get_event_by_id(fest_narrative_map[banner])
      if not nev.is_empty():
          location_explore_ui.hide(); dialogue_ui.show(); dialogue_ui.start_event(nev)
  ```
- 影响：4 个节日均会强制启动叙事事件（既有 3 个节日由"仅解锁食谱"升级为"解锁食谱 + 叙事"，属于增量增强）。

**D2. `DailyCycleManager.gd` · `SPECIAL_DATES`（L12-29）**
- 性质：**追加** 5 条字典项：
  - `10:  {"label": "📚 教师节",     "effect": "festival", "banner": "teacher_day"}`（新增节日）
  - `100: {"label": "第一次月考",   "effect": "exam"}`
  - `240: {"label": "第二次月考",   "effect": "exam"}`
  - `330: {"label": "一模",         "effect": "exam"}`
  - `480: {"label": "二模",         "effect": "exam"}`
- 注意：`exam` 日**无需**改 `MainGame` exam 分支（E3 已确认按 effect 通用）；`teacher_day` 因不在 `festival_map`，D1 的 `fest_narrative_map` 负责其叙事，烹饪分支 `if festival_map.has(banner)` 自然跳过 → 无食谱解锁，符合预期。

**D3. `DataManager.gd` · `EVENT_FILES`（L10-21）—— 必需**
- 性质：**注册文件**（取决于落地策略）。
- 推荐：将 20 个 P1 事件**追加进 `events_life.json`**（已在 `EVENT_FILES`，position 10 最后加载，重复 id 时优先；且与 P0 life 事件同源，便于维护）。
- 备选：若另建 `events_p1.json`，必须在 `EVENT_FILES` 数组内追加其路径（L10-21 之间）。
- ⚠️ 若不注册，事件不会被加载、`get_event_by_id` 返回空 → 节日/考试强制启动将静默失败。

**D4.（可选）`MainGame.gd` · `_on_special_date()` · exam 分支（L243-265）**
- 性质：**改造**（仅当需一模/二模/月考独立结算文案时）。
- 设计：将 `target_event_id` 的判定由固定 `exam_result_perfect/bad` 改为按 `GameManager.day` 映射（如 day330→`mock_mid1_result` 等），新增对应事件 JSON。
- 不改造时：新 exam 日直接复用既有 `exam_result_perfect/bad`（功能完整，仅文案不区分"一模/二模"，可接受为 P1 草案默认）。

**D5.（可选）`WeChatUI.gd` · `moments_db`（L31-108）+ `build_moments_list()`（L1118+）**
- 性质：**追加**（朋友圈联动）。
- 设计：为 `bond_*` 事件新增 `moments_db` 帖子，可设 `unlock_day` 为事件日，或在 `build_moments_list` 增加 `require_flag` 过滤（当前仅按 `unlock_day` 过滤，E9）。属"发布到朋友圈"可选接线。

**D6.（可选）`GameManager.gd` · `GALLERY_ITEMS`（L291-343）**
- 性质：**追加**（毕业 collectible 进画廊）。
- 设计：为 `grad_yearbook`/`grad_photo` 增加条目（`char` 可用 `"player"` 或中性标识，`bg` 用现有 `classroom.jpg`/`lakeside.jpg`）。不接也 OK（flag 即 collectible）。

---

## 5. 节日/考试 `SPECIAL_DATES` 改动建议（仅描述，不写代码）

- **节日**：在 `SPECIAL_DATES` 新增 `10: teacher_day`（festival，无 cooking）；其余 3 个节日 banner 不变。配合 D1 在 `_on_special_date` festival 分支追加叙事启动（见 §4-D1）。
- **考试**：新增 4 条 `exam` effect 项（day100/240/330/480）。**无需**改动 exam 分支逻辑（E3 确认按 effect 通用、非 day 硬编码）；旧 day60/180 期末/期中保持不变。考试"成绩展示"继续走既有 `exam_result_perfect/bad` 事件（E4/E5）。

---

## 6. 质量门草案（PASS / CONCERNS / FAIL）

> 参考既有 life 校验（`design/life_pillar_p0_gdd.md` 与 `tests/life_smoke/validate_life.py`）口径制定。落地阶段由 engineering 跑校验。

| 检查项 | PASS | CONCERNS | FAIL |
|---|---|---|---|
| ID 唯一性 | P1 全部 id 在 live `EVENT_FILES` 内零重复；前缀 `fest_/mock_/grad_/bond_` 与既有 `exam_result_*` 不撞（用 `mock_` 规避） | 存在同前缀但全 id 不同（仅 validate 脚本警告） | 与既有 id **全 id 重复**（如误用 `exam_result_perfect`） |
| statDelta 合法 | 仅用 `intellect/strength/social/art/charm/stress/addict/money` | — | 出现 `study` 等死键或非上述字段 |
| 性别对称 | 全部 P1 事件 `charId:null`，男女主均可触发 | 个别事件含性别特定名词但 `charId:null` | 误写 `charId` 指向具体角色 |
| 不碰恋爱状态机 | 无 `affDelta`/`favors`/`relCold`/`relRecover`，无 `RelationshipManager` 调用 | — | P1 事件写入好感或触发冷战/挽回 |
| 不新建 Autoload | 仅复用 GameManager/DataManager/DialogueUI/CookingManager/WeChatUI | — | 新增 Autoload / 单例 |
| 文件注册 | P1 事件已落入 `events_life.json`（或已注册新文件） | 仅放入未注册的 `events.json` | 完全未注册 → 运行时不加载 |
| 门控合法性 | `requireFlags`/`excludeFlags` 引用的 flag 真实存在（如 `flag_conflict_resolved`） | 引用了 P0 之外未定义的 flag | 引用不存在的 flag 导致永不触发 |
| 时间轴密度 | 任意 5 日窗口强制触发 ≤1 次；毕业 4 件跨 ≥10 天 | 某窗口 2 次强制触发 | 同日/相邻日 ≥3 次强制触发（认知过载） |
| 经济/主导策略 | 未新增经济摆动量级；无单一属性主导回路 | 考试日频率上升但量级不变 | 引入刷分主导策略或新经济失衡 |

**验收门槛**：全部检查项 ≥ CONCERNS 且 **0 FAIL** 方可通过移交用户最终确认；出现任意 FAIL 须返工。

---

## 7. 风险与取舍

- **信息过载**：20 事件 + 4 考试日。缓解 = 时间轴散布（§1）；节日/考试为单日单发，bonding/exam 上下文按 triggerDay 错峰；毕业 4 件跨 14 天。监测点：若 `grad_*` 四件在 day555-569 因玩家不访问对应地点而错过，可升级为 `SPECIAL_DATES` 强制启动（见 D2 扩展，非必需）。
- **性别对称**：`charId:null` + 中性文案 = 男女主通用（E11）。取舍：若要求"闺蜜 vs 兄弟"严格分线，需把 6 个 bond 事件各拆男女版（+6 事件，共 12），成本翻倍。**草案默认中性单版**。
- **不碰恋爱状态机**：P1 全事件 `social`+flag，零好感写入。这是对抗审计所指"支柱漂移"的关键护栏（审计 §六）。
- **不新建 Autoload**：全部机制复用既有系统；朋友圈/画廊均为可选追加，不引入新单例。
- **节日强制启动打断当前活动**：`_on_special_date` 在每日结算时触发，`start_event` 会顶替当前地点 UI 进入节日叙事 —— 与既有 special 日日志行为一致，属预期"节日时刻"。节日事件设 `location:null` 以避免附带地点属性加成（E8）。
- **毕业照 CG**：按用户要求**暂缓生成**；以文字 collectible（`grad_photo` flag + 现有背景）落地，不依赖美术排期。
- **考试结算文案**：默认复用 `exam_result_perfect/bad`（量级与既有期末/期中一致，无新失衡）。独立一模/二模叙事为可选（D4）。

---

## 8. 待用户确认的关键决策点（交主理人汇编）

1. **教师节是否加入**？建议加（day10，`festival`/`teacher_day`，无烹饪解锁）。
2. **毕业照是否生成 CG**？建议暂缓，先用文字 collectible + 现有背景（不阻塞美术）。
3. **月考/一模/二模 day 定哪**？建议 月考 day100 & day240、一模 day330、二模 day480（均为 `exam` effect，自动复用结算）。
4. **exam 分支是否需改造**？建议 P1 **不改造**（复用 `exam_result_perfect/bad`）；若需一模/二模独立结算文案则改 `MainGame` L243-265（D4，可选）。
5. **前缀 `exam_` vs `mock_`**？建议 `mock_` —— Grep 确认 `exam_` 与既有 `exam_result_perfect/bad` 共享前缀（全 id 不冲突但前缀级去重会误报），`mock_` 已验证零冲突。
6. **社交 bonding 性别对称粒度**？建议 `charId:null` 中性单版（6 事件）；若需严格男女分线则扩至 12 事件。

---

## 附录 A · 落地 JSON 字段约定（供后续 authoring，非本草案产出）

事件对象需符合 `DataManager.get_available_event` 与 `DialogueUI` 已实现的 schema：
- 顶层：`id`(唯一) / `charId`(P1 全 `null`) / `location`(强制启动事件用 `null`) / `slotId`(可 `null`) / `triggerDay` / `priority` / `repeatable`(默认 `false`) / `requireFlags` / `excludeFlags` / `title` / `scenes[]`。
- scene：`speaker`(`null`/`"player"`/角色id) / `text` / `setFlag`(自动解锁同名 GALLERY flag，E10) / `statDelta` 或 `statsDelta`(二者均被 `DialogueUI` 识别，键仅限 E8 合法字段) / `next`(99=结束)。
- choice：`text` / `statDelta` / `next`(99=结束)；可选 `reqMoney`/`reqItem`。
- 强制启动类（`fest_*`）由 `_on_special_date` 经 `dialogue_ui.start_event()` 启动，**不经过** `get_available_event` 门控，但仍须能被 `get_event_by_id` 检索 → 必须注册进 live `EVENT_FILES`（D3）。

*—— 本草案完。所有结论均来自对 `scripts/` 真实源码与事件文件的读盘，未臆造字段名/行号。*
