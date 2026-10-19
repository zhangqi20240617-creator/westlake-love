# 关系状态机 落地设计（Phase 2 收口）

> 目标：把「0–100 好感数字 + 30/60/85 瓶颈锁」升级为**可感知、可倒退**的关系状态。
> 让玩家从「刷数值」转为「经营关系」——这是把养成质变恋爱的核心一步。
> 设计已对齐现有代码（`GameManager` / `DailyCycleManager` / `DataManager` / `SaveSystem` / `CharacterStatsPopup`）。

---

## 1. 状态定义

关系状态 = 好感度的**纯函数**（加冷战覆盖态）。共 5 个上升态 + 1 个覆盖态：

| state id     | 中文   | 颜色 ramp | 好感区间 | 含义 |
|--------------|--------|-----------|----------|------|
| `stranger`   | 陌生   | gray      | 0–14     | 刚认识 / 几乎没交集 |
| `acquaintance` | 熟悉 | blue      | 15–29    | 脸熟，能说上话 |
| `friend`     | 朋友   | green     | 30–59    | 稳定友谊（对应首个瓶颈锁 30） |
| `close`      | 暧昧   | pink      | 60–84    | 明显超出友谊（对应瓶颈锁 60） |
| `crush`      | 心动   | coral     | ≥85      | 关系质变（对应瓶颈锁 85） |
| `cold`       | 冷战   | red       | 覆盖态   | 由 flag 触发，叠加在以上任一态之上 |

> 区间边界刻意与 `FAVOR_MILESTONES` 的 30/60/85 瓶颈锁对齐——状态跃迁点正好卡在「解锁剧情」的门槛上，叙事与系统咬合。

---

## 2. 核心设计：状态是派生值，不是真值

- `GameManager.relationship_state: Dictionary`（char_id -> state 字符串）为**缓存**，由 `favorability` 推导，**不直接作为真相**。
- 冷战态由 `flags["rel_cold_<char_id>"] = true` **覆盖**（flag 已在存档体系内，自动持久化）。
- 好处：
  - 好感升/降时，状态前进/倒退**自动发生**，无需额外记账。
  - 与现有 `char_mood`（每日刷新、缓存、随档保存）模式完全一致，团队无认知负担。
  - `_check_daily_decay` 的冷落/沉迷惩罚已经改 `favorability`，状态倒退顺理成章。

---

## 3. 转换规则

- **前进**：`add_favor` 后重算该角色状态；若状态序号上升，弹 toast「你和 X 的关系进入了『暧昧』阶段！」（仅升级时提示，降级不提示，避免负反馈噪音）。
- **倒退**：好感跌破阈值自动降级（如 暧昧→朋友）。重度冷落触发冷战（见下）。
- **冷战**：进入时好感一次性 −10（clamp 0–100），期间该角色好感增益封锁；需「挽回事件」解锁后才恢复增益与正常状态。

---

## 4. 冷战机制（让高好感也脆弱，制造张力）

### 触发（两种）
1. **说错话**：对话选项标记 `relCold: true` → `RelationshipManager.enter_cold_war(char_id)`。
2. **重度冷落**：在 `DailyCycleManager._check_daily_decay` 中，若角色处于 `close`/`crush` 且连续 **21 天**无互动（`flags["last_interact_<char_id>"]` 已存在该机制）→ 进入冷战。

### 期间行为
- `GameManager.add_favor`：若 `flags.has("rel_cold_<char_id>")`，`final_amount = 0`，弹「现在不是增进感情的时候……」，**跳过瓶颈锁提示**（避免冷战期误报剧情锁）。
- `relationship_state[char_id] = "cold"`。

### 挽回
- 事件标记 `requireRelState: "cold"` + `relRecover: true`，完成后 `RelationshipManager.recover_from_cold(char_id)` → 清 flag、由当前好感重算状态、弹「你和 X 和好了」。

---

## 5. 集成点（精确文件 / 函数）

