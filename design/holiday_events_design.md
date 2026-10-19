# 长假特殊事件系统设计文档 · 《西湖边的青春》（set-piece 版 v2）

> 阶段：Phase 3「内容厚度」 · 模块：寒 / 暑 / 春 / 秋 四长假特殊事件
> 作者：design-strategist（文策渊） · 对接：engineering-lead（落地）/ quality-lead（质量门）/ art-director（§10 美术）
> 约束：**本文档只描述改动规格，不修改任何 `.gd` 文件**；`events_break.json` 为新增草稿文件。
> v2 变更：按用户拍板 4 项决策，长假升级为 **set-piece（强关系线 + 专属 CG / 分支结局）**，补全女主路线，秋假前移至 `[303,309]`。

---

## 0. 设计目标与核心支柱咬合

用户意图：「初中生活除了在学校的日子，还有寒假、暑假、春假、秋假，这些长假应该要有特殊事件。」

v2 在 v1（轻量 flavor）基础上，按已拍板决策升级为 **重磅 set-piece**：每个长假 = 一条强关系线 + 专属 CG / 画廊记忆 + 按选择分 2 个分支收尾。四个长假事件系统必须咬合已有**核心设计支柱**：
1. **机会成本提示**（学习 vs 社交）——kickoff 三选一（学习/出游/陪伴）。
2. **中考倒计时张力**——暑假 kickoff「学习」支线给 intellect 收益（决策 2 确认暑假保持 31 天 `[270,300]`）。
3. **关系状态机**——chapter 事件一律 `excludeRelState:"cold"`；长假期间暂停冷战检测。
4. **NG+ 继承**——chapter 为 `repeatable:false`，`DialogueUI.finish_event` 自动置 flag，与既有事件一致（详见 §7 风险 3）。

---

## 1. 长假日历扩展方案

### 1.1 新增 `SPECIAL_DATES` 条目（春假 / 秋假）

在 `DailyCycleManager.SPECIAL_DATES`（L12-27）**追加**以下两条：

```gdscript
# ── 新增：春假 / 秋假（决策 4：秋假前移至 day304，避开暑假 [270,300] 与白色情人节 day330）──
150: {"label": "🌱 春假开始",   "effect": "break"},
304: {"label": "🍂 秋假开始",   "effect": "break"},
```

> 避让校验：
> - 春假 day150：介于 day120 端午 与 day180 期中 之间，落在春学期末（季节映射春=1-150，day150 仍为春）。
> - 秋假 day304：处于 `BREAK_PERIODS.autumn=[303,309]` 内；前于 白色情人节 day330（间隔 26 天，无冲突），后于 中秋 day310（间隔 6 天）。原 day320 方案因与暑假 `[270,300]` 重叠风险被弃，**决策 4 改为 autumn `[303,309]`、标记日 304**。

### 1.2 新增 `BREAK_PERIODS` 常量

```gdscript
const BREAK_PERIODS = {
    "winter": [90, 100],    # 寒假 ≈11 天
    "spring": [150, 155],   # 春假 ≈6 天
    "summer": [270, 300],   # 暑假 ≈31 天（决策 2：保持 31 天不改）
    "autumn": [303, 309],   # 秋假 ≈7 天（决策 4：前移，原为 [320,325]）
}
```

- key 值 `winter/spring/summer/autumn` 即长假类型，**全系统统一**，被 `current_holiday`、`requireHoliday`、kickoff 事件 id 共用。
- 区间内每一天都视为「长假中」，用于门控事件、放宽地点、暂停冷战。

---

## 2. 新增状态变量 `GameManager.current_holiday`

### 2.1 变量声明（GameManager.gd）
与 `day` / `day_of_week` / `current_weather` 同级新增：
```gdscript
var current_holiday: String = ""   # 当前所处长假类型，否则 ""
```

### 2.2 每日设置函数（DailyCycleManager.gd）
```gdscript
func _update_current_holiday():
    var cur: String = ""
    for hol_type in BREAK_PERIODS.keys():
        var rng: Array = BREAK_PERIODS[hol_type]
        if GameManager.day >= int(rng[0]) and GameManager.day <= int(rng[1]):
            cur = hol_type
            break
    GameManager.current_holiday = cur
```

