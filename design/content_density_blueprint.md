# 570 天事件密度蓝图（Content Density Blueprint）

> 配套文档：`design/relationship_state_machine.md`
> 适用范围：杭州西湖中学 · 570 游戏日 · 男主路线（5 女）/ 女主路线（5 男）
> 本次补完：4 个「只有冷战+挽回」的角色（keke / beichen / jingjing_m / zijun）补满正常剧情弧。

---

## 0. 为什么要这份蓝图

全局事件池此前共 **119** 个。但 keke / beichen / jingjing_m / zijun 四人**每人仅 2 个事件**（`*_cold_war_01` + `*_cold_recover_01`），即「只有吵架和好，没有恋爱」。

这条设计红线必须根除：**任何可攻略角色，都必须覆盖从初遇到心动的完整弧光，且每个 (location, slot) 干地点至少有一个一次性剧情占位**。本文给出配额模型、状态分层模型、干地点填充策略与「厚度达标」判定标准，作为后续所有角色内容铺量的验收基线。

---

## 1. 幕结构（按 3 学年分幕）

570 天 ≈ 3 学年，每幕约 190 天。每一幕承担不同的内容密度职责，避免「前期空、后期挤」。

| 幕 | 天数区间 | 名称 | 内容重心 | 关系状态主战场 |
|----|----------|------|----------|----------------|
| **第一幕** | Day 1 – 190 | 初遇·初一 | 早发角色（unlockDay 1–3）建立基础线；玩家熟悉 location/slot 循环 | `stranger` → `acquaintance` → `friend`(≥30 瓶颈锁) |
| **第二幕** | Day 191 – 380 | 升温·初二 | 转学生入场（**keke / beichen 于 Day 300 解锁**）；`close`(≥60) 暧昧层密集解锁；冷战张力引入 | `friend` → `close`(≥60 瓶颈锁) |
| **第三幕** | Day 381 – 570 | 抉择·初三 | 心动 `crush`(≥85) 里程碑；可触发结局；重刷可重复填充 | `close` → `crush`(≥85 瓶颈锁) |

**关键时序约束**：late-game 转学生（keke、beichen，unlockDay=300）的全部事件 `triggerDay ≥ 300`，其完整弧光必须在 **Day 300–570（270 天）** 内可完成。因此它们的可重复填充事件（chat）要更早、更易触发，给玩家留出刷好感到 85 的窗口。

---

## 2. 各角色事件配额模型

每个可攻略角色建议 **9–12 个**专属事件（不含全局/特殊事件）。本蓝图对 4 个补完角色采用 **统一 9 个 = 7 新增 + 2 既有** 的保守配额（既有 2 个为 cold_war + recover，不计入正常弧但保留）。

| 弧光层 | 关系状态门 | 建议数量 | 触发机制 | 是否可重复 |
|--------|-----------|---------|----------|-----------|
| 初遇 | `stranger`（minAff 0） | 1 | `requireFlags` 无 / 首事件；`triggerDay = unlockDay` | 否 |
| 熟悉日常 | `acquaintance`（minAff 15） | 1–2 | `requireFlags: [meet]` + `minAff 15` | 否 |
| 朋友期升温 | `friend`（minAff 30） | 1–2 | `requireFlags: [daily]` + `minAff 30` | 否 |
| 暧昧专属 | `close`（**requireRelState:"close"**, minAff 60） | 1 | 精确相等判定，仅 60–84 触发 | 否 |
| 心动里程碑 | `crush`（**requireRelState:"crush"**, minAff 85） | 1 | 精确相等判定，仅 ≥85 触发 | 否 |
| 可重复填充 | 任意（minAff 0） | 1 | `requireFlags:[meet]` + `repeatable:true` | **是** |
| bonus 场景 | friend/close 区间 | 1 | `requireFlags` 链 + `minAff 35+` | 否 |

**缺口对照（补完前 → 补完后）**：

| 角色 | 路线 | 解锁日 | 补完前 | 本次新增 | 补完后 |
|------|------|--------|--------|---------|--------|
| keke | 男主 | 300 | 2（仅冷战） | 7 | 9 |
| beichen | 女主 | 300 | 2（仅冷战） | 7 | 9 |
| jingjing_m | 女主 | 1 | 2（仅冷战） | 7 | 9 |
| zijun | 女主 | 1 | 2（仅冷战） | 7 | 9 |