| 文件 | 改动 |
|------|------|
| `scripts/RelationshipManager.gd` **(NEW Autoload)** | `REL_STATES` 常量（id/中文/颜色/好感下限）；`get_rel_state(char_id)`；`get_rel_state_display(char_id)`；`recompute_rel_state(char_id)`；`recompute_all_states()`；`enter_cold_war(char_id)`；`recover_from_cold(char_id)`；`_emit_state_change(char_id, prev, now)` |
| `scripts/GameManager.gd` | + `var relationship_state: Dictionary = {}`；`add_favor` 末尾调 `RelationshipManager.recompute_rel_state` 并封锁冷战增益；+ 门面 `get_rel_state` / `get_rel_state_display`；`_ready` 调 `recompute_all_states()` |
| `scripts/DailyCycleManager.gd` | `_check_daily_decay` 末尾调 `recompute_all_states()` + 重度冷落→冷战检测（复用 `last_interact_` flag） |
| `scripts/DataManager.gd` | `get_available_event` 增加 `requireRelState` / `excludeRelState` 两项检查（仿 `requireWeather` 写法） |
| `scripts/SaveSystem.gd` | `SAVE_VER` 5→6；保存 dict 加 `relationship_state`；`load_from_dict` 恢复；`_migrate_v5_to_v6` 保证键存在（缺失则由 `favorability` 重算） |
| `scripts/CharacterStatsPopup.gd` | 好感度网格中每个角色名后追加状态 chip（中文 + 颜色） |
| `project.godot` | `[autoload]` 注册 `RelationshipManager="*res://scripts/RelationshipManager.gd"` |
| `scripts/events_yutong.json` | 加 1–2 个示例事件：冷战触发选项 + 挽回事件（作为 Proof of Concept，后续再铺到其他角色） |

> 约定：新 Manager 用 **tab** 缩进；`GameManager` 继续用 **4 空格**（沿用现有拆分约定，避免同文件混用）。`relationship_state` 缓存字典与 `char_mood` 同款处理。

---

## 6. 事件 schema 新增字段

```json
{
  "id": "yt_cold_war_01",
  "charId": "yutong",
  "requireRelState": "crush",
  "excludeRelState": "",
  "relCold": true,
  "relRecover": false,
  "scenes": [ ... ]
}
```

- `requireRelState`：可选，关系状态需等于该值才触发（如专属心动事件仅 `crush` 出现）。
- `excludeRelState`：可选，关系状态不能等于（如冷战期屏蔽普通邀约事件）。
- `relCold`：可选，选此选项 / 完成此事件 → 进入冷战。
- `relRecover`：可选，完成此事件 → 挽回冷战。

---

## 7. UI 呈现

- **角色面板（`CharacterStatsPopup`）**：好感度网格每角色追加状态 chip，如「陈雨桐 [朋友]」，颜色随状态 ramp（gray/blue/green/pink/coral/red）。
- **升级 toast**：关系进入新阶段时提示（仅在 `recompute_rel_state` 检测到序号上升时）。
- **（本次不做，留待 Phase 4）**：`DialogueUI` 对话头、中央 Dashboard 显示状态——先验证核心机制，UI 扩展后续接。

---

## 8. 存档与迁移

- `relationship_state` 字典随档保存（v6 新增键）。
- 读档若无该键（旧档），`_migrate_v5_to_v6` 直接由 `favorability` 重算填充，不影响旧进度。
- 冷战 flag 落在 `flags` 内，已自动持久化，无需额外处理。

---

## 9. 实施检查清单（建议顺序）

1. 新建 `RelationshipManager.gd` 并注册 Autoload。
2. `GameManager`：加 `relationship_state` 字典 + `add_favor` 重算/封锁钩子 + 门面 + `_ready` 重算。
3. `DailyCycleManager`：衰减后重算 + 重度冷落冷战检测。
4. `DataManager`：`requireRelState` / `excludeRelState` 检查。
5. `SaveSystem`：v6 + 序列化 + 迁移。
6. `CharacterStatsPopup`：状态 chip。
7. 示例事件：yutong 冷战 + 挽回。
8. 全量 grep 校验无悬空引用、缩进一致；交付用户在 Godot 验证。

---

## 10. 风险与注意

- **重算时机**：必须在 `add_favor` 与 `_check_daily_decay` 两处都重算，否则 UI 与真值不一致。
- **冷战增益封锁**要同时处理正向 `final_amount=0` 与跳过瓶颈锁提示，避免冷战期误报「关系遭遇瓶颈」。
- **倒退不提示**：降级静默处理，只在升级时给正反馈，控制情感噪音。
- **零破窗**：所有新调用走 `GameManager` 门面，27 个现有调用方不受影响（它们本就不读关系状态字段）。