### 2.3 挂接位置（关键：顺序）
在 `GameManager.advance_time()` 每日结算块，置于 `_check_special_date()`（L419）**之前**：
```gdscript
DailyCycleManager._update_current_holiday()   # 新增，L419 之前
DailyCycleManager._refresh_char_moods()
DailyCycleManager._check_daily_decay()
DailyCycleManager._check_special_date()        # 此时 current_holiday 已就绪
DailyCycleManager._check_weekly_allowance()
```
> 读档注意：若 `SaveSystem` 不序列化 `current_holiday`，需读档后调用一次 `_update_current_holiday()` 重建。

---

## 3. 事件门控机制（混合方案）

### 3.1 (a) 信号 kickoff —— MainGame._on_special_date
在 `_on_special_date`（L233）新增分支，类型直接读 `GameManager.current_holiday`，按 `holiday_kickoff_<type>` 取事件并 `start_event`（复用 exam 分支写法）：
```gdscript
elif effect == "break" or effect == "free_day":
    var hol_type: String = GameManager.current_holiday
    if hol_type != "":
        var ev = DataManager.get_event_by_id("holiday_kickoff_" + hol_type)
        if not ev.is_empty():
            location_explore_ui.hide()
            dialogue_ui.show()
            dialogue_ui.start_event(ev)
```
> kickoff 的「出游 / 陪伴」选择会 `setFlag: "holiday_chapter_<type>"`，作为后续 chapter 事件的触发闸门（见 §9）。

### 3.2 (b) 多日门控 —— `requireHoliday`
`DataManager.get_available_event`（L173）`requireSeason` 检查（L269-271）之后插入：
```gdscript
var req_holiday = ev.get("requireHoliday", "")
if req_holiday == null: req_holiday = ""
if req_holiday != "":
    if req_holiday == "any":
        if GameManager.current_holiday == "": continue
    elif GameManager.current_holiday != req_holiday: continue
```

### 3.3 (c) 上学日日常事件抑制（位置集合方案，零 JSON 改）
长假期间跳过校内地点事件：
```gdscript
if GameManager.current_holiday != "":
    var SCHOOL_LOCATIONS = ["classroom", "library", "playground", "music_room", "art_room"]
    var ev_loc = ev.get("location", "")
    if ev_loc == null: ev_loc = ""
    if ev_loc in SCHOOL_LOCATIONS: continue
```

### 3.4 (d) chapter 触发闸门 —— `requireFlags`
chapter 事件额外要求 kickoff 选择了出游/陪伴，避免「学习」支线误入 set-piece：
```gdscript
# 在 requireHoliday 检查之后
var req_flags = ev.get("requireFlags", [])
if req_flags == null: req_flags = []
for f in req_flags:
    if not (f in GameManager.flags): continue   # 已复用 L224-231 的 requireFlags 逻辑
```
> chapter 的 `requireFlags: ["holiday_chapter_<type>"]` 与 kickoff 的 `setFlag` 严格对应（winter/spring/summer/autumn）。

### 3.5 (e) 新字段 `bg`（美术占位，需引擎支持）
chapter / kickoff 事件携带 `"bg": "res://assets/backgrounds/holiday_*.jpg"`。当前引擎未消费该字段——**engineering 需在 `DialogueUI` start_event 时若事件含 `bg` 则切换背景层**（见 §10 / §7 风险 7）。`events_break.json` 已填入占位路径，art 后续替换真图即可。

---

## 4. 地点 / 访问变更（LocationManager.gd）

### 4.1 放宽 school_only_mode
`get_available_locations()`（L34）school_only_mode 隐藏块（L59-61）叠加 `current_holiday == ""`：
```gdscript
if not weekend and GameManager.current_holiday == "" and (slot_id == "morning" or slot_id == "noon"):
    if loc_id in school_only_mode: continue
```
### 4.2 长假临时热点 ✅ 已落地（2026-07-30）
`_get_temp_hotspots()`（L16-24）可追加长假热点，`event_id` 指向 `events_break.json` 真实 id（如 `break_winter_temple`）。核心门控已由 §3 保证。

---

## 5. 关系机制（长假暂停冷战）