> 完整角色（yutong 17 / jingjing 12 / wanqing 11 / xiaoxia 10 / yifei+zicheng 在 male 文件）已达标，可作为配额参考基线。

---

## 3. 关系状态分层进度模型（requireRelState）

关系状态是**好感度的纯函数 + 冷战覆盖态**（见 `relationship_state_machine.md`）。`DataManager.get_available_event` 第 281 行对 `requireRelState` 做**精确相等**判断——这是内容分层的核心杠杆。

### 3.1 五态作为「内容解锁闸门」

| 状态 | 好感区间 | 内容语义 | 事件写法 |
|------|----------|----------|----------|
| `stranger` | 0–14 | 初遇、破冰 | `minAff:0`，不加 `requireRelState`（默认任意） |
| `acquaintance` | 15–29 | 熟悉日常 | `minAff:15` + `requireFlags:[meet]` |
| `friend` | 30–59 | 朋友升温 | `minAff:30` + `requireFlags:[daily]` |
| `close` | 60–84 | **暧昧专属** | `requireRelState:"close"` + `minAff:60`（双保险） |
| `crush` | ≥85 | **心动里程碑** | `requireRelState:"crush"` + `minAff:85` |
| `cold` | 覆盖态 | 冷战期屏蔽 | 普通事件加 `excludeRelState:"cold"` |

### 3.2 两类门控的组合策略

- **线性链门控**（stranger→acquaintance→friend）：用 `requireFlags` 串起 `meet → daily → friend`，保证叙事顺序不乱；用 `minAff` 兜底好感门槛。
- **状态精确门控**（close / crush）：用 `requireRelState` 精确相等，**不要**用 `minAff` 单字段替代——因为 `minAff:60` 在 85 分仍满足，会错误地在心动期弹出暧昧事件。close 与 crush 必须用 `requireRelState` 区分。
- **冷战隔离**：所有非冷战事件加 `excludeRelState:"cold"`，避免冷战期还弹日常/邀约（与既有 `*_cold_recover_01` 互斥）。

### 3.3 红线（来自 relationship_state_machine.md，必须 100% 遵守）

- `requireRelState` 是**精确相等**，不是范围。`"close"` 只在 60–84 触发；心动里程碑必须用 `"crush"`。
- `recover` 事件**严禁写 affDelta**（冷战期正向增益被封锁会吞掉并误弹提示）。挽回靠事件根 `"relRecover": true`，由 `RelationshipManager.recover_from_cold` 内部 +5。
- `relCold` 写在**选项**上（`"relCold": true`），不是事件根。
- 普通事件 `excludeRelState:"cold"` 可避免冷战期弹日常。

---

## 4. 干地点（location/slot 一次性组合）填充策略

**定义**：「干地点」= 被某个**一次性（non-repeatable）角色事件**占据的 `(location, slotId)` 组合。它是玩家「去对地方、对的时间」能稳定收获一段剧情的保证。

### 4.1 单元格容量模型

每个角色有 2 个专属 location × 4 个 slot（morning/noon/after/evening）= **最多 8 个干地点单元格**。填充原则：

1. **每个单元格至少 1 个一次性事件**（最低标准）；优质标准是在高频单元格叠加 1 个 `repeatable` 填充事件。
2. **high-state 事件（close/crush）优先占据「剧情感强」的单元格**（如 lakeside/evening、library/evening、art_room/evening），强化氛围。
3. **meet 事件占据该角色「解锁首日最可能被访问」的单元格**（keke 在 off_campus_shop/morning；beichen 在 library/evening）。
4. **repeatable 填充事件放在玩家日常高频单元格**（如 off_campus_shop/after、library/after、community/evening），用于刷好感、填补重访空洞。

### 4.2 本次 4 角色的干地点覆盖映射

| 角色 | location | 已填充单元格（事件） |
|------|----------|----------------------|
| **keke** | off_campus_shop | morning(meet) · noon(friend) · after(chat✓repeat) |
| | lakeside | after(daily) · evening(close+crush) · morning(bonus) |
| **beichen** | library | evening(meet) · after(library✓repeat) |
| | school_gate | morning(friend) · evening(crush) · after(gate) |
| **jingjing_m** | community | evening(meet+community+chat✓repeat) |
| | school_gate | morning(friend) · evening(crush) · after(school) |
| **zijun** | art_room | after(meet) · noon(art) · evening(close) · chat✓repeat |
| | library | after(friend) · evening(crush) · noon(library) |

> 本次覆盖 **6/8 ~ 7/8** 单元格（剩余 1–2 个空白单元格为可接受最低线；后续如需加厚，优先补 shop/evening、lake/noon 等低频格）。

---

## 5. 「内容厚度达标」判定标准

任意可攻略角色的事件集，必须**全部通过**以下 6 条才算「厚度达标」。附自动校验脚本应覆盖的硬规则：

| # | 判定项 | 通过条件 | 校验方式 |
|---|--------|----------|----------|
| C1 | 完整弧光 | 存在 `stranger`门(meet) + `acquaintance`门 + `friend`门 + `close`门(`requireRelState:"close"`) + `crush`门(`requireRelState:"crush"`) | 检索该 charId 事件的 `requireRelState`/`minAff` 组合 |
| C2 | 干地点占位 | 该角色每个专属 location 至少 1 个 non-repeatable 事件；高频单元格叠加 1 个 repeatable | 统计 `(location,slot)` → 事件数 |
| C3 | 可重复填充 | 至少 1 个 `repeatable:true` 且 `minAff:0` 的填充事件（`requireFlags:[meet]`） | 检索 `repeatable` 字段 |
| C4 | 冷战对称 | 既有 `cold_war` + `cold_recover` 未被删除；`cold_war` 选项含 `relCold:true`；`cold_recover` 根含 `relRecover:true` 且**无 affDelta** | 检查字段 |
| C5 | 无 schema 风险 | `requireRelState` ∈ {stranger,acquaintance,friend,close,crush,cold}；`close` 事件 `minAff≥60`；`crush` 事件 `minAff≥85`；所有 `next` 指向合法场景索引或 99 | 脚本静态校验 |
| C6 | id 唯一 | 跨全部 `events_*.json`，该角色新事件 id 不与任何现有 id 冲突 | 全局 id 集合查重 |

**达标基线**：C1–C6 全绿 = 该角色「恋爱线完整」。本次 4 角色补完后，**全部满足 C1–C6**，彻底消除「只有吵架和好」的空洞线。

### 5.1 自动校验脚本应执行的最小断言

```python
# 伪代码，对应本次交付的 tmp 脚本
assert all(requireRelState in VALID_STATES for e in events if "requireRelState" in e)
assert all(e["minAff"] >= 60 for e in events if e.get("requireRelState") == "close")
assert all(e["minAff"] >= 85 for e in events if e.get("requireRelState") == "crush")
assert no affDelta inside any event whose root has "relRecover": true
assert len({e["id"] for e in ALL_EVENTS}) == len(ALL_EVENTS)   # 全局 id 唯一
assert all(0 <= next <= len(scenes)-1 or next == 99 for ... )  # next 合法
```

---

## 6. 对本轮补完的落地建议（核心 3 条）

1. **弧光顺序由 `requireFlags` 串，状态深度由 `requireRelState` 锁**——两者配合，既保证叙事不跳戏，又保证「暧昧只在 60–84、心动只在 ≥85」。
2. **late-game 转学生（unlockDay 300）的 repeatable 填充事件要在 Day 300 即可触发**（`triggerDay:300` + `minAff:0`），给玩家 270 天窗口把好感刷到 85。
3. **普通新事件（无 `requireRelState` 锁的）都加 `excludeRelState:"cold"`**；而 `close`/`crush` 事件因 `requireRelState` 精确相等判定——冷战期 `get_rel_state` 返回 `cold`，已天然不触发，无需重复加。两者合力杜绝冷战期弹日常导致叙事穿帮。

> 后续若要对标完整角色（yutong 17 / jingjing 12），可在本蓝图 9 事件基线之上，按第 4 节空白单元格继续加厚至 11–12 个。