`DailyCycleManager._check_daily_decay()` 第 4 步（L114-126）包 `current_holiday == ""` 守卫：
```gdscript
if GameManager.current_holiday == "":
    for char_id in GameManager.favorability.keys():
        ... # 仅学期内检测 21 天未互动 → 进入冷战
```
> kickoff 的「陪伴」支线呼应关系支柱：选陪伴后设 `holiday_chapter_<type>`，长假中到对应角色地点会触发 chapter（强关系 set-piece）。

---

## 6. 给 engineering-lead 的代码改动规格（分文件）

> 字段名 / 状态变量名 / kickoff id 须与本文档及 `events_break.json` 完全一致。

| # | 文件 | 函数 / 行号范围 | 改动意图 |
|---|------|----------------|----------|
| 1 | `scripts/DailyCycleManager.gd` | `SPECIAL_DATES`（L12-27）之后 | **追加** `day150` 春假、`day304` 秋假两条 `break` 条目（§1.1；秋假标记日 304，非 320） |
| 2 | `scripts/DailyCycleManager.gd` | `SPECIAL_DATES` 之后 | **新增** `const BREAK_PERIODS`（§1.2），autumn=`[303,309]` |
| 3 | `scripts/DailyCycleManager.gd` | 新函数 | **新增** `func _update_current_holiday()`（§2.2） |
| 4 | `scripts/GameManager.gd` | 状态变量区 | **新增** `var current_holiday: String = ""` |
| 5 | `scripts/GameManager.gd` | `advance_time()`（L419 之前） | **调用** `_update_current_holiday()`（§2.3）；读档后重建 |
| 6 | `scripts/DataManager.gd` | `get_available_event()`（L271 后） | **新增** `requireHoliday` 检查（§3.2） |
| 7 | `scripts/DataManager.gd` | `get_available_event()` 循环内 | **新增** 校内地点抑制（§3.3）；复用既有 `requireFlags` 逻辑承载 chapter 闸门（§3.4） |
| 8 | `scripts/DataManager.gd` | `EVENT_FILES`（L10-19） | **注册** `"res://scripts/events_break.json"`（v1 已列，确认保留） |
| 9 | `scripts/MainGame.gd` | `_on_special_date()`（L233，festival 后） | **新增** `elif effect=="break" or effect=="free_day":` 分支（§3.1） |
| 10 | `scripts/LocationManager.gd` | `get_available_locations()`（L59-61） | 隐藏条件追加 `current_holiday == ""`（§4.1） |
| 11 | `scripts/LocationManager.gd` | `_get_temp_hotspots()`（L16-24） | **可选** 长假热点（§4.2） |
| 12 | `scripts/DialogueUI.gd` | `start_event()` | ✅ 已落地：事件含 `bg` 字段则切换背景层（L116-121，含 null 防御） |

---

## 7. 风险点 / 取舍（供 quality-lead）

1. **暑假 31 天**：决策 2 确认保持 `[270,300]`。长假内校内事件被抑制约一个月；内容由 2 个 summer chapter（keke/zijun）+ 3 个 summer filler 填充，多天可重复触发 filler 缓解空窗。如仍显空，可后续缩短（非本次范围）。
2. **冷战「暂停」非「冻结」**：§5 仅阻止长假内新触发，未冻结 `last_interact_*` 计数，长假结束次日可能集中进入冷战。已采纳为已知行为；如需真正冻结，须边界前移计数（成本略高）。
3. **NG+ 继承**：chapter `repeatable:false`，`finish_event` 自动置 flag → 若 `NGPlusManager` 重置 flags 则每周目重放（与 `ng_first_*` 一致）；若不清则只播一次。需与 `NGPlusManager` 行为对齐确认。
4. **性别路线覆盖**：**已补全**——10 个 chapter 覆盖全部 5 男（yutong/jingjing/wanqing/xiaoxia/keke）+ 5 女（yifei/zicheng/beichen/jingjing_m/zijun），每个长假至少 1 条女主线分支（winter=yifei, spring=beichen, summer=zijun, autumn=zicheng+jingjing_m）。原 v1 的「女主无内容」缺口已关闭。
5. **秋假位置**：决策 4 已解决——autumn `[303,309]`、标记日 day304，与暑假 `[270,300]` 零重叠，距白色情人节(330) 26 天，无叙事撞车。
6. **chapter 与 filler 的 (loc,slot) 共存**：chapter 优先级 160-170 高于 filler 110-130，且 chapter 为一次性、filler 可重复。同 (loc,slot) 同日发生时 chapter 胜出，filler 可在其他天/地点触发；多日长假天然提供变化。若某长假内仍觉 filler 被压制，可在 LocationManager 热点或 slot 分配上微调（见 §9 分布表）。
7. **`bg` 字段引擎支持**：`events_break.json` 已写占位路径，`DialogueUI.gd` L116-121 已实现事件级 bg 覆盖（含 null 防御），CG 可正常显示（§6 #12 已落地）。原"不消费 bg"的缺口已关闭。

---

## 8. Handoff 备注（决策落地状态）

| # | 用户决策 | 落地状态 | 说明 |
|---|----------|----------|------|
| 1 | 出游深度 = 重磅 set-piece | ✅ 已落地 | 每假 1+ 条强关系 chapter（多场景 + 分支结局 + 专属 CG/画廊记忆） |
| 2 | 暑假长度 = 保持 31 天 | ✅ 已落地 | `summer:[270,300]` 不变 |
| 3 | 性别路线 = 补全女主线 | ✅ 已落地 | 10 chapter 覆盖全部 5 女角色；每假 ≥1 女支线 |
| 4 | 秋假前移避让 ~day300 | ✅ 已落地 | `autumn:[303,309]`、标记日 day304（非 day320） |

**仍未完全关闭（待 art / 工程 / 用户）**：
- A. 美术生产：§10 列出的 4 张 CG 背景 + 10 个画廊记忆槽需 art-director 制作（当前为占位路径）。
- B. `bg` 引擎接线：§6 #12，`DialogueUI` 背景切换。
- C. NG+ flag 重置：与 `NGPlusManager` 对齐（风险 3）。
- D. `free_day`（元旦 day31）仍不触发 kickoff——是否要轻量元旦事件，待定（低优先）。
- E. chapter 与 filler 的 (loc,slot) 平衡可在落地后按手感微调（风险 6）。

---

## 9. Set-piece 结构说明

**触发链**：长假第 1 天 `_check_special_date` 发 `break` 信号 → `MainGame` 按 `current_holiday` 取 `holiday_kickoff_<type>` 强制启动 → 玩家三选一：
- 学习 → 仅 statDelta，置 `holiday_mode_<type>_study`，**不进入 chapter**。
- 出游 / 陪伴 → 置 `holiday_chapter_<type>`，于后续地点访问中由 `get_available_event` 选出对应角色的 chapter。

**chapter 结构（每事件 8-9 场景）**：出发 → 角色邀约 → 相处分支A/B → 高潮 moment（角色台词）→ 玩家二选一 → **2 个分支收尾场景**（按选择分流，affDelta 不同文本不同）。章节用 `charId` + `minAff:30` + `excludeRelState:"cold"` + `requireHoliday` + `requireFlags:["holiday_chapter_<type>"]` 门控，自动按玩家性别（route）与关系状态筛选。

**分支结局（务实解读，不 fork 主大结局）**：两个收尾场景均 `setFlag:"holiday_memory_<holiday>_<char>"`——该 flag 经 `DialogueUI` 的 scene `setFlag` 路径自动 `unlock_gallery`（解锁画廊记忆），并随 `finish_event` 自动写入「和 X 聊了聊」日记（特殊 log）。玩家可在画廊回看该假期的专属 CG + 记忆文本。

**分布（避免 (loc,slot) 互相压制）**：
| 长假 | chapter（角色 / 位置 / 优先级） | 女主线 |
|------|--------------------------------|--------|
| winter [90,100] | yutong/lakeside·evening/170 · jingjing/off_campus_shop·after/165 · yifei/cinema·noon/160 | yifei ✓ |
| spring [150,155] | wanqing/lakeside·evening/170 · xiaoxia/community·after/165 · beichen/cinema·noon/160 | beichen ✓ |
| summer [270,300] | keke/lakeside·evening/170 · zijun/community·after/165 | zijun ✓ |
| autumn [303,309] | zicheng/lakeside·evening/170 · jingjing_m/community·after/165 | zicheng ✓ / jingjing_m ✓ |

---

## 10. 美术资产清单（供 art-director）

> 所有路径为占位，art 交付真图后替换即可；`events_break.json` 已引用。

**A. 假期背景 CG（4 张，按长假各 1 张，chapter/kickoff 共用）**
- `res://assets/backgrounds/holiday_winter.jpg` — 寒假·雪后断桥 / 糖水铺暖光
- `res://assets/backgrounds/holiday_spring_outing.jpg` — 春假·苏堤桃花 / 攀岩馆
- `res://assets/backgrounds/holiday_summer_trip.jpg` — 暑假·萤火夜跑 / 夜市
- `res://assets/backgrounds/holiday_autumn_osmanthus.jpg` — 秋假·桂花林 / 诗会

**B. 画廊记忆槽（10 个，flag = 解锁 id，需配套记忆文本 + 缩略 CG）**
- `holiday_memory_winter_yutong` / `holiday_memory_winter_jingjing` / `holiday_memory_winter_yifei`
- `holiday_memory_spring_wanqing` / `holiday_memory_spring_xiaoxia` / `holiday_memory_spring_beichen`
- `holiday_memory_summer_keke` / `holiday_memory_summer_zijun`
- `holiday_memory_autumn_zicheng` / `holiday_memory_autumn_jingjing_m`

**C. 角色立绘（可选增强）**：chapter 当前复用角色 `emoji` 标识（👩‍🎓🌸📚⚽🎻🏀🌟）。若 art 希望 set-piece 有专属立绘，可按上表 10 个 (角色×假期) 组合追加，非强制。

**D. 引擎接线（engineering）**：`DialogueUI.start_event` 检测到事件 `bg` 字段时切换背景层；`unlock_gallery` 须识别 §B 的 10 个 flag 以展示对应记忆（参考既有 `west_lake_*` setFlag 流程）。

---

## 11. 事件清单速览（26 个 · id + 一句话）

**Kickoff（4）**
- `holiday_kickoff_winter` — 寒假开始，学习/出游/陪伴三选一。
- `holiday_kickoff_summer` — 暑假开始，学习/出游/陪伴三选一（中考前最长自主期）。
- `holiday_kickoff_spring` — 春假开始，学习/出游/陪伴三选一。
- `holiday_kickoff_autumn` — 秋假开始（day304），学习/出游/陪伴三选一。

**Set-piece Chapter（10，覆盖全部 10 角色 / 双路线）**
- `break_winter_chapter_yutong` (M) — 雪夜断桥，与雨桐的牵手时刻。
- `break_winter_chapter_jingjing` (M) — 糖水铺，与菁菁的「明年同班」约定。
- `break_winter_chapter_yifei` (F) — 冬夜影院，与逸飞的「下次还来」。
- `break_spring_chapter_wanqing` (M) — 桃林写生，晚晴念出春天故事的主角名。
- `break_spring_chapter_xiaoxia` (M) — 攀岩馆，与小夏的每年之约。
- `break_spring_chapter_beichen` (F) — 科幻片，与北辰的「下个春假老地方」。
- `break_summer_chapter_keke` (M) — 萤火夜跑，与可可的芦苇荡秘密基地。
- `break_summer_chapter_zijun` (F) — 夜市淘宝，与子珺的河灯之约。
- `break_autumn_chapter_zicheng` (F) — 桂花林，与子诚的「每年秋天都来」。
- `break_autumn_chapter_jingjing_m` (F) — 桂花诗会，与菁菁（男）的朗诵之约。

**轻量 Filler（12，长假散落内容，与 set-piece 并存）**
- `break_winter_ski` / `break_winter_family` / `break_winter_temple`
- `break_summer_camp` / `break_summer_lake_night` / `break_summer_cram_meet`(yutong)
- `break_spring_outing` / `break_spring_qingming` / `break_spring_companion`(jingjing)
- `break_autumn_nationalday` / `break_autumn_osmanthus` / `break_autumn_companion`(wanqing)
